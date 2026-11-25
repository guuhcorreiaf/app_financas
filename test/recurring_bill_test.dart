import 'package:flutter_test/flutter_test.dart';
import 'package:app_financas/models/bill_model.dart';

void main() {
  group('Bill.addMonths', () {
    test('soma meses mantendo o dia quando válido (Julho + 3x -> Ago, Set, Out)', () {
      final start = DateTime(2026, 7, 15);
      expect(Bill.addMonths(start, 0), DateTime(2026, 7, 15));
      expect(Bill.addMonths(start, 1), DateTime(2026, 8, 15));
      expect(Bill.addMonths(start, 2), DateTime(2026, 9, 15));
      expect(Bill.addMonths(start, 3), DateTime(2026, 10, 15));
    });

    test('ajusta corretamente virada de ano', () {
      final start = DateTime(2026, 11, 10);
      expect(Bill.addMonths(start, 1), DateTime(2026, 12, 10));
      expect(Bill.addMonths(start, 2), DateTime(2027, 1, 10));
      expect(Bill.addMonths(start, 3), DateTime(2027, 2, 10));
    });

    test('ajusta dia 31 para último dia de meses menores sem transbordar', () {
      final start = DateTime(2026, 1, 31);
      expect(Bill.addMonths(start, 1), DateTime(2026, 2, 28));
      expect(Bill.addMonths(start, 2), DateTime(2026, 3, 31));
      expect(Bill.addMonths(start, 3), DateTime(2026, 4, 30));

      // Ano bissexto
      final leapStart = DateTime(2028, 1, 31);
      expect(Bill.addMonths(leapStart, 1), DateTime(2028, 2, 29));
    });
  });

  group('Bill.generateRecurringSeries', () {
    test('gera conta inicial + 3 repetições mensais com metadados corretos', () {
      final series = Bill.generateRecurringSeries(
        baseId: 'grp1',
        title: 'Internet',
        amount: 120.0,
        startDate: DateTime(2026, 7, 10),
        additionalMonths: 3,
      );

      expect(series.length, 4);
      expect(series.map((b) => b.dueDate).toList(), [
        DateTime(2026, 7, 10),
        DateTime(2026, 8, 10),
        DateTime(2026, 9, 10),
        DateTime(2026, 10, 10),
      ]);

      for (var i = 0; i < series.length; i++) {
        expect(series[i].isRecurring, isTrue);
        expect(series[i].recurrenceGroupId, 'grp1');
        expect(series[i].installmentIndex, i + 1);
        expect(series[i].installmentTotal, 4);
        expect(series[i].isPaid, isFalse);
      }

      // IDs únicos
      expect(series.map((b) => b.id).toSet().length, 4);
    });
  });
}
