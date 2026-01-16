import 'package:cima_box/providers/downloads_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'utils/video_scraper.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'providers/category_provider.dart';
import 'providers/details_provider.dart';
import 'screens/main_layout.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'providers/watch_history_provider.dart';
import 'providers/favorites_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  await FlutterDownloader.initialize(
      debug: true,
      ignoreSsl: true
  );

  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'download_channel',
        channelName: 'HLS Downloads',
        channelDescription: 'Notification channel for HLS downloads',
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
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => DetailsProvider()),
        ChangeNotifierProvider(create: (_) => WatchHistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cima Box',
        theme: ThemeData(
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const MainLayout(),
      ),
    );
  }
}