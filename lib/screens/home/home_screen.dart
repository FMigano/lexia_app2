import 'package:flutter/material.dart';
import 'package:lexia_app/screens/home/feed_screen.dart';
import 'package:lexia_app/screens/chat/chat_and_appointments_screen.dart';
import 'package:lexia_app/screens/professionals/professionals_screen.dart';
import 'package:lexia_app/screens/profile/profile_screen.dart';
import 'package:lexia_app/screens/analytics/analytics_screen.dart';
import 'package:provider/provider.dart';
// Fix the ambiguous import by using a prefix
import 'package:lexia_app/providers/auth_provider.dart' as app_auth;
import 'package:lexia_app/screens/posts/create_post_screen.dart';
import 'package:lexia_app/screens/posts/hidden_posts_screen.dart';
// Add the missing import for ProfessionalVerificationScreen
import 'package:lexia_app/screens/auth/professional_verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Check if user needs verification (helper method)
  bool _needsVerification(Map<String, dynamic>? userData) {
    final role = userData?['role'];
    final verificationStatus = userData?['verificationStatus'];
    
    // Show notification for professionals who are NOT verified
    return role == 'professional' && verificationStatus != 'verified';
  }

  // Create blocking verification overlay for specific screens
  Widget _buildBlockingVerificationOverlay() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final role = userData?['role'];
        final verificationStatus = userData?['verificationStatus'];
        
        // Debug print to see what's happening
        print('=== VERIFICATION DEBUG ===');
        print('Role: $role');
        print('Verification Status: $verificationStatus');
        print('Needs Verification: ${_needsVerification(userData)}');
        print('========================');
        
        // Only show for professionals who need verification (not verified)
        if (!_needsVerification(userData)) {
          return const SizedBox.shrink();
        }
        
        // Different UI for pending vs unverified
        final isPending = verificationStatus == 'pending';
        final isRejected = verificationStatus == 'rejected';
        
        // Create full-screen blocking overlay
        return Positioned.fill(
          child: Material(
            color: Colors.black.withOpacity(0.9),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.9,
                          ),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Text(
                                'Verification Required',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isPending 
                                      ? Colors.blue.shade100 
                                      : isRejected 
                                          ? Colors.red.shade100
                                          : Colors.orange.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPending 
                                      ? Icons.hourglass_top 
                                      : isRejected 
                                          ? Icons.error_outline
                                          : Icons.verified_user,
                                  size: 30,
                                  color: isPending 
                                      ? Colors.blue.shade700 
                                      : isRejected 
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Title
                              Text(
                                isPending 
                                    ? 'Verification In Progress'
                                    : isRejected 
                                        ? 'Verification Rejected'
                                        : 'Complete Your Verification',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              
                              // Description
                              Text(
                                isPending 
                                    ? 'Your verification is being reviewed. Access to this feature is limited until approved.'
                                    : isRejected 
                                        ? 'Your verification was rejected. Please verify your professional credentials to access this feature.'
                                        : 'As a healthcare professional, you need to verify your credentials to access this feature and build trust with patients.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              if (!isPending) ...[
                                const SizedBox(height: 16),
                                
                                // Benefits list (only for non-pending)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Verification Benefits:',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildBenefitRow('✓ Access to professional features'),
                                      _buildBenefitRow('✓ Enhanced credibility with patients'),
                                      _buildBenefitRow('✓ Verified professional badge'),
                                      _buildBenefitRow('✓ Higher visibility in directory'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Action button (REMOVED GO BACK BUTTON)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ProfessionalVerificationScreen(),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      isRejected ? Icons.refresh : Icons.verified_user,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isRejected ? 'Retry Verification' : 'Start Verification',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isRejected 
                                          ? Colors.red.shade600 
                                          : Colors.orange.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // For pending status, just show spacing
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for benefit rows
  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Create wrapper widgets that include BLOCKING verification overlay for specific screens
  Widget _buildChatScreenWithNotification() {
    return Stack(
      children: [
        const ChatAndAppointmentsScreen(), // Background screen (blocked)
        _buildBlockingVerificationOverlay(), // Blocking overlay on top
      ],
    );
  }

  Widget _buildProfessionalsScreenWithNotification() {
    return Stack(
      children: [
        const ProfessionalsScreen(), // Background screen (blocked)
        _buildBlockingVerificationOverlay(), // Blocking overlay on top
      ],
    );
  }

  // ADD Analytics screen with blocking verification overlay
  Widget _buildAnalyticsScreenWithNotification() {
    return Stack(
      children: [
        const AnalyticsScreen(), // Background screen (blocked)
        _buildBlockingVerificationOverlay(), // Blocking overlay on top
      ],
    );
  }

  // Update the screens list to include Analytics blocking
  List<Widget> get _screens => [
    const FeedScreen(), // ✅ NO notification on home screen
    _buildChatScreenWithNotification(), // ✅ Show blocking overlay on chat screen
    _buildProfessionalsScreenWithNotification(), // ✅ Show blocking overlay on professionals screen
    _buildAnalyticsScreenWithNotification(), // ✅ Show blocking overlay on analytics screen
    const ProfileScreen(), // ✅ NO notification on profile screen
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);

    // Redirect to login if not authenticated
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Text(
                'Home',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hidden_posts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HiddenPostsScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'hidden_posts',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off),
                          SizedBox(width: 8),
                          Text('Hidden Posts'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: _screens[_selectedIndex], // Removed the Column wrapper that was adding notifications to all screens
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Professional',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: 'home_fab',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreatePostScreen()),
                );
                setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
