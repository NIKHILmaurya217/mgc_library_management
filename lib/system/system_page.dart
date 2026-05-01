import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';
import '../analysis/analysis_page.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  Color get surfaceColor => context.color.surface;
  final Color surfaceLighter = const Color(0xFF131922);
  Color get accentColor => context.color.accent;
  Color get borderColor => context.color.border;
  Color get mutedText => context.color.textSecondary;

  bool _isRebooting = false;
  final FirestoreService _firestoreService = FirestoreService();

  String _formatUptime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  void _triggerAction(String actionName, dynamic value) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: $actionName → $value'),
        backgroundColor: accentColor.withValues(alpha: 0.8),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showJsonDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor)),
        title: Text('ESP32 Raw Status', style: TextStyle(color: context.color.textPrimary, fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(
            data.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: context.color.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: context.color.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('⚙️ SYSTEM INFO'),
            const SizedBox(height: 16),

            StreamBuilder<Map<String, dynamic>?>(
              stream: _firestoreService.streamDeviceStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                bool isOnline = false;
                if (!snapshot.hasError && snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  if (data.containsKey('last_ping')) {
                    final lastPing = (data['last_ping']).toDate();
                    isOnline = DateTime.now().difference(lastPing).inSeconds <= 60;
                  } else {
                    isOnline = true; // Fallback
                  }
                }

                if (!isOnline) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Text('❌ ESP32 Offline or Not Configured',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  );
                }

                final data = snapshot.data!;
                final firmware = data['firmware'] ?? 'Unknown';
                final mode = data['mode'] ?? 'attendance';
                final uptimeSec = (data['uptime_sec'] ?? 0) as int;
                final rssi = (data['rssi'] ?? -100) as int;
                final wifiList = data['wifiList'] ?? 'Unknown';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildStatusRow('WiFi Network', wifiList,
                          isBadge: true, badgeColor: AppColors.success),
                      _buildStatusRow('Current Mode', mode.toUpperCase(),
                          isBadge: true,
                          badgeColor: mode == 'enroll' ? Colors.orange : accentColor),
                      _buildStatusRow('Firmware', firmware,
                          isBadge: true, badgeColor: accentColor),
                      _buildStatusRow('Uptime', _formatUptime(uptimeSec), isMono: true),
                      _buildStatusRow('Signal Strength', '$rssi dBm', isMono: true),
                      _buildStatusRow('Cloud Sync', '✅ Active', hideDivider: true),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('🎮 HARDWARE CONTROLS'),
            const SizedBox(height: 16),

            StreamBuilder<Map<String, dynamic>?>(
              stream: _firestoreService.streamDeviceStatus(),
              builder: (context, snapshot) {
                bool isOnline = false;
                if (!snapshot.hasError && snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  if (data.containsKey('last_ping')) {
                    final lastPing = (data['last_ping']).toDate();
                    isOnline = DateTime.now().difference(lastPing).inSeconds <= 60;
                  } else {
                    isOnline = true;
                  }
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: [
                    _buildControlButton('TEST LOCK / LED', Icons.lock_outline, Colors.orange,
                        isOnline ? () async {
                          HapticFeedback.mediumImpact();
                          await _firestoreService.sendDeviceCommand({'cmd_lock': true});
                          if (mounted) _triggerAction('Lock Test', 'Sent to ESP32');
                        } : null),
                    
                    _buildControlButton(
                      (snapshot.data?['mode'] == 'enroll') ? 'SWITCH TO ATTENDANCE' : 'SWITCH TO ENROLL', 
                      Icons.swap_horiz, 
                      accentColor,
                        isOnline ? () async {
                          HapticFeedback.mediumImpact();
                          final newMode = (snapshot.data?['mode'] == 'enroll') ? 'attendance' : 'enroll';
                          await _firestoreService.sendDeviceCommand({'cmd_mode': newMode});
                          if (mounted) _triggerAction('Mode', newMode);
                        } : null),
                        
                    _buildControlButton(
                      _isRebooting ? 'REBOOTING...' : 'REBOOT ESP32',
                      Icons.refresh,
                      Colors.redAccent,
                      isOnline ? () async {
                        setState(() => _isRebooting = true);
                        HapticFeedback.heavyImpact();
                        await _firestoreService.sendDeviceCommand({'cmd_reboot': true});
                        if (mounted) _triggerAction('Reboot', 'Signal Sent');
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) setState(() => _isRebooting = false);
                        });
                      } : null,
                    ),
                    
                    _buildControlButton('JSON STATUS', Icons.code, mutedText,
                        isOnline && snapshot.data != null ? () {
                          HapticFeedback.lightImpact();
                          _showJsonDialog(snapshot.data!);
                        } : null),
                  ],
                );
              }
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('📉 ANALYSIS & REPORTS'),
            const SizedBox(height: 16),
            _buildFullWidthButton(
              'VIEW ANALYSIS REPORT',
              Icons.analytics_rounded,
              accentColor,
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalysisPage()),
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('📊 EXTERNAL LINKS'),
            const SizedBox(height: 16),

            _buildFullWidthButton(
              'OPEN GOOGLE SHEET DATABASE',
              Icons.table_chart,
              const Color(0xFF7C3AED),
              () => _triggerAction('Open URL', 'Google Sheets'),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                color: mutedText,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: borderColor)),
      ],
    );
  }

  Widget _buildStatusRow(String key, String value,
      {bool isBadge = false,
      Color? badgeColor,
      bool isMono = false,
      bool hideDivider = false,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(key, style: TextStyle(color: mutedText, fontSize: 13)),
                isBadge
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor!.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(value,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      )
                    : Text(value,
                        style: TextStyle(
                          color: context.color.textPrimary,
                          fontSize: 13,
                          fontFamily: isMono ? 'monospace' : null,
                        )),
              ],
            ),
          ),
          if (!hideDivider) Divider(color: borderColor.withValues(alpha: 0.5), height: 1),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    final isDisabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.3 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceLighter,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
