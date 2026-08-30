import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

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

  // ========== UI Helpers ===========
  Widget _buildHeader(double salary, double totalPending, double balance) {
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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(108, 99, 255, 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo disponível', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _currencyFmt.format(balance),
            style: TextStyle(
              color: balance >= 0 ? Colors.white : Colors.red.shade200,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStat(icon: Icons.account_balance_wallet_outlined, label: 'Salário', value: _currencyFmt.format(salary)),
              const SizedBox(width: 12),
              _buildStat(icon: Icons.receipt_long_outlined, label: 'A pagar', value: _currencyFmt.format(totalPending), valueColor: Colors.red.shade200),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({required IconData icon, required String label, required String value, Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: valueColor ?? Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Bill CRUD UI ===========
  void _showAddBillModal(String uid) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    bool isRecurring = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                const Text('Nova Conta', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildTextField(controller: titleCtrl, label: 'Descrição', icon: Icons.description_outlined, validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null),
                const SizedBox(height: 16),
                _buildTextField(controller: amountCtrl, label: 'Valor (R\$)', icon: Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe o valor';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                  return null;
                }),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF), surface: Color(0xFF1E1E2E)),), child: child!),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A3E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFF6C63FF), size: 20),
                        const SizedBox(width: 12),
                        Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Recorrente Mensal', style: TextStyle(color: Colors.white70)),
                  value: isRecurring,
                  activeColor: const Color(0xFF6C63FF),
                  onChanged: (v) => setState(() => isRecurring = v),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final bill = Bill(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleCtrl.text.trim(),
                        amount: double.parse(amountCtrl.text.replaceAll(',', '.')),
                        dueDate: selectedDate,
                        isPaid: false,
                        isRecurring: isRecurring,
                        category: 'Outros',
                      );
                      try {
                        await Provider.of<FirestoreService>(context, listen: false).addBill(uid, bill);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Erro ao salvar: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: const Text('Salvar Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(Bill bill, String uid) {
    final isOverdue = !bill.isPaid && bill.dueDate.isBefore(DateTime.now());
    final daysLeft = bill.dueDate.difference(DateTime.now()).inDays;
    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
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
        decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(18), border: Border.all(color: isOverdue ? Color.fromRGBO(239, 68, 68, 0.4) : Color.fromRGBO(255, 255, 255, 0.06))),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: bill.isPaid ? Color.fromRGBO(34, 197, 94, 0.15) : isOverdue ? Color.fromRGBO(239, 68, 68, 0.15) : Color.fromRGBO(108, 99, 255, 0.15), shape: BoxShape.circle),
            child: Icon(bill.isPaid ? Icons.check_circle_outline : isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded, color: bill.isPaid ? const Color(0xFF22C55E) : isOverdue ? Colors.red.shade300 : const Color(0xFF6C63FF), size: 22),
          ),
          title: Text(bill.title, style: TextStyle(color: bill.isPaid ? Colors.white38 : Colors.white, fontWeight: FontWeight.w600, fontSize: 15, decoration: bill.isPaid ? TextDecoration.lineThrough : null, decorationColor: Colors.white38)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              bill.isPaid ? 'Pago ✓' : isOverdue ? 'Venceu em ${DateFormat('dd/MM').format(bill.dueDate)}' : daysLeft == 0 ? 'Vence hoje!' : 'Vence em $daysLeft dia(s) — ${DateFormat('dd/MM/yyyy').format(bill.dueDate)}',
              style: TextStyle(color: bill.isPaid ? Colors.white24 : isOverdue ? Colors.red.shade300 : daysLeft <= 3 ? Colors.orange.shade300 : Colors.white38, fontSize: 12),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_currencyFmt.format(bill.amount), style: TextStyle(color: bill.isPaid ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  await Provider.of<FirestoreService>(context, listen: false).toggleBillStatus(uid, bill.id, !bill.isPaid);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bill.isPaid ? Colors.white12 : Color.fromRGBO(108, 99, 255, 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(bill.isPaid ? 'Desfazer' : 'Pagar', style: TextStyle(color: bill.isPaid ? Colors.white38 : const Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, String? Function(String?)? validator}) {
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
    final auth = Provider.of<AuthService>(context, listen: false);
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final uid = snapshot.data!.uid;
        final firestore = Provider.of<FirestoreService>(context, listen: false);
        return StreamBuilder<double>(
          stream: firestore.salaryStream(uid),
          builder: (c, salarySnap) {
            final salary = salarySnap.data ?? 0.0;
            return StreamBuilder<List<Bill>>(
              stream: firestore.billsStream(uid),
              builder: (c2, billsSnap) {
                final bills = billsSnap.data ?? [];
                final totalPending = bills.where((b) => !b.isPaid).fold(0.0, (s, b) => s + b.amount);
                final balance = salary - totalPending;
                return Scaffold(
                  backgroundColor: const Color(0xFF12121C),
                  body: SafeArea(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(salary, totalPending, balance)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Suas Contas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('${bills.length} item(s)', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        bills.isEmpty
                            ? SliverFillRemaining(child: _buildEmptyState())
                            : SliverList(delegate: SliverChildBuilderDelegate((_, i) => _buildBillCard(bills[i], uid), childCount: bills.length)),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                  floatingActionButton: ScaleTransition(
                    scale: _fabScale,
                    child: FloatingActionButton.extended(
                      heroTag: 'fab_nova_conta',
                      onPressed: () => _showAddBillModal(uid),
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 72, color: Color.fromRGBO(255, 255, 255, 0.1)),
        const SizedBox(height: 16),
        const Text('Nenhuma conta cadastrada', style: TextStyle(color: Colors.white38, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Toque em "Nova Conta" para começar', style: TextStyle(color: Colors.white24, fontSize: 13)),
      ]),
    );
  }
}
