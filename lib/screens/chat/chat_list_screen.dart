import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexia_app/screens/chat/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(
        child: Text(
          'You need to be logged in to see your chats',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search for chats
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[800],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting with parents or professionals',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.5,
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
              // Force refresh by waiting briefly
              await Future.delayed(const Duration(milliseconds: 500));
              setState(() {});
            },
            child: ListView.separated(
              itemCount: snapshot.data!.docs.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final chatDoc = snapshot.data!.docs[index];
                final chatData = chatDoc.data() as Map<String, dynamic>;

                final String chatStatus =
                    chatData['status'] as String? ?? 'accepted';
                final String requestedBy =
                    chatData['requestedBy'] as String? ?? '';
                final bool isPendingRequest = chatStatus == 'pending';
                final bool isIncomingRequest =
                    isPendingRequest && requestedBy != currentUser.uid;
                final bool isOutgoingRequest =
                    isPendingRequest && requestedBy == currentUser.uid;

                final participants =
                    List<String>.from(chatData['participants']);
                String otherParticipantId;

                // Check if this is a self-chat
                if (participants.length == 1 &&
                    participants.first == currentUser.uid) {
                  otherParticipantId = currentUser.uid;
                } else {
                  // Normal chat with another person
                  otherParticipantId = participants.firstWhere(
                    (id) => id != currentUser.uid,
                    orElse: () => 'unknown_user',
                  );
                }

                // Skip unknown users completely
                if (otherParticipantId == 'unknown_user') {
                  return Container();
                }

                final lastMessage = chatData['lastMessage'] as String? ?? '';
                final lastMessageTime =
                    (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                final unreadCount =
                    chatData['unreadCount.${currentUser.uid}'] as int? ?? 0;

                if (isPendingRequest && otherParticipantId != currentUser.uid) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherParticipantId)
                        .get(),
                    builder: (context, userSnapshot) {
                      String name = 'Loading...';
                      String photoUrl = '';
                      bool isProfessional = false;

                      if (userSnapshot.connectionState ==
                              ConnectionState.done &&
                          userSnapshot.hasData &&
                          userSnapshot.data!.exists) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        name = userData['name'] as String? ?? 'Unknown User';
                        photoUrl = userData['photoUrl'] as String? ?? '';
                        isProfessional =
                            (userData['role'] as String?) == 'professional';
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isIncomingRequest
                                ? Colors.amber.withAlpha(150)
                                : Colors.grey.withAlpha(26),
                            width: isIncomingRequest ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin:
                                            const EdgeInsets.only(right: 16),
                                        child: photoUrl.isNotEmpty
                                            ? CircleAvatar(
                                                backgroundImage:
                                                    NetworkImage(photoUrl))
                                            : CircleAvatar(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withAlpha(51),
                                                child: Text(
                                                  name.isNotEmpty
                                                      ? name[0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
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
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: const Icon(
                                              Icons.verified,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          isIncomingRequest
                                              ? 'Wants to connect with you'
                                              : 'Request pending',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: isIncomingRequest
                                                ? Colors.amber.shade800
                                                : Colors.grey.shade600,
                                            fontStyle: isOutgoingRequest
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Show accept/reject buttons only for incoming requests
                              if (isIncomingRequest)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 12, left: 76),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _rejectChatRequest(chatDoc.id),
                                        child: Text(
                                          'Reject',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _acceptChatRequest(
                                            chatDoc.id,
                                            otherParticipantId,
                                            name),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        child: Text(
                                          'Accept',
                                          style: GoogleFonts.poppins(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                if (otherParticipantId == currentUser.uid) {
                  // Self-chat display
                  return Card(
                    elevation: 0,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Colors.grey.withAlpha(26), width: 1),
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
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading:
                                    const Icon(Icons.delete, color: Colors.red),
                                title: Text(
                                  'Delete Notes',
                                  style: GoogleFonts.poppins(),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _deleteChat(
                                      context, chatDoc.id, 'Notes to Self');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.edit_note),
                                title: Text(
                                  'Rename Notes',
                                  style: GoogleFonts.poppins(),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Rename functionality coming soon',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
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
                                    ? const Icon(Icons.note_alt,
                                        color: Colors.amber, size: 28)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          timeago.format(lastMessageTime,
                                              locale: 'en_short'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastMessage,
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

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherParticipantId)
                      .get(),
                  builder: (context, userSnapshot) {
                    String name = 'Loading...';
                    String photoUrl = '';
                    bool isProfessional = false;

                    if (userSnapshot.connectionState == ConnectionState.done &&
                        userSnapshot.hasData &&
                        userSnapshot.data!.exists) {
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      name = userData['name'] as String? ?? 'Unknown';
                      photoUrl = userData['photoUrl'] as String? ?? '';
                      isProfessional =
                          (userData['role'] as String?) == 'professional';
                    }

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
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
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
                          // Get reference to chat document
                          final chatRef = FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatDoc.id);

                          // Delete all messages in the chat
                          final messagesSnapshot =
                              await chatRef.collection('messages').get();
                          final batch = FirebaseFirestore.instance.batch();

                          for (final doc in messagesSnapshot.docs) {
                            batch.delete(doc.reference);
                          }

                          // Delete the chat document itself
                          batch.delete(chatRef);

                          // Commit the batch
                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Conversation deleted',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error deleting chat: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error deleting conversation',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Colors.grey.withAlpha(26), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                            onLongPress: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (bottomSheetContext) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.delete,
                                          color: Colors.red),
                                      title: Text(
                                        'Delete Conversation',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      onTap: () {
                                        Navigator.of(bottomSheetContext).pop();
                                        _deleteChat(context, chatDoc.id, name);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.block),
                                      title: Text(
                                        'Block User',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      onTap: () {
                                        Navigator.of(bottomSheetContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Block user functionality coming soon',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin:
                                            const EdgeInsets.only(right: 16),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: unreadCount > 0
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: photoUrl.isNotEmpty
                                            ? CircleAvatar(
                                                backgroundImage:
                                                    NetworkImage(photoUrl),
                                              )
                                            : CircleAvatar(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withAlpha(51),
                                                child: Text(
                                                  name.isNotEmpty
                                                      ? name[0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
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
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: const Icon(
                                              Icons.verified,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                                timeago.format(lastMessageTime,
                                                    locale: 'en_short'),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                lastMessage,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w500
                                                      : FontWeight.w400,
                                                  height: 1.3,
                                                  color: unreadCount > 0
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (unreadCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    left: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  unreadCount.toString(),
                                                  style: GoogleFonts.poppins(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
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
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Store a reference to ScaffoldMessenger before the async operation
          // Removed unused scaffoldMessenger variable

          // Show dialog to select user type
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              // Keep your existing dialog code
              title: Text(
                'New Conversation',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                // Keep your existing dialog options
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('parent');
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    'Find a Parent',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('professional');
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    'Find a Professional',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('notes');
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    'Notes to Self',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ),
              ],
            ),
          );

          // CHANGE THIS PART - Replace the SnackBar with actual functionality
          if (result != null && mounted) {
            if (result == 'notes') {
              await _createSelfChat();
            } else {
              // Find parent or professional
              await _findUserByEmail(result);
            }
          }
        },
        tooltip: 'New Message',
        child: const Icon(Icons.chat),
      ),
    );
  }

  Future<void> _deleteChat(
      BuildContext context, String chatId, String otherUserName) async {
    // Keep only the scaffold messenger reference, remove the unused theme
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
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
          'Are you sure you want to delete your conversation with $otherUserName? This cannot be undone.',
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

    if (confirmed ?? false) {
      try {
        final chatRef =
            FirebaseFirestore.instance.collection('chats').doc(chatId);

        final messagesSnapshot = await chatRef.collection('messages').get();
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(chatRef);

        await batch.commit();

        // Check if widget is still mounted before using stored context
        if (!mounted) return;

        // Use the stored scaffoldMessenger reference here instead of ScaffoldMessenger.of(context)
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Conversation deleted',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Error deleting chat: $e');

        if (!mounted) return;

        // Use the stored scaffoldMessenger reference
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting conversation',
              style: GoogleFonts.poppins(),
            ),
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

    // Show dialog to enter email
    final String? email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Find ${userRole.capitalize()}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email address of the $userRole you want to chat with:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email address',
                hintText: 'example@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(),
            ),
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
          TextButton(
            onPressed: () {
              if (emailController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(emailController.text.trim());
              }
            },
            child: Text(
              'Find',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (email == null || !mounted) return;

    // Show loading
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          'Searching for $email...',
          style: GoogleFonts.poppins(),
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // Search for user by email and role
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: userRole)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'No $userRole found with that email',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final userId = userDoc.id;
      final name = userData['name'] as String? ?? 'Unknown User';

      // Check if chat already exists
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? existingChatId;

      for (final doc in existingChatQuery.docs) {
        final List<String> participants =
            List<String>.from(doc['participants']);
        if (participants.contains(userId) && participants.length == 2) {
          existingChatId = doc.id;
          break;
        }
      }

      if (existingChatId != null) {
        // Chat already exists, navigate to it
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: existingChatId!,
              otherUserId: userId,
              otherUserName: name,
            ),
          ),
        );

        return;
      }

      // Create new chat
      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      final timestamp = FieldValue.serverTimestamp();

      await newChatRef.set({
        'participants': [currentUser.uid, userId],
        'createdAt': timestamp,
        'lastMessage': 'Chat request sent',
        'lastMessageTime': timestamp,
        'lastMessageSender': 'system',
        'unreadCount.${currentUser.uid}': 0,
        'unreadCount.$userId': 1, // Set unread for recipient
        'status': 'pending', // Add status field
        'requestedBy': currentUser.uid, // Add requestedBy field
      });

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: newChatRef.id,
            otherUserId: userId,
            otherUserName: name,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error finding user: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error finding user: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
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
      // Check if self-chat already exists
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', isEqualTo: [currentUser.uid]).get();

      if (existingChatQuery.docs.isNotEmpty) {
        // Self-chat already exists, navigate to it
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: existingChatQuery.docs.first.id,
              otherUserId: currentUser.uid,
              otherUserName: 'Me',
            ),
          ),
        );

        return;
      }

      // Create new self-chat
      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      final timestamp = FieldValue.serverTimestamp();

      await newChatRef.set({
        'participants': [currentUser.uid],
        'createdAt': timestamp,
        'lastMessage': '',
        'lastMessageTime': timestamp,
        'lastMessageSender': '',
        'unreadCount.${currentUser.uid}': 0,
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
          content: Text(
            'Error creating notes: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptChatRequest(
      String chatId, String otherUserId, String otherUserName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Update chat status to 'accepted'
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'status': 'accepted',
      });

      // Add a system message to the chat
      final timestamp = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': 'Chat request accepted. You can now send messages.',
        'senderId': 'system',
        'timestamp': timestamp,
        'isSystemMessage': true,
      });

      // Update the chat with the first message
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': 'Chat request accepted',
        'lastMessageTime': timestamp,
        'lastMessageSender': 'system',
      });

      if (!mounted) return;

      // Navigate to the chat
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
          ),
        ),
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Chat request accepted',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error accepting chat request: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error accepting request',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectChatRequest(String chatId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Delete the chat
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      final messagesSnapshot = await chatRef.collection('messages').get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(chatRef);
      await batch.commit();

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Chat request rejected',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      debugPrint('Error rejecting chat request: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error rejecting request',
            style: GoogleFonts.poppins(),
          ),
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
