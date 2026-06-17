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

        if (mounted) {
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

        if (mounted) {
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

    // Calculate energy efficiency with improved formula
    final enemiesDefeated = _userData!['dungeons']?['progress']?['enemies_defeated'] as int? ?? 0;
    final currentEnergy = _userData!['stats']?['player']?['energy'] as int? ?? 20;
    const maxEnergy = 20;
    final energyUsed = maxEnergy - currentEnergy;

    // Get additional performance metrics
    final currentLevel = _userData!['stats']?['player']?['level'] as int? ?? 1;
    final totalExp = _userData!['stats']?['player']?['exp'] as int? ?? 0;

    // Calculate stage completion rate (stages per day)
    final stageCompletionRate = _daysActive > 0 ? _totalStagesCompleted / _daysActive : 0;

    // Calculate word challenge performance
    final wordChallengeTotal = _correctWords + _mistakeWords;
    final wordChallengeScore = wordChallengeTotal > 0 ? (_correctWords / wordChallengeTotal) : 0;

    // IMPROVED EFFICIENCY CALCULATION WITH BETTER EDGE CASE HANDLING
    if (_totalStagesCompleted > 0 || energyUsed > 0) {
      // Components of efficiency (weighted):
      
      // 1. Stage progression (40%) - Stages completed relative to energy used or stages themselves
      double stageEfficiency = 0;
      if (energyUsed > 0) {
        stageEfficiency = ((_totalStagesCompleted / energyUsed).clamp(0, 5) / 5) * 40;
      } else if (_totalStagesCompleted > 0) {
        // If no energy used yet but stages completed (edge case)
        stageEfficiency = (_totalStagesCompleted / _totalPossibleStages * 40);
      }
      
      // 2. Enemy defeat rate (20%) - Enemies per stage or per energy
      double enemyEfficiency = 0;
      if (_totalStagesCompleted > 0) {
        final enemiesPerStage = enemiesDefeated / _totalStagesCompleted;
        enemyEfficiency = (enemiesPerStage.clamp(0, 5) / 5) * 20; // Expect ~2 enemies per stage
      }
      
      // 3. Learning performance (20%) - Word accuracy with volume bonus
      double learningEfficiency = 0;
      if (wordChallengeTotal > 0) {
        final volumeMultiplier = (wordChallengeTotal / 20).clamp(0, 1); // Scale up to 20 attempts
        learningEfficiency = (wordChallengeScore * volumeMultiplier) * 20;
      }
      
      // 4. Level progression (10%) - Level relative to days or stages
      double levelEfficiency = 0;
      if (_totalStagesCompleted > 0) {
        final expectedLevel = (_totalStagesCompleted / 3).ceil(); // ~3 stages per level
        final levelRatio = (currentLevel / expectedLevel.clamp(1, 100)).clamp(0, 1.5);
        levelEfficiency = levelRatio * 10;
      } else if (_daysActive > 0) {
        levelEfficiency = ((currentLevel / _daysActive).clamp(0, 2) / 2) * 10;
      }
      
      // 5. Consistency (10%) - Stage completion rate
      double consistencyEfficiency = 0;
      if (_daysActive > 0 && _totalStagesCompleted > 0) {
        consistencyEfficiency = (stageCompletionRate.clamp(0, 3) / 3) * 10;
      }
      
      // Total efficiency score (0-100)
      final totalEfficiency = stageEfficiency + enemyEfficiency + learningEfficiency + 
                              levelEfficiency + consistencyEfficiency;
      
      _energyEfficiency = totalEfficiency.round().clamp(0, 100);
      
      debugPrint('=== EFFICIENCY CALCULATION ===');
      debugPrint('Total stages: $_totalStagesCompleted');
      debugPrint('Energy used: $energyUsed/$maxEnergy');
      debugPrint('Enemies defeated: $enemiesDefeated');
      debugPrint('Word challenges: $_correctWords/$wordChallengeTotal (${(wordChallengeScore * 100).toStringAsFixed(1)}%)');
      debugPrint('Current level: $currentLevel');
      debugPrint('Days active: $_daysActive');
      debugPrint('---');
      debugPrint('Stage efficiency (40%): ${stageEfficiency.toStringAsFixed(1)}');
      debugPrint('Enemy efficiency (20%): ${enemyEfficiency.toStringAsFixed(1)}');
      debugPrint('Learning efficiency (20%): ${learningEfficiency.toStringAsFixed(1)}');
      debugPrint('Level efficiency (10%): ${levelEfficiency.toStringAsFixed(1)}');
      debugPrint('Consistency efficiency (10%): ${consistencyEfficiency.toStringAsFixed(1)}');
      debugPrint('Total efficiency: $_energyEfficiency%');
      debugPrint('================================');
    } else {
      // No activity yet - 0% efficiency
      _energyEfficiency = 0;
      debugPrint('No activity detected - efficiency set to 0%');
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

  Future<void> _showAvailableUsers() async {
    try {
      final querySnapshot = await _firestore.collection('dyslexia_users').get();
      final availableUsers = <String>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['profile']?['username'] != null) {
          availableUsers.add(data['profile']['username'].toString());
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Available Users (${availableUsers.length})',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: availableUsers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      availableUsers[index],
                      style: GoogleFonts.poppins(),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      _searchUserByUsername(availableUsers[index]);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
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
                          _getAccuracyColor(_wordAccuracy).withValues(alpha: 0.2),
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
        color: color.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.1),
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

                        // NEW: Characters Section
                        _buildCharactersSection(),

                        const SizedBox(height: 24),

                        // NEW: Learning Modules Progress Section  
                        _buildLearningModulesSection(),

                        const SizedBox(height: 24),

                        // NEW: Stage Performance Times Section
                        _buildStagePerformanceSection(),

                        const SizedBox(height: 24),

                        // NEW: Word Challenges Section
                        _buildWordChallengesSection(),

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
        color: color.withValues(alpha: 0.2),
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
                  color: color.withValues(alpha: 0.8),
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
                profile?['username'] ?? 'Unknown User',  // Should show proper name
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

  // NEW: Build method for Characters Section
  Widget _buildCharactersSection() {
    // Access data correctly - unlocked_count and selected_character are at root level
    final selectedCharacter = _userData?['selected_character'] as int? ?? 0;
    final unlockedCount = _userData?['unlocked_count'] as int? ?? 1; // Default to 1
    final currentCharacter = _userData?['stats']?['player']?['current_character'] as String? ?? 'lexia';
    final unlockNotifications = _userData?['unlock_notifications_shown'] as List<dynamic>? ?? [];

    // Map character name to number: 1 for Ragna, 2 for Lexia
    String getCharacterDisplayNumber(String characterName) {
      switch (characterName.toLowerCase()) {
        case 'ragna':
          return '1';
        case 'lexia':
          return '2';
        default:
          return '0';
      }
    }

    final characterNumber = getCharacterDisplayNumber(currentCharacter);

    // Add debug print to see what's happening
    debugPrint('=== CHARACTER UNLOCK DEBUG ===');
    debugPrint('Raw userData keys: ${_userData?.keys.toList()}');
    debugPrint('Raw selected_character: ${_userData?['selected_character']}');
    debugPrint('Raw unlocked_count: ${_userData?['unlocked_count']}');
    debugPrint('Selected character value: $selectedCharacter');
    debugPrint('Unlocked count value: $unlockedCount');
    debugPrint('Current character name: $currentCharacter');
    debugPrint('Character number: $characterNumber');
    debugPrint('Unlock notifications: $unlockNotifications');
    debugPrint('================================');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Character Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.face, color: Colors.purple, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          currentCharacter.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Current Character',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          characterNumber, // Shows 1 for Ragna, 2 for Lexia
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Selected',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.lock_open, color: Colors.green, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '$unlockedCount', // Shows actual unlocked_count from database (2)
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Unlocked',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Character Stats
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Character Stats',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Health',
                    '${_userData?['stats']?['player']?['health'] ?? 0}/${_userData?['stats']?['player']?['base_health'] ?? 0}',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatBox(
                    'Damage',
                    '${_userData?['stats']?['player']?['damage'] ?? 0}',
                    Icons.flash_on,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatBox(
                    'Durability',
                    '${_userData?['stats']?['player']?['durability'] ?? 0}',
                    Icons.shield,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            // Show unlocked characters list if available
            if (unlockNotifications.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlocked Characters:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlockNotifications.map((char) => char.toString().toUpperCase()).join(', '),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLearningModulesSection() {
  final modules = _userData?['modules'] as Map<String, dynamic>?;
  
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Learning Modules Progress',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (modules == null) ...[
            _buildEmptyDataCard('No learning modules data available'),
          ] else ...[
            // Phonics Module - WITH sub-items (like Read Aloud)
            _buildPhonicsModuleCard(modules),
            
            const SizedBox(height: 12),
            
            // Flip Quiz Module - WITH sub-items (like Read Aloud)
            _buildFlipQuizModuleCard(modules),
            
            const SizedBox(height: 12),
            
            // Read Aloud Module - WITH sub-items (existing)
            _buildReadAloudModuleCard(modules),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildPhonicsModuleCard(Map<String, dynamic> modules) {
  final phonicsData = _calculatePhonicsProgress(modules['phonics']);
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Phonics header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.abc, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Phonics',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        phonicsData['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: phonicsData['completed'] ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${(phonicsData['progress'] as num).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Sub-modules for Phonics
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            children: [
              // Letters Completed sub-module
              _buildSubModuleRow(
                'Letters Completed',
                ((modules['phonics']?['letters_completed'] as List<dynamic>?)?.length ?? 0) / 26 * 100,
                (modules['phonics']?['letters_completed'] as List<dynamic>?)?.length ?? 0,
                26, // max letters
                Icons.text_fields,
                Colors.indigo,
              ),
              
              const SizedBox(height: 8),
              
              // Sight Words sub-module  
              _buildSubModuleRow(
                'Sight Words',
                ((modules['phonics']?['sight_words_completed'] as List<dynamic>?)?.length ?? 0) / 20 * 100,
                (modules['phonics']?['sight_words_completed'] as List<dynamic>?)?.length ?? 0,
                20, // max sight words
                Icons.visibility,
                Colors.cyan,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildFlipQuizModuleCard(Map<String, dynamic> modules) {
  final flipQuizData = _calculateFlipQuizProgress(modules['flip_quiz']);
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Flip Quiz header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.quiz, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Flip Quiz',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        flipQuizData['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: flipQuizData['completed'] ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${(flipQuizData['progress'] as num).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Sub-modules for Flip Quiz
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            children: [
              // Animals Sets sub-module
              _buildSubModuleRow(
                'Animals Sets',
                ((modules['flip_quiz']?['animals']?['sets_completed'] as List<dynamic>?)?.length ?? 0) / 3 * 100,
                (modules['flip_quiz']?['animals']?['sets_completed'] as List<dynamic>?)?.length ?? 0,
                3, // max animals sets
                Icons.pets,
                Colors.brown,
              ),
              
              const SizedBox(height: 8),
              
              // Vehicles Sets sub-module  
              _buildSubModuleRow(
                'Vehicles Sets',
                ((modules['flip_quiz']?['vehicles']?['sets_completed'] as List<dynamic>?)?.length ?? 0) / 3 * 100,
                (modules['flip_quiz']?['vehicles']?['sets_completed'] as List<dynamic>?)?.length ?? 0,
                3, // max vehicles sets
                Icons.directions_car,
                Colors.blueGrey,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStagePerformanceSection() {
  final stageTimes = _userData?['stage_times'] as Map<String, dynamic>?;
  
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Stage Performance Times',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (stageTimes == null || stageTimes.isEmpty) ...[
            _buildEmptyDataCard('No stage performance data available'),
          ] else ...[
            // Performance summary
            Builder(
              builder: (context) {
                // Calculate total time and average
                double totalTime = 0;
                int totalStages = 0;
                
                stageTimes.forEach((dungeonKey, dungeonData) {
                  if (dungeonData is Map<String, dynamic>) {
                    dungeonData.forEach((stageKey, time) {
                      if (time is num) {
                        totalTime += time;
                        totalStages++;
                      }
                    });
                  }
                });
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPerformanceMetric(
                        'Total Time',
                        _formatStageTime(totalTime),
                        Icons.timer,
                        Colors.blue,
                      ),
                      _buildPerformanceMetric(
                        'Stages',
                        '$totalStages',
                        Icons.flag,
                        Colors.green,
                      ),
                      _buildPerformanceMetric(
                        'Avg Time',
                        totalStages > 0 ? _formatStageTime(totalTime / totalStages) : '0s',
                        Icons.speed,
                        Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Show stage times for each dungeon
            for (String dungeonKey in stageTimes.keys)
              _buildDungeonTimeCard(dungeonKey, stageTimes[dungeonKey] as Map<String, dynamic>),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildWordChallengesSection() {
    final wordChallenges = _userData?['word_challenges'] as Map<String, dynamic>?;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Word Challenges Performance',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (wordChallenges == null) ...[
              _buildEmptyDataCard('No word challenges data available'),
            ] else ...[
              // Challenge performance cards
              Row(
                children: [
                  Expanded(
                    child: _buildChallengeCard(
                      'STT (Speech-to-Text)',
                      wordChallenges['completed']?['stt'] ?? 0,
                      wordChallenges['failed']?['stt'] ?? 0,
                      Icons.mic,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChallengeCard(
                      'Whiteboard',
                      wordChallenges['completed']?['whiteboard'] ?? 0,
                      wordChallenges['failed']?['whiteboard'] ?? 0,
                      Icons.edit,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Overall performance summary
              _buildOverallChallengePerformance(wordChallenges),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods for the new sections:

  Widget _buildCharacterStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedModuleCard(String title, Map<String, dynamic>? moduleData, IconData icon, Color color, {List<String>? additionalInfo}) {
  final isCompleted = moduleData?['completed'] as bool? ?? false;
  final progress = moduleData?['progress'] as num? ?? 0;
  
  // Debug print to see what data we're getting
  debugPrint('Building card for $title: completed=$isCompleted, progress=$progress');
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                  // FIXED: ALWAYS show progress, not just when > 0
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${progress.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (additionalInfo != null && additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...additionalInfo.map((info) => Padding(
            padding: const EdgeInsets.only(left: 40, top: 2),
            child: Text(
              '• $info',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          )),
        ],
      ],
    ),
  );
}

  Widget _buildEmptyDataCard(String message) {
    return Container(
      width: double.infinity, // Fixed: Ensure it takes full width properly
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20), // Smaller icon
          const SizedBox(width: 8), // Reduced spacing
          Expanded( // Fixed: Wrap text in Expanded to prevent overflow
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13, // Slightly smaller font
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis, // Handle text overflow
              maxLines: 2, // Allow up to 2 lines
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color, // Keep the metric color
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white, // Fixed: White text for labels
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDungeonTimeCard(String dungeonKey, Map<String, dynamic> stageData) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade800,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade600),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dungeonKey.replaceAll('_', ' ').toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        // Fixed: Use Wrap instead of GridView to prevent overflow
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (String stageKey in stageData.keys)
              _buildStageTimeChip(stageKey, stageData[stageKey] as num),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildStageTimeChip(String stageName, num timeSeconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12), // Less rounded for more space
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${stageName.replaceAll('stage_', 'S')}: ${_formatStageTime(timeSeconds)}',
        style: GoogleFonts.poppins(
          fontSize: 11, // Smaller font to fit better
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildChallengeCard(String title, int completed, int failed, IconData icon, Color color) {
    final total = completed + failed;
    final accuracy = total > 0 ? (completed / total * 100) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${accuracy.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '✓$completed  ✗$failed',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallChallengePerformance(Map<String, dynamic> wordChallenges) {
  final sttCompleted = wordChallenges['completed']?['stt'] ?? 0;
  final sttFailed = wordChallenges['failed']?['stt'] ?? 0;
  final whiteboardCompleted = wordChallenges['completed']?['whiteboard'] ?? 0;
  final whiteboardFailed = wordChallenges['failed']?['whiteboard'] ?? 0;
  
  final totalCompleted = sttCompleted + whiteboardCompleted;
  final totalFailed = sttFailed + whiteboardFailed;
  final totalAttempts = totalCompleted + totalFailed;
  final overallAccuracy = totalAttempts > 0 ? (totalCompleted / totalAttempts * 100) : 0.0;
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      // Fixed: Use solid dark background instead of light gradient
      color: Colors.grey.shade800,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade600),
    ),
    child: Column(
      children: [
        Text(
          'Overall Performance',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white, // Fixed: White text on dark background
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOverallMetric('Total Correct', '$totalCompleted', Icons.check_circle, Colors.green),
            _buildOverallMetric('Total Failed', '$totalFailed', Icons.cancel, Colors.red),
            _buildOverallMetric('Accuracy', '${overallAccuracy.toStringAsFixed(1)}%', Icons.gps_fixed, Colors.blue),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildOverallMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color, // Keep the metric color
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white, // Fixed: White text for labels
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatStageTime(num timeSeconds) {
    if (timeSeconds < 60) {
      return '${timeSeconds.toStringAsFixed(1)}s';
    } else {
      final minutes = (timeSeconds / 60).floor();
      final seconds = (timeSeconds % 60).toStringAsFixed(1);
      return '${minutes}m ${seconds}s';
    }
  }

  // Missing calculation methods:
  Map<String, dynamic> _calculatePhonicsProgress(Map<String, dynamic>? phonicsData) {
  if (phonicsData == null) return {'completed': false, 'progress': 0};
  
  final lettersCompleted = (phonicsData['letters_completed'] as List<dynamic>?)?.length ?? 0;
  final sightWordsCompleted = (phonicsData['sight_words_completed'] as List<dynamic>?)?.length ?? 0;
  
  // Calculate progress: Letters (26 max) + Sight Words (20 max) = 46 total
  final totalProgress = ((lettersCompleted + sightWordsCompleted) / 46 * 100);
  final isCompleted = lettersCompleted >= 26 && sightWordsCompleted >= 20;
  
  return {
    'completed': isCompleted,
    'progress': totalProgress,
  };
}

Map<String, dynamic> _calculateFlipQuizProgress(Map<String, dynamic>? flipQuizData) {
  if (flipQuizData == null) return {'completed': false, 'progress': 0};
  
  final animalsSets = (flipQuizData['animals']?['sets_completed'] as List<dynamic>?)?.length ?? 0;
  final vehiclesSets = (flipQuizData['vehicles']?['sets_completed'] as List<dynamic>?)?.length ?? 0;
  
  // Calculate progress: Animals (3 max) + Vehicles (3 max) = 6 total
  final totalProgress = ((animalsSets + vehiclesSets) / 6 * 100);
  final isCompleted = animalsSets >= 3 && vehiclesSets >= 3;
  
  return {
    'completed': isCompleted,
    'progress': totalProgress,
  };
}

Map<String, dynamic> _calculateReadAloudProgress(Map<String, dynamic>? modules) {
  if (modules == null) return {'completed': false, 'progress': 0};
  
  final readAloud = modules['read_aloud'];
  if (readAloud == null) return {'completed': false, 'progress': 0};
  
  // FIXED: Access nested data correctly
  final guidedReading = readAloud['guided_reading'];
  final syllableWorkshop = readAloud['syllable_workshop'];
  
  // Debug the data
  debugPrint('=== READ ALOUD DEBUG ===');
  debugPrint('Read Aloud data: $readAloud');
  debugPrint('Guided Reading data: $guidedReading');
  debugPrint('Syllable Workshop data: $syllableWorkshop');
  
  // Guided Reading: max 4 activities
  final guidedActivities = (guidedReading?['activities_completed'] as List<dynamic>?)?.length ?? 0;
  final guidedProgress = (guidedActivities / 4 * 100).clamp(0, 100);
  
  // Syllable Workshop: max 9 words
  final syllableWords = (syllableWorkshop?['activities_completed'] as List<dynamic>?)?.length ?? 0;
  final syllableProgress = (syllableWords / 9 * 100).clamp(0, 100);
  
  // Overall progress: average of both sub-modules
  final totalProgress = (guidedProgress + syllableProgress) / 2;
  
  // Check if Read Aloud itself is completed OR both sub-modules are complete
  final isCompleted = (readAloud['completed'] as bool? ?? false) || 
                     (guidedActivities >= 4 && syllableWords >= 9);
  
  debugPrint('Guided: $guidedActivities/4 = ${guidedProgress.toStringAsFixed(1)}%');                   
  debugPrint('Syllable: $syllableWords/9 = ${syllableProgress.toStringAsFixed(1)}%');
  debugPrint('Total Read Aloud progress: ${totalProgress.toStringAsFixed(1)}%');
  debugPrint('========================');
  
  return {
    'completed': isCompleted,
    'progress': totalProgress,

    'guided_progress': guidedProgress,
    'guided_activities': guidedActivities,
    'syllable_progress': syllableProgress,
    'syllable_words': syllableWords,
  };
}

Widget _buildReadAloudModuleCard(Map<String, dynamic> modules) {
  final readAloudData = _calculateReadAloudProgress(modules);
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.purple.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Read Aloud header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.record_voice_over, color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Read Aloud',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        readAloudData['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: readAloudData['completed'] ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${(readAloudData['progress'] as num).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Sub-modules with null-safe access
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            children: [
              // Guided Reading sub-module
              _buildSubModuleRow(
                'Guided Reading',
                readAloudData['guided_progress'] ?? 0,
                readAloudData['guided_activities'] ?? 0,
                4, // max activities
                Icons.menu_book,
                Colors.teal,
              ),
              
              const SizedBox(height: 8),
              
              // Syllable Workshop sub-module  
              _buildSubModuleRow(
                'Syllable Workshop',
                readAloudData['syllable_progress'] ?? 0,
                readAloudData['syllable_words'] ?? 0,
                9, // max words
                Icons.format_textdirection_l_to_r,
                Colors.orange,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSubModuleRow(String title, num progress, int completed, int max, IconData icon, Color color) {
  final isCompleted = completed >= max;
  
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size:  16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? Colors.green : Colors.grey,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${progress.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$completed/$max',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}