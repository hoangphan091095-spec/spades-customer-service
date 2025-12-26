// free_drink_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class FreeDrinkHistoryScreen extends StatefulWidget {
  @override
  _FreeDrinkHistoryScreenState createState() => _FreeDrinkHistoryScreenState();
}

class _FreeDrinkHistoryScreenState extends State<FreeDrinkHistoryScreen> {
  final int _pageSize = 20;
  int _currentLimit = 20;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allDrinkHistory = [];
  bool _isInitialLoading = true;

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
          .collection('Round&Drink')
          .doc(currentUser?.username)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final drinkHistory = List<Map<String, dynamic>>.from(data?['freeDrinkHistory'] ?? []);

        // Filter out entries with "Tour free rounds" text and take latest 30
        final filteredHistory = drinkHistory
            .where((entry) => !_containsTourFreeRounds(entry['text']?.toString() ?? ''))
            .toList();

        // Sort by date descending (newest first) and take max 30
        filteredHistory.sort((a, b) => _compareDates(b['date'], a['date']));
        final limitedHistory = filteredHistory.take(30).toList();

        setState(() {
          _allDrinkHistory = limitedHistory;
          _isInitialLoading = false;
          _hasMoreData = _currentLimit < _allDrinkHistory.length;
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

  bool _containsTourFreeRounds(String text) {
    return text.toLowerCase().contains('tour') && text.toLowerCase().contains('free rounds');
  }

  int _compareDates(dynamic dateA, dynamic dateB) {
    final String dateStrA = dateA?.toString() ?? '';
    final String dateStrB = dateB?.toString() ?? '';
    return dateStrA.compareTo(dateStrB);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Add delay for loading effect
    await Future.delayed(Duration(milliseconds: 1500));

    setState(() {
      _currentLimit += _pageSize;
      _isLoadingMore = false;
      _hasMoreData = _currentLimit < _allDrinkHistory.length;
    });
  }

  Color _getTextColor(String text) {
    if (text.contains('+')) {
      return Colors.green;
    } else if (text.contains('-')) {
      return Color(0xFFDC2626);
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final displayedHistory = _allDrinkHistory.take(_currentLimit).toList();

    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Lịch sử Nước khuyến mại',
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
      body: _isInitialLoading
          ? _buildLoadingState()
          : displayedHistory.isEmpty
          ? _buildEmptyState()
          : GlowingOverscrollIndicator(
        axisDirection: AxisDirection.down,
        color: Color(0xFFDC2626).withOpacity(0.3),
        child: Column(
          children: [
            // Header row
            _buildHeaderRow(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: displayedHistory.length + (_hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == displayedHistory.length && _hasMoreData) {
                    return _buildLoadMoreItem();
                  }
                  final history = displayedHistory[index];
                  return _buildHistoryRow(history);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Date',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.grey[600],
            margin: EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Description',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> history) {
    final date = history['date']?.toString() ?? '--/--/----';
    final text = history['text']?.toString() ?? '';
    final textColor = _getTextColor(text);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[700],
            margin: EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            flex: 3,
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Loading more history...',
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
                  'Load more',
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFDC2626)),
          SizedBox(height: 16),
          Text(
            'Loading drink history...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
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
            Icons.local_drink,
            color: Colors.grey[600],
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No Drink History',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your drink history will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}