class WeatherAlertItem {
  final String level;
  final String title;
  final String message;
  final String actionRequired;
  final String icon;

  WeatherAlertItem({
    required this.level,
    required this.title,
    required this.message,
    required this.actionRequired,
    this.icon = 'alert',
  });

  factory WeatherAlertItem.fromJson(Map<String, dynamic> json) {
    return WeatherAlertItem(
      level: json['level'] ?? 'advisory',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      actionRequired: json['action_required'] ?? '',
      icon: json['icon'] ?? 'alert',
    );
  }
}

class WeatherForecastDay {
  final String date;
  final String dayName;
  final double tempMin;
  final double tempMax;
  final String condition;
  final int rainProbabilityPct;
  final double rainfallMm;
  final String icon;

  WeatherForecastDay({
    required this.date,
    required this.dayName,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.rainProbabilityPct,
    required this.rainfallMm,
    required this.icon,
  });

  factory WeatherForecastDay.fromJson(Map<String, dynamic> json) {
    return WeatherForecastDay(
      date: json['date'] ?? '',
      dayName: json['day_name'] ?? '',
      tempMin: (json['temp_min'] as num?)?.toDouble() ?? 0.0,
      tempMax: (json['temp_max'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] ?? '',
      rainProbabilityPct: json['rain_probability_pct'] ?? 0,
      rainfallMm: (json['rainfall_mm'] as num?)?.toDouble() ?? 0.0,
      icon: json['icon'] ?? '01d',
    );
  }
}

class WeatherAlertsResponse {
  final String city;
  final String? district;
  final String? state;
  final String country;
  final double temperature;
  final double tempFeelsLike;
  final int humidity;
  final double windSpeedKmh;
  final String condition;
  final String description;
  final String icon;
  final bool isRainExpected24h;
  final double totalRainForecast3daysMm;
  final List<WeatherAlertItem> alerts;
  final List<WeatherForecastDay> forecast;

  WeatherAlertsResponse({
    required this.city,
    this.district,
    this.state,
    required this.country,
    required this.temperature,
    required this.tempFeelsLike,
    required this.humidity,
    required this.windSpeedKmh,
    required this.condition,
    required this.description,
    required this.icon,
    required this.isRainExpected24h,
    required this.totalRainForecast3daysMm,
    required this.alerts,
    required this.forecast,
  });

  factory WeatherAlertsResponse.fromJson(Map<String, dynamic> json) {
    return WeatherAlertsResponse(
      city: json['city'] ?? 'Farm Location',
      district: json['district'],
      state: json['state'],
      country: json['country'] ?? 'India',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 28.0,
      tempFeelsLike: (json['temp_feels_like'] as num?)?.toDouble() ?? 30.0,
      humidity: json['humidity'] ?? 65,
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 10.0,
      condition: json['condition'] ?? 'Clear',
      description: json['description'] ?? 'Sunny and clear',
      icon: json['icon'] ?? '01d',
      isRainExpected24h: json['is_rain_expected_24h'] ?? false,
      totalRainForecast3daysMm: (json['total_rain_forecast_3days_mm'] as num?)?.toDouble() ?? 0.0,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => WeatherAlertItem.fromJson(e))
              .toList() ??
          [],
      forecast: (json['forecast'] as List<dynamic>?)
              ?.map((e) => WeatherForecastDay.fromJson(e))
              .toList() ??
          [],
    );
  }
}
