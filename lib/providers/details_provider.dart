import 'package:cima_box/services/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/details_model.dart';
import '../models/server_model.dart';
import '../screens/video_player_screen.dart';
import '../services/dynamic_scraper_service.dart';
import '../utils/video_scraper.dart';
import 'downloads_provider.dart';
import '../services/api_service.dart';
import '../screens/downloads_screen.dart';
import 'settings_provider.dart';
import '../providers/auth_provider.dart';

class DetailsProvider with ChangeNotifier {
  DetailsModel? details;
  bool isLoading = false;
  String? error;
  int selectedSeasonIndex = 0;

  String? loadingAction;
  Map<String, List<ServerItem>>? availableQualities;

  final String _detailsUrl = 'https://ar.fastmovies.site/arb/details';
  final String _serversUrl = 'https://ar.fastmovies.site/arb/servers';

  Future<void> fetchDetails(int id, {bool sortDescending = true}) async {
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
        _sortSeasonsAndEpisodes(sortDescending);
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

  void _sortSeasonsAndEpisodes(bool descending) {
    if (details == null) return;

    if (details!.seasons.isNotEmpty) {
      details!.seasons.sort((a, b) {
        int n1 = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int n2 = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return descending ? n2.compareTo(n1) : n1.compareTo(n2);
      });

      for (var season in details!.seasons) {
        season.episodes.sort((a, b) {
          int n1 = int.tryParse(a.number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          int n2 = int.tryParse(b.number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return descending ? n2.compareTo(n1) : n1.compareTo(n2);
        });
      }
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

  Future<void> handleAction(BuildContext context, int contentId, {required bool isPlay, bool isEpisode = false, String? title, String? poster}) async {
    loadingAction = isPlay ? 'play' : 'download';
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
          final settings = Provider.of<SettingsProvider>(context, listen: false);

          if (isPlay) {
            _autoPlay(context, qualities, settings.preferredWatchQuality, contentId, isEpisode, title, poster);
          } else {
            _autoDownload(context, qualities, settings.preferredDownloadQuality, contentId);
          }
        }
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد سيرفرات متاحة')));
      }
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      loadingAction = null;
      notifyListeners();
    }
  }

  List<String> _getPriorityList(String preferred, bool isPremium, {bool isDownload = false}) {
    List<String> order;
    if (preferred == '1080') {
      order = ['1080', '720', '480', '360', '240'];
    } else if (preferred == '720') {
      order = ['720', '1080', '480', '360', '240'];
    } else if (preferred == '480') {
      order = ['480', '360', '720', '240', '1080'];
    } else {
      order = ['360', '240', '480', '720', '1080'];
    }

    if (isDownload && !isPremium) {
      order.remove('1080');
    }

    return order;
  }

  Future<void> _autoDownload(BuildContext context, Map<String, List<ServerItem>> qualities, String prefQuality, int contentId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isPremium) {
      await AdManager.showInterstitialAd(context);
    }

    List<String> priorities = _getPriorityList(prefQuality, auth.isPremium, isDownload: true);

    bool started = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    for (var q in priorities) {
      if (qualities.containsKey(q)) {
        var linkData = await fetchLinkForDownload(contentId, q, context);

        if (linkData != null) {
          if (context.mounted) Navigator.pop(context);

          if (context.mounted) {
            downloadQuality(context, q, contentId, qualitiesMap: qualities, preFetchedData: linkData, showLoading: false);

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF333333),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
                content: Row(
                  children: [
                    const Icon(Icons.downloading, color: Colors.greenAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("جاري تحميل $q", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text("يرجى عدم إغلاق التطبيق", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: 'عرض',
                  textColor: Colors.redAccent,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DownloadsScreen()),
                    );
                  },
                ),
              ),
            );
          }
          started = true;
          break;
        }
      }
    }

