class Post {
  final String id;
  final String title;
  final String content;
  final String mediaUrl;
  final String mediaType; // 'image', 'audio', 'video', or 'text'

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.mediaUrl,
    required this.mediaType,
  });
}
