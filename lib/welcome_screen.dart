import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'game_history_screen.dart';
import 'top_players_screen.dart';
import 'profile_screen.dart';
import 'tournament_schedule_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_control_panel.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
  }

  Future<void> _loadRecentActivities() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser?.username == null) {
        setState(() {
          _isLoadingActivities = false;
        });
        return;
      }

      final List<Map<String, dynamic>> allActivities = [];

      // 1. Load Game History (Priority 1)
      try {
        final customerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(currentUser!.username)  // Use ! since we checked above
            .get();

        if (customerDoc.exists) {
          final customerData = customerDoc.data();
          final gameHistory = List<Map<String, dynamic>>.from(
              customerData?['GameHistory'] ?? []);

          // Add game activities with type and date
          for (var game in gameHistory.reversed.take(5)) {
            final position = _parsePosition(game['Position']);
            final eloChange = _parseEloChange(game['Elochange']);

            String description = '';
            String? icon;
            Color color = Color(0xFF10B981); // Default green

            if (position <= 3 && position >= 1) {
              icon = position == 1 ? '🥇' : position == 2 ? '🥈' : '🥉';
              description = 'Xếp hạng ${position}${_getOrdinalSuffix(position)}';
              color = position == 1
                  ? Color(0xFFFFD700) // Gold
                  : position == 2
                  ? Color(0xFFC0C0C0) // Silver
                  : Color(0xFFCD7F32); // Bronze
            } else {
              icon = '🎮';
              description = 'Hoàn thành ván đấu';
            }

            allActivities.add({
              'type': 'game',
              'date': game['Date'] ?? '--/--/----',
              'time': game['Time'] ?? '--:--',
              'description': '$description (${eloChange >= 0 ? '+' : ''}$eloChange ELO)',
              'icon': icon,
              'color': color,
              'timestamp': _parseDateTime(game['Date'], game['Time']),
            });
          }
        }
      } catch (e) {
        print('Error loading game history: $e');
      }

      // 2. Load Free Round History (Priority 2)
      try {
        final roundDrinkDoc = await FirebaseFirestore.instance
            .collection('Round&Drink')
            .doc(currentUser!.username)  // Use ! since we checked above
            .get();

        if (roundDrinkDoc.exists) {
          final data = roundDrinkDoc.data();
          final roundHistory = List<Map<String, dynamic>>.from(
              data?['freeRoundHistory'] ?? []);

          // Filter out "Tour free rounds" entries and sort by date
          final filteredRoundHistory = roundHistory
              .where((entry) => !_containsTourFreeRounds(
              entry['text']?.toString() ?? ''))
              .toList();

          filteredRoundHistory.sort((a, b) =>
              _compareDates(b['date'], a['date']));

          for (var round in filteredRoundHistory.take(5)) {
            final text = round['text']?.toString() ?? '';
            final date = round['date']?.toString() ?? '--/--/----';

            allActivities.add({
              'type': 'round',
              'date': date,
              'time': '',
              'description': text,
              'icon': '🎲',
              'color': text.contains('+')
                  ? Color(0xFF10B981) // Green for positive
                  : Color(0xFFDC2626), // Red for negative
              'timestamp': _parseDate(date),
            });
          }
        }
      } catch (e) {
        print('Error loading free round history: $e');
      }

      // 3. Load Free Drink History (Priority 3)
      try {
        final roundDrinkDoc = await FirebaseFirestore.instance
            .collection('Round&Drink')
            .doc(currentUser!.username)  // Use ! since we checked above
            .get();

        if (roundDrinkDoc.exists) {
          final data = roundDrinkDoc.data();
          final drinkHistory = List<Map<String, dynamic>>.from(
              data?['freeDrinkHistory'] ?? []);

          // Filter out "Tour free rounds" entries and sort by date
          final filteredDrinkHistory = drinkHistory
              .where((entry) => !_containsTourFreeRounds(
              entry['text']?.toString() ?? ''))
              .toList();

          filteredDrinkHistory.sort((a, b) =>
              _compareDates(b['date'], a['date']));

          for (var drink in filteredDrinkHistory.take(5)) {
            final text = drink['text']?.toString() ?? '';
            final date = drink['date']?.toString() ?? '--/--/----';

            allActivities.add({
              'type': 'drink',
              'date': date,
              'time': '',
              'description': text,
              'icon': '🥤',
              'color': text.contains('+')
                  ? Color(0xFF3B82F6) // Blue for positive
                  : Color(0xFFDC2626), // Red for negative
              'timestamp': _parseDate(date),
            });
          }
        }
      } catch (e) {
        print('Error loading free drink history: $e');
      }

      // 4. Sort all activities by timestamp (newest first) and take latest 5
      allActivities.sort((a, b) {
        final timeA = a['timestamp'] as DateTime? ?? DateTime(2000);
        final timeB = b['timestamp'] as DateTime? ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });

      // 5. Get latest 5 activities with priority: game > round > drink
      final latestActivities = _getLatestActivitiesWithPriority(allActivities, 5);

      setState(() {
        _recentActivities = latestActivities;
        _isLoadingActivities = false;
      });

    } catch (e) {
      print('Error loading recent activities: $e');
      setState(() {
        _isLoadingActivities = false;
      });
    }
  }

  List<Map<String, dynamic>> _getLatestActivitiesWithPriority(
      List<Map<String, dynamic>> allActivities, int limit) {
    // Sort by timestamp first
    allActivities.sort((a, b) {
      final timeA = a['timestamp'] as DateTime? ?? DateTime(2000);
      final timeB = b['timestamp'] as DateTime? ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    // Group activities by date (same day)
    final Map<String, List<Map<String, dynamic>>> activitiesByDate = {};
    for (var activity in allActivities) {
      final date = activity['date'] as String;
      if (!activitiesByDate.containsKey(date)) {
        activitiesByDate[date] = [];
      }
      activitiesByDate[date]!.add(activity);
    }

    // Sort dates (newest first)
    final sortedDates = activitiesByDate.keys.toList()
      ..sort((a, b) => _compareDates(b, a));

    // Select activities with priority: game > round > drink
    final List<Map<String, dynamic>> selectedActivities = [];

    for (var date in sortedDates) {
      if (selectedActivities.length >= limit) break;

      final dayActivities = activitiesByDate[date]!;

      // Sort day's activities by priority: game > round > drink > timestamp
      dayActivities.sort((a, b) {
        final priorityA = _getActivityPriority(a['type']);
        final priorityB = _getActivityPriority(b['type']);

        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB); // Lower number = higher priority
        }

        // Same priority, sort by timestamp
        final timeA = a['timestamp'] as DateTime? ?? DateTime(2000);
        final timeB = b['timestamp'] as DateTime? ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });

      // Add activities from this day until we reach limit
      for (var activity in dayActivities) {
        if (selectedActivities.length >= limit) break;
        selectedActivities.add(activity);
      }
    }

    return selectedActivities.take(limit).toList();
  }

  int _getActivityPriority(String type) {
    switch (type) {
      case 'game': return 1; // Highest priority
      case 'round': return 2;
      case 'drink': return 3; // Lowest priority
      default: return 4;
    }
  }

  // Helper methods from game_history_screen.dart
  int _parsePosition(dynamic position) {
    if (position == null) return 0;
    if (position is int) return position;
    if (position is String) {
      if (position.contains('1') || position.toLowerCase().contains('first')) return 1;
      if (position.contains('2') || position.toLowerCase().contains('second')) return 2;
      if (position.contains('3') || position.toLowerCase().contains('third')) return 3;
      final match = RegExp(r'\d+').firstMatch(position);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  int _parseEloChange(dynamic eloChange) {
    if (eloChange == null) return 0;
    if (eloChange is int) return eloChange;
    if (eloChange is String) return int.tryParse(eloChange) ?? 0;
    if (eloChange is double) return eloChange.toInt();
    return 0;
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return '';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return '';
    }
  }

  bool _containsTourFreeRounds(String text) {
    return text.toLowerCase().contains('tour') &&
        text.toLowerCase().contains('free rounds');
  }

  int _compareDates(dynamic dateA, dynamic dateB) {
    final String dateStrA = dateA?.toString() ?? '';
    final String dateStrB = dateB?.toString() ?? '';
    return dateStrA.compareTo(dateStrB);
  }

  DateTime? _parseDateTime(String? date, String? time) {
    try {
      if (date == null || date.isEmpty) return null;

      // Parse date in format "dd/MM/yyyy" or "dd/MM/yy"
      final dateParts = date.split('/');
      if (dateParts.length < 3) return null;

      int day = int.tryParse(dateParts[0]) ?? 1;
      int month = int.tryParse(dateParts[1]) ?? 1;
      int year = int.tryParse(dateParts[2]) ?? DateTime.now().year;

      // Handle 2-digit year
      if (year < 100) {
        year += 2000;
      }

      // Parse time if available
      int hour = 0, minute = 0;
      if (time != null && time.isNotEmpty) {
        final timeParts = time.split(':');
        if (timeParts.length >= 2) {
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = int.tryParse(timeParts[1]) ?? 0;
        }
      }

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseDate(String? date) {
    return _parseDateTime(date, null);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final customer = authService.currentCustomer;

    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2937),
        title: Text(
          'SPADES Dịch vụ khách hàng',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              authService.logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card - UPDATED: Now clickable
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
              child: _buildWelcomeHeader(
                customer?.name ?? user?.name ?? 'Player',
                user?.profilePictureUrl,
                customer?.elorank['Medal']?.toString() ?? 'Chưa có hạng',
              ),
            ),

            SizedBox(height: 30),

            // Features Grid
            Text(
              'Truy cập nhanh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 20),
            _buildFeaturesGrid(context),

            SizedBox(height: 30),

            // Recent Activity - UPDATED with real data
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String userName, String? profilePictureUrl, String medalRank) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with profile picture or default
          _buildUserAvatar(profilePictureUrl),

          SizedBox(width: 16),

          // Welcome Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào,',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),

                // Medal Rank Badge
                _buildMedalBadge(medalRank),
              ],
            ),
          ),

          // Arrow indicator to show it's clickable
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? profilePictureUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Color(0xFFDC2626).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: profilePictureUrl,
          placeholder: (context, url) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDC2626),
                  Color(0xFF991B1B),
                ],
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDC2626),
                  Color(0xFF991B1B),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          fit: BoxFit.cover,
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFDC2626),
                Color(0xFF991B1B),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedalBadge(String medalRank) {
    // Define colors for Vietnamese ranking system
    Color badgeColor;
    Color textColor;
    IconData medalIcon;
    String displayText = medalRank;

    // Customize badge appearance based on Vietnamese ranking system
    if (medalRank.contains('Spades The Best')) {
      badgeColor = Color(0xFFDC2626).withOpacity(0.2); // Red
      textColor = Color(0xFFDC2626);
      medalIcon = Icons.workspace_premium;
      displayText = 'Spades The Best';
    } else if (medalRank.contains('Cao Thủ')) {
      badgeColor = Color(0xFF8B5CF6).withOpacity(0.2); // Purple
      textColor = Color(0xFF8B5CF6);
      medalIcon = Icons.workspace_premium;
      displayText = 'Cao Thủ';
    } else if (medalRank.contains('Tinh Anh')) {
      badgeColor = Color(0xFF3B82F6).withOpacity(0.2); // Blue
      textColor = Color(0xFF3B82F6);
      medalIcon = Icons.diamond;
      displayText = 'Tinh Anh';
    } else if (medalRank.contains('Kim Cương')) {
      badgeColor = Color(0xFF10B981).withOpacity(0.2); // Emerald
      textColor = Color(0xFF10B981);
      medalIcon = Icons.diamond;
      displayText = 'Kim Cương';
    } else if (medalRank.contains('Vàng')) {
      badgeColor = Color(0xFFFFD700).withOpacity(0.2); // Gold
      textColor = Color(0xFFFFD700);
      medalIcon = Icons.emoji_events;
      displayText = 'Vàng';
    } else if (medalRank.contains('Bạc')) {
      badgeColor = Color(0xFFC0C0C0).withOpacity(0.2); // Silver
      textColor = Color(0xFFC0C0C0);
      medalIcon = Icons.emoji_events;
      displayText = 'Bạc';
    } else if (medalRank.contains('Đồng')) {
      badgeColor = Color(0xFFCD7F32).withOpacity(0.2); // Bronze
      textColor = Color(0xFFCD7F32);
      medalIcon = Icons.emoji_events;
      displayText = 'Đồng';
    } else {
      // Default for "Chưa có hạng" or other ranks
      badgeColor = Colors.grey[800]!.withOpacity(0.3);
      textColor = Colors.grey[400]!;
      medalIcon = Icons.emoji_events_outlined;
      displayText = 'Chưa có hạng';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            medalIcon,
            color: textColor,
            size: 14,
          ),
          SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isAdmin = authService.currentUser?.username == 'admin';

    final features = [
      {
        'title': 'Lịch sử đấu',
        'icon': Icons.history_toggle_off,
        'color': Color(0xFF3B82F6),
        'gradient': [
          Color(0xFF3B82F6),
          Color(0xFF1D4ED8),
        ],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GameHistoryScreen()),
          );
        },
      },
      {
        'title': 'Lịch thi đấu',
        'icon': Icons.calendar_today,
        'color': Color(0xFF10B981),
        'gradient': [
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TournamentScheduleScreen()),
          );
        },
      },
      {
        'title': 'Xếp hạng',
        'icon': Icons.leaderboard,
        'color': Color(0xFFF59E0B),
        'gradient': [
          Color(0xFFF59E0B),
          Color(0xFFD97706),
        ],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TopPlayersScreen()),
          );
        },
      },
      {
        'title': 'Hồ sơ',
        'icon': Icons.account_circle_outlined,
        'color': Color(0xFF8B5CF6),
        'gradient': [
          Color(0xFF8B5CF6),
          Color(0xFF7C3AED),
        ],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
        },
      },
    ];

    // Add Admin Control Panel if user is admin
    if (isAdmin) {
      features.insert(0, {
        'title': 'Admin Control Panel',
        'icon': Icons.admin_panel_settings,
        'color': Color(0xFFDC2626),
        'gradient': [
          Color(0xFFDC2626),
          Color(0xFF991B1B),
        ],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminControlPanel()),
          );
        },
      });
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(
          title: feature['title'] as String,
          icon: feature['icon'] as IconData,
          gradient: feature['gradient'] as List<Color>,
          onTap: feature['onTap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Colored circle with icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: gradient[0].withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gradient[0].withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: gradient[0],
                  size: 24,
                ),
              ),
              SizedBox(height: 16),

              // Title with accent color
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Hoạt động gần đây',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_isLoadingActivities)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_recentActivities.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có hoạt động',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Các hoạt động sẽ hiển thị tại đây',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _recentActivities.map((activity) {
                return _buildActivityItem(
                  date: activity['date'] as String,
                  time: activity['time'] as String,
                  description: activity['description'] as String,
                  activityType: activity['type'] as String, // Pass activity type
                  color: activity['color'] as Color,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String date,
    required String time,
    required String description,
    required String activityType, // Added parameter
    required Color color,
  }) {
    // Get the appropriate icon based on activity type
    IconData activityIcon;
    switch (activityType) {
      case 'game':
        activityIcon = Icons.casino; // Match profile screen games played icon
        break;
      case 'round':
        activityIcon = Icons.casino_outlined; // Match profile screen free round icon
        break;
      case 'drink':
        activityIcon = Icons.local_drink; // Match profile screen free drink icon
        break;
      default:
        activityIcon = Icons.casino; // Default to game icon
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container with Material Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                activityIcon, // Use Material Icon instead of emoji
                color: color,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey[500],
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ]
                  ],
                ),
                SizedBox(height: 4),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}