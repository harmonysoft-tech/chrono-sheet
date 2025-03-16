import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class SnackBarUtil {
  static void showSnackBarIfPossible(BuildContext context, String message, Logger logger) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      logger.info("cannot show snackbar with message '$message' - the build context is not mounted");
    }
  }
}