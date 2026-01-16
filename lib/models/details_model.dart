class DetailsModel {
  final String type;
  final String title;
  final String poster;
  final String story;
  final Map<String, dynamic> info;
  final List<Season> seasons;
  final List<RelatedItem> related;
  final List<RelatedItem> collection;

  DetailsModel({
    required this.type,
    required this.title,
    required this.poster,
    required this.story,
    required this.info,
    required this.seasons,
    required this.related,
    required this.collection,
  });

  factory DetailsModel.fromJson(Map<String, dynamic> json) {
    return DetailsModel(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      poster: json['poster'] ?? '',
      story: json['story'] ?? '',
      info: json['info'] ?? {},
      seasons: json['seasons'] != null
          ? (json['seasons'] as List).map((e) => Season.fromJson(e)).toList()
          : [],
      related: json['related'] != null
          ? (json['related'] as List).map((e) => RelatedItem.fromJson(e)).toList()
          : [],
      collection: json['collection'] != null
          ? (json['collection'] as List).map((e) => RelatedItem.fromJson(e)).toList()
          : [],
    );
  }
}

class Season {
  final String name;
  final List<Episode> episodes;

  Season({required this.name, required this.episodes});

  factory Season.fromJson(Map<String, dynamic> json) {
    var eps = json['episodes'] != null
        ? (json['episodes'] as List).map((e) => Episode.fromJson(e)).toList()
        : <Episode>[];

    // --- التعديل هنا: ترتيب الحلقات تصاعدياً ---
    try {
      eps.sort((a, b) {
        // استخراج الأرقام وتحويلها لـ int للمقارنة الصحيحة
        int n1 = int.tryParse(a.number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int n2 = int.tryParse(b.number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return n1.compareTo(n2);
      });
    } catch (e) {
      // في حالة فشل الترتيب، اتركها كما هي
    }
    // -------------------------------------------

    return Season(
      name: json['name'] ?? '',
      episodes: eps,
    );
  }
}

class Episode {
  final String link;
  final String number;

  Episode({required this.link, required this.number});

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      link: json['link'] ?? '',
      number: json['number'] != null ? json['number'].toString() : '',
    );
  }
}

class RelatedItem {
  final String title;
  final String image;
  final String link;

  RelatedItem({required this.title, required this.image, required this.link});

  factory RelatedItem.fromJson(Map<String, dynamic> json) {
    return RelatedItem(
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      link: json['link'] ?? '',
    );
  }
}