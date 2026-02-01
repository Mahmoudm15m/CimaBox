import 'package:cima_box/providers/auth_provider.dart';
import 'package:cima_box/providers/downloads_provider.dart';
import 'package:cima_box/services/dynamic_scraper_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'utils/video_scraper.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'providers/category_provider.dart';
import 'providers/details_provider.dart';
import 'providers/actor_provider.dart';
import 'screens/splash_screen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'providers/watch_history_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/settings_provider.dart';
import 'package:background_downloader/background_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  HttpOverrides.global = MyHttpOverrides();

  await FlutterDownloader.initialize(
      debug: true,
      ignoreSsl: true
  );

  await FileDownloader().trackTasks();

  await AwesomeNotifications().initialize(
    'resource://drawable/notification_icon',
    [
      NotificationChannel(
        channelKey: 'download_channel',
        channelName: 'Download Notifications',
        channelDescription: 'Notification channel for downloads',
        defaultColor: const Color(0xFFE50914),
        ledColor: Colors.white,
        playSound: false,
        enableVibration: false,
        importance: NotificationImportance.High,
        locked: true,
        channelShowBadge: false,
      )
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => DetailsProvider()),
        ChangeNotifierProvider(create: (_) => WatchHistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ActorProvider()),
        Provider<DynamicScraperService>(
          create: (_) => DynamicScraperService()..init(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cima Box',
        theme: ThemeData(
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}