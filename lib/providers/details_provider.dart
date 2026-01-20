import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/details_model.dart';
import '../models/server_model.dart';
import '../screens/video_player_screen.dart';
import '../utils/video_scraper.dart';
import 'downloads_provider.dart';
import '../services/api_service.dart';

class DetailsProvider with ChangeNotifier {
  DetailsModel? details;
  bool isLoading = false;
  String? error;
  int selectedSeasonIndex = 0;

  bool isServersLoading = false;
  Map<String, List<ServerItem>>? availableQualities;

  final String _detailsUrl = 'https://ar.fastmovies.site/arb/details';
  final String _serversUrl = 'https://ar.fastmovies.site/arb/servers';

  Future<void> fetchDetails(int id) async {
    isLoading = true;
    error = null;
    selectedSeasonIndex = 0;
    availableQualities = null;
    notifyListeners();
    try {
      final data = await ApiService.post(
        _detailsUrl,
        {'id': id},
      );

      if (data != null) {
        details = DetailsModel.fromJson(data);
      } else {
        error = 'فشل التحميل';
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

  Future<Map<String, List<ServerItem>>?> getServersOnly(int contentId) async {
    try {
      final data = await ApiService.post(
        _serversUrl,
        {'id': contentId},
      );

      if (data != null) {
        Map<String, dynamic> jsonResponse = data;
        Map<String, List<ServerItem>> result = {};

        jsonResponse.forEach((quality, serversList) {
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

  Future<void> fetchServers(int contentId, BuildContext context, {bool isEpisode = false, String? title, String? poster}) async {
    isServersLoading = true;
    notifyListeners();

    try {
      if (details == null) {
        try {
          await fetchDetails(contentId);
        } catch (e) {}
      }

      final qualities = await getServersOnly(contentId);

      if (qualities != null) {
        availableQualities = qualities;
        if (context.mounted) {
          _showQualitySelector(context, contentId, isEpisode: isEpisode, title: title, poster: poster);
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

  void _showQualitySelector(BuildContext context, int contentId, {bool isEpisode = false, String? title, String? poster}) {
    int targetSeasonIdx = 0;
    int targetEpisodeIdx = 0;

    if (details != null && details!.seasons.isNotEmpty) {
      bool found = false;
      for(int s = 0; s < details!.seasons.length; s++) {
        for(int e = 0; e < details!.seasons[s].episodes.length; e++) {
          if (details!.seasons[s].episodes[e].id == contentId) {
            targetSeasonIdx = s;
            targetEpisodeIdx = e;
            selectedSeasonIndex = s;
            found = true;
            break;
          }
        }
        if (found) break;
      }
    }

    DetailsModel? finalDetails = details;
    if (finalDetails == null && title != null) {
      finalDetails = DetailsModel(
        type: 'video',
        title: title,
        poster: poster ?? '',
        story: '',
        info: {},
        seasons: [],
        related: [],
        collection: [],
      );
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
                                builder: (context) => ListenableProvider.value(
                                  value: this,
                                  child: VideoPlayerScreen(
                                    qualities: availableQualities!,
                                    startQuality: quality,
                                    detailsModel: finalDetails,
                                    currentSeasonIndex: targetSeasonIdx,
                                    currentEpisodeIndex: targetEpisodeIdx,
                                    sourceId: contentId,
                                  ),
                                ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.file_download_outlined, color: Colors.white70),
                            onPressed: () {
                              Navigator.pop(ctx);
                              downloadQuality(context, quality);
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
        if (aIsDirect && !bIsDirect) return -1;
        if (!aIsDirect && bIsDirect) return 1;
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