enum DownloadStatus { pending, paused, downloading, completed, failed }
enum DownloadType { direct, hls }

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String image;
  final String fileNameLabel;
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  final DownloadType type;
  final int? contentId;
  final String quality;
  String? exportedPath;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.image,
    required this.fileNameLabel,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.type = DownloadType.direct,
    this.contentId,
    this.quality = "",
    this.exportedPath,
  });

  DownloadItem copyWith({
    String? id,
    String? url,
    String? title,
    String? image,
    String? fileNameLabel,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    DownloadType? type,
    int? contentId,
    String? quality,
    String? exportedPath,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      image: image ?? this.image,
      fileNameLabel: fileNameLabel ?? this.fileNameLabel,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      type: type ?? this.type,
      contentId: contentId ?? this.contentId,
      quality: quality ?? this.quality,
      exportedPath: exportedPath ?? this.exportedPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'image': image,
      'fileNameLabel': fileNameLabel,
      'status': status.index,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'type': type.index,
      'contentId': contentId,
      'quality': quality,
      'exportedPath': exportedPath,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      image: json['image'],
      fileNameLabel: json['fileNameLabel'] ?? '',
      status: DownloadStatus.values[json['status'] ?? 0],
      progress: (json['progress'] ?? 0.0).toDouble(),
      downloadedBytes: json['downloadedBytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      type: DownloadType.values[json['type'] ?? 0],
      contentId: json['contentId'],
      quality: json['quality'] ?? "",
      exportedPath: json['exportedPath'],
    );
  }
}