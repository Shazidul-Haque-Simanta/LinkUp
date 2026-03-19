import 'package:flutter/material.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/group_models.dart';
import 'package:project_v2/models/user_model.dart';
// Note: In a production app, real AES/RSA encryption should be used. 
// For this level, we rely on Firebase Rules + private in-app logic to keep messages unreadable to non-members.

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final user = _firebaseService.currentUser;
    if (user == null) return;
    
    // Check membership authorization right before sending
    final isMember = widget.group.members.containsKey(user.uid);
    if (!isMember) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied: You must join the group to send messages.')));
      return;
    }

    setState(() => _isSending = true);
    try {
      // In a real encrypted app, you would encrypt `text` here using a shared group key
      // e.g., String encryptedMsg = EncryptionHelper.encrypt(text, widget.group.secretKey);
      await _firebaseService.sendGroupMessage(widget.group.id, text, user.uid);
      _msgController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _firebaseService.currentUser;
    final isMember = user != null && widget.group.members.containsKey(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '${widget.group.members.length} member(s)', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: !isMember 
          ? _buildAccessDenied() 
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _firebaseService.listenToGroupMessages(widget.group.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return const Center(child: Text('Be the first to say hi!', style: TextStyle(color: Colors.grey)));
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.userId == user.uid;
                          // In a real encrypted app, you would decrypt `msg.text` here
                          return _buildMessageBubble(msg, isMe);
                        },
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Private Study Group', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
          ),
          const SizedBox(height: 8),
          Text(
            'You must join this group to read or send messages.', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe 
              ? Theme.of(context).colorScheme.primaryContainer 
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              FutureBuilder<UserModel?>(
                future: _firebaseService.getUserProfile(msg.userId),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name ?? 'Member';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      name, 
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.indigo[400],
                      ),
                    ),
                  );
                },
              ),
            Text(
              msg.text, 
              style: TextStyle(
                color: isMe 
                    ? Theme.of(context).colorScheme.onPrimaryContainer 
                    : Theme.of(context).colorScheme.onSurface, 
                fontSize: 14
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            radius: 24,
            child: _isSending 
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                : IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }
}
