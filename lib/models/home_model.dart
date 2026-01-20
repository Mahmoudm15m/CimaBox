class ContentItem {
  final int id;
  final String title;
  final String image;
  final String? rating;
  final String? quality;
  final String? category;
  final String? type;
  final String? seriesName;
  final String? episodeNumber;

  ContentItem({
    required this.id,
    required this.title,
    required this.image,
    this.rating,
    this.quality,
    this.category,
    this.type,
    this.seriesName,
    this.episodeNumber,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      rating: json['rating'] == "N/A" ? null : json['rating'],
      quality: json['quality'],
      category: json['category'],
      type: json['type'],
      seriesName: json['series_name'],
      episodeNumber: json['episode_number'],
    );
  }
}

class HomeData {
  final List<ContentItem> featured;
  final List<ContentItem> episodes;
  final List<ContentItem> movies;
  final List<ContentItem> series;

  HomeData({
    required this.featured,
    required this.episodes,
    required this.movies,
    required this.series,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    List<ContentItem> parseList(String key) {
      return json[key] != null
          ? (json[key] as List).map((e) => ContentItem.fromJson(e)).toList()
          : [];
    }

    return HomeData(
      featured: parseList('featured'),
      episodes: parseList('episodes'),
      movies: parseList('movies'),
      series: parseList('series'),
    );
  }
}

class CategoryItem {
  final int id;
  final String title;
  final String type;

  CategoryItem({required this.id, required this.title, required this.type});

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      type: json['type'] ?? 'category',
    );
  }
}