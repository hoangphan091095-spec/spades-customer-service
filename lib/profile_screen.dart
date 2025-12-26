// profile_screen.dart - COMPLETE VERSION with fade-in animation for skip button
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'auth_service.dart';
import 'free_drink_history_screen.dart';
import 'free_round_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;
  bool _isUploadingImage = false;

  // Video player variables
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _showVideo = true;
  int _secondsPassed = 0;
  bool _canSkip = false;

  // Animation variables
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showSkipButton = false;

  // New state variables for Round & Drink data
  int _freeDrink = 0;
  int _freeRound = 0;
  int _top1Wins = 0;
  bool _isLoadingRoundDrink = true;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _loadRoundDrinkData();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Get video URL from Firebase Storage
      final videoRef = FirebaseStorage.instance
          .ref()
          .child('clipnoiquy')
          .child('clip nội quy.mp4');

      final videoUrl = await videoRef.getDownloadURL();

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControls: false, // Disable all controls
        allowPlaybackSpeedChanging: false,
        allowedScreenSleep: false,
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFFDC2626),
            ),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Color(0xFFDC2626),
          handleColor: Color(0xFFDC2626),
          backgroundColor: Colors.grey[700]!,
          bufferedColor: Colors.grey[500]!,
        ),
        // Add these options to completely disable seeking
        allowMuting: false,
        allowFullScreen: false,
        showControlsOnInitialize: false,
      );

      // Start timer to track 5 seconds
      _startSkipTimer();

      setState(() {});
    } catch (e) {
      print('Error loading video: $e');
      // If video fails to load, skip to main screen
      _skipVideo();
    }
  }

  void _startSkipTimer() {
    // Update timer every second
    _videoPlayerController?.addListener(() {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        final currentPosition = _videoPlayerController!.value.position;
        setState(() {
          _secondsPassed = currentPosition.inSeconds;
          _canSkip = _secondsPassed >= 5;

          // Trigger animation when becomes skippable
          if (_canSkip && !_showSkipButton) {
            _showSkipButton = true;
            _animationController.forward();
          }
        });
      }
    });
  }

  void _skipVideo() {
    if (_chewieController != null) {
      _chewieController!.pause();
    }
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
    }
    setState(() {
      _showVideo = false;
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn ảnh đại diện',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.white),
                title: Text(
                  'Chọn từ thư viện',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _selectImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  'Chụp ảnh mới',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _takePhoto();
                },
              ),
              if (Provider.of<AuthService>(context, listen: false)
                  .currentUser
                  ?.profilePictureUrl != null)
                ListTile(
                  leading: Icon(Icons.delete, color: Color(0xFFDC2626)),
                  title: Text(
                    'Xóa ảnh hiện tại',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteImage();
                  },
                ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Hủy',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectImageFromGallery() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageFile = await authService.pickImageFromGallery();
      if (imageFile != null) {
        final url = await authService.uploadProfilePicture(imageFile, user.username);
        if (url != null) {
          _showSuccess('Cập nhật ảnh đại diện thành công!');
        }
      }
    } catch (e) {
      _showError('Không thể tải ảnh lên: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageFile = await authService.takePhotoWithCamera();
      if (imageFile != null) {
        final url = await authService.uploadProfilePicture(imageFile, user.username);
        if (url != null) {
          _showSuccess('Cập nhật ảnh đại diện thành công!');
        }
      }
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _deleteImage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null || user.profilePictureUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Xóa ảnh đại diện',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa ảnh đại diện hiện tại?',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isUploadingImage = true;
              });

              try {
                await authService.deleteProfilePicture(
                    user.username,
                    user.profilePictureUrl!
                );
                _showSuccess('Đã xóa ảnh đại diện!');
              } catch (e) {
                _showError('Không thể xóa ảnh: $e');
              } finally {
                setState(() {
                  _isUploadingImage = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Xóa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRoundDrinkData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser?.username != null) {
        final roundDrinkDoc = await FirebaseFirestore.instance
            .collection('Round&Drink')
            .doc(currentUser!.username)
            .get();

        if (roundDrinkDoc.exists) {
          final data = roundDrinkDoc.data();
          setState(() {
            _freeDrink = data?['freeDrink'] ?? 0;
            _freeRound = data?['freeRound'] ?? 0;
            _top1Wins = data?['top1'] ?? 0;
            _isLoadingRoundDrink = false;
          });
        } else {
          setState(() {
            _isLoadingRoundDrink = false;
          });
        }
      } else {
        setState(() {
          _isLoadingRoundDrink = false;
        });
      }
    } catch (e) {
      print('Error loading Round & Drink data: $e');
      setState(() {
        _isLoadingRoundDrink = false;
      });
    }
  }

  Future<void> _changePassword(BuildContext dialogContext) async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Mật khẩu mới không khớp');
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      _showError('Mật khẩu mới không được để trống');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        _showError('Không tìm thấy người dùng');
        return;
      }

      // Verify current password
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.username)
          .get();

      if (!userDoc.exists) {
        _showError('Không tìm thấy dữ liệu người dùng');
        return;
      }

      final userData = userDoc.data();
      if (userData?['password'] != _currentPasswordController.text) {
        _showError('Mật khẩu hiện tại không đúng');
        return;
      }

      // Update password in Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.username)
          .update({
        'password': _newPasswordController.text,
      });

      // Show success message
      _showSuccess('Đổi mật khẩu thành công');

      // Clear fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Close the dialog
      Navigator.pop(dialogContext);

    } catch (e) {
      _showError('Lỗi khi đổi mật khẩu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Tính năng sắp ra mắt',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tính năng "$featureName" đang được phát triển và sẽ sớm có mặt trong phiên bản tới.',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Color(0xFF1F2937),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Đổi mật khẩu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Password
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF374151),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                SizedBox(height: 16),

                // New Password
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        setState(() => _obscureNewPassword = !_obscureNewPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF374151),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                SizedBox(height: 16),

                // Confirm Password
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.lock_reset, color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF374151),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Hủy',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton(
              onPressed: _isChangingPassword ? null : () => _changePassword(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isChangingPassword
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text('Đổi mật khẩu'),
            ),
          ],
        );
      },
    ).then((_) {
      // Reset password visibility states when dialog closes
      _obscureCurrentPassword = true;
      _obscureNewPassword = true;
      _obscureConfirmPassword = true;
      _isChangingPassword = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Video screen
  Widget _buildVideoScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          if (_chewieController != null)
            Chewie(controller: _chewieController!)
          else
            Center(
              child: CircularProgressIndicator(
                color: Color(0xFFDC2626),
              ),
            ),

          // Skip button overlay (only shows after 5 seconds with fade-in)
          if (_showSkipButton)
            Positioned(
              top: 40,
              right: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: _skipVideo,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFFDC2626).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showVideo) {
      return _buildVideoScreen();
    }

    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final customer = authService.currentCustomer;

    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Hồ sơ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFDC2626),
                    Color(0xFF991B1B),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture with upload overlay
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _isUploadingImage
                              ? Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : ClipOval(
                            child: user?.profilePictureUrl != null
                                ? CachedNetworkImage(
                              imageUrl: user!.profilePictureUrl!,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildDefaultProfileIcon(),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                                : _buildDefaultProfileIcon(),
                          ),
                        ),
                        // Upload overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    customer?.name ?? user?.name ?? 'Người chơi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    user?.phone ?? 'Chưa có số điện thoại',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // Stats Cards
            Row(
              children: [
                _buildStatCard('Top 1 đã thắng', '$_top1Wins', Icons.emoji_events),
                SizedBox(width: 12),
                _buildStatCard('Hạng hiện tại', customer?.elorank['Medal'] ?? 'Chưa có hạng', Icons.workspace_premium),
              ],
            ),

            SizedBox(height: 20),

            // Round & Drink Cards
            Column(
              children: [
                _buildRoundDrinkCard(
                  'Nước khuyến mại',
                  _freeDrink.toString(),
                  Icons.local_drink,
                  _isLoadingRoundDrink,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FreeDrinkHistoryScreen()),
                    );
                  },
                ),
                SizedBox(height: 12),
                _buildRoundDrinkCard(
                  'Free round còn lại',
                  _freeRound.toString(),
                  Icons.casino_outlined,
                  _isLoadingRoundDrink,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FreeRoundHistoryScreen()),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 30),

            // Account Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cài đặt tài khoản',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSettingItem(
                    'Đổi mật khẩu',
                    'Cập nhật mật khẩu tài khoản của bạn',
                    Icons.lock,
                    _showChangePasswordDialog,
                  ),
                  _buildSettingItem(
                    'Cài đặt riêng tư',
                    'Quản lý tùy chọn riêng tư',
                    Icons.privacy_tip,
                        () => _showComingSoonDialog('Cài đặt riêng tư'),
                  ),
                  _buildSettingItem(
                    'Cài đặt thông báo',
                    'Kiểm soát tùy chọn thông báo',
                    Icons.notifications,
                        () => _showComingSoonDialog('Cài đặt thông báo'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Personal Info Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow('Tên đăng nhập', user?.username ?? 'N/A'),
                  _buildInfoRow('Tên người dùng', customer?.name ?? user?.name ?? 'N/A'),
                  _buildInfoRow('Trạng thái', 'Hoạt động'),
                ],
              ),
            ),

            SizedBox(height: 30),

            // Logout Button
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  authService.logout();
                  Navigator.of(context).pushReplacementNamed('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF374151),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultProfileIcon() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Color(0xFFDC2626), size: 24),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundDrinkCard(String title, String value, IconData icon, bool isLoading, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFDC2626).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xFFDC2626), size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  isLoading
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFDC2626),
                    ),
                  )
                      : Text(
                    value,
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFDC2626).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Color(0xFFDC2626), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}