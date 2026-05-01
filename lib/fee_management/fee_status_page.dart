import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';

class FeeStatusPage extends StatefulWidget {
  const FeeStatusPage({super.key});

  @override
  State<FeeStatusPage> createState() => _FeeStatusPageState();
}

class _FeeStatusPageState extends State<FeeStatusPage>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late TabController _tabController;

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  final _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.background,
      appBar: AppBar(
        title: const Text('Fee Status'),
        backgroundColor: context.color.background,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.color.accent,
          labelColor: context.color.accent,
          unselectedLabelColor: context.color.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline), text: 'PAID'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'UNPAID'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month / Year selector
          Container(
            color: context.color.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: context.color.accent, size: 18),
                const SizedBox(width: 10),
                Text('Period:', style: TextStyle(color: context.color.textSecondary, fontSize: 13)),
                const SizedBox(width: 12),
                _periodDropdown<int>(
                  value: _month,
                  items: List.generate(12, (i) => i + 1),
                  label: (m) => _months[m - 1],
                  onChanged: (v) => setState(() => _month = v!),
                ),
                const SizedBox(width: 10),
                _periodDropdown<int>(
                  value: _year,
                  items: [2024, 2025, 2026, 2027],
                  label: (y) => y.toString(),
                  onChanged: (v) => setState(() => _year = v!),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentModel>>(
              stream: _service.getStudents(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final students = snap.data ?? [];

                return FutureBuilder<Set<String>>(
                  future: _service.getPaidStudentIds(_month, _year),
                  builder: (context, feeSnap) {
                    if (feeSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final paidIds = feeSnap.data ?? {};
                    final paid = students.where((s) => paidIds.contains(s.id)).toList();
                    final unpaid = students.where((s) => !paidIds.contains(s.id)).toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(paid, isPaid: true),
                        _buildList(unpaid, isPaid: false),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<StudentModel> students, {required bool isPaid}) {
    final color = isPaid ? AppColors.success : AppColors.error;
    final icon = isPaid ? Icons.check_circle_rounded : Icons.cancel_rounded;

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              isPaid ? 'No paid students for this period.' : 'All students have paid!',
              style: TextStyle(color: context.color.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                '${students.length} student${students.length == 1 ? '' : 's'} — ${_months[_month - 1]} $_year',
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: students.length,
            itemBuilder: (_, i) => _buildStudentRow(students[i], isPaid: isPaid),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRow(StudentModel s, {required bool isPaid}) {
    final color = isPaid ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: TextStyle(
                        color: context.color.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text('${s.roll}  •  ${s.className}',
                    style: TextStyle(
                        color: context.color.textSecondary, fontSize: 12)),
                if (s.course.isNotEmpty)
                  Text(s.course,
                      style: TextStyle(
                          color: context.color.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yy').format(s.validUntil),
                style: TextStyle(color: context.color.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
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

  Widget _periodDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.color.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.color.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: context.color.surface,
          isDense: true,
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(label(i),
                        style: TextStyle(color: context.color.textPrimary, fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
