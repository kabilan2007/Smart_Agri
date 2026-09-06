import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/market_rate_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MarketRatesScreen extends StatefulWidget {
  final double? lat;
  final double? lon;
  final String? state;
  final String? district;

  const MarketRatesScreen({
    super.key,
    this.lat,
    this.lon,
    this.state,
    this.district,
  });

  @override
  State<MarketRatesScreen> createState() => _MarketRatesScreenState();
}

class _MarketRatesScreenState extends State<MarketRatesScreen>
    with SingleTickerProviderStateMixin {
  MarketRatesResponse? _data;
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedDistrict = 'All Nearby';
  String? _detectedDistrict;
  String? _state;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  double? _lat;
  double? _lon;

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Grains',
    'Pulses',
    'Spices',
    'Cash Crops',
  ];

  final List<String> _districts = [
    'All Nearby',
    'Coimbatore',
    'Tiruppur',
    'Oddanchatram / Dindigul',
    'Mettupalayam / Nilgiris',
    'Erode',
    'Salem',
    'Thanjavur',
  ];

  @override
  void initState() {
    super.initState();
    _lat = widget.lat;
    _lon = widget.lon;
    _state = widget.state;
    _detectedDistrict = widget.district;

    _tabController =
        TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index < _categories.length) {
        final newCat = _categories[_tabController.index];
        if (_selectedCategory != newCat) {
          setState(() => _selectedCategory = newCat);
          _fetchMarketData(query: _searchController.text);
        }
      }
    });

    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    if (_lat == null || _lon == null) {
      try {
        final locProvider = Provider.of<LocationProvider>(context, listen: false);
        if (locProvider.hasLocation) {
          _lat = locProvider.currentLatitude;
          _lon = locProvider.currentLongitude;
          _state = locProvider.currentState;
          _detectedDistrict = locProvider.currentDistrict;
        } else {
          final locRes = await LocationService.getLivePosition();
          if (locRes.isSuccess && locRes.position != null && mounted) {
            _lat = locRes.position!.latitude;
            _lon = locRes.position!.longitude;
            if (locRes.details != null) {
              _detectedDistrict = locRes.details!.district;
              _state = locRes.details!.state;
            }
          }
        }
      } catch (_) {}
    }

    if (_lat != null && _lon != null && (_detectedDistrict == null || _state == null)) {
      try {
        final details = await LocationService.getDetailedLocation(_lat!, _lon!);
        if (details != null && mounted) {
          setState(() {
            _detectedDistrict = details.district ?? details.city;
            _state = details.state;
          });
        }
      } catch (_) {}
    }

    if (_detectedDistrict != null && !_districts.contains(_detectedDistrict)) {
      setState(() {
        _districts.insert(1, _detectedDistrict!);
      });
    }

    _fetchMarketData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarketData({String? query}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final districtParam = _selectedDistrict == 'All Nearby'
        ? _detectedDistrict
        : _selectedDistrict.split(' / ').first;

    final data = await ApiService.getMarketRates(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      query: query,
      lat: _lat,
      lon: _lon,
      state: _state,
      district: districtParam,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('Live Mandi Rates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _detectedDistrict != null
                  ? '📍 Live Mandis near $_detectedDistrict'
                  : 'e-NAM / Agmarknet Market Index',
              style: const TextStyle(fontSize: 10.5, color: AgriColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchMarketData(query: _searchController.text),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(132),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => _fetchMarketData(query: v),
                  decoration: InputDecoration(
                    hintText: 'Search commodity, mandi or district...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AgriColors.textMuted, size: 20),
                    filled: true,
                    fillColor:
                        isDark ? AgriColors.cardDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              // District Chips Row
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _districts.length,
                  itemBuilder: (_, i) {
                    final d = _districts[i];
                    final isSel = _selectedDistrict == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          i == 0 && _detectedDistrict != null ? '📍 $_detectedDistrict (GPS)' : d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: AgriColors.primaryGreen,
                        backgroundColor: isDark ? AgriColors.cardDark : Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDistrict = d);
                            _fetchMarketData(query: _searchController.text);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AgriColors.primaryGreen,
                unselectedLabelColor: AgriColors.textMuted,
                indicatorColor: AgriColors.primaryGreen,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12.5),
                tabs: _categories.map((c) => Tab(text: c)).toList(),
              ),
            ],
          ),
        ),
      ),
               
      body: RefreshIndicator(
        color: AgriColors.primaryGreen,
        onRefresh: () => _fetchMarketData(query: _searchController.text),
        child: _isLoading
            ? _buildShimmer()
            : _data == null
                ? _buildError()
                : _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final commodities = _data!.commodities;
    if (commodities.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AgriColors.cardDark : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.search_off_rounded,
                      color: AgriColors.textMuted, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'No rates found for "${_searchController.text}"'
                      : 'No commodities found in $_selectedCategory',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to refresh or check another category',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AgriColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Market overview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF37474F), Color(0xFF455A64)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded,
                      color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Market Overview — ${_data!.date}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _data!.marketOverview,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),
        // Market Summary stats
        _buildStatRow(commodities),
        const SizedBox(height: 16),
        ...commodities.asMap().entries.map(
              (e) => _buildCommodityCard(e.value, e.key, isDark),
            ),
      ],
    );
  }

  Widget _buildStatRow(List<MarketItem> items) {
    final up = items.where((i) => i.priceTrend == 'UP').length;
    final down = items.where((i) => i.priceTrend == 'DOWN').length;
    final stable = items.where((i) => i.priceTrend == 'STABLE').length;

    return Row(
      children: [
        _statCard('↑ Rising', up.toString(), Colors.green),
        const SizedBox(width: 8),
        _statCard('↓ Falling', down.toString(), Colors.red),
        const SizedBox(width: 8),
        _statCard('→ Stable', stable.toString(), Colors.blue),
        const SizedBox(width: 8),
        _statCard('Total', items.length.toString(), AgriColors.primaryGreen),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(
                    color: AgriColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommodityCard(MarketItem item, int index, bool isDark) {
    final isUp = item.priceTrend == 'UP';
    final isDown = item.priceTrend == 'DOWN';
    final trendColor = isUp
        ? const Color(0xFF388E3C)
        : isDown
            ? const Color(0xFFD32F2F)
            : const Color(0xFF1976D2);
    final trendIcon = isUp ? '↑' : isDown ? '↓' : '→';
    final changeText = item.priceChange24hPct != 0.0
        ? '${item.priceChange24hPct > 0 ? '+' : ''}${item.priceChange24hPct.toStringAsFixed(1)}%'
        : '0.0%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AgriColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: trendColor.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _categoryColor(item.category).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _categoryEmoji(item.category),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.commodity,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: AgriColors.textMuted),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${item.mandiName}, ${item.state}',
                        style: const TextStyle(
                            fontSize: 11, color: AgriColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Min ₹${item.minPrice.toStringAsFixed(0)} → Max ₹${item.maxPrice.toStringAsFixed(0)} ${item.unit}',
                  style: const TextStyle(
                      fontSize: 10.5, color: AgriColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.modalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 2),
              Text(
                item.unit.replaceAll('₹ / ', '/ '),
                style: const TextStyle(
                    fontSize: 9.5, color: AgriColors.textMuted),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$trendIcon $changeText',
                  style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildShimmer() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1.2.seconds),
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Container(
                height: 55,
                margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1.2.seconds),
        const SizedBox(height: 16),
        ...List.generate(
          6,
          (i) => Container(
            height: 84,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1.2.seconds),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Market Data Unavailable',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Could not retrieve live mandi rates. Please check your network connection and retry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AgriColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _fetchMarketData(query: _searchController.text),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Vegetables':
        return Colors.green;
      case 'Grains':
        return Colors.amber;
      case 'Pulses':
        return Colors.orange;
      case 'Spices':
        return Colors.deepOrange;
      case 'Cash Crops':
        return Colors.purple;
      default:
        return AgriColors.primaryGreen;
    }
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Vegetables':
        return '🥦';
      case 'Grains':
        return '🌾';
      case 'Pulses':
        return '🫘';
      case 'Spices':
        return '🌶️';
      case 'Cash Crops':
        return '🏭';
      default:
        return '🌱';
    }
  }
}
