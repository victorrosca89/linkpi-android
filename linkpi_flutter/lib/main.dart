import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'helpers/chat_controller.dart';
import 'helpers/storage_helper.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portret only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF08080c),
  ));

  final profile = await StorageHelper.loadProfile();
  final hasProfile = (profile['name'] ?? '').isNotEmpty;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatController(),
      child: LinkPiApp(hasProfile: hasProfile, savedName: profile['name']),
    ),
  );
}

class LinkPiApp extends StatelessWidget {
  final bool hasProfile;
  final String? savedName;

  const LinkPiApp({super.key, required this.hasProfile, this.savedName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkPi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08080c),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4ade80),
          surface: Color(0xFF0d0d14),
        ),
        fontFamily: 'Roboto',
      ),
      home: hasProfile && savedName != null
          ? HomeScreen(autoInitName: savedName!)
          : const SetupScreen(),
    );
  }
}
