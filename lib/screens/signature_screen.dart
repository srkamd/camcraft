import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../theme/app_theme.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late SignatureController _controller;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.5;

  final List<Color> _availableColors = [
    Colors.black,
    const Color(0xFF003366), // Deep Navy Blue
    const Color(0xFF005B41), // CamScanner Green
    const Color(0xFF990000), // Crimson Red
  ];

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.transparent,
    );
  }

  void _updatePen({Color? color, double? strokeWidth}) {
    setState(() {
      if (color != null) _selectedColor = color;
      if (strokeWidth != null) _strokeWidth = strokeWidth;
    });
    // Preserve current points with new pen settings
    final points = _controller.points;
    _controller.dispose();
    _controller = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.transparent,
      points: points,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exportSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first')),
      );
      return;
    }

    final Uint8List? signatureBytes = await _controller.toPngBytes();
    if (signatureBytes != null && mounted) {
      Navigator.pop(context, signatureBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature (E-Sign)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo stroke',
            onPressed: () {
              if (_controller.isNotEmpty) {
                _controller.undo();
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear canvas',
            onPressed: () {
              _controller.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Sign inside the box below with your finger or stylus.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),

          // Signature Canvas Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Dotted guideline at bottom for signing line
                    Positioned(
                      bottom: 50,
                      left: 30,
                      right: 30,
                      child: Container(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    const Positioned(
                      bottom: 30,
                      left: 32,
                      child: Text('x ________________________',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Signature(
                      controller: _controller,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pen Customization Toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Color Picker Row
                Row(
                  children: [
                    const Text('Ink Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 14),
                    ..._availableColors.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => _updatePen(color: color),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ],
                ),
                const SizedBox(height: 16),

                // Save / Apply Signature Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _exportSignature,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text(
                      'Use This Signature',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
