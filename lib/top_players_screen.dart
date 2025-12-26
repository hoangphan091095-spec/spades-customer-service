import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TopPlayersScreen extends StatefulWidget {
  @override
  _TopPlayersScreenState createState() => _TopPlayersScreenState();
}

class _TopPlayersScreenState extends State<TopPlayersScreen> {
  List<Map<String, dynamic>> _topPlayers = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTopPlayers();
  }

  Future<void> _loadTopPlayers() async {
    try {
      print('🔄 Loading top players basic data...');

      final customersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .get();

      print('📊 Found ${customersSnapshot.docs.length} customers');

      List<Map<String, dynamic>> allPlayers = [];

      // Step 1: Get all players with basic data (NO profile pictures yet)
      for (var doc in customersSnapshot.docs) {
        final customer = doc.data();
        final eloRank = customer['Elorank'] ?? {};
        final numbRank = eloRank['Numbrank'];

        // Only include players with valid Numbrank
        if (numbRank != null && numbRank is int) {
          allPlayers.add({
            'name': customer['Name'] ?? 'Unknown',
            'phone': customer['Phone']?.toString() ?? '',
            'numbRank': numbRank,
            'medal': eloRank['Medal'] ?? 'No Rank',
            'gameHistory': customer['GameHistory'] ?? [],
            'profilePictureUrl': null, // Will be filled later in background
          });
        }
      }

      // Step 2: Sort by Numbrank (descending) and take top 10
      allPlayers.sort((a, b) => b['numbRank'].compareTo(a['numbRank']));
      final top10Players = allPlayers.take(10).toList();

      print('🏆 Top 10 players identified');

      // Step 3: Update UI immediately with basic data
      setState(() {
        _topPlayers = top10Players;
        _isLoading = false;
      });

      // Step 4: Load profile pictures for top 3 in background
      if (top10Players.length >= 3) {
        _loadTop3ProfilePicturesInBackground(top10Players);
      }

      print('✅ Basic player data loaded, UI updated');

    } catch (e) {
      print('💥 Error loading top players: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTop3ProfilePicturesInBackground(List<Map<String, dynamic>> players) async {
    print('📸 Background: Loading profile pictures for top 3...');

    // Create a copy to avoid modifying the original while iterating
    final updatedPlayers = List<Map<String, dynamic>>.from(players);

    // Fetch pictures for top 3 players
    for (int i = 0; i < 3 && i < updatedPlayers.length; i++) {
      final phone = updatedPlayers[i]['phone'];

      if (phone.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(phone)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            final profilePictureUrl = userData?['profilePictureUrl']?.toString();

            if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
              // Update the player data with profile picture URL
              updatedPlayers[i]['profilePictureUrl'] = profilePictureUrl;

              // Update UI for this specific player only
              if (mounted) {
                setState(() {
                  _topPlayers[i] = Map<String, dynamic>.from(updatedPlayers[i]);
                });
              }

              print('✅ Background: Loaded picture for ${updatedPlayers[i]['name']}');
            } else {
              print('ℹ️ Background: No profile picture for ${updatedPlayers[i]['name']}');
            }
          } else {
            print('⚠️ Background: No user document for phone: $phone');
          }
        } catch (e) {
          // Silently fail for background loading - don't show errors to user
          print('⚠️ Background: Picture load failed for index $i: $e');
        }
      }
    }

    print('✅ Background: Profile picture loading complete');
  }

  Widget _buildPlayerAvatar({
    required String? profilePictureUrl,
    required Color borderColor,
    required double size,
    bool hasCrown = false,
  }) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: size == 100 ? 4 : 3,
            ),
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                borderColor.withOpacity(0.3),
              ],
            ),
          ),
          child: ClipOval(
            child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: profilePictureUrl,
              placeholder: (context, url) => Container(
                color: Colors.white.withOpacity(0.1),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * 0.5,
                  ),
                ),
              ),
              fit: BoxFit.cover,
            )
                : Container(
              color: Colors.white.withOpacity(0.1),
              child: Center(
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ),
            ),
          ),
        ),
        if (hasCrown)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFD700),
              ),
              child: Icon(
                Icons.workspace_premium,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopThreePodium() {
    if (_topPlayers.length < 3) return SizedBox();

    final top1 = _topPlayers[0];
    final top2 = _topPlayers[1];
    final top3 = _topPlayers[2];

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F2937),
            Color(0xFF374151),
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
          Text(
            'TOP 3 PLAYERS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              Expanded(
                child: Column(
                  children: [
                    _buildPlayerAvatar(
                      profilePictureUrl: top2['profilePictureUrl'],
                      borderColor: Color(0xFFC0C0C0),
                      size: 70,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFC0C0C0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🥈',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      top2['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      top2['medal'],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${top2['numbRank']}',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 1st Place
              Expanded(
                child: Column(
                  children: [
                    _buildPlayerAvatar(
                      profilePictureUrl: top1['profilePictureUrl'],
                      borderColor: Color(0xFFFFD700),
                      size: 100,
                      hasCrown: true,
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '🥇',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      top1['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      top1['medal'],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${top1['numbRank']}',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 3rd Place
              Expanded(
                child: Column(
                  children: [
                    _buildPlayerAvatar(
                      profilePictureUrl: top3['profilePictureUrl'],
                      borderColor: Color(0xFFCD7F32),
                      size: 70,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFCD7F32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🥉',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      top3['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      top3['medal'],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${top3['numbRank']}',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(int index, Map<String, dynamic> player) {
    final rank = index + 1;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank - Fixed width
          Container(
            width: 40,
            alignment: Alignment.centerLeft,
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Name - Flexible width
          Expanded(
            flex: 3,
            child: Text(
              player['name'],
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Medal - Fixed width
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(
              player['medal'],
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // NumbRank - Fixed width
          Container(
            width: 60,
            alignment: Alignment.centerRight,
            child: Text(
              '${player['numbRank']}',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaders() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // Rank header
          Container(
            width: 40,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rank',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Name header
          Expanded(
            flex: 3,
            child: Text(
              'Name',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Medal header
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(
              'Medal',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ELO header
          Container(
            width: 60,
            alignment: Alignment.centerRight,
            child: Text(
              'ELO',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFDC2626)),
          SizedBox(height: 16),
          Text(
            'Loading top players...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Failed to load top players',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadTopPlayers,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            color: Colors.grey[600],
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No Players Found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Player rankings will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingPlayers = _topPlayers.length > 3
        ? _topPlayers.sublist(3)
        : [];

    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Bảng xếp hạng',
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
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _topPlayers.isEmpty
          ? _buildEmptyState()
          : GlowingOverscrollIndicator(
        axisDirection: AxisDirection.down,
        color: Color(0xFFDC2626).withOpacity(0.3),
        child: Column(
          children: [
            // Top 3 Podium
            _buildTopThreePodium(),

            // Remaining Players Section
            if (remainingPlayers.isNotEmpty) ...[
              // Section Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'RUNNER UP',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Table Headers
              _buildTableHeaders(),

              // Remaining Players List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 16),
                  itemCount: remainingPlayers.length,
                  itemBuilder: (context, index) {
                    return _buildPlayerRow(index + 3, remainingPlayers[index]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}