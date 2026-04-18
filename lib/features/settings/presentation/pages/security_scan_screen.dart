import 'package:flutter/material.dart';
import 'package:project_v2/core/utils/security_auditor.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class SecurityScanScreen extends StatefulWidget {
  const SecurityScanScreen({super.key});

  @override
  State<SecurityScanScreen> createState() => _SecurityScanScreenState();
}

class _SecurityScanScreenState extends State<SecurityScanScreen> {
  final SecurityAuditor _auditor = SecurityAuditor();
  List<SecurityAuditResult>? _results;
  bool _isScanning = false;
  double _progress = 0.0;

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _results = null;
      _progress = 0.0;
    });

    // Simulate progress for dramatic effect ⚡
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _progress = i / 10.0);
    }

    final scanResults = await _auditor.runFullScan();
    
    setState(() {
      _results = scanResults;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security & Privacy Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Shield Icon & Header ───────────────────────────────────────
            _buildShieldHeader(isDark),
            const SizedBox(height: 32),

            // ── Scan Logic ──────────────────────────────────────────────────
            Expanded(
              child: _results == null
                  ? _buildInitialState()
                  : _buildResultsList(),
            ),

            // ── Action Button ───────────────────────────────────────────────
            if (!_isScanning)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton.icon(
                  onPressed: _startScan,
                  icon: Icon(Icons.security, color: theme.colorScheme.onPrimary),
                  label: Text(_results == null ? 'Start Security Audit' : 'Re-scan System'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              ).animate().fade().scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildShieldHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning 
                    ? Colors.blue.withValues(alpha: 0.1) 
                    : (_results?.any((r) => !r.passed) ?? false) ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds),
            Icon(
              _isScanning ? Icons.sync : (_results?.any((r) => !r.passed) ?? false) ? Icons.warning_rounded : Icons.verified_user_rounded, 
              size: 64, 
              color: _isScanning 
                  ? Colors.blue 
                  : (_results?.any((r) => !r.passed) ?? false) ? Colors.red : Colors.greenAccent[400]
            ).animate(target: _isScanning ? 1 : 0).rotate(duration: 1.seconds),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _isScanning ? 'Auditing System...' : _results == null ? 'Ready to Audit' : 'Scan Complete',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (_isScanning)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_reset_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'This scan will probe your backend logic for:\n• Authorization Vulnerabilities\n• Deletion Ownership Checks\n• Private Content Isolation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    ).animate().fade(duration: 1.seconds);
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        final result = _results![index];
        return _buildResultTile(result);
      },
    ).animate().fade();
  }

  Widget _buildResultTile(SecurityAuditResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: result.passed ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(result.passed ? Icons.check_circle : Icons.error, color: result.passed ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(result.passed ? result.description : result.error!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                ),
                if (result.passed)
                  const Text('SECURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (100 * _results!.indexOf(result)).ms).slideX(begin: 0.1).fade();
  }
}
