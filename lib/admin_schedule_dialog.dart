import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScheduleDialog extends StatefulWidget {
  final DateTime weekStartDate;
  final List<String> eventOptions;
  final int initialTabIndex; // Add parameter for initial tab

  const AdminScheduleDialog({
    Key? key,
    required this.weekStartDate,
    required this.eventOptions,
    this.initialTabIndex = 0, // Default to first tab
  }) : super(key: key);

  @override
  _AdminScheduleDialogState createState() => _AdminScheduleDialogState();
}

class _AdminScheduleDialogState extends State<AdminScheduleDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _mondayEvents = [];
  final List<Map<String, dynamic>> _tuesdayEvents = [];
  final List<Map<String, dynamic>> _wednesdayEvents = [];
  final List<Map<String, dynamic>> _thursdayEvents = [];
  final List<Map<String, dynamic>> _fridayEvents = [];
  final List<Map<String, dynamic>> _saturdayEvents = [];
  final List<Map<String, dynamic>> _sundayEvents = [];

  final TextEditingController _eventNameController = TextEditingController();
  String? _selectedStartTime;
  String? _selectedEndTime;
  String? _selectedEventName;
  bool _isLoading = false;
  bool _isSaving = false;

  // Track which days have been loaded
  final Set<int> _loadedDays = {};

  // Generate time options from 11:00 to 23:00 in 30-minute intervals
  final List<String> _timeOptions = [
    '11:00', '11:30', '12:00', '12:30', '13:00', '13:30',
    '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30', '19:00', '19:30',
    '20:00', '20:30', '21:00', '21:30', '22:00', '22:30',
    '23:00'
  ];

  @override
  void initState() {
    super.initState();
    // Start from the tab passed from main screen
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex, // Use the passed initial index
    );

    // Load ALL days' events immediately, not just the initial tab
    _loadAllDaysEvents();

    // Listen to tab changes
    _tabController.addListener(_onTabChanged);
  }

  Future<void> _loadAllDaysEvents() async {
    try {
      final weekId = '${widget.weekStartDate.year}-${widget.weekStartDate.month}-${widget.weekStartDate.day}';

      final doc = await FirebaseFirestore.instance
          .collection('tournamentSchedules')
          .doc(weekId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Load events for ALL days
        _loadEventsForDay('monday', data);
        _loadEventsForDay('tuesday', data);
        _loadEventsForDay('wednesday', data);
        _loadEventsForDay('thursday', data);
        _loadEventsForDay('friday', data);
        _loadEventsForDay('saturday', data);
        _loadEventsForDay('sunday', data);

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading all events: $e');
    }
  }

  void _loadEventsForDay(String dayName, Map<String, dynamic> data) {
    final dayKey = '${dayName}Events';

    if (data.containsKey(dayKey)) {
      final events = List<Map<String, dynamic>>.from(data[dayKey]);

      switch (dayName) {
        case 'monday':
          _mondayEvents.clear();
          _mondayEvents.addAll(events);
          _mondayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'tuesday':
          _tuesdayEvents.clear();
          _tuesdayEvents.addAll(events);
          _tuesdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'wednesday':
          _wednesdayEvents.clear();
          _wednesdayEvents.addAll(events);
          _wednesdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'thursday':
          _thursdayEvents.clear();
          _thursdayEvents.addAll(events);
          _thursdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'friday':
          _fridayEvents.clear();
          _fridayEvents.addAll(events);
          _fridayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'saturday':
          _saturdayEvents.clear();
          _saturdayEvents.addAll(events);
          _saturdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
        case 'sunday':
          _sundayEvents.clear();
          _sundayEvents.addAll(events);
          _sundayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final currentIndex = _tabController.index;
      // Load events for the newly selected tab if not already loaded
      if (!_loadedDays.contains(currentIndex)) {
        _loadDayEvents(currentIndex);
      } else {
        // Even if already loaded, ensure UI updates
        setState(() {});
      }
    }
  }

  Future<void> _loadDayEvents(int dayIndex) async {
    // Mark this day as being loaded
    _loadedDays.add(dayIndex);

    try {
      final weekId = '${widget.weekStartDate.year}-${widget.weekStartDate.month}-${widget.weekStartDate.day}';

      final doc = await FirebaseFirestore.instance
          .collection('tournamentSchedules')
          .doc(weekId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final dayName = _getDayName(dayIndex).toLowerCase();
        final dayKey = '${dayName}Events';

        if (data.containsKey(dayKey)) {
          final events = List<Map<String, dynamic>>.from(data[dayKey]);

          // Update the appropriate day's events
          _updateDayEvents(dayIndex, events);

          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('Error loading events for day $dayIndex: $e');
      // Remove from loaded days so we can retry
      _loadedDays.remove(dayIndex);
    }
  }

  void _updateDayEvents(int dayIndex, List<Map<String, dynamic>> events) {
    switch (dayIndex) {
      case 0:
        _mondayEvents.clear();
        _mondayEvents.addAll(events);
        _mondayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 1:
        _tuesdayEvents.clear();
        _tuesdayEvents.addAll(events);
        _tuesdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 2:
        _wednesdayEvents.clear();
        _wednesdayEvents.addAll(events);
        _wednesdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 3:
        _thursdayEvents.clear();
        _thursdayEvents.addAll(events);
        _thursdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 4:
        _fridayEvents.clear();
        _fridayEvents.addAll(events);
        _fridayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 5:
        _saturdayEvents.clear();
        _saturdayEvents.addAll(events);
        _saturdayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
      case 6:
        _sundayEvents.clear();
        _sundayEvents.addAll(events);
        _sundayEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
        break;
    }
  }

  List<Map<String, dynamic>> _getCurrentDayEvents() {
    switch (_tabController.index) {
      case 0: return _mondayEvents;
      case 1: return _tuesdayEvents;
      case 2: return _wednesdayEvents;
      case 3: return _thursdayEvents;
      case 4: return _fridayEvents;
      case 5: return _saturdayEvents;
      case 6: return _sundayEvents;
      default: return _mondayEvents;
    }
  }

  String _getDayName(int index) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[index];
  }

  String _getFormattedDate(int dayIndex) {
    final date = widget.weekStartDate.add(Duration(days: dayIndex));
    return '${date.day}/${date.month}/${date.year}';
  }

  // In admin_schedule_dialog.dart - Update the _saveAllEvents method:

  Future<void> _saveAllEvents() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final weekId = '${widget.weekStartDate.year}-${widget.weekStartDate.month}-${widget.weekStartDate.day}';

      // Create data with ALL days' events (not just current tab)
      final data = {
        'weekStartDate': widget.weekStartDate.toIso8601String(),
        'mondayEvents': _mondayEvents,
        'tuesdayEvents': _tuesdayEvents,
        'wednesdayEvents': _wednesdayEvents,
        'thursdayEvents': _thursdayEvents,
        'fridayEvents': _fridayEvents,
        'saturdayEvents': _saturdayEvents,
        'sundayEvents': _sundayEvents,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Use set() without merge to replace entire document
      // This ensures ALL days are saved together
      await FirebaseFirestore.instance
          .collection('tournamentSchedules')
          .doc(weekId)
          .set(data);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedule: $e'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addEvent() {
    if (_selectedStartTime == null ||
        _selectedEndTime == null ||
        _selectedEventName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Validate time order
    final startIndex = _timeOptions.indexOf(_selectedStartTime!);
    final endIndex = _timeOptions.indexOf(_selectedEndTime!);

    if (startIndex >= endIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thời gian kết thúc phải sau thời gian bắt đầu'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final dayName = _getDayName(_tabController.index);
    final formattedDate = _getFormattedDate(_tabController.index);

    final newEvent = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'dayOfWeek': dayName,
      'date': formattedDate,
      'startTime': _selectedStartTime,
      'endTime': _selectedEndTime,
      'eventName': _selectedEventName,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      final currentEvents = _getCurrentDayEvents();
      currentEvents.add(newEvent);
      currentEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
      _selectedStartTime = null;
      _selectedEndTime = null;
      _selectedEventName = null;
    });
  }

  void _removeEvent(int index) {
    setState(() {
      final currentEvents = _getCurrentDayEvents();
      currentEvents.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: 700, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_calendar, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chỉnh sửa lịch tuần',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Day tabs
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

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(7, (index) => _buildDayContent(index)),
              ),
            ),

            // Footer buttons
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF374151),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Hủy'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAllEvents,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text('Lưu tất cả'),
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

  Widget _buildTab(String dayName, int dayIndex) {
    final date = widget.weekStartDate.add(Duration(days: dayIndex));
    final formattedDate = '${date.day}/${date.month}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dayName,
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

  Widget _buildDayContent(int dayIndex) {
    final dayName = _getDayName(dayIndex);
    final formattedDate = _getFormattedDate(dayIndex);
    final currentEvents = _getCurrentDayEvents();
    final isDayLoaded = _loadedDays.contains(dayIndex) || currentEvents.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Date display
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$dayName • $formattedDate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Add event form
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Thêm sự kiện mới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),

                // Start Time
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStartTime,
                      onChanged: (value) {
                        setState(() {
                          _selectedStartTime = value;
                        });
                      },
                      dropdownColor: Color(0xFF1F2937),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Thời gian bắt đầu',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                      items: _timeOptions.map((time) {
                        return DropdownMenuItem(
                          value: time,
                          child: Text(
                            time.replaceAll(':', 'h'),
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // End Time
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedEndTime,
                      onChanged: (value) {
                        setState(() {
                          _selectedEndTime = value;
                        });
                      },
                      dropdownColor: Color(0xFF1F2937),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Thời gian kết thúc',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                      items: _timeOptions.map((time) {
                        return DropdownMenuItem(
                          value: time,
                          child: Text(
                            time.replaceAll(':', 'h'),
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Event Name Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedEventName,
                      onChanged: (value) {
                        setState(() {
                          _selectedEventName = value;
                        });
                      },
                      dropdownColor: Color(0xFF1F2937),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tên sự kiện',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                      items: [
                        ...widget.eventOptions.map((event) {
                          return DropdownMenuItem(
                            value: event,
                            child: SizedBox(
                              width: 300, // Constrain the width
                              child: Text(
                                event,
                                style: TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                      isExpanded: true, // Add this line
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Add button
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _addEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 8),
                        Text('Thêm vào $dayName', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Existing events list
          if (!isDayLoaded)
            Container(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                  strokeWidth: 2,
                ),
              ),
            )
          else if (currentEvents.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sự kiện đã lên lịch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                ...currentEvents.asMap().entries.map((entry) {
                  final index = entry.key;
                  final event = entry.value;
                  return _buildEventItem(index, event);
                }).toList(),
              ],
            )
          else
            Container(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có sự kiện nào cho $dayName',
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
    );
  }

  Widget _buildEventItem(int index, Map<String, dynamic> event) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time row - separate line
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${event['startTime'].replaceAll(':', 'h')} - ${event['endTime'].replaceAll(':', 'h')}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(height: 12),

          // Event name and delete button row
          Row(
            children: [
              // Event name (larger font)
              Expanded(
                child: Text(
                  event['eventName'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Delete button
              IconButton(
                onPressed: () => _removeEvent(index),
                icon: Icon(Icons.delete, color: Color(0xFFDC2626), size: 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}