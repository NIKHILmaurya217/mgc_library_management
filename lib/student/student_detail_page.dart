import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import 'edit_student_page.dart';
import '../core/theme/app_theme.dart';

class StudentDetailPage extends StatefulWidget {
  final StudentModel student;
  const StudentDetailPage({super.key, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late TabController _tabController;
  late StudentModel _student;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<StudentModel>(
      context,
      MaterialPageRoute(builder: (_) => EditStudentPage(student: _student)),
    );
    if (updated != null && mounted) {
      setState(() => _student = updated);
    }
  }

  Future<void> _toggleDebar() async {
    final isDebar = !_student.isDebarred;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.color.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.color.border)),
        title: Text(isDebar ? 'Debar Student?' : 'Remove Debarment?',
            style: TextStyle(color: context.color.textPrimary)),
        content: Text(
          isDebar
              ? 'This will mark ${_student.name} as debarred. They will be blocked from library access.'
              : 'This will restore ${_student.name}\'s library access.',
          style: TextStyle(color: context.color.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.color.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: isDebar ? AppColors.warning : AppColors.success),
              child: Text(isDebar ? 'Debar' : 'Restore')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _service.toggleDebarred(_student.id, isDebar);
      setState(() => _student = _student.copyWith(isDebarred: isDebar));
    }
  }

  Future<void> _deleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.color.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.color.border)),
        title: Text('Delete Student?',
            style: TextStyle(color: context.color.textPrimary)),
        content: Text(
            'This will permanently remove the student and all their records from the system.',
            style: TextStyle(color: context.color.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.color.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pop(context);
      await _service.deleteStudent(_student.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: context.color.background.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: context.color.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: context.color.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              // ID Card header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildIdCard(),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEdit,
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('EDIT',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.color.accent,
                          side: BorderSide(color: context.color.accent.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleDebar,
                        icon: Icon(
                          _student.isDebarred ? Icons.lock_open_rounded : Icons.block_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _student.isDebarred ? 'RESTORE' : 'DEBAR',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                          foregroundColor: AppColors.warning,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _deleteStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.15),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: context.color.accent,
                labelColor: context.color.accent,
                unselectedLabelColor: context.color.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
                tabs: const [
                  Tab(text: 'DETAILS'),
                  Tab(text: 'FEES'),
                  Tab(text: 'ATTENDANCE'),
                ],
              ),
              Divider(height: 1, color: context.color.border),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(),
                    _buildFeesTab(),
                    _buildAttendanceTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdCard() {
    final isInside = _student.status == 'Inside';
    final isDebarred = _student.isDebarred;
    final statusColor = isDebarred
        ? AppColors.warning
        : isInside
            ? AppColors.success
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDebarred
              ? AppColors.warning.withValues(alpha: 0.5)
              : context.color.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          if (isDebarred)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded, color: AppColors.warning, size: 14),
                  SizedBox(width: 6),
                  Text('DEBARRED — Library Access Blocked',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.2)],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: context.color.surface),
                  child: GestureDetector(
                    onTap: _student.photoUrl.isNotEmpty
                        ? () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InteractiveViewer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.memory(
                                          base64Decode(_student.photoUrl),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.cancel, color: Colors.white, size: 32),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        : null,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: context.color.background,
                      backgroundImage: _student.photoUrl.isNotEmpty
                          ? MemoryImage(base64Decode(_student.photoUrl))
                          : null,
                      child: _student.photoUrl.isEmpty
                          ? Text(
                              _student.name.isNotEmpty
                                  ? _student.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_student.name,
                        style: TextStyle(
                            color: context.color.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_student.className.toUpperCase(),
                        style: TextStyle(
                            color: context.color.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDebarred
                              ? 'Debarred'
                              : isInside
                                  ? 'Inside Library'
                                  : 'Outside',
                          style: TextStyle(color: statusColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.nfc, color: context.color.accent, size: 20),
                  const SizedBox(height: 4),
                  Text(_student.uid,
                      style: TextStyle(
                          color: context.color.textSecondary,
                          fontSize: 10,
                          fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    final isExpired = _student.validUntil.isBefore(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoGrid([
            _infoItem('ROLL NO', _student.roll, Icons.numbers),
            _infoItem('CLASS', _student.className, Icons.school),
          ]),
          const SizedBox(height: 16),
          _buildInfoGrid([
            _infoItem('PHONE', _student.phone, Icons.phone),
            _infoItem('EMAIL', _student.email, Icons.email),
          ]),
          const SizedBox(height: 16),
          _buildInfoGrid([
            _infoItem('JOINING DATE',
                DateFormat('dd MMM yyyy').format(_student.joiningDate),
                Icons.calendar_today),
            _infoItem(
              'VALID UNTIL',
              DateFormat('dd MMM yyyy').format(_student.validUntil),
              Icons.event_available,
              valueColor: isExpired ? AppColors.error : AppColors.success,
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.color.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.color.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('HOME ADDRESS', Icons.home),
                const SizedBox(height: 8),
                Text(_student.address.isNotEmpty ? _student.address : '—',
                    style: TextStyle(
                        color: context.color.textPrimary, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatChip('Books Borrowed',
                    _student.booksBorrowed.toString(), AppColors.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip('Total Fines',
                    '₹${_student.totalFines.toStringAsFixed(0)}',
                    _student.totalFines > 0 ? AppColors.error : AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatChip('Attendance Status',
                    _student.status == 'Inside' ? 'Inside' : 'Outside',
                    _student.status == 'Inside' ? AppColors.success : AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTab() {
    return StreamBuilder<List<FeeModel>>(
      stream: _service.getFeesForStudent(_student.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppColors.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final fees = snapshot.data ?? [];
        if (fees.isEmpty) {
          return Center(
            child: Text('No fee records found.',
                style: TextStyle(color: context.color.textSecondary)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: fees.length,
          itemBuilder: (context, i) {
            final fee = fees[i];
            final statusColor = fee.status == 'PAID'
                ? AppColors.success
                : fee.status == 'PARTIAL'
                    ? AppColors.warning
                    : AppColors.error;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.color.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.color.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fee.monthLabel,
                            style: TextStyle(
                                color: context.color.textPrimary,
                                fontWeight: FontWeight.w600)),
                        if (fee.note.isNotEmpty)
                          Text(fee.note,
                              style: TextStyle(
                                  color: context.color.textSecondary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic)),
                        Text(
                            DateFormat('dd MMM yyyy').format(fee.paidOn),
                            style: TextStyle(
                                color: context.color.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${fee.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(fee.status,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _service.getAttendanceForStudent(_student.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppColors.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc, size: 48, color: context.color.border),
                const SizedBox(height: 12),
                Text('No RFID scans recorded yet.',
                    style: TextStyle(color: context.color.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final log = logs[i];
            final isEntry = log.action == 'Entry';
            final color = isEntry ? AppColors.success : AppColors.error;
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEntry ? Icons.login_rounded : Icons.logout_rounded,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(log.timestamp),
                          style: TextStyle(
                              color: context.color.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        if (log.duration.isNotEmpty)
                          Text('Duration: ${log.duration}',
                              style: TextStyle(
                                  color: context.color.textSecondary,
                                  fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(log.action.toUpperCase(),
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm:ss').format(log.timestamp),
                        style: TextStyle(
                            color: context.color.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoGrid(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.border),
      ),
      child: Row(
        children: items
            .asMap()
            .entries
            .map((e) => Expanded(
                  child: Row(
                    children: [
                      Expanded(child: e.value),
                      if (e.key < items.length - 1)
                        Container(
                            width: 1, height: 40, color: context.color.border),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: context.color.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: context.color.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value.isNotEmpty ? value : '—',
              style: TextStyle(
                  color: valueColor ?? context.color.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: context.color.textSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: context.color.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.color.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
