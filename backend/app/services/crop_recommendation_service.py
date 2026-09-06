import datetime
from typing import List, Dict, Any, Optional
from app.models.schemas import CropRecommendationRequest, CropRecommendationResponse, RecommendedCrop

class CropRecommendationService:
    @staticmethod
    def detect_season(month: Optional[int] = None) -> str:
        """Determines agricultural season in Indian / Tropical climate"""
        if month is None:
            month = datetime.date.today().month
            
        if 6 <= month <= 10:
            return "Kharif (Monsoon Season - Jun to Oct)"
        elif month in [11, 12, 1, 2]:
            return "Rabi (Winter / Post-Monsoon - Nov to Feb)"
        else:
            return "Zaid (Summer Season - Mar to May)"

    @staticmethod
    def get_crop_matrix(soil_type: str, season_str: str, water_source: str) -> Dict[str, Any]:
        s_norm = soil_type.lower()
        
        # Knowledge Base Matrix
        crops: List[RecommendedCrop] = []
        avoid_crops: List[Dict[str, str]] = []
        advice = ""

        is_monsoon = "kharif" in season_str.lower()
        is_winter = "rabi" in season_str.lower()
        is_summer = "zaid" in season_str.lower()
        is_low_water = "rainfed" in water_source.lower() or "drip" in water_source.lower()

        # Soil & Season Rules
        if "red" in s_norm:
            advice = "Red soil has good drainage, rich in iron and manganese, but tends to be low in nitrogen and phosphorus. Enhance organic matter with well-rotted FYM (Farmyard Manure) or Vermicompost."
            
            if is_monsoon:
                crops.append(RecommendedCrop(
                    crop_name="Groundnut (Peanut)",
                    scientific_name="Arachis hypogaea",
                    variety_recommendations=["TMV-7", "Kadiri-6", "TAG-24", "VRI-8"],
                    suitability_score=96,
                    growth_duration_days=105,
                    expected_yield_per_acre="14 - 18 Quintals",
                    estimated_profit_per_acre_inr="₹45,000 - ₹65,000",
                    water_requirement="Medium (350-450mm)",
                    irrigation_schedule="Critical irrigations at Flowering (30-35 DAS) and Pegging stage (45-50 DAS).",
                    fertilizer_plan={
                        "Basal": "NPK 10:20:30 kg/acre + 200kg Gypsum during last ploughing.",
                        "Top-Dressing": "Apply 100kg Gypsum at 40-45 days along with earthing up."
                    },
                    why_recommended="Light-textured red loam allows easy peg penetration and excellent pod development without pod rot.",
                    strict_warning="Do not flood fields during pod filling stage."
                ))
                crops.append(RecommendedCrop(
                    crop_name="Finger Millet (Ragi)",
                    scientific_name="Eleusine coracana",
                    variety_recommendations=["GPU-28", "ML-365", "Co-14", "Paiyur-2"],
                    suitability_score=92,
                    growth_duration_days=110,
                    expected_yield_per_acre="16 - 20 Quintals",
                    estimated_profit_per_acre_inr="₹35,000 - ₹48,000",
                    water_requirement="Low (300-350mm)",
                    irrigation_schedule="Can thrive under rainfed conditions. 3-4 life-saving irrigations if rain fails.",
                    fertilizer_plan={
                        "Basal": "FYM 5 tonnes + NPK 25:12:12 kg/acre.",
                        "Top-Dressing": "Urea 12 kg/acre at 25 days after transplanting."
                    },
                    why_recommended="Highly resilient drought-tolerant super-millet with high market demand for nutritional value.",
                    strict_warning=None
                ))
                crops.append(RecommendedCrop(
                    crop_name="Hybrid Tomato",
                    scientific_name="Solanum lycopersicum",
                    variety_recommendations=["Arka Rakshak (Triple disease resistant)", "Abhinav (Syngenta)", "Shivam"],
                    suitability_score=89,
                    growth_duration_days=120,
                    expected_yield_per_acre="25 - 35 Tonnes",
                    estimated_profit_per_acre_inr="₹1,20,000 - ₹2,50,000",
                    water_requirement="Medium (Drip Fertigation Recommended)",
                    irrigation_schedule="Alternate day drip irrigation (1.5 - 2 hours).",
                    fertilizer_plan={
                        "Basal": "Well-decomposed cattle manure 10 tonnes + DAP 50kg + MOP 30kg.",
                        "Fertigation": "19:19:19 water-soluble grade weekly twice starting day 15."
                    },
                    why_recommended="Red soils provide rapid root aeration preventing bacterial wilt under proper ridge & furrow method.",
                    strict_warning="Install yellow sticky traps (15/acre) to control whitefly vector of TLCV."
                ))
                
                avoid_crops.append({
                    "crop": "Paddy / Rice (Lowland)",
                    "reason": "Red soils have high percolation rates, requiring 3x more water to maintain puddle conditions. Highly uneconomical."
                })

            else:
                # Winter / Summer for Red soil
                crops.append(RecommendedCrop(
                    crop_name="Black Gram / Green Gram (Pulses)",
                    scientific_name="Vigna mungo / Vigna radiata",
                    variety_recommendations=["VBN-6", "VBN-8", "IPM-0205-7 (Virat)"],
                    suitability_score=94,
                    growth_duration_days=65,
                    expected_yield_per_acre="6 - 8 Quintals",
                    estimated_profit_per_acre_inr="₹30,000 - ₹42,000",
                    water_requirement="Low (200-250mm)",
                    irrigation_schedule="Sowing irrigation, flowering stage (25-30 DAS), and pod formation (45 DAS).",
                    fertilizer_plan={
                        "Basal": "DAP 25kg + Gypsum 40kg + Rhizobium seed treatment @ 200g/acre.",
                        "Foliar": "Foliar spray of 2% DAP or Pulse Wonder @ 2kg/acre at peak flowering."
                    },
                    why_recommended="Short 65-day crop fixes atmospheric nitrogen, restoring red soil fertility with minimal water.",
                    strict_warning=None
                ))
                crops.append(RecommendedCrop(
                    crop_name="Turmeric (Long Duration Cash Crop)",
                    scientific_name="Curcuma longa",
                    variety_recommendations=["Prathibha", "BSR-2", "Salem Local"],
                    suitability_score=91,
                    growth_duration_days=240,
                    expected_yield_per_acre="22 - 28 Quintals (Dry Rhizome)",
                    estimated_profit_per_acre_inr="₹1,80,000 - ₹3,00,000",
                    water_requirement="High (Drip essential in red soil)",
                    irrigation_schedule="Drip every 2 days with micronutrient fertigation.",
                    fertilizer_plan={
                        "Basal": "Vermicompost 2 tonnes + Neem cake 200kg + Trichoderma 2kg/acre.",
                        "Top-Dressing": "Micronutrient mixture spray at 60th and 90th day."
                    },
                    why_recommended="Well-drained red soils produce bright yellow curcumin-rich rhizomes with zero root rotting.",
                    strict_warning="Ensure drip system is operational before planting."
                ))

        elif "black" in s_norm:
            advice = "Black Cotton soil (Regur) is rich in montmorillonite clay, with tremendous water retention capacity, high calcium carbonate, and potassium. Avoid over-irrigation."
            
            crops.append(RecommendedCrop(
                crop_name="Bt Cotton (High Yielding)",
                scientific_name="Gossypium hirsutum",
                variety_recommendations=["Bollgard II hybrids", "RCH 659", "Ajeet 155"],
                suitability_score=97,
                growth_duration_days=150,
                expected_yield_per_acre="12 - 16 Quintals",
                estimated_profit_per_acre_inr="₹70,000 - ₹1,10,000",
                water_requirement="Medium (Deep moisture retention in black soil)",
                irrigation_schedule="Irrigate every 12-15 days depending on soil cracking. Avoid standing water.",
                fertilizer_plan={
                    "Basal": "NPK 12:32:16 @ 50kg/acre.",
                    "Split Doses": "Urea 30kg + Potash 20kg at square formation and peak boll bursting."
                },
                why_recommended="Black cotton soil's high swelling-shrinking index provides self-mulching and deep moisture storage for bolls.",
                strict_warning="Avoid planting in waterlogged lowlands to prevent Para-wilt."
            ))
            crops.append(RecommendedCrop(
                crop_name="Soybean",
                scientific_name="Glycine max",
                variety_recommendations=["JS 335", "JS 9560", "NRC 37"],
                suitability_score=93,
                growth_duration_days=95,
                expected_yield_per_acre="10 - 14 Quintals",
                estimated_profit_per_acre_inr="₹40,000 - ₹55,000",
                water_requirement="Medium (350mm)",
                irrigation_schedule="Usually rainfed in black soils. 1 protective irrigation during pod fill if dry spell exceeds 15 days.",
                fertilizer_plan={
                    "Basal": "Single Super Phosphate (SSP) 150kg + MOP 20kg + Bradyrhizobium inoculant.",
                    "Foliar": "00:52:34 (MKP) 1kg/100L at pod filling."
                },
                why_recommended="Highly compatible with black clay's cation exchange capacity; excellent oil content.",
                strict_warning=None
            ))
            avoid_crops.append({
                "crop": "Groundnut (during heavy monsoon)",
                "reason": "Black clay turns sticky when wet and hard when dry, causing up to 40% pod loss during harvesting."
            })

        elif "alluvial" in s_norm or "loam" in s_norm:
            advice = "Alluvial soil is the most fertile agricultural soil, enriched with silt and potash. Ideal for intensive multi-cropping."
            
            crops.append(RecommendedCrop(
                crop_name="Banana (Tissue Culture Grand Naine)",
                scientific_name="Musa acuminata",
                variety_recommendations=["Grand Naine (G9)", "Nendran", "Red Banana"],
                suitability_score=98,
                growth_duration_days=330,
                expected_yield_per_acre="35 - 45 Tonnes (1200 plants/acre)",
                estimated_profit_per_acre_inr="₹2,50,000 - ₹4,50,000",
                water_requirement="High (Drip Irrigation required)",
                irrigation_schedule="Daily drip irrigation (15-20 liters per plant depending on temperature).",
                fertilizer_plan={
                    "Basal": "10kg FYM + 250g Neem cake per pit.",
                    "Monthly Fertigation": "Soluble Nitrogen and Potash (Urea + MOP) in 24 split doses."
                },
                why_recommended="Deep alluvial silt supports vigorous root growth and heavy bunch weights (30-35 kg/bunch).",
                strict_warning="Ensure windbreak trees (Sesbania/Agathi) around farm boundary."
            ))
            crops.append(RecommendedCrop(
                crop_name="Sugarcane (Co 0238 / Co 86032)",
                scientific_name="Saccharum officinarum",
                variety_recommendations=["Co 86032 (Nayana)", "Co 0238", "CoC 24"],
                suitability_score=94,
                growth_duration_days=360,
                expected_yield_per_acre="55 - 75 Tonnes",
                estimated_profit_per_acre_inr="₹1,50,000 - ₹2,30,000",
                water_requirement="High",
                irrigation_schedule="Irrigate every 7-10 days in alluvium.",
                fertilizer_plan={
                    "Basal": "DAP 100kg + Potash 50kg + Zinc Sulphate 10kg/acre.",
                    "Top-Dressing": "Urea top dressing at 45, 90, and 120 days."
                },
                why_recommended="Rich organic deposits in alluvium ensure highest sugar recovery percentage.",
                strict_warning=None
            ))

        elif "clay" in s_norm:
            advice = "Clay soil holds moisture for long periods and is prone to water stagnation. Suitable for water-loving crops or crops raised on raised beds."
            
            crops.append(RecommendedCrop(
                crop_name="Paddy / Rice (Short/Medium Duration)",
                scientific_name="Oryza sativa",
                variety_recommendations=["CO 51", "ADT 53", "IR 64", "BPT 5204 (Samba Mahsuri)"],
                suitability_score=95,
                growth_duration_days=115,
                expected_yield_per_acre="24 - 30 Quintals",
                estimated_profit_per_acre_inr="₹40,000 - ₹58,000",
                water_requirement="High (Standing water 2-5cm)",
                irrigation_schedule="Alternate Wetting and Drying (AWD) to save 30% water.",
                fertilizer_plan={
                    "Basal": "DAP 50kg + MOP 25kg + Zinc 10kg.",
                    "Top-Dressing": "Urea with neem coating in 3 splits at tillering and panicle initiation."
                },
                why_recommended="Clay creates an impermeable hardpan, preventing water percolation and retaining nutrients.",
                strict_warning="If borewell water is saline, apply 500kg Gypsum per acre."
            ))
            avoid_crops.append({
                "crop": "Carrot / Potato / Root Tubers",
                "reason": "Heavy clay restricts root expansion, leading to deformed tubers and fungal tuber rot."
            })
            
        else: # Sandy / Laterite / Default
            advice = "Sandy/Laterite soil has rapid drainage and low nutrient retention. Frequent light irrigations and high organic manuring are crucial."
            
            crops.append(RecommendedCrop(
                crop_name="Cashewnut / Coconut Plantation",
                scientific_name="Anacardium occidentale / Cocos nucifera",
                variety_recommendations=["VRI-3 Cashew", "Dwarf x Tall Coconut Hybrids"],
                suitability_score=92,
                growth_duration_days=365,
                expected_yield_per_acre="High Long-term Perennial Yield",
                estimated_profit_per_acre_inr="₹80,000 - ₹1,60,000/year",
                water_requirement="Medium",
                irrigation_schedule="Basin irrigation or 4-point drip emitters per tree.",
                fertilizer_plan={
                    "Annual Dose": "50kg Compost + 1.3kg Urea + 2kg SSP + 2kg MOP per tree in 2 splits."
                },
                why_recommended="Laterite and sandy loam soils prevent root asphyxiation and facilitate deep taproot penetration.",
                strict_warning="Mulch tree basins heavily with coconut coir pith to retain moisture."
            ))

        # Strict water enforcement rule:
        if is_low_water:
            # Filter out extreme water-guzzling crops if farmer marked low water
            avoid_crops.append({
                "crop": "Lowland Flood Paddy / Sugarcane",
                "reason": "Water availability is low/rainfed. Planting high water-consumption crops will risk complete crop failure at heading stage."
            })

        return {
            "crops": crops,
            "avoid_crops": avoid_crops,
            "advice": advice
        }

    @staticmethod
    def recommend_crops(req: CropRecommendationRequest) -> CropRecommendationResponse:
        season = req.season or CropRecommendationService.detect_season(req.month)
        loc = req.location_name or "Agri Field Hub"
        
        matrix_result = CropRecommendationService.get_crop_matrix(
            soil_type=req.soil_type,
            season_str=season,
            water_source=req.water_source or "Borewell"
        )
        
        weather_sum = f"Detected {season} season. Soil profile matches {req.soil_type} with {req.water_source} irrigation conditions."

        return CropRecommendationResponse(
            detected_season=season,
            soil_analyzed=req.soil_type,
            location=loc,
            weather_summary=weather_sum,
            best_crops=matrix_result["crops"],
            crops_to_avoid=matrix_result["avoid_crops"],
            general_soil_advice=matrix_result["advice"]
        )
