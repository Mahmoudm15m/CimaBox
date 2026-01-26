import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:dio/dio.dart';
import '../models/download_model.dart';

class DownloadsProvider with ChangeNotifier {
  List<DownloadItem> downloads = [];
  final Dio _dio = Dio();
  final String _defaultUserAgent = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final Map<String, CancelToken> _cancelTokens = {};
  final String _dbFileName = "downloads_db.json";

  DownloadsProvider() {
    _loadDownloadsFromDisk();
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
    } catch (e) {
      print("Error saving downloads: $e");
    }
  }

  Future<void> _loadDownloadsFromDisk() async {
    try {
      final file = await _getDbFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> decodedList = json.decode(jsonStr);
        downloads = decodedList.map((e) => DownloadItem.fromJson(e)).toList();

        for (var item in downloads) {
          if (item.status == DownloadStatus.downloading) {
            item.status = DownloadStatus.paused;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      print("Error loading downloads: $e");
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) return true;
      return true;
    }
    return true;
  }

  Future<String> _getDownloadPath() async {
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/CimaBox');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      return directory.path;
    } catch (e) {
      final dir = await getExternalStorageDirectory();
      return dir?.path ?? '';
    }
  }

  Future<void> addPendingDownload({
    required int contentId,
    required String quality,
    required String title,
    required String fileNameLabel,
    required String image,
  }) async {
    String saveDir = await _getDownloadPath();
    String finalFileName = fileNameLabel.endsWith('.mp4') ? fileNameLabel : "$fileNameLabel.mp4";
    String filePath = "$saveDir/$finalFileName";

    final downloadItem = DownloadItem(
      id: DateTime.now().toString() + contentId.toString(),
      contentId: contentId,
      quality: quality,
      url: '',
      title: title,
      fileNameLabel: fileNameLabel,
      image: image,
      savedPath: filePath,
      status: DownloadStatus.pending,
    );

    downloads.insert(0, downloadItem);
    _saveDownloadsToDisk();
    notifyListeners();
  }

  Future<void> startDownload(String url, String title, String image, {Map<String, String>? headers, String? fileName, bool autoStart = true}) async {
    bool hasPermission = await _requestPermission();
    if (!hasPermission) return;

    String saveDir = await _getDownloadPath();

    String finalFileName;
    if (fileName != null && fileName.isNotEmpty) {
      finalFileName = fileName.endsWith('.mp4') ? fileName : "$fileName.mp4";
    } else {
      String cleanTitle = title.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '');
      finalFileName = "${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4";
    }

    String filePath = "$saveDir/$finalFileName";

    bool isHls = url.contains('.m3u8') || url.contains('vidmoly') || url.contains('dood');

    final downloadItem = DownloadItem(
      id: DateTime.now().toString(),
      url: url,
      title: title,
      fileNameLabel: finalFileName,
      image: image,
      savedPath: filePath,
      type: isHls ? DownloadType.hls : DownloadType.direct,
      status: autoStart ? DownloadStatus.downloading : DownloadStatus.paused,
      headers: headers,
    );

    downloads.insert(0, downloadItem);
    _saveDownloadsToDisk();
    notifyListeners();

    if (autoStart) {
      if (isHls) {
        _startHlsDownload(downloadItem);
      } else {
        _startDirectDownloadWithDio(downloadItem);
      }
    }
  }

  Future<void> initializePendingDownload(String id, String url, {Map<String, String>? headers}) async {
    bool hasPermission = await _requestPermission();
    if (!hasPermission) return;

    final item = downloads.firstWhere((element) => element.id == id, orElse: () => DownloadItem(id: '', url: '', title: '', image: ''));
    if (item.id.isEmpty) return;

    bool isHls = url.contains('.m3u8') || url.contains('vidmoly') || url.contains('dood');

    item.url = url;
    item.type = isHls ? DownloadType.hls : DownloadType.direct;
    item.status = DownloadStatus.downloading;
    if (headers != null) {
      item.headers = headers;
    }

    _saveDownloadsToDisk();
    notifyListeners();

    if (isHls) {
      _startHlsDownload(item);
    } else {
      _startDirectDownloadWithDio(item);
    }
  }

  void resumeDownload(String id) {
    final item = downloads.firstWhere((element) => element.id == id, orElse: () => DownloadItem(id: '', url: '', title: '', image: ''));
    if (item.id.isEmpty) return;

    if (item.url.isEmpty) {
      return;
    }

    item.status = DownloadStatus.downloading;
    notifyListeners();

    if (item.type == DownloadType.hls) {
      _startHlsDownload(item);
    } else {
      _startDirectDownloadWithDio(item);
    }
  }

  Future<void> _startDirectDownloadWithDio(DownloadItem item) async {
    CancelToken cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    _updateNotification(item, customBody: "جاري التحميل... لا تغلق التطبيق");

    int lastUpdateTimestamp = 0;

    Map<String, dynamic> requestHeaders = {};
    if (item.headers != null) {
      requestHeaders.addAll(item.headers!);
    }

    bool hasUserAgent = requestHeaders.keys.any((k) => k.toLowerCase() == 'user-agent');
    if (!hasUserAgent) {
      requestHeaders['User-Agent'] = _defaultUserAgent;
    }

    print("--- STARTING DOWNLOAD ---");
    print("URL: ${item.url}");
    print("Headers: $requestHeaders");

    try {
      await _dio.download(
        item.url,
        item.savedPath,
        cancelToken: cancelToken,
        options: Options(
          headers: requestHeaders,
          validateStatus: (status) => status != null && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.totalBytes = total;
            item.downloadedBytes = received;
            item.progress = received / total;
          } else {
            item.downloadedBytes = received;
          }

          int now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateTimestamp > 250 || received == total) {
            lastUpdateTimestamp = now;
            notifyListeners();
            _updateNotification(item, customBody: "جارٍ التحميل (${(item.progress*100).toInt()}%) - لا تغلق التطبيق");
          }
        },
      );

      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      _updateNotification(item, isCompleted: true);
      _saveDownloadsToDisk();
      notifyListeners();
      print("--- DOWNLOAD COMPLETED ---");

    } catch (e) {
      print("--- DOWNLOAD FAILED ---");
      print("Error: $e");
      if (e is DioException) {
        print("Dio Status Code: ${e.response?.statusCode}");
        print("Dio Response Data: ${e.response?.data}");
        print("Dio Response Headers: ${e.response?.headers}");
      }

      if (CancelToken.isCancel(e as DioException)) {
        print("Download cancelled");
      } else {
        item.status = DownloadStatus.failed;
        _updateNotification(item, isFailed: true);
        _saveDownloadsToDisk();
      }
      notifyListeners();
    } finally {
      _cancelTokens.remove(item.id);
    }
  }

  void _startHlsDownload(DownloadItem item) {
    Map<String, String> finalHeaders = {};
    if (item.headers != null) {
      finalHeaders.addAll(item.headers!);
    }
    bool hasUserAgent = finalHeaders.keys.any((k) => k.toLowerCase() == 'user-agent');
    if (!hasUserAgent) {
      finalHeaders['User-Agent'] = _defaultUserAgent;
    }

    String headersOption = "";
    if (finalHeaders.isNotEmpty) {
      StringBuffer sb = StringBuffer();
      finalHeaders.forEach((k, v) => sb.write("$k: $v\r\n"));
      headersOption = '-headers "${sb.toString()}"';
    }

    print("--- STARTING HLS DOWNLOAD ---");
    print("URL: ${item.url}");
    print("Headers Option: $headersOption");

    _updateNotification(item, customBody: "تجهيز التحميل...");

    String probeCommand = '$headersOption -v error -show_entries format=duration,bit_rate -of default=noprint_wrappers=1:nokey=0 "${item.url}"';
    FFprobeKit.execute(probeCommand).then((session) async {
      final output = await session.getOutput();
      if (output != null) {
        final lines = output.split('\n');
        double totalDuration = 0;
        double bitrate = 0;
        for (var line in lines) {
          if (line.startsWith('duration=')) {
            totalDuration = double.tryParse(line.split('=')[1].trim()) ?? 0;
          } else if (line.startsWith('bit_rate=')) {
            bitrate = double.tryParse(line.split('=')[1].trim()) ?? 0;
          }
        }
        if (totalDuration > 0 && bitrate > 0) {
          item.totalBytes = ((bitrate * totalDuration) / 8).round();
          notifyListeners();
        }
      }
    });

    String command = '$headersOption -i "${item.url}" -c copy -bsf:a aac_adtstoasc -y "${item.savedPath}"';

    FFmpegKit.executeAsync(
      command,
          (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
          if (await File(item.savedPath!).exists()) {
            item.totalBytes = await File(item.savedPath!).length();
            item.downloadedBytes = item.totalBytes;
          }
          _updateNotification(item, isCompleted: true);
          print("--- HLS DOWNLOAD COMPLETED ---");
        } else {
          item.status = DownloadStatus.failed;
          _updateNotification(item, isFailed: true);
          print("--- HLS DOWNLOAD FAILED ---");
          final logs = await session.getAllLogs();
          for(var log in logs) {
            print(log.getMessage());
          }
        }
        _saveDownloadsToDisk();
        notifyListeners();
      },
          (log) {},
          (statistics) {
        item.downloadedBytes = statistics.getSize();
        if (item.totalBytes > 0) {
          double p = item.downloadedBytes / item.totalBytes;
          item.progress = p > 1.0 ? 1.0 : p;
        }

        _updateNotification(item, customBody: "تحويل HLS... لا تغلق التطبيق");
        notifyListeners();
      },
    ).then((session) {
      item.taskId = session.getSessionId() as int?;
    });
  }

  void _updateNotification(DownloadItem item, {bool isCompleted = false, bool isFailed = false, String? customBody}) {
    int notificationId = item.id.hashCode;

    if (isCompleted) {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'download_channel',
            title: isCompleted ? 'اكتمل التحميل' : (isFailed ? 'فشل التحميل' : item.title),
            body: isCompleted || isFailed ? item.title : (customBody ?? "جاري التحميل"),
            notificationLayout: isCompleted || isFailed ? NotificationLayout.Default : NotificationLayout.ProgressBar,
            progress: isCompleted ? null : (item.progress * 100).toInt().toDouble(),
            locked: !isCompleted && !isFailed,
            icon: 'resource://drawable/notification_icon',
          )
      );
    }
  }

  void deleteDownload(String id) {
    final item = downloads.firstWhere((element) => element.id == id, orElse: () => DownloadItem(id: '', url: '', title: '', image: ''));
    if (item.id.isEmpty) return;

    if (item.type == DownloadType.direct) {
      if (_cancelTokens.containsKey(id)) {
        _cancelTokens[id]!.cancel();
        _cancelTokens.remove(id);
      }
      if (item.downloaderTaskId != null) {
        FlutterDownloader.cancel(taskId: item.downloaderTaskId!);
      }
    } else {
      if (item.taskId != null) {
        FFmpegKit.cancel(item.taskId!);
      }
    }

    AwesomeNotifications().cancel(item.id.hashCode);

    if (item.savedPath != null) {
      final file = File(item.savedPath!);
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (e) { }
      }
    }

    downloads.removeWhere((element) => element.id == id);
    _saveDownloadsToDisk();
    notifyListeners();
  }
}