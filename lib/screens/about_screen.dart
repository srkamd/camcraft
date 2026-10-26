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
      'Check out ScanCraft: Easy PDF & Doc Scanner by Shahrukh Ahmad (srkamd)! A free, privacy-first CamScanner alternative with on-device AI, ID Card mode, and digital signatures: https://github.com/srkamd/scancraft',
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
              title: '🎯 App Vision & Mission',
              icon: Icons.lightbulb_outline,
              child: const Text(
                'ScanCraft was built to offer a completely free, modern, and privacy-first alternative to commercial document scanners. Traditional scanning apps frequently lock essential features behind expensive monthly subscriptions, bombard users with intrusive ads, and upload sensitive personal documents to external cloud servers.\n\n'
                'ScanCraft is designed with a strict zero-cloud architecture: document boundary detection, perspective deskewing, OCR text extraction, and PDF generation run 100% locally on your smartphone processor using Google ML Kit. Your confidential documents never leave your device.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Complete Feature Suite
            _buildSectionCard(
              title: '⚡ Complete Feature Suite',
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

            // 4. Developer Information Card (Personalized for Shahrukh Ahmad)
            _buildSectionCard(
              title: '👨‍💻 Developer & Creator',
              icon: Icons.person_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          'https://avatars.githubusercontent.com/u/208114373?v=4',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: 29,
                            backgroundColor: AppTheme.primary.withOpacity(0.12),
                            child: const Icon(Icons.person, size: 32, color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shahrukh Ahmad (SRK AMD)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Computer Science • Computer Vision & Full-Stack Engineer',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Built with passion for real-world software engineering, computer vision, and privacy-first client applications.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 18),

                  // Contact & Social Links Grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSocialChip(
                        label: 'LinkedIn',
                        icon: Icons.business_center_outlined,
                        color: const Color(0xFF0077B5),
                        onTap: () => _launchUrl('https://linkedin.com/in/srkamd'),
                      ),
                      _buildSocialChip(
                        label: 'GitHub',
                        icon: Icons.code,
                        color: const Color(0xFF24292E),
                        onTap: () => _launchUrl('https://github.com/srkamd'),
                      ),
                      _buildSocialChip(
                        label: 'Email',
                        icon: Icons.email_outlined,
                        color: const Color(0xFFD14836),
                        onTap: () => _launchUrl('mailto:srkamduk@gmail.com'),
                      ),
                      _buildSocialChip(
                        label: 'Kaggle',
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF20BEFF),
                        onTap: () => _launchUrl('https://kaggle.com/srkamd'),
                      ),
                      _buildSocialChip(
                        label: 'X (Twitter)',
                        icon: Icons.alternate_email,
                        color: Colors.black87,
                        onTap: () => _launchUrl('https://x.com/srkamd'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Star Repo Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _launchUrl('https://github.com/srkamd/scancraft'),
                      icon: const Icon(Icons.star, size: 18, color: Colors.amber),
                      label: const Text('Star ScanCraft on GitHub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
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

  Widget _buildSocialChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
