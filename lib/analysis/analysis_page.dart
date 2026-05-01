import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';
import '../core/theme/app_theme.dart';

enum TimeFrame { daily, monthly, yearly }

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late TabController _tabController;
  TimeFrame _selectedTimeFrame = TimeFrame.monthly;

  List<FeeModel> _allFees = [];
  List<AttendanceModel> _allAttendance = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fees = await _service.getAllFees();
      final attendance = await _service.getAllAttendance();
      if (mounted) {
        setState(() {
          _allFees = fees;
          _allAttendance = attendance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
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
        title: const Text('Analysis Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.color.surface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.color.accent,
          unselectedLabelColor: context.color.textSecondary,
          indicatorColor: context.color.accent,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Fees Collection'),
            Tab(icon: Icon(Icons.verified_user), text: 'Attendance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    _buildTimeFrameSelector(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeesAnalysis(),
                          _buildAttendanceAnalysis(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTimeFrameSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<TimeFrame>(
        segments: const [
          ButtonSegment(value: TimeFrame.daily, label: Text('Daily')),
          ButtonSegment(value: TimeFrame.monthly, label: Text('Monthly')),
          ButtonSegment(value: TimeFrame.yearly, label: Text('Yearly')),
        ],
        selected: {_selectedTimeFrame},
        onSelectionChanged: (Set<TimeFrame> newSelection) {
          setState(() {
            _selectedTimeFrame = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildFeesAnalysis() {
    return _buildChartContainer(
      child: _FeeChart(fees: _allFees, timeFrame: _selectedTimeFrame, color: context.color.accent),
    );
  }

  Widget _buildAttendanceAnalysis() {
    return _buildChartContainer(
      child: _AttendanceChart(attendanceLogs: _allAttendance, timeFrame: _selectedTimeFrame, color: const Color(0xFF10B981)),
    );
  }

  Widget _buildChartContainer({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              width: constraints.maxWidth > 800 ? 800 : constraints.maxWidth,
              height: 400,
              decoration: BoxDecoration(
                color: context.color.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.color.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// FEE CHART WIDGET
// ==========================================

class _FeeChart extends StatelessWidget {
  final List<FeeModel> fees;
  final TimeFrame timeFrame;
  final Color color;

  const _FeeChart({required this.fees, required this.timeFrame, required this.color});

  @override
  Widget build(BuildContext context) {
    // 1. Filter and Group Data
    final validFees = fees.where((f) => f.status == 'PAID' || f.status == 'PARTIAL').toList();
    
    // Grouping logic based on selected TimeFrame
    final Map<String, double> groupedData = {};

    for (var fee in validFees) {
      String key;
      if (timeFrame == TimeFrame.daily) {
        key = DateFormat('yyyy-MM-dd').format(fee.paidOn);
      } else if (timeFrame == TimeFrame.monthly) {
        key = DateFormat('yyyy-MM').format(fee.paidOn);
      } else {
        key = DateFormat('yyyy').format(fee.paidOn);
      }

      groupedData[key] = (groupedData[key] ?? 0) + fee.amount;
    }

    // Sort keys chronologically
    final sortedKeys = groupedData.keys.toList()..sort();
    
    if (sortedKeys.isEmpty) {
      return Center(child: Text('No fee data found.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)));
    }

    final double maxY = groupedData.values.fold(0, (max, val) => val > max ? val : max);
    final double maxYWithPadding = maxY == 0 ? 100 : maxY * 1.2;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final val = groupedData[key]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: color,
              width: timeFrame == TimeFrame.yearly ? 40 : 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxYWithPadding,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total Fees Collected',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxYWithPadding,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_formatKeyForDisplay(sortedKeys[group.x], timeFrame)}\n₹${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedKeys.length) return const SizedBox.shrink();
                      String text = _formatKeyForShortDisplay(sortedKeys[index], timeFrame);
                      // Skip some labels if there are too many (e.g. daily over 30 days)
                      if (sortedKeys.length > 10 && index % (sortedKeys.length ~/ 10) != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == maxYWithPadding) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          _formatCurrencyAxis(value),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxYWithPadding / 5 == 0 ? 1 : maxYWithPadding / 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrencyAxis(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}

// ==========================================
// ATTENDANCE CHART WIDGET
// ==========================================

class _AttendanceChart extends StatelessWidget {
  final List<AttendanceModel> attendanceLogs;
  final TimeFrame timeFrame;
  final Color color;

  const _AttendanceChart({required this.attendanceLogs, required this.timeFrame, required this.color});

  @override
  Widget build(BuildContext context) {
    // 1. Filter and Group Data
    // Usually we only care about unique entries per period per student, or total entries.
    // Let's count total 'Entry' logs.
    final validLogs = attendanceLogs.where((l) => l.action == 'Entry').toList();
    
    // Grouping logic based on selected TimeFrame
    final Map<String, int> groupedData = {};

    for (var log in validLogs) {
      String key;
      if (timeFrame == TimeFrame.daily) {
        key = DateFormat('yyyy-MM-dd').format(log.timestamp);
      } else if (timeFrame == TimeFrame.monthly) {
        key = DateFormat('yyyy-MM').format(log.timestamp);
      } else {
        key = DateFormat('yyyy').format(log.timestamp);
      }

      groupedData[key] = (groupedData[key] ?? 0) + 1;
    }

    // Sort keys chronologically
    final sortedKeys = groupedData.keys.toList()..sort();
    
    if (sortedKeys.isEmpty) {
      return Center(child: Text('No attendance data found.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)));
    }

    final int maxY = groupedData.values.fold(0, (max, val) => val > max ? val : max);
    final double maxYWithPadding = maxY == 0 ? 10 : (maxY * 1.2);

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final val = groupedData[key]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val.toDouble(),
              color: color,
              width: timeFrame == TimeFrame.yearly ? 40 : 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxYWithPadding,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total Attendance Entries',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxYWithPadding,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_formatKeyForDisplay(sortedKeys[group.x], timeFrame)}\n${rod.toY.toInt()} Entries',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedKeys.length) return const SizedBox.shrink();
                      String text = _formatKeyForShortDisplay(sortedKeys[index], timeFrame);
                      if (sortedKeys.length > 10 && index % (sortedKeys.length ~/ 10) != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == maxYWithPadding || value % 1 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxYWithPadding / 5 == 0 ? 1 : maxYWithPadding / 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }
}

// Helpers

String _formatKeyForDisplay(String key, TimeFrame timeFrame) {
  if (timeFrame == TimeFrame.daily) {
    // key is yyyy-MM-dd
    final date = DateTime.parse(key);
    return DateFormat('dd MMM yyyy').format(date);
  } else if (timeFrame == TimeFrame.monthly) {
    // key is yyyy-MM
    final date = DateTime.parse('$key-01');
    return DateFormat('MMMM yyyy').format(date);
  } else {
    return key;
  }
}

String _formatKeyForShortDisplay(String key, TimeFrame timeFrame) {
  if (timeFrame == TimeFrame.daily) {
    // key is yyyy-MM-dd
    final date = DateTime.parse(key);
    return DateFormat('dd/MM').format(date);
  } else if (timeFrame == TimeFrame.monthly) {
    // key is yyyy-MM
    final date = DateTime.parse('$key-01');
    return DateFormat('MMM').format(date);
  } else {
    return key;
  }
}
