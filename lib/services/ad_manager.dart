import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdManager {

  static late BuildContext _context;

  static DateTime? _lastAdShowTime;
  static const Duration _adInterval = Duration(minutes: 5);

  static Future<String> getGameId() async {
    return '5783672';
  }

  static Future<String> getBannerAdPlacementId() async {
    return 'Banner_Android';
  }

  static Future<String> getInterstitialVideoAdPlacementId() async {
    return 'Interstitial_Android';
  }

  static Future<String> getRewardedVideoAdPlacementId() async {
    return 'Rewarded_Android';
  }

  static final Map<String, bool> placements = {
    'Interstitial_Android': false,
    'Rewarded_Android': false,
  };

  static final Map<String, Completer<bool>> _loadingCompleters = {};

  static const int maxRetryCount = 5;

  static Future<void> initializeAds(BuildContext context) async {
    _context = context;

    String gameId = await getGameId();
    UnityAds.init(
      gameId: gameId,
      testMode: false,
      onComplete: () {
        print('✅ تم تهيئة إعلانات Unity بنجاح');
        _loadAd('Interstitial_Android');
      },
      onFailed: (error, message) {
        print('❌ فشل تهيئة إعلانات Unity: $error - $message');
      },
    );

    UnityAds.setPrivacyConsent(PrivacyConsentType.gdpr, true);
    UnityAds.setPrivacyConsent(PrivacyConsentType.ageGate, true);
    UnityAds.setPrivacyConsent(PrivacyConsentType.ccpa, true);
    UnityAds.setPrivacyConsent(PrivacyConsentType.pipl, true);
  }

  static Future<bool> _loadAd(String placementId) async {
    if (placements[placementId] == true) {
      return true;
    }

    if (_loadingCompleters[placementId] != null && !_loadingCompleters[placementId]!.isCompleted) {
      print("⏳ انتظار تحميل سابق للإعلان: $placementId");
      return _loadingCompleters[placementId]!.future;
    }

    print("🚀 بدء تحميل جديد للإعلان: $placementId");
    _loadingCompleters[placementId] = Completer<bool>();
    int currentRetryCount = 0;

    Future<void> tryLoad() async {
      try {
        await UnityAds.load(
          placementId: placementId,
          onComplete: (pid) {
            print('✅ الإعلان جاهز: $pid');
            placements[pid] = true;
            if (!_loadingCompleters[pid]!.isCompleted) {
              _loadingCompleters[pid]!.complete(true);
            }
          },
          onFailed: (pid, error, message) async {
            print('❌ فشل تحميل الإعلان: $pid - $error - $message');
            currentRetryCount++;
            if (currentRetryCount < maxRetryCount) {
              print('🔄 إعادة محاولة تحميل الإعلان: $pid (محاولة ${currentRetryCount + 1})');
              await Future.delayed(Duration(seconds: 2));
              tryLoad();
            } else {
              print('⚠️ تم الوصول إلى الحد الأقصى لمحاولات التحميل: $pid');
              if (!_loadingCompleters[pid]!.isCompleted) {
                _loadingCompleters[pid]!.complete(false);
              }
            }
          },
        );
      } catch (e) {
        print("⚠️ خطأ أثناء تحميل الإعلان: $e");
        if (!_loadingCompleters[placementId]!.isCompleted) {
          _loadingCompleters[placementId]!.complete(false);
        }
      }
    }

    tryLoad();
    return _loadingCompleters[placementId]!.future;
  }

  static Future<bool> showInterstitialAd(BuildContext context) async {

    if (_lastAdShowTime != null && DateTime.now().difference(_lastAdShowTime!) < _adInterval) {
      return false;
    }

    String placementId = await getInterstitialVideoAdPlacementId();

    _showLoadingDialog(context, "جاري تحميل الإعلان...");

    bool isAdReady = await _loadAd(placementId);

    Navigator.of(context, rootNavigator: true).pop();

    if (isAdReady) {
      try {
        await UnityAds.showVideoAd(
          placementId: placementId,
          onComplete: (pid) {
            print('✅ الإعلان المكتمل: $pid');
            _lastAdShowTime = DateTime.now();
            placements[pid] = false;
            _loadAd(pid);
          },
          onFailed: (pid, error, message) {
            print('❌ فشل تشغيل الإعلان: $pid - $error - $message');
            placements[pid] = false;
          },
          onSkipped: (pid) {
            print('✅ الإعلان المكتمل: $pid');
            _lastAdShowTime = DateTime.now();
            placements[pid] = false;
            _loadAd(pid);
          },
        );
        return true;
      } catch (e) {
        print('⚠️ خطأ أثناء تشغيل الإعلان: $e');
        placements[placementId] = false;
        return false;
      }
    } else {
      print('⚠️ الإعلان غير جاهز بعد كل المحاولات');
      placements[placementId] = false;
      return false;
    }
  }

  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}