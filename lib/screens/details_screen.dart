import 'package:cima_box/services/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/details_provider.dart';
import '../models/details_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watch_history_provider.dart';
import 'category_screen.dart';
import 'actor_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';

class DetailsScreen extends StatelessWidget {
  final int id;
  const DetailsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DetailsProvider(),
      child: _DetailsContent(id: id),
    );
  }
}

class _DetailsContent extends StatefulWidget {
  final int id;
  const _DetailsContent({required this.id});

  @override
  State<_DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<_DetailsContent> {
  int? _loadingEpisodeId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final isDescending = Provider.of<SettingsProvider>(context, listen: false).sortDescending;
      Provider.of<DetailsProvider>(context, listen: false).fetchDetails(widget.id, sortDescending: isDescending);
    });

    final isPremium = Provider.of<AuthProvider>(context, listen: false).isPremium;
    if (!isPremium) {
      AdManager.initializeAds(context);
    }
  }

  void _showPremiumDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.workspace_premium, size: 60, color: Colors.amber),
              const SizedBox(height: 15),
              const Text(
                "ميزة للمشتركين فقط",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "تحميل الموسم بالكامل متاح فقط لعضوية Premium",
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final Uri url = Uri.parse('https://t.me/M2HM00D');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل فتح الرابط")));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("اشترك الآن عبر تيليجرام", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeasonDownloadBtn(DetailsProvider provider) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        bool isLocked = !auth.isPremium;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 15),
          child: OutlinedButton.icon(
            onPressed: () {
              if (isLocked) {
                _showPremiumDialog();
              } else {
                provider.downloadSeason(context);
              }
            },
            icon: Icon(
                isLocked ? Icons.lock : Icons.playlist_add_check,
                color: isLocked ? Colors.grey : Colors.white70
            ),
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "تحميل الموسم بالكامل",
                  style: TextStyle(color: isLocked ? Colors.grey : Colors.white70),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                ]
              ],
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isLocked ? Colors.white10 : Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      },
    );
  }

  void _navigateToNewPage(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(id: id),
      ),
    );
  }

  void _navigateToCategory(String title, int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryScreen(title: title, id: id),
      ),
    );
  }

  void _navigateToActor(int id, String name, String image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActorScreen(id: id, name: name, imageUrl: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Consumer<DetailsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.white)));
          }
          if (provider.details == null) return const SizedBox();

          final data = provider.details!;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 450,
                pinned: true,
                backgroundColor: const Color(0xFF121212),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: data.poster,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF121212).withOpacity(0.2),
                              const Color(0xFF121212).withOpacity(0.9),
                              const Color(0xFF121212),
                            ],
                            stops: const [0.0, 0.5, 0.85, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 20,
                        right: 20,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                shadows: [BoxShadow(blurRadius: 20, color: Colors.black)],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoGrid(data.info),
                      const SizedBox(height: 15),
                      _buildGenresRow(data.info),
                      const SizedBox(height: 25),
                      _buildActionButtons(provider, data, widget.id),
                      const SizedBox(height: 25),

                      Text(
                        data.story,
                        style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.7,
                            fontWeight: FontWeight.w400
                        ),
                      ),

                      const SizedBox(height: 30),

                      if (data.cast.isNotEmpty) ...[
                        const Text(
                          "طاقم العمل",
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildCastList(data.cast),
                        const SizedBox(height: 30),
                      ],

                      if (data.collection.isNotEmpty) ...[
                        const Text(
                          "سلسلة العمل",
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildHorizontalPosterList(data.collection),
                        const SizedBox(height: 30),
                      ],

                      if (data.seasons.isNotEmpty) ...[
                        _buildSeasonsDropdown(provider, data.seasons),
                        const SizedBox(height: 15),

                        if (data.type == 'series')
                            _buildSeasonDownloadBtn(provider),

                        _buildEpisodesHorizontalList(data.seasons[provider.selectedSeasonIndex].episodes, data.poster, provider),
                        const SizedBox(height: 30),
                      ],

                      if (data.related.isNotEmpty) ...[
                        const Text(
                          "أعمال مشابهة",
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildRelatedGrid(data.related),
                      ],

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> info) {
    List<Widget> items = [];

    void addItem(String key, IconData icon, Color color) {
      if (info.containsKey(key) && info[key] is List && (info[key] as List).isNotEmpty) {
        var item = info[key][0];
        if (item is Map && item.containsKey('text') && item.containsKey('id')) {
          items.add(
              InkWell(
                onTap: () => _navigateToCategory(item['text'].toString(), item['id'] is int ? item['id'] : int.tryParse(item['id'].toString()) ?? 0),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        item['text'].toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
          );
        }
      }
    }

    addItem('سنة_العرض_', Icons.calendar_today, Colors.amber);
    addItem('جودة_العرض_', Icons.high_quality, Colors.redAccent);
    addItem('بلد_العرض_', Icons.public, Colors.blueAccent);
    addItem('لغة_العرض_', Icons.translate, Colors.greenAccent);

    if (items.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items,
    );
  }

  Widget _buildGenresRow(Map<String, dynamic> info) {
    List<Widget> genres = [];
    final keys = ['نوع_العرض_', 'تصنيف_العرض_'];

    for (var key in keys) {
      if (info.containsKey(key) && info[key] is List) {
        for (var item in info[key]) {
          if (item is Map && item.containsKey('text') && item.containsKey('id')) {
            if (genres.isNotEmpty) {
              genres.add(const Text("  •  ", style: TextStyle(color: Colors.grey, fontSize: 12)));
            }
            genres.add(
                InkWell(
                  onTap: () => _navigateToCategory(
                      item['text'].toString(),
                      item['id'] is int ? item['id'] : int.tryParse(item['id'].toString()) ?? 0
                  ),
                  child: Text(
                    item['text'].toString(),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.redAccent,
                      decorationThickness: 1.5,
                    ),
                  ),
                )
            );
          }
        }
      }
    }

    if (genres.isEmpty) return const SizedBox();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: genres,
    );
  }

  Widget _buildActionButtons(DetailsProvider provider, DetailsModel data, int id) {
    bool isSeries = data.type == 'series';

    return Column(
      children: [
        Row(
          children: [
            if (!isSeries)
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: (provider.loadingAction != null) ? null : () => provider.handleAction(context, id, isPlay: true),
                  icon: (provider.loadingAction == 'play')
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("مشاهدة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                ),
              ),
            if (!isSeries)
              const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Consumer<FavoritesProvider>(
                builder: (context, favProvider, _) {
                  final isFav = favProvider.isFavorite(id);
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: IconButton(
                      onPressed: () => favProvider.toggleFavorite(data.title, data.poster, id),
                      icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (!isSeries)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (provider.loadingAction != null) ? null : () => provider.handleAction(context, id, isPlay: false),
              icon: (provider.loadingAction == 'download')
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2))
                  : const Icon(Icons.download_rounded, color: Colors.white70),
              label: const Text("تحميل", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "اختر الحلقة من الأسفل للمشاهدة أو التحميل",
                    style: TextStyle(color: Colors.amber[100], fontSize: 12),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCastList(List<CastItem> cast) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final actor = cast[index];
          return GestureDetector(
            onTap: () => _navigateToActor(actor.id, actor.name, actor.image),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12, width: 1),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(actor.image),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    actor.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                if (actor.role.isNotEmpty && actor.role != "ممثل")
                  SizedBox(
                    width: 80,
                    child: Text(
                      actor.role,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeasonsDropdown(DetailsProvider provider, List<Season> seasons) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: provider.selectedSeasonIndex,
          dropdownColor: const Color(0xFF2B2B2B),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          items: List.generate(seasons.length, (index) {
            return DropdownMenuItem(
              value: index,
              child: Text(seasons[index].name),
            );
          }),
          onChanged: (val) {
            if (val != null) provider.changeSeason(val);
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesHorizontalList(List<Episode> episodes, String posterUrl, DetailsProvider provider) {
    return Consumer<WatchHistoryProvider>(
      builder: (context, historyProvider, _) {
        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: episodes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final episode = episodes[index];
              final bool isLoading = _loadingEpisodeId == episode.id;

              double progress = 0.0;
              bool hasHistory = false;

              try {
                final historyItem = historyProvider?.history.firstWhere((item) => item.id == episode.id);
                if (historyItem!.durationMs > 0) {
                  progress = historyItem.positionMs / historyItem.durationMs;
                  hasHistory = true;
                }
              } catch (_) {}

              return Container(
                width: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              color: Colors.black.withOpacity(0.3),
                              colorBlendMode: BlendMode.darken,
                            ),
                          ),
                          Center(
                            child: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                : Icon(Icons.play_circle_fill, color: Colors.white.withOpacity(0.9), size: 35),
                          ),

                          if (hasHistory)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white24,
                                color: Colors.redAccent,
                                minHeight: 3,
                              ),
                            ),

                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isLoading ? null : () async {
                                setState(() => _loadingEpisodeId = episode.id);
                                await provider.handleAction(context, episode.id, isPlay: true, isEpisode: true);
                                if(mounted) setState(() => _loadingEpisodeId = null);
                              },
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF252525),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "حلقة ${episode.number}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isLoading ? null : () async {
                                setState(() => _loadingEpisodeId = episode.id);
                                await provider.handleAction(context, episode.id, isPlay: false, isEpisode: true);
                                if(mounted) setState(() => _loadingEpisodeId = null);
                              },
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.download_rounded, color: Colors.redAccent, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHorizontalPosterList(List<RelatedItem> items) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _navigateToNewPage(item.id),
            child: SizedBox(
              width: 100,
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[900]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRelatedGrid(List<RelatedItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _navigateToNewPage(item.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }
}