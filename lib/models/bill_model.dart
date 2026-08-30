import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final bool isRecurring;
  final String category;

  Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.isRecurring = false,
    this.category = 'Outros',
  });

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    bool? isRecurring,
    String? category,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      isRecurring: isRecurring ?? this.isRecurring,
      category: category ?? this.category,
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
      };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        dueDate: (json['dueDate'] as Timestamp).toDate(),
        isPaid: json['isPaid'] as bool? ?? false,
        isRecurring: json['isRecurring'] as bool? ?? false,
        category: json['category'] as String? ?? 'Outros',
      );
}
