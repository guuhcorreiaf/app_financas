import 'package:flutter_test/flutter_test.dart';
import 'package:app_financas/models/bill_model.dart';
import 'package:app_financas/models/payment_record.dart';

void main() {
  group('Bill.advanceToNextRecurrence', () {
    test('avança 01/12/2026 (1/4) -> 01/01/2027 (2/4) -> 01/02/2027 (3/4) -> 01/03/2027 (4/4)', () {
      var bill = Bill(
        id: 'bill_1',
        title: 'Internet',
        amount: 120.0,
        dueDate: DateTime(2026, 12, 1),
        isRecurring: true,
        installmentIndex: 1,
        installmentTotal: 4,
        originalDay: 1,
      );

      expect(bill.hasNextRecurrence, isTrue);

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2027, 1, 1));
      expect(bill.installmentIndex, 2);
      expect(bill.installmentTotal, 4);
      expect(bill.isPaid, isFalse);
      expect(bill.hasNextRecurrence, isTrue);

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2027, 2, 1));
      expect(bill.installmentIndex, 3);
      expect(bill.hasNextRecurrence, isTrue);

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2027, 3, 1));
      expect(bill.installmentIndex, 4);
      // Última parcela: após pagar esta, vai para o histórico e sai da tela inicial
      expect(bill.hasNextRecurrence, isFalse);
    });

    test('preserva o dia original 31 mesmo após passar por fevereiro', () {
      var bill = Bill(
        id: 'bill_31',
        title: 'Aluguel',
        amount: 1500.0,
        dueDate: DateTime(2026, 1, 31),
        isRecurring: true,
        installmentIndex: 1,
        installmentTotal: 4,
        originalDay: 31,
      );

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2026, 2, 28));

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2026, 3, 31));

      bill = bill.advanceToNextRecurrence();
      expect(bill.dueDate, DateTime(2026, 4, 30));
    });

    test('conta não recorrente não tem próxima repetição', () {
      final bill = Bill(
        id: 'single',
        title: 'Mercado',
        amount: 250.0,
        dueDate: DateTime(2026, 12, 5),
        isRecurring: false,
      );
      expect(bill.hasNextRecurrence, isFalse);
    });
  });

  group('PaymentRecord', () {
    test('cria registro a partir da conta e restaura estado anterior ao desfazer', () {
      final bill = Bill(
        id: 'bill_1',
        title: 'Internet',
        amount: 120.0,
        dueDate: DateTime(2026, 12, 1),
        isRecurring: true,
        installmentIndex: 1,
        installmentTotal: 4,
        originalDay: 1,
      );

      final record = PaymentRecord.fromBill(
        bill,
        id: 'rec_1',
        paidAt: DateTime(2026, 11, 25, 18, 30),
      );

      expect(record.title, 'Internet');
      expect(record.dueDate, DateTime(2026, 12, 1));
      expect(record.installmentIndex, 1);
      expect(record.installmentTotal, 4);

      final restored = record.toRestoredBill();
      expect(restored.id, 'bill_1');
      expect(restored.dueDate, DateTime(2026, 12, 1));
      expect(restored.isPaid, isFalse);
      expect(restored.isRecurring, isTrue);
      expect(restored.installmentIndex, 1);
      expect(restored.installmentTotal, 4);
    });
  });
}
