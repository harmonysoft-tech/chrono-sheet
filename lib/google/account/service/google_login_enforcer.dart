import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/google/account/service/google_identity_provider.dart';
import 'package:chrono_sheet/util/snackbar_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final googleLoginEnforcer = Provider<GoogleLoginEnforcer>((ref) => GoogleLoginEnforcer(ref));

class GoogleLoginEnforcer {
  final Ref _ref;

  GoogleLoginEnforcer(this._ref);

  Future<bool> ensureLogin(BuildContext context, Logger logger, String Function(AppLocalizations) messageMapper) async {
    final identity = _ref.read(googleIdentityProvider.notifier);
    final result = await identity.getAccount(true);
    final loggedIn = result.isRight();
    if (!loggedIn && context.mounted) {
      SnackBarUtil.showL10nMessage(context, logger, messageMapper);
    }
    return loggedIn;
  }
}
