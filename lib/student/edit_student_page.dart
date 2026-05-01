import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../core/constants/app_colors.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';

class EditStudentPage extends StatefulWidget {
  final StudentModel student;
  const EditStudentPage({super.key, required this.student});

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  late final TextEditingController _nameController;
  late final TextEditingController _rollController;
  late final TextEditingController _classController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _uidController;

  late DateTime _joiningDate;
  late DateTime _validUntil;
  bool _isLoading = false;

  String _base64Image = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s.name);
    _rollController = TextEditingController(text: s.roll);
    _classController = TextEditingController(text: s.className);
    _phoneController = TextEditingController(text: s.phone);
    _emailController = TextEditingController(text: s.email);
    _addressController = TextEditingController(text: s.address);
    _uidController = TextEditingController(text: s.uid);
    _joiningDate = s.joiningDate;
    _validUntil = s.validUntil;
    _base64Image = s.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _classController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isJoining) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isJoining ? _joiningDate : _validUntil,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
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
      setState(() {
        if (isJoining) {
          _joiningDate = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Check UID uniqueness (excluding current student)
      final newUid = _uidController.text.trim().toUpperCase();
      if (newUid != widget.student.uid) {
        final exists = await _firestoreService.checkUidExists(newUid, excludeId: widget.student.id);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This RFID UID is already assigned to another student.'), backgroundColor: AppColors.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final updated = widget.student.copyWith(
        name: _nameController.text.trim(),
        roll: _rollController.text.trim(),
        className: _classController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        uid: newUid,
        joiningDate: _joiningDate,
        validUntil: _validUntil,
        photoUrl: _base64Image,
      );

      await _firestoreService.updateStudent(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student updated successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, updated);
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
      appBar: AppBar(title: const Text('Edit Student')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoSection(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('PERSONAL INFORMATION', Icons.person_outline),
                    _buildCard([
                      _buildInput(_nameController, 'Full Name', Icons.person),
                      _buildInput(_rollController, 'Roll Number', Icons.numbers),
                      _buildInput(_classController, 'Class/Course', Icons.school, isLast: true),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('CONTACT DETAILS', Icons.contact_mail_outlined),
                    _buildCard([
                      _buildInput(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                      _buildInput(_emailController, 'Email Address', Icons.email, keyboardType: TextInputType.emailAddress, isEmail: true),
                      _buildInput(_addressController, 'Home Address', Icons.home, isLast: true, maxLines: 2),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('LIBRARY ACCESS', Icons.local_library_outlined),
                    _buildCard([
                      _buildInput(_uidController, 'RFID UID', Icons.nfc),
                      _buildDateSelector('Joining Date', _joiningDate, () => _selectDate(true)),
                      Divider(color: context.color.border),
                      _buildDateSelector('Valid Until', _validUntil, () => _selectDate(false)),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('SAVE CHANGES',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.accent,
                          foregroundColor: context.color.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
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

  Widget _buildDateSelector(String label, DateTime date, VoidCallback onTap) {
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
                  Text(label,
                      style: TextStyle(color: context.color.textSecondary, fontSize: 12)),
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
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: context.color.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.color.textSecondary),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 16.0 : 0),
            child: Icon(icon, color: context.color.textSecondary, size: 20),
          ),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.color.border)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.color.accent)),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return '$label is required';
          if (isEmail && !value.contains('@')) return 'Enter a valid email';
          return null;
        },
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
            label: const Text('Update Photo'),
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
        imageQuality: 85,
      );
      
      if (imageRaw == null) return;
      
      setState(() => _isLoading = true);

      final bytes = await imageRaw.readAsBytes();
      
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw Exception('Could not decode image');

      final resizedImage = img.copyResize(decodedImage, width: 600);
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      final base64String = base64Encode(compressedBytes);

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
}
