import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get user => _auth.currentUser;

  bool isSigningIn = false;
  bool isPremium = false;

  AuthProvider() {
    _initAuthListener();
    _initPremiumListener();
  }

  void _initPremiumListener() {
    ApiService.onPremiumStateChange = (bool status) {
      if (isPremium != status) {
        isPremium = status;
        Future.microtask(() => notifyListeners());
      }
    };
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        String? token = await user.getIdToken();
        ApiService.userToken = token;
      } else {
        ApiService.userToken = null;
        isPremium = false;
      }
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      isSigningIn = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        isSigningIn = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

    } catch (e) {
      print("Google Sign In Error: $e");
    } finally {
      isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    isPremium = false;
    notifyListeners();
  }
}