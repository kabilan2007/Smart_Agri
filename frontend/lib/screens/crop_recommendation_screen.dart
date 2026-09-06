import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/colors.dart';
import '../models/crop_recommendation_model.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../services/location_service.dart';

typedef CropAdvisorScreen = CropRecommendationScreen;

class CropRecommendationScreen extends StatefulWidget {
  final double? lat;
  final double? lon;

  const CropRecommendationScreen(
      {super.key, this.lat, this.lon});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  String _selectedSoil = 'Red';
  String _selectedWater = 'Borewell / Canal';
  CropRecommendationResponse? _result;
  bool _isLoading = false;
  RecommendedCrop? _expandedCrop;
  double? _liveLat;
  double? _liveLon;

  final List<Map<String, dynamic>> _soilOptions = [
    {'name': 'Red Soil', 'code': 'Red', 'emoji': '🟥', 'desc': 'Good drainage, low N & P'},
    {'name': 'Black Cotton', 'code': 'Black', 'emoji': '⬛', 'desc': 'High clay, moisture retaining'},
    {'name': 'Alluvial / Loamy', 'code': 'Alluvial', 'emoji': '🟫', 'desc': 'Most fertile, multi-crop'},
    {'name': 'Clay Soil', 'code': 'Clay', 'emoji': '🟤', 'desc': 'Heavy, suited for paddy'},
    {'name': 'Laterite', 'code': 'Laterite', 'emoji': '🔶', 'desc': 'Acidic, plantation crops'},
    {'name': 'Sandy Loam', 'code': 'Sandy', 'emoji': '🟡', 'desc': 'Light, needs irrigation'},
  ];

  final List<Map<String, String>> _waterOptions = [
    {'name': 'Borewell / Canal', 'icon': '💧', 'desc': 'Assured irrigation'},
    {'name': 'Drip Irrigation', 'icon': '🚿', 'desc': 'Efficient micro-irrigation'},
    {'name': 'Rainfed', 'icon': '🌧️', 'desc': 'Monsoon dependent'},
    {'name': 'River / Tank', 'icon': '🏞️', 'desc': 'Surface water source'},
  ];

