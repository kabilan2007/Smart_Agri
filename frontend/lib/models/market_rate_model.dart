class MarketItem {
  final String commodity;
  final String category;
  final String mandiName;
  final String state;
  final String unit;
  final double modalPrice;
  final double minPrice;
  final double maxPrice;
  final String priceTrend; // 'UP', 'DOWN', 'STABLE'
  final double priceChange24hPct;
  final String lastUpdated;

  MarketItem({
    required this.commodity,
    required this.category,
    required this.mandiName,
    required this.state,
    required this.unit,
    required this.modalPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.priceTrend,
    required this.priceChange24hPct,
    required this.lastUpdated,
  });

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    return MarketItem(
      commodity: json['commodity']?.toString() ?? 'Commodity',
      category: json['category']?.toString() ?? 'General',
      mandiName: json['mandi_name']?.toString() ?? json['mandiName']?.toString() ?? 'Local APMC Mandi',
      state: json['state']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '₹ / Quintal',
      modalPrice: _parseDouble(json['modal_price'] ?? json['modalPrice']),
      minPrice: _parseDouble(json['min_price'] ?? json['minPrice']),
      maxPrice: _parseDouble(json['max_price'] ?? json['maxPrice']),
      priceTrend: (json['price_trend']?.toString() ?? json['priceTrend']?.toString() ?? 'STABLE').toUpperCase(),
      priceChange24hPct: _parseDouble(json['price_change_24h_pct'] ?? json['priceChange24hPct']),
      lastUpdated: json['last_updated']?.toString() ?? json['lastUpdated']?.toString() ?? 'Today',
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }
}

class MarketRatesResponse {
  final String marketOverview;
  final String date;
  final List<MarketItem> commodities;

  MarketRatesResponse({
    required this.marketOverview,
    required this.date,
    required this.commodities,
  });

  factory MarketRatesResponse.fromJson(Map<String, dynamic> json) {
    List<MarketItem> items = [];
    if (json['commodities'] is List) {
      for (var item in (json['commodities'] as List)) {
        if (item != null && item is Map<String, dynamic>) {
          try {
            items.add(MarketItem.fromJson(item));
          } catch (_) {}
        }
      }
    }
    return MarketRatesResponse(
      marketOverview: json['market_overview']?.toString() ??
          json['marketOverview']?.toString() ??
          'Market trends are stable across major APMC Mandis.',
      date: json['date']?.toString() ?? 'Today',
      commodities: items,
    );
  }
}
