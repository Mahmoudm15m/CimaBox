class ContentItem {
  final String title;
  final String link;
  final String image;
  final String? rating;
  final String? quality;
  final String? category;
  final String? type;
  final String? seriesName;
  final String? episodeNumber;

  ContentItem({
    required this.title,
    required this.link,
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
      title: json['title'] ?? '',
      link: json['link'] ?? '',
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
    return HomeData(
      featured: (json['featured'] as List).map((e) => ContentItem.fromJson(e)).toList(),
      episodes: (json['episodes'] as List).map((e) => ContentItem.fromJson(e)).toList(),
      movies: (json['movies'] as List).map((e) => ContentItem.fromJson(e)).toList(),
      series: (json['series'] as List).map((e) => ContentItem.fromJson(e)).toList(),
    );
  }
}

class CategoryItem {
  final String title;
  final String link;
  final String type;

  CategoryItem({required this.title, required this.link, required this.type});

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      type: json['type'] ?? '',
    );
  }
}