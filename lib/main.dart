import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/webview_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF06070A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const FlowMultiloginApp());
}

class FlowMultiloginApp extends StatelessWidget {
  const FlowMultiloginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boxpower Portal',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF06070A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF0C0E14),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF8FAFC),
        ),
      ),
      home: const WebViewView(),
    );
  }
}
