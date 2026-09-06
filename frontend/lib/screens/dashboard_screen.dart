import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/colors.dart';
import '../models/weather_model.dart';
import '../models/crop_recommendation_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/localization_service.dart';
import 'ai_chat_screen.dart';
import 'disease_detection_screen.dart';
import 'crop_recommendation_screen.dart';
import 'market_rates_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  WeatherAlertsResponse? _weather;
  CropRecommendationResponse? _crops;
  bool _isLocating = true;
  bool _weatherLoading = false;
  bool _cropsLoading = false;
  LocationResult? _locationResult;
  double? _lat;
  double? _lon;
  String? _state;
  String? _district;
  String? _placeName;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fetchLocationAndData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndData({bool isUserRefresh = false}) async {
    setState(() {
      _isLocating = true;
      _weatherLoading = true;
      _cropsLoading = true;
    });

    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    final locResult = await locProvider.fetchLiveLocation(force: true);
    if (!mounted) return;

    setState(() {
      _locationResult = locResult;
      _isLocating = false;
      _lat = locProvider.currentLatitude;
      _lon = locProvider.currentLongitude;
      _state = locProvider.currentState;
      _district = locProvider.currentDistrict;
      _placeName = locProvider.placeName;
    });

    if (locProvider.hasLocation) {
      await _fetchWeatherAndCrops(
        locProvider.currentLatitude!,
        locProvider.currentLongitude!,
        state: locProvider.currentState,
        district: locProvider.currentDistrict,
      );
    } else {
      setState(() {
        _weatherLoading = false;
        _cropsLoading = false;
      });
      if (isUserRefresh && locResult.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locResult.errorMessage!),
            backgroundColor: Colors.redAccent,
            action: locResult.status == LocationStatus.serviceDisabled
                ? SnackBarAction(
                    label: 'SETTINGS',
                    textColor: Colors.white,
                    onPressed: () => LocationService.openLocationSettings(),
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _fetchWeatherAndCrops(
    double lat,
    double lon, {
    String? state,
    String? district,
  }) async {
    setState(() {
      _weatherLoading = true;
      _cropsLoading = true;
    });
    final weather = await ApiService.getWeatherAlerts(
      lat: lat,
      lon: lon,
      state: state,
      district: district,
    );
    if (!mounted) return;
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final crops = await ApiService.getCropRecommendation(
      lat: lat,
      lon: lon,
      soilType: 'Red',
      locationName: weather?.city ?? district,
      state: state,
      district: district,
      language: loc.currentLocale,
    );
    if (!mounted) return;
    setState(() {
      _weather = weather;
      _crops = crops;
      _weatherLoading = false;
      _cropsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        color: AgriColors.primaryGreen,
        onRefresh: () => _fetchLocationAndData(isUserRefresh: true),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(loc, isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    _buildWeatherBanner(loc, isDark),
                    _buildQuickActions(loc, isDark),
                    _buildTopCropsSection(loc, isDark),
                    _buildMarketTicker(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildVoiceFAB(loc),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(loc),
    );
  }

  Widget _buildAppBar(LocalizationService loc, bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AgriColors.bgDark : AgriColors.primaryGreen,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.spa_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loc.tr('app_name'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildLanguagePill(loc),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final theme = Theme.of(context);
                              // Theme toggle handled by parent
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      if (_locationResult?.status == LocationStatus.serviceDisabled) {
                        await LocationService.openLocationSettings();
                        _fetchLocationAndData();
                      } else if (_locationResult?.status == LocationStatus.permissionDeniedForever) {
                        await LocationService.openAppSettings();
                      } else {
                        _fetchLocationAndData();
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _isLocating
                                ? 'Acquiring live GPS...'
                                : _placeName != null && _placeName!.isNotEmpty
                                    ? _placeName!
                                    : _weather != null
                                        ? '${_weather!.city}, ${_weather!.state ?? ''}'
                                        : _lat != null
                                            ? 'GPS: ${_lat!.toStringAsFixed(3)}, ${_lon!.toStringAsFixed(3)}'
                                            : _locationResult?.status == LocationStatus.serviceDisabled
                                                ? 'GPS OFF (Tap to Enable)'
                                                : _locationResult?.status == LocationStatus.permissionDenied
                                                    ? 'Location Permission Needed'
                                                    : 'Live GPS Required',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _lat != null
                                  ? Color.lerp(Colors.greenAccent,
                                      Colors.green.shade200, _pulseController.value)
                                  : Colors.amberAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildLanguagePill(LocalizationService loc) {
    return GestureDetector(
      onTap: () => _showLanguageBottomSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.currentLanguageInfo.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              loc.currentLanguageInfo.nativeName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.tr('change_language'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: LocalizationService.supportedLanguages.map((lang) {
                final isSelected = loc.currentLocale == lang.code;
                return GestureDetector(
                  onTap: () {
                    loc.setLocale(lang.code);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AgriColors.primaryGreen
                          : AgriColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AgriColors.primaryGreen
                            : AgriColors.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.flag,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.nativeName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AgriColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              lang.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : AgriColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherBanner(LocalizationService loc, bool isDark) {
    if (_isLocating) {
      return _buildLocatingCard(isDark);
    }

    if (_lat == null || (_locationResult != null && !_locationResult!.isSuccess)) {
      return _buildLocationPromptCard(isDark);
    }

    if (_weatherLoading) {
      return _buildShimmerBox(height: 200);
    }

    if (_weather == null) {
      return _buildErrorCard(
          'Could not load weather for your live coordinates. Pull to refresh.', isDark);
    }

    final w = _weather!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main weather card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: w.isRainExpected24h
                    ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                    : [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (w.isRainExpected24h
                          ? Colors.blue
                          : AgriColors.primaryGreen)
                      .withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.tr('weather_risk_alerts'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${w.temperature.toStringAsFixed(1)}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 46,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'C',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              w.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _weatherInfoChip(
                                    Icons.water_drop_outlined,
                                    '${w.humidity}%'),
                                _weatherInfoChip(
                                    Icons.air_rounded,
                                    '${w.windSpeedKmh.toStringAsFixed(0)} km/h'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _weatherEmoji(w.condition),
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (w.totalRainForecast3daysMm > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '🌧 ${w.totalRainForecast3daysMm}mm',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 5-Day Forecast Row
                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: w.forecast.length,
                    itemBuilder: (_, i) {
                      final day = w.forecast[i];
                      return Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                i == 0 ? loc.tr('today') : day.dayName,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10.5),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _weatherEmoji(day.condition),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.tempMax.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (day.rainProbabilityPct > 20)
                              Text(
                                '💧${day.rainProbabilityPct}%',
                                style: const TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontSize: 9.5),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 14),
          // Dynamic Localized Alerts List
          ...(w.alerts.isNotEmpty
                  ? w.alerts
                  : [
                      if (w.windSpeedKmh > 15.0)
                        WeatherAlertItem(
                          level: 'warning',
                          title: '💨 High Wind Warning (Spraying Hazard)',
                          message: 'Wind speed is ${w.windSpeedKmh.toStringAsFixed(1)} km/h (> 15 km/h limit). High spray drift risk.',
                          actionRequired: 'Postpone all pesticide and foliar spraying until wind speeds drop below 15 km/h.',
                          icon: 'wind',
                        )
                      else if (w.isRainExpected24h || w.humidity >= 80 || w.totalRainForecast3daysMm > 0)
                        WeatherAlertItem(
                          level: 'advisory',
                          title: '🌧️ Rain / High Humidity Alert (Halt Irrigation)',
                          message: 'High humidity (${w.humidity}%) or rain detected. Soil moisture is sufficient.',
                          actionRequired: 'Stop all drip, sprinkler, and canal irrigation to prevent root rot.',
                          icon: 'cloud-rain',
                        )
                      else
                        WeatherAlertItem(
                          level: 'optimal',
                          title: '🌿 Optimal Farming Conditions',
                          message: 'Favorable weather conditions for field operations.',
                          actionRequired: 'Good window for spraying, sowing, fertilizing, and standard irrigation.',
                          icon: 'check-circle',
                        )
                    ])
              .map((alert) => _buildAlertCard(alert, isDark, loc)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(WeatherAlertItem alert, bool isDark, LocalizationService loc) {
    final color = _alertLevelColor(alert.level);
    final localizedTitle = _getLocalizedAlertTitle(alert.title, loc);
    final localizedMessage = _getLocalizedAlertMessage(alert.title, alert.message, loc);
    final localizedAction = _getLocalizedAlertAction(alert.title, alert.actionRequired, loc);
    final localizedLevel = _getLocalizedAlertLevel(alert.level, loc);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_alertIcon(alert.level), color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizedTitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  localizedLevel,
                  style: TextStyle(
                      color: color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            localizedMessage,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.task_alt_rounded, color: color, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: '${loc.tr('action_required')}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: localizedAction,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideX(begin: -0.05, end: 0);
  }

  String _getLocalizedAlertTitle(String rawTitle, LocalizationService loc) {
    final t = rawTitle.toLowerCase();
    if (t.contains('spray') || (t.contains('wind') && t.contains('hazard'))) {
      return loc.tr('alert_wind_spray_title');
    } else if (t.contains('irrigation') || (t.contains('rain') && t.contains('halt'))) {
      return loc.tr('alert_irrigation_halt_title');
    } else if (t.contains('heavy rain') || t.contains('inundation')) {
      return loc.tr('alert_heavy_rain_title');
    } else if (t.contains('fungal') || t.contains('blast') || t.contains('blight') || t.contains('leaf spot')) {
      return loc.tr('alert_fungal_title');
    } else if (t.contains('wind') || t.contains('velocity') || t.contains('gust')) {
      return loc.tr('alert_wind_title');
    } else if (t.contains('heat') || t.contains('evapotranspiration') || t.contains('temperature')) {
      return loc.tr('alert_heat_title');
    } else if (t.contains('optimal') || t.contains('window') || t.contains('safe') || t.contains('favorable') || t.contains('condition')) {
      return loc.tr('alert_optimal_title');
    }
    return rawTitle;
  }

  String _getLocalizedAlertMessage(String rawTitle, String rawMsg, LocalizationService loc) {
    final t = rawTitle.toLowerCase();
    if (t.contains('spray') || (t.contains('wind') && t.contains('hazard'))) {
      return loc.tr('alert_wind_spray_msg');
    } else if (t.contains('irrigation') || (t.contains('rain') && t.contains('halt'))) {
      return loc.tr('alert_irrigation_halt_msg');
    } else if (t.contains('heavy rain') || t.contains('inundation')) {
      return loc.tr('alert_heavy_rain_msg');
    } else if (t.contains('fungal') || t.contains('blast') || t.contains('blight')) {
      return loc.tr('alert_fungal_msg');
    } else if (t.contains('wind') || t.contains('velocity')) {
      return loc.tr('alert_wind_msg');
    } else if (t.contains('heat') || t.contains('evapotranspiration')) {
      return loc.tr('alert_heat_msg');
    } else if (t.contains('optimal') || t.contains('window') || t.contains('safe') || t.contains('condition')) {
      return loc.tr('alert_optimal_msg');
    }
    return rawMsg;
  }

  String _getLocalizedAlertAction(String rawTitle, String rawAction, LocalizationService loc) {
    final t = rawTitle.toLowerCase();
    if (t.contains('spray') || (t.contains('wind') && t.contains('hazard'))) {
      return loc.tr('alert_wind_spray_action');
    } else if (t.contains('irrigation') || (t.contains('rain') && t.contains('halt'))) {
      return loc.tr('alert_irrigation_halt_action');
    } else if (t.contains('heavy rain') || t.contains('inundation')) {
      return loc.tr('alert_heavy_rain_action');
    } else if (t.contains('fungal') || t.contains('blast') || t.contains('blight')) {
      return loc.tr('alert_fungal_action');
    } else if (t.contains('wind') || t.contains('velocity')) {
      return loc.tr('alert_wind_action');
    } else if (t.contains('heat') || t.contains('evapotranspiration')) {
      return loc.tr('alert_heat_action');
    } else if (t.contains('optimal') || t.contains('window') || t.contains('safe') || t.contains('condition')) {
      return loc.tr('alert_optimal_action');
    }
    return rawAction;
  }

  String _getLocalizedAlertLevel(String level, LocalizationService loc) {
    switch (level.toLowerCase()) {
      case 'critical':
        return loc.tr('level_critical');
      case 'warning':
        return loc.tr('level_warning');
      case 'advisory':
        return loc.tr('level_advisory');
      default:
        return loc.tr('level_safe');
    }
  }

  Widget _buildQuickActions(LocalizationService loc, bool isDark) {
    final actions = [
      {
        'title': loc.tr('ai_chat_title'),
        'subtitle': loc.tr('ai_chat_desc'),
        'icon': Icons.smart_toy_rounded,
        'gradient': const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'route': () => const AiChatScreen(),
      },
      {
        'title': loc.tr('disease_scan_title'),
        'subtitle': loc.tr('disease_scan_desc'),
        'icon': Icons.biotech_rounded,
        'gradient': const LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFEF6C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'route': () => const DiseaseDetectionScreen(),
      },
      {
        'title': loc.tr('crop_advisor_title'),
        'subtitle': loc.tr('crop_advisor_desc'),
        'icon': Icons.grass_rounded,
        'gradient': const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'route': () => CropRecommendationScreen(lat: _lat, lon: _lon),
      },
      {
        'title': loc.tr('market_rates_title'),
        'subtitle': loc.tr('market_rates_desc'),
        'icon': Icons.show_chart_rounded,
        'gradient': const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        'route': () => MarketRatesScreen(
          lat: _lat,
          lon: _lon,
          state: _state,
          district: _district,
        ),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('quick_actions'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: actions.length,
            itemBuilder: (_, i) {
              final action = actions[i];
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => (action['route'] as Function())())),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: action['gradient'] as LinearGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(action['icon'] as IconData,
                          color: Colors.white70, size: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              action['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action['subtitle'] as String,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 9.5,
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 80 * i))
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopCropsSection(LocalizationService loc, bool isDark) {
    if (_cropsLoading) return _buildShimmerBox(height: 220);
    if (_crops == null || _crops!.bestCrops.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.tr('best_crops_heading'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            CropRecommendationScreen(lat: _lat, lon: _lon))),
                child: Text(loc.tr('view_all'),
                    style:
                        const TextStyle(color: AgriColors.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AgriColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    color: AgriColors.harvestGold, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _crops!.detectedSeason,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AgriColors.primaryGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 235,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _crops!.bestCrops.length,
              itemBuilder: (_, i) =>
                  _buildCropCard(_crops!.bestCrops[i], isDark),
            ),
          ),
          if (_crops!.cropsToAvoid.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...(_crops!.cropsToAvoid.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AgriColors.alertCritical.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AgriColors.alertCritical.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.do_not_disturb_on_rounded,
                          color: AgriColors.alertCritical, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Avoid ${c.crop}: ',
                                style: const TextStyle(
                                  color: AgriColors.alertCritical,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              TextSpan(
                                text: c.reason,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )))
          ],
        ],
      ),
    );
  }

  Widget _buildCropCard(RecommendedCrop crop, bool isDark) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? AgriColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AgriColors.primaryGreen.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        crop.cropName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AgriColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${crop.suitabilityScore}%',
                        style: const TextStyle(
                          color: AgriColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  crop.scientificName,
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontStyle: FontStyle.italic,
                      color: AgriColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 6),
            _cropInfoRow(Icons.payments_outlined, crop.estimatedProfitPerAcreInr),
            const SizedBox(height: 4),
            _cropInfoRow(Icons.water_drop_outlined, crop.waterRequirement),
            const SizedBox(height: 4),
            _cropInfoRow(Icons.timer_outlined,
                '${crop.growthDurationDays} Days'),
            if (crop.strictWarning != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AgriColors.alertWarning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⚠️ ${crop.strictWarning}',
                  style: const TextStyle(
                      fontSize: 9,
                      color: AgriColors.alertWarning,
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cropInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AgriColors.primaryMedium),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 10.5, color: AgriColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketTicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketRatesScreen(
              lat: _lat,
              lon: _lon,
              state: _state,
              district: _district,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF37474F), Color(0xFF455A64)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded,
                      color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Mandi Rates',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'View All →',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniRateTile(
                      name: 'Turmeric', price: '₹15,200', trend: 'UP'),
                  _MiniRateTile(name: 'Tomato', price: '₹420', trend: 'UP'),
                  _MiniRateTile(
                      name: 'Shallots', price: '₹58', trend: 'UP'),
                  _MiniRateTile(name: 'Potato', price: '₹1,350', trend: 'STABLE'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceFAB(LocalizationService loc) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
      child: Container(
        height: 62,
        width: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AgriColors.primaryGreen.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 2.seconds, color: Colors.greenAccent.withOpacity(0.3));
  }

  Widget _buildBottomNav(LocalizationService loc) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 'Home', true),
            _navItem(Icons.grass_rounded, 'Crops', false, onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CropRecommendationScreen(lat: _lat, lon: _lon)));
            }),
            const SizedBox(width: 60),
            _navItem(Icons.biotech_rounded, 'Scan', false, onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DiseaseDetectionScreen()));
            }),
            _navItem(Icons.bar_chart_rounded, 'Market', false, onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketRatesScreen(
                    lat: _lat,
                    lon: _lon,
                    state: _state,
                    district: _district,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active
                    ? AgriColors.primaryGreen
                    : AgriColors.textMuted,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? AgriColors.primaryGreen
                      : AgriColors.textMuted,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1.2.seconds, color: Colors.grey.shade100);
  }

  Widget _buildErrorCard(String message, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AgriColors.cardDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: AgriColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: AgriColors.textMuted))),
      ]),
    );
  }

  Widget _buildLocatingCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AgriColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: AgriColors.primaryGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              '🛰️ Detecting Live Satellite GPS...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Auto-detecting your farm coordinates for hyper-local weather & crop advice',
              textAlign: TextAlign.center,
              style: TextStyle(color: AgriColors.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPromptCard(bool isDark) {
    final status = _locationResult?.status ?? LocationStatus.serviceDisabled;
    String title;
    String message;
    String buttonText;
    IconData icon;
    VoidCallback action;

    switch (status) {
      case LocationStatus.serviceDisabled:
        title = '🛰️ GPS Location Services Disabled';
        message = 'Turn ON your device GPS so Smart Agri can detect live local weather and calculate soil/crop recommendations.';
        buttonText = 'Enable Location Services (GPS)';
        icon = Icons.location_off_rounded;
        action = () async {
          await LocationService.openLocationSettings();
          _fetchLocationAndData();
        };
        break;
      case LocationStatus.permissionDenied:
        title = '📍 Location Permission Required';
        message = 'Please allow location permission to auto-detect your real-time farm coordinates and live weather risk alerts.';
        buttonText = 'Grant Location Permission';
        icon = Icons.near_me_disabled_rounded;
        action = () async {
          await LocationService.requestPermission();
          _fetchLocationAndData();
        };
        break;
      case LocationStatus.permissionDeniedForever:
        title = '🔒 Location Access Denied';
        message = 'Location permission is permanently denied. Please grant permission in App Settings to enable live farm weather detection.';
        buttonText = 'Open App Settings';
        icon = Icons.lock_outline_rounded;
        action = () async {
          await LocationService.openAppSettings();
        };
        break;
      default:
        title = '⚠️ GPS Acquisition Failed';
        message = _locationResult?.errorMessage ?? 'Could not detect your GPS location.';
        buttonText = 'Retry GPS Detection';
        icon = Icons.refresh_rounded;
        action = () => _fetchLocationAndData();
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AgriColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AgriColors.alertWarning.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AgriColors.alertWarning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AgriColors.alertWarning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Color _alertLevelColor(String level) {
    switch (level) {
      case 'critical':
        return AgriColors.alertCritical;
      case 'warning':
        return AgriColors.alertWarning;
      case 'advisory':
        return AgriColors.alertAdvisory;
      default:
        return AgriColors.alertSafe;
    }
  }

  IconData _alertIcon(String level) {
    switch (level) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.report_problem_rounded;
      case 'advisory':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _weatherEmoji(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder') || c.contains('storm')) return '⛈️';
    if (c.contains('heavy rain') || c.contains('moderate rain')) return '🌧️';
    if (c.contains('rain') || c.contains('shower') || c.contains('drizzle')) return '🌦️';
    if (c.contains('cloud')) return '☁️';
    if (c.contains('fog') || c.contains('mist')) return '🌫️';
    if (c.contains('snow')) return '❄️';
    if (c.contains('wind')) return '💨';
    return '☀️';
  }
}

class _MiniRateTile extends StatelessWidget {
  final String name;
  final String price;
  final String trend;
  const _MiniRateTile(
      {required this.name, required this.price, required this.trend});

  @override
  Widget build(BuildContext context) {
    final trendColor = trend == 'UP'
        ? Colors.greenAccent
        : trend == 'DOWN'
            ? Colors.redAccent
            : Colors.grey;
    final trendIcon = trend == 'UP'
        ? '↑'
        : trend == 'DOWN'
            ? '↓'
            : '→';
    return Column(
      children: [
        Text(name,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 3),
        Text(price,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        Text(trendIcon,
            style: TextStyle(color: trendColor, fontSize: 13)),
      ],
    );
  }
}
