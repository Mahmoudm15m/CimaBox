import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _textController;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _bgOpacityAnimation;
  late ScrollController _autoScrollController;
  Timer? _scrollTimer;

  bool _showActions = false;
  bool _isLoadingAction = false;
  bool _showUpdateUI = false;
  bool _splashVisible = true;
  Map<String, dynamic>? _updateData;
  final int _currentVersion = 5;

  final String textCima = "CIMA";
  final String textBox = "BOX";

  @override
  void initState() {
    super.initState();

    _autoScrollController = ScrollController();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _zoomAnimation = Tween<double>(begin: 1.0, end: 30.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInExpo),
    );

    _bgOpacityAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _zoomController, curve: const Interval(0.5, 1.0)),
    );

    _textController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _startAutoScroll();
    });

    _zoomController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _splashVisible = false;
        });
        _scrollTimer?.cancel();
        if (_autoScrollController.hasClients) {
          _autoScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
        }
      }
    });
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_splashVisible && _autoScrollController.hasClients) {
        double current = _autoScrollController.offset;
        double target = current + 150.0;
        if (target > _autoScrollController.position.maxScrollExtent) {
          target = 0;
        }
        _autoScrollController.animateTo(
          target,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOutQuart,
        );
      } else {
        timer.cancel();
      }
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
        if (Platform.isAndroid) SystemNavigator.pop(); else exit(0);
        return;
      }
    }
    _checkForUpdates();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _autoScrollController.dispose();
    _textController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse('https://ar.syria-live.fun/cimabox/check-update'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int latestVersion = int.tryParse(data['version'].toString()) ?? 2;

        if (latestVersion > _currentVersion) {
          setState(() {
            _updateData = data;
            _showUpdateUI = true;
          });
          return;
        }
      }
    } catch (_) {}
    _startAppInitialization();
  }

  Future<void> _startAppInitialization() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      await _zoomController.forward();
    } else {
      setState(() {
        _showActions = true;
      });
    }
  }

  Future<void> _launchUpdateUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل فتح رابط التحديث")));
    }
  }

  Widget _buildAnimatedLetter(String letter, int index, TextStyle style, int totalLetters) {
    double start = (index / totalLetters) * 0.5;
    double end = start + 0.4;

    final Animation<double> fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    final Animation<double> scale = Tween<double>(begin: 4.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Interval(start, end, curve: Curves.bounceOut),
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
        fontSize: 55.0,
        fontWeight: FontWeight.w900,
        fontFamily: 'Arial',
        color: Color(0xFFE50914),
        letterSpacing: 2,
        shadows: [BoxShadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 5))]
    );

    const boxStyle = TextStyle(
        fontSize: 55.0,
        fontWeight: FontWeight.w900,
        fontFamily: 'Arial',
        color: Colors.white,
        letterSpacing: 2,
        shadows: [BoxShadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 5))]
    );

    int totalLetters = textCima.length + textBox.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MainLayout(homeScrollController: _autoScrollController),

          if (_splashVisible)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _zoomController,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(_bgOpacityAnimation.value),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Transform.scale(
                            scale: _zoomAnimation.value,
                            child: Opacity(
                              opacity: _bgOpacityAnimation.value > 0.1 ? 1.0 : 0.0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int i = 0; i < textCima.length; i++)
                                    _buildAnimatedLetter(textCima[i], i, cimaStyle, totalLetters),
                                  const SizedBox(width: 15),
                                  for (int i = 0; i < textBox.length; i++)
                                    _buildAnimatedLetter(textBox[i], textCima.length + i, boxStyle, totalLetters),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (_showUpdateUI && _updateData != null)
                          _buildUpdateDialog(),

                        if (!_showUpdateUI)
                          Positioned(
                            bottom: 60,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _zoomController.isAnimating ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Column(
                                children: [
                                  if (!_showActions) ...[
                                    const SizedBox(
                                        width: 25,
                                        height: 25,
                                        child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2)
                                    ),
                                    const SizedBox(height: 20),
                                    if (user != null)
                                      Text(
                                        "مرحباً ${user.displayName?.split(' ')[0] ?? ''}",
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: 1.2
                                        ),
                                      ),
                                  ],
                                  if (_showActions) ...[
                                    if (_isLoadingAction)
                                      const CircularProgressIndicator(color: Colors.white)
                                    else ...[
                                      _buildLoginButton(authProvider),
                                      const SizedBox(height: 15),
                                      TextButton(
                                        onPressed: () async {
                                          await _zoomController.forward();
                                        },
                                        child: const Text("المتابعة كزائر", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                      ),
                                    ]
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: MaterialButton(
        onPressed: () async {
          setState(() => _isLoadingAction = true);
          await authProvider.signInWithGoogle();
          setState(() => _isLoadingAction = false);
          if (authProvider.user != null) {
            await _zoomController.forward();
          }
        },
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png",
              height: 24,
            ),
            const SizedBox(width: 15),
            const Text("تسجيل الدخول", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateDialog() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, color: Color(0xFFE50914), size: 50),
              const SizedBox(height: 20),
              const Text("تحديث إجباري", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("الإصدار ${_updateData!['version']} متوفر الآن", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _launchUpdateUrl(_updateData!['url']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("تحديث الآن", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_updateData!['force_update'] != true) ...[
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    setState(() => _showUpdateUI = false);
                    _startAppInitialization();
                  },
                  child: const Text("تخطى هذه المرة", style: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}