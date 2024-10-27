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

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(userData['name'] ?? 'Unknown'),
                      subtitle: Text(userData['role'] ?? ''),
                      onTap: () {
                        setState(() {
                          _selectedRecipientId = users[index].id;
                          _selectedRecipientName = userData['name'];
                        });
                        Navigator.of(context).pop();
                      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      height: 70.0,
      color: Colors.white,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration.collapsed(
                hintText: 'Send a message...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _handleSubmitted,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedRecipientName ?? 'Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showNewMessageDialog,
          ),
        ],
      ),
      body: Column(
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment:
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            senderName,
            style: const TextStyle(
              fontSize: 12.0,
              color: Colors.black54,
            ),
          ),
          Material(
            borderRadius: BorderRadius.circular(8.0),
            elevation: 1,
            color: isCurrentUser ? Colors.lightBlueAccent : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              child: Text(
                message,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 15.0,
                ),
              ),
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(timestamp.toDate()),
            style: const TextStyle(
              fontSize: 10.0,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}