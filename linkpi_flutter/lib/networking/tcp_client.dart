import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/network_packet.dart';

class TcpClient {
  static const int _lingerMs = 2000;

  /// Construiește frame: [4 bytes big-endian length][JSON UTF-8]
  static Uint8List _buildFrame(NetworkPacket packet) {
    final jsonBytes = utf8.encode(packet.toJsonString());
    final frame = ByteData(4 + jsonBytes.length);
    frame.setInt32(0, jsonBytes.length, Endian.big);
    final result = frame.buffer.asUint8List();
    result.setRange(4, 4 + jsonBytes.length, jsonBytes);
    return result;
  }

  static Future<void> _sendAll(Socket socket, List<int> data) async {
    socket.add(data);
    await socket.flush();
  }

  /// Graceful disconnect — aceeași logică ca Windows
  static Future<void> _gracefulDisconnect(Socket socket) async {
    try {
      await socket.flush();
      // Semnalăm că am terminat de trimis
      // Flutter nu are Shutdown(Send) direct, dar close() trimite FIN
      // Așteptăm un pic pentru ca serverul să consume datele
      await Future.delayed(Duration(milliseconds: _lingerMs));
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
    socket.destroy();
  }

  static void sendMessage(
      String targetIp, int targetPort, NetworkPacket packet) {
    Future(() async {
      Socket? socket;
      try {
        socket = await Socket.connect(
          targetIp,
          targetPort,
          timeout: const Duration(seconds: 5),
        );
        socket.setOption(SocketOption.tcpNoDelay, true);

        final frame = _buildFrame(packet);
        await _sendAll(socket, frame);
        await _gracefulDisconnect(socket);
      } catch (e) {
        print('TcpClient.sendMessage error: $e');
        try {
          socket?.destroy();
        } catch (_) {}
      }
    });
  }

  static void sendFile(
      String targetIp, int targetPort, NetworkPacket packet, String filePath) {
    Future(() async {
      Socket? socket;
      try {
        final file = File(filePath);
        if (!await file.exists()) return;
        final fileBytes = await file.readAsBytes();
        packet.fileSize = fileBytes.length;

        socket = await Socket.connect(
          targetIp,
          targetPort,
          timeout: const Duration(seconds: 10),
        );
        socket.setOption(SocketOption.tcpNoDelay, true);

        // 1. Trimite JSON header frame
        final frame = _buildFrame(packet);
        await _sendAll(socket, frame);

        // 2. Trimite bytes fișier în chunk-uri de 64KB
        const chunkSize = 65536;
        int offset = 0;
        while (offset < fileBytes.length) {
          final end = (offset + chunkSize).clamp(0, fileBytes.length);
          socket.add(fileBytes.sublist(offset, end));
          offset = end;
          // Flush periodic ca să nu umplim buffer-ul
          if (offset % (chunkSize * 4) == 0) await socket.flush();
        }

        await _gracefulDisconnect(socket);
      } catch (e) {
        print('TcpClient.sendFile error: $e');
        try {
          socket?.destroy();
        } catch (_) {}
      }
    });
  }
}
