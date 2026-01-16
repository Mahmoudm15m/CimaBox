import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/favorites_provider.dart';
import 'details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("قائمتي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // زر حذف الكل (إضافة جديدة لتطابق التصميم)
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text("تفريغ القائمة", style: TextStyle(color: Colors.white)),
                  content: const Text("هل أنت متأكد من حذف كل العناصر من قائمتي؟", style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(
                      child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    TextButton(
                      child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        // ملاحظة: تأكد من إضافة دالة clearFavorites في FavoritesProvider
                        // إذا لم تكن موجودة، سأكتبها لك في الأسفل
                        Provider.of<FavoritesProvider>(context, listen: false).clearFavorites();
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
      body: Consumer<FavoritesProvider>(
        builder: (context, provider, child) {
          if (provider.favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 10),
                  Text("لم تقم بإضافة أي شيء بعد", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.favorites.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final item = provider.favorites[index];

              return Dismissible(
                key: Key(item.link),
                direction: DismissDirection.horizontal, // السحب في الاتجاهين

                // خلفية السحب (يمين)
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                // خلفية السحب (يسار)
                secondaryBackground: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                onDismissed: (direction) {
                  provider.removeFavorite(item.link);
                },

                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => DetailsScreen(url: item.link)));
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // صورة العرض
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9, // تحافظ على نسبة العرض للارتفاع
                            child: CachedNetworkImage(
                              imageUrl: item.image,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(color: Colors.grey[900]),
                              errorWidget: (c, u, e) => const Icon(Icons.movie, color: Colors.white54),
                            ),
                          ),
                        ),

                        // النصوص والمعلومات
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                                const SizedBox(height: 8),
                                // زر مشاهدة صغير أو نص توضيحي
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "مشاهدة الآن",
                                        style: TextStyle(color: Colors.redAccent, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // سهم صغير للتوجيه (اختياري)
                        const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white24),
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