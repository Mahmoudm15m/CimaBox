import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import '../providers/downloads_provider.dart';
import '../providers/details_provider.dart';
import '../models/download_model.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String? _initializingId;

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<bool> _checkStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;

    if (deviceInfo.version.sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        return true;
      }
      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      var status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> _startPendingDownload(
      BuildContext context, DownloadItem item, DownloadsProvider provider) async {
    if (item.contentId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("خطأ: معرف المحتوى مفقود")));
      return;
    }

    setState(() {
      _initializingId = item.id;
    });

    try {
      final detailsProvider =
      Provider.of<DetailsProvider>(context, listen: false);
      final linkData = await detailsProvider.fetchLinkForDownload(
          item.contentId!, item.quality, context);

      if (linkData != null && mounted) {
        String url = linkData['url'];
        Map<String, String> headers = {};
        if (linkData['headers'] != null) {
          if (linkData['headers'] is Map) {
            linkData['headers'].forEach((k, v) {
              headers[k.toString()] = v.toString();
            });
          }
        }
        await provider.initializePendingDownload(item.id, url, headers: headers);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("فشل جلب رابط التحميل")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializingId = null;
        });
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, DownloadsProvider provider, String id) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("تأكيد الحذف",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذا الفيديو؟",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteDownload(id);
              Navigator.of(ctx).pop();
            },
            child: const Text("حذف",
                style:
                TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("التنزيلات",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
            onPressed: () {
              try {
                OpenFile.open("/storage/emulated/0/Download/CimaBox");
              } catch (_) {}
            },
          )
        ],
      ),
      body: Consumer<DownloadsProvider>(
        builder: (context, provider, child) {
          if (provider.downloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_done_rounded,
                        size: 65, color: Colors.white24),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "لا توجد تنزيلات حالياً",
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: provider.downloads.length,
            itemBuilder: (context, index) {
              final item = provider.downloads[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildDownloadCard(context, item, provider),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadCard(
      BuildContext context, DownloadItem item, DownloadsProvider provider) {
    bool isInitializing = _initializingId == item.id;
    double displayProgress = item.progress.clamp(0, 1);
    bool isCompleted = item.status == DownloadStatus.completed;
    bool isExported = item.exportedPath != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F1F1F),
            Color(0xFF181818),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.4),
          )
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CachedNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[900]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[850],
                      child: const Icon(Icons.movie,
                          color: Colors.white24, size: 35),
                    ),
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  color: Colors.black.withOpacity(0.35),
                ),
                if ((isCompleted || item.status == DownloadStatus.downloading || item.status == DownloadStatus.paused) && item.downloadedBytes > 0)
                  InkWell(
                    onTap: () => provider.playDownloadedVideo(item),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 12,
                              color: Colors.black.withOpacity(0.6))
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 30, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  if (item.fileNameLabel.isNotEmpty)
                    Text(
                      item.fileNameLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white38),
                    ),
                  const SizedBox(height: 8),

                  if (item.status == DownloadStatus.downloading ||
                      item.status == DownloadStatus.paused) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: displayProgress,
                        minHeight: 6,
                        color: item.status == DownloadStatus.paused
                            ? Colors.amber
                            : Colors.redAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "${(displayProgress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          item.totalBytes > 0
                              ? "${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}"
                              : _formatBytes(item.downloadedBytes),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.status == DownloadStatus.downloading)
                          Expanded(
                            child: _miniButton(
                              text: "إيقاف",
                              icon: Icons.pause,
                              color: Colors.amber,
                              onTap: () => provider.pauseDownload(item.id),
                            ),
                          ),
                        if (item.status == DownloadStatus.paused) ...[
                          Expanded(
                            flex: 3,
                            child: _miniButton(
                              text: "استكمال",
                              icon: Icons.play_arrow,
                              color: Colors.green,
                              onTap: () => provider.resumeDownload(item.id),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => provider.refreshDownloadLink(context, item.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.link, color: Colors.blueAccent, size: 16),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _confirmDelete(context, provider, item.id),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                          ),
                        )
                      ],
                    )
                  ]
                  else if (item.status == DownloadStatus.pending) ...[
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 4),
                        const Text("انتظار...", style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        const Spacer(),
                        if (isInitializing)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                        else
                          InkWell(
                            onTap: () => _startPendingDownload(context, item, provider),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.download_rounded, color: Colors.redAccent, size: 20),
                            ),
                          ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _confirmDelete(context, provider, item.id),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                          ),
                        )
                      ],
                    )
                  ]
                  else if (isCompleted) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatBytes(item.totalBytes > 0 ? item.totalBytes : item.downloadedBytes),
                              style: const TextStyle(fontSize: 9, color: Colors.white60),
                            ),
                          ),
                          const Spacer(),
                          if (!isExported)
                            _miniButton(
                              text: "حفظ",
                              icon: Icons.save_alt_rounded,
                              color: Colors.blueAccent,
                              onTap: () async {
                                bool hasPermission = await _checkStoragePermission();
                                if (!hasPermission) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("مطلوب إذن التخزين لحفظ الملف"), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                BuildContext? dialogContext;

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    dialogContext = context;
                                    return Dialog(
                                      backgroundColor: const Color(0xFF1F1F1F),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "جاري الحفظ في الاستوديو...",
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 20),
                                            const LinearProgressIndicator(
                                              backgroundColor: Colors.white10,
                                              color: Colors.redAccent,
                                              minHeight: 5,
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              "يرجى الانتظار، لا تغلق التطبيق",
                                              style: TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );

                                bool success = await provider.exportVideoToGallery(item.id);

                                if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                  Navigator.pop(dialogContext!);
                                }

                                if (mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 10),
                                            Expanded(child: Text("تم حفظ الفيديو بنجاح في مجلد Downloads/CimaBox")),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("فشل حفظ الفيديو، تأكد من المساحة أو الصلاحيات"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            )
                          else
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            (item.exportedPath != null)? Row(
                              children: [
                                SizedBox(width: 4),
                                InkWell(
                                  onTap: () => OpenFile.open(item.exportedPath),
                                  child: Icon(Icons.queue_play_next_rounded , color: Colors.blueAccent,),
                                ),
                              ],
                            ) : SizedBox(),

                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _confirmDelete(context, provider, item.id),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                            ),
                          )
                        ],
                      )
                    ]
                    else if (item.status == DownloadStatus.failed) ...[
                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 4),
                            const Text("فشل", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            InkWell(
                              onTap: () => _confirmDelete(context, provider, item.id),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _miniButton(
                                text: "تحديث الرابط",
                                icon: Icons.link,
                                color: Colors.blueAccent,
                                onTap: () => provider.refreshDownloadLink(context, item.id),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: _miniButton(
                                text: "إعادة",
                                icon: Icons.refresh,
                                color: Colors.white,
                                onTap: () => provider.resumeDownload(item.id),
                              ),
                            ),
                          ],
                        )
                      ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _miniButton(
      {required String text,
        required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}