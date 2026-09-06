class DiseaseDetectionResponse {
  final String plantName;
  final String diseaseIdentified;
  final bool isHealthy;
  final double confidenceScorePct;
  final String severityLevel;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> organicRemedies;
  final List<String> chemicalTreatments;
  final List<String> preventiveMeasures;
  final String visualAlertColor;

  DiseaseDetectionResponse({
    required this.plantName,
    required this.diseaseIdentified,
    required this.isHealthy,
    required this.confidenceScorePct,
    required this.severityLevel,
    required this.symptoms,
    required this.causes,
    required this.organicRemedies,
    required this.chemicalTreatments,
    required this.preventiveMeasures,
    required this.visualAlertColor,
  });

  factory DiseaseDetectionResponse.fromJson(Map<String, dynamic> json) {
    return DiseaseDetectionResponse(
      plantName: json['plant_name'] ?? 'Crop',
      diseaseIdentified: json['disease_identified'] ?? 'Unknown Condition',
      isHealthy: json['is_healthy'] ?? false,
      confidenceScorePct: (json['confidence_score_pct'] as num?)?.toDouble() ?? 85.0,
      severityLevel: json['severity_level'] ?? 'Moderate',
      symptoms: (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      causes: (json['causes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      organicRemedies: (json['organic_remedies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      chemicalTreatments: (json['chemical_treatments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      preventiveMeasures: (json['preventive_measures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      visualAlertColor: json['visual_alert_color'] ?? '#FF9800',
    );
  }
}
