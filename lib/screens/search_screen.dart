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

  
  final List<List<Color>> _gradients = [
    [const Color(0xFFE50914), const Color(0xFFB00610)], 
    [const Color(0xFF1E88E5), const Color(0xFF1565C0)], 
    [const Color(0xFF8E24AA), const Color(0xFF6A1B9A)], 
    [const Color(0xFF43A047), const Color(0xFF2E7D32)], 
    [const Color(0xFFFF8F00), const Color(0xFFFF6F00)], 
    [const Color(0xFF00ACC1), const Color(0xFF00838F)], 
    [const Color(0xFFEC407A), const Color(0xFFD81B60)], 
    [const Color(0xFFFFD600), const Color(0xFFFBC02D)], 
  ];

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
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
                ],
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
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFFE50914), width: 1),
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
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              
              if (provider.years.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        "تصفح حسب السنة",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: provider.years.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _buildYearCard(provider.years[index], index);
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],

              
              if (provider.qualities.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.hd_outlined, color: Colors.cyanAccent, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        "تصفح حسب الجودة",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: provider.qualities.asMap().entries.map((entry) {
                      return _buildQualityCard(entry.value, entry.key);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 30),
              ],

              
              if (provider.genres.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.category_outlined, color: Colors.purpleAccent, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        "تصفح حسب التصنيف",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2, 
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

  Widget _buildYearCard(BrowseItem item, int index) {
    
    final gradient = _gradients[index % _gradients.length];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(title: item.value, id: 0, year: item.value),
          ),
        );
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          item.value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))]
          ),
        ),
      ),
    );
  }

  Widget _buildQualityCard(BrowseItem item, int index) {
    
    final gradient = _gradients[(_gradients.length - 1 - index) % _gradients.length];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(title: item.value, id: item.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gradient[0].withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: gradient[0].withOpacity(0.1), blurRadius: 4)
            ]
        ),
        child: Text(
          item.value,
          style: TextStyle(
              color: gradient[1], 
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5
          ),
        ),
      ),
    );
  }

  Widget _buildGenreCard(BrowseItem item) {
    final gradient = _gradients[item.id % _gradients.length];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(title: item.value, id: item.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                  Icons.movie_creation_outlined,
                  size: 60,
                  color: Colors.white.withOpacity(0.2)
              ),
            ),
            Center(
              child: Text(
                item.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    shadows: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
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
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: 0.75,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.rating != null && item.rating != "N/A") ...[
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            item.rating!,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 15),
                        ],
                        if (item.type != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type == 'movie' ? 'فيلم' : 'مسلسل',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (item.quality != null)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      item.quality!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
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
          color: isSelected ? const Color(0xFFE50914) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFE50914) : Colors.white12),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFFE50914).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
          ] : [],
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