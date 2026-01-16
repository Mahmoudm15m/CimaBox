enum DownloadType { hls, direct }
enum DownloadStatus { downloading, completed, failed, paused }

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String image;
  String? savedPath;
  double progress;
  int downloadedBytes;
  int totalBytes;
  DownloadStatus status;
  int? taskId;
  String? downloaderTaskId;
  DownloadType type;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.image,
    this.savedPath,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.downloading,
    this.taskId,
    this.downloaderTaskId,
    this.type = DownloadType.hls,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'image': image,
      'savedPath': savedPath,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'status': status.index,
      'taskId': taskId,
      'downloaderTaskId': downloaderTaskId,
      'type': type.index,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      image: json['image'],
      savedPath: json['savedPath'],
      progress: (json['progress'] as num).toDouble(),
      downloadedBytes: json['downloadedBytes'],
      totalBytes: json['totalBytes'],
      status: DownloadStatus.values[json['status']],
      taskId: json['taskId'],
      downloaderTaskId: json['downloaderTaskId'],
      type: DownloadType.values[json['type']],
    );
  }
}