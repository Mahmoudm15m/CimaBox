import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showActions = false;
  bool _isLoadingAction = false;

  bool _isCheckingUpdate = true;
  bool _showUpdateUI = false;
  Map<String, dynamic>? _updateData;
  final int _currentVersion = 1;

  final String textCima = "CIMA";
  final String textBox = "BOX";

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: 'download_channel',
        permissions: [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
        ],
      );


      isAllowed = await AwesomeNotifications().isNotificationAllowed();

      if (!isAllowed) {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        } else {
          exit(0);
        }
        return;
      }
    }

    _checkForUpdates();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('https://ar.fastmovies.site/cimabox/check-update'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int latestVersion = int.tryParse(data['version'].toString()) ?? 2;

        if (latestVersion > _currentVersion) {
          setState(() {
            _updateData = data;
            _showUpdateUI = true;
            _isCheckingUpdate = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Update check failed: $e");
    }

    _startAppInitialization();
  }

  Future<void> _startAppInitialization() async {
    setState(() => _isCheckingUpdate = false);

    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final minDisplayTime = Future.delayed(const Duration(seconds: 4));
    final dataFetch = homeProvider.fetchHomeData();
    await Future.wait([minDisplayTime, dataFetch]);
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  void _checkAuthAndNavigate() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _navigateToHome();
    } else {
      setState(() {
        _showActions = true;
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const MainLayout(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  Future<void> _launchUpdateUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("فشل فتح رابط التحديث")));
      }
    }
  }

  Widget _buildAnimatedLetter(String letter, int index, TextStyle style, int totalLetters) {
    double start = index / totalLetters;
    double end = (index + 1) / totalLetters;

    final Animation<double> fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start * 0.5, end * 1.0, curve: Curves.easeIn),
      ),
    );

    final Animation<double> scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start * 0.5, end * 1.0, curve: Curves.easeOutBack),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: Text(letter, style: style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    const cimaStyle = TextStyle(
        fontSize: 50.0,
        fontWeight: FontWeight.bold,
        fontFamily: 'Arial Black',
        color: Colors.white,
        letterSpacing: 4);
    const boxStyle = TextStyle(
        fontSize: 50.0,
        fontWeight: FontWeight.bold,
        fontFamily: 'Arial Black',
        color: Colors.redAccent,
        letterSpacing: 4);

    int totalLetters = textCima.length + textBox.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < textCima.length; i++)
                      _buildAnimatedLetter(textCima[i], i, cimaStyle, totalLetters),
                    const SizedBox(width: 10),
                    for (int i = 0; i < textBox.length; i++)
                      _buildAnimatedLetter(textBox[i], textCima.length + i, boxStyle, totalLetters),
                  ],
                );
              },
            ),
          ),

          if (_showUpdateUI && _updateData != null)
            Container(
              color: Colors.black.withOpacity(0.9), // تعتيم الخلفية
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update, color: Colors.redAccent, size: 50),
                      const SizedBox(height: 16),
                      const Text(
                        "تحديث جديد متوفر",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "الإصدار ${_updateData!['version']}",
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _updateData!['changes'] ?? "",
                          style: const TextStyle(color: Colors.white70, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _launchUpdateUrl(_updateData!['url']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("تحديث الآن", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      if (_updateData!['force_update'] != true) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() => _showUpdateUI = false);
                            _startAppInitialization();
                          },
                          child: const Text("لاحقاً", style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          if (!_showUpdateUI)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (!_showActions) ...[
                    const CircularProgressIndicator(color: Colors.redAccent),
                    const SizedBox(height: 20),
                    if (user != null)
                      Text(
                        "مرحباً ${user.displayName?.split(' ')[0] ?? ''}.. جاري تجهيز السينما",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                  ],
                  if (_showActions) ...[
                    if (_isLoadingAction)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: MaterialButton(
                          onPressed: () async {
                            setState(() => _isLoadingAction = true);
                            await authProvider.signInWithGoogle();
                            setState(() => _isLoadingAction = false);
                            if (authProvider.user != null) {
                              _navigateToHome();
                            }
                          },
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png",
                                height: 24,
                              ),
                              const SizedBox(width: 15),
                              const Text("تسجيل الدخول بجوجل",
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: _navigateToHome,
                        child: const Text("تابِع بدون تسجيل دخول",
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ),
                    ]
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}