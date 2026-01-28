import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> _startPendingDownload(BuildContext context, DownloadItem item, DownloadsProvider provider) async {
    // التحقق من أن معرف المحتوى موجود
    if (item.contentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ: معرف المحتوى مفقود")));
      return;
    }

    setState(() {
      _initializingId = item.id;
    });

    try {
      final detailsProvider = Provider.of<DetailsProvider>(context, listen: false);

      final linkData = await detailsProvider.fetchLinkForDownload(item.contentId!, item.quality, context);

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل جلب رابط التحميل")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _initializingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التنزيلات', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.white),
            tooltip: "فتح مجلد التنزيلات",
            onPressed: () {
              OpenFile.open("/storage/emulated/0/Download/CimaBox");
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Consumer<DownloadsProvider>(
        builder: (context, provider, child) {
          if (provider.downloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_download_outlined, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 10),
                  Text("لا توجد تنزيلات حالياً", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.downloads.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = provider.downloads[index];
              return _buildDownloadItem(context, item, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadItem(BuildContext context, DownloadItem item, DownloadsProvider provider) {
    bool isInitializing = _initializingId == item.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 110,
              child: (item.image.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: Colors.grey[900]),
                errorWidget: (c, u, e) => const Icon(Icons.error),
              )
                  : Container(
                color: Colors.grey[900],
                child: const Icon(Icons.video_library, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (item.fileNameLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.fileNameLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
                const SizedBox(height: 10),

                if (item.status == DownloadStatus.downloading) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: item.progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.grey[800],
                        color: Colors.redAccent,
                        minHeight: 4,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(item.progress * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        item.totalBytes > 0
                            ? "${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}"
                            : _formatBytes(item.downloadedBytes),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "يرجى عدم إغلاق التطبيق أثناء التحميل",
                    style: TextStyle(color: Colors.amber, fontSize: 10),
                  ),

                ] else if (item.status == DownloadStatus.paused || item.status == DownloadStatus.pending) ...[
                  Row(
                    children: [
                      const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 5),
                      const Text("في الانتظار", style: TextStyle(color: Colors.amber, fontSize: 12)),
                      const Spacer(),
                      if (isInitializing)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        IconButton(
                          onPressed: () {
                            if (item.url.isEmpty) {
                              _startPendingDownload(context, item, provider);
                            } else {
                              provider.resumeDownload(item.id);
                            }
                          },
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          tooltip: "بدء التحميل",
                        )
                    ],
                  ),
                ] else if (item.status == DownloadStatus.completed) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 5),
                      const Text("تم التحميل", style: TextStyle(color: Colors.green, fontSize: 12)),
                      const Spacer(),
                      Text(_formatBytes(item.totalBytes), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ] else ...[
                  const Text("فشل التحميل", style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),

          Column(
            children: [
              if (item.status == DownloadStatus.completed)
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  onPressed: () => OpenFile.open(item.savedPath),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.deleteDownload(item.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}