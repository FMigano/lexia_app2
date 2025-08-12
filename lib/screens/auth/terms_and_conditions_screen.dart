import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final bool showAcceptButton;
  final VoidCallback? onAccept;

  const TermsAndConditionsScreen({
    super.key,
    this.showAcceptButton = false,
    this.onAccept,
  });

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _hasAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.showAcceptButton) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms and Conditions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terms and Conditions of Use',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSection(
                    '1. Acceptance of Terms',
                    'By creating an account and using Lexia Community, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our service.',
                  ),

                  _buildSection(
                    '2. Description of Service',
                    'Lexia Community is a social platform designed to connect parents and professionals to share resources, experiences, and support related to dyslexia and learning differences. Our services include:\n\n• Community forums and discussions\n• Professional directory and booking\n• Direct messaging between users\n• Resource sharing and educational content\n• Analytics and progress tracking',
                  ),

                  _buildSection(
                    '3. User Accounts and Registration',
                    'To use our services, you must:\n\n• Provide accurate and complete information\n• Maintain the security of your account\n• Be at least 13 years of age (or have parental consent)\n• Use the platform responsibly and ethically\n• Not create multiple accounts for the same person',
                  ),

                  _buildSection(
                    '4. User Content and Conduct',
                    'You are responsible for all content you post. You agree not to:\n\n• Share false, misleading, or harmful information\n• Violate privacy of others, especially children\n• Post spam, advertisements, or irrelevant content\n• Engage in harassment, bullying, or discrimination\n• Share personal medical information without consent\n• Impersonate others or misrepresent your credentials',
                  ),

                  _buildSection(
                    '5. Privacy and Data Protection',
                    'We take your privacy seriously:\n\n• We collect only necessary information to provide our services\n• Your personal data is protected according to our Privacy Policy\n• We do not sell your personal information to third parties\n• You can request deletion of your data at any time\n• We use secure encryption for sensitive information',
                  ),

                  _buildSection(
                    '6. Professional Services Disclaimer',
                    'Important: Lexia Community is not a substitute for professional medical advice:\n\n• Information shared is for educational purposes only\n• Consultations through our platform do not replace in-person evaluations\n• Always seek qualified professional help for medical concerns\n• We do not verify all professional credentials - do your own research\n• Emergency situations require immediate professional attention',
                  ),

                  _buildSection(
                    '7. Children\'s Safety and COPPA Compliance',
                    'Protecting children is our priority:\n\n• Users under 13 need verified parental consent\n• Parents can monitor and control their children\'s activity\n• We do not knowingly collect data from children under 13 without consent\n• Report any inappropriate content involving minors immediately\n• All interactions involving children are monitored',
                  ),

                  _buildSection(
                    '8. Intellectual Property',
                    'Respect for intellectual property:\n\n• You retain rights to your original content\n• By posting, you grant us license to display and distribute your content\n• Do not post copyrighted material without permission\n• Respect others\' intellectual property rights\n• Report copyright violations to us immediately',
                  ),

                  _buildSection(
                    '9. Limitation of Liability',
                    'To the fullest extent permitted by law:\n\n• We provide the service "as is" without warranties\n• We are not liable for user-generated content\n• We are not responsible for outcomes of professional consultations\n• Our liability is limited to the amount you paid for services\n• We are not liable for indirect or consequential damages',
                  ),

                  _buildSection(
                    '10. Termination',
                    'Either party may terminate the agreement:\n\n• You can delete your account at any time\n• We may suspend accounts that violate these terms\n• Upon termination, these terms remain in effect for past activities\n• Some provisions survive termination (privacy, intellectual property)',
                  ),

                  _buildSection(
                    '11. Changes to Terms',
                    'We may update these terms:\n\n• We will notify you of significant changes\n• Continued use after changes constitutes acceptance\n• You can review the latest version anytime in the app\n• If you disagree with changes, you may terminate your account',
                  ),

                  _buildSection(
                    '12. Contact Information',
                    'For questions about these terms:\n\n• Email: support@lexiacommunity.com\n• Address: [Your Company Address]\n• Phone: [Your Support Phone]\n• Response time: Within 48 hours for non-emergency issues',
                  ),

                  const SizedBox(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'By clicking "I Accept" below, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          if (widget.showAcceptButton) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (!_hasScrolledToBottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_down_alt,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please scroll to the bottom to review all terms',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    Row(
                      children: [
                        Checkbox(
                          value: _hasAccepted,
                          onChanged: _hasScrolledToBottom
                              ? (value) => setState(() => _hasAccepted = value ?? false)
                              : null,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _hasScrolledToBottom
                                ? () => setState(() => _hasAccepted = !_hasAccepted)
                                : null,
                            child: Text(
                              'I have read and agree to the Terms and Conditions',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _hasScrolledToBottom
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_hasAccepted && _hasScrolledToBottom && widget.onAccept != null)
                            ? widget.onAccept
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'I Accept',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}