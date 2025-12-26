import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'admin_schedule_dialog.dart';

class TournamentScheduleScreen extends StatefulWidget {
  @override
  _TournamentScheduleScreenState createState() => _TournamentScheduleScreenState();
}

class _TournamentScheduleScreenState extends State<TournamentScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _currentWeekStart;
  List<String> _eventOptions = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  // Vietnamese day names
  final Map<String, String> _vietnameseDays = {
    'Monday': 'Thứ Hai',
    'Tuesday': 'Thứ Ba',
    'Wednesday': 'Thứ Tư',
    'Thursday': 'Thứ Năm',
    'Friday': 'Thứ Sáu',
    'Saturday': 'Thứ Bảy',
    'Sunday': 'Chủ Nhật',
  };

  // Vietnamese month names
  final Map<int, String> _vietnameseMonths = {
    1: 'Tháng 1',
    2: 'Tháng 2',
    3: 'Tháng 3',
    4: 'Tháng 4',
    5: 'Tháng 5',
    6: 'Tháng 6',
    7: 'Tháng 7',
    8: 'Tháng 8',
    9: 'Tháng 9',
    10: 'Tháng 10',
    11: 'Tháng 11',
    12: 'Tháng 12',
  };

  // Map to store events for each day
  final Map<String, List<Map<String, dynamic>>> _weekEvents = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  // Cache for spadesProfiles data to avoid multiple Firebase calls
  final Map<String, Map<String, dynamic>> _spadesProfilesCache = {};

  // Track multi-day event positions
  final Map<String, List<Map<String, dynamic>>> _multiDayEventsByHeader = {};

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStartDate(DateTime.now());
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: DateTime.now().weekday - 1, // 0-indexed
    );
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _getWeekStartDate(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _initializeData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _isAdmin = authService.currentUser?.username == 'admin';

      await _loadEventOptions();
      await _loadWeekSchedule();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEventOptions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('spadesProfiles')
          .get();

      final headers = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final headerText = data['HeaderText']?.toString();
        if (headerText != null && headerText.isNotEmpty) {
          headers.add(headerText);
          // Cache the data
          _spadesProfilesCache[headerText] = data;
        }
      }

      setState(() {
        _eventOptions = headers.toList()..sort();
      });
    } catch (e) {
      print('Error loading event options: $e');
    }
  }

  Future<Map<String, dynamic>?> _getSpadesProfileData(String headerText) async {
    // Return from cache if available
    if (_spadesProfilesCache.containsKey(headerText)) {
      return _spadesProfilesCache[headerText];
    }

    // If not in cache, fetch from Firebase
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('spadesProfiles')
          .where('HeaderText', isEqualTo: headerText)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        _spadesProfilesCache[headerText] = data;
        return data;
      }
    } catch (e) {
      print('Error fetching spades profile for $headerText: $e');
    }
    return null;
  }

  Future<void> _loadWeekSchedule() async {
    try {
      // Format the week ID consistently
      final formattedDate = '${_currentWeekStart.year}-${_currentWeekStart.month.toString().padLeft(2, '0')}-${_currentWeekStart.day.toString().padLeft(2, '0')}';
      final weekId = formattedDate;

      print('Loading schedule for week ID: $weekId'); // Debug print

      final doc = await FirebaseFirestore.instance
          .collection('tournamentSchedules')
          .doc(weekId)
          .get();

      // Clear existing events
      _weekEvents.forEach((key, value) => value.clear());
      _multiDayEventsByHeader.clear();

      if (doc.exists) {
        print('Found schedule for week: $weekId'); // Debug print
        final data = doc.data() as Map<String, dynamic>;

        // Load events for each day
        for (var day in _weekEvents.keys) {
          final dayKey = '${day.toLowerCase()}Events';
          if (data.containsKey(dayKey)) {
            final events = List<Map<String, dynamic>>.from(data[dayKey]);
            _weekEvents[day] = events;

            // Track multi-day events
            for (var event in events) {
              final headerText = event['eventName'];
              if (!_multiDayEventsByHeader.containsKey(headerText)) {
                _multiDayEventsByHeader[headerText] = [];
              }
              _multiDayEventsByHeader[headerText]!.add({
                ...event,
                'day': day,
                'dayIndex': _getDayIndex(day),
              });
            }
          }
        }

        // Sort multi-day events by day index
        for (var header in _multiDayEventsByHeader.keys) {
          _multiDayEventsByHeader[header]!.sort((a, b) => a['dayIndex'].compareTo(b['dayIndex']));
        }
      } else {
        print('No schedule found for week: $weekId'); // Debug print
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading week schedule: $e');
      // Clear all events on error
      _weekEvents.forEach((key, value) => value.clear());
      _multiDayEventsByHeader.clear();
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getFormattedDate(int dayIndex) {
    final date = _currentWeekStart.add(Duration(days: dayIndex));
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _onEditSchedule() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AdminScheduleDialog(
        weekStartDate: _currentWeekStart,
        eventOptions: _eventOptions,
        initialTabIndex: _tabController.index,
      ),
    );

    if (result == true) {
      await _loadWeekSchedule();
    }
  }

  int _getDayIndex(String day) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.indexOf(day);
  }

  // Helper method to get unique durations from BlindLevels (sorted descending, only if IsBreak is false)
  List<String> _getSortedDurations(Map<String, dynamic>? profileData) {
    final durations = <String>{};

    if (profileData != null && profileData.containsKey('BlindLevels')) {
      final blindLevels = profileData['BlindLevels'] as List<dynamic>?;
      if (blindLevels != null) {
        for (var level in blindLevels) {
          if (level is Map<String, dynamic>) {
            // Check if IsBreak is false or not present
            final isBreak = level['IsBreak'] ?? false;
            if (!isBreak && level.containsKey('Duration')) {
              final duration = level['Duration']?.toString();
              if (duration != null && duration.isNotEmpty) {
                durations.add(duration);
              }
            }
          }
        }
      }
    }

    // Sort durations in descending order (larger first)
    final sortedList = durations.toList();
    sortedList.sort((a, b) {
      final intA = int.tryParse(a) ?? 0;
      final intB = int.tryParse(b) ?? 0;
      return intB.compareTo(intA); // Descending order
    });

    return sortedList;
  }

  // Helper method to get GTD value
  String _getGTDValue(Map<String, dynamic>? profileData) {
    if (profileData != null && profileData.containsKey('PayoutData')) {
      final payoutData = profileData['PayoutData'] as Map<String, dynamic>?;
      if (payoutData != null && payoutData.containsKey('GTD')) {
        final gtdValue = payoutData['GTD'];

        if (gtdValue == null) return 'N/A';

        // Convert to string first
        final gtdString = gtdValue.toString();

        // Check if it ends with ".0" (exact whole number)
        if (gtdString.endsWith('.0')) {
          // Remove the ".0" part
          return gtdString.substring(0, gtdString.length - 2);
        }

        // Return the original string for other cases (15.5, 15, etc.)
        return gtdString;
      }
    }
    return 'N/A';
  }

  // Helper method to get LateRegLevel
  String _getLateRegLevel(Map<String, dynamic>? profileData) {
    if (profileData != null && profileData.containsKey('LateRegLevel')) {
      return profileData['LateRegLevel']?.toString() ?? 'N/A';
    }
    return 'N/A';
  }

  // Helper method to check if event is multi-day
  bool _isMultiDayEvent(Map<String, dynamic>? profileData) {
    if (profileData != null && profileData.containsKey('IsMultiDay')) {
      return profileData['IsMultiDay'] == true;
    }
    return false;
  }

  // Helper method to get formatted header text for multi-day events
  String _getFormattedHeaderText(Map<String, dynamic> event, Map<String, dynamic>? profileData, String day) {
    final headerText = event['eventName'];

    // Check if this is a multi-day event
    if (_isMultiDayEvent(profileData)) {
      final multiDayEvents = _multiDayEventsByHeader[headerText] ?? [];
      if (multiDayEvents.length > 1) {
        // Find position of this event in the multi-day sequence
        for (int i = 0; i < multiDayEvents.length; i++) {
          if (multiDayEvents[i]['day'] == day) {
            if (i == multiDayEvents.length - 1) {
              // Last event in the sequence
              return '$headerText - Final Day';
            } else {
              // Not the last event
              return '$headerText - Day ${i + 1}';
            }
          }
        }
      }
    }

    // Not a multi-day event or only has one occurrence
    return headerText;
  }

  // Get Vietnamese formatted date: "Thứ Ba - Tháng 12, 2025"
  String _getVietnameseDate(int dayIndex) {
    final date = _currentWeekStart.add(Duration(days: dayIndex));
    final vietnameseDay = _vietnameseDays[_getEnglishDayName(dayIndex)] ?? '';
    final vietnameseMonth = _vietnameseMonths[date.month] ?? 'Tháng ${date.month}';

    return '$vietnameseDay - $vietnameseMonth, ${date.year}';
  }

  // Get English day name from index
  String _getEnglishDayName(int dayIndex) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dayIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'Lịch Thi Đấu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              // Week navigation - only show for admin
              if (_isAdmin)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.subtract(Duration(days: 7));
                          });
                          _loadWeekSchedule();
                        },
                      ),
                      Text(
                        '${DateFormat('dd/MM').format(_currentWeekStart)} - ${DateFormat('dd/MM').format(_currentWeekStart.add(Duration(days: 6)))}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.add(Duration(days: 7));
                          });
                          _loadWeekSchedule();
                        },
                      ),
                    ],
                  ),
                )
              else
              // For normal users, show current week only
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Lịch thi đấu tuần này',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Tabs with Vietnamese abbreviations
              Container(
                color: Color(0xFF1F2937),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Color(0xFFDC2626),
                  unselectedLabelColor: Colors.grey[400],
                  indicatorColor: Color(0xFFDC2626),
                  indicatorWeight: 3,
                  tabs: [
                    _buildTab('T2', 0),
                    _buildTab('T3', 1),
                    _buildTab('T4', 2),
                    _buildTab('T5', 3),
                    _buildTab('T6', 4),
                    _buildTab('T7', 5),
                    _buildTab('CN', 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(color: Color(0xFFDC2626)),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildDaySchedule('Monday'),
          _buildDaySchedule('Tuesday'),
          _buildDaySchedule('Wednesday'),
          _buildDaySchedule('Thursday'),
          _buildDaySchedule('Friday'),
          _buildDaySchedule('Saturday'),
          _buildDaySchedule('Sunday'),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
        onPressed: _onEditSchedule,
        backgroundColor: Color(0xFFDC2626),
        child: Icon(Icons.edit, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      )
          : null,
    );
  }

  Widget _buildTab(String vietnameseDayName, int dayIndex) {
    final date = _currentWeekStart.add(Duration(days: dayIndex));
    final formattedDate = '${date.day}/${date.month}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vietnameseDayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySchedule(String day) {
    final dayIndex = _getDayIndex(day);
    final vietnameseDate = _getVietnameseDate(dayIndex);
    final events = _weekEvents[day] ?? [];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF111827),
            Color(0xFF1F2937),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Option 3 - Minimalist Modern Design with Vietnamese date
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F2937), // Dark background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFFDC2626).withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFDC2626).withOpacity(0.2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Date circle
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFEF4444),
                          Color(0xFFDC2626),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFDC2626).withOpacity(0.4),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _currentWeekStart
                            .add(Duration(days: _getDayIndex(day)))
                            .day
                            .toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // Vietnamese day and month
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _vietnameseDays[day] ?? day,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          vietnameseDate.split(' - ')[1], // Get "Tháng 12, 2025" part
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit button for admin
                  if (_isAdmin)
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: _onEditSchedule,
                    ),
                ],
              ),
            ),

            // Events list
            if (events.isNotEmpty)
              ...events.map((event) => FutureBuilder<Map<String, dynamic>?>(
                future: _getSpadesProfileData(event['eventName']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFDC2626),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  return _buildEventCard(event, snapshot.data, day);
                },
              )).toList()
            else
              Container(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.grey[600],
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Không có sự kiện nào',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Vui lòng kiểm tra lại sau',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, Map<String, dynamic>? profileData, String day) {
    final gtd = _getGTDValue(profileData);
    final sortedDurations = _getSortedDurations(profileData);
    final lateRegLevel = _getLateRegLevel(profileData);
    final formattedHeaderText = _getFormattedHeaderText(event, profileData, day);

    // Format durations as "20/15/10 Mins/Level" (largest first)
    final durationsText = sortedDurations.isNotEmpty
        ? '${sortedDurations.join("/")} Mins/Level'
        : 'N/A';

    final isEventActive = _isEventActive(event);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First line: Time range (darker gold color)
          Text(
            '${event['startTime'].replaceAll(':', 'h')} - ${event['endTime'].replaceAll(':', 'h')}',
            style: TextStyle(
              color: Color(0xFFD4AF37), // Darker gold color
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          // Second line: Header Text (with multi-day formatting if applicable)
          Text(
            formattedHeaderText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          // Third line: GTD information (darker white)
          Text(
            'Guarantee: $gtd Round',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 8),

          // Fourth line: Duration and Reg. Close on same line
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Duration section (aligned left)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Color(0xFFD4AF37), // Darker gold color
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          durationsText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16),

                // Reg. Close section (aligned right)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFD4AF37), // Darker gold color
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Reg. Close: Level $lateRegLevel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Status indicator (removed "UPCOMING" text, only shows "LIVE" when active)
          if (isEventActive)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),

                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isEventActive(Map<String, dynamic> event) {
    try {
      final now = DateTime.now();
      final currentTime = DateFormat('HH:mm').format(now);

      return currentTime.compareTo(event['startTime']) >= 0 &&
          currentTime.compareTo(event['endTime']) <= 0;
    } catch (e) {
      return false;
    }
  }

  String _getCurrentDayName() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }
}