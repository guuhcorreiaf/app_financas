import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final bool isRecurring;
  final String category;
  final String? recurrenceGroupId;
  final int? installmentIndex;
  final int? installmentTotal;

  Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.isRecurring = false,
    this.category = 'Outros',
    this.recurrenceGroupId,
    this.installmentIndex,
    this.installmentTotal,
  });

  /// Soma [monthsToAdd] meses calendário à [date], ajustando o dia para o
  /// último dia válido do mês de destino (ex: 31/01 + 1 mês -> 28/02 ou 29/02).
  static DateTime addMonths(DateTime date, int monthsToAdd) {
    final totalMonths = (date.year * 12 + (date.month - 1)) + monthsToAdd;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Gera a conta inicial + [additionalMonths] repetições mensais consecutivas.
  /// Ex: startDate em julho com additionalMonths = 3 gera 4 contas:
  /// julho (1/4), agosto (2/4), setembro (3/4) e outubro (4/4).
  static List<Bill> generateRecurringSeries({
    required String baseId,
    required String title,
    required double amount,
    required DateTime startDate,
    required int additionalMonths,
    bool isPaidFirst = false,
    String category = 'Outros',
    String? existingFirstId,
  }) {
    final repeats = additionalMonths < 0 ? 0 : additionalMonths;
    final total = 1 + repeats;
    final groupId = baseId;

    return List.generate(total, (index) {
      final isFirst = index == 0;
      return Bill(
        id: isFirst && existingFirstId != null ? existingFirstId : '${baseId}_$index',
        title: title,
        amount: amount,
        dueDate: addMonths(startDate, index),
        isPaid: isFirst ? isPaidFirst : false,
        isRecurring: repeats > 0,
        category: category,
        recurrenceGroupId: repeats > 0 ? groupId : null,
        installmentIndex: repeats > 0 ? index + 1 : null,
        installmentTotal: repeats > 0 ? total : null,
      );
    });
  }

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    bool? isRecurring,
    String? category,
    String? recurrenceGroupId,
    int? installmentIndex,
    int? installmentTotal,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      isRecurring: isRecurring ?? this.isRecurring,
      category: category ?? this.category,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'isPaid': isPaid,
        'isRecurring': isRecurring,
        'category': category,
        if (recurrenceGroupId != null) 'recurrenceGroupId': recurrenceGroupId,
        if (installmentIndex != null) 'installmentIndex': installmentIndex,
        if (installmentTotal != null) 'installmentTotal': installmentTotal,
      };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        dueDate: json['dueDate'] is Timestamp
            ? (json['dueDate'] as Timestamp).toDate()
            : DateTime.tryParse(json['dueDate']?.toString() ?? '') ?? DateTime.now(),
        isPaid: json['isPaid'] as bool? ?? false,
        isRecurring: json['isRecurring'] as bool? ?? false,
        category: json['category'] as String? ?? 'Outros',
        recurrenceGroupId: json['recurrenceGroupId'] as String?,
        installmentIndex: (json['installmentIndex'] as num?)?.toInt(),
        installmentTotal: (json['installmentTotal'] as num?)?.toInt(),
      );
}
