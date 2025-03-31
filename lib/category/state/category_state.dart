import 'dart:math';

import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/category/model/category_representation.dart';
import 'package:chrono_sheet/file/state/file_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:chrono_sheet/util/regexp_util.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../file/model/google_file.dart';
import '../../network/network.dart';
import '../../sheet/updater/sheet_updater.dart';
import '../../sheet/updater/update_service.dart';

part 'category_state.g.dart';

final _categoryNamesToHideInUi = {Column.date, Column.total};
final _logger = getNamedLogger();

class CategoryState {
  static CategoryState empty = CategoryState();

  final Category? selected;
  final List<Category> categories;
  final String id;

  CategoryState({this.selected, this.categories = const [], String? id}) : id = id ?? Uuid().v4();

  @override
  String toString() {
    return 'CategoryState{id: $id, selected: ${selected?.name}, ${categories.length} categories: \n${categories.join("\n")}}';
  }
}

class _Key {
  static String getStateId(GoogleFile file) {
    return "category.${file.id}.state.id";
  }

  static String getSelected(GoogleFile file) {
    return "category.${file.id}.selected";
  }

  static String getFileCategoryPrefix(GoogleFile file, int i) {
    return "category.${file.id}.$i";
  }

  static String getCommonCategoryPrefix(String categoryName) {
    return "category.common.$categoryName";
  }
}

enum ManageCategoryResult {
  success,
  nameConflict,
  noFileSelected,
  wrongOriginalCategory,
  generic;

  String getMessage(AppLocalizations l10n) {
    switch (this) {
      case ManageCategoryResult.success:
        return l10n.textChangeIsSuccessful;
      case ManageCategoryResult.nameConflict:
        return l10n.errorCategoryNameMustBeUnique;
      case ManageCategoryResult.noFileSelected:
        return l10n.errorNoFileIsSelected;
      case ManageCategoryResult.wrongOriginalCategory:
        return l10n.errorChangeIsStale;
      case ManageCategoryResult.generic:
        return l10n.errorGeneric;
    }
  }
}

@riverpod
class CategoryStateManager extends _$CategoryStateManager {
  final SharedPreferencesAsync _prefs;

