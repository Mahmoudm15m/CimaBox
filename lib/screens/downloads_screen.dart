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
            style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded,color: Colors.white,),
            onPressed: () {
              OpenFile.open("/storage/emulated/0/Download/CimaBox");
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F1F1F),
            const Color(0xFF181818),
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
                  width: 120,
                  height: 120,
                  child: CachedNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: Colors.grey[900]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[850],
                      child: const Icon(Icons.movie,
                          color: Colors.white24, size: 35),
                    ),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  color: Colors.black.withOpacity(0.35),
                ),
                if (isCompleted)
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
                          size: 34, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  if (item.fileNameLabel.isNotEmpty)
                    Text(
                      item.fileNameLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                  const SizedBox(height: 12),
                  if (item.status == DownloadStatus.downloading ||
                      item.status == DownloadStatus.paused) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: displayProgress,
                        minHeight: 7,
                        color: item.status == DownloadStatus.paused
                            ? Colors.amber
                            : Colors.redAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          "${(displayProgress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          item.totalBytes > 0
                              ? "${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}"
                              : _formatBytes(item.downloadedBytes),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (item.status == DownloadStatus.downloading)
                          _miniButton(
                            text: "إيقاف",
                            icon: Icons.pause,
                            color: Colors.amber,
                            onTap: () => provider.pauseDownload(item.id),
                          ),
                        if (item.status == DownloadStatus.paused)
                          _miniButton(
                            text: "استكمال",
                            icon: Icons.play_arrow,
                            color: Colors.green,
                            onTap: () => provider.resumeDownload(item.id),
                          ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white38),
                          onPressed: () =>
                              _confirmDelete(context, provider, item.id),
                        )
                      ],
                    )
                  ] else if (item.status == DownloadStatus.pending) ...[
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 6),
                        const Text("في الانتظار...",
                            style: TextStyle(
                                color: Colors.orangeAccent, fontSize: 12)),
                        const Spacer(),
                        if (isInitializing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.download_rounded,
                                color: Colors.white),
                            onPressed: () =>
                                _startPendingDownload(context, item, provider),
                          )
                      ],
                    )
                  ] else if (isCompleted) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatBytes(item.totalBytes > 0
                                ? item.totalBytes
                                : item.downloadedBytes),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white60),
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
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("يجب منح إذن الوصول للذاكرة لحفظ الفيديو"),
                                  backgroundColor: Colors.red,
                                ));
                                return;
                              }

                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("جاري التصدير للمعرض..."),
                                    duration: Duration(seconds: 1),
                                  ),
                                );

                                bool success = await provider.exportVideoToGallery(item.id);

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text("تم الحفظ في المعرض بنجاح"),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text("فشل التصدير"),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.orange,
                                    content: Text(e.toString()),
                                  ),
                                );
                              }
                            },
                          )
                        else
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white38),
                          onPressed: () =>
                              _confirmDelete(context, provider, item.id),
                        )
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}