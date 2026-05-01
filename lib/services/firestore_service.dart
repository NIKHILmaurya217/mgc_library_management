import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _studentsRef => _db.collection('students');
  CollectionReference get _feesRef => _db.collection('fees');
  CollectionReference get _attendanceRef => _db.collection('attendance');

  // ── STUDENTS ──────────────────────────────────────────────
  Stream<List<StudentModel>> getStudents() {
    return _studentsRef.orderBy('name').snapshots().map((s) => s.docs
        .map((d) => StudentModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  Future<StudentModel?> getStudent(String id) async {
    final doc = await _studentsRef.doc(id).get();
    if (doc.exists) return StudentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    return null;
  }

  Future<void> addStudent(StudentModel student) async {
    await _studentsRef.doc().set(student.toMap());
  }

  Future<void> updateStudent(StudentModel student) async {
    await _studentsRef.doc(student.id).update(student.toMap());
  }

  Future<void> deleteStudent(String id) async {
    await _studentsRef.doc(id).delete();
  }

  Future<String> generateNextRollNo() async {
    try {
      final snap = await _studentsRef.get();
      if (snap.docs.isEmpty) return '1';
      
      int maxRoll = 0;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final rollStr = data['roll']?.toString() ?? '0';
          final rollMatch = RegExp(r'\d+').firstMatch(rollStr);
          final rollInt = rollMatch != null ? int.parse(rollMatch.group(0)!) : 0;
          if (rollInt > maxRoll) maxRoll = rollInt;
        }
      }
      return (maxRoll + 1).toString();
    } catch (e) {
      return '1';
    }
  }

  Future<void> toggleDebarred(String id, bool debar) async {
    await _studentsRef.doc(id).update({'isDebarred': debar});
  }

  Future<bool> checkUidExists(String uid, {String? excludeId}) async {
    final query = await _studentsRef.where('uid', isEqualTo: uid).get();
    if (excludeId != null) {
      return query.docs.any((d) => d.id != excludeId);
    }
    return query.docs.isNotEmpty;
  }

  // ── FEES ──────────────────────────────────────────────────
  Stream<List<FeeModel>> getFees() {
    return _feesRef
        .orderBy('paidOn', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FeeModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<FeeModel>> getFeesForStudent(String studentId) {
    return _feesRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => FeeModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) {
            int cmp = b.year.compareTo(a.year);
            if (cmp == 0) cmp = b.month.compareTo(a.month);
            return cmp;
          });
          return list;
        });
  }

  Future<void> addFee(FeeModel fee) async {
    await _feesRef.doc().set(fee.toMap());
  }

  Future<void> deleteFee(String id) async {
    await _feesRef.doc(id).delete();
  }

  /// Returns studentIds that have a PAID/PARTIAL fee for the given month+year
  Future<Set<String>> getPaidStudentIds(int month, int year) async {
    final snap = await _feesRef
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .where('status', whereIn: ['PAID', 'PARTIAL'])
        .get();
    return snap.docs.map((d) => (d.data() as Map)['studentId'] as String).toSet();
  }

  Future<List<FeeModel>> getAllFees() async {
    final snap = await _feesRef.get();
    return snap.docs
        .map((d) => FeeModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ── ATTENDANCE ────────────────────────────────────────────
  Stream<List<AttendanceModel>> getAttendanceLogs({int limit = 50}) {
    return _attendanceRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AttendanceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<AttendanceModel>> getAttendanceForStudent(String studentId, {int limit = 30}) {
    return _attendanceRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => AttendanceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (list.length > limit) {
             return list.sublist(0, limit);
          }
          return list;
        });
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    final snap = await _attendanceRef.get();
    return snap.docs
        .map((d) => AttendanceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ── DEVICE ────────────────────────────────────────────────
  Stream<Map<String, dynamic>?> streamDeviceStatus() {
    return _db.collection('devices').doc('esp32_main').snapshots().map((s) {
      if (s.exists) return s.data() as Map<String, dynamic>;
      return null;
    });
  }

  Future<void> sendDeviceCommand(Map<String, dynamic> commands) async {
    await _db.collection('devices').doc('esp32_main').set(
      commands,
      SetOptions(merge: true),
    );
  }
}
