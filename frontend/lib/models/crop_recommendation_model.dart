class RecommendedCrop {
  final String cropName;
  final String scientificName;
  final List<String> varietyRecommendations;
  final int suitabilityScore;
  final int growthDurationDays;
  final String expectedYieldPerAcre;
  final String estimatedProfitPerAcreInr;
  final String waterRequirement;
  final String irrigationSchedule;
  final Map<String, String> fertilizerPlan;
  final String? strictWarning;
  final String whyRecommended;

  RecommendedCrop({
    required this.cropName,
    this.scientificName = '',
    required this.varietyRecommendations,
    required this.suitabilityScore,
    required this.growthDurationDays,
    required this.expectedYieldPerAcre,
    required this.estimatedProfitPerAcreInr,
    required this.waterRequirement,
    required this.irrigationSchedule,
    required this.fertilizerPlan,
    this.strictWarning,
    required this.whyRecommended,
  });

  factory RecommendedCrop.fromJson(Map<String, dynamic> json) {
    return RecommendedCrop(
      cropName: json['crop_name'] ?? '',
      scientificName: json['scientific_name'] ?? '',
      varietyRecommendations: (json['variety_recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suitabilityScore: json['suitability_score'] ?? 80,
      growthDurationDays: json['growth_duration_days'] ?? 100,
      expectedYieldPerAcre: json['expected_yield_per_acre'] ?? '',
      estimatedProfitPerAcreInr: json['estimated_profit_per_acre_inr'] ?? '',
      waterRequirement: json['water_requirement'] ?? 'Medium',
      irrigationSchedule: json['irrigation_schedule'] ?? '',
      fertilizerPlan: Map<String, String>.from(json['fertilizer_plan'] ?? {}),
      strictWarning: json['strict_warning'],
      whyRecommended: json['why_recommended'] ?? '',
    );
  }
}

class CropToAvoid {
  final String crop;
  final String reason;

  CropToAvoid({required this.crop, required this.reason});

  factory CropToAvoid.fromJson(Map<String, dynamic> json) {
    return CropToAvoid(
      crop: json['crop'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class CropRecommendationResponse {
  final String detectedSeason;
  final String soilAnalyzed;
  final String location;
  final String weatherSummary;
  final List<RecommendedCrop> bestCrops;
  final List<CropToAvoid> cropsToAvoid;
  final String generalSoilAdvice;

  CropRecommendationResponse({
    required this.detectedSeason,
    required this.soilAnalyzed,
    required this.location,
    required this.weatherSummary,
    required this.bestCrops,
    required this.cropsToAvoid,
    required this.generalSoilAdvice,
  });

  factory CropRecommendationResponse.fromJson(Map<String, dynamic> json) {
    return CropRecommendationResponse(
      detectedSeason: json['detected_season'] ?? '',
      soilAnalyzed: json['soil_analyzed'] ?? '',
      location: json['location'] ?? '',
      weatherSummary: json['weather_summary'] ?? '',
      bestCrops: (json['best_crops'] as List<dynamic>?)
              ?.map((e) => RecommendedCrop.fromJson(e))
              .toList() ??
          [],
      cropsToAvoid: (json['crops_to_avoid'] as List<dynamic>?)
              ?.map((e) => CropToAvoid.fromJson(e))
              .toList() ??
          [],
      generalSoilAdvice: json['general_soil_advice'] ?? '',
    );
  }
}
