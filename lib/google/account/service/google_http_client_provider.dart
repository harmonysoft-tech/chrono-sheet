import 'package:chrono_sheet/google/account/service/google_identity_provider.dart';
import 'package:chrono_sheet/http/AuthenticatedHttpClient.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'google_http_client_provider.g.dart';

http.Client? _overriddenData;

@riverpod
class GoogleHttpClient extends _$GoogleHttpClient {

  @override
  Future<http.Client?> build() async {
    if (_overriddenData != null) {
      if (state is !AsyncData || state.value == null) {
        state = AsyncValue.data(_overriddenData);
      }
      return _overriddenData;
    }

    final identity = await ref.watch(googleIdentityProvider.future);
    if (identity == null) {
      return null;
    }

    final headers = {"Authorization": "Bearer ${identity.accessToken}"};
    return AuthenticatedHttpClient(headers);
  }

  static void setDataOverride(http.Client client) {
    _overriddenData = client;
  }

  static void resetOverride() {
    _overriddenData = null;
  }
}