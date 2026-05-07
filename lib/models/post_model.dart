import 'package:firebase_database/firebase_database.dart';

class VoicePost {
  final String key;
  final String uid;
  final String name;
  final String description;
  final String location;
  final double? latitude;
  final double? longitude;
  final String category;
  final String timestamp;
  final String imageUrl;
  final int supports;
  final int replies;

  final Map<String, dynamic> supportedBy;

  VoicePost({
    required this.key,
    required this.uid,
    required this.name,
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    required this.category,
    required this.timestamp,
    required this.imageUrl,
    required this.supports,
    required this.replies,
    required this.supportedBy,
  });

  factory VoicePost.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return VoicePost(
      key: snapshot.key ?? '',
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'User',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      category: data['category'] ?? 'General',
      timestamp: data['timestamp'] ?? '',
      imageUrl: data['image_url'] ?? '',
      supports: (data['supports'] as num?)?.toInt() ?? 0,
      replies: (data['replies'] as num?)?.toInt() ?? 0,
      supportedBy: data['supportedBy'] != null
          ? Map<String, dynamic>.from(data['supportedBy'])
          : {},
    );
  }

  factory VoicePost.fromMap(String key, Map<String, dynamic> data) {
    return VoicePost(
      key: key,
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'User',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      category: data['category'] ?? 'General',
      timestamp: data['timestamp'] ?? '',
      imageUrl: data['image_url'] ?? '',
      supports: (data['supports'] as num?)?.toInt() ?? 0,
      replies: (data['replies'] as num?)?.toInt() ?? 0,
      supportedBy: data['supportedBy'] != null
          ? Map<String, dynamic>.from(data['supportedBy'])
          : {},
    );
  }
}

class PostReply {
  final String key;
  final String uid;
  final String name;
  final String text;
  final String timestamp;

  PostReply({
    required this.key,
    required this.uid,
    required this.name,
    required this.text,
    required this.timestamp,
  });

  factory PostReply.fromMap(String key, Map<String, dynamic> data) {
    return PostReply(
      key: key,
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'Anonymous',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? '',
    );
  }
}
