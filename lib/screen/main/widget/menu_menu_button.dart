import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/google/account/service/google_identity_provider.dart';
import 'package:chrono_sheet/network/network.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainMenuButton extends ConsumerStatefulWidget {
  const MainMenuButton({super.key});

  @override
  ConsumerState createState() => MainMenuButtonState();
}

class MainMenuButtonState extends ConsumerState<MainMenuButton> {
  bool _online = false;

  @override
  void initState() {
    super.initState();
    isOnline().then((online) => _online = online);
  }

  @override
  Widget build(BuildContext context) {
    final googleIdentity = ref.watch(googleIdentityProvider);
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.access_time),
            title: Text(l10n.titleActivity),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoute.activity);
            },
          ),
        ),
        googleIdentity.maybeWhen(
          data: (loginState) => loginState == null
              ? PopupMenuItem(
                  enabled: _online,
                  child: ListTile(
                    leading: Icon(Icons.login),
                    title: Text(l10n.titleLogin),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(googleIdentityProvider.notifier).login();
                    },
                  ),
                )
              : PopupMenuItem(
                  enabled: _online,
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text(l10n.titleLogout),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(googleIdentityProvider.notifier).logout();
                    },
                  ),
                ),
          orElse: () => PopupMenuItem(
            enabled: _online,
            child: ListTile(
              leading: Icon(Icons.login),
              title: Text(l10n.titleLogin),
              onTap: () {
                Navigator.pop(context);
                ref.read(googleIdentityProvider.notifier).login();
              },
            ),
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text(l10n.titleLogs),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoute.logs);
            },
          ),
        ),
      ],
    );
  }
}
