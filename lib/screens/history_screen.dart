import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment_record.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatefulWidget {
  final String uid;

  const HistoryScreen({super.key, required this.uid});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
  String? _selectedMonthKey; // null = Todos

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return '${_shortMonthNames[month - 1]}/$year';
  }

  Future<void> _confirmUndo(PaymentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Desfazer pagamento?', style: TextStyle(color: Colors.white)),
        content: Text(
          record.wasRecurring
              ? 'A conta "${record.title}" voltará para o vencimento ${DateFormat('dd/MM/yyyy').format(record.dueDate)}${record.installmentIndex != null && record.installmentTotal != null ? ' (Parcela ${record.installmentIndex}/${record.installmentTotal})' : ''} na tela inicial.'
              : 'A conta "${record.title}" (${DateFormat('dd/MM/yyyy').format(record.dueDate)}) voltará como pendente na tela inicial.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desfazer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<FirestoreService>(context, listen: false)
          .undoPayment(widget.uid, record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pagamento de "${record.title}" desfeito e restaurado nas contas.',
            ),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desfazer pagamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF12121C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Histórico de Pagamentos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: StreamBuilder<List<PaymentRecord>>(
        stream: firestore.paymentHistoryStream(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar histórico: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }

          final allRecords = snapshot.data ?? [];
          if (allRecords.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 72, color: Color(0x1AFFFFFF)),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum pagamento registrado ainda',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quando você marcar uma conta como paga, ela será registrada aqui.',
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final monthKeys = <String>[];
          for (final r in allRecords) {
            final key = _monthKey(r.paidAt);
            if (!monthKeys.contains(key)) monthKeys.add(key);
          }

          final activeMonthKey =
              (_selectedMonthKey != null && monthKeys.contains(_selectedMonthKey))
                  ? _selectedMonthKey
                  : null;

          final filtered = activeMonthKey == null
              ? allRecords
              : allRecords.where((r) => _monthKey(r.paidAt) == activeMonthKey).toList();

          final totalPaid = filtered.fold(0.0, (sum, r) => sum + r.amount);

          return Column(
            children: [
              // Resumo do histórico
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeMonthKey == null
                              ? 'Total Pago (Histórico)'
                              : 'Total Pago (${_monthLabel(activeMonthKey)})',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFmt.format(totalPaid),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filtered.length} pago(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filtros por mês de pagamento
              if (monthKeys.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todos'),
                          selected: activeMonthKey == null,
                          onSelected: (_) => setState(() => _selectedMonthKey = null),
                          selectedColor: const Color(0xFF6C63FF),
                          backgroundColor: const Color(0xFF1E1E2E),
                          labelStyle: TextStyle(
                            color: activeMonthKey == null ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: activeMonthKey == null
                                ? const Color(0xFF6C63FF)
                                : Colors.white12,
                          ),
                        ),
                      ),
                      ...monthKeys.map((key) {
                        final isSelected = activeMonthKey == key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_monthLabel(key)),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedMonthKey = key),
                            selectedColor: const Color(0xFF6C63FF),
                            backgroundColor: const Color(0xFF1E1E2E),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white12,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Lista de pagamentos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    return Dismissible(
                      key: Key(record.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E2E),
                                title: const Text('Apagar do histórico',
                                    style: TextStyle(color: Colors.white)),
                                content: Text(
                                  'Deseja remover o registro de "${record.title}" permanentemente do histórico?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar',
                                        style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Apagar',
                                        style: TextStyle(color: Colors.white)),
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
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                      ),
                      onDismissed: (_) =>
                          firestore.deletePaymentRecord(widget.uid, record.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x1F10B981)),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0x2610B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (record.wasRecurring) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0x266C63FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    record.installmentIndex != null &&
                                            record.installmentTotal != null
                                        ? '${record.installmentIndex}/${record.installmentTotal}'
                                        : 'Recorrente',
                                    style: const TextStyle(
                                      color: Color(0xFF9D97FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vencimento: ${DateFormat('dd/MM/yyyy').format(record.dueDate)}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                                Text(
                                  'Pago em ${DateFormat('dd/MM/yyyy • HH:mm').format(record.paidAt)}',
                                  style: const TextStyle(
                                      color: Color(0xFF10B981), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFmt.format(record.amount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _confirmUndo(record),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Desfazer',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
