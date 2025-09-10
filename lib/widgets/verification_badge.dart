import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerificationBadge extends StatelessWidget {
  final String? role;
  final String? verificationStatus;
  final double size;
  final bool showText;

  const VerificationBadge({
    super.key,
    this.role,
    this.verificationStatus,
    this.size = 16,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show badge for verified professionals
    if (role != 'professional' || verificationStatus != 'verified') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: showText 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : null,
      decoration: showText
          ? BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 0.5),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            color: Colors.blue.shade600,
            size: size,
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: GoogleFonts.poppins(
                fontSize: size * 0.75,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}