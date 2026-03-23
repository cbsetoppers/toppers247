import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class PlatformHelper {
  /// Save bytes to device Downloads folder (native) or trigger download (web)
  static Future<String?> saveBytesToDevice({
    required Uint8List bytes,
    required String title,
  }) async {
    if (kIsWeb) {
      // For web, you might need a different implementation, but usually you'd use a package or JS interop
      // For now, let's focus on keeping the native side functional as it was.
      return null;
    }

    var status = await Permission.storage.request();
    if (Platform.isAndroid && !status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }

    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final fileName =
        "${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final savePath = "${dir?.path}/$fileName";

    final file = File(savePath);
    await file.writeAsBytes(bytes);

    return savePath;
  }

  /// Open a file with the system viewer
  static void openFile(String path) {
    OpenFilex.open(path);
  }
}
