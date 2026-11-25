import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

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
    await _userDoc(uid).collection('bills').doc(bill.id).set(bill.toJson());
  }

  Future<void> addBills(String uid, List<Bill> bills) async {
    if (bills.isEmpty) return;
    final batch = _db.batch();
    final col = _userDoc(uid).collection('bills');
    for (final bill in bills) {
      batch.set(col.doc(bill.id), bill.toJson());
    }
    await batch.commit();
  }

  Future<void> updateBill(String uid, Bill bill) async {
    await _userDoc(uid).collection('bills').doc(bill.id).update(bill.toJson());
  }

  Future<void> updateBills(String uid, List<Bill> bills) async {
    if (bills.isEmpty) return;
    final batch = _db.batch();
    final col = _userDoc(uid).collection('bills');
    for (final bill in bills) {
      batch.set(col.doc(bill.id), bill.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> toggleBillStatus(String uid, String billId, bool isPaid) async {
    await _userDoc(uid)
        .collection('bills')
        .doc(billId)
        .update({'isPaid': isPaid});
  }

  Future<void> deleteBill(String uid, String billId) async {
    await _userDoc(uid).collection('bills').doc(billId).delete();
  }

  Future<void> deleteBills(String uid, List<String> billIds) async {
    if (billIds.isEmpty) return;
    final batch = _db.batch();
    final col = _userDoc(uid).collection('bills');
    for (final id in billIds) {
      batch.delete(col.doc(id));
    }
    await batch.commit();
  }

  Stream<List<Bill>> billsStream(String uid) {
    return _userDoc(uid)
        .collection('bills')
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Bill.fromJson(doc.data()))
            .toList());
  }
}
