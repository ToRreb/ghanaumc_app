import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ghanaumc_app/widgets/audio_player_widget.dart';
import 'package:ghanaumc_app/widgets/video_player_widget.dart';

final user = FirebaseAuth.instance.currentUser;
final FirebaseStorage storage = FirebaseStorage.instance;
final FirebaseFirestore firestore = FirebaseFirestore.instance;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> { 
  String? _currentGroupId;
  String? _currentGroupName;
  String? _currentGroupIcon;
  final ImagePicker _picker = ImagePicker();

  Future<void> _showAddGroupDialog(BuildContext context) async {
    final TextEditingController groupNameController = TextEditingController();
    File? groupIconFile;

    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Create New Group'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() => groupIconFile = File(image.path));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: groupIconFile != null 
                        ? FileImage(groupIconFile!) 
                        : null,
                    child: groupIconFile == null
                        ? Icon(Icons.add_a_photo, size: 30)
                        : null,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: groupNameController,
                  decoration: InputDecoration(
                    hintText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (groupNameController.text.isNotEmpty) {
                    Navigator.pop(context, true);
                  }
                },
                child: Text('Create'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      String iconUrl = '';
      if (groupIconFile != null) {
        iconUrl = await _uploadFile(groupIconFile!, 'group_icons');
      }

      final groupRef = await firestore.collection('groups').add({
        'name': groupNameController.text,
        'icon': iconUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentGroupId = groupRef.id;
        _currentGroupName = groupNameController.text;
        _currentGroupIcon = iconUrl;
      });
    }
  }

  Future<void> _uploadMedia() async {
    if (_currentGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a group first')),
      );
      return;
    }

    final mediaType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create New Post"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.text_fields),
              title: Text("Text Post"),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              leading: Icon(Icons.image),
              title: Text("Image"),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: Icon(Icons.audiotrack),
              title: Text("Audio"),
              onTap: () => Navigator.pop(context, 'audio'),
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text("Video"),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    File? selectedFile;
    String? filePath;

    if (mediaType != 'text') {
      try {
        if (mediaType == 'image') {
          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            selectedFile = File(image.path);
            filePath = image.path;
          }
        } else {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: mediaType == 'audio' ? FileType.audio : FileType.video,
          );
          if (result != null) {
            selectedFile = File(result.files.single.path!);
            filePath = result.files.single.path;
          }
        }
      } catch (e) {
        print("Error picking file: $e");
        return;
      }
    }

    if (mediaType != 'text' && selectedFile == null) return;

    final TextEditingController postController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Create Post"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filePath != null)
                mediaType == 'image'
                    ? Image.file(File(filePath!), height: 150, fit: BoxFit.cover)
                    : mediaType == 'video'
                        ? VideoPlayerWidget(url: filePath!)
                        : AudioPlayerWidget(url: filePath!),
              SizedBox(height: 10),
              TextField(
                controller: postController,
                decoration: InputDecoration(
                  hintText: 'Write something...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Post'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    String? mediaUrl;
    if (mediaType != 'text') {
      mediaUrl = await _uploadFile(selectedFile!, '${mediaType}s');
    }

    await firestore.collection('posts').add({
      'content': postController.text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'groupId': _currentGroupId,
      'groupName': _currentGroupName,
      'groupIcon': _currentGroupIcon,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
    });
  }

  Future<String> _uploadFile(File file, String folder) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}';
    Reference ref = storage.ref().child('$folder/$fileName');
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  void _deletePost(String postId) {
    firestore.collection('posts').doc(postId).delete();
  }

  void _deleteGroup(String groupId) {
    firestore.collection('groups').doc(groupId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGroupName ?? "All Posts"),
        backgroundColor: Colors.deepPurple,
      ),
      drawer: _buildGroupDrawer(),
      body: _buildFeed(),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadMedia,
        child: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildGroupDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Padding(
              padding: const EdgeInsets.only(top: 50.0),
              child: Text(
                'Groups',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ListTile(
            title: Text('Add Group'),
            onTap: () => _showAddGroupDialog(context),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('groups').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              var groups = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  var group = groups[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: group['icon'] != null 
                          ? NetworkImage(group['icon'])
                          : null,
                    ),
                    title: Text(group['name']),
                    onTap: () {
                      setState(() {
                        _currentGroupId = group.id;
                        _currentGroupName = group['name'];
                        _currentGroupIcon = group['icon'];
                      });
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteGroup(group.id),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentGroupId == null
          ? firestore.collection('posts').orderBy('timestamp', descending: true).snapshots()
          : firestore
              .collection('posts')
              .where('groupId', isEqualTo: _currentGroupId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        var posts = snapshot.data!.docs;
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var post = posts[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: post['groupIcon'] != null
                    ? NetworkImage(post['groupIcon'])
                    : null,
              ),
              title: Text(post['groupName']),
              subtitle: Text(post['content']),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _deletePost(post.id),
              ),
            );
          },
        );
      },
    );
  }
}
