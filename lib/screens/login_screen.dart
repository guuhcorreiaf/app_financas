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
        final msg = e is FirebaseException
            ? (e.message ?? 'Erro de autenticação')
            : 'Erro ao realizar login: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF9F3A3E)),
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
        final msg = e is FirebaseException
            ? (e.message ?? 'Erro ao entrar anonimamente')
            : 'Erro: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF9F3A3E)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF054E4B), Color(0xFF0A6E6A), Color(0xFFEEF3F4)],
            stops: [0.0, 0.42, 0.42],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            size: 36, color: Color(0xFF86E2D5)),
                        SizedBox(width: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Finanças',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: '.app',
                                style: TextStyle(
                                  color: Color(0xFF86E2D5),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Controle suas contas, vencimentos e reserva em um só lugar',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2ECEE)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14065F5B),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRegister ? 'Criar nova conta' : 'Acesse sua conta',
                            style: const TextStyle(
                              color: Color(0xFF0F2A2E),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRegister
                                ? 'Cadastre seu e-mail para sincronizar suas finanças.'
                                : 'Entre para acompanhar seus lembretes de pagamento.',
                            style: const TextStyle(
                              color: Color(0xFF5B7277),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Color(0xFF0F2A2E)),
                                  decoration: InputDecoration(
                                    labelText: 'E-mail',
                                    labelStyle: const TextStyle(color: Color(0xFF5B7277)),
                                    prefixIcon: const Icon(Icons.email_outlined,
                                        color: Color(0xFF065F5B)),
                                    filled: true,
                                    fillColor: const Color(0xFFF6FAFA),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFD6E4E6)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF065F5B), width: 1.5),
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
                                  style: const TextStyle(color: Color(0xFF0F2A2E)),
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    labelStyle: const TextStyle(color: Color(0xFF5B7277)),
                                    prefixIcon: const Icon(Icons.lock_outline,
                                        color: Color(0xFF065F5B)),
                                    filled: true,
                                    fillColor: const Color(0xFFF6FAFA),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFD6E4E6)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF065F5B), width: 1.5),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Informe a senha'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF065F5B)))
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF065F5B),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
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
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _isRegister = !_isRegister),
                              child: Text(
                                _isRegister
                                    ? 'Já tem conta? Entrar'
                                    : 'Ainda não tem conta? Criar',
                                style: const TextStyle(
                                  color: Color(0xFF065F5B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Divider(
                              color: Color(0xFFE2ECEE), thickness: 1, height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInAnonymously,
                              icon: const Icon(Icons.person_outline,
                                  color: Color(0xFF065F5B)),
                              label: const Text(
                                'Entrar anonimamente',
                                style: TextStyle(
                                  color: Color(0xFF0F2A2E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFD6E4E6)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
