import 'dart:io';

class IpHelper {
  /// Același algoritm ca Windows: connect UDP la 8.8.8.8 și citim IP-ul local ales de OS
  static Future<String> getLocalIp() async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.close();

      // Alternativă mai robustă: enumerăm interfețele de rețea
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Preferăm adrese LAN (192.168.x.x sau 10.x.x.x sau 172.16-31.x.x)
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
            return ip;
          }
        }
      }

      // Fallback: prima adresă non-loopback găsită
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static String getIpSuffix(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[2]}.${parts[3]}';
    return '0.0';
  }

  /// Identic cu Windows: "victor" -> "victor@linkpi.me.1.5"
  static String generateEmail(String name, String ip) {
    final cleanName = name.toLowerCase().replaceAll(' ', '');
    final suffix = getIpSuffix(ip);
    return '$cleanName@linkpi.me.$suffix';
  }
}
