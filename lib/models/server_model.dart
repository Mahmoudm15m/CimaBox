class ServerItem {
  final String name;
  final String link;

  ServerItem({required this.name, required this.link});

  factory ServerItem.fromJson(Map<String, dynamic> json) {
    return ServerItem(
      name: json['name'] ?? '',
      link: json['link'] ?? '',
    );
  }
}