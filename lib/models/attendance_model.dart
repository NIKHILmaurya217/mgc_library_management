import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final String uid;
  final String action; // Entry or Exit
  final DateTime timestamp;
  final String duration; // only on Exit

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.uid,
    required this.action,
    required this.timestamp,
    this.duration = '',
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> data, String docId) {
    return AttendanceModel(
      id: docId,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentRoll: data['studentRoll'] ?? '',
      uid: data['uid'] ?? '',
      action: data['action'] ?? 'Entry',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: data['duration'] ?? '',
    );
  }
}
