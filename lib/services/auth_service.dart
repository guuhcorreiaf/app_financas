import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// AuthService encapsula todas as operações de autenticação.
class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Stream que emite mudanças no estado de autenticação.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Sign‑in anônimo – usado para acesso rápido.
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    notifyListeners();
    return cred.user;
  }

  /// Sign‑in com e‑mail e senha.
  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    notifyListeners();
    return cred.user;
  }

  /// Registro de novo usuário com e‑mail e senha.
  Future<User?> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    notifyListeners();
    return cred.user;
  }

  /// Sign‑out.
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
