import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/actor_provider.dart';
import '../models/home_model.dart';
import 'details_screen.dart';

class ActorScreen extends StatelessWidget {
  final int id;
  final String name;
  final String? imageUrl;

  const ActorScreen({
    super.key,
    required this.id,
    required this.name,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActorProvider(),
      child: _ActorContent(id: id, name: name, imageUrl: imageUrl),
    );
  }
}

class _ActorContent extends StatefulWidget {
  final int id;
  final String name;
  final String? imageUrl;

  const _ActorContent({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  @override
  State<_ActorContent> createState() => _ActorContentState();
}

class _ActorContentState extends State<_ActorContent> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<ActorProvider>(context, listen: false).fetchActor(widget.id)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Consumer<ActorProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                  const SizedBox(height: 10),
                  Text(provider.error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.fetchActor(widget.id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text("إعادة المحاولة", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }

          if (provider.actor == null) return const SizedBox();

          final actor = provider.actor!;
          final displayImage = actor.image ?? widget.imageUrl;
          final displayName = actor.name ?? widget.name;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
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
                      if (displayImage != null)
                        CachedNetworkImage(
                          imageUrl: displayImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) => Container(color: Colors.grey[900]),
                          errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF121212).withOpacity(0.2),
                              const Color(0xFF121212),
                            ],
                            stops: const [0.0, 0.6, 1.0],
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
                              displayName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                shadows: [BoxShadow(blurRadius: 20, color: Colors.black)],
                              ),
                            ),
                            const SizedBox(height: 20),
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
                      if (actor.summary != null && actor.summary!.isNotEmpty) ...[
                        const Text(
                          "نبذة",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          actor.summary!,
                          style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 25),
                      ],

                      if (actor.movies.isNotEmpty) ...[
                        const Text(
                          "أفلام",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildContentList(actor.movies),
                        const SizedBox(height: 25),
                      ],

                      if (actor.series.isNotEmpty) ...[
                        const Text(
                          "مسلسلات",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildContentList(actor.series),
                        const SizedBox(height: 25),
                      ],
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

  Widget _buildContentList(List<ContentItem> items) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
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
                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.grey),
                          ),
                          if (item.quality != null && item.quality!.isNotEmpty)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.quality!,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (item.rating != null && item.rating!.isNotEmpty)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.rating!,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
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
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
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