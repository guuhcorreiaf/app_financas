import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment_record.dart';
import '../services/firestore_service.dart';
import '../utils/bill_categories.dart';

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
  String? _selectedMonthKey;

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Desfazer pagamento?',
          style: TextStyle(color: Color(0xFF0F2A2E), fontWeight: FontWeight.bold),
        ),
        content: Text(
          record.wasRecurring
              ? 'A conta "${record.title}" voltará para o vencimento ${DateFormat('dd/MM/yyyy').format(record.dueDate)}${record.installmentIndex != null && record.installmentTotal != null ? ' (Parcela ${record.installmentIndex}/${record.installmentTotal})' : ''} na tela inicial.'
              : 'A conta "${record.title}" (${DateFormat('dd/MM/yyyy').format(record.dueDate)}) voltará como pendente na tela inicial.',
          style: const TextStyle(color: Color(0xFF5B7277)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF5B7277))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F5B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desfazer'),
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
            backgroundColor: const Color(0xFF065F5B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desfazer pagamento: $e'),
            backgroundColor: const Color(0xFF9F3A3E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065F5B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Histórico de Pagamentos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  style: const TextStyle(color: Color(0xFF9F3A3E)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF065F5B)),
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
                    Icon(Icons.history_rounded, size: 72, color: Color(0xFFCBD9DC)),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum pagamento registrado ainda',
                      style: TextStyle(
                        color: Color(0xFF0F2A2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quando você marcar uma conta como paga, ela será registrada aqui.',
                      style: TextStyle(color: Color(0xFF5B7277), fontSize: 13),
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  // Resumo no estilo hero + card branco
                  Stack(
                    children: [
                      Container(
                        height: 64,
                        width: double.infinity,
                        color: const Color(0xFF065F5B),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2ECEE)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12065F5B),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F5F3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Color(0xFF0D6E6E),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeMonthKey == null
                                          ? 'Total Pago (Histórico)'
                                          : 'Total Pago (${_monthLabel(activeMonthKey)})',
                                      style: const TextStyle(
                                        color: Color(0xFF5B7277),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currencyFmt.format(totalPaid),
                                      style: const TextStyle(
                                        color: Color(0xFF0D6E6E),
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F5F3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filtered.length} pago(s)',
                                style: const TextStyle(
                                  color: Color(0xFF0D6E6E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

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
                              selectedColor: const Color(0xFF065F5B),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: activeMonthKey == null
                                    ? Colors.white
                                    : const Color(0xFF0F2A2E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: activeMonthKey == null
                                    ? const Color(0xFF065F5B)
                                    : const Color(0xFFD6E4E6),
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
                                selectedColor: const Color(0xFF065F5B),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF0F2A2E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF065F5B)
                                      : const Color(0xFFD6E4E6),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        final cat = BillCategories.of(record.category);

                        return Dismissible(
                          key: Key(record.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                    title: const Text(
                                      'Apagar do histórico',
                                      style: TextStyle(
                                          color: Color(0xFF0F2A2E),
                                          fontWeight: FontWeight.bold),
                                    ),
                                    content: Text(
                                      'Deseja remover o registro de "${record.title}" permanentemente do histórico?',
                                      style: const TextStyle(color: Color(0xFF5B7277)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar',
                                            style: TextStyle(color: Color(0xFF5B7277))),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF9F3A3E),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Apagar'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9F3A3E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          ),
                          onDismissed: (_) =>
                              firestore.deletePaymentRecord(widget.uid, record.id),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2ECEE)),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cat.softBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(cat.icon, color: cat.color, size: 22),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.title,
                                      style: const TextStyle(
                                        color: Color(0xFF0F2A2E),
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
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F5F3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        record.installmentIndex != null &&
                                                record.installmentTotal != null
                                            ? '${record.installmentIndex}/${record.installmentTotal}'
                                            : 'Recorrente',
                                        style: const TextStyle(
                                          color: Color(0xFF065F5B),
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
                                      '${cat.name} • Venc. ${DateFormat('dd/MM/yyyy').format(record.dueDate)}',
                                      style: const TextStyle(
                                          color: Color(0xFF5B7277), fontSize: 12),
                                    ),
                                    Text(
                                      'Pago em ${DateFormat('dd/MM/yyyy • HH:mm').format(record.paidAt)}',
                                      style: const TextStyle(
                                        color: Color(0xFF0D6E6E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                      color: Color(0xFF0F2A2E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _confirmUndo(record),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF3F4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Desfazer',
                                        style: TextStyle(
                                          color: Color(0xFF5B7277),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
