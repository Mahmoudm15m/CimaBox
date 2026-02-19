import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../models/home_model.dart';
import 'details_screen.dart';
import 'category_screen.dart';
import '../providers/watch_history_provider.dart';
import '../providers/details_provider.dart';
import 'watch_history_screen.dart';
import 'chat_screen.dart';
import 'package:flutter/rendering.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const HomeScreen({super.key, this.scrollController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<HomeProvider>(context, listen: false).fetchHomeData()
    );
  }

  void _navigateToDetails(BuildContext context, int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(id: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isFabVisible ? 1.0 : 0.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFFFF5252)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
              label: const Text(
                "الدردشة الجماعيه",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<HomeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.white)));
          }
          if (provider.homeData == null) {
            return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)));
          }

          final data = provider.homeData!;

          return NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isFabVisible) setState(() => _isFabVisible = false);
              } else if (notification.direction == ScrollDirection.forward || notification.direction == ScrollDirection.idle) {
                if (!_isFabVisible) setState(() => _isFabVisible = true);
              }
              return true;
            },
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (data.featured.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(data.featured),
                  ),
            
                if (data.episodes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('أحدث الحلقات'),
                        _buildHorizontalList(data.episodes),
                      ],
                    ),
                  ),
            
                if (data.movies.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('أحدث الأفلام'),
                        _buildHorizontalList(data.movies),
                      ],
                    ),
                  ),
            
                Consumer<WatchHistoryProvider>(
                    builder: (context, historyProvider, _) {
                      if (historyProvider.history.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox());
                      }
            
                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.history, color: Colors.redAccent, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "استكمال المشاهدة",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => const WatchHistoryScreen()));
                                    },
                                    child: const Text(
                                      "عرض الكل",
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 140,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: historyProvider.history.take(10).length,
                                separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                                itemBuilder: (ctx, i) {
                                  final item = historyProvider.history[i];
                                  double progress = 0.0;
                                  if (item.durationMs > 0) {
                                    progress = item.positionMs / item.durationMs;
                                  }
            
                                  return GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text("جاري الاستكمال..."),
                                        duration: Duration(seconds: 1),
                                      ));
            
                                      Provider.of<DetailsProvider>(context, listen: false).handleAction(
                                          context,
                                          item.id,
                                          isPlay: true,
                                          title: item.title,
                                          poster: item.image,
                                          isFromHistory: true
                                      );
                                    },
                                    onLongPress: (){
                                      historyProvider.removeItem(item.id);
                                    },
                                    child: SizedBox(
                                      width: 200,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CachedNetworkImage(
                                                    imageUrl: item.image,
                                                    fit: BoxFit.cover,
                                                    placeholder: (c, u) => Container(color: Colors.grey[900]),
                                                    errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54)),
                                                  ),
                                                  Container(color: Colors.black38),
                                                  const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
                                                  Positioned(
                                                    bottom: 0, left: 0, right: 0,
                                                    child: LinearProgressIndicator(
                                                      value: progress,
                                                      backgroundColor: Colors.white24,
                                                      color: Colors.redAccent,
                                                      minHeight: 4,
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                          Text(
                                            "${(progress * 100).toInt()}% مكتمل",
                                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    }
                ),
            
                if (data.series.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('المسلسلات'),
                        _buildSeriesSection(data.series),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
            
                if (provider.categories.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final reorderedList = _interleaveCategories(provider.categories);
                        final category = reorderedList[index];
                        return CategorySection(category: category);
                      },
                      childCount: provider.categories.length,
                    ),
                  ),
            
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<CategoryItem> _interleaveCategories(List<CategoryItem> allCategories) {
    if (allCategories.isEmpty) return [];

    List<CategoryItem> moviesList = [];
    List<CategoryItem> seriesList = [];
    List<CategoryItem> others = [];

    for (var item in allCategories) {
      if (item.title.contains("افلام") || item.title.contains("أفلام")) {
        moviesList.add(item);
      } else if (item.title.contains("مسلسلات")) {
        seriesList.add(item);
      } else {
        others.add(item);
      }
    }

    if (moviesList.isEmpty && seriesList.isEmpty) return allCategories;

    List<CategoryItem> mixed = [];
    int m = 0;
    int s = 0;

    while (m < moviesList.length || s < seriesList.length) {
      if (m < moviesList.length) {
        mixed.add(moviesList[m]);
        m++;
      }
      if (s < seriesList.length) {
        mixed.add(seriesList[s]);
        s++;
      }
    }

    mixed.addAll(others);
    return mixed;
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text(
                "عرض المزيد",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(List<ContentItem> items) {
    return SizedBox(
      height: 450,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        padEnds: false,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.only(right: 15),
            height: 450,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[900]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 90,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.category != null)
                          Text(
                            item.category!.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _navigateToDetails(context, item.id),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 30,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Play",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeriesSection(List<ContentItem> items) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        padEnds: false,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _navigateToDetails(context, item.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          item.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalList(List<ContentItem> items) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _navigateToDetails(context, item.id),
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: item.image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[900]),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                          if (item.quality != null && item.quality!.isNotEmpty && item.quality!.toLowerCase() != "unknown")
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.quality!,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategorySection extends StatefulWidget {
  final CategoryItem category;
  const CategorySection({super.key, required this.category});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeProvider>(context, listen: false).fetchCategoryPreview(widget.category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, provider, child) {
        final items = provider.categoryPreviews[widget.category.id];

        if (items == null) {
          return Container(
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: const Center(child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)),
          );
        }

        if (items.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
                            title: widget.category.title,
                            id: widget.category.id,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "عرض المزيد",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(id: item.id),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: item.image,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                  if (item.quality != null && item.quality!.isNotEmpty && item.quality!.toLowerCase() != "unknown")
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE50914),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: ((item.quality!.toLowerCase() != "unknown") || (item.quality!.isEmpty))? Text(
                                          item.quality!,
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ) : SizedBox(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}