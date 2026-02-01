enum DownloadStatus { pending, downloading, paused, completed, failed, canceled }
enum DownloadType { direct, hls }

class DownloadItem {
  String id;
  int? contentId;
  String url;
  String title;
  String fileNameLabel;
  String image;
  String? savedPath;
  DownloadStatus status;
  DownloadType type;
  double progress;
  int downloadedBytes;
  int totalBytes;
  int? taskId;
  String? downloaderTaskId;
  String quality;
  Map<String, String>? headers;

  DownloadItem({
    required this.id,
    this.contentId,
    required this.url,
    required this.title,
    this.fileNameLabel = '',
    required this.image,
    this.savedPath,
    this.status = DownloadStatus.pending,
    this.type = DownloadType.direct,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.taskId,
    this.downloaderTaskId,
    this.quality = '',
    this.headers,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] ?? '',
      contentId: json['contentId'],
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      fileNameLabel: json['fileNameLabel'] ?? '',
      image: json['image'] ?? '',
      savedPath: json['savedPath'],
      status: DownloadStatus.values[json['status'] ?? 0],
      type: DownloadType.values[json['type'] ?? 0],
      progress: json['progress'] ?? 0.0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      quality: json['quality'] ?? '',
      headers: json['headers'] != null ? Map<String, String>.from(json['headers']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'url': url,
      'title': title,
      'fileNameLabel': fileNameLabel,
      'image': image,
      'savedPath': savedPath,
      'status': status.index,
      'type': type.index,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'quality': quality,
      'headers': headers,
    };
  }
}