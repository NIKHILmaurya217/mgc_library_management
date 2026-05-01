import 'package:cloud_firestore/cloud_firestore.dart';

class FeeModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final int month; // 1-12
  final int year;
  final double amount;
  final String status; // PAID, PARTIAL, PENDING
  final DateTime paidOn;
  final String note;

  FeeModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.month,
    required this.year,
    required this.amount,
    required this.status,
    required this.paidOn,
    this.note = '',
  });

  factory FeeModel.fromMap(Map<String, dynamic> data, String docId) {
    return FeeModel(
      id: docId,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentRoll: data['studentRoll'] ?? '',
      month: (data['month'] != null && data['month'] >= 1 && data['month'] <= 12) ? data['month'] : 1,
      year: data['year'] ?? DateTime.now().year,
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'PENDING',
      paidOn: (data['paidOn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'studentRoll': studentRoll,
        'month': month,
        'year': year,
        'amount': amount,
        'status': status,
        'paidOn': Timestamp.fromDate(paidOn),
        'note': note,
      };

  String get monthLabel {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    int safeMonth = (month >= 1 && month <= 12) ? month : 1;
    return '${months[safeMonth - 1]} $year';
  }
}
