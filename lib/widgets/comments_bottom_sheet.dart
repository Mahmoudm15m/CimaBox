import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/comments_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/details_provider.dart';
import '../models/comment_model.dart';
import '../models/reply_model.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String contentId;

  const CommentsBottomSheet({super.key, required this.contentId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Stream<List<CommentModel>> _commentsStream;

  @override
  void initState() {
    super.initState();
    _commentsStream = Provider.of<CommentsProvider>(context, listen: false).getCommentsStream(widget.contentId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      Provider.of<DetailsProvider>(context, listen: false).showLoginDialog(context);
      return;
    }

    final provider = Provider.of<CommentsProvider>(context, listen: false);
    final userId = auth.user!.uid;
    final userName = auth.user!.displayName ?? 'مستخدم';
    final userImage = auth.user!.photoURL ?? 'https://i.imgur.com/BoN9kdC.png';

    _commentController.clear();
    FocusScope.of(context).unfocus();

    await provider.addComment(
      contentId: widget.contentId,
      userId: userId,
      userName: userName,
      userImage: userImage,
      text: text,
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "التعليقات",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: _commentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        "كن أول من يعلق على هذا العمل",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: comments.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 30, thickness: 1),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _CommentItemWidget(
                        key: ValueKey(comment.id),
                        comment: comment,
                        formatTime: _formatTime,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 12
                    : 35,
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
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: "أضف تعليقاً جديداً...",
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
                    onTap: _submitComment,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItemWidget extends StatefulWidget {
  final CommentModel comment;
  final Function(DateTime) formatTime;

  const _CommentItemWidget({
    super.key,
    required this.comment,
    required this.formatTime,
  });

  @override
  State<_CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<_CommentItemWidget> {
  bool _showReplies = false;
  Stream<List<ReplyModel>>? _repliesStream;
  final TextEditingController _replyController = TextEditingController();
  final String adminEmail = "mahmoudm15m@gmail.com";
  final String adminUid = "cDH9gfiqwmNuQjOOUwXRHiQ6I803";

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _handleLike(BuildContext context, bool isLiked) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      Provider.of<DetailsProvider>(context, listen: false).showLoginDialog(context);
      return;
    }
    Provider.of<CommentsProvider>(context, listen: false).toggleCommentLike(widget.comment.id, auth.user!.uid, isLiked);
  }

  void _handleReplyLike(BuildContext context, String replyId, bool isLiked) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      Provider.of<DetailsProvider>(context, listen: false).showLoginDialog(context);
      return;
    }
    Provider.of<CommentsProvider>(context, listen: false).toggleReplyLike(widget.comment.id, replyId, auth.user!.uid, isLiked);
  }

  void _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      Provider.of<DetailsProvider>(context, listen: false).showLoginDialog(context);
      return;
    }

    final provider = Provider.of<CommentsProvider>(context, listen: false);
    final userId = auth.user!.uid;
    final userName = auth.user!.displayName ?? 'مستخدم';
    final userImage = auth.user!.photoURL ?? 'https://i.imgur.com/BoN9kdC.png';

    _replyController.clear();
    FocusScope.of(context).unfocus();

    await provider.addReply(
      commentId: widget.comment.id,
      userId: userId,
      userName: userName,
      userImage: userImage,
      text: text,
    );
  }

  void _handleDeleteComment(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("حذف التعليق", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text("هل أنت متأكد من حذف هذا التعليق بالكامل؟", style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CommentsProvider>(context, listen: false).deleteComment(widget.comment.id);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteReply(BuildContext context, String replyId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("حذف الرد", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text("هل أنت متأكد من حذف هذا الرد؟", style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CommentsProvider>(context, listen: false).deleteReply(widget.comment.id, replyId);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isLiked = auth.user != null && widget.comment.likedBy.contains(auth.user!.uid);
    final bool canDelete = auth.user != null && (auth.user!.email == adminEmail || auth.user!.uid == widget.comment.userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(widget.comment.userImage),
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.comment.userName,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                if (widget.comment.userId == adminUid) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.formatTime(widget.comment.createdAt),
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                                if (canDelete) ...[
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => _handleDeleteComment(context),
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.comment.text,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _handleLike(context, isLiked),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.redAccent : Colors.white54,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.comment.likesCount.toString(),
                                style: TextStyle(
                                    color: isLiked ? Colors.redAccent : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showReplies = !_showReplies;
                            if (_showReplies && _repliesStream == null) {
                              _repliesStream = Provider.of<CommentsProvider>(context, listen: false).getRepliesStream(widget.comment.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.mode_comment_outlined, color: Colors.white54, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.comment.repliesCount} ردود",
                                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
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

        if (_showReplies)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 15, right: 35),
            padding: const EdgeInsets.only(right: 15, top: 5, bottom: 5),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white10, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_repliesStream != null)
                  StreamBuilder<List<ReplyModel>>(
                    stream: _repliesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final replies = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final reply = replies[index];
                          final isReplyLiked = auth.user != null && reply.likedBy.contains(auth.user!.uid);
                          final bool canDeleteReply = auth.user != null && (auth.user!.email == adminEmail || auth.user!.uid == reply.userId);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: CachedNetworkImageProvider(reply.userImage),
                                  backgroundColor: Colors.grey[800],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E).withOpacity(0.7),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      reply.userName,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                    if (reply.userId == adminUid) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.verified, color: Colors.blueAccent, size: 12),
                                                    ],
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      widget.formatTime(reply.createdAt),
                                                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                                                    ),
                                                    if (canDeleteReply) ...[
                                                      const SizedBox(width: 10),
                                                      GestureDetector(
                                                        onTap: () => _handleDeleteReply(context, reply.id),
                                                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 12),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              reply.text,
                                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _handleReplyLike(context, reply.id, isReplyLiked),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isReplyLiked ? Icons.favorite : Icons.favorite_border,
                                                color: isReplyLiked ? Colors.redAccent : Colors.white38,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                reply.likesCount.toString(),
                                                style: TextStyle(
                                                    color: isReplyLiked ? Colors.redAccent : Colors.white38,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _replyController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "اكتب رداً...",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF252525),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitReply,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white70, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}