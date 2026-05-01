import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../core/constants/app_colors.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import 'scanner_page.dart';
import '../core/theme/app_theme.dart';

class AddStudentPage extends StatefulWidget {
  final StudentModel? student; // non-null = edit mode
  const AddStudentPage({super.key, this.student});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();

  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _classController = TextEditingController();
  final _courseController = TextEditingController();
  final _semesterController = TextEditingController();
  final _fatherController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _uidController = TextEditingController();

  String _base64Image = ''; // Store the base64 string
  final ImagePicker _picker = ImagePicker();

  String _gender = 'Male';
  DateTime _joiningDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.student!;
      _nameController.text = s.name;
      _rollController.text = s.roll;
      _classController.text = s.className;
      _courseController.text = s.course;
      _semesterController.text = s.semester;
      _fatherController.text = s.fatherName;
      _phoneController.text = s.phone;
      _emailController.text = s.email;
      _addressController.text = s.address;
      _uidController.text = s.uid;
      _base64Image = s.photoUrl;
      _gender = s.gender.isEmpty ? 'Male' : s.gender;
      _joiningDate = s.joiningDate;
      _validUntil = s.validUntil;
    } else {
      _fetchNextRollNo();
    }
  }

  Future<void> _fetchNextRollNo() async {
    setState(() => _isLoading = true);
    final nextRoll = await _service.generateNextRollNo();
    if (mounted) {
      setState(() {
        _rollController.text = nextRoll;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController, _rollController, _classController, _courseController,
      _semesterController, _fatherController, _phoneController,
      _emailController, _addressController, _uidController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isJoining) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isJoining ? _joiningDate : _validUntil,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: context.color.accent,
            onPrimary: Colors.white,
            surface: context.color.surface,
            onSurface: context.color.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isJoining ? _joiningDate = picked : _validUntil = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = _uidController.text.trim().toUpperCase();
      final uidExists = await _service.checkUidExists(
        uid,
        excludeId: _isEdit ? widget.student!.id : null,
      );
      if (uidExists && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This RFID UID is already assigned to another student.'),
          backgroundColor: AppColors.error,
        ));
        setState(() => _isLoading = false);
        return;
      }

      final student = StudentModel(
        id: _isEdit ? widget.student!.id : '',
        name: _nameController.text.trim(),
        roll: _rollController.text.trim(),
        className: _classController.text.trim(),
        course: _courseController.text.trim(),
        semester: _semesterController.text.trim(),
        fatherName: _fatherController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        uid: uid,
        photoUrl: _base64Image,
        gender: _gender,
        status: _isEdit ? widget.student!.status : 'Outside',
        joiningDate: _joiningDate,
        validUntil: _validUntil,
        totalFines: _isEdit ? widget.student!.totalFines : 0.0,
        booksBorrowed: _isEdit ? widget.student!.booksBorrowed : 0,
        isActive: _isEdit ? widget.student!.isActive : true,
      );

      if (_isEdit) {
        await _service.updateStudent(student);
      } else {
        await _service.addStudent(student);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Student updated!' : 'Student registered!'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, student);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Student' : 'New Library Member'),
        backgroundColor: context.color.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo preview
                    _buildPhotoSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('PERSONAL INFORMATION', Icons.person_outline),
                    _buildCard([
                      _buildInput(_nameController, 'Full Name', Icons.person),
                      _buildInput(_rollController, 'Roll Number', Icons.numbers, readOnly: true),
                      _buildInput(_fatherController, "Father's Name", Icons.family_restroom, required: false),
                      // Gender
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Icon(Icons.wc, color: context.color.textSecondary, size: 20),
                            const SizedBox(width: 16),
                            Text('Gender', style: TextStyle(color: context.color.textSecondary, fontSize: 14)),
                            const Spacer(),
                            _genderChip('Male'),
                            const SizedBox(width: 8),
                            _genderChip('Female'),
                            const SizedBox(width: 8),
                            _genderChip('Other'),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('ACADEMIC DETAILS', Icons.school_outlined),
                    _buildCard([
                      _buildInput(_classController, 'Class / Department', Icons.school),
                      _buildInput(_courseController, 'Course (e.g. B.Sc, B.Com)', Icons.menu_book, required: false),
                      _buildInput(_semesterController, 'Semester / Year', Icons.layers, isLast: true, required: false),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('CONTACT DETAILS', Icons.contact_mail_outlined),
                    _buildCard([
                      _buildInput(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                      _buildInput(_emailController, 'Email Address', Icons.email, keyboardType: TextInputType.emailAddress, isEmail: true, required: false),
                      _buildInput(_addressController, 'Home Address', Icons.home, isLast: true, maxLines: 2, required: false),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('LIBRARY ACCESS', Icons.local_library_outlined),
                    _buildCard([
                      _buildUidRow(),
                      _buildDateRow('Admission Date', _joiningDate, () => _pickDate(true)),
                      Divider(color: context.color.border),
                      _buildDateRow('Valid Until', _validUntil, () => _pickDate(false)),
                    ]),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: Icon(_isEdit ? Icons.save_outlined : Icons.check_circle_outline),
                        label: Text(
                          _isEdit ? 'SAVE CHANGES' : 'REGISTER STUDENT',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.accent,
                          foregroundColor: context.color.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceActionSheet,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.color.surface,
                border: Border.all(color: context.color.accent, width: 2),
              ),
              child: ClipOval(
                child: _base64Image.isNotEmpty
                    ? Image.memory(
                        base64Decode(_base64Image),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showImageSourceActionSheet,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Pick Image'),
            style: TextButton.styleFrom(foregroundColor: context.color.accent),
          ),
          if (_base64Image.isEmpty)
            Text(
              'No photo selected',
              style: TextStyle(color: context.color.textSecondary, fontSize: 11),
            )
          else
            TextButton(
              onPressed: () => setState(() => _base64Image = ''),
              child: const Text('Remove Photo', style: TextStyle(color: AppColors.error, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: context.color.accent),
              title: Text('Gallery / File Explorer', style: TextStyle(color: context.color.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndCompressImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: context.color.accent),
              title: Text('Camera', style: TextStyle(color: context.color.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndCompressImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCompressImage(ImageSource source) async {
    try {
      final XFile? imageRaw = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Initial hardware compression
      );
      
      if (imageRaw == null) return;
      
      setState(() => _isLoading = true);

      // Read file
      final bytes = await imageRaw.readAsBytes();
      
      // Decode image
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw Exception('Could not decode image');

      // Resize image to a better size (600px max)
      final resizedImage = img.copyResize(decodedImage, width: 600);

      // Encode back to JPG with better quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

      // Convert to Base64
      final base64String = base64Encode(compressedBytes);

      // Firestore document max limit is 1MB. A heavily compressed 200x200 JPEG base64
      // string will typically be around 10KB to 30KB, which is perfectly safe.
      setState(() {
        _base64Image = base64String;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _avatarFallback() {
    final name = _nameController.text;
    return Container(
      color: context.color.background,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: context.color.accent, fontSize: 36, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _genderChip(String label) {
    final selected = _gender == label;
    return GestureDetector(
      onTap: () => setState(() => _gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.color.accent.withValues(alpha: 0.15) : context.color.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? context.color.accent : context.color.border),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? context.color.accent : context.color.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.color.accent),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: context.color.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDateRow(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: context.color.textSecondary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: context.color.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd MMM yyyy').format(date),
                      style: TextStyle(color: context.color.textPrimary, fontSize: 16)),
                ],
              ),
            ),
            Icon(Icons.edit, color: context.color.accent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isLast = false,
    int maxLines = 1,
    bool isEmail = false,
    bool required = true,
    bool readOnly = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? context.color.textSecondary : context.color.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.color.textSecondary),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 16.0 : 0),
            child: Icon(icon, color: context.color.textSecondary, size: 20),
          ),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.color.border)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.color.accent)),
          errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.error)),
          focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.error)),
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return '$label is required';
          if (isEmail && v != null && v.isNotEmpty && !v.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
    );
  }

  Widget _buildUidRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildInput(_uidController, 'RFID UID (Scan Card)', Icons.nfc, isLast: true),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.nfc, size: 18),
            label: const Text('SCAN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.accent.withValues(alpha: 0.1),
              foregroundColor: context.color.accent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.color.accent.withValues(alpha: 0.3)),
              )
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    final String? scannedUid = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    
    if (scannedUid != null && scannedUid.isNotEmpty && mounted) {
      setState(() {
        _uidController.text = scannedUid;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Card scanned successfully!'),
        backgroundColor: AppColors.success,
      ));
    }
  }
}
