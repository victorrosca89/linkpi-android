import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/network_packet.dart';

class UdpDiscovery {
  static const int discoveryPort = 50506;
  static const Duration broadcastInterval = Duration(seconds: 5);

  RawDatagramSocket? _recvSocket;
  RawDatagramSocket? _sendSocket;
  Timer? _broadcastTimer;
  bool _running = false;

  String _name = '';
  String _email = '';
  String _ip = '';
  int _port = 0;
  String _status = 'online';

  void Function(NetworkPacket)? onPeerDiscovered;

  Future<void> start(
      String name, String email, String ip, int port, String status) async {
    if (_running) return;
    _running = true;
    _name = name;
    _email = email;
    _ip = ip;
    _port = port;
    _status = status;

    // Socket de recepție — bind pe portul de discovery
    try {
      _recvSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
      _recvSocket!.broadcastEnabled = true;
      _recvSocket!.listen(_onData, onError: (_) {}, cancelOnError: false);
    } catch (e) {
      debugPrint('UdpDiscovery recv bind error: $e');
    }

    // Socket de trimitere — port aleatoriu, broadcast enabled
    try {
      _sendSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _sendSocket!.broadcastEnabled = true;
    } catch (e) {
      debugPrint('UdpDiscovery send socket error: $e');
    }

    // Broadcast periodic — după 2s întârziere ca socket-ul să fie gata
    await Future.delayed(const Duration(milliseconds: 2000));
    _sendBroadcast();
    _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _sendBroadcast());
  }

  void _onData(RawSocketEvent event) {
    if (!_running || _recvSocket == null) return;
    if (event != RawSocketEvent.read) return;

    try {
      final dg = _recvSocket!.receive();
      if (dg == null) return;
      final jsonStr = utf8.decode(dg.data);
      final packet = NetworkPacket.tryParse(jsonStr);
      if (packet == null || packet.type != 'discovery') return;
      // Ignoră propriul broadcast (compară email, nu IP — permite test pe același device)
      if (packet.email == _email) return;
      onPeerDiscovered?.call(packet);
    } catch (e) {
      debugPrint('UdpDiscovery onData error: $e');
    }
  }

  void _sendBroadcast() {
    if (!_running || _sendSocket == null) return;
    try {
      final packet = NetworkPacket.discovery(_name, _email, _ip, _port, _status);
      final data = utf8.encode(packet.toJsonString());
      _sendSocket!.send(
        data,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    } catch (e) {
      debugPrint('UdpDiscovery broadcast error: $e');
    }
  }

  void updateInfo(String name, String email, String ip) {
    _name = name;
    _email = email;
    _ip = ip;
  }

  void setStatus(String status) {
    _status = status;
  }

  void stop() {
    _running = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _recvSocket?.close();
    _recvSocket = null;
    _sendSocket?.close();
    _sendSocket = null;
  }
}

void debugPrint(String s) {
  // ignore: avoid_print
  print(s);
}
