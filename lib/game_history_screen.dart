import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class GameHistoryScreen extends StatefulWidget {
  @override
  _GameHistoryScreenState createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final int _pageSize = 20;
  int _currentLimit = 20;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allGameHistory = [];
  bool _isInitialLoading = true;
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser?.username)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _customerData = docSnapshot.data() as Map<String, dynamic>;
          _allGameHistory = List.from(_customerData!['GameHistory'] ?? []);
          _isInitialLoading = false;
          _hasMoreData = _currentLimit < _allGameHistory.length;
        });
      } else {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(Duration(milliseconds: 1000));

    setState(() {
      _currentLimit += _pageSize;
      _isLoadingMore = false;
      _hasMoreData = _currentLimit < _allGameHistory.length;
    });
  }

  // Helper method to parse position from any format
  int _parsePosition(dynamic position) {
    if (position == null) return 0;

    if (position is int) {
      return position;
    }

    if (position is String) {
      // Handle text positions like "1st", "2nd", "3rd"
      if (position.contains('1') || position.toLowerCase().contains('first')) return 1;
      if (position.contains('2') || position.toLowerCase().contains('second')) return 2;
      if (position.contains('3') || position.toLowerCase().contains('third')) return 3;

      // Try to extract number from text
      final match = RegExp(r'\d+').firstMatch(position);
      if (match != null) {
        final matchedString = match.group(0);
        if (matchedString != null) {
          return int.tryParse(matchedString) ?? 0;
        }
      }

      return 0;
    }

    return 0;
  }

  // Helper method to parse Elo change from any format
  int _parseEloChange(dynamic eloChange) {
    if (eloChange == null) return 0;

    if (eloChange is int) {
      return eloChange;
    }

    if (eloChange is String) {
      // Handle negative numbers in strings like "-20"
      return int.tryParse(eloChange) ?? 0;
    }

    if (eloChange is double) {
      return eloChange.toInt();
    }

    return 0;
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF111827),
        appBar: AppBar(
          backgroundColor: Color(0xFF1F2937),
          title: Text(
            'Lịch sử đấu',
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFDC2626)),
        ),
      );
    }

    if (_customerData == null) {
      return Scaffold(
        backgroundColor: Color(0xFF111827),
        appBar: AppBar(
          backgroundColor: Color(0xFF1F2937),
          title: Text(
            'Lịch sử đấu',
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
        body: Center(
          child: Text(
            'No customer data found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Get the last N games (newest first)
    final displayedHistory = _allGameHistory.reversed.take(_currentLimit).toList();

    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Lịch sử đấu',
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
      body: Column(
        children: [
          _buildProfileHeader(_customerData!),
          Expanded(
            child: displayedHistory.isEmpty
                ? _buildEmptyState()
                : GlowingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              color: Color(0xFFDC2626).withOpacity(0.3),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: displayedHistory.length + (_hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == displayedHistory.length && _hasMoreData) {
                    return _buildLoadMoreItem();
                  }
                  final game = displayedHistory[index];
                  return _buildGameHistoryRow(game);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> customer) {
    final eloRank = customer['Elorank'] ?? {};
    final numbRank = eloRank['Numbrank'];
    final medal = eloRank['Medal'] ?? 'No Rank';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDC2626),
            Color(0xFF991B1B),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 8),

          Text(
            customer['Name'] ?? 'Unknown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 20,
                      ),
                      SizedBox(height: 2),
                      Text(
                        medal.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Medal',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),

                Expanded(
                  child: Column(
                    children: [
                      Text(
                        numbRank?.toString() ?? '--',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Elo Rating',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHistoryRow(Map<String, dynamic> game) {
    final date = game['Date'] ?? '--/--/----';
    final time = game['Time'] ?? '--:--';

    // Use the helper methods to handle both text and numbers
    final position = _parsePosition(game['Position']);
    final eloChange = _parseEloChange(game['Elochange']);

    String rankDisplay;
    Color rankColor;

    // Handle position display based on the parsed position
    if (position <= 3 && position >= 1) {
      switch (position) {
        case 1:
          rankDisplay = '🥇 1st';
          rankColor = Colors.amber;
          break;
        case 2:
          rankDisplay = '🥈 2nd';
          rankColor = Colors.grey;
          break;
        case 3:
          rankDisplay = '🥉 3rd';
          rankColor = Color(0xFFCD7F32);
          break;
        default:
          rankDisplay = '🥇 1st';
          rankColor = Colors.amber;
      }
    } else {
      // If position is text or invalid, use the original value as fallback
      final positionText = game['Position']?.toString() ?? '0';
      rankDisplay = positionText;
      rankColor = Colors.white;
    }

    final eloColor = eloChange >= 0 ? Colors.green : Color(0xFFDC2626);
    final eloPrefix = eloChange >= 0 ? '+' : '';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 30,
            color: Colors.grey[700],
            margin: EdgeInsets.symmetric(horizontal: 12),
          ),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rank',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  rankDisplay,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 30,
            color: Colors.grey[700],
            margin: EdgeInsets.symmetric(horizontal: 12),
          ),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Elo Change',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '$eloPrefix$eloChange',
                  style: TextStyle(
                    color: eloColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreItem() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          if (_isLoadingMore)
            Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Loading more games...',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Icon(
                  Icons.arrow_downward,
                  color: Colors.grey[500],
                  size: 20,
                ),
                SizedBox(height: 4),
                Text(
                  'Loading more history...',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlowingOverscrollIndicator(
      axisDirection: AxisDirection.down,
      color: Color(0xFFDC2626).withOpacity(0.3),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  color: Colors.grey[600],
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'No Game History',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your game history will appear here',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}