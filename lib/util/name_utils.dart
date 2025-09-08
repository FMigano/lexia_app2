import 'package:firebase_auth/firebase_auth.dart';

class NameUtils {
  /// Extracts the best available name from user data
  static String extractName(Map<String, dynamic>? userData, {User? user}) {
    if (userData != null) {
      // Try different name fields in order of preference
      final name = userData['name']?.toString().trim() ?? 
                   userData['fullName']?.toString().trim() ?? 
                   userData['displayName']?.toString().trim();
      
      if (name != null && name.isNotEmpty && name != 'null') {
        return name;
      }
    }
    
    // Fallback to Firebase Auth user
    if (user != null) {
      final authName = user.displayName?.trim();
      if (authName != null && authName.isNotEmpty && authName != 'null') {
        return authName;
      }
      
      // Extract name from email if available
      if (user.email != null) {
        final emailPart = user.email!.split('@').first;
        if (emailPart.isNotEmpty) {
          // Clean up email-based name
          final cleanName = emailPart
              .replaceAll('.', ' ')
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .map((word) => word.isNotEmpty ? 
                  '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
              .join(' ')
              .trim();
          
          if (cleanName.isNotEmpty) {
            return cleanName;
          }
        }
      }
    }
    
    return 'Anonymous User';
  }
  
  /// Gets the first letter for avatar display
  static String getInitials(String name) {
    if (name.isEmpty || name == 'Anonymous User') return '?';
    
    final words = name.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}