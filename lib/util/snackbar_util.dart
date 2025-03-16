import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class SnackBarUtil {
  static void showMessage(BuildContext context, String message, Logger logger) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      logger.info("cannot show snackbar with message '$message' - the build context is not mounted");
    }
  }

  static void showL10nMessage(BuildContext context, Logger logger, String Function(AppLocalizations) messageMapper) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      showMessage(context, messageMapper(l10n), logger);
    } else {
      logger.info("cannot show snackbar for mapped message - the build context is not mounted");
    }
  }
}
