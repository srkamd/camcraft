import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'Check out ScanCraft: Easy PDF & Doc Scanner! A complete, free, privacy-first CamScanner alternative with on-device AI, ID Card mode, and digital signatures: https://github.com/srkamd/scancraft',
      subject: 'ScanCraft - Mobile Document Scanner & PDF Utility',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About ScanCraft'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. App Header & Logo
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.document_scanner, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ScanCraft',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Easy PDF & Doc Scanner',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'v1.0.0 • On-Device AI & 100% Private',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. Vision & Mission Section
            _buildSectionCard(
              title: '🎯 Our Vision',
              icon: Icons.lightbulb_outline,
              child: const Text(
                'ScanCraft was built to offer a free, modern, and privacy-first alternative to commercial document scanners. Traditional scanning apps often lock essential tools behind expensive subscriptions, bombard users with ads, and upload sensitive documents to external cloud servers.\n\n'
                'ScanCraft processes all documents, boundary detection, OCR, and PDF generation 100% locally on your phone processor using Google ML Kit. Your confidential documents never leave your device.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Complete Feature Suite
            _buildSectionCard(
              title: '⚡ Feature Suite',
              icon: Icons.auto_awesome_outlined,
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.crop_free,
                    title: 'Smart Boundary Detection',
                    desc: 'Real-time edge recognition and perspective deskewing for crystal-clear rectangular scans.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.badge_outlined,
                    title: 'ID Card & License Mode',
                    desc: 'Scans Front & Back of identity cards and merges them onto a single standard A4 sheet.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.draw_outlined,
                    title: 'Digital Signature (E-Sign)',
                    desc: 'Draw your signature on an interactive pad and stamp it permanently onto document pages.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.text_fields,
                    title: '99% Accurate Offline OCR',
                    desc: 'Pre-processed contrast-enhanced engine for extracting readable text and exporting to .txt.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.lock_outline,
                    title: 'AES-128 Password Protection',
                    desc: 'Lock exported PDF files with standard encryption to secure sensitive information.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.compress,
                    title: 'Smart 3-Tier PDF Compression',
                    desc: 'Standard (65% smaller), Compact (instant sharing), and High-res Original modes.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.merge_type,
                    title: 'Multi-Document Merger',
                    desc: 'Select multiple documents and combine all pages into a unified master PDF.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.qr_code_scanner,
                    title: 'QR & Barcode Scanner',
                    desc: 'Instant code detection, URL launch, and export to document notes.',
                  ),
                  const Divider(height: 20),
                  _buildFeatureRow(
                    icon: Icons.fingerprint,
                    title: 'Biometric App Lock',
                    desc: 'Secure entire app access with device Fingerprint or Face ID authentication.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Developer Information Card
            _buildSectionCard(
              title: '👨‍💻 Developer & Creator',
              icon: Icons.person_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        child: const Icon(Icons.person, size: 32, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'srkamd',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Software Engineer & Mobile App Developer',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Built with passion for high-performance mobile utilities, clean software architecture, and modern computer vision on mobile platforms.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 18),

                  // Developer Links
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _launchUrl('https://github.com/srkamd'),
                          icon: const Icon(Icons.code, size: 18, color: AppTheme.primary),
                          label: const Text('GitHub Profile', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _launchUrl('https://github.com/srkamd/scancraft'),
                          icon: const Icon(Icons.star_outline, size: 18, color: Colors.white),
                          label: const Text('Star on GitHub', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Share App Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _shareApp,
              icon: const Icon(Icons.share, size: 20, color: Color(0xFF1E293B)),
              label: const Text('Share ScanCraft with Friends', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                '© 2026 ScanCraft • Open Source MIT License',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
