import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UniversalMessagingScreen extends StatefulWidget {
  final String userId;
  final String schoolId;
  final String userType;
  final String username;

  const UniversalMessagingScreen({
    super.key,
    required this.userId,
    required this.schoolId,
    required this.userType,
    required this.username,
  });

  @override
  UniversalMessagingScreenState createState() => UniversalMessagingScreenState();
}

// Create a fixed list of background colors for avatars
final List<Color> avatarColors = [
  Colors.blue[400]!,
  Colors.purple[400]!,
  Colors.orange[400]!,
  Colors.green[400]!,
  Colors.pink[400]!,
  Colors.teal[400]!,
  Colors.indigo[400]!,
  Colors.red[400]!,
];

class UniversalMessagingScreenState extends State<UniversalMessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedRecipientId;
  String? _selectedRecipientName;

  void _showNewMessageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Message'),
          backgroundColor: Colors.white,
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('schoolCode', isEqualTo: widget.schoolId)
                  .where('role', whereIn: _getAllowedRoles())
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                var users = snapshot.data?.docs ?? [];
                users = users.where((doc) => doc.id != widget.userId).toList();

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    String name = userData['name'] ?? 'Unknown';
                    String role = userData['role'] ?? '';
                    String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    // Use the name's first character ASCII value to deterministically assign a color
                    final colorIndex = name.isNotEmpty
                        ? name.codeUnitAt(0) % avatarColors.length
                        : 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 8.0,
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: avatarColors[colorIndex],
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        role.toLowerCase(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedRecipientId = users[index].id;
                          _selectedRecipientName = userData['name'];
                        });
                        Navigator.of(context).pop();
                      },
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  List<String> _getAllowedRoles() {
    switch (widget.userType) {
      case 'parent':
        return ['teacher'];
      case 'teacher':
        return ['parent', 'student'];
      case 'student':
        return ['teacher'];
      default:
        return [];
    }
  }

  void _handleSubmitted() {
    if (_messageController.text.isNotEmpty) {
      _sendMessage(_messageController.text);
      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String content) async {
    if (_selectedRecipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient first')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('messages')
          .add({
        'senderId': widget.userId,
        'senderName': widget.username,
        'recipientId': _selectedRecipientId,
        'recipientName': _selectedRecipientName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'participants': [widget.userId, _selectedRecipientId],
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Widget _buildMessageComposer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          constraints: const BoxConstraints(
            minHeight: 64.0,
            maxHeight: 120.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16.0,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                margin: const EdgeInsets.only(bottom: 4.0),
                child: Material(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(24.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24.0),
                    onTap: _handleSubmitted,
                    child: Container(
                      height: 44.0,
                      width: 44.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedRecipientName ?? 'Messages',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 20,
          )
      ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showNewMessageDialog,
          ),
        ],
      ),
      body: _selectedRecipientName == null ?  _buildContactsScreen(): Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(widget.schoolId)
                  .collection('messages')
                  .where('participants', arrayContains: widget.userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start a conversation!'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    bool isCurrentUser = message['senderId'] == widget.userId;

                    // Update read status if recipient
                    if (!isCurrentUser && !message['read']) {
                      messages[index].reference.update({'read': true});
                    }

                    return MessageBubble(
                      message: message['content'],
                      isCurrentUser: isCurrentUser,
                      senderName: message['senderName'],
                      timestamp: message['timestamp'] ?? Timestamp.now(),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildContactsScreen() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('schoolCode', isEqualTo: widget.schoolId)
          .where('role', whereIn: _getAllowedRoles())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading contacts',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 16.0,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        var users = snapshot.data?.docs ?? [];
        users = users.where((doc) => doc.id != widget.userId).toList();

        if (users.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No contacts available',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String name = userData['name'] ?? 'Unknown';
            String role = userData['role'] ?? '';
            String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

            // Use the name's first character ASCII value to deterministically assign a color
            final colorIndex = name.isNotEmpty
                ? name.codeUnitAt(0) % avatarColors.length
                : 0;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: avatarColors[colorIndex],
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                role.toLowerCase(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedRecipientId = users[index].id;
                  _selectedRecipientName = userData['name'];
                });
              },
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            );
          },
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final String senderName;
  final Timestamp timestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.senderName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isCurrentUser ? 64.0 : 16.0,
        right: isCurrentUser ? 16.0 : 64.0,
        top: 4.0,
        bottom: 4.0,
      ),
      child: Column(
        crossAxisAlignment:
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (!isCurrentUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
              child: Text(
                senderName,
                style: const TextStyle(
                  fontSize: 13.0,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue[400] : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16.0),
                topRight: const Radius.circular(16.0),
                bottomLeft: Radius.circular(isCurrentUser ? 16.0 : 4.0),
                bottomRight: Radius.circular(isCurrentUser ? 4.0 : 16.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 16.0,
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 16.0,
                  height: 1.3,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
            child: Text(
              DateFormat('MMM d, h:mm a').format(timestamp.toDate()),
              style: TextStyle(
                fontSize: 11.0,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


