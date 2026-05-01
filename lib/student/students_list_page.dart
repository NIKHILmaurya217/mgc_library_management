import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import 'add_student_page.dart';
import 'student_detail_page.dart';
import '../core/theme/app_theme.dart';

class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  final _service = FirestoreService();
  String _search = '';
  String _filter = 'All'; // All, Active, Expired, Inside, Inactive

  final _filters = ['All', 'Active', 'Expired', 'Inside', 'Inactive', 'Debarred'];

  List<StudentModel> _applyFilter(List<StudentModel> list) {
    final now = DateTime.now();
    return list.where((s) {
      final matchSearch = s.name.toLowerCase().contains(_search) ||
          s.roll.toLowerCase().contains(_search) ||
          s.className.toLowerCase().contains(_search) ||
          s.course.toLowerCase().contains(_search);
      if (!matchSearch) return false;
      switch (_filter) {
        case 'Active':
          return s.isActive && s.validUntil.isAfter(now);
        case 'Expired':
          return s.validUntil.isBefore(now);
        case 'Inside':
          return s.status == 'Inside';
        case 'Inactive':
          return !s.isActive;
        case 'Debarred':
          return s.isDebarred;
        default:
          return true;
      }
    }).toList();
  }

  void _openDetail(StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: StudentDetailPage(student: student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.background,
      appBar: AppBar(
        title: const Text('All Students'),
        backgroundColor: context.color.background,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: context.color.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddStudentPage()),
            ),
            tooltip: 'Add Student',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name, roll, class, course...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.color.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.color.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.color.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.color.accent),
                ),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? context.color.accent.withValues(alpha: 0.15) : context.color.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? context.color.accent : context.color.border,
                      ),
                    ),
                    child: Text(f,
                        style: TextStyle(
                          color: selected ? context.color.accent : context.color.textSecondary,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              },
            ),
          ),
          // List
          Expanded(
            child: StreamBuilder<List<StudentModel>>(
              stream: _service.getStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? [];
                final list = _applyFilter(all);

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 56, color: context.color.border),
                        const SizedBox(height: 12),
                        Text(
                          all.isEmpty ? 'No students registered yet.' : 'No students match the filter.',
                          style: TextStyle(color: context.color.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _buildTile(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(StudentModel s) {
    final isInside = s.status == 'Inside';
    final isExpired = s.validUntil.isBefore(DateTime.now());
    final statusColor = isInside ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.border),
      ),
      child: ListTile(
        onTap: () => _openDetail(s),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 2),
          ),
          child: ClipOval(
            child: s.photoUrl.isNotEmpty
                ? () {
                    try {
                      return Image.memory(
                        base64Decode(s.photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => _avatar(s),
                      );
                    } catch (_) {
                      return _avatar(s);
                    }
                  }()
                : _avatar(s),
          ),
        ),
        title: Text(s.name,
            style: TextStyle(
                color: context.color.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.roll}  •  ${s.className}',
                style: TextStyle(color: context.color.textSecondary, fontSize: 12)),
            if (s.course.isNotEmpty)
              Text(s.course,
                  style: TextStyle(color: context.color.textSecondary, fontSize: 11)),
          ],
        ),
        isThreeLine: s.course.isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (s.isDebarred)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Text('DEBARRED',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            const SizedBox(height: 4),
            if (isExpired)
              const Text('EXPIRED',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.bold))
            else
              Text(
                DateFormat('dd MMM yy').format(s.validUntil),
                style: TextStyle(color: context.color.textSecondary, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(StudentModel s) {
    return Container(
      color: context.color.background,
      child: Center(
        child: Text(
          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: context.color.accent, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }
}
