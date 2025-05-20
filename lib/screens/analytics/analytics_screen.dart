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
  final int _totalPossibleStages = 30; // Assuming 3 dungeons with 10 stages each
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

      final doc = await _firestore.collection('users').doc(userId).get();

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
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _error = 'User not found';
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _userData = querySnapshot.docs.first.data();
        _calculateStats();
        _isSearching = false;
      });

      // Close the search dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching for user: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  void _calculateStats() {
    if (_userData == null) return;

    // Calculate total stages completed
    _totalStagesCompleted = 0;
    if (_userData!['dungeons_completed'] != null) {
      final dungeons = _userData!['dungeons_completed'] as Map<String, dynamic>;
      dungeons.forEach((key, value) {
        _totalStagesCompleted += (value['stages_completed'] as int? ?? 0);
      });
    }

    // Calculate completion percentage
    _completionPercentage =
        (_totalStagesCompleted / _totalPossibleStages * 100).round();

    // Calculate days active (from account creation to now)
    if (_userData!['created_at'] != null) {
      try {
        final createdAt =
            DateFormat('yyyy-MM-dd HH:mm:ss').parse(_userData!['created_at']);
        _daysActive = DateTime.now().difference(createdAt).inDays;
      } catch (e) {
        _daysActive = 0;
      }
    }

    // Calculate energy efficiency (energy used vs. stages completed)
    final currentEnergy = _userData!['energy'] as int? ?? 0;
    final maxEnergy = _userData!['max_energy'] as int? ?? 20;
    final energyUsed = maxEnergy - currentEnergy;

    if (energyUsed > 0) {
      _energyEfficiency = (_totalStagesCompleted / energyUsed * 100).round();
    } else {
      _energyEfficiency = 0;
    }

    // Language learning statistics calculations
    _correctWords = _userData?['correct_words'] as int? ?? 0;
    _mistakeWords = _userData?['mistake_words'] as int? ?? 0;
    _totalWords = _correctWords + _mistakeWords;

    // Calculate word accuracy percentage
    if (_totalWords > 0) {
      _wordAccuracy = (_correctWords / _totalWords * 100);
    } else {
      _wordAccuracy = 0.0;
    }

    // Calculate usage time statistics
    _totalUsageTimeMinutes =
        _userData?['total_usage_time_minutes'] as int? ?? 0;
    _sessionsCompleted = _userData?['sessions_completed'] as int? ?? 0;

    // Calculate average session time
    if (_sessionsCompleted > 0) {
      final avgMinutes = _totalUsageTimeMinutes / _sessionsCompleted;
      if (avgMinutes >= 60) {
        final hours = (avgMinutes / 60).floor();
        final minutes = (avgMinutes % 60).round();
        _averageSessionTime = "${hours}h ${minutes}m";
      } else {
        _averageSessionTime = "${avgMinutes.round()}m";
      }
    } else {
      _averageSessionTime = "0m";
    }
  }

  void _showUserSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Find User Stats',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter exact username',
                prefixIcon: Icon(Icons.person_search),
              ),
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
              10, // Assuming 10 stages per dungeon
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
          // User search button
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: _showUserSearchDialog,
            tooltip: 'Search User',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserData,
            tooltip: 'Refresh Data',
          ),
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
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: _userData?['profile_picture'] !=
                                          "default" &&
                                      _userData?['profile_picture'] != null &&
                                      _userData?['profile_picture'].isNotEmpty
                                  ? NetworkImage(_userData!['profile_picture'])
                                  : null,
                              child: _userData?['profile_picture'] ==
                                          "default" ||
                                      _userData?['profile_picture'] == null ||
                                      _userData?['profile_picture'].isEmpty
                                  ? Text(
                                      (_userData?['username'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? (_userData!['username'] as String)
                                              .characters
                                              .first
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(fontSize: 36),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userData?['username'] ?? 'Unknown User',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rank: ${_userData?['rank']?.toString().toUpperCase() ?? 'N/A'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Level ${_userData?['user_level'] ?? 0}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Performance Summary Card - NEW SECTION
                        Card(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              'Power Scale',
                              _userData?['power_scale']?.toString() ?? '0',
                              Icons.flash_on,
                              color: Colors.amber,
                            ),
                            _buildStatCard(
                              'Energy',
                              '${_userData?['energy'] ?? 0} / ${_userData?['max_energy'] ?? 0}',
                              Icons.battery_charging_full,
                              color: Colors.green,
                            ),
                            _buildStatCard(
                              'Age',
                              _userData?['age']?.toString() ?? 'N/A',
                              Icons.cake,
                              color: Colors.blue,
                            ),
                            _buildStatCard(
                              'Birth Date',
                              (_userData?['birth_date'] != null &&
                                      (_userData?['birth_date']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false))
                                  ? _userData!['birth_date'].toString()
                                  : 'Not Set',
                              Icons.calendar_today,
                              color: Colors.purple,
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
                                      'Current Location:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Dungeon ${_userData?['current_dungeon'] ?? 1} - Stage ${_userData?['current_stage'] ?? 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_userData?['dungeons_completed'] != null) ...[
                          for (var i = 1; i <= 3; i++)
                            if (_userData?['dungeons_completed']
                                    ?[i.toString()] !=
                                null)
                              _buildDungeonProgress(
                                  _userData!['dungeons_completed']
                                      [i.toString()],
                                  i),
                        ],

                        const SizedBox(height: 24),

                        // Account Info Section
                        Text(
                          'Account Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  'Email',
                                  _userData?['email'] ?? 'Not set',
                                  Icons.email,
                                ),
                                const Divider(),
                                _buildInfoRow(
                                  'Created At',
                                  _formatDate(_userData?['created_at']),
                                  Icons.access_time,
                                ),
                                const Divider(),
                                _buildInfoRow(
                                  'Last Login',
                                  _formatDate(_userData?['last_login']),
                                  Icons.login,
                                ),
                              ],
                            ),
                          ),
                        ),

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
}
