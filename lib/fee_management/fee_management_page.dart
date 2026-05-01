import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/fee_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';

enum FilterMode { daily, monthly, yearly }

class FeeManagementPage extends StatefulWidget {
  const FeeManagementPage({super.key});

  @override
  State<FeeManagementPage> createState() => _FeeManagementPageState();
}

class _FeeManagementPageState extends State<FeeManagementPage> {
  final FirestoreService _service = FirestoreService();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  FilterMode _filterMode = FilterMode.monthly;
  DateTime _filterDate = DateTime.now();
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;

  String? _selectedStudentId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedStatus = 'PAID';
  bool _isSubmitting = false;

  final List<String> _statuses = ['PAID', 'PARTIAL', 'PENDING'];
  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitFee(List<StudentModel> currentStudents) async {
    if (_selectedStudentId == null) {
      _snack('Please select a student', AppColors.error);
      return;
    }
    
    final student = currentStudents.firstWhere((s) => s.id == _selectedStudentId, orElse: () => currentStudents.first);

    if (_amountController.text.trim().isEmpty) {
      _snack('Please enter an amount', AppColors.error);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final fee = FeeModel(
        id: '',
        studentId: student.id,
        studentName: student.name,
        studentRoll: student.roll,
        month: _selectedMonth,
        year: _selectedYear,
        amount: double.parse(_amountController.text.trim()),
        status: _selectedStatus,
        paidOn: DateTime.now(),
        note: _noteController.text.trim(),
      );
      await _service.addFee(fee);
      _amountController.clear();
      _noteController.clear();
      if (mounted) _snack('Fee record saved!', AppColors.success);
    } catch (e) {
      if (mounted) _snack('Error: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _confirmDelete(FeeModel fee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.color.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.color.border)),
        title: Text('Delete Record?', style: TextStyle(color: context.color.textPrimary)),
        content: Text(
          'Delete fee record for ${fee.studentName} — ${fee.monthLabel}?',
          style: TextStyle(color: context.color.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: context.color.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) await _service.deleteFee(fee.id);
  }

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('FILTER COLLECTIONS BY'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdown<FilterMode>(
                  value: _filterMode,
                  items: FilterMode.values,
                  labelBuilder: (m) => m.name.toUpperCase(),
                  onChanged: (v) => setState(() => _filterMode = v!),
                ),
              ),
              const SizedBox(width: 12),
              if (_filterMode == FilterMode.daily) ...[
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filterDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => _filterDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.color.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.color.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(_filterDate),
                              style: TextStyle(color: context.color.textPrimary, fontSize: 13)),
                          Icon(Icons.calendar_today, size: 16, color: context.color.accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (_filterMode == FilterMode.monthly) ...[
                Expanded(
                  flex: 2,
                  child: _buildDropdown<int>(
                    value: _filterMonth,
                    items: List.generate(12, (i) => i + 1),
                    labelBuilder: (m) => _monthNames[m - 1],
                    onChanged: (v) => setState(() => _filterMonth = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDropdown<int>(
                    value: _filterYear,
                    items: [2024, 2025, 2026, 2027],
                    labelBuilder: (y) => y.toString(),
                    onChanged: (v) => setState(() => _filterYear = v!),
                  ),
                ),
              ] else if (_filterMode == FilterMode.yearly) ...[
                Expanded(
                  flex: 3,
                  child: _buildDropdown<int>(
                    value: _filterYear,
                    items: [2024, 2025, 2026, 2027],
                    labelBuilder: (y) => y.toString(),
                    onChanged: (v) => setState(() => _filterYear = v!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<FeeModel> _filterFees(List<FeeModel> allFees) {
    return allFees.where((f) {
      if (_filterMode == FilterMode.daily) {
        return f.paidOn.year == _filterDate.year &&
               f.paidOn.month == _filterDate.month &&
               f.paidOn.day == _filterDate.day;
      } else if (_filterMode == FilterMode.monthly) {
        return f.paidOn.month == _filterMonth && f.paidOn.year == _filterYear;
      } else {
        return f.paidOn.year == _filterYear;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter Controls ──────────────────────────────────
          _buildFilterControls(),
          const SizedBox(height: 16),

          // ── Summary Cards ──────────────────────────────────
          StreamBuilder<List<FeeModel>>(
            stream: _service.getFees(),
            builder: (context, snapshot) {
              final allFees = snapshot.data ?? [];
              final fees = _filterFees(allFees);
              
              final totalCollected = fees
                  .where((f) => f.status == 'PAID' || f.status == 'PARTIAL')
                  .fold(0.0, (sum, f) => sum + f.amount);
              final pendingCount =
                  fees.where((f) => f.status == 'PENDING').length;

              return Row(
                children: [
                  _buildSummaryCard('Total Collected',
                      '₹${NumberFormat('#,##0').format(totalCollected)}', AppColors.success),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                      'Pending Records', '$pendingCount entries', AppColors.warning),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('RECORD PAYMENT', Icons.add_card_outlined),
          const SizedBox(height: 12),

          // ── Payment Form ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.color.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.color.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student picker
                _buildLabel('SELECT STUDENT'),
                const SizedBox(height: 8),
                StreamBuilder<List<StudentModel>>(
                  stream: _service.getStudents(),
                  builder: (context, snapshot) {
                    final students = snapshot.data ?? [];
                    
                    // CRITICAL FIX: Ensure _selectedStudentId exists in the current stream
                    if (_selectedStudentId != null) {
                      final exists = students.any((s) => s.id == _selectedStudentId);
                      if (!exists) {
                        _selectedStudentId = null;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.color.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.color.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: context.color.surface,
                          hint: Text('Choose student...',
                              style: TextStyle(color: context.color.textSecondary, fontSize: 14)),
                          value: _selectedStudentId,
                          items: students.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text('${s.roll} — ${s.name}',
                                  style: TextStyle(color: context.color.textPrimary, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (id) => setState(() => _selectedStudentId = id),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                // Month + Year row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('MONTH'),
                          const SizedBox(height: 8),
                          _buildDropdown<int>(
                            value: _selectedMonth,
                            items: List.generate(12, (i) => i + 1),
                            labelBuilder: (m) => _monthNames[m - 1],
                            onChanged: (v) => setState(() => _selectedMonth = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('YEAR'),
                          const SizedBox(height: 8),
                          _buildDropdown<int>(
                            value: _selectedYear,
                            items: [2024, 2025, 2026, 2027],
                            labelBuilder: (y) => y.toString(),
                            onChanged: (v) => setState(() => _selectedYear = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('STATUS'),
                          const SizedBox(height: 8),
                          _buildDropdown<String>(
                            value: _selectedStatus,
                            items: _statuses,
                            labelBuilder: (s) => s,
                            onChanged: (v) => setState(() => _selectedStatus = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Amount
                TextField(
                  controller: _amountController,
                  style: TextStyle(color: context.color.textPrimary),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDeco('Amount (₹)', '500'),
                ),
                const SizedBox(height: 12),
                // Note (optional)
                TextField(
                  controller: _noteController,
                  style: TextStyle(color: context.color.textPrimary),
                  decoration: _inputDeco('Note (optional)', 'e.g. Late fee included'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: StreamBuilder<List<StudentModel>>(
                    stream: _service.getStudents(),
                    builder: (context, snapshot) {
                      final students = snapshot.data ?? [];
                      return ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitFee(students),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSubmitting ? 'Saving...' : 'SAVE PAYMENT RECORD',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: context.color.border,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('RECENT PAYMENTS', Icons.receipt_long_outlined),
          const SizedBox(height: 12),

          // ── Recent Payments List ───────────────────────────
          StreamBuilder<List<FeeModel>>(
            stream: _service.getFees(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allFees = snapshot.data ?? [];
              final fees = _filterFees(allFees);
              
              if (fees.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.color.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.color.border),
                  ),
                  child: Center(
                    child: Text('No payment records yet.',
                        style: TextStyle(color: context.color.textSecondary)),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fees.length,
                itemBuilder: (context, i) => _buildFeeRow(fees[i]),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeeRow(FeeModel fee) {
    final statusColor = fee.status == 'PAID'
        ? AppColors.success
        : fee.status == 'PARTIAL'
            ? AppColors.warning
            : AppColors.error;

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_outlined, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fee.studentName,
                    style: TextStyle(
                        color: context.color.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text('${fee.monthLabel}  •  Roll: ${fee.studentRoll}',
                    style: TextStyle(
                        color: context.color.textSecondary, fontSize: 11)),
                if (fee.note.isNotEmpty)
                  Text(fee.note,
                      style: TextStyle(
                          color: context.color.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
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
                      fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(fee.status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async => _confirmDelete(fee),
            icon: Icon(Icons.delete_outline, color: context.color.textSecondary, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.color.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.color.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.color.textSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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

  Widget _buildLabel(String text) {
    return Text(text,
        style: TextStyle(
            color: context.color.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1));
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.color.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.color.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          dropdownColor: context.color.surface,
          value: value,
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(labelBuilder(i),
                        style: TextStyle(color: context.color.textPrimary, fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.color.textSecondary, fontSize: 12),
      hintText: hint,
      hintStyle: TextStyle(color: context.color.textSecondary.withValues(alpha: 0.5), fontSize: 12),
      filled: true,
      fillColor: context.color.background,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.color.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.color.accent)),
    );
  }
}