  @override
  void initState() {
    super.initState();
    _liveLat = widget.lat;
    _liveLon = widget.lon;
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    if (_liveLat == null || _liveLon == null || (_liveLat == 0.0 && _liveLon == 0.0)) {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _liveLat = pos.latitude;
          _liveLon = pos.longitude;
        });
      }
    }
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _expandedCrop = null;
    });
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final latToUse = _liveLat ?? 11.6643;
    final lonToUse = _liveLon ?? 78.1460;
    final res = await ApiService.getCropRecommendation(
      lat: latToUse,
      lon: lonToUse,
      soilType: _selectedSoil,
      waterSource: _selectedWater,
      language: loc.currentLocale,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AgriColors.bgDark : const Color(0xFFF4F7F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.tr('crop_advisor_title'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(loc.tr('crop_advisor_desc'),
                style: const TextStyle(
                    fontSize: 10.5, color: AgriColors.textMuted)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSoilSelector(loc, isDark),
              const SizedBox(height: 16),
              _buildWaterSelector(loc, isDark),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fetchRecommendations,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isLoading
                      ? 'Analyzing Conditions...'
                      : 'Get AI Crop Recommendations'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 24),
                _buildSeasonBanner(_result!, isDark),
                const SizedBox(height: 16),
                _buildSoilAdvice(_result!, isDark),
                const SizedBox(height: 20),
                Text(loc.tr('best_crops_heading'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._result!.bestCrops.asMap().entries.map(
                      (e) => _buildExpandableCropCard(e.value, e.key, isDark),
                    ),
                if (_result!.cropsToAvoid.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '🚫 Crops to Avoid This Season',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ..._result!.cropsToAvoid.map((c) => _buildAvoidCard(c, isDark)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoilSelector(LocalizationService loc, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.tr('select_soil'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15),
          itemCount: _soilOptions.length,
          itemBuilder: (_, i) {
            final s = _soilOptions[i];
            final isSelected = _selectedSoil == s['code'];
            return GestureDetector(
              onTap: () => setState(() => _selectedSoil = s['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AgriColors.primaryGreen
                      : isDark
                          ? AgriColors.cardDark
                          : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AgriColors.primaryGreen
                        : AgriColors.primaryGreen.withOpacity(0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s['emoji']!,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        s['name']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      s['desc']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isSelected
                            ? Colors.white70
                            : AgriColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWaterSelector(LocalizationService loc, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.tr('select_water'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: _waterOptions.map((w) {
            final isSelected = _selectedWater == w['name'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedWater = w['name']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AgriColors.primaryGreen
                        : isDark
                            ? AgriColors.cardDark
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AgriColors.primaryGreen
                          : AgriColors.primaryGreen.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(w['icon']!,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text(
                        w['name']!.split(' ').first,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeasonBanner(CropRecommendationResponse res, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🌾', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detected Season',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                Text(
                  res.detectedSeason,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  res.weatherSummary,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSoilAdvice(CropRecommendationResponse res, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgriColors.soilBrown.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriColors.soilBrown.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🪱', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${res.soilAnalyzed} Soil Health Advice',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  res.generalSoilAdvice,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.5, color: AgriColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCropCard(
      RecommendedCrop crop, int index, bool isDark) {
    final isExpanded = _expandedCrop == crop;

    return GestureDetector(
      onTap: () =>
          setState(() => _expandedCrop = isExpanded ? null : crop),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AgriColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded
                ? AgriColors.primaryGreen
                : AgriColors.primaryGreen.withOpacity(0.1),
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.08 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AgriColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _cropEmoji(crop.cropName),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(crop.cropName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5)),
                      Text(
                        crop.scientificName.isNotEmpty
                            ? crop.scientificName
                            : crop.waterRequirement,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AgriColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _scoreColor(crop.suitabilityScore)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${crop.suitabilityScore}% match',
                        style: TextStyle(
                          color: _scoreColor(crop.suitabilityScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AgriColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
            if (!isExpanded) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _infoChip(Icons.payments_rounded, crop.estimatedProfitPerAcreInr),
                  const SizedBox(width: 6),
                  _infoChip(Icons.timer_rounded, '${crop.growthDurationDays} days'),
                  const SizedBox(width: 6),
                  _infoChip(Icons.water_drop_rounded, crop.waterRequirement.split(' ').first),
                ],
              ),
            ],
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _detailRow('💰 Profit / Acre', crop.estimatedProfitPerAcreInr),
              _detailRow('📦 Yield / Acre', crop.expectedYieldPerAcre),
              _detailRow('⏱ Duration', '${crop.growthDurationDays} Days'),
              _detailRow('💧 Water Need', crop.waterRequirement),
              const SizedBox(height: 10),
              _expandableSection('🌾 Recommended Varieties',
                  crop.varietyRecommendations.join('\n'), isDark),
              _expandableSection(
                  '💡 Why This Crop?', crop.whyRecommended, isDark),
              _expandableSection(
                  '💊 Irrigation Schedule', crop.irrigationSchedule, isDark),
              if (crop.fertilizerPlan.isNotEmpty)
                _fertilizerPlan(crop.fertilizerPlan, isDark),
              if (crop.strictWarning != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AgriColors.alertWarning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AgriColors.alertWarning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AgriColors.alertWarning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          crop.strictWarning!,
                          style: const TextStyle(
                              color: AgriColors.alertWarning,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ).animate(delay: Duration(milliseconds: 60 * index))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildAvoidCard(CropToAvoid c, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AgriColors.alertCritical.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AgriColors.alertCritical.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded,
              color: AgriColors.alertCritical, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${c.crop}: ',
                  style: const TextStyle(
                      color: AgriColors.alertCritical,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                TextSpan(
                  text: c.reason,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AgriColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AgriColors.primaryGreen),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AgriColors.primaryGreen)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, color: AgriColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _expandableSection(String title, String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AgriColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 5),
          Text(content,
              style: const TextStyle(fontSize: 12, height: 1.5, color: AgriColors.textMuted)),
        ],
      ),
    );
  }

  Widget _fertilizerPlan(Map<String, String> plan, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AgriColors.soilBrown.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriColors.soilBrown.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱 Fertilizer Management Plan',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 8),
          ...plan.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AgriColors.soilBrown.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AgriColors.soilBrown)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return AgriColors.primaryGreen;
    if (score >= 75) return AgriColors.harvestGold;
    return AgriColors.alertWarning;
  }

  String _cropEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('tomato')) return '🍅';
    if (n.contains('rice') || n.contains('paddy')) return '🌾';
    if (n.contains('cotton')) return '🫙';
    if (n.contains('banana')) return '🍌';
    if (n.contains('groundnut') || n.contains('peanut')) return '🥜';
    if (n.contains('sugarcane')) return '🎋';
    if (n.contains('turmeric')) return '🌿';
    if (n.contains('millet') || n.contains('ragi')) return '🌾';
    if (n.contains('soybean')) return '🫘';
    if (n.contains('cashew') || n.contains('coconut')) return '🥥';
    return '🌱';
  }
}
