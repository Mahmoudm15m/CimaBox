import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/search_provider.dart';
import '../models/home_model.dart';
import 'details_screen.dart';
import 'category_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _selectedType = 'all';
  List<String> _searchHistory = [];
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    Future.microtask(() =>
        Provider.of<SearchProvider>(context, listen: false).fetchBrowseData()
    );

    _searchController.addListener(() {
      setState(() {});
    });

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/search_history.json');
  }

  Future<void> _loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> list = json.decode(jsonStr);
        setState(() {
          _searchHistory = list.cast<String>();
          _isHistoryLoaded = true;
        });
      } else {
        setState(() => _isHistoryLoaded = true);
      }
    } catch (e) {
      setState(() => _isHistoryLoaded = true);
    }
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    if (_searchHistory.contains(query)) {
      _searchHistory.remove(query);
    }
    _searchHistory.insert(0, query);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    setState(() {});
    _saveHistory();
  }

  Future<void> _removeFromHistory(String query) async {
    setState(() => _searchHistory.remove(query));
    _saveHistory();
  }

  Future<void> _clearHistory() async {
    setState(() => _searchHistory.clear());
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final file = await _getHistoryFile();
      await file.writeAsString(json.encode(_searchHistory));
    } catch (e) { }
  }

  Future<void> _performSearch({String? query}) async {
    String text = query ?? _searchController.text;
    if (text.trim().isEmpty) return;

    if (query != null) {
      _searchController.text = query;
      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    }

    _focusNode.unfocus();

    final provider = Provider.of<SearchProvider>(context, listen: false);
    await provider.search(text, type: _selectedType);

    if (provider.results.isNotEmpty) {
      _addToHistory(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_searchController.text.isNotEmpty) {
      content = _buildSearchResults();
    } else if (_focusNode.hasFocus) {
      content = _buildHistoryView();
    } else {
      content = _buildBrowseView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن فيلم أو مسلسل...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          Provider.of<SearchProvider>(context, listen: false).clearResults();
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 15),
                  if (_searchController.text.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterChip('الكل', 'all'),
                          const SizedBox(width: 10),
                          _buildFilterChip('أفلام', 'movie'),
                          const SizedBox(width: 10),
                          _buildFilterChip('مسلسلات', 'series'),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<SearchProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        if (provider.error != null) {
          return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.white70)));
        }

        if (provider.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey[800]),
                const SizedBox(height: 10),
                Text("لا توجد نتائج", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = provider.results[index];
            return _buildResultItem(context, item);
          },
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (!_isHistoryLoaded) return const SizedBox();

    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 70, color: Colors.grey[800]),
            const SizedBox(height: 10),
            Text("سجل البحث فارغ", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "عمليات البحث السابقة",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text(
                  "مسح الكل",
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                  onPressed: () => _removeFromHistory(query),
                ),
                onTap: () => _performSearch(query: query),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseView() {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        if (provider.isBrowseLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        if (provider.genres.isEmpty && provider.qualities.isEmpty && provider.years.isEmpty) {
          return const SizedBox();
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Years Section - Dropdown Menu (القائمة المنسدلة)
              if (provider.years.isNotEmpty) ...[
                const Text(
                  "تصفح حسب السنة",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("اختر السنة", style: TextStyle(color: Colors.grey)),
                      dropdownColor: const Color(0xFF252525),
                      icon: const Icon(Icons.calendar_today, color: Colors.redAccent, size: 20),
                      menuMaxHeight: 300, // تحديد أقصى ارتفاع للقائمة لتسمح بالسكرول
                      items: provider.years.map((item) {
                        return DropdownMenuItem(
                          value: item.value,
                          child: Text(
                            item.value,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryScreen(
                                title: val, // يعرض السنة فقط كعنوان
                                id: 0,
                                year: val,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),
              ],

              // 2. Qualities Section
              if (provider.qualities.isNotEmpty) ...[
                const Text(
                  "تصفح حسب الجودة",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: provider.qualities.map((item) => _buildQualityChip(item)).toList(),
                ),
                const SizedBox(height: 25),
              ],

              // 3. Genres Section
              if (provider.genres.isNotEmpty) ...[
                const Text(
                  "تصفح حسب التصنيف",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: provider.genres.length,
                  itemBuilder: (context, index) {
                    final item = provider.genres[index];
                    return _buildGenreCard(item);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityChip(BrowseItem item) {
    return ActionChip(
      label: Text(item.value),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      backgroundColor: const Color(0xFF252525),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(title: item.value, id: item.id),
          ),
        );
      },
    );
  }

  Widget _buildGenreCard(BrowseItem item) {
    final List<Color> colors = [
      Colors.blueAccent.withOpacity(0.1),
      Colors.redAccent.withOpacity(0.1),
      Colors.purpleAccent.withOpacity(0.1),
      Colors.orangeAccent.withOpacity(0.1),
      Colors.greenAccent.withOpacity(0.1),
      Colors.tealAccent.withOpacity(0.1),
    ];
    final color = colors[item.id % colors.length];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(title: item.value, id: item.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, ContentItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(id: item.id),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 0.7,
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.rating != null && item.rating != "N/A") ...[
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            item.rating!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.type != null)
                          Text(
                            item.type == 'movie' ? 'فيلم' : 'مسلسل',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (item.quality != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Text(
                              item.quality!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
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
        setState(() => _selectedType = type);
        if (_searchController.text.isNotEmpty) _performSearch();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.redAccent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}