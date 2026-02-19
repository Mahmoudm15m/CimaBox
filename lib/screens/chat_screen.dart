import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Stream<List<MessageModel>> _chatStream;
  late Stream<bool> _chatStatusStream;
  final String adminUid = "cDH9gfiqwmNuQjOOUwXRHiQ6I803";

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ChatProvider>(context, listen: false);
    _chatStream = provider.getMessagesStream();
    _chatStatusStream = provider.getChatStatusStream();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);
    final userId = auth.user!.uid;
    final userName = auth.user!.displayName ?? 'مستخدم';
    final userImage = auth.user!.photoURL ?? 'https://i.imgur.com/BoN9kdC.png';

    _messageController.clear();

    await provider.sendMessage(
      senderId: userId,
      senderName: userName,
      senderImage: userImage,
      text: text,
    );
  }

  void _handleDelete(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("حذف الرسالة", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text("هل أنت متأكد من حذف هذه الرسالة؟", style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).deleteMessage(messageId);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String hour = time.hour > 12 ? (time.hour - 12).toString() : time.hour.toString();
    if (hour == '0') hour = '12';
    String minute = time.minute.toString().padLeft(2, '0');
    String amPm = time.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.uid ?? '';
    final bool isCurrentUserAdmin = currentUserId == adminUid && currentUserId.isNotEmpty;

    return StreamBuilder<bool>(
        stream: _chatStatusStream,
        builder: (context, statusSnapshot) {
          final isChatEnabled = statusSnapshot.data ?? true;

          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1A1A1A),
              elevation: 0,
              title: const Text(
                "غرفة الدردشه",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (isCurrentUserAdmin)
                  Row(
                    children: [
                      Text(
                        isChatEnabled ? "مفعلة" : "معطلة",
                        style: TextStyle(
                            color: isChatEnabled ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      Switch(
                        value: isChatEnabled,
                        activeColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.redAccent,
                        inactiveTrackColor: Colors.redAccent.withOpacity(0.3),
                        onChanged: (val) {
                          Provider.of<ChatProvider>(context, listen: false).toggleChatStatus(val);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      stream: _chatStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                        }
                        final messages = snapshot.data ?? [];
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              "لا توجد رسائل حالياً، كن أول من يكتب!",
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          physics: const BouncingScrollPhysics(),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == currentUserId;
                            final isMessageAdmin = message.senderId == adminUid && adminUid.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: CachedNetworkImageProvider(message.senderImage),
                                      backgroundColor: Colors.grey[800],
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.redAccent : const Color(0xFF252525),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(15),
                                          topRight: const Radius.circular(15),
                                          bottomLeft: Radius.circular(isMe ? 0 : 15),
                                          bottomRight: Radius.circular(isMe ? 15 : 0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  message.senderName,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (isMessageAdmin) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.verified, color: Colors.blueAccent, size: 12),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          Text(
                                            message.text,
                                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(message.timestamp),
                                                style: TextStyle(
                                                  color: isMe ? Colors.white54 : Colors.white38,
                                                  fontSize: 9,
                                                ),
                                              ),
                                              if (isCurrentUserAdmin) ...[
                                                const SizedBox(width: 10),
                                                GestureDetector(
                                                  onTap: () => _handleDelete(message.id),
                                                  child: Icon(Icons.delete_outline, color: isMe ? Colors.white : Colors.redAccent, size: 14),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    Column(
                                      children: [
                                        if (isMessageAdmin)
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 4),
                                            child: Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                                          ),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: CachedNetworkImageProvider(message.senderImage),
                                          backgroundColor: Colors.grey[800],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (isChatEnabled || isCurrentUserAdmin)
                    Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                        top: 12,
                        left: 16,
                        right: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        border: Border(top: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: "اكتب رسالة...",
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: const Color(0xFF252525),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                        top: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        border: Border(top: BorderSide(color: Colors.white10)),
                      ),
                      child: const Text(
                        "الدردشة معطلة حالياً من قبل الإدارة",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
    );
  }
}