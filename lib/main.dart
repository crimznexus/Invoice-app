import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/gallery_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MoosjanInvoiceApp());
}

class MoosjanInvoiceApp extends StatelessWidget {
  const MoosjanInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moosjan Invoice',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const GalleryScreen(),
    );
  }
}
