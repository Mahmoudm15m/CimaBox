import 'home_model.dart';

class ActorModel {
  final String? name;
  final String? image;
  final String? summary;
  final List<ContentItem> movies;
  final List<ContentItem> series;

  ActorModel({
    this.name,
    this.image,
    this.summary,
    required this.movies,
    required this.series,
  });

  factory ActorModel.fromJson(Map<String, dynamic> json) {
    List<ContentItem> parseList(String key) {
      return json[key] != null
          ? (json[key] as List).map((e) => ContentItem.fromJson(e)).toList()
          : [];
    }

    return ActorModel(
      name: json['name'],
      image: json['image'],
      summary: json['summary'],
      movies: parseList('movies'),
      series: parseList('series'),
    );
  }
}