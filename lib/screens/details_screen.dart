import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/details_provider.dart';
import '../models/details_model.dart';
import '../providers/favorites_provider.dart'; // تأكد إن المسار صح

class DetailsScreen extends StatelessWidget {
  final String url;
  const DetailsScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return _DetailsContent(url: url);
  }
}

class _DetailsContent extends StatefulWidget {
  final String url;
  const _DetailsContent({required this.url});

  @override
  State<_DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<_DetailsContent> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<DetailsProvider>(context, listen: false).fetchDetails(widget.url)
    );
  }

  void _navigateToNewPage(String link) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(url: link),
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
            slivers: [
              SliverAppBar(
                expandedHeight: 450,
                pinned: true,
                backgroundColor: const Color(0xFF121212),
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
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
                              const Color(0xFF121212).withOpacity(0.6),
                              const Color(0xFF121212),
                            ],
                            stops: const [0.4, 0.8, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [BoxShadow(blurRadius: 10, color: Colors.black)],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _buildInfoChips(data.info),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.story,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                      ),
                      const SizedBox(height: 20),

                      Consumer<FavoritesProvider>(
                        builder: (context, favProvider, _) {
                          final isFav = favProvider.isFavorite(widget.url);
                          return Align(
                            alignment: Alignment.center,
                            child: InkWell(
                              onTap: () {
                                favProvider.toggleFavorite(data.title, data.poster, widget.url);
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isFav ? const Color(0xFFE50914) : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: isFav ? null : Border.all(color: Colors.white30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isFav ? Icons.remove : Icons.add,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isFav ? "إزالة من المفضلة" : "أضف الي المفضلة",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // ================== زر المفضلة (نهاية الإضافة) ==================

                      const SizedBox(height: 25),

                      if (data.type != 'series') ...[
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFB00710)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: MaterialButton(
                            onPressed: provider.isServersLoading
                                ? null
                                : () {
                              Provider.of<DetailsProvider>(context, listen: false).fetchServers(widget.url, context);
                            },
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: provider.isServersLoading
                                ? const SizedBox(
                                height: 25,
                                width: 25,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  'مشاهدة و تحميل',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "قم باختيار الموسم والحلقة بالأسفل للمشاهدة",
                                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      if (data.collection.isNotEmpty) ...[
                        const Text(
                          "سلسلة العمل",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildHorizontalPosterList(data.collection),
                        const SizedBox(height: 30),
                      ],

                      if (data.seasons.isNotEmpty) ...[
                        _buildSeasonsDropdown(provider, data.seasons),
                        const SizedBox(height: 15),
                        _buildEpisodesHorizontalList(data.seasons[provider.selectedSeasonIndex].episodes),
                      ],

                      const SizedBox(height: 30),

                      if (data.related.isNotEmpty) ...[
                        const Text(
                          "أعمال مشابهة",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildRelatedGrid(data.related),
                      ],

                      const SizedBox(height: 30),
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

  List<Widget> _buildInfoChips(Map<String, dynamic> info) {
    List<Widget> chips = [];
    if (info.containsKey('سنة_العرض_')) {
      chips.add(_infoChip(info['سنة_العرض_'][0].toString(), Colors.amber));
    }
    if (info.containsKey('جودة_العرض_')) {
      chips.add(_infoChip(info['جودة_العرض_'][0].toString(), Colors.blueAccent));
    }
    if (info.containsKey('نوع_العرض_')) {
      chips.add(_infoChip(info['نوع_العرض_'][0].toString(), Colors.purpleAccent));
    }
    return chips;
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSeasonsDropdown(DetailsProvider provider, List<Season> seasons) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: provider.selectedSeasonIndex,
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.redAccent),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildEpisodesHorizontalList(List<Episode> episodes) {
    return SizedBox(
      height: 65,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: episodes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final episode = episodes[index];
          return InkWell(
            onTap: () => _navigateToNewPage(episode.link),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "الحلقة ${episode.number}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalPosterList(List<RelatedItem> items) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _navigateToNewPage(item.link),
            child: SizedBox(
              width: 110,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
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
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _navigateToNewPage(item.link),
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
                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }
}