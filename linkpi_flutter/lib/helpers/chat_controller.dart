import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/network_packet.dart';
import '../networking/udp_discovery.dart';
import '../networking/tcp_server.dart';
import '../networking/tcp_client.dart';
import '../helpers/ip_helper.dart';
import '../helpers/storage_helper.dart';

class ChatController extends ChangeNotifier {
  static const int peerTimeoutSeconds = 15;

  String myName = '';
  String myEmail = '';
  String myIp = '';
  bool busyMode = false;
  bool offlineMode = false;
  bool isInitialized = false;

  final List<ChatUser> users = [];
  final Map<String, List<ChatMessageData>> chatHistory = {};
  ChatUser? selectedUser;

  final _uuid = const Uuid();
  final _discovery = UdpDiscovery();
  final _server = TcpServer();
  Timer? _cleanupTimer;
  Timer? _ipCheckTimer;

  // Callback pentru scroll-to-bottom după mesaj nou
  VoidCallback? onNewMessage;
  // Callback pentru notificare când mesaj vine din background
  void Function(String fromName, String text)? onNotification;

  // ── Inițializare ────────────────────────────────────────────────────────────

  Future<void> initialize(String name) async {
    myName = name;
    myIp = await IpHelper.getLocalIp();
    myEmail = IpHelper.generateEmail(myName, myIp);

    final profile = await StorageHelper.loadProfile();
    busyMode = await StorageHelper.getBusy();
    offlineMode = await StorageHelper.getOffline();

    await StorageHelper.saveProfile(myName, myEmail, myIp);

    _startServer();
    if (!offlineMode) await _startDiscovery();
    _startTimers();

    isInitialized = true;
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    myName = newName;
    myEmail = IpHelper.generateEmail(myName, myIp);
    await StorageHelper.saveProfile(myName, myEmail, myIp);
    _discovery.updateInfo(myName, myEmail, myIp);
    notifyListeners();
  }

  Future<void> setBusy(bool v) async {
    busyMode = v;
    await StorageHelper.setBusy(v);
    _discovery.setStatus(_myStatus);
    notifyListeners();
  }

  Future<void> setOffline(bool v) async {
    offlineMode = v;
    await StorageHelper.setOffline(v);
    if (offlineMode) {
      _discovery.stop();
    } else {
      await _startDiscovery();
    }
    notifyListeners();
  }

  String get _myStatus {
    if (offlineMode) return 'offline';
    if (busyMode) return 'busy';
    return 'online';
  }

  // ── Networking ───────────────────────────────────────────────────────────────

  void _startServer() {
    _server.onMessageReceived = _onMessageReceived;
    _server.onFileReceived = _onFileReceived;
    _server.onMessageEdited = _onMessageEdited;
    _server.onMessageDeleted = _onMessageDeleted;
    _server.start();
  }

  Future<void> _startDiscovery() async {
    _discovery.onPeerDiscovered = _onPeerDiscovered;
    await _discovery.start(myName, myEmail, myIp, TcpServer.port, _myStatus);
  }

