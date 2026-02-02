import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/download_model.dart';

class DownloadsProvider with ChangeNotifier {
  List<DownloadItem> downloads = [];
  final String _dbFileName = "downloads_db.json";
  static const platform = MethodChannel('com.cima_box/downloads');
  static const eventChannel = EventChannel('com.cima_box/downloads_progress');
  StreamSubscription? _progressSubscription;

  DownloadsProvider() {
    _loadDownloadsFromDisk();
    _startListeningToProgress();
  }

  void _startListeningToProgress() {
    _progressSubscription = eventChannel.receiveBroadcastStream().listen((event) {
      if (event is List) {
        bool needsNotify = false;
        bool needsSave = false;

        for (var update in event) {
          final Map<dynamic, dynamic> data = update;
          final String id = data['id'];
          final int statusIdx = data['status'];
          final double progress = (data['progress'] as num).toDouble();
          final int downloadedBytes = data['downloadedBytes'];
          final int totalBytes = data['totalBytes'];

          final index = downloads.indexWhere((d) => d.id == id);
          if (index != -1) {
            final item = downloads[index];

            if (item.exportedPath != null) continue;

            if (item.status == DownloadStatus.completed && item.progress >= 1.0) {
              if (progress < 100.0) continue;
            }

            if (item.progress != progress / 100 || item.downloadedBytes != downloadedBytes || item.status.index != _mapMedia3Status(statusIdx).index) {
              final oldStatus = item.status;

              item.progress = progress / 100;
              item.downloadedBytes = downloadedBytes;
              item.totalBytes = totalBytes;
              item.status = _mapMedia3Status(statusIdx);
              needsNotify = true;

              if (oldStatus != item.status || item.status == DownloadStatus.completed) {
                needsSave = true;
              }
            }
          }
        }

        if (needsSave) {
          _saveDownloadsToDisk();
        }

        if (needsNotify) {
          notifyListeners();
        }
      }
    }, onError: (error) {
      print("Error receiving progress: $error");
    });
  }

  DownloadStatus _mapMedia3Status(int media3State) {
    switch (media3State) {
      case 0: return DownloadStatus.pending;
      case 1: return DownloadStatus.paused;
      case 2: return DownloadStatus.downloading;
      case 3: return DownloadStatus.completed;
      case 4: return DownloadStatus.failed;
      default: return DownloadStatus.downloading;
    }
  }

  Future<void> startDownload(String url, String title, String image, {Map<String, String>? headers, String? fileName, int? contentId, String? quality}) async {
    final downloadItem = DownloadItem(
      id: url,
      url: url,
      title: title,
      image: image,
      fileNameLabel: fileName ?? title,
      status: DownloadStatus.downloading,
      progress: 0.0,
      type: url.contains('.m3u8') ? DownloadType.hls : DownloadType.direct,
      contentId: contentId,
      quality: quality ?? "",
    );

    downloads.removeWhere((item) => item.id == url);
    downloads.insert(0, downloadItem);
    _saveDownloadsToDisk();
    notifyListeners();

    try {
      await platform.invokeMethod('startDownload', {
        'url': url,
        'title': title,
        'headers': headers ?? {},
      });
    } catch (e) {
      downloadItem.status = DownloadStatus.failed;
      _saveDownloadsToDisk();
      notifyListeners();
    }
  }

  Future<void> addPendingDownload({required int contentId, required String quality, required String title, required String fileNameLabel, required String image}) async {
    final String tempId = "pending_${contentId}_${DateTime.now().microsecondsSinceEpoch}";

    final downloadItem = DownloadItem(
      id: tempId,
      url: "",
      title: title,
      image: image,
      fileNameLabel: fileNameLabel,
      status: DownloadStatus.pending,
      progress: 0.0,
      type: DownloadType.direct,
      contentId: contentId,
      quality: quality,
    );

    downloads.insert(0, downloadItem);
    _saveDownloadsToDisk();
    notifyListeners();
  }

  Future<void> initializePendingDownload(String id, String url, {Map<String, String>? headers}) async {
    final index = downloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      final pendingItem = downloads[index];

      downloads.removeAt(index);
      notifyListeners();

      await startDownload(
        url,
        pendingItem.title,
        pendingItem.image,
        headers: headers,
        fileName: pendingItem.fileNameLabel,
        contentId: pendingItem.contentId,
        quality: pendingItem.quality,
      );
    }
  }

  Future<void> pauseDownload(String id) async {
    final index = downloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      downloads[index].status = DownloadStatus.paused;
      notifyListeners();
      try {
        await platform.invokeMethod('pauseDownload', {'url': id});
      } catch (_) {}
      _saveDownloadsToDisk();
    }
  }

  Future<void> resumeDownload(String id) async {
    final index = downloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      downloads[index].status = DownloadStatus.downloading;
      notifyListeners();
      try {
        await platform.invokeMethod('resumeDownload', {'url': id});
      } catch (_) {}
      _saveDownloadsToDisk();
    }
  }

  Future<void> deleteDownload(String id) async {
    try {
      await platform.invokeMethod('removeDownload', {'url': id});
    } catch (_) {}

    downloads.removeWhere((element) => element.id == id);
    _saveDownloadsToDisk();
    notifyListeners();
  }

  Future<void> playDownloadedVideo(DownloadItem item) async {
    if (item.exportedPath != null && item.exportedPath!.isNotEmpty) {
      OpenFile.open(item.exportedPath);
    } else {
      try {
        await platform.invokeMethod('playOfflineVideo', {'url': item.url});
      } catch (e) {
        debugPrint("Play failed: $e");
      }
    }
  }

  Future<bool> exportVideoToGallery(String id) async {
    final index = downloads.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final item = downloads[index];

    try {
      final String? newPath = await platform.invokeMethod('exportDownload', {
        'url': item.url,
        'title': item.title,
      });

      if (newPath != null) {
        item.exportedPath = newPath;
        item.status = DownloadStatus.completed;

        _saveDownloadsToDisk();
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (e.toString().contains("NOT_SUPPORTED")) {
        throw "هذا الفيديو محمي ولا يمكن تصديره للمعرض";
      }
    }
    return false;
  }

  Future<File> _getDbFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_dbFileName');
  }

  Future<void> _saveDownloadsToDisk() async {
    try {
      final file = await _getDbFile();
      final String jsonStr = json.encode(downloads.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (_) { }
  }

  Future<void> _loadDownloadsFromDisk() async {
    try {
      final file = await _getDbFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> decodedList = json.decode(jsonStr);
        downloads = decodedList.map((e) => DownloadItem.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) { }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}