  CategoryStateManager({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  @override
  Future<CategoryState> build() async {
    final fileState = await ref.watch(fileStateManagerProvider.future);
    _logger.info("start building categories state");
    final selectedFile = fileState.selected;
    if (selectedFile == null) {
      return CategoryState.empty;
    }
    final cached = await _readCachedCategoryState(selectedFile);
    if (cached == null) {
      final result = await _parseAndApplyCategoriesFromSheet(selectedFile);
      return result.match((error) => CategoryState(), (newState) => newState);
    } else {
      _logger.info("found cached category state: $cached");
      _parseAndApplyCategoriesFromSheet(selectedFile).then((result) {
        result.map((newState) {
          state = AsyncValue.data(newState);
        });
      });
      return cached;
    }
  }

  Future<Either<Unit, CategoryState>> _parseAndApplyCategoriesFromSheet(GoogleFile file) async {
    _logger.info("loading categories from the remote document");
    final categoryNamesFromFileResult = await _parseCategoryNames(file);
    return categoryNamesFromFileResult.match(
      (error) {
        _logger.info("failed to load categories from $file");
        return Either.left(unit);
      },
      (categoryNamesFromFile) async {
        _logger.info("fetched remote categories: $categoryNamesFromFile");
        final currentState = state;
        CategoryState? cached;
        if (currentState is AsyncData) {
          cached = currentState.value;
        }
        final newCategoryState = await _merge(cached, categoryNamesFromFile);
        await _cacheCategoryState(newCategoryState, file);
        return Either.right(newCategoryState);
      },
    );
  }

  Future<Category> _getCategoryByName(String name) async {
    final category = await Category.deserialiseIfPossible(_prefs, _Key.getCommonCategoryPrefix(name));
    if (category != null) {
      return category;
    }
    return Category(
      name: name,
      persistedInGoogle: false,
      representation: TextCategoryRepresentation(_getDefaultRepresentationText(name)),
    );
  }

  Future<CategoryState?> _readCachedCategoryState(GoogleFile file) async {
    List<Category> categories = [];
    for (int i = 0; ; i++) {
      final categoryName = await _prefs.getString(_Key.getFileCategoryPrefix(file, i));
      if (categoryName == null) {
        break;
      }
      final category = await _getCategoryByName(categoryName);
      categories.add(category);
    }
    _logger.info(
      "found ${categories.length} cached categories for file ${file.id} (${file.name}): \n${categories.join("\n")}",
    );
    if (categories.isEmpty) {
      return null;
    }

    final normalisedCategories = ensureNoDuplicateTextRepresentations(categories);
    final shouldSaveAfterNormalisation = categories != normalisedCategories;

    final selectedCategoryName = await _prefs.getString(_Key.getSelected(file));
    _logger.info("found selected category '$selectedCategoryName' for file ${file.id} (${file.name})");
    Category? selectedCategory;
    if (selectedCategoryName != null) {
      selectedCategory = normalisedCategories.firstWhereOrNull((c) => c.name == selectedCategoryName);
    }

    selectedCategory ??= normalisedCategories.first;

    final id = await _prefs.getString(_Key.getStateId(file));
    final result = CategoryState(id: id, selected: selectedCategory, categories: normalisedCategories);

    if (shouldSaveAfterNormalisation) {
      _logger.info(
        "detected that normalised categories differ from originally read categories, caching "
        "the normalised categories state",
      );
      await _cacheCategoryState(result, file);
    }
    return result;
  }

  String _getDefaultRepresentationText(String name) {
    final parts = name.split(AppRegexp.whitespaces);
    if (parts.length > 1) {
      return parts.first.substring(0, 1) + parts[1][0];
    }
    if (name.isEmpty) {
      return name;
    } else if (name.length == 1) {
      return name.substring(0, 1);
    } else {
      return name.substring(0, 2);
    }
  }

  List<Category> ensureNoDuplicateTextRepresentations(List<Category> categories) {
    final List<Category> result = [];
    Map<String, int> usedRepresentations = {};
    for (var category in categories) {
      var representation = category.representation;
      if (representation is! TextCategoryRepresentation) {
        result.add(category);
        continue;
      }
      representation = _normaliseTextRepresentation(representation);
      final clashingCategoryIndex = usedRepresentations.remove(representation.text);
      if (clashingCategoryIndex == null) {
        usedRepresentations[representation.text] = result.length;
        result.add(category.copyWith(representation: representation));
        continue;
      }

      final clashingCategory = result[clashingCategoryIndex];
      final adjusted = _resolveTextRepresentationClash(category.name, clashingCategory.name, usedRepresentations);
      final adjustedClashingCategoryTextRepresentation = adjusted[clashingCategory.name]!;
      usedRepresentations[adjustedClashingCategoryTextRepresentation] = clashingCategoryIndex;
      result[clashingCategoryIndex] = clashingCategory.copyWith(
        representation: TextCategoryRepresentation(adjustedClashingCategoryTextRepresentation),
      );

      final adjustedCategoryTextRepresentation = adjusted[category.name]!;
      usedRepresentations[adjustedCategoryTextRepresentation] = result.length;
      result.add(category.copyWith(representation: TextCategoryRepresentation(adjustedCategoryTextRepresentation)));
    }
    return result;
  }

  TextCategoryRepresentation _normaliseTextRepresentation(TextCategoryRepresentation representation) {
    if (representation.text.length > 1) {
      return TextCategoryRepresentation(_getDefaultRepresentationText(representation.text));
    } else {
      return representation;
    }
  }

  Map<String, String> _resolveTextRepresentationClash(String s1, String s2, Map<String, int> usedRepresentations) {
    final partsFirstLetters1 = s1.split(AppRegexp.whitespaces).map((s) => s[0]).join();
    final partsFirstLetters2 = s2.split(AppRegexp.whitespaces).map((s) => s[0]).join();
    final fromFirstLetters = _doResolveTextRepresentationClash(
      partsFirstLetters1,
      partsFirstLetters2,
      usedRepresentations,
    );
    if (fromFirstLetters[partsFirstLetters1] != fromFirstLetters[partsFirstLetters2]) {
      return fromFirstLetters;
    }
    return _doResolveTextRepresentationClash(s1, s2, usedRepresentations);
  }

  Map<String, String> _doResolveTextRepresentationClash(String s1, String s2, Map<String, int> usedRepresentations) {
    for (int i = 1, limit = min(s1.length, s2.length); i < limit; i++) {
      if (s1[i] != s2[i]) {
        return {s1: s1.substring(0, 1) + s1[i], s2: s2.substring(0, 1) + s2[i]};
      }
    }
    return {s1: _getDefaultRepresentationText(s1), s2: _getDefaultRepresentationText(s2)};
  }

  Future<CategoryState> _merge(CategoryState? cached, List<String> currentCategoryNames) async {
    _logger.info("merging cached categories state (\n$cached\n) and current categories ($currentCategoryNames)");
    if (currentCategoryNames.isEmpty && (cached?.categories.all((c) => c.persistedInGoogle) ?? true)) {
      return CategoryState.empty;
    }
    if (cached == null) {
      List<Category> categories = await Future.wait(
        currentCategoryNames.map((name) async {
          return await _getCategoryByName(name);
        }),
      );
      categories = ensureNoDuplicateTextRepresentations(categories);
      final selected = categories.first;
      return CategoryState(selected: selected, categories: categories);
    }
    List<Category> sortedCategories = List.of(cached.categories);
    sortedCategories.removeWhere(
      (category) => !currentCategoryNames.contains(category.name) && category.persistedInGoogle,
    );
    final Set<String> cachedCategoryNames = Set.of(cached.categories.map((c) => c.name));
    final categoryNamesToAdd = currentCategoryNames.where((name) => !cachedCategoryNames.contains(name));
    final categoriesToAdd = await Future.wait(
      categoryNamesToAdd.map((name) async {
        return await _getCategoryByName(name);
      }),
    );
    sortedCategories.addAll(categoriesToAdd);

    sortedCategories = ensureNoDuplicateTextRepresentations(sortedCategories);

    Category? selected = cached.selected;
    if (selected == null || !currentCategoryNames.contains(selected.name)) {
      selected = sortedCategories.first;
    }
    final result = CategoryState(selected: selected, categories: sortedCategories);
    _logger.info("categories after merge: $result");
    return result;
  }

  Future<ManageCategoryResult> _cacheCategoryState(CategoryState state, [GoogleFile? file]) async {
    final GoogleFile fileToUse;
    if (file == null) {
      final fileState = await ref.read(fileStateManagerProvider.future);
      final file = fileState.selected;
      if (file == null) {
        _logger.info("cannot cache categories state because no file is selected");
        return ManageCategoryResult.noFileSelected;
      } else {
        fileToUse = file;
      }
    } else {
      fileToUse = file;
    }

    await _prefs.setString(_Key.getStateId(fileToUse), state.id);

    final selected = state.selected;
    if (selected == null) {
      await _prefs.remove(_Key.getSelected(fileToUse));
      await _prefs.remove(_Key.getFileCategoryPrefix(fileToUse, state.categories.length));
    } else {
      await _prefs.setString(_Key.getSelected(fileToUse), selected.name);
      await selected.serialize(_prefs, _Key.getFileCategoryPrefix(fileToUse, state.categories.length));
      await _prefs.remove(_Key.getFileCategoryPrefix(fileToUse, state.categories.length + 1));
    }

    final categories = state.categories;
    for (int i = 0; i < categories.length; i++) {
      await _prefs.setString(_Key.getFileCategoryPrefix(fileToUse, i), categories[i].name);
    }
    _logger.info("cached categories state for file ${fileToUse.id} (${fileToUse.name}): $state");
    return ManageCategoryResult.success;
  }

  Future<Either<Unit, List<String>>> _parseCategoryNames(GoogleFile file) async {
    final online = await isOnline();
    if (!online) {
      return Either.left(unit);
    }
    final info = await parseSheetDocument(file);
    return Either.right(info.columns.keys.where((c) => !_categoryNamesToHideInUi.contains(c)).toList());
  }

  Category? _findCategoryWithName(CategoryState state, String name, [Category? toSkip]) {
    if (state.selected?.name == name && state.selected != toSkip) {
      return state.selected;
    }
    for (final existingCategory in state.categories) {
      if (existingCategory.name == name && existingCategory != toSkip) {
        return existingCategory;
      }
    }
    return null;
  }

  Future<ManageCategoryResult> addNewCategory(Category category) async {
    final currentState = await future;
    final selected = currentState.selected;
    final withConflictingName = _findCategoryWithName(currentState, category.name);
    if (withConflictingName != null) {
      _logger.info("given new category ($category) conflicts by name with the selected one - '$withConflictingName'");
      return ManageCategoryResult.nameConflict;
    }

    List<Category> categoriesToUse = List.of(currentState.categories);
    if (selected != null) {
      categoriesToUse.insert(0, selected);
    }
    categoriesToUse.insert(0, category);
    final normalisedCategoriesToUse = ensureNoDuplicateTextRepresentations(categoriesToUse);
    final newState = CategoryState(selected: category, categories: normalisedCategoriesToUse);
    state = AsyncValue.data(newState);
    final result = await _cacheCategoryState(newState);
    if (result == ManageCategoryResult.success) {
      _logger.info("categories state after adding new category '$category': $newState");
    }

    return result;
  }

  Future<ManageCategoryResult> replaceCategory(Category from, Category to) async {
    _logger.info("got a request to replace category '$from' by '$to'");
    final current = await future;

    final withConflictingName = _findCategoryWithName(current, to.name, from);
    if (withConflictingName != null) {
      _logger.info(
        "cannot replace category '$from' by '$to' because the name '${to.name}' is already used "
        "for category '$withConflictingName'",
      );
      return ManageCategoryResult.nameConflict;
    }

    final i = current.categories.indexOf(from);
    if (i < 0) {
      _logger.info("cannot replace non-selected category '$from' by '$to' because no 'from' category is registered");
      return ManageCategoryResult.wrongOriginalCategory;
    }

    await to.serialize(_prefs, _Key.getCommonCategoryPrefix(to.name));
    final newCategories = List.of(current.categories);
    newCategories[i] = to;
    final newSelected = current.selected == from ? to : current.selected;
    final newState = CategoryState(selected: newSelected, categories: newCategories);
    state = AsyncValue.data(newState);
    final result = await _cacheCategoryState(newState);
    if (result == ManageCategoryResult.success) {
      _logger.info("categories state after replacing category '$from' by '$to': $newState");
    }
    if (from.name != to.name) {
      final file = await ref.read(sheetUpdaterProvider.notifier).prepareToChange();
      if (file == null) {
        return ManageCategoryResult.noFileSelected;
      }
      final updateService = ref.read(updateServiceProvider);
      final ok = await updateService.renameCategory(from: from.name, to: to.name, file: file);
      if (!ok) {
        return ManageCategoryResult.generic;
      }
    }
    return result;
  }

  Future<CategoryState> select(Category category) async {
    _logger.info("got a request to select category '$category'");
    final current = await future;
    if (current.selected == category) {
      _logger.info("category '$category' is already selected");
      return current;
    }
    if (!current.categories.contains(category)) {
      _logger.info("cannot select category '$category' because it's not registered");
      return current;
    }

    CategoryState newState = CategoryState(selected: category, categories: current.categories);
    final saveResult = await _cacheCategoryState(newState);
    if (saveResult == ManageCategoryResult.success) {
      _logger.info("categories state after '$category' is selected: $newState");
    }
    state = AsyncValue.data(newState);
    return newState;
  }

  Future<void> onMeasurement(Category category) async {
    final current = await future;
    final i = current.categories.indexWhere((c) => c.name == category.name);
    if (i < 0) {
      _logger.info("skipping onMeasurement() for category '${category.name}' because it's not registered");
      return;
    }
    if (i == 0 && category.persistedInGoogle) {
      _logger.info("category ${category.name} is already the first and is persisted, skipping onMeasurement()");
      return;
    }
    final categoriesToUse = List.of(current.categories);
    Category categoryToUse = categoriesToUse[i];
    if (!categoryToUse.persistedInGoogle) {
      categoryToUse = categoryToUse.copyWith(persistedInGoogle: true);
    }
    categoriesToUse.removeAt(i);
    categoriesToUse.insert(0, categoryToUse);
    final newState = CategoryState(selected: categoryToUse, categories: categoriesToUse);
    await _cacheCategoryState(newState);
    state = AsyncValue.data(newState);
  }
}
