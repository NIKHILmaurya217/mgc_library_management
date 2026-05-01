import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirestoreService _service = FirestoreService();
  String _filterAction = 'All';
  String _searchQuery = '';
  String _filterDate = 'Today'; // Today, Week, All

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<List<AttendanceModel>>(
            stream: _service.getAttendanceLogs(limit: 100),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                );
              }

              var logs = snapshot.data ?? [];

              // Date filter
              final now = DateTime.now();
              if (_filterDate == 'Today') {
                logs = logs.where((l) =>
                    l.timestamp.day == now.day &&
                    l.timestamp.month == now.month &&
                    l.timestamp.year == now.year).toList();
              } else if (_filterDate == 'Week') {
                final weekAgo = now.subtract(const Duration(days: 7));
                logs = logs.where((l) => l.timestamp.isAfter(weekAgo)).toList();
              }

              if (_filterAction != 'All') {
                logs = logs.where((l) => l.action == _filterAction).toList();
              }
              if (_searchQuery.isNotEmpty) {
                logs = logs
                    .where((l) =>
                        l.studentName.toLowerCase().contains(_searchQuery) ||
                        l.studentRoll.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nfc, size: 56, color: context.color.border),
                      const SizedBox(height: 16),
                      Text('No RFID scans yet',
                          style: TextStyle(
                              color: context.color.textSecondary, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                          'Scans from ESP32 will appear here in real-time',
                          style: TextStyle(
                              color: context.color.textSecondary, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: logs.length,
                itemBuilder: (context, i) => _buildLogTile(logs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: context.color.background,
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: TextStyle(color: context.color.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name or roll...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          const SizedBox(height: 10),
          // Date filter chips
          Row(
            children: ['Today', 'Week', 'All'].map((f) {
              final isSelected = _filterDate == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterDate = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.info.withValues(alpha: 0.15)
                          : context.color.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.info : context.color.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(f,
                        style: TextStyle(
                            color: isSelected ? AppColors.info : context.color.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Action filter chips
          Row(
            children: ['All', 'Entry', 'Exit'].map((f) {
              final isSelected = _filterAction == f;
              final color = f == 'Entry'
                  ? AppColors.success
                  : f == 'Exit'
                      ? AppColors.error
                      : context.color.accent;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterAction = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : context.color.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : context.color.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSelected ? color : context.color.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(AttendanceModel log) {
    final isEntry = log.action == 'Entry';
    final color = isEntry ? AppColors.success : AppColors.error;
    final icon = isEntry ? Icons.login_rounded : Icons.logout_rounded;
    final now = DateTime.now();
    final isToday = log.timestamp.day == now.day &&
        log.timestamp.month == now.month &&
        log.timestamp.year == now.year;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          log.studentName,
          style: TextStyle(
              color: context.color.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Text('Roll: ${log.studentRoll}',
                  style: TextStyle(
                      color: context.color.textSecondary, fontSize: 11)),
              if (log.duration.isNotEmpty) ...[
                Text('  •  ',
                    style: TextStyle(color: context.color.border)),
                Icon(Icons.timer_outlined,
                    size: 11, color: context.color.textSecondary),
                const SizedBox(width: 3),
                Text(log.duration,
                    style: TextStyle(
                        color: context.color.textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                log.action.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isToday
                  ? DateFormat('HH:mm:ss').format(log.timestamp)
                  : DateFormat('dd MMM, HH:mm').format(log.timestamp),
              style: TextStyle(
                  color: context.color.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
