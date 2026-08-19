import 'dart:convert';

class NetworkPacket {
  String? type;
  String? name;
  String? email;
  String? ip;
  int? port;
  int? timestamp;
  String? id;
  String? fromEmail;
  String? fromName;
  String? text;
  String? timeText;
  bool? isEdited;
  String? fileName;
  int? fileSize;
  String? newText;
  String? status;

  NetworkPacket({
    this.type,
    this.name,
    this.email,
    this.ip,
    this.port,
    this.timestamp,
    this.id,
    this.fromEmail,
    this.fromName,
    this.text,
    this.timeText,
    this.isEdited,
    this.fileName,
    this.fileSize,
    this.newText,
    this.status,
  });

  // Câmpurile JSON sunt identice cu versiunea Windows (Newtonsoft.Json camelCase)
  factory NetworkPacket.fromJson(Map<String, dynamic> j) => NetworkPacket(
        type: j['type'],
        name: j['name'],
        email: j['email'],
        ip: j['ip'],
        port: j['port'],
        timestamp: j['timestamp'],
        id: j['id'],
        fromEmail: j['fromEmail'],
        fromName: j['fromName'],
        text: j['text'],
        timeText: j['timeText'],
        isEdited: j['isEdited'],
        fileName: j['fileName'],
        fileSize: j['fileSize'],
        newText: j['newText'],
        status: j['status'],
      );

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (ip != null) 'ip': ip,
        if (port != null) 'port': port,
        if (timestamp != null) 'timestamp': timestamp,
        if (id != null) 'id': id,
        if (fromEmail != null) 'fromEmail': fromEmail,
        if (fromName != null) 'fromName': fromName,
        if (text != null) 'text': text,
        if (timeText != null) 'timeText': timeText,
        if (isEdited != null) 'isEdited': isEdited,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (newText != null) 'newText': newText,
        if (status != null) 'status': status,
      };

  String toJsonString() => jsonEncode(toJson());

  static NetworkPacket? tryParse(String jsonStr) {
    try {
      return NetworkPacket.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return null;
    }
  }

  static NetworkPacket discovery(
      String name, String email, String ip, int port, String status) {
    return NetworkPacket(
      type: 'discovery',
      name: name,
      email: email,
      ip: ip,
      port: port,
      status: status,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  static NetworkPacket message(ChatMessageData msg) {
    return NetworkPacket(
      type: 'message',
      id: msg.id,
      fromEmail: msg.fromEmail,
      fromName: msg.fromName,
      text: msg.text,
      timeText: msg.timeText,
      fileName: msg.fileName,
      fileSize: msg.fileSize,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  static NetworkPacket edit(String messageId, String newText, String fromEmail) {
    return NetworkPacket(
      type: 'edit',
      id: messageId,
      newText: newText,
      fromEmail: fromEmail,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  static NetworkPacket delete(String messageId, String fromEmail) {
    return NetworkPacket(
      type: 'delete',
      id: messageId,
      fromEmail: fromEmail,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }
}

// Model simplu pentru mesaj (folosit intern)
class ChatMessageData {
  String id;
  String fromEmail;
  String fromName;
  String text;
  String timeText;
  bool isSent;
  bool isEdited;
  bool isDeleted;
  String? fileName;
  int? fileSize;
  String? filePath;

  ChatMessageData({
    required this.id,
    required this.fromEmail,
    required this.fromName,
    required this.text,
    required this.timeText,
    required this.isSent,
    this.isEdited = false,
    this.isDeleted = false,
    this.fileName,
    this.fileSize,
    this.filePath,
  });

  bool get isFile => fileName != null && fileName!.isNotEmpty;

  String get fileSizeText {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get displayText {
    if (isDeleted) return '🗑 Mesaj șters';
    return text;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromEmail': fromEmail,
        'fromName': fromName,
        'text': text,
        'timeText': timeText,
        'isSent': isSent,
        'isEdited': isEdited,
        'isDeleted': isDeleted,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (filePath != null) 'filePath': filePath,
      };

  factory ChatMessageData.fromJson(Map<String, dynamic> j) => ChatMessageData(
        id: j['id'] ?? '',
        fromEmail: j['fromEmail'] ?? '',
        fromName: j['fromName'] ?? '',
        text: j['text'] ?? '',
        timeText: j['timeText'] ?? '',
        isSent: j['isSent'] ?? false,
        isEdited: j['isEdited'] ?? false,
        isDeleted: j['isDeleted'] ?? false,
        fileName: j['fileName'],
        fileSize: j['fileSize'],
        filePath: j['filePath'],
      );
}

class ChatUser {
  String name;
  String email;
  String ip;
  int port;
  bool isOnline;
  DateTime lastSeen;
  String status;

  ChatUser({
    required this.name,
    required this.email,
    required this.ip,
    required this.port,
    this.isOnline = true,
    required this.lastSeen,
    this.status = 'online',
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  String get statusText {
    if (!isOnline) return 'OFFLINE';
    if (status == 'busy') return 'OCCUPAT';
    return 'ONLINE';
  }
}