  void _onPeerDiscovered(NetworkPacket packet) {
    final email = packet.email ?? '';
    if (email.isEmpty) return;

    final existing = users.where((u) => u.email == email).firstOrNull;
    if (existing != null) {
      existing.name = packet.name ?? existing.name;
      existing.ip = packet.ip ?? existing.ip;
      existing.port = packet.port ?? existing.port;
      existing.isOnline = true;
      existing.lastSeen = DateTime.now();
      existing.status = packet.status ?? 'online';
    } else {
      final user = ChatUser(
        name: packet.name ?? 'Anonim',
        email: email,
        ip: packet.ip ?? '',
        port: packet.port ?? TcpServer.port,
        lastSeen: DateTime.now(),
        status: packet.status ?? 'online',
      );
      users.add(user);
      // Încearcă să încarce istoricul salvat
      StorageHelper.loadChatHistory(email).then((msgs) {
        chatHistory[email] = msgs;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _onMessageReceived(NetworkPacket packet, String fromEmail) {
    final msg = ChatMessageData(
      id: packet.id ?? _uuid.v4(),
      fromEmail: packet.fromEmail ?? fromEmail,
      fromName: packet.fromName ?? 'Anonim',
      text: packet.text ?? '',
      timeText: packet.timeText ?? _formatNow(),
      isSent: false,
      fileName: packet.fileName,
      fileSize: packet.fileSize,
    );

    _addMessage(fromEmail, msg);

    final isActive = selectedUser?.email == fromEmail;
    if (!isActive) {
      onNotification?.call(msg.fromName, msg.text.isNotEmpty ? msg.text : '📎 Fișier');
    } else {
      onNewMessage?.call();
    }
  }

  void _onFileReceived(String fromEmail, String fromName, int fileSize,
      String fileName, String savedPath) {
    // Actualizăm mesajul existent cu calea reală
    final history = chatHistory[fromEmail];
    if (history != null) {
      for (final m in history) {
        if (m.fileName == fileName && (m.filePath == null || m.filePath!.isEmpty)) {
          m.filePath = savedPath;
          break;
        }
      }
      StorageHelper.saveChatHistory(fromEmail, history);
    }
    final isActive = selectedUser?.email == fromEmail;
    if (!isActive) {
      onNotification?.call(fromName, '📎 Fișier primit: $fileName');
    } else {
      onNewMessage?.call();
    }
    notifyListeners();
  }

  void _onMessageEdited(String messageId, String newText, String fromEmail) {
    final history = chatHistory[fromEmail];
    if (history != null) {
      for (final m in history) {
        if (m.id == messageId) {
          m.text = newText;
          m.isEdited = true;
          break;
        }
      }
      StorageHelper.saveChatHistory(fromEmail, history);
    }
    notifyListeners();
  }

  void _onMessageDeleted(String messageId, String fromEmail) {
    final history = chatHistory[fromEmail];
    if (history != null) {
      for (final m in history) {
        if (m.id == messageId) {
          m.isDeleted = true;
          m.text = '';
          m.fileName = null;
          break;
        }
      }
      StorageHelper.saveChatHistory(fromEmail, history);
    }
    notifyListeners();
  }

  // ── Trimitere ────────────────────────────────────────────────────────────────

  void sendMessage(String text) {
    final user = selectedUser;
    if (user == null || text.trim().isEmpty) return;

    final msg = ChatMessageData(
      id: _uuid.v4(),
      fromEmail: myEmail,
      fromName: myName,
      text: text.trim(),
      timeText: _formatNow(),
      isSent: true,
    );

    _addMessage(user.email, msg);
    final packet = NetworkPacket.message(msg);
    TcpClient.sendMessage(user.ip, user.port, packet);
    onNewMessage?.call();
  }

  void sendFile(String filePath, String fileName, int fileSize) {
    final user = selectedUser;
    if (user == null) return;

    final msg = ChatMessageData(
      id: _uuid.v4(),
      fromEmail: myEmail,
      fromName: myName,
      text: 'A trimis un fișier',
      timeText: _formatNow(),
      isSent: true,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
    );

    _addMessage(user.email, msg);
    final packet = NetworkPacket.message(msg);
    TcpClient.sendFile(user.ip, user.port, packet, filePath);
    onNewMessage?.call();
  }

  void editMessage(String messageId, String newText) {
    final user = selectedUser;
    if (user == null) return;

    final history = chatHistory[user.email];
    if (history != null) {
      for (final m in history) {
        if (m.id == messageId) {
          m.text = newText;
          m.isEdited = true;
          break;
        }
      }
      StorageHelper.saveChatHistory(user.email, history);
    }

    final packet = NetworkPacket.edit(messageId, newText, myEmail);
    TcpClient.sendMessage(user.ip, user.port, packet);
    notifyListeners();
  }

  void deleteMessage(String messageId) {
    final user = selectedUser;
    if (user == null) return;

    final history = chatHistory[user.email];
    if (history != null) {
      for (final m in history) {
        if (m.id == messageId) {
          m.isDeleted = true;
          m.text = '';
          m.fileName = null;
          break;
        }
      }
      StorageHelper.saveChatHistory(user.email, history);
    }

    final packet = NetworkPacket.delete(messageId, myEmail);
    TcpClient.sendMessage(user.ip, user.port, packet);
    notifyListeners();
  }

  void selectUser(ChatUser user) {
    selectedUser = user;
    if (!chatHistory.containsKey(user.email)) {
      StorageHelper.loadChatHistory(user.email).then((msgs) {
        chatHistory[user.email] = msgs;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _addMessage(String email, ChatMessageData msg) {
    chatHistory.putIfAbsent(email, () => []);
    chatHistory[email]!.add(msg);
    StorageHelper.saveChatHistory(email, chatHistory[email]!);
    notifyListeners();
  }

  String _formatNow() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  void _startTimers() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      bool changed = false;
      final toRemove = <ChatUser>[];

      for (final u in users) {
        final diff = now.difference(u.lastSeen).inSeconds;
        if (diff > peerTimeoutSeconds && u.isOnline) {
          u.isOnline = false;
          changed = true;
        }
        if (diff > peerTimeoutSeconds * 3) {
          toRemove.add(u);
          changed = true;
        }
      }
      for (final u in toRemove) users.remove(u);
      if (changed) notifyListeners();
    });

    _ipCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final newIp = await IpHelper.getLocalIp();
      if (newIp != myIp) {
        myIp = newIp;
        myEmail = IpHelper.generateEmail(myName, myIp);
        await StorageHelper.saveProfile(myName, myEmail, myIp);
        _discovery.updateInfo(myName, myEmail, myIp);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _discovery.stop();
    _server.stop();
    _cleanupTimer?.cancel();
    _ipCheckTimer?.cancel();
    super.dispose();
  }
}
