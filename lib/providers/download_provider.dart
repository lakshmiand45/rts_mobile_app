import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadState {
  final double progress;
  final bool isDownloading;
  final String? filePath;
  final String? error;

  DownloadState({
    this.progress = 0.0,
    this.isDownloading = false,
    this.filePath,
    this.error,
  });

  DownloadState copyWith({
    double? progress,
    bool? isDownloading,
    String? filePath,
    String? error,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadNotifier() : super({});

  Future<void> downloadFile(String url, String fileName) async {
    // 1. Request Permissions
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // For Android 13+, we don't strictly need storage permission for app-specific folders,
        // but for public Downloads we might. To keep it simple and internal:
        var status = await Permission.storage.request();
        if (status.isDenied) {
           state = {...state, url: DownloadState(error: "Storage permission denied")};
           return;
        }
      }
    }

    state = {...state, url: DownloadState(isDownloading: true, progress: 0.0)};

    try {
      final response = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final contentLength = response.contentLength ?? 0;
      
      List<int> bytes = [];
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory(); // Internal to app but accessible
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = "${directory!.path}/$fileName";
      final file = File(filePath);
      
      int downloaded = 0;

      response.stream.listen(
        (List<int> newBytes) {
          bytes.addAll(newBytes);
          downloaded += newBytes.length;
          if (contentLength > 0) {
            state = {
              ...state,
              url: state[url]!.copyWith(progress: downloaded / contentLength)
            };
          }
        },
        onDone: () async {
          await file.writeAsBytes(bytes);
          state = {
            ...state,
            url: state[url]!.copyWith(isDownloading: false, progress: 1.0, filePath: filePath)
          };
          // Automatically try to open
          OpenFile.open(filePath);
        },
        onError: (e) {
          state = {
            ...state,
            url: DownloadState(error: e.toString())
          };
        },
        cancelOnError: true,
      );
    } catch (e) {
      state = {
        ...state,
        url: DownloadState(error: e.toString())
      };
    }
  }

  void clearError(String url) {
    if (state.containsKey(url)) {
      state = {...state, url: state[url]!.copyWith(error: null)};
    }
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, Map<String, DownloadState>>((ref) {
  return DownloadNotifier();
});
