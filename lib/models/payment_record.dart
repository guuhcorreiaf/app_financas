import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_model.dart';

class PaymentRecord {
  final String id;
  final String billId;
  final String title;
  final double amount;
  final DateTime dueDate;
  final DateTime paidAt;
  final String category;
  final bool wasRecurring;
  final int? installmentIndex;
  final int? installmentTotal;
  final int? originalDay;

  PaymentRecord({
    required this.id,
    required this.billId,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.paidAt,
    this.category = 'Outros',
    this.wasRecurring = false,
    this.installmentIndex,
    this.installmentTotal,
    this.originalDay,
  });

  factory PaymentRecord.fromBill(Bill bill, {required String id, DateTime? paidAt}) {
    return PaymentRecord(
      id: id,
      billId: bill.id,
      title: bill.title,
      amount: bill.amount,
      dueDate: bill.dueDate,
      paidAt: paidAt ?? DateTime.now(),
      category: bill.category,
      wasRecurring: bill.isRecurring,
      installmentIndex: bill.installmentIndex,
      installmentTotal: bill.installmentTotal,
      originalDay: bill.originalDay ?? bill.dueDate.day,
    );
  }

  /// Reconstrói a conta no estado exatamente anterior a este pagamento
  /// (usado ao desfazer um pagamento no Histórico).
  Bill toRestoredBill() {
    return Bill(
      id: billId,
      title: title,
      amount: amount,
      dueDate: dueDate,
      isPaid: false,
      isRecurring: wasRecurring,
      category: category,
      installmentIndex: installmentIndex,
      installmentTotal: installmentTotal,
      originalDay: originalDay ?? dueDate.day,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'billId': billId,
        'title': title,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'paidAt': Timestamp.fromDate(paidAt),
        'category': category,
        'wasRecurring': wasRecurring,
        if (installmentIndex != null) 'installmentIndex': installmentIndex,
        if (installmentTotal != null) 'installmentTotal': installmentTotal,
        if (originalDay != null) 'originalDay': originalDay,
      };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String? ?? '',
        billId: json['billId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        dueDate: json['dueDate'] is Timestamp
            ? (json['dueDate'] as Timestamp).toDate()
            : DateTime.tryParse(json['dueDate']?.toString() ?? '') ?? DateTime.now(),
        paidAt: json['paidAt'] is Timestamp
            ? (json['paidAt'] as Timestamp).toDate()
            : DateTime.tryParse(json['paidAt']?.toString() ?? '') ?? DateTime.now(),
        category: json['category'] as String? ?? 'Outros',
        wasRecurring: json['wasRecurring'] as bool? ?? false,
        installmentIndex: (json['installmentIndex'] as num?)?.toInt(),
        installmentTotal: (json['installmentTotal'] as num?)?.toInt(),
        originalDay: (json['originalDay'] as num?)?.toInt(),
      );
}
