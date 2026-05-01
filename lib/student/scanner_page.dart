import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_colors.dart';
import '../services/firestore_service.dart';
import '../core/theme/app_theme.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Timestamp _startTime;
  final FirestoreService _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Record exactly when we opened the page so we ignore old scans
    _startTime = Timestamp.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.background,
      appBar: AppBar(
        title: const Text('Scan ID Card'),
        backgroundColor: context.color.background,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to temp_scans for anything added AFTER we opened the page
        stream: FirebaseFirestore.instance
            .collection('temp_scans')
            .where('timestamp', isGreaterThan: _startTime)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
          }

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final doc = snapshot.data!.docs.first;
            final uid = doc['uid'] as String;
            
            // Pop the specific UID back to the form immediately
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pop(context, uid);
              }
            });

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 80),
                  const SizedBox(height: 16),
                  Text('Card Detected: $uid', style: const TextStyle(color: AppColors.success, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          // While waiting for a scan, check if the device is actually online
          return StreamBuilder<Map<String, dynamic>?>(
            stream: _service.streamDeviceStatus(),
            builder: (context, deviceSnap) {
              bool isOnline = false;
              if (deviceSnap.hasData && deviceSnap.data != null && !deviceSnap.hasError) {
                final data = deviceSnap.data!;
                if (data.containsKey('last_ping')) {
                  final lastPing = (data['last_ping'] as Timestamp).toDate();
                  isOnline = DateTime.now().difference(lastPing).inSeconds <= 60;
                } else {
                  isOnline = true; // Fallback
                }
              }

              if (!isOnline) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 2),
                        ),
                        child: const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.error),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Scanner is Offline',
                        style: TextStyle(color: AppColors.error, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The ESP32 is powered off or disconnected.\nPlease check the hardware connection.',
                        style: TextStyle(color: context.color.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.surface,
                          foregroundColor: context.color.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.color.accent.withValues(alpha: 0.1),
                          border: Border.all(color: context.color.accent.withValues(alpha: 0.5), width: 2),
                        ),
                        child: Icon(Icons.nfc, size: 64, color: context.color.accent),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Waiting for Card Scan...',
                      style: TextStyle(color: context.color.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please tap the ID card on the ESP32 scanner.',
                      style: TextStyle(color: context.color.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.surface,
                        foregroundColor: context.color.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }
}
