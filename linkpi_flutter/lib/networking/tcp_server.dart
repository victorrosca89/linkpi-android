import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/network_packet.dart';

typedef MessageCallback = void Function(NetworkPacket packet, String fromEmail);
typedef FileCallback = void Function(
    String fromEmail, String fromName, int fileSize, String fileName, String savedPath);
typedef EditCallback = void Function(
    String messageId, String newText, String fromEmail);
typedef DeleteCallback = void Function(String messageId, String fromEmail);
typedef ProgressCallback = void Function(
    String fromEmail, String fileName, int received, int total);

class TcpServer {
  static const int port = 50505;

  ServerSocket? _server;
  bool _running = false;
  final List<Socket> _clients = [];

  MessageCallback? onMessageReceived;
  FileCallback? onFileReceived;
  EditCallback? onMessageEdited;
  DeleteCallback? onMessageDeleted;
  ProgressCallback? onFileProgress;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server!.listen(_onClient, onError: (e) {
        print('TcpServer listen error: $e');
      });
      print('TcpServer started on port $port');
    } catch (e) {
      print('TcpServer.start error: $e');
    }
  }

  void _onClient(Socket client) {
    _clients.add(client);
    final state = _ClientState(client);

    client.listen(
      (Uint8List data) => _onData(state, data),
      onError: (e) {
        print('TcpServer client error: $e');
        _processBuffer(state); // încearcă să salveze ce a primit
        _finalize(state);
      },
      onDone: () {
        _processBuffer(state); // procesează datele rămase la FIN
        _finalize(state);
      },
      cancelOnError: false,
    );
  }

  void _onData(_ClientState state, Uint8List chunk) {
    state.buffer.addAll(chunk);
    _processBuffer(state);
  }

  void _processBuffer(_ClientState state) {
    while (state.buffer.isNotEmpty) {
      if (state.readingFile) {
        // Consumă bytes pentru fișier
        final toWrite =
            state.fileBytesRemaining.clamp(0, state.buffer.length).toInt();
        if (toWrite <= 0) break;

        state.fileData.addAll(state.buffer.sublist(0, toWrite));
        state.buffer.removeRange(0, toWrite);
        state.fileBytesRemaining -= toWrite;

        onFileProgress?.call(
          state.filePacket!.fromEmail!,
          state.filePacket!.fileName!,
          state.filePacket!.fileSize! - state.fileBytesRemaining,
          state.filePacket!.fileSize!,
        );

        if (state.fileBytesRemaining <= 0) {
          // Fișier complet
          state.readingFile = false;
          final bytes = Uint8List.fromList(state.fileData);
          state.fileData.clear();

          _saveFile(state.filePacket!, bytes).then((savedPath) {
            if (savedPath != null) {
              onFileReceived?.call(
                state.filePacket!.fromEmail!,
                state.filePacket!.fromName!,
                state.filePacket!.fileSize!,
                state.filePacket!.fileName!,
                savedPath,
              );
            }
            state.filePacket = null;
          });
          // continuă bucla — pot urma alte pachete
        } else {
          break; // așteptăm mai multe date
        }
      } else {
        // Încearcă să extragă un pachet length-prefixed
        if (state.buffer.length < 4) break;

        // Citim lungimea JSON (4 bytes big-endian)
        final lenBytes = state.buffer.sublist(0, 4);
        final jsonLength = ByteData.sublistView(Uint8List.fromList(lenBytes))
            .getInt32(0, Endian.big);

        if (jsonLength <= 0 || jsonLength > 64 * 1024 * 1024) {
          print('TcpServer: jsonLength invalid: $jsonLength, resetez buffer');
          state.buffer.clear();
          break;
        }

        final totalNeeded = 4 + jsonLength;
        if (state.buffer.length < totalNeeded) break;

        final jsonBytes = state.buffer.sublist(4, totalNeeded);
        state.buffer.removeRange(0, totalNeeded);

        String jsonStr;
        try {
          jsonStr = utf8.decode(jsonBytes);
        } catch (e) {
          print('TcpServer: UTF-8 decode error: $e');
          continue;
        }

        final packet = NetworkPacket.tryParse(jsonStr);
        if (packet == null) {
          print('TcpServer: JSON invalid, ignorat');
          continue;
        }

        if (packet.type == 'message' &&
            packet.fileName != null &&
            packet.fileName!.isNotEmpty &&
            (packet.fileSize ?? 0) > 0) {
          // Urmează bytes de fișier
          state.readingFile = true;
          state.filePacket = packet;
          state.fileData.clear();
          state.fileBytesRemaining = packet.fileSize!;
          // bucla continuă și consumă bytes de fișier
        } else if (packet.type == 'message') {
          onMessageReceived?.call(packet, packet.fromEmail ?? '');
        } else if (packet.type == 'edit') {
          onMessageEdited?.call(
              packet.id ?? '', packet.newText ?? '', packet.fromEmail ?? '');
        } else if (packet.type == 'delete') {
          onMessageDeleted?.call(packet.id ?? '', packet.fromEmail ?? '');
        }
      }
    }
  }

  void _finalize(_ClientState state) {
    if (state.readingFile) {
      print(
          'TcpServer: Fișier incomplet "${state.filePacket?.fileName}", '
          'lipsesc ${state.fileBytesRemaining} bytes');
    }
    try {
      state.socket.destroy();
    } catch (_) {}
    _clients.remove(state.socket);
  }

  Future<String?> _saveFile(NetworkPacket packet, Uint8List data) async {
    try {
      final dir = Directory(
          '${(await _getDownloadDir())}${Platform.pathSeparator}LinkPi_Downloads');
      if (!await dir.exists()) await dir.create(recursive: true);

      String fileName = packet.fileName!;
      String nameOnly = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      String ext =
          fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '';

      File file = File('${dir.path}${Platform.pathSeparator}$fileName');
      int counter = 1;
      while (await file.exists()) {
        file = File(
            '${dir.path}${Platform.pathSeparator}$nameOnly ($counter)$ext');
        counter++;
      }

      await file.writeAsBytes(data);
      print('TcpServer: Fișier salvat la ${file.path}');
      return file.path;
    } catch (e) {
      print('TcpServer.saveFile error: $e');
      return null;
    }
  }

  Future<String> _getDownloadDir() async {
    if (Platform.isAndroid) {
      // Folder Downloads vizibil în Files app
      const path = '/storage/emulated/0/Download';
      if (await Directory(path).exists()) return path;
    }
    // Fallback: documents dir
    return Directory.systemTemp.path;
  }

  void stop() {
    _running = false;
    for (final c in _clients) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _clients.clear();
    _server?.close();
    _server = null;
  }
}

class _ClientState {
  final Socket socket;
  final List<int> buffer = [];
  bool readingFile = false;
  NetworkPacket? filePacket;
  final List<int> fileData = [];
  int fileBytesRemaining = 0;

  _ClientState(this.socket);
}
