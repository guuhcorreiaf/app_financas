import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final bool isRecurring;
  final String category;
  final int? installmentIndex;
  final int? installmentTotal;
  final int? originalDay;

  Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.isRecurring = false,
    this.category = 'Outros',
    this.installmentIndex,
    this.installmentTotal,
    this.originalDay,
  });

  /// Soma [monthsToAdd] meses calendário à [date], preservando [preferredDay]
  /// (ou `date.day`) e ajustando para o último dia válido do mês de destino
  /// (ex: dia 31 em fevereiro -> 28/02 ou 29/02, voltando para 31/03 em março).
  static DateTime addMonths(DateTime date, int monthsToAdd, {int? preferredDay}) {
    final anchorDay = preferredDay ?? date.day;
    final totalMonths = (date.year * 12 + (date.month - 1)) + monthsToAdd;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = anchorDay > lastDayOfTargetMonth ? lastDayOfTargetMonth : anchorDay;
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Retorna `true` se esta conta ainda possui próxima parcela/repetição
  /// quando for marcada como paga.
  bool get hasNextRecurrence {
    if (!isRecurring) return false;
    if (installmentTotal == null) return true; // recorrência contínua legada
    final current = installmentIndex ?? 1;
    return current < installmentTotal!;
  }

  /// Avança esta conta recorrente para o próximo mês e próxima parcela,
  /// mantendo-a pendente (`isPaid = false`) para aparecer na fila com a nova data.
  Bill advanceToNextRecurrence() {
    final anchorDay = originalDay ?? dueDate.day;
    final nextDate = addMonths(dueDate, 1, preferredDay: anchorDay);
    final currentIndex = installmentIndex ?? 1;

    return copyWith(
      dueDate: nextDate,
      isPaid: false,
      installmentIndex: installmentTotal != null ? currentIndex + 1 : installmentIndex,
      originalDay: anchorDay,
    );
  }

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    bool? isRecurring,
    String? category,
    int? installmentIndex,
    int? installmentTotal,
    int? originalDay,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      isRecurring: isRecurring ?? this.isRecurring,
      category: category ?? this.category,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
      originalDay: originalDay ?? this.originalDay,
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
        if (installmentIndex != null) 'installmentIndex': installmentIndex,
        if (installmentTotal != null) 'installmentTotal': installmentTotal,
        if (originalDay != null) 'originalDay': originalDay,
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
        installmentIndex: (json['installmentIndex'] as num?)?.toInt(),
        installmentTotal: (json['installmentTotal'] as num?)?.toInt(),
        originalDay: (json['originalDay'] as num?)?.toInt(),
      );
}
