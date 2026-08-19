import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../helpers/chat_controller.dart';
import '../models/network_packet.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<ChatController>();
    ctrl.onNewMessage = _scrollToBottom;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    final ctrl = context.read<ChatController>();
    ctrl.onNewMessage = null;
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<ChatController>().sendMessage(text);
    _textCtrl.clear();
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    context.read<ChatController>().sendFile(
          f.path!,
          f.name,
          f.size,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, ctrl, _) {
        final messages = ctrl.chatHistory[widget.user.email] ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF08080c),
          appBar: _buildAppBar(ctrl),
          body: Column(
            children: [
              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(msg: messages[i], ctrl: ctrl),
                      ),
              ),
              // Input area
              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ChatController ctrl) {
    final user = widget.user;
    return AppBar(
      backgroundColor: const Color(0xFF0d0d14),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1c1c26),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                user.initial,
                style: const TextStyle(
                  color: Color(0xFF4ade80),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor(user),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.statusText,
                      style: TextStyle(
                        color: _statusColor(user),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFF1c1c26)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          const Text(
            'Niciun mesaj încă',
            style: TextStyle(color: Color(0xFF60606e), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0d0d14),
        border: Border(top: BorderSide(color: Color(0xFF1c1c26))),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Attach file button
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFF60606e)),
            onPressed: _pickFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFF4ade80),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Scrie un mesaj...',
                hintStyle: const TextStyle(color: Color(0xFF60606e)),
                filled: true,
                fillColor: const Color(0xFF14141e),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1c1c26)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1c1c26)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF4ade80)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4ade80),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send,
                  color: Color(0xFF08080c), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ChatUser user) {
    if (!user.isOnline) return const Color(0xFF60606e);
    if (user.status == 'busy') return const Color(0xFFef4444);
    return const Color(0xFF4ade80);
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessageData msg;
  final ChatController ctrl;

  const _MessageBubble({required this.msg, required this.ctrl});

  bool _isImage(String? fileName) {
    if (fileName == null) return false;
    final ext = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!msg.isDeleted && msg.text.isNotEmpty)
              _OptionTile(
                icon: Icons.copy,
                label: 'Copiază textul',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copiat în clipboard'),
                      backgroundColor: Color(0xFF1c1c26),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            if (msg.isSent && !msg.isDeleted && !msg.isFile)
              _OptionTile(
                icon: Icons.edit,
                label: 'Editează',
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context);
                },
              ),
            if (msg.isSent && !msg.isDeleted)
              _OptionTile(
                icon: Icons.delete_outline,
                label: 'Șterge',
                color: const Color(0xFFef4444),
                onTap: () {
                  Navigator.pop(context);
                  ctrl.deleteMessage(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final editCtrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF14141e),
        title: const Text('Editează mesajul',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFF4ade80),
          maxLines: 4,
          minLines: 1,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0d0d14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1c1c26)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4ade80)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează',
                style: TextStyle(color: Color(0xFF60606e))),
          ),
          TextButton(
            onPressed: () {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty) {
                ctrl.editMessage(msg.id, newText);
              }
              Navigator.pop(context);
            },
            child: const Text('Salvează',
                style: TextStyle(color: Color(0xFF4ade80))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSent = msg.isSent;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isSent
                ? const Color(0xFF1a1a28)
                : const Color(0xFF141420),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isSent ? 14 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 14),
            ),
            border: Border.all(color: const Color(0xFF1c1c26), width: 0.5),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      msg.fromName,
                      style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Fișier attachment
                if (msg.isFile && !msg.isDeleted) _buildFileAttachment(context),
                // Text
                if (msg.displayText.isNotEmpty)
                  Text(
                    msg.displayText,
                    style: TextStyle(
                      color: msg.isDeleted
                          ? const Color(0xFF60606e)
                          : Colors.white,
                      fontSize: 14,
                      fontStyle: msg.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                const SizedBox(height: 4),
                // Time + edited
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.isEdited)
                      const Text(
                        'editat • ',
                        style: TextStyle(
                            color: Color(0xFF60606e), fontSize: 10),
                      ),
                    Text(
                      msg.timeText,
                      style: const TextStyle(
                          color: Color(0xFF60606e), fontSize: 10),
                    ),
                    if (isSent) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all,
                          size: 12, color: Color(0xFF4ade80)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context) {
    final hasPath =
        msg.filePath != null && msg.filePath!.isNotEmpty;
    final isImg = _isImage(msg.fileName);

    return GestureDetector(
      onTap: hasPath
          ? () async {
              if (isImg) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _ImageViewerScreen(filePath: msg.filePath!),
                  ),
                );
              } else {
                await OpenFilex.open(msg.filePath!);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0d0d14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1c1c26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImg ? Icons.image_outlined : Icons.insert_drive_file_outlined,
              color: const Color(0xFF4ade80),
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hasPath
                        ? msg.fileSizeText
                        : '${msg.fileSizeText} • Se primește...',
                    style: const TextStyle(
                        color: Color(0xFF60606e), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              hasPath ? Icons.open_in_new : Icons.hourglass_empty,
              size: 14,
              color: const Color(0xFF60606e),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white, size: 20),
      title: Text(
        label,
        style: TextStyle(
            color: color ?? Colors.white, fontSize: 14),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Image Viewer ──────────────────────────────────────────────────────────────

class _ImageViewerScreen extends StatelessWidget {
  final String filePath;
  const _ImageViewerScreen({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(filePath)),
        ),
      ),
    );
  }
}