    if (!started && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل استخراج رابط التحميل لجميع الجودات المتاحة")));
    }
  }

  Future<void> _autoPlay(BuildContext context, Map<String, List<ServerItem>> qualities, String prefQuality, int contentId, bool isEpisode, String? title, String? poster) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isPremium) {
      await AdManager.showInterstitialAd(context);
    }

    List<String> priorities = _getPriorityList(prefQuality, auth.isPremium, isDownload: false);
    String targetQuality = priorities.first;
    bool foundWorking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    for (var q in priorities) {
      if (qualities.containsKey(q)) {
        var linkData = await fetchLinkForDownload(contentId, q, context);
        if (linkData != null) {
          targetQuality = q;
          foundWorking = true;
          break;
        }
      }
    }

    if (context.mounted) Navigator.pop(context);

    if (!foundWorking) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("عذراً، لا توجد سيرفرات تعمل حالياً")));
      return;
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
        cast: [],
      );
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListenableProvider.value(
            value: this,
            child: VideoPlayerScreen(
              qualities: qualities,
              startQuality: targetQuality,
              detailsModel: finalDetails,
              currentSeasonIndex: selectedSeasonIndex,
              currentEpisodeIndex: isEpisode ? _getEpisodeIndex(contentId) : 0,
              sourceId: contentId,
            ),
          ),
        ),
      );

      if (targetQuality != prefQuality) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("تم التشغيل بجودة $targetQuality لعدم توفر $prefQuality"),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  int _getEpisodeIndex(int episodeId) {
    if (details == null || details!.seasons.isEmpty) return 0;
    try {
      return details!.seasons[selectedSeasonIndex].episodes.indexWhere((e) => e.id == episodeId);
    } catch (_) { return 0; }
  }

  Future<void> downloadQuality(BuildContext context, String quality, int contentId, {Map<String, List<ServerItem>>? qualitiesMap, bool autoStart = true, bool showLoading = true, Map<String, dynamic>? preFetchedData}) async {
    final available = qualitiesMap ?? availableQualities;
    if (available == null || !available.containsKey(quality)) return;

    if (showLoading) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    try {
      List<ServerItem> servers = List.from(available[quality]!);

      servers.sort((a, b) {
        bool aIsDirect = a.link.contains('reviewrate') || a.link.contains('savefiles');
        bool bIsDirect = b.link.contains('reviewrate') || b.link.contains('savefiles');
        if (aIsDirect && !bIsDirect) return -1;
        if (!aIsDirect && bIsDirect) return 1;
        return 0;
      });

      Map<String, dynamic>? directLinkData = preFetchedData;

      if (directLinkData == null) {
        for (var server in servers) {
          directLinkData = await _tryExtract(server.link);
          if (directLinkData != null) break;
        }

        if (directLinkData == null) {
          DynamicScraperService? dynamicScraper;
          try {
            dynamicScraper = Provider.of<DynamicScraperService>(context, listen: false);
          } catch (e) {}

          if (dynamicScraper != null) {
            for (var server in servers) {
              try {
                directLinkData = await dynamicScraper.extractLink(server.link);
                if (directLinkData != null) break;
              } catch (e) {}
            }
          }
        }
      }

      if (showLoading && context.mounted) Navigator.pop(context);

      if (directLinkData != null && context.mounted) {
        String finalUrl = directLinkData['url'];
        Map<String, String> headers = {};
        if (directLinkData['headers'] != null) {
          if (directLinkData['headers'] is Map) {
            directLinkData['headers'].forEach((k, v) {
              headers[k.toString()] = v.toString();
            });
          }
        }

        String fileNameBase = "";
        String mainTitle = details?.title ?? "video";
        mainTitle = mainTitle.trim().replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '').replaceAll(' ', '-');

        if (details != null && details!.type == 'series') {
          String sNum = "01";
          String eNum = "01";

          bool found = false;
          for(int s=0; s<details!.seasons.length; s++) {
            int epIdx = details!.seasons[s].episodes.indexWhere((ep) => ep.id == contentId);
            if (epIdx != -1) {
              sNum = (s + 1).toString().padLeft(2, '0');
              eNum = details!.seasons[s].episodes[epIdx].number.padLeft(2, '0');
              found = true;
              break;
            }
          }
          fileNameBase = "$mainTitle-SE$sNum-EP$eNum-${quality}p";
        } else {
          fileNameBase = "$mainTitle-${quality}p";
        }

        Provider.of<DownloadsProvider>(context, listen: false).startDownload(
          finalUrl,
          fileNameBase,
          details?.poster ?? "",
          headers: headers,
          fileName: fileNameBase,
          autoStart: autoStart,
        );

        if (autoStart && showLoading) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF333333),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(Icons.downloading, color: Colors.greenAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("جاري تحميل $quality", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        const Text("يرجى عدم إغلاق التطبيق", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'عرض',
                textColor: Colors.redAccent,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DownloadsScreen()),
                  );
                },
              ),
            ),
          );
        }

      } else {
        if (showLoading && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("فشل استخراج رابط تحميل لهذه الجودة")),
          );
        }
      }
    } catch (e) {
      if (showLoading && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
      }
    }
  }

  void downloadSeason(BuildContext context) {
    if (details == null || details!.seasons.isEmpty) return;

    final episodes = details!.seasons[selectedSeasonIndex].episodes;
    if (episodes.isEmpty) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    String prefQuality = settings.preferredDownloadQuality;

    final downloadsProvider = Provider.of<DownloadsProvider>(context, listen: false);

    String mainTitle = details?.title ?? "مسلسل";
    mainTitle = mainTitle.trim();
    String mainTitleFile = mainTitle.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '').replaceAll(' ', '-');
    String sNum = (selectedSeasonIndex + 1).toString().padLeft(2, '0');

    final reversedEpisodes = episodes.reversed.toList();

    for (var episode in reversedEpisodes) {
      String readableTitle = "$mainTitle : الحلقة ${episode.number}";
      String eNum = episode.number.padLeft(2, '0');
      String fileNameLabel = "$mainTitleFile-SE$sNum-EP$eNum-${prefQuality}p.mp4";

      downloadsProvider.addPendingDownload(
          contentId: episode.id,
          quality: prefQuality,
          title: readableTitle,
          fileNameLabel: fileNameLabel,
          image: details?.poster ?? ""
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("تم إضافة ${episodes.length} حلقات إلى التنزيلات (في الانتظار)"),
          action: SnackBarAction(
            label: 'عرض',
            textColor: Colors.redAccent,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const DownloadsScreen()));
            },
          ),
        )
    );
  }

  String _resolveBestQuality(Map<String, List<ServerItem>> qualities, String pref) {
    if (qualities.containsKey(pref)) return pref;

    List<String> priority;
    if (pref == '1080') priority = ['1080', '720', '480', '360'];
    else if (pref == '720') priority = ['720', '1080', '480', '360'];
    else priority = ['480', '360', '720', '1080'];

    for (var q in priority) {
      if (qualities.containsKey(q)) return q;
    }
    return qualities.keys.first;
  }

  Future<Map<String, dynamic>?> fetchLinkForDownload(int contentId, String quality, BuildContext context) async {
    try {
      final qualities = await getServersOnly(contentId);
      if (qualities == null) return null;

      String targetQuality = _resolveBestQuality(qualities, quality);
      if (!qualities.containsKey(targetQuality)) return null;

      List<ServerItem> servers = List.from(qualities[targetQuality]!);

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

      if (directLinkData == null) {
        DynamicScraperService? dynamicScraper;
        try {
          dynamicScraper = Provider.of<DynamicScraperService>(context, listen: false);
        } catch (e) {}

        if (dynamicScraper != null) {
          for (var server in servers) {
            try {
              directLinkData = await dynamicScraper.extractLink(server.link);
              if (directLinkData != null) break;
            } catch (e) {}
          }
        }
      }

      return directLinkData;

    } catch (e) {
      return null;
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