import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  Map<String, dynamic>? _userData;
  String _error = '';

  // Calculated stats
  int _completionPercentage = 0;
  int _totalStagesCompleted = 0;
  final int _totalPossibleStages =
      15; // Changed from 30 to 15 (3 dungeons × 5 stages each)
  int _daysActive = 0;
  int _energyEfficiency = 0;

  // Additional language learning stats
  int _correctWords = 0;
  int _mistakeWords = 0;
  int _totalWords = 0;
  double _wordAccuracy = 0.0;
  int _totalUsageTimeMinutes = 0;
  String _averageSessionTime = "0m";
  int _sessionsCompleted = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Try to get data from dyslexia_users collection first
      var doc = await _firestore.collection('dyslexia_users').doc(userId).get();

      // If not found in dyslexia_users, try the regular users collection
      if (!doc.exists) {
        doc = await _firestore.collection('users').doc(userId).get();
      }

      if (!doc.exists) {
        setState(() {
          _error = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userData = doc.data();
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Replace your existing _searchUserByUsername method with this enhanced version:
  Future<void> _searchUserByUsername(String username) async {
    if (username.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _error = '';
    });

    try {
      final searchTerm = username.trim().toLowerCase();
      debugPrint('🔍 Searching for dyslexia user: $searchTerm');

      // Get ALL dyslexia users first
      final querySnapshot = await _firestore.collection('dyslexia_users').get();
      debugPrint(
          '📊 Retrieved ${querySnapshot.docs.length} total dyslexia users');

      // Debug: Print all available usernames
      final availableUsers = <String>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['profile']?['username'] != null) {
          final username = data['profile']['username'].toString();
          availableUsers.add(username);
          debugPrint('👤 Available user: $username');
        }
      }

      // Try direct query first (case-sensitive)
      var usernameQuery = await _firestore
          .collection('dyslexia_users')
          .where('profile.username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (usernameQuery.docs.isEmpty) {
        // Try lowercase
        usernameQuery = await _firestore
            .collection('dyslexia_users')
            .where('profile.username', isEqualTo: searchTerm)
            .limit(1)
            .get();
      }

      if (usernameQuery.docs.isNotEmpty) {
        final userData = usernameQuery.docs.first.data();
        debugPrint('✅ Found user directly: ${userData['profile']['username']}');

        setState(() {
          _userData = userData;
          _calculateStats();
          _isSearching = false;
        });

        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Manual search through all documents
      DocumentSnapshot? matchingDoc;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        if (data['profile']?['username'] != null) {
          final docUsername = data['profile']['username'].toString();

          // Try exact match (case insensitive)
          if (docUsername.toLowerCase() == searchTerm) {
            debugPrint('✅ Found exact match: $docUsername');
            matchingDoc = doc;
            break;
          }

          // Try partial match
          if (docUsername.toLowerCase().contains(searchTerm) ||
              searchTerm.contains(docUsername.toLowerCase())) {
            debugPrint('✅ Found partial match: $docUsername');
            matchingDoc = doc;
            break;
          }
        }
      }

      if (matchingDoc != null) {
        final userData = matchingDoc.data() as Map<String, dynamic>;
        debugPrint(
            '✅ Successfully found user: ${userData['profile']['username']}');

        setState(() {
          _userData = userData;
          _calculateStats();
          _isSearching = false;
        });

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        debugPrint(
            '❌ User not found. Available users: ${availableUsers.join(', ')}');
        throw Exception(
            'User "$username" not found.\nAvailable users: ${availableUsers.take(5).join(', ')}${availableUsers.length > 5 ? '...' : ''}');
      }
    } catch (e) {
      debugPrint('💥 Error searching dyslexia user: $e');
      setState(() {
        _error = e.toString().contains('Available users:')
            ? e.toString().replaceAll('Exception: ', '')
            : 'User not found. Use the list button to see available users.';
        _isSearching = false;
      });
    }
  }

  void _calculateStats() {
    if (_userData == null) return;

    debugPrint('=== FULL USER DATA STRUCTURE ===');
    debugPrint('User data keys: ${_userData!.keys.join(', ')}');
    debugPrint('Profile section: ${_userData!['profile']}');
    debugPrint('Stats section: ${_userData!['stats']}');
    debugPrint('Word challenges section: ${_userData!['word_challenges']}');
    debugPrint('================================');

    debugPrint(
        'Calculating stats for user: ${_userData!['profile']?['username']}');

    // Calculate days active using profile created_at and last_session_date
    _daysActive = 0;
    if (_userData!['profile'] != null) {
      try {
        final createdAtString = _userData!['profile']['created_at'] as String?;
        final lastSessionString =
            _userData!['profile']['last_session_date'] as String?;

        if (createdAtString != null) {
          final createdAt = DateTime.parse(createdAtString);

          if (lastSessionString != null) {
            // Use last_session_date if available
            final lastSession = DateTime.parse(lastSessionString);
            _daysActive = lastSession.difference(createdAt).inDays + 1;
          } else {
            // Fallback to current date
            _daysActive = DateTime.now().difference(createdAt).inDays + 1;
          }

          if (_daysActive < 1) _daysActive = 1;
          debugPrint('Days active: $_daysActive');
        }
      } catch (e) {
        debugPrint('Error calculating days active: $e');
        _daysActive = 1;
      }
    }

    // Calculate stages completed from dungeons
    _totalStagesCompleted = 0;
    if (_userData!['dungeons'] != null &&
        _userData!['dungeons']['completed'] != null) {
      final dungeons =
          _userData!['dungeons']['completed'] as Map<String, dynamic>;
      dungeons.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final stagesCompleted = value['stages_completed'] as int? ?? 0;
          _totalStagesCompleted += stagesCompleted;
          debugPrint('Dungeon $key: $stagesCompleted stages completed');
        }
      });
    }

    // Calculate completion percentage
    if (_totalPossibleStages > 0) {
      _completionPercentage =
          (_totalStagesCompleted / _totalPossibleStages * 100).round();
    } else {
      _completionPercentage = 0;
    }

    // Calculate energy efficiency
    final enemiesDefeated =
        _userData!['dungeons']?['progress']?['enemies_defeated'] as int? ?? 0;
    final currentEnergy =
        _userData!['stats']?['player']?['energy'] as int? ?? 20;
    final maxEnergy = 20;
    final energyUsed = maxEnergy - currentEnergy;

    if (energyUsed > 0) {
      final performanceScore = _totalStagesCompleted + (enemiesDefeated * 0.5);
      _energyEfficiency = (performanceScore / energyUsed * 100).round();
    } else {
      _energyEfficiency = currentEnergy == maxEnergy ? 100 : 0;
    }

    // CORRECTED: Language learning statistics from word_challenges
    _correctWords = 0;
    _mistakeWords = 0;

    if (_userData!['word_challenges'] != null) {
      final wordChallenges = _userData!['word_challenges'];
      debugPrint('Word challenges data: $wordChallenges');

      // Get completed words (correct answers)
      if (wordChallenges['completed'] != null) {
        final completed = wordChallenges['completed'] as Map<String, dynamic>;
        _correctWords += (completed['stt'] as int? ?? 0);
        _correctWords += (completed['whiteboard'] as int? ?? 0);
        debugPrint(
            'Completed - STT: ${completed['stt']}, Whiteboard: ${completed['whiteboard']}');
      }

      // Get failed words (incorrect answers)
      if (wordChallenges['failed'] != null) {
        final failed = wordChallenges['failed'] as Map<String, dynamic>;
        _mistakeWords += (failed['stt'] as int? ?? 0);
        _mistakeWords += (failed['whiteboard'] as int? ?? 0);
        debugPrint(
            'Failed - STT: ${failed['stt']}, Whiteboard: ${failed['whiteboard']}');
      }
    } else {
      debugPrint('No word_challenges data found in user data');
    }

    _totalWords = _correctWords + _mistakeWords;

    // Calculate word accuracy percentage
    if (_totalWords > 0) {
      _wordAccuracy = (_correctWords / _totalWords * 100);
    } else {
      _wordAccuracy = 0.0;
    }

    debugPrint(
        'Word Stats - Correct: $_correctWords, Mistakes: $_mistakeWords, Total: $_totalWords, Accuracy: ${_wordAccuracy.toStringAsFixed(1)}%');

    // CORRECTED: Usage time calculation using profile fields
    _totalUsageTimeMinutes = 0;
    _sessionsCompleted = 1; // Default to 1 session

    debugPrint('=== USAGE TIME DEBUG ===');
    debugPrint('Raw usage_time: ${_userData!['profile']?['usage_time']}');
    debugPrint('Session count: ${_userData!['profile']?['session']}');
    debugPrint('Created at: ${_userData!['profile']?['created_at']}');
    debugPrint(
        'Last session date: ${_userData!['profile']?['last_session_date']}');
    debugPrint('========================');

    // Get usage time from profile (not root level)
    if (_userData!['profile']?['usage_time'] != null) {
      final usageTimeValue = _userData!['profile']['usage_time'] as num;
      debugPrint('Raw usage_time value: $usageTimeValue');

      // Your value 1748439285.696 appears to be in seconds (timestamp-like)
      // Let's try different conversions to get reasonable minutes
      if (usageTimeValue > 1000000000) {
        // Large number - likely a timestamp, convert differently
        // Try treating it as microseconds first
        _totalUsageTimeMinutes = (usageTimeValue / 60000000).round();

        // If still too large, try milliseconds
        if (_totalUsageTimeMinutes > 10000) {
          _totalUsageTimeMinutes = (usageTimeValue / 60000).round();
        }

        // If still too large, try seconds
        if (_totalUsageTimeMinutes > 10000) {
          _totalUsageTimeMinutes = (usageTimeValue / 60).round();
        }
      } else {
        // Smaller number - likely already in seconds or minutes
        _totalUsageTimeMinutes = (usageTimeValue / 60).round();
      }

      debugPrint('Converted to minutes: $_totalUsageTimeMinutes');
    } else {
      debugPrint('No usage_time field found in profile');
    }

    // Get session count from profile (not root level)
    if (_userData!['profile']?['session'] != null) {
      _sessionsCompleted = _userData!['profile']['session'] as int;
      debugPrint('Sessions completed: $_sessionsCompleted');
    } else {
      _sessionsCompleted = _daysActive > 0 ? _daysActive : 1;
      debugPrint('No session field found, using default: $_sessionsCompleted');
    }

    // Calculate average session time
    if (_sessionsCompleted > 0 && _totalUsageTimeMinutes > 0) {
      final avgMinutes = _totalUsageTimeMinutes / _sessionsCompleted;
      _averageSessionTime = _formatUsageTime(avgMinutes.round());
      debugPrint('Average session time: $_averageSessionTime');
    } else {
      _averageSessionTime = "0m";
      debugPrint('No valid usage data for average calculation');
    }

    debugPrint('=== FINAL USAGE STATS ===');
    debugPrint('Total usage time: ${_formatUsageTime(_totalUsageTimeMinutes)}');
    debugPrint('Sessions completed: $_sessionsCompleted');
    debugPrint('Average session time: $_averageSessionTime');
    debugPrint('Days active: $_daysActive');
    debugPrint('==========================');

    debugPrint(
        'Stats calculated - Completion: $_completionPercentage%, Stages: $_totalStagesCompleted, Word Accuracy: ${_wordAccuracy.toStringAsFixed(1)}%');
  }

  void _showUserSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Find Dyslexia User Stats',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username (e.g. lexia106)',
                prefixIcon: Icon(Icons.person_search),
              ),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && !_isSearching) {
                  _searchUserByUsername(value);
                }
              },
            ),
            const SizedBox(height: 16),
            _isSearching ? const CircularProgressIndicator() : Container(),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _error,
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: _isSearching
                ? null
                : () => _searchUserByUsername(_usernameController.text),
            child: Text(
              'Search',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color? color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  icon,
                  color: color ?? Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String title, int current, int max, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$current / $max',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: current / max,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Theme.of(context).colorScheme.primary),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDungeonProgress(
      Map<String, dynamic> dungeonData, int dungeonId) {
    final bool completed = dungeonData['completed'] ?? false;
    final int stagesCompleted = dungeonData['stages_completed'] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dungeon $dungeonId',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  completed ? Icons.check_circle : Icons.pending,
                  color: completed ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProgressBar(
              'Stages Completed',
              stagesCompleted,
              5, // Changed from 10 to 5
              color: completed ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to the _AnalyticsScreenState class
  Widget _buildLanguageLearningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Statistics',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Word Accuracy Card
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Word Accuracy',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          _getAccuracyColor(_wordAccuracy).withOpacity(0.2),
                      child: Text(
                        '${_wordAccuracy.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getAccuracyColor(_wordAccuracy),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildWordStatBox(
                        'Correct',
                        _correctWords.toString(),
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWordStatBox(
                        'Mistakes',
                        _mistakeWords.toString(),
                        Icons.highlight_off,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWordStatBox(
                        'Total',
                        _totalWords.toString(),
                        Icons.library_books,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Usage Time Card
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Usage Time',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.timer,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeStatBox(
                        'Total Usage',
                        _formatUsageTime(_totalUsageTimeMinutes),
                        Icons.access_time_filled,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeStatBox(
                        'Sessions',
                        _sessionsCompleted.toString(),
                        Icons.event_available,
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeStatBox(
                        'Avg. Session',
                        _averageSessionTime,
                        Icons.timelapse,
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordStatBox(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStatBox(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.amber.shade700;
    return Colors.red;
  }

  String _formatUsageTime(int minutes) {
    if (minutes < 60) {
      return "${minutes}m";
    } else if (minutes < 24 * 60) {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      return "${hours}h ${mins}m";
    } else {
      final days = (minutes / (24 * 60)).floor();
      final hours = ((minutes % (24 * 60)) / 60).floor();
      return "${days}d ${hours}h";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // User search button only - refresh button removed
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: _showUserSearchDialog,
            tooltip: 'Search User',
          ),
          // Refresh button removed from here
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchUserData,
                        child: Text(
                          'Try Again',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Profile Section
                        _buildUserProfileSection(),

                        const SizedBox(height: 24),

                        // Performance Summary Card - NEW SECTION
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance Summary',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildProgressBar(
                                  'Overall Completion',
                                  _totalStagesCompleted,
                                  _totalPossibleStages,
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMetricChip(
                                      '$_completionPercentage%',
                                      'Completion',
                                      Icons.pie_chart,
                                      color: Colors.blue,
                                    ),
                                    _buildMetricChip(
                                      '$_daysActive',
                                      'Days Active',
                                      Icons.calendar_today,
                                      color: Colors.green,
                                    ),
                                    _buildMetricChip(
                                      '$_energyEfficiency%',
                                      'Efficiency',
                                      Icons.bolt,
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _buildStatCard(
                              'Health',
                              '${_userData?['stats']?['player']?['health'] ?? 0}',
                              Icons.favorite,
                              color: Colors.red,
                            ),
                            _buildStatCard(
                              'Energy',
                              '${_userData?['stats']?['player']?['energy'] ?? 0}/20',
                              Icons.battery_charging_full,
                              color: Colors.green,
                            ),
                            _buildStatCard(
                              'Durability',
                              '${_userData?['stats']?['player']?['durability'] ?? 0}',
                              Icons.shield,
                              color: Colors.blue,
                            ),
                            _buildStatCard(
                              'Damage',
                              '${_userData?['stats']?['player']?['damage'] ?? 0}',
                              Icons.flash_on,
                              color: Colors.orange,
                            ),
                            _buildStatCard(
                              'Age',
                              '${_userData?['profile']?['age'] ?? 0}',
                              Icons.cake,
                              color: Colors.purple,
                            ),
                            _buildStatCard(
                              'Birthday',
                              _userData?['profile']?['birth_date'] ?? 'Not Set',
                              Icons.calendar_today,
                              color: Colors.pink,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Language Learning Statistics
                        _buildLanguageLearningSection(),

                        const SizedBox(height: 24),

                        // Dungeon Progress Section
                        Text(
                          'Dungeon Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Current Dungeon Info
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current Progress:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Dungeon ${_userData?['dungeons']?['progress']?['current_dungeon'] ?? 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Enemies Defeated: ${_userData?['dungeons']?['progress']?['enemies_defeated'] ?? 0}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Total Stages: $_totalStagesCompleted',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_userData?['dungeons']?['completed'] != null) ...[
                          for (var i = 1; i <= 3; i++)
                            if (_userData?['dungeons']?['completed']
                                    ?[i.toString()] !=
                                null)
                              _buildDungeonProgress(
                                  _userData!['dungeons']['completed']
                                      [i.toString()],
                                  i),
                        ],

                        const SizedBox(height: 24),

                        // Account Info Section
                        _buildAccountInfoCard(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricChip(String value, String label, IconData icon,
      {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Not available';
    }

    try {
      final parsedDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateString);
      return DateFormat('MMM d, yyyy • h:mm a').format(parsedDate);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileSection() {
    final profile = _userData?['profile'];
    final stats = _userData?['stats'];

    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[300],
          child: Text(
            profile?['username']?.toString().isNotEmpty == true
                ? profile!['username'].toString().characters.first.toUpperCase()
                : '?',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?['username'] ?? 'Unknown User',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rank: ${profile?['rank']?.toString().toUpperCase() ?? 'BRONZE'}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Level ${stats?['player']?['level'] ?? 1}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'EXP: ${stats?['player']?['exp'] ?? 0}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfoCard() {
    final profile = _userData?['profile'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Username',
              profile?['username'] ?? 'Not set',
              Icons.person,
            ),
            const Divider(),
            _buildInfoRow(
              'Email',
              profile?['email'] ?? 'Not set',
              Icons.email,
            ),
            const Divider(),
            _buildInfoRow(
              'Age',
              '${profile?['age'] ?? 'Not set'}',
              Icons.cake,
            ),
            const Divider(),
            _buildInfoRow(
              'Rank',
              profile?['rank']?.toString().toUpperCase() ?? 'Not set',
              Icons.emoji_events,
            ),
            const Divider(),
            _buildInfoRow(
              'Account Created',
              profile?['created_at'] != null
                  ? DateFormat('MMM dd, yyyy')
                      .format(DateTime.parse(profile!['created_at']))
                  : 'Not available',
              Icons.calendar_today,
            ),
            const Divider(),
            _buildInfoRow(
              'Last Login',
              profile?['last_login'] != null
                  ? DateFormat('MMM dd, yyyy')
                      .format(DateTime.parse(profile!['last_login']))
                  : 'Not available',
              Icons.login,
            ),
            const Divider(),
            _buildInfoRow(
              'Days Active',
              '$_daysActive days',
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }
}
