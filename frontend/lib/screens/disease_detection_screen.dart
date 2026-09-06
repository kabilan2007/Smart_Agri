import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../models/disease_detection_model.dart';
import '../services/api_service.dart';
import '../services/tts_stt_service.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() =>
      _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  DiseaseDetectionResponse? _result;
  bool _isLoading = false;
  int _activeTab = 0; // 0: Symptoms, 1: Organic, 2: Chemical, 3: Preventive
  late AnimationController _scanAnimController;
  final TtsSttService _voice = TtsSttService();

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scanAnimController.dispose();
    _voice.stopSpeaking();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
      });
      await _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() => _isLoading = true);
    _scanAnimController.repeat();

    final result = await ApiService.detectDisease(_selectedImage!);
    _scanAnimController.stop();
    _scanAnimController.reset();

    setState(() {
      _isLoading = false;
      _result = result;
    });
  }

  Color _hexToColor(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return AgriColors.alertWarning;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AgriColors.bgDark : const Color(0xFFF4F7F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Leaf Disease Scanner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Powered by Gemini Vision',
                style: TextStyle(fontSize: 10.5, color: AgriColors.textMuted)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          children: [
            _buildImageSection(isDark),
            if (_isLoading) _buildScanningOverlay(),
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultHeader(_result!, isDark),
              const SizedBox(height: 14),
              _buildTabSelector(),
              const SizedBox(height: 14),
              _buildTabContent(_result!, isDark),
            ],
            if (!_isLoading && _result == null) _buildTipsSection(isDark),
          ],
        ),
      ),
      floatingActionButton: _selectedImage == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _analyzeImage,
              backgroundColor: AgriColors.primaryGreen,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Re-Analyze',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    return GestureDetector(
      onTap: () => _showPickerOptions(),
      child: Stack(
        children: [
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AgriColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AgriColors.primaryGreen.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AgriColors.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.biotech_rounded,
                            color: AgriColors.primaryGreen, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Take or Upload a Leaf Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AgriColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Point at an affected leaf or crop for\ninstant AI diagnosis & treatment advice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AgriColors.textMuted),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _sourceButton(
                              Icons.camera_alt_rounded, 'Camera', () {
                            _pickImage(ImageSource.camera);
                          }),
                          const SizedBox(width: 12),
                          _sourceButton(
                              Icons.photo_library_rounded, 'Gallery', () {
                            _pickImage(ImageSource.gallery);
                          }),
                        ],
                      ),
                    ],
                  ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AgriColors.primaryLight,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 14),
                        Text('🤖 AI Analyzing Leaf...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_selectedImage != null && !_isLoading)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _showPickerOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Change',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AgriColors.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AgriColors.primaryGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AgriColors.primaryGreen, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AgriColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AgriColors.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AgriColors.primaryGreen, strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Scanning leaf patterns with Gemini Vision...',
                style: TextStyle(
                    color: AgriColors.primaryGreen,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(DiseaseDetectionResponse res, bool isDark) {
    final alertColor = _hexToColor(res.visualAlertColor);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            alertColor.withOpacity(0.15),
            alertColor.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  res.isHealthy
                      ? Icons.check_circle_rounded
                      : Icons.local_hospital_rounded,
                  color: alertColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.plantName,
                      style: TextStyle(
                          fontSize: 12,
                          color: alertColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      res.diseaseIdentified,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      res.severityLevel.toUpperCase(),
                      style: TextStyle(
                          color: alertColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${res.confidenceScorePct.toStringAsFixed(1)}% confidence',
                    style: const TextStyle(
                        fontSize: 11, color: AgriColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: res.confidenceScorePct / 100,
              backgroundColor: alertColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(alertColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _voice.speak(
              'Disease detected: ${res.diseaseIdentified}. ${res.symptoms.join('. ')}',
              langCode: 'en',
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_rounded, color: alertColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Listen to Diagnosis',
                    style: TextStyle(
                        color: alertColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTabSelector() {
    final tabs = ['Symptoms', 'Organic', 'Chemical', 'Prevention'];
    final icons = [
      Icons.info_outline_rounded,
      Icons.eco_rounded,
      Icons.science_rounded,
      Icons.shield_rounded,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          tabs.length,
          (i) => GestureDetector(
            onTap: () => setState(() => _activeTab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _activeTab == i
                    ? AgriColors.primaryGreen
                    : AgriColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icons[i],
                      size: 15,
                      color: _activeTab == i
                          ? Colors.white
                          : AgriColors.primaryGreen),
                  const SizedBox(width: 5),
                  Text(
                    tabs[i],
                    style: TextStyle(
                      color: _activeTab == i
                          ? Colors.white
                          : AgriColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(DiseaseDetectionResponse res, bool isDark) {
    List<String> items;
    String title;
    IconData icon;
    Color color;

    switch (_activeTab) {
      case 1:
        items = res.organicRemedies;
        title = '🌿 Organic & Bio-remedies';
        icon = Icons.eco_rounded;
        color = AgriColors.primaryGreen;
        break;
      case 2:
        items = res.chemicalTreatments;
        title = '🧪 Chemical Fungicide / Pesticide (Dosage)';
        icon = Icons.science_rounded;
        color = AgriColors.alertAdvisory;
        break;
      case 3:
        items = res.preventiveMeasures;
        title = '🛡️ Preventive Measures';
        icon = Icons.shield_rounded;
        color = AgriColors.harvestGold;
        break;
      default:
        // Symptoms & Causes combined
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard('🔍 Visual Symptoms', res.symptoms, isDark,
                AgriColors.alertWarning),
            const SizedBox(height: 12),
            _sectionCard('🦠 Causes & Triggers', res.causes, isDark,
                AgriColors.alertCritical),
          ],
        );
    }

    return _sectionCard(title, items, isDark, color);
  }

  Widget _sectionCard(String title, List<String> items, bool isDark,
      Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AgriColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildTipsSection(bool isDark) {
    final tips = [
      '📸 Take the photo in bright daylight for best accuracy',
      '🌿 Focus on the affected leaf area (lesions, spots, discoloration)',
      '🔍 Avoid blurry or dark images',
      '🌾 Works best with: Rice, Cotton, Tomato, Banana, Chilli, Groundnut',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AgriColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 Tips for Best Results',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tip,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4)),
                )),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Image Source',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOption(Icons.camera_alt_rounded, 'Camera',
                    () => _pickImage(ImageSource.camera)),
                _pickerOption(Icons.photo_library_rounded, 'Gallery',
                    () => _pickImage(ImageSource.gallery)),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: AgriColors.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AgriColors.primaryGreen.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AgriColors.primaryGreen, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AgriColors.primaryGreen,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
