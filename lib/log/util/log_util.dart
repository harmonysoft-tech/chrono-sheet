import 'package:logging/logging.dart';

final regex = RegExp(r'package:([^:]+)');

Logger getNamedLogger() {
  final stackTrace = StackTrace.current.toString();
  final matches = regex.allMatches(stackTrace).toList();
  var name = '';
  if (matches.length > 1) {
    name = matches[1][0] ?? '';
    final i = name.lastIndexOf('/');
    if (i > 0) {
      name = name.substring(i + 1);
    }
  }
  return Logger(name);
}