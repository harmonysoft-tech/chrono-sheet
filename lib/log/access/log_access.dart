import 'package:chrono_sheet/google/state/google_login_state.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'log_access.g.dart';

@riverpod
class LogAccessManager extends _$LogAccessManager {
  @override
  bool build() {
    final loginStateAsync = ref.watch(loginStateManagerProvider);
    return kDebugMode ||
        (loginStateAsync is AsyncData<GoogleIdentity?> && loginStateAsync.value?.email == "denzhdanov@gmail.com");
  }
}
