import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegister = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      if (_isRegister) {
        await auth.registerWithEmail(
            _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await auth.signInWithEmail(
            _emailCtrl.text.trim(), _passwordCtrl.text);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseException ? (e.message ?? 'Erro de autenticação') : 'Erro ao realizar login: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await auth.signInAnonymously();
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseException ? (e.message ?? 'Erro ao entrar anonimamente') : 'Erro: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet,
                    size: 96, color: Color(0xFF6C63FF)),
                const SizedBox(height: 24),
                Text(
                  _isRegister ? 'Criar Conta' : 'Entrar',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          labelStyle:
                              const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.email,
                              color: Color(0xFF6C63FF)),
                          filled: true,
                          fillColor: const Color(0xFF2A2A3E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe o e-mail'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle:
                              const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.lock,
                              color: Color(0xFF6C63FF)),
                          filled: true,
                          fillColor: const Color(0xFF2A2A3E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe a senha'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator(
                        color: Color(0xFF6C63FF))
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isRegister ? 'Criar Conta' : 'Entrar',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Já tem conta? Entrar'
                        : 'Ainda não tem conta? Criar',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const Divider(
                    color: Colors.white24, thickness: 1, height: 32),
                TextButton.icon(
                  onPressed: _signInAnonymously,
                  icon: const Icon(Icons.person_outline,
                      color: Color(0xFF6C63FF)),
                  label: const Text('Entrar anonimamente',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
