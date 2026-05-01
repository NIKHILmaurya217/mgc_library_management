import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'student/student_detail_page.dart';
import 'student/add_student_page.dart';
import 'student/students_list_page.dart';
import 'fee_management/fee_management_page.dart';
import 'fee_management/fee_status_page.dart';
import 'system/system_page.dart';
import 'attendance/attendance_page.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'widgets/stat_card.dart';
import 'services/firestore_service.dart';
import 'models/student_model.dart';
import 'models/attendance_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final ValueNotifier<String> _timeNotifier = ValueNotifier('');
  Timer? _timer;
  String _dashSearchQuery = '';
  String _studentSearchQuery = '';
  final FirestoreService _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeNotifier.dispose();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    _timeNotifier.value =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  void _showStudentDetail(StudentModel student) {
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
      appBar: _buildAppBar(),
      body: _buildCurrentPage(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStudentPage()),
              ),
              backgroundColor: context.color.accent,
              child: Icon(Icons.person_add_alt_1_rounded,
                  color: context.color.background),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeeStatusPage()),
                  ),
                  backgroundColor: context.color.accent,
                  foregroundColor: context.color.background,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Fee Status', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: context.color.surface, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('LIBRARY RFID',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              Text('Management System',
                  style: TextStyle(fontSize: 10, color: context.color.textSecondary)),
            ],
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<String>(
          valueListenable: _timeNotifier,
          builder: (context, timeValue, child) {
            return Text(timeValue,
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: context.color.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13));
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            context.watch<ThemeProvider>().isDarkMode 
              ? Icons.light_mode_rounded 
              : Icons.dark_mode_rounded,
            size: 20
          ),
          color: context.color.textSecondary,
          onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          tooltip: 'Toggle Theme',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 20),
          color: context.color.textSecondary,
          onPressed: () => FirebaseAuth.instance.signOut(),
          tooltip: 'Sign Out',
        ),
      ],
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildStudentsTab();
      case 2:
        return const FeeManagementPage();
      case 3:
        return const AttendancePage();
      case 4:
        return const SystemPage();
      default:
        return _buildDashboard();
    }
  }

  // ── DASHBOARD ──────────────────────────────────────────────
  Widget _buildDashboard() {
    return StreamBuilder<List<StudentModel>>(
      stream: _service.getStudents(),
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];
        final total = students.length;
        final inside = students.where((s) => s.status == 'Inside').length;
        final expired = students
            .where((s) => s.validUntil.isBefore(DateTime.now()))
            .length;
        final active = students.where((s) => s.isActive).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search
              TextField(
                onChanged: (v) =>
                    setState(() => _dashSearchQuery = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search students...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),

              // Stats grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                      label: 'Total Members',
                      value: total.toString(),
                      icon: Icons.people_rounded,
                      color: context.color.accent),
                  StatCard(
                      label: 'Inside Now',
                      value: inside.toString(),
                      icon: Icons.sensor_door_rounded,
                      color: const Color(0xFF10B981)), // Success Green (Keep unchanged for status)
                  StatCard(
                      label: 'Active',
                      value: active.toString(),
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFF7C3AED)), // Info Purple
                  StatCard(
                      label: 'Expired',
                      value: expired.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B)), // Warning Orange
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionLabel('LIVE RFID ACTIVITY', Icons.nfc),
              const SizedBox(height: 12),
              _buildLiveActivity(),

              const SizedBox(height: 24),
              _buildSectionLabel('RECENT MEMBERS', Icons.people_outline),
              const SizedBox(height: 12),
              _buildStudentList(limit: 5),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentsListPage()),
                  ),
                  icon: const Icon(Icons.people_rounded, size: 16),
                  label: const Text('View All Students'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.color.accent,
                    side: BorderSide(color: context.color.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveActivity() {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _service.getAttendanceLogs(limit: 8),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.color.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.color.border),
            ),
            child: Row(
              children: [
                Icon(Icons.nfc, color: context.color.border, size: 20),
                const SizedBox(width: 12),
                Text('Waiting for RFID scans...',
                    style: TextStyle(color: context.color.textSecondary)),
              ],
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: context.color.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.color.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: context.color.border),
            itemBuilder: (_, i) => _buildActivityRow(logs[i]),
          ),
        );
      },
    );
  }

  Widget _buildActivityRow(AttendanceModel log) {
    final isEntry = log.action == 'Entry';
    final color = isEntry ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final now = DateTime.now();
    final isToday = log.timestamp.day == now.day &&
        log.timestamp.month == now.month &&
        log.timestamp.year == now.year;

    return ListTile(
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isEntry ? Icons.login_rounded : Icons.logout_rounded,
          color: color,
          size: 16,
        ),
      ),
      title: Text(log.studentName,
          style: TextStyle(
              color: context.color.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      subtitle: Text('Roll: ${log.studentRoll}',
          style: TextStyle(
              color: context.color.textSecondary, fontSize: 11)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isToday
                ? DateFormat('HH:mm:ss').format(log.timestamp)
                : DateFormat('dd MMM').format(log.timestamp),
            style: TextStyle(
                color: context.color.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Text(log.action,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── STUDENTS TAB ───────────────────────────────────────────
  Widget _buildStudentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _studentSearchQuery = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search by name or roll...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(child: _buildStudentList()),
      ],
    );
  }

  Widget _buildStudentList({int? limit}) {
    return StreamBuilder<List<StudentModel>>(
      stream: _service.getStudents(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFEF4444))));
        }

        var list = (snapshot.data ?? []).where((s) {
          final q = _selectedIndex == 0 ? _dashSearchQuery : _studentSearchQuery;
          return s.name.toLowerCase().contains(q) ||
              s.roll.toLowerCase().contains(q);
        }).toList();

        if (limit != null && list.length > limit) {
          list = list.sublist(0, limit);
        }

        if (list.isEmpty) {
          return Center(
            child: Text('No students found.',
                style: TextStyle(color: context.color.textSecondary)),
          );
        }

        return ListView.builder(
          shrinkWrap: limit != null,
          physics: limit != null ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: list.length,
          itemBuilder: (_, i) => _buildStudentTile(list[i]),
        );
      },
    );
  }

  Widget _buildStudentTile(StudentModel student) {
    final isInside = student.status == 'Inside';
    final isExpired = student.validUntil.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.border),
      ),
      child: ListTile(
        onTap: () => _showStudentDetail(student),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isInside ? const Color(0xFF10B981) : context.color.border,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: student.photoUrl.isNotEmpty
                ? () {
                    try {
                      return Image.memory(
                        base64Decode(student.photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => _avatar(student),
                      );
                    } catch (_) {
                      return _avatar(student);
                    }
                  }()
                : _avatar(student),
          ),
        ),
        title: Text(student.name,
            style: TextStyle(
                color: context.color.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        subtitle: Text('${student.roll}  •  ${student.className}',
            style: TextStyle(
                color: context.color.textSecondary, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isInside ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            if (isExpired)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('EXPIRED',
                    style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.color.accent),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: context.color.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: context.color.border)),
      ],
    );
  }

  Widget _avatar(StudentModel student) {
    return Container(
      color: context.color.background,
      child: Center(
        child: Text(
          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: context.color.accent, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded), label: 'Students'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded), label: 'Fees'),
        BottomNavigationBarItem(
            icon: Icon(Icons.nfc_rounded), label: 'Attendance'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded), label: 'System'),
      ],
    );
  }
}
