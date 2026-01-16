import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/watch_history_provider.dart';
import '../providers/details_provider.dart';

class WatchHistoryScreen extends StatelessWidget {
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("سجل المشاهدة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text("تفريغ السجل", style: TextStyle(color: Colors.white)),
                  content: const Text("هل أنت متأكد من حذف كل سجل المشاهدة؟", style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(
                      child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    TextButton(
                      child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        Provider.of<WatchHistoryProvider>(context, listen: false).clearHistory();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<WatchHistoryProvider>(
        builder: (context, provider, child) {
          if (provider.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 10),
                  Text("السجل فارغ", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.history.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = provider.history[index];
              double progress = 0.0;
              if (item.durationMs > 0) {
                progress = item.positionMs / item.durationMs;
              }

              return Dismissible(
                key: Key(item.link),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  provider.removeItem(item.link);
                },
                child: GestureDetector(
                  onTap: () {
                    Provider.of<DetailsProvider>(context, listen: false).fetchServers(item.link, context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("جاري الاستكمال..."),
                      duration: Duration(seconds: 1),
                    ));
                  },
                  child: Container(
                    height: 120, // <--- التعديل هنا: زودنا الارتفاع من 100 لـ 120
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: item.image,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: Colors.grey[900]),
                                  errorWidget: (c, u, e) => const Icon(Icons.movie, color: Colors.white54),
                                ),
                                Container(color: Colors.black38),
                                const Center(child: Icon(Icons.play_circle_outline, color: Colors.white)),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white24,
                                    color: Colors.redAccent,
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // تحسين الـ padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${(progress * 100).toInt()}% مكتمل",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                                const SizedBox(height: 4), // مسافة صغيرة إضافية
                                if (item.quality != null)
                                  Text(
                                    "الجودة: ${item.quality}",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}