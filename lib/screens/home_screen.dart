import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';
import '../models/payment_record.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;
  final Set<String> _payingBillIds = {};

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
    _fabController.dispose();
    super.dispose();
  }

  String _formatShortMonthYear(DateTime date) =>
      '${_shortMonthNames[date.month - 1]}/${date.year}';

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
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Sair da conta', style: TextStyle(color: Colors.white)),
        content: const Text('Tem certeza de que deseja sair?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF10B981),
          action: SnackBarAction(
            label: 'Ver Histórico',
            textColor: Colors.white,
            onPressed: () => _openHistory(uid),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar pagamento: $e'),
            backgroundColor: Colors.red,
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
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 24,
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
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Definir Salário', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Informe a sua renda ou salário mensal para calcular o saldo disponível.', style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final val = _parseAmount(salaryCtrl.text);
                                  if (val == null) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await Provider.of<FirestoreService>(context, listen: false).setSalary(uid, val);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao atualizar salário: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Salvar Salário', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 24,
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
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Reserva de Emergência',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajuste manualmente o valor total guardado na sua reserva/cofrinho.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
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
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final val = _parseAmount(savingsCtrl.text);
                                  if (val == null) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await Provider.of<FirestoreService>(context, listen: false).setSavings(uid, val);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao atualizar reserva: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Salvar Reserva', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // ========== UI Helpers ===========
  Widget _buildHeader({
    required User user,
    required String uid,
    required double salary,
    required double totalPaidThisMonth,
    required double totalPending,
    required double currentBalance,
    required double projectedFinalBalance,
    required int historyCount,
  }) {
    final userLabel = user.isAnonymous
        ? 'Usuário Anônimo'
        : (user.email ?? 'Minha Conta');

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x666C63FF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        userLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openHistory(uid),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        historyCount > 0 ? 'Histórico ($historyCount)' : 'Histórico',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                tooltip: 'Sair',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Saldo Atual Disponível', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _currencyFmt.format(currentBalance),
            style: TextStyle(
              color: currentBalance >= 0 ? Colors.white : Colors.red.shade200,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Previsão Livre Final: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                _currencyFmt.format(projectedFinalBalance),
                style: TextStyle(
                  color: projectedFinalBalance >= 0 ? Colors.white70 : Colors.red.shade200,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStat(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Salário',
                value: _currencyFmt.format(salary),
                onTap: () => _showEditSalaryModal(uid, salary),
                trailingIcon: Icons.edit_outlined,
              ),
              const SizedBox(width: 8),
              _buildStat(
                icon: Icons.schedule_rounded,
                label: 'A pagar',
                value: _currencyFmt.format(totalPending),
                valueColor: Colors.orange.shade200,
              ),
              const SizedBox(width: 8),
              _buildStat(
                icon: Icons.check_circle_outline,
                label: 'Pago (mês)',
                value: _currencyFmt.format(totalPaidThisMonth),
                valueColor: Colors.green.shade200,
                onTap: () => _openHistory(uid),
                trailingIcon: Icons.history_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(14),
            border: trailingIcon != null ? Border.all(color: Colors.white24, width: 0.8) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailingIcon != null)
                    Icon(trailingIcon, color: Colors.white54, size: 12),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Card Dedicado para Reserva de Emergência (Caixinha) ==========
  Widget _buildSavingsCard({
    required String uid,
    required double savings,
    required double suggestedReserve,
    required double projectedLeftover,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x336C63FF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x266C63FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.savings_outlined, color: Color(0xFF6C63FF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserva de Emergência',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Cofrinho / Guardado',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _showEditSavingsModal(uid, savings),
                icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                tooltip: 'Editar Reserva',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _currencyFmt.format(savings),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'guardados',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: projectedLeftover > 0 ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: projectedLeftover > 0 ? const Color(0x6610B981) : const Color(0x66F59E0B),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  projectedLeftover > 0 ? Icons.lightbulb_outline : Icons.info_outline,
                  color: projectedLeftover > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projectedLeftover > 0
                        ? 'Sugestão do mês: Guardar 10% da sobra (${_currencyFmt.format(suggestedReserve)})'
                        : 'Sem sobra prevista neste mês para guardar.',
                    style: TextStyle(
                      color: projectedLeftover > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (suggestedReserve > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    final newTotal = savings + suggestedReserve;
                    await firestore.setSavings(uid, newTotal);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Guardado ${_currencyFmt.format(suggestedReserve)} na reserva!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao atualizar reserva: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(
                  'Aplicar 10% (${_currencyFmt.format(suggestedReserve)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
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
              color: Color(0xFF1E1E2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 24,
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
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Editar Conta' : 'Nova Conta',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            if (isEditing &&
                                billToEdit.isRecurring &&
                                billToEdit.installmentIndex != null &&
                                billToEdit.installmentTotal != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0x266C63FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Parcela ${billToEdit.installmentIndex}/${billToEdit.installmentTotal}',
                                  style: const TextStyle(
                                    color: Color(0xFF9D97FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: titleCtrl,
                          label: 'Descrição',
                          icon: Icons.description_outlined,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              builder: (c, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF), surface: Color(0xFF1E1E2E)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: Color(0xFF6C63FF), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Vencimento: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recorrente Mensal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: const Text(
                            'Ao pagar, envia para o Histórico e avança para o próximo mês',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          value: isRecurring,
                          activeThumbColor: const Color(0xFF6C63FF),
                          onChanged: (v) => setModalState(() => isRecurring = v),
                        ),

                        if (isRecurring) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252538),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x4D6C63FF)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Repetir por mais quantos meses?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: remainingRepeats > 1
                                          ? () => setRepeats(remainingRepeats - 1)
                                          : null,
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: const Color(0xFF6C63FF),
                                      disabledColor: Colors.white24,
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
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          filled: true,
                                          fillColor: const Color(0xFF1E1E2E),
                                          suffixText: remainingRepeats == 1 ? 'mês' : 'meses',
                                          suffixStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Colors.white12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
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
                                      color: const Color(0xFF6C63FF),
                                      disabledColor: Colors.white24,
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
                                      selectedColor: const Color(0xFF6C63FF),
                                      backgroundColor: const Color(0xFF1E1E2E),
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFF6C63FF) : Colors.white12,
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
                                    color: const Color(0x1A6C63FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.event_repeat_rounded, color: Color(0xFF9D97FF), size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Sequência automática: ${previewDates.length} parcelas (${_formatShortMonthYear(previewDates.first)} a ${_formatShortMonthYear(previewDates.last)})',
                                              style: const TextStyle(
                                                color: Color(0xFFC4BFFF),
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
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E1E2E),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.white12),
                                                ),
                                                child: Text(
                                                  DateFormat('dd/MM/yy').format(d),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                ),
                                              )),
                                          if (previewDates.length > 5)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0x336C63FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '+${previewDates.length - 5} até ${DateFormat('dd/MM/yy').format(previewDates.last)}',
                                                style: const TextStyle(color: Color(0xFFC4BFFF), fontSize: 11),
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

                        const SizedBox(height: 24),
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
                                    final nextTotal = isRecurring ? (currentInstallment + repeats) : null;

                                    final bill = Bill(
                                      id: isEditing ? billToEdit.id : DateTime.now().millisecondsSinceEpoch.toString(),
                                      title: titleCtrl.text.trim(),
                                      amount: amountVal,
                                      dueDate: selectedDate,
                                      isPaid: false,
                                      isRecurring: isRecurring,
                                      category: isEditing ? billToEdit.category : 'Outros',
                                      installmentIndex: nextIndex,
                                      installmentTotal: nextTotal,
                                      originalDay: isRecurring ? selectedDate.day : null,
                                    );

                                    try {
                                      final firestore = Provider.of<FirestoreService>(context, listen: false);
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
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    isEditing ? 'Atualizar Conta' : 'Salvar Conta',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildBillCard(Bill bill, String uid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final billDate = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);

    final isOverdue = billDate.isBefore(today);
    final isToday = billDate.isAtSameMomentAs(today);
    final daysLeft = billDate.difference(today).inDays;
    final isPaying = _payingBillIds.contains(bill.id);

    String subtitleText;
    Color subtitleColor;

    if (isOverdue) {
      subtitleText = 'Venceu em ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      subtitleColor = Colors.red.shade300;
    } else if (isToday) {
      subtitleText = 'Vence hoje! — ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      subtitleColor = Colors.orange.shade300;
    } else {
      subtitleText = 'Vence em $daysLeft dia(s) — ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}';
      subtitleColor = daysLeft <= 3 ? Colors.orange.shade300 : Colors.white38;
    }

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E2E),
                title: const Text('Excluir conta', style: TextStyle(color: Colors.white)),
                content: Text('Deseja excluir "${bill.title}"?', style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => Provider.of<FirestoreService>(context, listen: false).deleteBill(uid, bill.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOverdue ? const Color(0x66EF4444) : const Color(0x0FFFFFFF),
          ),
        ),
        child: ListTile(
          onTap: () => _showBillModal(uid, billToEdit: bill),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0x26EF4444) : const Color(0x266C63FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              color: isOverdue ? Colors.red.shade300 : const Color(0xFF6C63FF),
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  bill.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (bill.isRecurring) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x266C63FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat_rounded, color: Color(0xFF9D97FF), size: 11),
                      const SizedBox(width: 3),
                      Text(
                        bill.installmentIndex != null && bill.installmentTotal != null
                            ? '${bill.installmentIndex}/${bill.installmentTotal}'
                            : 'Fixa',
                        style: const TextStyle(
                          color: Color(0xFF9D97FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitleText, style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFmt.format(bill.amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isPaying ? null : () => _handlePayBill(uid, bill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x336C63FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isPaying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Color(0xFF9D97FF),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Pagar',
                          style: TextStyle(
                            color: Color(0xFF9D97FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
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
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF12121C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    final uid = user.uid;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final now = DateTime.now();

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
                        backgroundColor: const Color(0xFF12121C),
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Erro ao carregar contas do Firebase: ${billsSnap.error}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    // Apenas contas pendentes ficam na tela inicial (pagas vão para o Histórico)
                    final activeBills = (billsSnap.data ?? []).where((b) => !b.isPaid).toList();
                    final totalPending = activeBills.fold(0.0, (s, b) => s + b.amount);

                    // Regras de negócio:
                    final projectedLeftover = salary - (totalPaidThisMonth + totalPending);
                    final suggestedReserve = projectedLeftover > 0 ? (projectedLeftover * 0.10) : 0.0;

                    final currentBalance = salary - totalPaidThisMonth - savings;
                    final projectedFinalBalance = salary - (totalPaidThisMonth + totalPending) - savings;

                    return Scaffold(
                      backgroundColor: const Color(0xFF12121C),
                      body: SafeArea(
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _buildHeader(
                                user: user,
                                uid: uid,
                                salary: salary,
                                totalPaidThisMonth: totalPaidThisMonth,
                                totalPending: totalPending,
                                currentBalance: currentBalance,
                                projectedFinalBalance: projectedFinalBalance,
                                historyCount: history.length,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildSavingsCard(
                                uid: uid,
                                savings: savings,
                                suggestedReserve: suggestedReserve,
                                projectedLeftover: projectedLeftover,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Contas a Pagar',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${activeBills.length} pendente(s)',
                                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            activeBills.isEmpty
                                ? SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _buildEmptyState(uid, history.length),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => _buildBillCard(activeBills[i], uid),
                                      childCount: activeBills.length,
                                    ),
                                  ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
                      floatingActionButton: ScaleTransition(
                        scale: _fabScale,
                        child: FloatingActionButton.extended(
                          heroTag: 'fab_nova_conta',
                          onPressed: () => _showBillModal(uid),
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          icon: const Icon(Icons.add),
                          label: const Text('Nova Conta', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildEmptyState(String uid, int historyCount) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 72, color: Color(0x1AFFFFFF)),
            const SizedBox(height: 16),
            Text(
              historyCount > 0 ? 'Tudo pago por aqui!' : 'Nenhuma conta cadastrada',
              style: const TextStyle(color: Colors.white38, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              historyCount > 0
                  ? 'Consulte as contas já pagas no Histórico ou adicione uma nova.'
                  : 'Toque em "Nova Conta" para começar',
              style: const TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (historyCount > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openHistory(uid),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('Ver Histórico ($historyCount)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9D97FF),
                  side: const BorderSide(color: Color(0x666C63FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
