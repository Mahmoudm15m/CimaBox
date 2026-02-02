import 'package:flutter/material.dart';

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
    required this.status,
    required this.progress,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    required this.type,
    this.contentId,
    this.quality = "",
    this.exportedPath,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      image: json['image'] ?? "",
      fileNameLabel: json['fileNameLabel'] ?? "",
      status: json['exportedPath'] != null
          ? DownloadStatus.completed
          : DownloadStatus.values[json['status'] ?? 0],
      progress: json['progress'] ?? 0.0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      type: DownloadType.values[json['type'] ?? 0],
      contentId: json['contentId'],
      quality: json['quality'] ?? "",
      exportedPath: json['exportedPath'],
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
}