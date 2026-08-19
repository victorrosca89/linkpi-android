import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helpers/chat_controller.dart';
import '../helpers/storage_helper.dart';
import '../models/network_packet.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? autoInitName;
  const HomeScreen({super.key, this.autoInitName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoInitName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final controller = context.read<ChatController>();
        if (!controller.isInitialized) {
          await controller.initialize(widget.autoInitName!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, ctrl, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF08080c),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0d0d14),
            elevation: 0,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ade80),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub,
                        color: Color(0xFF08080c), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'LINKPI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status dot
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _statusColor(ctrl),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _statusText(ctrl),
                    style: TextStyle(
                      color: _statusColor(ctrl),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Color(0xFF60606e)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFF1c1c26)),
            ),
          ),
          body: ctrl.isInitialized ? _buildBody(ctrl) : _buildLoading(),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4ade80)),
          SizedBox(height: 16),
          Text('Se conectează la rețea...',
              style: TextStyle(color: Color(0xFF60606e))),
        ],
      ),
    );
  }

  Widget _buildBody(ChatController ctrl) {
    return Column(
      children: [
        // IP info bar
        Container(
          color: const Color(0xFF0a0a12),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.lan_outlined,
                  size: 14, color: Color(0xFF60606e)),
              const SizedBox(width: 6),
              Text(
                '${ctrl.myIp}:50505',
                style: const TextStyle(
                    color: Color(0xFF60606e), fontSize: 11),
              ),
              const Spacer(),
              const Icon(Icons.people_outline,
                  size: 14, color: Color(0xFF60606e)),
              const SizedBox(width: 4),
              Text(
                'Noduri: ${ctrl.users.where((u) => u.isOnline).length + 1}',
                style: const TextStyle(
                    color: Color(0xFF60606e), fontSize: 11),
              ),
            ],
          ),
        ),

        Expanded(
          child: ctrl.users.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  itemCount: ctrl.users.length,
                  itemBuilder: (context, i) =>
                      _UserTile(user: ctrl.users[i], ctrl: ctrl),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_tethering,
              size: 56, color: Colors.white.withOpacity(0.07)),
          const SizedBox(height: 16),
          const Text(
            'Se caută dispozitive...',
            style: TextStyle(color: Color(0xFF60606e), fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Asigură-te că ești în aceeași rețea Wi-Fi',
            style: TextStyle(color: Color(0xFF3a3a4a), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ChatController ctrl) {
    if (ctrl.offlineMode) return const Color(0xFF60606e);
    if (ctrl.busyMode) return const Color(0xFFef4444);
    return const Color(0xFF4ade80);
  }

  String _statusText(ChatController ctrl) {
    if (ctrl.offlineMode) return 'OFFLINE';
    if (ctrl.busyMode) return 'OCCUPAT';
    return 'ONLINE';
  }
}

class _UserTile extends StatelessWidget {
  final ChatUser user;
  final ChatController ctrl;

  const _UserTile({required this.user, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final history = ctrl.chatHistory[user.email] ?? [];
    final lastMsg = history.isNotEmpty ? history.last : null;

    return InkWell(
      onTap: () {
        ctrl.selectUser(user);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF1c1c26), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c26),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Center(
                child: Text(
                  user.initial,
                  style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMsg != null)
                        Text(
                          lastMsg.timeText,
                          style: const TextStyle(
                              color: Color(0xFF60606e), fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg != null
                              ? (lastMsg.isDeleted
                                  ? '🗑 Mesaj șters'
                                  : lastMsg.isFile
                                      ? '📎 ${lastMsg.fileName}'
                                      : lastMsg.text)
                              : user.email,
                          style: const TextStyle(
                            color: Color(0xFF60606e),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status dot
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _dotColor(),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _dotColor() {
    if (!user.isOnline) return const Color(0xFF60606e);
    if (user.status == 'busy') return const Color(0xFFef4444);
    return const Color(0xFF4ade80);
  }
}
