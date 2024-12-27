class GoogleSheetInfo {

  static GoogleSheetInfo empty = GoogleSheetInfo();

  final String? title;
  final Map<String, String> columns;
  final String? todayRow;

  GoogleSheetInfo({
    this.title,
    this.columns = const <String, String>{},
    this.todayRow,
  });
}