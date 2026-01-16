import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
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
            item.status = DownloadStatus.failed;
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

  // --- بدء التحميل ---
  Future<void> startDownload(String url, String title, String image, {Map<String, String>? headers}) async {
    bool hasPermission = await _requestPermission();
    if (!hasPermission) return;

    String saveDir = await _getDownloadPath();
    String cleanTitle = title.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '');
    String fileName = "${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4";
    String filePath = "$saveDir/$fileName";

    bool isHls = url.contains('.m3u8') || url.contains('vidmoly') || url.contains('dood');

    final downloadItem = DownloadItem(
      id: DateTime.now().toString(),
      url: url,
      title: title,
      image: image,
      savedPath: filePath,
      type: isHls ? DownloadType.hls : DownloadType.direct,
      status: DownloadStatus.downloading,
    );

    downloads.insert(0, downloadItem);
    _saveDownloadsToDisk();
    notifyListeners();

    if (isHls) {
      _startHlsDownload(downloadItem, headers);
    } else {
      _startDirectDownloadWithDio(downloadItem, headers);
    }
  }

  Future<void> _startDirectDownloadWithDio(DownloadItem item, Map<String, String>? headers) async {
    CancelToken cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    _updateNotification(item, customBody: "جاري التحميل... لا تغلق التطبيق");

    try {
      await _dio.download(
        item.url,
        item.savedPath,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.totalBytes = total;
            item.downloadedBytes = received;
            item.progress = received / total;
          } else {
            item.downloadedBytes = received;

          }

          notifyListeners();

          // تحديث الإشعار كل 5% لتخفيف الضغط
          if ((item.progress * 100).toInt() % 5 == 0) {
            _updateNotification(item, customBody: "جارٍ التحميل (${(item.progress*100).toInt()}%) - لا تغلق التطبيق");
          }
        },
      );

      // اكتمل التحميل
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      _updateNotification(item, isCompleted: true);
      _saveDownloadsToDisk();

    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        // تم الإلغاء يدوياً (تم حذفه)
        print("Download cancelled");
      } else {
        item.status = DownloadStatus.failed;
        _updateNotification(item, isFailed: true);
        _saveDownloadsToDisk();
      }
    } finally {
      _cancelTokens.remove(item.id);
      notifyListeners();
    }
  }

  void _startHlsDownload(DownloadItem item, Map<String, String>? headers) {
    String headersOption = "";
    if (headers != null && headers.isNotEmpty) {
      StringBuffer sb = StringBuffer();
      headers.forEach((k, v) => sb.write("$k: $v\r\n"));
      headersOption = '-headers "${sb.toString()}"';
    }

    _updateNotification(item, customBody: "تجهيز التحميل...");

    // محاولة معرفة الحجم أولاً
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
        } else {
          item.status = DownloadStatus.failed;
          _updateNotification(item, isFailed: true);
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
            title: 'اكتمل التحميل',
            body: item.title,
            notificationLayout: NotificationLayout.Default,
            locked: false,
          )
      );
    } else if (isFailed) {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'download_channel',
            title: 'فشل التحميل',
            body: item.title,
            notificationLayout: NotificationLayout.Default,
            locked: false,
          )
      );
    } else {
      int progress = (item.progress * 100).toInt();
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'download_channel',
          title: item.title,
          body: customBody ?? "جاري التحميل $progress%",
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress.toDouble(),
          locked: true,
          payload: {'path': item.savedPath ?? ''},
        ),
      );
    }
  }

  // --- حذف التحميل ---
  void deleteDownload(String id) {
    final item = downloads.firstWhere((element) => element.id == id, orElse: () => DownloadItem(id: '', url: '', title: '', image: ''));
    if (item.id.isEmpty) return;

    if (item.type == DownloadType.direct) {
      // 1. إلغاء Dio إذا كان يعمل
      if (_cancelTokens.containsKey(id)) {
        _cancelTokens[id]!.cancel();
        _cancelTokens.remove(id);
      }
      // إلغاء FlutterDownloader القديم إن وجد
      if (item.downloaderTaskId != null) {
        FlutterDownloader.cancel(taskId: item.downloaderTaskId!);
      }
    } else {
      // 2. إلغاء FFmpeg
      if (item.taskId != null) {
        FFmpegKit.cancel(item.taskId!);
      }
    }

    // إلغاء الإشعار
    AwesomeNotifications().cancel(item.id.hashCode);

    // حذف الملف
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