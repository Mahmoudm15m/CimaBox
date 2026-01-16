import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../models/details_model.dart';
import '../models/server_model.dart';
import '../screens/video_player_screen.dart';
import '../utils/video_scraper.dart';
import 'downloads_provider.dart';

class DetailsProvider with ChangeNotifier {
  DetailsModel? details;
  bool isLoading = false;
  String? error;
  int selectedSeasonIndex = 0;

  bool isServersLoading = false;
  Map<String, List<ServerItem>>? availableQualities;

  final Dio _dio = Dio();
  final String _detailsUrl = 'https://ar.fastmovies.site/arb/details';
  final String _serversUrl = 'https://ar.fastmovies.site/arb/servers';

  Future<void> fetchDetails(String link) async {
    isLoading = true;
    error = null;
    selectedSeasonIndex = 0;
    availableQualities = null;
    notifyListeners();
    try {
      final response = await _dio.post(
        _detailsUrl,
        data: {'url': link},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        details = DetailsModel.fromJson(response.data);
      } else {
        error = 'فشل التحميل: ${response.statusCode}';
      }
    } catch (e) {
      error = 'حدث خطأ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void changeSeason(int index) {
    selectedSeasonIndex = index;
    notifyListeners();
  }

  Future<Map<String, List<ServerItem>>?> getServersOnly(String contentUrl) async {
    try {
      final response = await _dio.post(
        _serversUrl,
        data: {'url': contentUrl},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = response.data;
        Map<String, List<ServerItem>> result = {};

        data.forEach((quality, serversList) {
          if (serversList is List && serversList.isNotEmpty) {
            result[quality] = serversList
                .map((e) => ServerItem.fromJson(e))
                .toList();
          }
        });
        return result.isNotEmpty ? result : null;
      }
    } catch (e) {
      print("Error fetching servers: $e");
    }
    return null;
  }

  Future<void> fetchServers(String contentUrl, BuildContext context) async {
    isServersLoading = true;
    notifyListeners();

    try {
      final qualities = await getServersOnly(contentUrl);

      if (qualities != null) {
        availableQualities = qualities;
        if (context.mounted) {
          _showQualitySelector(context, contentUrl);
        }
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد سيرفرات متاحة')));
      }
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      isServersLoading = false;
      notifyListeners();
    }
  }

  String _cleanUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/$'), ''); // حذف الشرطة المائلة في الاخر
  }

  void _showQualitySelector(BuildContext context, String currentUrl) {
    int targetSeasonIdx = 0;
    int targetEpisodeIdx = 0;
    String cleanCurrentUrl = _cleanUrl(currentUrl);

    if (details != null && details!.seasons.isNotEmpty) {
      bool found = false;
      for (int s = 0; s < details!.seasons.length; s++) {
        final season = details!.seasons[s];
        for (int e = 0; e < season.episodes.length; e++) {
          if (_cleanUrl(season.episodes[e].link) == cleanCurrentUrl) {
            targetSeasonIdx = s;
            targetEpisodeIdx = e;
            found = true;
            break;
          }
        }
        if (found) break;
      }
      if (!found) {
        targetSeasonIdx = selectedSeasonIndex;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("الجودات المتاحة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: availableQualities!.keys.map((quality) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10)
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            radius: 18,
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          ),
                          title: Text(
                              "${quality}p",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  qualities: availableQualities!,
                                  startQuality: quality,
                                  detailsModel: details,
                                  currentSeasonIndex: targetSeasonIdx,
                                  currentEpisodeIndex: targetEpisodeIdx,
                                  sourceLink: cleanCurrentUrl,
                                ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.file_download_outlined, color: Colors.white70),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Provider.of<DetailsProvider>(context, listen: false).downloadQuality(context, quality);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> downloadQuality(BuildContext context, String quality) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    try {
      List<ServerItem> servers = List.from(availableQualities![quality]!);

      servers.sort((a, b) {
        bool aIsDirect = a.link.contains('reviewrate') || a.link.contains('savefiles');
        bool bIsDirect = b.link.contains('reviewrate') || b.link.contains('savefiles');

        bool aIsHls = a.link.contains('vidmoly') || a.link.contains('up4fun');
        bool bIsHls = b.link.contains('vidmoly') || b.link.contains('up4fun');

        if (aIsDirect && !bIsDirect) return -1;
        if (!aIsDirect && bIsDirect) return 1;

        if (aIsHls && !bIsHls) return 1;
        if (!aIsHls && bIsHls) return -1;

        return 0;
      });

      Map<String, dynamic>? directLinkData;

      for (var server in servers) {
        directLinkData = await _tryExtract(server.link);
        if (directLinkData != null) break;
      }

      if (context.mounted) Navigator.pop(context);

      if (directLinkData != null && context.mounted) {
        String finalUrl = directLinkData['url'];

        Map<String, String> headers = {};
        if (directLinkData['headers'] != null) {
          directLinkData['headers'].forEach((k, v) {
            headers[k.toString()] = v.toString();
          });
        }

        Provider.of<DownloadsProvider>(context, listen: false).startDownload(
          finalUrl,
          details?.title ?? "فيديو بدون عنوان",
          details?.poster ?? "",
          headers: headers,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("بدأ تحميل جودة $quality", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("⚠️ يرجى عدم إغلاق التطبيق تماماً أثناء التحميل لضمان الاستمرار.", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );

      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("فشل استخراج رابط تحميل لهذه الجودة")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
      }
    }
  }

  Future<Map<String, dynamic>?> _tryExtract(String url) async {
    if (url.contains('bysezejataos') || url.contains('g9r6')) {
      return await VideoScraper.bysezejataosDirect(url);
    } else if (url.contains('savefiles')) {
      return await VideoScraper.savefilesDirect(url);
    } else if (url.contains('reviewrate')) {
      return await VideoScraper.reviewrateDirect(url);
    } else if (url.contains('up4fun')) {
      return await VideoScraper.up4funDirect(url);
    } else if (url.contains('vidmoly')) {
      return await VideoScraper.vidmolyDirect(url);
    } else if (url.contains('dood')) {
      return await VideoScraper.doodstreamDirect(url);
    }
    return null;
  }
}