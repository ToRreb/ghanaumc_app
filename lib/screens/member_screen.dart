import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ghanaumc_app/screens/welcome_screen.dart';
import 'package:share_plus/share_plus.dart'; // ✅ ADDED for sharing

class MemberScreen extends StatefulWidget {
  @override
  _MemberScreenState createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  String? selectedGroup;
  late Stream<List<String>> groupsStream;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;

    groupsStream = FirebaseFirestore.instance
        .collection('groups')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc['name'] as String).toList());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Member Feed'),
          backgroundColor: Colors.deepPurple,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.deepPurple),
                child: Text(
                  'Groups',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              StreamBuilder<List<String>>(
                stream: groupsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  var groups = snapshot.data!;
                  return Column(
                    children: groups.map((group) {
                      return _buildDrawerItem(context, group, group);
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ✅ ADDED: Display current group info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                selectedGroup == null ? 'All Posts' : 'Showing: $selectedGroup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: selectedGroup == null
                    ? FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('timestamp', descending: true) // ✅ Confirmed sorting
                        .snapshots()
                    : FirebaseFirestore.instance
                        .collection('posts')
                        .where('groupName', isEqualTo: selectedGroup)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var posts = snapshot.data!.docs;

                  if (posts.isEmpty) {
                    return Center(child: Text('No posts available'));
                  }

                  return ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      var post = posts[index];
                      return _buildPostItem(post);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, String? group) {
    return ListTile(
      title: Text(title),
      onTap: () {
        setState(() {
          selectedGroup = group;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildPostItem(QueryDocumentSnapshot post) {
    Map<String, dynamic> data = post.data() as Map<String, dynamic>;
    List likedBy = data['likedBy'] ?? [];
    bool isLiked = _user != null && likedBy.contains(_user!.uid);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? 'No Title',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(data['content'] ?? 'No Content'),
            if (data['mediaUrl'] != null) ...[
              SizedBox(height: 10),
              Image.network(data['mediaUrl'], height: 200, fit: BoxFit.cover),
            ],
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: isLiked ? Colors.blue : null,
                      ),
                      onPressed: () async {
                        if (!isLiked) {
                          await _likePost(post.id, likedBy);

                          // ✅ ADDED: immediate visual feedback
                          setState(() {});
                        }
                      },
                    ),
                    Text('${likedBy.length}'),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.comment_outlined),
                  onPressed: () => _showCommentSheet(post.id),
                ),
                IconButton(
                  icon: Icon(Icons.share_outlined),
                  onPressed: () {
                    Share.share('${data['title'] ?? ''}\n\n${data['content'] ?? ''}');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _likePost(String postId, List likedBy) async {
    final userId = _user?.uid;
    if (userId == null || likedBy.contains(userId)) return;

    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likedBy': FieldValue.arrayUnion([userId]),
      'likes': FieldValue.increment(1),
    });
  }

  void _showCommentSheet(String postId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        TextEditingController commentController = TextEditingController();
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commentController,
                decoration: InputDecoration(labelText: 'Add a Comment'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _addComment(postId, commentController.text);
                  Navigator.of(context).pop();
                },
                child: Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addComment(String postId, String comment) {
    if (comment.isNotEmpty) {
      FirebaseFirestore.instance.collection('comments').add({
        'postId': postId,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
