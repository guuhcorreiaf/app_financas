import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';
import '../models/payment_record.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/bill_categories.dart';
import 'history_screen.dart';

enum _BillFilter { all, overdue, upcoming7, recurring }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Color _tealDark = Color(0xFF065F5B);
  static const Color _tealMid = Color(0xFF0B726E);
  static const Color _tealSoft = Color(0xFFE6F5F3);
  static const Color _bgPage = Color(0xFFEEF3F4);
  static const Color _borderCard = Color(0xFFE2ECEE);
  static const Color _textPrimary = Color(0xFF0F2A2E);
  static const Color _textSecondary = Color(0xFF5B7277);
  static const Color _kpiBlue = Color(0xFF0E5A7A);
  static const Color _kpiBlueSoft = Color(0xFFE6F2F8);
  static const Color _kpiRed = Color(0xFF9F3A3E);
  static const Color _kpiRedSoft = Color(0xFFFCEBEB);
  static const Color _kpiGreen = Color(0xFF0D6E6E);
  static const Color _warnAmber = Color(0xFFC26B0E);
  static const Color _warnAmberSoft = Color(0xFFFEF3E6);

  static const List<String> _shortMonthNames = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _searchCtrl = TextEditingController();
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;
  final Set<String> _payingBillIds = {};

  String _searchQuery = '';
  _BillFilter _activeFilter = _BillFilter.all;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOut);
    _fabController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fabController.dispose();
    super.dispose();
  }

  String _formatShortMonthYear(DateTime date) =>
      '${_shortMonthNames[date.month - 1]}/${date.year}';

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _displayUserName(User user) {
    if (user.isAnonymous) return 'Visitante';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim().split(' ').first;
    }
    final email = user.email ?? '';
    if (email.contains('@')) {
      final raw = email.split('@').first;
      if (raw.isNotEmpty) {
        return raw[0].toUpperCase() + raw.substring(1);
      }
    }
    return 'Bem-vindo';
  }

  void _openHistory(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(uid: uid)),
    );
  }

  double? _parseAmount(String? text) {
    if (text == null) return null;
    String cleaned = text.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      if (cleaned.lastIndexOf('.') < cleaned.lastIndexOf(',')) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        // ponto decimal
      } else {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
    return double.tryParse(cleaned);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sair da conta',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Tem certeza de que deseja sair?',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kpiRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  // ========== Marcar Conta como Paga (Avança Recorrência + Envia ao Histórico) ==========
  Future<void> _handlePayBill(String uid, Bill bill) async {
    if (_payingBillIds.contains(bill.id)) return;
    setState(() => _payingBillIds.add(bill.id));

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final nextBill = await firestore.payBill(uid, bill);

      if (!mounted) return;
      final paidParcelLabel =
          bill.installmentIndex != null && bill.installmentTotal != null
              ? ' (${bill.installmentIndex}/${bill.installmentTotal})'
              : '';

      final message = nextBill != null
          ? '"${bill.title}"$paidParcelLabel paga! Próximo vencimento: ${DateFormat('dd/MM/yyyy').format(nextBill.dueDate)}'
          : '"${bill.title}"$paidParcelLabel paga e enviada para o Histórico!';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _tealDark,
          action: SnackBarAction(
            label: 'Ver Histórico',
            textColor: const Color(0xFF86E2D5),
            onPressed: () => _openHistory(uid),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar pagamento: $e'),
            backgroundColor: _kpiRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _payingBillIds.remove(bill.id));
      }
    }
  }

  // ========== Modal para Editar Salário ==========
  void _showEditSalaryModal(String uid, double currentSalary) {
    final salaryCtrl = TextEditingController(
      text: currentSalary > 0 ? currentSalary.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6E4E6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Definir Salário Mensal',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Informe sua renda mensal para calcular o saldo disponível, saúde do orçamento e sugestão de reserva.',
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: salaryCtrl,
                        label: 'Valor do Salário (R\$)',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o salário';
                          final parsed = _parseAmount(v);
                          if (parsed == null || parsed < 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final val = _parseAmount(salaryCtrl.text);
                                  if (val == null) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await Provider.of<FirestoreService>(context, listen: false)
                                        .setSalary(uid, val);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao atualizar salário: $e'),
                                          backgroundColor: _kpiRed,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tealDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Salvar Salário',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== Modal para Editar Reserva / Caixinha ==========
  void _showEditSavingsModal(String uid, double currentSavings) {
    final savingsCtrl = TextEditingController(
      text: currentSavings > 0 ? currentSavings.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6E4E6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Reserva de Emergência',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajuste manualmente o valor total guardado no seu cofrinho.',
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: savingsCtrl,
                        label: 'Valor Guardado (R\$)',
                        icon: Icons.savings_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o valor';
                          final parsed = _parseAmount(v);
                          if (parsed == null || parsed < 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final val = _parseAmount(savingsCtrl.text);
                                  if (val == null) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await Provider.of<FirestoreService>(context, listen: false)
                                        .setSavings(uid, val);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao atualizar reserva: $e'),
                                          backgroundColor: _kpiRed,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tealDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Salvar Reserva',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== Top Hero Banner + 3 Cards KPI Flutuantes (Estilo Finance.app) ==========
  Widget _buildHeroDashboard({
    required User user,
    required String uid,
    required double salary,
    required double totalPaidThisMonth,
    required double totalPending,
    required double currentBalance,
    required double projectedFinalBalance,
    required int pendingCount,
    required int overdueCount,
    required int historyCount,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 760;
    final userName = _displayUserName(user);

    final kpiCards = [
      _buildKpiCard(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: _kpiBlue,
        iconBg: _kpiBlueSoft,
        title: 'Saldo disponível',
        value: _currencyFmt.format(currentBalance),
        valueColor: currentBalance >= 0 ? _kpiBlue : _kpiRed,
        footer: 'Previsão final: ${_currencyFmt.format(projectedFinalBalance)}',
        footerColor: projectedFinalBalance >= 0 ? _textSecondary : _kpiRed,
      ),
      _buildKpiCard(
        icon: Icons.receipt_long_outlined,
        iconColor: _kpiRed,
        iconBg: _kpiRedSoft,
        title: 'Total a pagar',
        value: _currencyFmt.format(totalPending),
        valueColor: _kpiRed,
        badgeText: overdueCount > 0 ? '$overdueCount vencida(s)' : null,
        badgeColor: _kpiRed,
        badgeBg: _kpiRedSoft,
        footer: pendingCount == 0
            ? 'Nenhuma conta pendente ✓'
            : '$pendingCount conta(s) aguardando pagamento',
        onTap: overdueCount > 0
            ? () => setState(() => _activeFilter = _BillFilter.overdue)
            : null,
      ),
      _buildKpiCard(
        icon: Icons.payments_outlined,
        iconColor: _kpiGreen,
        iconBg: _tealSoft,
        title: 'Salário do mês',
        value: _currencyFmt.format(salary),
        valueColor: _kpiGreen,
        trailingAction: const Icon(Icons.edit_outlined, size: 17, color: _textSecondary),
        onTap: () => _showEditSalaryModal(uid, salary),
        footerWidget: GestureDetector(
          onTap: () => _openHistory(uid),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: _kpiGreen),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Pago no mês: ${_currencyFmt.format(totalPaidThisMonth)}',
                  style: const TextStyle(
                    color: _kpiGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _kpiGreen),
            ],
          ),
        ),
      ),
    ];

    return Stack(
      children: [
        // Fundo Teal escuro do topo (estilo Finance.app)
        Container(
          width: double.infinity,
          height: isWide ? 245 : 225,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_tealDark, _tealMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : 16,
                16,
                isWide ? 28 : 16,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de navegação superior
                  Row(
                    children: [
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Finanças',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            TextSpan(
                              text: '.app',
                              style: TextStyle(
                                color: Color(0xFF86E2D5),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      if (isWide) ...[
                        _buildTopNavPill(
                          label: 'Dashboard',
                          active: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildTopNavPill(
                        label: historyCount > 0 ? 'Histórico ($historyCount)' : 'Histórico',
                        active: false,
                        icon: Icons.history_rounded,
                        onTap: () => _openHistory(uid),
                      ),
                      const Spacer(),
                      if (isWide) ...[
                        ElevatedButton.icon(
                          onPressed: () => _showBillModal(uid),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Nova conta',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _tealDark,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        onPressed: _confirmSignOut,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 21),
                        tooltip: 'Sair da conta',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Título DASHBOARD | Saudação
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'DASHBOARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 20,
                        color: Colors.white30,
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_greetingText()}, ',
                              style: const TextStyle(
                                color: Color(0xFFB5EBE4),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: userName,
                              style: const TextStyle(
                                color: Color(0xFF86E2D5),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 3 Cards KPI brancos sobrepostos na borda do hero
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: kpiCards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: kpiCards[1]),
                        const SizedBox(width: 16),
                        Expanded(child: kpiCards[2]),
                      ],
                    )
                  else
                    Column(
                      children: [
                        kpiCards[0],
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: kpiCards[1]),
                            const SizedBox(width: 12),
                            Expanded(child: kpiCards[2]),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopNavPill({
    required String label,
    required bool active,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required Color valueColor,
    String? footer,
    Color? footerColor,
    Widget? footerWidget,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
    Widget? trailingAction,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderCard),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E065F5B),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (trailingAction != null)
                    trailingAction,
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (footerWidget != null)
                footerWidget
              else if (footer != null)
                Text(
                  footer,
                  style: TextStyle(
                    color: footerColor ?? _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Lembrete Inteligente de Contas Urgentes ==========
  Widget _buildSmartReminderBanner(List<Bill> urgentBills, int overdueCount) {
    if (urgentBills.isEmpty) return const SizedBox.shrink();

    final urgentTotal = urgentBills.fold(0.0, (s, b) => s + b.amount);
    final isDanger = overdueCount > 0;
    final accent = isDanger ? _kpiRed : _warnAmber;
    final softBg = isDanger ? _kpiRedSoft : _warnAmberSoft;

    final message = isDanger
        ? 'Você tem $overdueCount conta(s) vencida(s) e ${urgentBills.length} urgente(s) somando ${_currencyFmt.format(urgentTotal)}.'
        : 'Lembrete: ${urgentBills.length} conta(s) vencendo nos próximos 3 dias (${_currencyFmt.format(urgentTotal)}).';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.notifications_active_rounded : Icons.alarm_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _activeFilter = isDanger ? _BillFilter.overdue : _BillFilter.upcoming7;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: accent,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Ver',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ========== Card de Saúde do Orçamento Mensal ==========
  Widget _buildBudgetHealthCard({
    required double salary,
    required double totalPaidThisMonth,
    required double totalPending,
    required double savings,
    required Bill? nextDueBill,
  }) {
    final totalCommitted = totalPaidThisMonth + totalPending + savings;
    final ratio = salary > 0 ? (totalCommitted / salary).clamp(0.0, 1.0) : 0.0;
    final percent = salary > 0 ? ((totalCommitted / salary) * 100).round() : 0;

    Color barColor;
    String statusLabel;
    if (salary <= 0) {
      barColor = _textSecondary;
      statusLabel = 'Defina seu salário para acompanhar';
    } else if (percent <= 70) {
      barColor = _kpiGreen;
      statusLabel = 'Orçamento saudável';
    } else if (percent <= 95) {
      barColor = _warnAmber;
      statusLabel = 'Atenção ao limite do mês';
    } else {
      barColor = _kpiRed;
      statusLabel = 'Orçamento acima da renda';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A065F5B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      color: _kpiBlueSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pie_chart_outline_rounded, color: _kpiBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saúde do Orçamento',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Comprometimento da renda',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  salary > 0 ? '$percent%' : '—',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFE6EFEF),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statusLabel,
            style: TextStyle(
              color: barColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderCard),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined, color: _tealDark, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextDueBill != null
                        ? 'Próximo vencimento: ${nextDueBill.title} (${DateFormat('dd/MM/yyyy').format(nextDueBill.dueDate)})'
                        : 'Nenhuma conta pendente agendada!',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== Card Dedicado para Reserva de Emergência (Cofrinho) ==========
  Widget _buildSavingsCard({
    required String uid,
    required double savings,
    required double suggestedReserve,
    required double projectedLeftover,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A065F5B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      color: _tealSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.savings_outlined, color: _kpiGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserva de Emergência',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cofrinho / Guardado',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _showEditSavingsModal(uid, savings),
                icon: const Icon(Icons.edit_outlined, color: _textSecondary, size: 19),
                tooltip: 'Editar Reserva',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _currencyFmt.format(savings),
                style: const TextStyle(
                  color: _kpiGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'guardados',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: projectedLeftover > 0 ? _tealSoft : _warnAmberSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  projectedLeftover > 0 ? Icons.lightbulb_outline : Icons.info_outline,
                  color: projectedLeftover > 0 ? _kpiGreen : _warnAmber,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projectedLeftover > 0
                        ? 'Sugestão do mês: Guardar 10% da sobra (${_currencyFmt.format(suggestedReserve)})'
                        : 'Sem sobra prevista neste mês para guardar.',
                    style: TextStyle(
                      color: projectedLeftover > 0 ? _kpiGreen : _warnAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (suggestedReserve > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    await firestore.setSavings(uid, savings + suggestedReserve);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Guardado ${_currencyFmt.format(suggestedReserve)} na reserva!',
                          ),
                          backgroundColor: _tealDark,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao atualizar reserva: $e'),
                          backgroundColor: _kpiRed,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 17),
                label: Text(
                  'Aplicar 10% (${_currencyFmt.format(suggestedReserve)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== Bloco Branco de Contas a Pagar (Busca + Filtros + Lista) ==========
  Widget _buildBillsSection({
    required String uid,
    required List<Bill> allActiveBills,
    required List<Bill> filteredBills,
    required int overdueCount,
    required int upcoming7Count,
    required int recurringCount,
    required int historyCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A065F5B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contas a Pagar',
                style: TextStyle(
                  color: _tealDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filteredBills.length} de ${allActiveBills.length}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de busca inspirada no Finance.app
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Pesquise pelo nome ou categoria da conta...',
              hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF4F8F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderCard),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _tealDark, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chips de filtro rápido
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Todas (${allActiveBills.length})',
                  selected: _activeFilter == _BillFilter.all,
                  onTap: () => setState(() => _activeFilter = _BillFilter.all),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Vencidas ($overdueCount)',
                  selected: _activeFilter == _BillFilter.overdue,
                  highlightColor: overdueCount > 0 ? _kpiRed : null,
                  onTap: () => setState(() => _activeFilter = _BillFilter.overdue),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Próx. 7 dias ($upcoming7Count)',
                  selected: _activeFilter == _BillFilter.upcoming7,
                  highlightColor: upcoming7Count > 0 ? _warnAmber : null,
                  onTap: () => setState(() => _activeFilter = _BillFilter.upcoming7),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Recorrentes ($recurringCount)',
                  selected: _activeFilter == _BillFilter.recurring,
                  onTap: () => setState(() => _activeFilter = _BillFilter.recurring),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _borderCard),
          if (filteredBills.isEmpty)
            _buildEmptyState(
              uid: uid,
              hasAnyActive: allActiveBills.isNotEmpty,
              historyCount: historyCount,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBills.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _borderCard),
              itemBuilder: (_, i) => _buildBillRow(filteredBills[i], uid),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? highlightColor,
    required VoidCallback onTap,
  }) {
    final activeBg = highlightColor ?? _tealDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeBg
              : (highlightColor != null ? highlightColor.withValues(alpha: 0.08) : const Color(0xFFF4F8F8)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? activeBg
                : (highlightColor != null ? highlightColor.withValues(alpha: 0.35) : _borderCard),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (highlightColor ?? _textPrimary),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(Bill bill, String uid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final billDate = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);

    final isOverdue = billDate.isBefore(today);
    final isToday = billDate.isAtSameMomentAs(today);
    final daysLeft = billDate.difference(today).inDays;
    final isPaying = _payingBillIds.contains(bill.id);
    final cat = BillCategories.of(bill.category);

    String statusText;
    Color statusColor;
    Color statusBg;

    if (isOverdue) {
      final overdueDays = today.difference(billDate).inDays;
      statusText = 'Venceu há $overdueDays dia(s) • ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      statusColor = _kpiRed;
      statusBg = _kpiRedSoft;
    } else if (isToday) {
      statusText = 'Vence hoje! • ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      statusColor = _warnAmber;
      statusBg = _warnAmberSoft;
    } else if (daysLeft <= 3) {
      statusText = 'Vence em $daysLeft dia(s) • ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      statusColor = _warnAmber;
      statusBg = _warnAmberSoft;
    } else {
      statusText = 'Vence em $daysLeft dias • ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      statusColor = _textSecondary;
      statusBg = const Color(0xFFF4F8F8);
    }

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text(
                  'Excluir conta',
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Deseja excluir "${bill.title}"?',
                  style: const TextStyle(color: _textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar', style: TextStyle(color: _textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kpiRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: _kpiRed,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) =>
          Provider.of<FirestoreService>(context, listen: false).deleteBill(uid, bill.id),
      child: InkWell(
        onTap: () => _showBillModal(uid, billToEdit: bill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              // Ícone da categoria
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOverdue ? _kpiRedSoft : cat.softBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOverdue ? Icons.warning_amber_rounded : cat.icon,
                  color: isOverdue ? _kpiRed : cat.color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              // Detalhes da conta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          bill.title,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cat.softBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              color: cat.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (bill.isRecurring)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _tealSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.repeat_rounded, color: _tealDark, size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  bill.installmentIndex != null && bill.installmentTotal != null
                                      ? '${bill.installmentIndex}/${bill.installmentTotal}'
                                      : 'Fixa',
                                  style: const TextStyle(
                                    color: _tealDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Valor + Botão Pagar
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFmt.format(bill.amount),
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: isPaying ? null : () => _handlePayBill(uid, bill),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tealSoft,
                        foregroundColor: _tealDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isPaying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: _tealDark,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Pagar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Modal para Criar ou Editar Conta ===========
  void _showBillModal(String uid, {Bill? billToEdit}) {
    final isEditing = billToEdit != null;
    final titleCtrl = TextEditingController(text: isEditing ? billToEdit.title : '');
    final amountCtrl = TextEditingController(
      text: isEditing ? billToEdit.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    DateTime selectedDate = isEditing ? billToEdit.dueDate : DateTime.now().add(const Duration(days: 7));
    bool isRecurring = isEditing ? billToEdit.isRecurring : false;
    String selectedCategory = isEditing ? billToEdit.category : 'Contas Fixas';

    final currentInstallment = isEditing ? (billToEdit.installmentIndex ?? 1) : 1;
    int remainingRepeats = isEditing && billToEdit.isRecurring && billToEdit.installmentTotal != null
        ? (billToEdit.installmentTotal! - currentInstallment).clamp(1, 60)
        : 3;
    final repeatCtrl = TextEditingController(text: '$remainingRepeats');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void setRepeats(int value) {
            final clamped = value.clamp(1, 60);
            setModalState(() {
              remainingRepeats = clamped;
              repeatCtrl.text = '$clamped';
              repeatCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: repeatCtrl.text.length),
              );
            });
          }

          final previewDates = List.generate(
            1 + remainingRepeats,
            (i) => Bill.addMonths(selectedDate, i, preferredDay: selectedDate.day),
          );

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6E4E6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Editar Conta' : 'Nova Conta',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isEditing &&
                                billToEdit.isRecurring &&
                                billToEdit.installmentIndex != null &&
                                billToEdit.installmentTotal != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _tealSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Parcela ${billToEdit.installmentIndex}/${billToEdit.installmentTotal}',
                                  style: const TextStyle(
                                    color: _tealDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: titleCtrl,
                          label: 'Descrição',
                          icon: Icons.description_outlined,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: amountCtrl,
                          label: 'Valor (R\$)',
                          icon: Icons.attach_money,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Informe o valor';
                            final parsed = _parseAmount(v);
                            if (parsed == null || parsed <= 0) return 'Valor inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Seletor de categoria
                        const Text(
                          'Categoria',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: BillCategories.all.map((cat) {
                            final isSelected = selectedCategory == cat.name;
                            return ChoiceChip(
                              avatar: Icon(
                                cat.icon,
                                size: 15,
                                color: isSelected ? Colors.white : cat.color,
                              ),
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (_) =>
                                  setModalState(() => selectedCategory = cat.name),
                              selectedColor: _tealDark,
                              backgroundColor: const Color(0xFFF4F8F8),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : _textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: isSelected ? _tealDark : _borderCard,
                              ),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              builder: (c, child) => Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: _tealDark,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6FAFA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD6E4E6)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: _tealDark, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Vencimento: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Recorrente Mensal',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Ao pagar, registra no Histórico e avança para o próximo mês',
                            style: TextStyle(color: _textSecondary, fontSize: 12),
                          ),
                          value: isRecurring,
                          activeThumbColor: _tealDark,
                          onChanged: (v) => setModalState(() => isRecurring = v),
                        ),

                        if (isRecurring) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4FAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFB5DFDA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Repetir por mais quantos meses?',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: remainingRepeats > 1
                                          ? () => setRepeats(remainingRepeats - 1)
                                          : null,
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: _tealDark,
                                      disabledColor: const Color(0xFFCBD9DC),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: repeatCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                        style: const TextStyle(
                                          color: _textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 12),
                                          filled: true,
                                          fillColor: Colors.white,
                                          suffixText: remainingRepeats == 1 ? 'mês' : 'meses',
                                          suffixStyle: const TextStyle(
                                              color: _textSecondary, fontSize: 13),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFD6E4E6)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: _tealDark, width: 1.5),
                                          ),
                                        ),
                                        onChanged: (v) {
                                          final parsed = int.tryParse(v);
                                          if (parsed != null && parsed >= 1 && parsed <= 60) {
                                            setModalState(() => remainingRepeats = parsed);
                                          }
                                        },
                                        validator: (v) {
                                          final parsed = int.tryParse(v ?? '');
                                          if (parsed == null || parsed < 1 || parsed > 60) {
                                            return 'Informe entre 1 e 60';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: remainingRepeats < 60
                                          ? () => setRepeats(remainingRepeats + 1)
                                          : null,
                                      icon: const Icon(Icons.add_circle_outline),
                                      color: _tealDark,
                                      disabledColor: const Color(0xFFCBD9DC),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [1, 3, 6, 11, 12].map((preset) {
                                    final isSelected = remainingRepeats == preset;
                                    return ChoiceChip(
                                      label: Text('+$preset${preset == 1 ? ' mês' : 'x'}'),
                                      selected: isSelected,
                                      onSelected: (_) => setRepeats(preset),
                                      selectedColor: _tealDark,
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : _textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(
                                        color: isSelected ? _tealDark : _borderCard,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _borderCard),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.event_repeat_rounded,
                                              color: _tealDark, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Sequência automática: ${previewDates.length} parcelas (${_formatShortMonthYear(previewDates.first)} a ${_formatShortMonthYear(previewDates.last)})',
                                              style: const TextStyle(
                                                color: _tealDark,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          ...previewDates.take(5).map((d) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _tealSoft,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  DateFormat('dd/MM/yy').format(d),
                                                  style: const TextStyle(
                                                    color: _tealDark,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              )),
                                          if (previewDates.length > 5)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _bgPage,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '+${previewDates.length - 5} até ${DateFormat('dd/MM/yy').format(previewDates.last)}',
                                                style: const TextStyle(
                                                  color: _textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    final amountVal = _parseAmount(amountCtrl.text);
                                    if (amountVal == null) return;
                                    setModalState(() => isSubmitting = true);

                                    final repeats = isRecurring
                                        ? (int.tryParse(repeatCtrl.text) ?? remainingRepeats)
                                        : 0;
                                    final nextIndex = isRecurring ? currentInstallment : null;
                                    final nextTotal =
                                        isRecurring ? (currentInstallment + repeats) : null;

                                    final bill = Bill(
                                      id: isEditing
                                          ? billToEdit.id
                                          : DateTime.now().millisecondsSinceEpoch.toString(),
                                      title: titleCtrl.text.trim(),
                                      amount: amountVal,
                                      dueDate: selectedDate,
                                      isPaid: false,
                                      isRecurring: isRecurring,
                                      category: selectedCategory,
                                      installmentIndex: nextIndex,
                                      installmentTotal: nextTotal,
                                      originalDay: isRecurring ? selectedDate.day : null,
                                    );

                                    try {
                                      final firestore =
                                          Provider.of<FirestoreService>(context, listen: false);
                                      if (isEditing) {
                                        await firestore.updateBill(uid, bill);
                                      } else {
                                        await firestore.addBill(uid, bill);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      setModalState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Erro ao salvar conta: $e'),
                                            backgroundColor: _kpiRed,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tealDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    isEditing ? 'Atualizar Conta' : 'Salvar Conta',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _tealDark, size: 20),
        filled: true,
        fillColor: const Color(0xFFF6FAFA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6E4E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _tealDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kpiRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kpiRed, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _kpiRed),
      ),
    );
  }

  Widget _buildEmptyState({
    required String uid,
    required bool hasAnyActive,
    required int historyCount,
  }) {
    if (hasAnyActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.filter_list_off_rounded, size: 48, color: Color(0xFFCBD9DC)),
              const SizedBox(height: 12),
              const Text(
                'Nenhuma conta corresponde ao filtro atual',
                style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _searchQuery = '';
                    _activeFilter = _BillFilter.all;
                  });
                },
                child: const Text(
                  'Limpar filtros',
                  style: TextStyle(color: _tealDark, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 56, color: Color(0xFF9AD3CC)),
            const SizedBox(height: 14),
            Text(
              historyCount > 0 ? 'Tudo pago por aqui!' : 'Nenhuma conta cadastrada',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              historyCount > 0
                  ? 'Consulte as contas já pagas no Histórico ou cadastre uma nova.'
                  : 'Toque em "Nova Conta" para adicionar seu primeiro lembrete.',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (historyCount > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openHistory(uid),
                icon: const Icon(Icons.history_rounded, size: 17),
                label: Text('Ver Histórico ($historyCount)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tealDark,
                  side: const BorderSide(color: _tealDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bgPage,
        body: Center(child: CircularProgressIndicator(color: _tealDark)),
      );
    }

    final uid = user.uid;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 760;

    return StreamBuilder<double>(
      stream: firestore.salaryStream(uid),
      builder: (c, salarySnap) {
        final salary = salarySnap.data ?? 0.0;
        return StreamBuilder<double>(
          stream: firestore.savingsStream(uid),
          builder: (cSavings, savingsSnap) {
            final savings = savingsSnap.data ?? 0.0;
            return StreamBuilder<List<PaymentRecord>>(
              stream: firestore.paymentHistoryStream(uid),
              builder: (cHistory, historySnap) {
                final history = historySnap.data ?? [];
                final totalPaidThisMonth = history
                    .where((r) => r.paidAt.year == now.year && r.paidAt.month == now.month)
                    .fold(0.0, (s, r) => s + r.amount);

                return StreamBuilder<List<Bill>>(
                  stream: firestore.billsStream(uid),
                  builder: (cBills, billsSnap) {
                    if (billsSnap.hasError) {
                      return Scaffold(
                        backgroundColor: _bgPage,
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Erro ao carregar contas do Firebase: ${billsSnap.error}',
                              style: const TextStyle(color: _kpiRed, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    final activeBills = (billsSnap.data ?? []).where((b) => !b.isPaid).toList();
                    final totalPending = activeBills.fold(0.0, (s, b) => s + b.amount);

                    // Contadores inteligentes de lembretes
                    bool isBillOverdue(Bill b) {
                      final d = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
                      return d.isBefore(today);
                    }

                    bool isBillWithinDays(Bill b, int maxDays) {
                      final d = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
                      final diff = d.difference(today).inDays;
                      return diff >= 0 && diff <= maxDays;
                    }

                    final overdueBills = activeBills.where(isBillOverdue).toList();
                    final upcoming7Bills = activeBills
                        .where((b) => isBillOverdue(b) || isBillWithinDays(b, 7))
                        .toList();
                    final urgentBills = activeBills
                        .where((b) => isBillOverdue(b) || isBillWithinDays(b, 3))
                        .toList();
                    final recurringBills = activeBills.where((b) => b.isRecurring).toList();

                    // Filtro da lista
                    final filteredBills = activeBills.where((b) {
                      if (_searchQuery.isNotEmpty) {
                        final matchesTitle = b.title.toLowerCase().contains(_searchQuery);
                        final matchesCat = b.category.toLowerCase().contains(_searchQuery);
                        if (!matchesTitle && !matchesCat) return false;
                      }
                      switch (_activeFilter) {
                        case _BillFilter.overdue:
                          return isBillOverdue(b);
                        case _BillFilter.upcoming7:
                          return isBillOverdue(b) || isBillWithinDays(b, 7);
                        case _BillFilter.recurring:
                          return b.isRecurring;
                        case _BillFilter.all:
                          return true;
                      }
                    }).toList();

                    // Regras de negócio preservadas:
                    final projectedLeftover = salary - (totalPaidThisMonth + totalPending);
                    final suggestedReserve =
                        projectedLeftover > 0 ? (projectedLeftover * 0.10) : 0.0;

                    final currentBalance = salary - totalPaidThisMonth - savings;
                    final projectedFinalBalance =
                        salary - (totalPaidThisMonth + totalPending) - savings;

                    final nextDueBill = activeBills.isNotEmpty ? activeBills.first : null;

                    return Scaffold(
                      backgroundColor: _bgPage,
                      body: SafeArea(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildHeroDashboard(
                                user: user,
                                uid: uid,
                                salary: salary,
                                totalPaidThisMonth: totalPaidThisMonth,
                                totalPending: totalPending,
                                currentBalance: currentBalance,
                                projectedFinalBalance: projectedFinalBalance,
                                pendingCount: activeBills.length,
                                overdueCount: overdueBills.length,
                                historyCount: history.length,
                              ),
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1120),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isWide ? 28 : 16,
                                      8,
                                      isWide ? 28 : 16,
                                      100,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildSmartReminderBanner(
                                          urgentBills,
                                          overdueBills.length,
                                        ),
                                        if (isWide)
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _buildBudgetHealthCard(
                                                  salary: salary,
                                                  totalPaidThisMonth: totalPaidThisMonth,
                                                  totalPending: totalPending,
                                                  savings: savings,
                                                  nextDueBill: nextDueBill,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: _buildSavingsCard(
                                                  uid: uid,
                                                  savings: savings,
                                                  suggestedReserve: suggestedReserve,
                                                  projectedLeftover: projectedLeftover,
                                                ),
                                              ),
                                            ],
                                          )
                                        else ...[
                                          _buildBudgetHealthCard(
                                            salary: salary,
                                            totalPaidThisMonth: totalPaidThisMonth,
                                            totalPending: totalPending,
                                            savings: savings,
                                            nextDueBill: nextDueBill,
                                          ),
                                          const SizedBox(height: 14),
                                          _buildSavingsCard(
                                            uid: uid,
                                            savings: savings,
                                            suggestedReserve: suggestedReserve,
                                            projectedLeftover: projectedLeftover,
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        _buildBillsSection(
                                          uid: uid,
                                          allActiveBills: activeBills,
                                          filteredBills: filteredBills,
                                          overdueCount: overdueBills.length,
                                          upcoming7Count: upcoming7Bills.length,
                                          recurringCount: recurringBills.length,
                                          historyCount: history.length,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      floatingActionButton: isWide
                          ? null
                          : ScaleTransition(
                              scale: _fabScale,
                              child: FloatingActionButton.extended(
                                heroTag: 'fab_nova_conta',
                                onPressed: () => _showBillModal(uid),
                                backgroundColor: _tealDark,
                                foregroundColor: Colors.white,
                                elevation: 6,
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  'Nova Conta',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
