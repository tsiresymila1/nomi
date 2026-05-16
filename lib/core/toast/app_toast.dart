import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum AppToastType { success, error, info }

class AppToast {
  static Future<bool?> show(
    String message, {
    AppToastType type = AppToastType.info,
  }) {
    final textColor = switch (type) {
      AppToastType.success => Colors.green,
      AppToastType.error => Colors.red,
      AppToastType.info => null,
    };

    return Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      textColor: textColor,
    );
  }
}
