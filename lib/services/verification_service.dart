import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class VerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Trusted domains for auto-verification
  static const List<String> TRUSTED_DOMAINS = [
    // Universities
    '.edu',
    'harvard.edu',
    'stanford.edu',
    'mit.edu',
    'yale.edu',
    'princeton.edu',
    'columbia.edu',
    'upenn.edu',
    'dartmouth.edu',
    'brown.edu',
    'cornell.edu',
    
    // Hospitals & Medical Centers
    'childrens.harvard.edu',
    'mayoclinic.org',
    'clevelandclinic.org',
    'jhmi.edu',
    'partners.org',
    'nyp.org',
    'chop.edu',
    'cchmc.org',
    
    // Government
    '.gov',
    'cdc.gov',
    'nih.gov',
    'ed.gov',
    
    // Professional Organizations
    'asha.org',
    'aap.org',
    'apta.org',
    'apa.org',
  ];

  static bool isTrustedDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    
    // Check exact domain matches
    if (TRUSTED_DOMAINS.contains(domain)) {
      return true;
    }
    
    // Check domain endings (like .edu, .gov)
    for (String trustedDomain in TRUSTED_DOMAINS) {
      if (trustedDomain.startsWith('.') && domain.endsWith(trustedDomain)) {
        return true;
      }
    }
    
    return false;
  }

  static Future<String> submitVerificationRequest({
    required String userId,
    required String workEmail,
    required String profession,
    required String affiliation,
    String? licenseNumber,
    PlatformFile? verificationDocument,
  }) async {
    try {
      final isTrusted = isTrustedDomain(workEmail);
      String? documentUrl;
      String? documentName;

      // Upload document if provided
      if (verificationDocument != null) {
        final uploadResult = await _uploadDocument(userId, verificationDocument);
        documentUrl = uploadResult['url'];
        documentName = uploadResult['name'];
      }

      // Create verification request
      final requestData = {
        'userId': userId,
        'workEmail': workEmail,
        'profession': profession,
        'affiliation': affiliation,
        'licenseNumber': licenseNumber,
        'documentUrl': documentUrl,
        'documentName': documentName,
        'status': isTrusted ? 'verified' : 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'isAutoVerified': isTrusted,
        'trustedDomain': isTrusted,
      };

      // Add to verification_requests collection
      final docRef = await _firestore.collection('verification_requests').add(requestData);

      // Update user profile
      final userUpdateData = {
        'verificationStatus': isTrusted ? 'verified' : 'pending',
        'professionalInfo': {
          'workEmail': workEmail,
          'profession': profession,
          'affiliation': affiliation,
          'licenseNumber': licenseNumber,
        },
        'verificationRequestId': docRef.id,
      };

      if (isTrusted) {
        userUpdateData['verifiedAt'] = FieldValue.serverTimestamp();
        userUpdateData['verifiedBy'] = 'auto_verification';
      }

      await _firestore.collection('users').doc(userId).update(userUpdateData);

      return isTrusted ? 'verified' : 'pending';
    } catch (e) {
      throw Exception('Failed to submit verification request: $e');
    }
  }

  static Future<Map<String, String>> _uploadDocument(String userId, PlatformFile file) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_${timestamp}_${file.name}';
      final ref = _storage.ref().child('verification_documents/$fileName');

      // Upload file
      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null) {
        throw Exception('Could not read file data');
      }

      await ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getContentType(file.extension ?? ''),
          customMetadata: {
            'userId': userId,
            'originalName': file.name,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'name': fileName,
      };
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  // Get verification status for a user
  static Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'status': data['verificationStatus'],
          'professionalInfo': data['professionalInfo'],
          'verifiedAt': data['verifiedAt'],
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get verification status: $e');
    }
  }
}