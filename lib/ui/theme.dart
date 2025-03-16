import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData theme = ThemeData(
    // useMaterial3: true,
    scaffoldBackgroundColor: Color(0xfffff8ff),
  );

  static final TextStyle labelTextStyle = TextStyle(
    fontSize: 14.0,
    fontFamily: "Roboto",
    fontWeight: FontWeight.normal,
    height: 1.0,
    color: Colors.black,
    decoration: TextDecoration.none,
  );
}