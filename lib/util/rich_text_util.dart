import 'package:flutter/material.dart';

class _Marker {
  static const bold = "**";
}

RichText buildRichText(String text, TextTheme theme) {
  List<TextSpan> spans = [];
  int offset = 0;
  while (offset < text.length) {
    int markerStart = text.indexOf(_Marker.bold, offset);
    if (markerStart >= 0) {
      int markerEnd = text.indexOf(_Marker.bold, markerStart + 1);
      if (markerEnd > markerStart) {
        if (offset < markerStart) {
          spans.add(TextSpan(
            text: text.substring(offset, markerStart),
          ));
        }
        spans.add(TextSpan(
          text: text.substring(markerStart + _Marker.bold.length, markerEnd),
          style: TextStyle(fontWeight: FontWeight.bold),
        ));
        offset = markerEnd + _Marker.bold.length;
      } else {
        spans.add(TextSpan(
          text: text.substring(offset, markerStart + _Marker.bold.length),
        ));
        offset = markerStart + _Marker.bold.length;
      }
    } else {
      spans.add(TextSpan(
        text: text.substring(offset),
      ));
      break;
    }
  }
  return RichText(
    text: TextSpan(
      style: TextStyle(color: theme.bodyMedium?.color ?? Colors.black, fontSize: 18),
      children: spans,
    ),
  );
}
