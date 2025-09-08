import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:lexia_app/util/name_utils.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

class ChatListScreen extends StatefulWidget {
  final bool showAppBar;
  final String? initialAction;

  const ChatListScreen({
    super.key,
    this.showAppBar = true,
    this.initialAction,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();

    // Handle initial actions if specified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAction != null) {
        switch (widget.initialAction) {
          case 'self_notes':
            _createSelfChat();
            break;
          case 'find_parent':
            _findUserByEmail('parent');
            break;
          case 'find_professional':
            _findUserByEmail('professional');
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(
              title: Text(
                'Chats',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: _buildChatList(),
          )
        : _buildChatList();
  }

  Widget _buildChatList() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(
        child: Text(
          'Please sign in to view chats',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        final chatDocs = snapshot.data?.docs ?? [];

        if (chatDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation with a professional or another parent',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh logic if needed
          },
          child: ListView.separated(
            itemCount: chatDocs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chatDoc = chatDocs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              final participants = List<String>.from(chatData['participants'] ?? []);
              
              // Find the other participant
              final otherParticipantId = participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => currentUser.uid, // Self-chat case
              );

              final lastMessage = chatData['lastMessage'] ?? '';
              final lastMessageTime = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
              final unreadCount = (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUser.uid] ?? 0;

              // Check if this is a self-chat
              final isSelfChat = otherParticipantId == currentUser.uid;

              if (isSelfChat) {
                return _buildSelfChatTile(chatDoc, lastMessage, lastMessageTime);
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherParticipantId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = NameUtils.extractName(userData);
                  final photoUrl = userData['photoUrl'] ?? userData['profile_image_url'] ?? '';
                  final isProfessional = userData['role'] == 'professional';

                  return _buildChatTile(
                    chatDoc: chatDoc,
                    otherParticipantId: otherParticipantId,
                    name: name,
                    photoUrl: photoUrl,
                    lastMessage: lastMessage,
                    lastMessageTime: lastMessageTime,
                    unreadCount: unreadCount,
                    isProfessional: isProfessional,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSelfChatTile(DocumentSnapshot chatDoc, String lastMessage, DateTime? lastMessageTime) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withAlpha(26), width: 1),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatDoc.id,
                otherUserId: currentUser.uid,
                otherUserName: 'Me',
              ),
            ),
          );
        },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    backgroundImage: currentUser.photoURL != null
                        ? NetworkImage(currentUser.photoURL!)
                        : null,
                    backgroundColor: Colors.amber.withAlpha(51),
                    child: currentUser.photoURL == null
                        ? const Icon(Icons.note_alt, color: Colors.amber, size: 28)
                        : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notes to Self',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              timeago.format(lastMessageTime, locale: 'en_short'),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildChatTile({
    required DocumentSnapshot chatDoc,
    required String otherParticipantId,
    required String name,
    required String photoUrl,
    required String lastMessage,
    required DateTime? lastMessageTime,
    required int unreadCount,
    required bool isProfessional,
  }) {
    return Dismissible(
      key: Key(chatDoc.id),
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_forever,
          color: Colors.white,
          size: 28,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete Conversation',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete your conversation with $name? This cannot be undone.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatDoc.id);
          final messagesSnapshot = await chatRef.collection('messages').get();
          final batch = FirebaseFirestore.instance.batch();

          for (final doc in messagesSnapshot.docs) {
            batch.delete(doc.reference);
          }

          batch.delete(chatRef);
          await batch.commit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Conversation deleted', style: GoogleFonts.poppins()),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error deleting chat: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting conversation', style: GoogleFonts.poppins()),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withAlpha(26), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatDoc.id,
                  otherUserId: otherParticipantId,
                  otherUserName: name,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unreadCount > 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: photoUrl.isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                          : CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(51),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                    ),
                    if (isProfessional)
                      Positioned(
                        bottom: 0,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              timeago.format(lastMessageTime, locale: 'en_short'),
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                                height: 1.3,
                                color: unreadCount > 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: GoogleFonts.poppins(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChat(BuildContext context, String chatId, String otherUserName) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete your conversation with $otherUserName?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
        final messagesSnapshot = await chatRef.collection('messages').get();
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(chatRef);
        await batch.commit();

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Conversation deleted', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _findUserByEmail(String userRole) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final TextEditingController emailController = TextEditingController();

    final String? email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Find ${userRole.capitalize()}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Enter email address',
            hintText: 'user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
            child: Text('Search', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (email == null || !mounted) return;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Searching for user...', style: GoogleFonts.poppins()),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final foundUserRole = userData['role'];
        final userName = NameUtils.extractName(userData);

        // Check existing chat
        final existingChatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .get();

        for (final chatDoc in existingChatQuery.docs) {
          final participants = List<String>.from(chatDoc['participants']);
          if (participants.contains(userDoc.id)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatDoc.id,
                  otherUserId: userDoc.id,
                  otherUserName: userName,
                ),
              ),
            );
            return;
          }
        }

        // Create new chat
        final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
        await newChatRef.set({
          'participants': [currentUser.uid, userDoc.id],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadCount': {currentUser.uid: 0, userDoc.id: 0},
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: newChatRef.id,
              otherUserId: userDoc.id,
              otherUserName: userName,
            ),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('No user found with email: $email', style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error finding user: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error searching for user', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createSelfChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (final chatDoc in existingChatQuery.docs) {
        final participants = List<String>.from(chatDoc['participants']);
        if (participants.length == 1 && participants[0] == currentUser.uid) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatDoc.id,
                otherUserId: currentUser.uid,
                otherUserName: 'Me',
              ),
            ),
          );
          return;
        }
      }

      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      await newChatRef.set({
        'participants': [currentUser.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'unreadCount': {currentUser.uid: 0},
      });

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: newChatRef.id,
            otherUserId: currentUser.uid,
            otherUserName: 'Me',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error creating self-chat: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error creating notes', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
