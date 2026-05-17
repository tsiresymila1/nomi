import 'package:flutter/services.dart';
import 'package:gena/core/toast/app_toast.dart';

Future copyToClipboard(String textToCopy) async {
  await Clipboard.setData(ClipboardData(text: textToCopy));
  AppToast.show("Copied to clipboard");
}
