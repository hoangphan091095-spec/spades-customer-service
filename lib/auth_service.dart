// auth_service.dart - CORRECTED VERSION
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class User {
  final String username;
  final String password;
  final String phone;
  final String name;
  final String? profilePictureUrl;

  User({
    required this.username,
    required this.password,
    required this.phone,
    required this.name,
    this.profilePictureUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phone': phone,
      'name': name,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      profilePictureUrl: json['profilePictureUrl'],
    );
  }
}

class Customer {
  final String name;
  final String phone;
  final List<dynamic> gameHistory;
  final Map<String, dynamic> elorank;

  Customer({
    required this.name,
    required this.phone,
    required this.gameHistory,
    required this.elorank,
  });

  static Customer fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['Name'] ?? '',
      phone: json['Phone'] ?? '',
      gameHistory: json['GameHistory'] ?? [],
      elorank: json['Elorank'] ?? {},
    );
  }
}

class RoundDrinkData {
  final String phone;
  final int top1;
  final int top2;
  final int top3;
  final int freeRound;
  final List<dynamic> freeRoundHistory;
  final int freeDrink;
  final List<dynamic> freeDrinkHistory;

  RoundDrinkData({
    required this.phone,
    required this.top1,
    required this.top2,
    required this.top3,
    required this.freeRound,
    required this.freeRoundHistory,
    required this.freeDrink,
    required this.freeDrinkHistory,
  });

  static RoundDrinkData fromJson(Map<String, dynamic> json) {
    return RoundDrinkData(
      phone: json['phone'] ?? '',
      top1: json['top1'] ?? 0,
      top2: json['top2'] ?? 0,
      top3: json['top3'] ?? 0,
      freeRound: json['freeRound'] ?? 0,
      freeRoundHistory: json['freeRoundHistory'] ?? [],
      freeDrink: json['freeDrink'] ?? 0,
      freeDrinkHistory: json['freeDrinkHistory'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'top1': top1,
      'top2': top2,
      'top3': top3,
      'freeRound': freeRound,
      'freeRoundHistory': freeRoundHistory,
      'freeDrink': freeDrink,
      'freeDrinkHistory': freeDrinkHistory,
    };
  }
}

class AuthService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  Customer? _currentCustomer;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  Customer? get currentCustomer => _currentCustomer;
  bool get isLoading => _isLoading;

  Future<void> initializeData() async {
    //await _uploadUserData();
    // await _uploadCustomerData();
    //await _uploadRoundDrinkData();
    print('📝 Upload functions are currently disabled');
  }

  Future<void> _uploadUserData() async {
    try {
      final usersRef = _firestore.collection('users');

      // Add admin user
      await usersRef.doc('admin').set({
        'username': 'admin',
        'password': '123456',
        'phone': 'admin',
        'name': 'Administrator',
      });

      // Add all users from your JSON
      List<User> users = [
        User(username: "0936850683", password: "1", phone: "0936850683", name: "Khánh Duy 0683"),
      ];

      for (var user in users) {
        if (user.username.isNotEmpty) {
          await usersRef.doc(user.username).set(user.toJson());
        }
      }
    } catch (e) {
      print('Error uploading user data: $e');
    }
  }

  Future<void> _uploadCustomerData() async {
    try {
      final customersRef = _firestore.collection('customers');

      // Use simple Map structure instead of Customer class
      List<Map<String, dynamic>> customers = [
        {
          "Name": "Khánh Duy 0683",
          "Phone": "0936850683",
          "GameHistory": [],
          "Elorank": {
            "Numbrank": null,
            "Medal": null
          }
        }
      ];

      int uploadedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      for (var customer in customers) {
        final phone = customer['Phone']?.toString().trim() ?? '';

        // Skip if phone is empty or invalid
        if (phone.isEmpty) {
          print('❌ SKIPPED - Empty phone: ${customer['Name']}');
          errorCount++;
          continue;
        }

        // Skip if phone is "undefined" or other invalid values
        if (phone == 'undefined' || phone == 'null') {
          print('❌ SKIPPED - Invalid phone: ${customer['Name']}');
          errorCount++;
          continue;
        }

        try {
          final customerDoc = await customersRef.doc(phone).get();
          if (!customerDoc.exists) {
            await customersRef.doc(phone).set(customer);
            uploadedCount++;
            print('✅ UPLOADED: ${customer['Name']} ($phone)');
          } else {
            skippedCount++;
            print('⏩ SKIPPED (exists): ${customer['Name']}');
          }
        } catch (e) {
          errorCount++;
          print('❌ ERROR uploading ${customer['Name']}: $e');
        }
      }

      print('🎉 Customer upload completed!');
      print('   Uploaded: $uploadedCount');
      print('   Skipped (exists): $skippedCount');
      print('   Errors: $errorCount');
      print('   Total processed: ${customers.length}');
    } catch (e) {
      print('💥 Error uploading customer data: $e');
    }
  }

