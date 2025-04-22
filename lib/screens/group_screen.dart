import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ghanaumc_app/widgets/audio_player_widget.dart';
import 'package:ghanaumc_app/widgets/video_player_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FirebaseFirestore firestore = FirebaseFirestore.instance;
final FirebaseStorage storage = FirebaseStorage.instance;
final ImagePicker _picker = ImagePicker();

class GroupScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupIcon;
  
  const GroupScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
  }) : super(key: key);

  @override
  _GroupScreenState createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late String _groupId;
  late String _groupName;
  late String _groupIcon;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
    _groupName = widget.groupName;
    _groupIcon = widget.groupIcon;
  }

  Future<void> _showAddPostDialog(BuildContext context) async {
    final TextEditingController postController = TextEditingController();
    String? postType;
    File? selectedFile;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Create New Post in $_groupName"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text("Text Post"),
                  leading: Icon(Icons.text_fields),
                  onTap: () {
                    setState(() {
                      postType = 'text';
                      selectedFile = null;
                    });
                  },
                ),
                ListTile(
                  title: Text("Image"),
                  leading: Icon(Icons.image),
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        postType = 'image';
                        selectedFile = File(image.path);
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text("Audio"),
                  leading: Icon(Icons.audiotrack),
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
                    if (result != null && result.files.single.path != null) {
                      setState(() {
                        postType = 'audio';
                        selectedFile = File(result.files.single.path!);
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text("Video"),
                  leading: Icon(Icons.videocam),
                  onTap: () async {
                    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                    if (video != null) {
                      setState(() {
                        postType = 'video';
                        selectedFile = File(video.path);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (selectedFile != null)
                  postType == 'image'
                      ? Image.file(selectedFile!, height: 150, fit: BoxFit.cover)
                      : postType == 'audio'
                          ? AudioPlayerWidget(url: selectedFile!.path)
                          : postType == 'video'
                              ? VideoPlayerWidget(url: selectedFile!.path)
                              : SizedBox(),
                const SizedBox(height: 10),
                TextField(
                  controller: postController,
                  decoration: InputDecoration(
                    hintText: 'Write your post...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Post'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    String mediaUrl = '';
    if (postType != 'text' && selectedFile != null) {
      mediaUrl = await _uploadFile(selectedFile!, postType!);
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    await firestore.collection('posts').add({
      'content': postController.text.trim(),
      'mediaUrl': mediaUrl,
      'mediaType': postType ?? 'text',
      'groupId': _groupId,
      'groupName': _groupName,
      'groupIcon': _groupIcon,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'userId': currentUser?.uid,
      'userEmail': currentUser?.email,
    });
  }

  Future<String> _uploadFile(File file, String type) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = storage.ref().child('group_posts/$filename');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('posts')
          .where('groupId', isEqualTo: _groupId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postId = post.id;
            final content = post['content'] ?? '';
            final mediaUrl = post['mediaUrl'] ?? '';
            final mediaType = post['mediaType'] ?? 'text';
            final timestamp = post['timestamp']?.toDate();
            final userEmail = post['userEmail'] ?? 'Unknown';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userEmail, style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (content.isNotEmpty) Text(content),
                    const SizedBox(height: 8),
                    if (mediaType == 'image' && mediaUrl.isNotEmpty)
                      Image.network(mediaUrl),
                    if (mediaType == 'audio' && mediaUrl.isNotEmpty)
                      AudioPlayerWidget(url: mediaUrl),
                    if (mediaType == 'video' && mediaUrl.isNotEmpty)
                      VideoPlayerWidget(url: mediaUrl),
                    if (timestamp != null)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "${timestamp.toLocal()}".split('.')[0],
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deletePost(postId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    await firestore.collection('posts').doc(postId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddPostDialog(context),
          ),
        ],
      ),
      body: _buildFeed(),
    );
  }
}
