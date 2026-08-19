import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_packet.dart';

class StorageHelper {
  static const _keyName = 'user_name';
  static const _keyEmail = 'user_email';
  static const _keyIp = 'user_ip';
  static const _keyBusy = 'busy_mode';
  static const _keyOffline = 'offline_mode';
  static const _prefixHistory = 'chat_history_';

  static Future<Map<String, String?>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyName),
      'email': prefs.getString(_keyEmail),
      'ip': prefs.getString(_keyIp),
    };
  }

  static Future<void> saveProfile(String name, String email, String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyIp, ip);
  }

  static Future<bool> getBusy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBusy) ?? false;
  }

  static Future<void> setBusy(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBusy, v);
  }

  static Future<bool> getOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOffline) ?? false;
  }

  static Future<void> setOffline(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOffline, v);
  }

  static String _safeKey(String email) =>
      email.replaceAll('@', '_').replaceAll('.', '_');

  static Future<void> saveChatHistory(
      String email, List<ChatMessageData> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefixHistory + _safeKey(email);
    final list = messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(key, list);
  }

  static Future<List<ChatMessageData>> loadChatHistory(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefixHistory + _safeKey(email);
    final list = prefs.getStringList(key) ?? [];
    return list.map((s) {
      try {
        return ChatMessageData.fromJson(jsonDecode(s));
      } catch (_) {
        return null;
      }
    }).whereType<ChatMessageData>().toList();
  }
}
