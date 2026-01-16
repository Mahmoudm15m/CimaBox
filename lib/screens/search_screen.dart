import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/search_provider.dart';
import '../models/home_model.dart'; // تأكد من استدعاء الموديل
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all';

  void _performSearch() {
    FocusScope.of(context).unfocus();
    Provider.of<SearchProvider>(context, listen: false)
        .search(_searchController.text, type: _selectedType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('بحث', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // 1. مربع البحث والفلاتر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن فيلم أو مسلسل...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _performSearch,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildFilterChip('الكل', 'all'),
                    const SizedBox(width: 10),
                    _buildFilterChip('أفلام', 'movie'),
                    const SizedBox(width: 10),
                    _buildFilterChip('مسلسلات', 'series'),
                  ],
                ),
              ],
            ),
          ),

          // 2. النتائج (تم التعديل لـ ListView)
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                if (provider.error != null) {
                  return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.grey)));
                }

                if (provider.results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[800]),
                        const SizedBox(height: 10),
                        Text("لا توجد نتائج بحث", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                // هنا التغيير: ListView بدل GridView
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12), // مسافة بين العناصر
                  itemBuilder: (context, index) {
                    final item = provider.results[index];
                    return _buildSearchItem(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // دالة بناء العنصر (صورة يسار + معلومات يمين)
  Widget _buildSearchItem(BuildContext context, ContentItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(url: item.link),
          ),
        );
      },
      child: Container(
        height: 140, // ارتفاع ثابت للكارت
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // لون خلفية الكارت
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 1. الصورة (على اليسار)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 2 / 3, // نسبة البوستر القياسية
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),

            // 2. المعلومات (على اليمين)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // العنوان
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),

                    // شارات المعلومات (تقييم - جودة - نوع)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // التقييم
                        if (item.rating != null && item.rating != "N/A")
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  item.rating!,
                                  style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),

                        // الجودة
                        if (item.quality != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Text(
                              item.quality!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),

                        // النوع (فيلم/مسلسل)
                        if (item.type != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                            ),
                            child: Text(
                              item.type == 'movie' ? 'فيلم' : 'مسلسل',
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
        if (_searchController.text.isNotEmpty) {
          _performSearch();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.redAccent : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}