  Future<void> _uploadRoundDrinkData() async {
    try {
      final roundDrinkRef = _firestore.collection('Round&Drink');

      // Your Round & Drink data - using the exact structure you provided
      Map<String, dynamic> roundDrinkData = {};

      int uploadedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      print('🚀 Starting Round & Drink data upload...');
      print('📊 Total phone numbers to process: ${roundDrinkData.length}');

      // Iterate through each phone number in the map
      roundDrinkData.forEach((phone, data) async {
        try {
          // Skip if phone is empty or invalid
          if (phone.isEmpty) {
            print('❌ SKIPPED - Empty phone key');
            errorCount++;
            return;
          }

          if (phone == 'undefined' || phone == 'null') {
            print('❌ SKIPPED - Invalid phone key: $phone');
            errorCount++;
            return;
          }

          final roundDrinkDoc = await roundDrinkRef.doc(phone).get();
          if (!roundDrinkDoc.exists) {
            await roundDrinkRef.doc(phone).set(data);
            uploadedCount++;
            print('✅ UPLOADED Round&Drink: $phone');
            print('   - Top1: ${data['top1']}, Top2: ${data['top2']}, Top3: ${data['top3']}');
            print('   - Free Round: ${data['freeRound']}, Free Drink: ${data['freeDrink']}');
            print('   - Round History: ${(data['freeRoundHistory'] as List).length} items');
            print('   - Drink History: ${(data['freeDrinkHistory'] as List).length} items');
          } else {
            skippedCount++;
            print('⏩ SKIPPED (exists) Round&Drink: $phone');
          }
        } catch (e) {
          errorCount++;
          print('❌ ERROR uploading Round&Drink for $phone: $e');
        }
      });

      // Wait a bit for all async operations to complete
      await Future.delayed(Duration(seconds: 2));

      print('🎉 Round & Drink upload completed!');
      print('   Uploaded: $uploadedCount');
      print('   Skipped (exists): $skippedCount');
      print('   Errors: $errorCount');
      print('   Total processed: ${roundDrinkData.length}');

    } catch (e) {
      print('💥 Error uploading Round & Drink data: $e');
    }
  }

  // FIX: This login method MUST be inside the AuthService class
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check for admin
      if (username == 'admin' && password == '123456') {
        _currentUser = User(
          username: 'admin',
          password: '123456',
          phone: 'admin',
          name: 'Administrator',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Check regular users
      final userDoc = await _firestore.collection('users').doc(username).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData?['password'] == password) {
          _currentUser = User.fromJson(userData!);

          // Find customer data
          final customerDoc = await _firestore.collection('customers').doc(username).get();
          if (customerDoc.exists) {
            _currentCustomer = Customer.fromJson(customerDoc.data()!);
          }

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // FIX: This logout method MUST be inside the AuthService class
  void logout() {
    _currentUser = null;
    _currentCustomer = null;
    notifyListeners();
  }

  // Method to upload profile picture
// Method to upload profile picture
  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      // First, check if user has an existing profile picture
      String? oldImageUrl = _currentUser?.profilePictureUrl;

      // Create a unique filename
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile-pictures/$userId/$fileName');

      // Upload the new file
      await ref.putFile(imageFile);

      // Get the download URL
      final downloadURL = await ref.getDownloadURL();

      // Update user document with the new URL
      await _firestore.collection('users').doc(userId).update({
        'profilePictureUrl': downloadURL,
      });

      // Delete the old profile picture if it exists
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final oldRef = _storage.refFromURL(oldImageUrl);
          await oldRef.delete();
          print('✅ Old profile picture deleted: $oldImageUrl');
        } catch (e) {
          // Don't fail the whole operation if deletion fails
          print('⚠️ Could not delete old profile picture: $e');
        }
      }

      // Update current user
      if (_currentUser != null) {
        _currentUser = User(
          username: _currentUser!.username,
          password: _currentUser!.password,
          phone: _currentUser!.phone,
          name: _currentUser!.name,
          profilePictureUrl: downloadURL,
        );
        notifyListeners();
      }

      return downloadURL;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  // Method to pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Method to take photo with camera
  Future<File?> takePhotoWithCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  // Method to delete profile picture
  Future<void> deleteProfilePicture(String userId, String imageUrl) async {
    try {
      // Extract the path from the URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'profilePictureUrl': null,
      });

      // Update current user
      if (_currentUser != null) {
        _currentUser = User(
          username: _currentUser!.username,
          password: _currentUser!.password,
          phone: _currentUser!.phone,
          name: _currentUser!.name,
          profilePictureUrl: null,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting profile picture: $e');
    }
  }
} // FIX: This is the correct closing brace for the AuthService class. NO MORE CODE AFTER THIS.