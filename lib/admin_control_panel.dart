// admin_control_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'admin_schedule_dialog.dart';

class AdminControlPanel extends StatefulWidget {
  @override
  _AdminControlPanelState createState() => _AdminControlPanelState();
}

class _AdminControlPanelState extends State<AdminControlPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _gameDateController = TextEditingController();
  final TextEditingController _gameTimeController = TextEditingController();
  final TextEditingController _gamePositionController = TextEditingController();
  final TextEditingController _gameEloChangeController = TextEditingController();
  final TextEditingController _roundAmountController = TextEditingController();
  final TextEditingController _roundDateController = TextEditingController();
  final TextEditingController _drinkAmountController = TextEditingController();
  final TextEditingController _drinkDateController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _gameHistory = [];
  List<Map<String, dynamic>> _roundHistory = [];
  List<Map<String, dynamic>> _drinkHistory = [];
  int _freeRoundCount = 0;
  int _freeDrinkCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize date controllers with current date
    _gameDateController.text = _getCurrentDate();
    _roundDateController.text = _getCurrentDate();
    _drinkDateController.text = _getCurrentDate();
    _gameTimeController.text = _getCurrentTime();
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resetRanks() async {
    if (_isLoading) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Reset Ranks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will reset ALL player ranks:\n\n'
              '• Top 10 players will get 1260 ELO\n'
              '• All other players will get 1200 ELO\n'
              '• All medals will be set to "Đồng"\n\n'
              'This action cannot be undone!',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performRankReset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRankReset() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Get all customers and find top 10 by Numbrank
      final customersSnapshot = await _firestore.collection('customers').get();
      final allPlayers = <Map<String, dynamic>>[];

      for (var doc in customersSnapshot.docs) {
        final customer = doc.data();
        final eloRank = customer['Elorank'] ?? {};
        final numbRank = eloRank['Numbrank'];

        if (numbRank != null && numbRank is int) {
          allPlayers.add({
            'id': doc.id,
            'numbRank': numbRank,
          });
        }
      }

      // Sort by Numbrank (descending) and take top 10
      allPlayers.sort((a, b) => b['numbRank'].compareTo(a['numbRank']));
      final top10Ids = allPlayers.take(10).map((player) => player['id']).toSet();

      // Step 2: Reset all players
      int processed = 0;
      int errors = 0;

      for (var doc in customersSnapshot.docs) {
        try {
          final isTop10 = top10Ids.contains(doc.id);
          final newRank = isTop10 ? 1260 : 1200;

          await _firestore.collection('customers').doc(doc.id).update({
            'Elorank': {
              'Medal': 'Đồng',
              'Numbrank': newRank,
            },
          });

          processed++;
        } catch (e) {
          errors++;
          print('Error resetting rank for ${doc.id}: $e');
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Rank reset completed!\n'
                'Processed: $processed players\n'
                'Errors: $errors',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting ranks: $e'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUser() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Search in customers collection
      final customerDoc = await _firestore.collection('customers').doc(username).get();

      if (customerDoc.exists) {
        final customerData = customerDoc.data()!;

        // Get Round&Drink data
        final roundDrinkDoc = await _firestore.collection('Round&Drink').doc(username).get();

        setState(() {
          _selectedUser = {
            'username': username,
            'name': customerData['Name'] ?? 'Unknown',
            'phone': customerData['Phone'] ?? '',
          };

          _gameHistory = List<Map<String, dynamic>>.from(customerData['GameHistory'] ?? []);

          if (roundDrinkDoc.exists) {
            final roundDrinkData = roundDrinkDoc.data()!;
            _roundHistory = List<Map<String, dynamic>>.from(roundDrinkData['freeRoundHistory'] ?? []);
            _drinkHistory = List<Map<String, dynamic>>.from(roundDrinkData['freeDrinkHistory'] ?? []);
            _freeRoundCount = roundDrinkData['freeRound'] ?? 0;
            _freeDrinkCount = roundDrinkData['freeDrink'] ?? 0;
          } else {
            _roundHistory = [];
            _drinkHistory = [];
            _freeRoundCount = 0;
            _freeDrinkCount = 0;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found user: ${customerData['Name']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not found'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        setState(() {
          _selectedUser = null;
          _gameHistory = [];
          _roundHistory = [];
          _drinkHistory = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching user: $e'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addGameHistory() async {
    if (_selectedUser == null) return;

    final date = _gameDateController.text.trim();
    final time = _gameTimeController.text.trim();
    final position = _gamePositionController.text.trim();
    final eloChange = _gameEloChangeController.text.trim();

    if (date.isEmpty || time.isEmpty || position.isEmpty || eloChange.isEmpty) {
      _showError('Please fill all game history fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newGame = {
        'Date': date,
        'Time': time,
        'Position': position,
        'Elochange': int.tryParse(eloChange) ?? 0,
      };

      // Update in Firebase
      await _firestore.collection('customers').doc(_selectedUser!['username']).update({
        'GameHistory': FieldValue.arrayUnion([newGame]),
      });

      // Update local state
      setState(() {
        _gameHistory.add(newGame);
      });

      // Clear fields
      _gameDateController.text = _getCurrentDate();
      _gameTimeController.text = _getCurrentTime();
      _gamePositionController.clear();
      _gameEloChangeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Game history added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error adding game history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addRoundHistory() async {
    if (_selectedUser == null) return;

    final amount = int.tryParse(_roundAmountController.text) ?? 0;
    final date = _roundDateController.text.trim();

    if (amount == 0 || date.isEmpty) {
      _showError('Please enter valid round amount and date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final text = amount > 0 ? '+$amount Free Round' : '$amount Free Round';
      final newRound = {
        'date': date,
        'text': text,
      };

      // Update in Firebase
      await _firestore.collection('Round&Drink').doc(_selectedUser!['username']).update({
        'freeRound': FieldValue.increment(amount),
        'freeRoundHistory': FieldValue.arrayUnion([newRound]),
      });

      // Update local state
      setState(() {
        _roundHistory.add(newRound);
        _freeRoundCount += amount;
      });

      // Clear amount field only
      _roundAmountController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Round history added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error adding round history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addDrinkHistory() async {
    if (_selectedUser == null) return;

    final amount = int.tryParse(_drinkAmountController.text) ?? 0;
    final date = _drinkDateController.text.trim();

    if (amount == 0 || date.isEmpty) {
      _showError('Please enter valid drink amount and date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final text = amount > 0 ? '+$amount Free Drink' : '$amount Free Drink';
      final newDrink = {
        'date': date,
        'text': text,
      };

      // Update in Firebase
      await _firestore.collection('Round&Drink').doc(_selectedUser!['username']).update({
        'freeDrink': FieldValue.increment(amount),
        'freeDrinkHistory': FieldValue.arrayUnion([newDrink]),
      });

      // Update local state
      setState(() {
        _drinkHistory.add(newDrink);
        _freeDrinkCount += amount;
      });

      // Clear amount field only
      _drinkAmountController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Drink history added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error adding drink history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeGameHistory(int index) async {
    if (_selectedUser == null || index >= _gameHistory.length) return;

    setState(() => _isLoading = true);

    try {
      final gameToRemove = _gameHistory[index];

      // Update in Firebase
      await _firestore.collection('customers').doc(_selectedUser!['username']).update({
        'GameHistory': FieldValue.arrayRemove([gameToRemove]),
      });

      // Update local state
      setState(() {
        _gameHistory.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Game history removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error removing game history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeRoundHistory(int index) async {
    if (_selectedUser == null || index >= _roundHistory.length) return;

    setState(() => _isLoading = true);

    try {
      final roundToRemove = _roundHistory[index];

      // Extract amount from text
      final text = roundToRemove['text'] ?? '';
      final amount = _extractAmountFromText(text);

      // Update in Firebase
      await _firestore.collection('Round&Drink').doc(_selectedUser!['username']).update({
        'freeRound': FieldValue.increment(-amount),
        'freeRoundHistory': FieldValue.arrayRemove([roundToRemove]),
      });

      // Update local state
      setState(() {
        _roundHistory.removeAt(index);
        _freeRoundCount -= amount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Round history removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error removing round history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeDrinkHistory(int index) async {
    if (_selectedUser == null || index >= _drinkHistory.length) return;

    setState(() => _isLoading = true);

    try {
      final drinkToRemove = _drinkHistory[index];

      // Extract amount from text
      final text = drinkToRemove['text'] ?? '';
      final amount = _extractAmountFromText(text);

      // Update in Firebase
      await _firestore.collection('Round&Drink').doc(_selectedUser!['username']).update({
        'freeDrink': FieldValue.increment(-amount),
        'freeDrinkHistory': FieldValue.arrayRemove([drinkToRemove]),
      });

      // Update local state
      setState(() {
        _drinkHistory.removeAt(index);
        _freeDrinkCount -= amount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Drink history removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Error removing drink history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _extractAmountFromText(String text) {
    try {
      final regex = RegExp(r'([+-]?\d+)');
      final match = regex.firstMatch(text);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _openScheduleDialog() async {
    // Get current week start
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);

    // Load event options
    final snapshot = await _firestore.collection('spadesProfiles').get();
    final headers = <String>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final headerText = data['HeaderText']?.toString();
      if (headerText != null && headerText.isNotEmpty) {
        headers.add(headerText);
      }
    }

    final eventOptions = headers.toList()..sort();

    final result = await showDialog(
      context: context,
      builder: (context) => AdminScheduleDialog(
        weekStartDate: weekStart,
        eventOptions: eventOptions,
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Admin Control Panel',
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
          ? Center(
        child: CircularProgressIndicator(color: Color(0xFFDC2626)),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Functions Section
            _buildAdminFunctions(),

            SizedBox(height: 24),

            // User Search Section
            _buildUserSearch(),

            SizedBox(height: 24),

            // User Details (if user is selected)
            if (_selectedUser != null) _buildUserDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminFunctions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Functions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Reset Rank Button
          Container(
            width: double.infinity,
            height: 50,
            margin: EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: _resetRanks,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Reset All Ranks', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),

          // Schedule Button
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _openScheduleDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Tournament Schedule', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSearch() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Edit Player',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Search field
          TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username/Phone Number',
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Color(0xFF374151),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          SizedBox(height: 12),

          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _searchUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Search User', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetails() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info
          Row(
            children: [
              Icon(Icons.person, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedUser!['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _selectedUser!['phone'],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Stats Summary
          Row(
            children: [
              _buildStatBox('Free Rounds', _freeRoundCount.toString(), Icons.casino_outlined),
              SizedBox(width: 12),
              _buildStatBox('Free Drinks', _freeDrinkCount.toString(), Icons.local_drink),
              SizedBox(width: 12),
              _buildStatBox('Games', _gameHistory.length.toString(), Icons.history),
            ],
          ),

          SizedBox(height: 24),

          // Game History Section
          _buildHistorySection(
            'Game History',
            _gameHistory,
            _removeGameHistory,
            _buildGameHistoryForm(),
          ),

          SizedBox(height: 24),

          // Round History Section
          _buildHistorySection(
            'Round History',
            _roundHistory,
            _removeRoundHistory,
            _buildRoundHistoryForm(),
          ),

          SizedBox(height: 24),

          // Drink History Section
          _buildHistorySection(
            'Drink History',
            _drinkHistory,
            _removeDrinkHistory,
            _buildDrinkHistoryForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFFDC2626), size: 20),
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
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(
      String title,
      List<Map<String, dynamic>> history,
      Function(int) onRemove,
      Widget addForm,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),

        // Add Form
        addForm,

        SizedBox(height: 12),

        // History List
        if (history.isNotEmpty)
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildHistoryItem(index, item, onRemove);
          }).toList()
        else
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No $title',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameHistoryForm() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gameDateController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date (dd/MM/yyyy)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _gameTimeController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Time (HH:mm)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gamePositionController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Position (1st, 2nd, etc)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _gameEloChangeController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Elo Change (+/-)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _addGameHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Game History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundHistoryForm() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roundAmountController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (+/-)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _roundDateController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date (dd/MM/yyyy)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _addRoundHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Round History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkHistoryForm() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _drinkAmountController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (+/-)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _drinkDateController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date (dd/MM/yyyy)',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF1F2937),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _addDrinkHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Drink History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(int index, Map<String, dynamic> item, Function(int) onRemove) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['date']?.toString() ?? '--/--/----',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  item['text']?.toString() ?? item['Date']?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onRemove(index),
            icon: Icon(Icons.delete, color: Color(0xFFDC2626), size: 20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
}