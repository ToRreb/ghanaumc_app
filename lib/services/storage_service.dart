import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Pick an image and upload it
  Future<String?> uploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null; // User canceled picking image

    File file = File(image.path);
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Upload file
      TaskSnapshot snapshot = await _storage.ref('uploads/$fileName').putFile(file);
      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }
}
