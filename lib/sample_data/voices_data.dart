class VoicePost {
  final String name;
  final String location;
  final String timeAgo;
  final String description;
  final String category;
  int supports;
  int replies;
  // final bool hasImage;
  final String? imageUrl;
  bool isSupported;

  VoicePost({
    required this.name,
    required this.location,
    required this.timeAgo,
    required this.description,
    required this.category,
    required this.supports,
    required this.replies,
    // required this.hasImage,
    this.imageUrl,
    this.isSupported = false,
  });
}

final List<VoicePost> dummyVoicePosts = [
  VoicePost(
    name: 'Jayesh Thakare',
    location: 'Belapur, Navi Mumbai, 400614',
    timeAgo: '21h ago',
    category: 'Water',
    description:
    'There is a continuous water leakage from a damaged pipeline in this area, leading to water wastage and waterlogging on the road...',
    supports: 1,
    replies: 0,
    // hasImage: true,
    imageUrl: 'assets/images/waterleakage.jpg',
  ),
  VoicePost(
    name: 'Priya Sharma',
    location: 'Sector 7, Kharghar, 410210',
    timeAgo: '3h ago',
    category: 'Electricity',
    description:
    'Streetlights on the main road have not been working for over 2 weeks now. Very dangerous for pedestrians at night...',
    supports: 4,
    replies: 2,
    // hasImage: false,
    imageUrl: 'assets/images/streetlights.jpg',
  ),
  VoicePost(
    name: 'Rahul Desai',
    location: 'Panvel, Navi Mumbai, 410206',
    timeAgo: '1d ago',
    category: 'Sanitation',
    description:
    'Garbage has not been collected for 4 days in our colony. The pile is growing and causing a bad smell in the area...',
    supports: 12,
    replies: 5,
    // hasImage: true,
    imageUrl: 'assets/images/garbage.jpg',
  ),
  VoicePost(
    name: 'Sneha Patil',
    location: 'Vashi, Navi Mumbai, 400703',
    timeAgo: '2d ago',
    category: 'Roads',
    description:
    'There are multiple potholes on the service road near the highway. Two-wheelers have already had accidents because of this...',
    supports: 23,
    replies: 8,
    // hasImage: true,
    imageUrl: 'assets/images/potholes.jpg',
  ),
  VoicePost(
    name: 'Amit Kulkarni',
    location: 'Airoli, Navi Mumbai, 400708',
    timeAgo: '5h ago',
    category: 'Noise',
    description:
    'Construction work is happening illegally after 10 PM every night. Residents including elderly and children are unable to sleep...',
    supports: 7,
    replies: 3,
    // hasImage: false,
    imageUrl: 'assets/images/illegal.jpg',
  ),
];