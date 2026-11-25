import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/payment_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _billsCol(String uid) =>
      _userDoc(uid).collection('bills');

  CollectionReference<Map<String, dynamic>> _historyCol(String uid) =>
      _userDoc(uid).collection('payment_history');

  // ── Salário ──
  Future<void> setSalary(String uid, double salary) async {
    await _userDoc(uid).set({'salary': salary}, SetOptions(merge: true));
  }

  Stream<double> salaryStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return 0.0;
      return (data['salary'] as num?)?.toDouble() ?? 0.0;
    });
  }

  // ── Reserva / Caixinha ──
  Future<void> setSavings(String uid, double savings) async {
    await _userDoc(uid).set({'savings': savings}, SetOptions(merge: true));
  }

  Stream<double> savingsStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return 0.0;
      return (data['savings'] as num?)?.toDouble() ?? 0.0;
    });
  }

  // ── Contas CRUD ──
  Future<void> addBill(String uid, Bill bill) async {
    await _billsCol(uid).doc(bill.id).set(bill.toJson());
  }

  Future<void> updateBill(String uid, Bill bill) async {
    await _billsCol(uid).doc(bill.id).set(bill.toJson());
  }

  Future<void> deleteBill(String uid, String billId) async {
    await _billsCol(uid).doc(billId).delete();
  }

  Stream<List<Bill>> billsStream(String uid) {
    return _billsCol(uid)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Bill.fromJson(doc.data()))
            .toList());
  }

  // ── Pagamento & Histórico ──
  /// Registra o pagamento em `payment_history`.
  /// - Se a conta for recorrente e ainda tiver repetições restantes, avança
  ///   automaticamente a data (+1 mês) e a parcela, retornando a próxima `Bill`.
  /// - Caso contrário (avulsa ou última parcela), remove a conta da lista ativa
  ///   e retorna `null`.
  Future<Bill?> payBill(String uid, Bill bill) async {
    final batch = _db.batch();
    final recordId = '${bill.id}_${DateTime.now().millisecondsSinceEpoch}';
    final record = PaymentRecord.fromBill(bill, id: recordId);

    batch.set(_historyCol(uid).doc(recordId), record.toJson());

    Bill? nextBill;
    if (bill.hasNextRecurrence) {
      nextBill = bill.advanceToNextRecurrence();
      batch.set(_billsCol(uid).doc(bill.id), nextBill.toJson());
    } else {
      batch.delete(_billsCol(uid).doc(bill.id));
    }

    await batch.commit();
    return nextBill;
  }

  /// Desfaz um pagamento do histórico: remove o registro de `payment_history`
  /// e restaura a conta na data/parcela exatamente anterior na lista ativa.
  Future<void> undoPayment(String uid, PaymentRecord record) async {
    final batch = _db.batch();
    batch.delete(_historyCol(uid).doc(record.id));
    batch.set(_billsCol(uid).doc(record.billId), record.toRestoredBill().toJson());
    await batch.commit();
  }

  Future<void> deletePaymentRecord(String uid, String recordId) async {
    await _historyCol(uid).doc(recordId).delete();
  }

  Stream<List<PaymentRecord>> paymentHistoryStream(String uid) {
    return _historyCol(uid)
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PaymentRecord.fromJson(doc.data()))
            .toList());
  }
}
