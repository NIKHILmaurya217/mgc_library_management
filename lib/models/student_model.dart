import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String roll;
  final String className;
  final String phone;
  final String email;
  final String address;
  final String uid; // RFID UID
  final String status; // Inside or Outside
  final DateTime joiningDate;
  final DateTime validUntil;
  final double totalFines;
  final int booksBorrowed;
  final bool isActive;
  final String photoUrl;
  final String gender;
  final String fatherName;
  final String course;
  final String semester;
  final bool isDebarred;

  StudentModel({
    required this.id,
    required this.name,
    required this.roll,
    required this.className,
    required this.phone,
    required this.email,
    required this.address,
    required this.uid,
    required this.status,
    required this.joiningDate,
    required this.validUntil,
    required this.totalFines,
    required this.booksBorrowed,
    required this.isActive,
    this.photoUrl = '',
    this.gender = '',
    this.fatherName = '',
    this.course = '',
    this.semester = '',
    this.isDebarred = false,
  });

  factory StudentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return StudentModel(
      id: documentId,
      name: data['name'] ?? '',
      roll: data['roll'] ?? '',
      className: data['class'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      uid: data['uid'] ?? '',
      status: data['status'] ?? 'Outside',
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validUntil: (data['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 365)),
      totalFines: (data['totalFines'] ?? 0.0).toDouble(),
      booksBorrowed: data['booksBorrowed'] ?? 0,
      isActive: data['isActive'] ?? true,
      photoUrl: data['photoUrl'] ?? '',
      gender: data['gender'] ?? '',
      fatherName: data['fatherName'] ?? '',
      course: data['course'] ?? '',
      semester: data['semester'] ?? '',
      isDebarred: data['isDebarred'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'roll': roll,
      'class': className,
      'phone': phone,
      'email': email,
      'address': address,
      'uid': uid,
      'status': status,
      'joiningDate': Timestamp.fromDate(joiningDate),
      'validUntil': Timestamp.fromDate(validUntil),
      'totalFines': totalFines,
      'booksBorrowed': booksBorrowed,
      'isActive': isActive,
      'photoUrl': photoUrl,
      'gender': gender,
      'fatherName': fatherName,
      'course': course,
      'semester': semester,
      'isDebarred': isDebarred,
    };
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? roll,
    String? className,
    String? phone,
    String? email,
    String? address,
    String? uid,
    String? status,
    DateTime? joiningDate,
    DateTime? validUntil,
    double? totalFines,
    int? booksBorrowed,
    bool? isActive,
    String? photoUrl,
    String? gender,
    String? fatherName,
    String? course,
    String? semester,
    bool? isDebarred,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      roll: roll ?? this.roll,
      className: className ?? this.className,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      uid: uid ?? this.uid,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      validUntil: validUntil ?? this.validUntil,
      totalFines: totalFines ?? this.totalFines,
      booksBorrowed: booksBorrowed ?? this.booksBorrowed,
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      fatherName: fatherName ?? this.fatherName,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      isDebarred: isDebarred ?? this.isDebarred,
    );
  }
}
