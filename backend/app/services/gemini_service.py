import json
from typing import List, Dict, Any, Optional
from app.config import settings
from app.models.schemas import AgriChatRequest, AgriChatResponse, ChatMessage

AGRI_SYSTEM_PROMPT = """You are 'Smart Agri AI Doctor' (விவசாய தோழன் / कृषि मित्र), a senior agricultural scientist, agronomist, plant pathologist, and soil doctor.
Your mission is to provide direct, specific, highly actionable, and cost-effective agricultural guidance to farmers.

CRITICAL INSTRUCTIONS:
1. **Direct Specificity**: Address the user's EXACT crop, disease, soil, or farming question directly. Never output generic boilerplate or repeated introductory paragraphs.
2. **Actionable Details**: Include specific fertilizer grades (e.g. NPK 120:60:40 kg/acre), exact pesticide/fungicide dosages per liter (e.g. Chlorantraniliprole 18.5% SC @ 0.3ml/L, Emamectin Benzoate 5% SG @ 0.4g/L), organic alternatives (Panchagavya, NSKE 5%, Trichoderma), and irrigation timing.
3. **Contextual Awareness**: Factor in the farmer's soil type, water source, current season, and GPS location if provided in the context.
4. **Strict Language Rule**: Respond directly in the EXACT language requested by the farmer (Tamil, Hindi, Telugu, Kannada, Malayalam, English, Chinese). Use natural, farmer-friendly terms.
5. **Formatting**: Use clean bullet points, bold key technical terms, and structured sections (Problem Diagnosis, Immediate Action, Organic Option, Chemical Remedy with Dosage, Preventive Steps).
"""

class GeminiService:
    @staticmethod
    def _generate_dynamic_crop_advisory(query: str, lang: str, context: Optional[Dict[str, Any]] = None) -> AgriChatResponse:
        """
        Intelligent dynamic agronomic response generator for when Gemini API key is offline/unreachable.
        Directly speaks to the user's exact crop, pest, disease, or farming inquiry.
        """
        q = query.lower().strip()
        ctx = context or {}
        soil = ctx.get("soil_type", "Standard Soil")
        water = ctx.get("water_source", "Irrigated")
        loc = ctx.get("location_name", "Local Farm")

        # 1. Corn / Maize specific advice
        if any(w in q for w in ["corn", "maize", "மக்காச்சோளம்", "मक्का", "మొక్కజొన్న", "ಮೆಕ್ಕೆಜೋಳ"]):
            if any(w in q for w in ["worm", "pest", "fall armyworm", "படைப்புழு", "कीट", "పురుగు"]):
                reply = (
                    "🌽 **Maize / Corn Fall Armyworm (FAW - Spodoptera frugiperda) Control**:\n\n"
                    "• **Immediate Diagnosis**: Check the central whorl for circular window-pane holes and sawdust-like frass.\n"
                    "• **Organic Remedy**: Spray 5% Neem Seed Kernel Extract (NSKE) @ 50ml/L or *Metarhizium anisopliae* (bio-pesticide) @ 5g/L during early instars.\n"
                    "• **Chemical Dosage (High Infestation)**: Spray **Emamectin Benzoate 5% SG @ 0.4g/L** or **Chlorantraniliprole 18.5% SC @ 0.3ml/L** directly directed into the whorl using knapsack sprayer with cone nozzle.\n"
                    "• **Pheromone Traps**: Install 5 FAW pheromone lure traps per acre for continuous monitoring."
                )
                followups = ["What is the recommended NPK fertilizer schedule for corn?", "How to control stem borer in maize?", "Best hybrid corn seeds for this season"]
            else:
                reply = (
                    "🌽 **Maize / Corn High-Yield Cultivation & Nutrient Management**:\n\n"
                    "• **Recommended Varieties**: CP 818, Pioneer P3522, DKC 9108, TNAU Hybrid Co 6.\n"
                    "• **Fertilizer Schedule (per acre)**:\n"
                    "  - *Basal*: DAP 50 kg + MOP 25 kg + Zinc Sulphate 10 kg (Zinc is critical for corn ear filling).\n"
                    "  - *Knee-High Stage (25 DAS)*: Top dress Urea 35 kg.\n"
                    "  - *Tasseling & Silking (45 DAS)*: Top dress Urea 35 kg + Potash 15 kg.\n"
                    "• **Irrigation Critical Stages**: Flowering (tasseling), Silking, and Grain Filling. Avoid moisture stress at silking.\n"
                    f"• **Soil Suitability**: Thrives well in {soil} with good drainage."
                )
                followups = ["How to control Fall Armyworm in corn?", "What is the water requirement per acre for maize?", "Current market prices for feed corn"]

        # 2. Peanut / Groundnut specific advice
        elif any(w in q for w in ["peanut", "groundnut", "நிலக்கடலை", "मूंगफली", "వేరుశనగ", "ಕಡಲೆಕಾಯಿ"]):
            reply = (
                "🥜 **Groundnut (Peanut) Production & Pod Filling Guide**:\n\n"
                "• **High Yield Varieties**: Kadiri-6, TAG-24, TMV-7, VRI-8 (Spanish bunch type).\n"
                "• **Critical Gypsum Application**: Apply **200 kg/acre Gypsum at 40-45 DAS** (pegging stage) along with earthing up. Calcium in gypsum prevents 'pops' (empty pods) and promotes solid kernel development.\n"
                "• **Seed Inoculation**: Treat seeds with *Rhizobium* (200g/acre) and *Trichoderma viride* (4g/kg seed) to prevent Collar Rot (*Aspergillus niger*).\n"
                "• **Tikka Leaf Spot Control**: If dark circular spots appear on leaves, spray **Mancozeb 75% WP @ 2g/L** or **Hexaconazole 5% EC @ 2ml/L**.\n"
                "• **Watering**: Irrigate during Flowering (30-35 DAS) and Peg penetration (45-50 DAS). Avoid water stagnation at maturity."
            )
            followups = ["How to identify and prevent Collar Rot in groundnut?", "Best fertilizer ratio for rainfed groundnut", "Mandi prices for shelled groundnut"]

        # 3. Tomato specific advice
        elif any(w in q for w in ["tomato", "தக்காளி", "टमाटर", "టమోటా", "ಟೊಮೆಟೊ"]):
            reply = (
                "🍅 **Tomato Disease, Pest & Yield Advisory**:\n\n"
                "• **Leaf Curl Virus (TLCV)**: Transmitted by Whiteflies. Install 15 yellow sticky traps per acre. Spray **Acetamiprid 20% SP @ 0.3g/L** or **Neem Oil 10,000 ppm @ 2ml/L**.\n"
                "• **Early / Late Blight Control**: Spray **Metalaxyl + Mancozeb (Ridomil MZ) @ 2g/L** or **Copper Oxychloride @ 2.5g/L**.\n"
                "• **Blossom End Rot Prevention**: Caused by Calcium deficiency. Foliar spray of **Calcium Nitrate @ 5g/L + Boron 20% @ 1g/L** at early fruit set.\n"
                "• **Drip Fertigation Schedule**: Alternate day fertigation with 19:19:19 (vegetative) and 13:0:45 (fruiting stage)."
            )
            followups = ["How to cure blossom end rot in tomato?", "Remedy for tomato fruit borer", "Best hybrid varieties resistant to leaf curl"]

        # 4. Cotton specific advice
        elif any(w in q for w in ["cotton", "பருத்தி", "कपास", "పత్తి", "ಹತ್ತಿ"]):
            reply = (
                "🌱 **Cotton Crop Health & Boll Development Advisory**:\n\n"
                "• **Pink Bollworm (*Pectinophora gossypiella*) IPM**:\n"
                "  - Install 5 Pheromone traps with Pectino-lure per acre at 45 DAS.\n"
                "  - If rosette flowers appear, spray **Profenofos 50% EC @ 2ml/L** or **Spinetoram 11.7% SC @ 1ml/L**.\n"
                "• **Sucking Pests (Aphids, Jassids, Thrips)**: Spray **Flonicamid 50% WG (Ulala) @ 0.4g/L** or **Imidacloprid 17.8% SL @ 0.3ml/L**.\n"
                "• **Square & Boll Drop Prevention**: Spray **Planofix (NAA) @ 4.5ml in 15 Liters water** at peak squaring and flowering.\n"
                "• **Foliar Nutrition**: Spray 1% Potassium Nitrate (13:0:45) + 0.5% Magnesium Sulphate at 75 and 90 DAS."
            )
            followups = ["How to identify Pink Bollworm early?", "Foliar nutrition schedule for Bt Cotton", "Current cotton mandi MSP rate"]

        # 5. Rice / Paddy specific advice
        elif any(w in q for w in ["rice", "paddy", "நெல்", "धान", "వరి", "ಭತ್ತ"]):
            reply = (
                "🌾 **Paddy / Rice Blast, BPH & Nutrient Advisory**:\n\n"
                "• **Blast Disease (*Magnaporthe oryzae*)**: Spindle-shaped lesions with grey center. Spray **Tricyclazole 75% WP @ 0.6g/L** or **Isoprothiolane 40% EC @ 1.5ml/L**.\n"
                "• **Brown Planthopper (BPH)**: Check base of tillers. Spray **Pymetrozine 50% WDG (Chess) @ 0.6g/L** or **Triflumuron**. Avoid excess urea.\n"
                "• **Stem Borer**: Install 'Trico-cards' (*Trichogramma japonicum*) @ 2 cards/acre. Apply **Cartap Hydrochloride 4G granules @ 8kg/acre**.\n"
                "• **Water Management**: Practice Alternate Wetting and Drying (AWD) using a field water tube to save 30% water and strengthen root anchorage."
            )
            followups = ["How to cure false smut in paddy?", "Zinc deficiency symptoms in rice", "Best rice varieties for post-monsoon"]

        # 6. General / Soil / Fertilizer / Organic queries
        elif any(w in q for w in ["panchagavya", "panchakavya", "organic", "பஞ்சகாவ்யா", "पंचगव्य"]):
            reply = (
                "🌿 **Panchagavya Preparation & Application Guide**:\n\n"
                "• **Ingredients for 20 Liters**:\n"
                "  - Fresh Cow dung (5 kg) + Cow ghee (500g) -> Mix and ferment for 3 days.\n"
                "  - Cow urine (3 L) + Water (10 L) -> Add on 4th day.\n"
                "  - Cow milk (2 L) + Curd (2 L) + Tender coconut water (3 L) + Jaggery (500g) + 12 ripe bananas.\n"
                "• **Application**: 300ml per 10 Liters water (3% foliar spray) at 15-day intervals. Stimulates growth, enhances flowering, and builds disease resistance."
            )
            followups = ["How to make Jeevamrutham?", "How to use Trichoderma in soil?", "Organic remedies for sucking pests"]
        elif any(w in q for w in ["ph", "acid", "alkaline", "மண்", "मिट्टी", "నేల"]):
            reply = (
                f"🧪 **Soil Health & pH Management for {soil}**:\n\n"
                "• **Ideal pH Range**: 6.5 to 7.5 for optimal macronutrient and micronutrient availability.\n"
                "• **Acidic Soil (pH < 6.0)**: Apply Agricultural Lime (CaCO3) or Dolomite @ 250-500 kg/acre during summer ploughing.\n"
                "• **Alkaline / Sodic Soil (pH > 8.0)**: Apply Gypsum @ 500 kg/acre + sow Daincha / Sunnhemp green manure and plough back at 45 days.\n"
                "• **Organic Carbon**: Incorporate 5 tonnes FYM or 2 tonnes Vermicompost + *Azospirillum* and *Phosphobacteria* @ 2kg/acre."
            )
            followups = ["How to conduct a Soil Health Card test?", "Best crops for high pH soil", "How to increase organic carbon in soil?"]
        elif any(w in q for w in ["scheme", "subsidy", "pm kisan", "loan", "kcc", "மானியங்கள்", "योजना"]):
            reply = (
                "🏛️ **Government Agricultural Schemes & Subsidies (2025-2026)**:\n\n"
                "1. **PM-KISAN**: ₹6,000/year direct bank transfer in 3 installments of ₹2,000.\n"
                "2. **Micro-Irrigation (PMKSY)**: 75% to 100% subsidy for small and marginal farmers for Drip/Sprinkler systems.\n"
                "3. **Kisan Credit Card (KCC)**: Crop loans up to ₹3 Lakhs at 4% effective interest rate with prompt repayment incentive.\n"
                "4. **Agri Drone & Machinery (SMAM)**: 40% to 50% subsidy on power tillers, tractors, and agricultural spray drones.\n"
                "5. **PMFBY Crop Insurance**: Comprehensive non-preventable yield loss coverage at only 1.5% - 2% farmer premium."
            )
            followups = ["Documents required for Drip Irrigation subsidy", "How to apply for PM-KISAN online", "KCC loan application procedure"]
        else:
            # Context-rich specific query answer
            reply = (
                f"🌾 **Agricultural Expert Advisory for**: *'{query}'*\n\n"
                f"• **Targeted Soil & Nutrition**: Recommended basal soil enrichment with balanced NPK based on {soil} profile and {water} supply.\n"
                "• **Integrated Pest Management (IPM)**: Install 5 pheromone traps and 15 yellow sticky traps per acre for early pest detection before chemical spraying.\n"
                "• **Foliar Bio-Stimulant**: Apply 3% Panchagavya or 0.2% seaweed extract spray at vegetative and flowering stages.\n"
                "• **Irrigation & Drainage**: Ensure good field drainage and schedule irrigation during early morning or evening hours."
            )
            followups = ["What is the recommended fertilizer dosage per acre?", "Organic pest control methods", "Government subsidies applicable for this crop"]

        # Localize titles/greetings based on language code
        if lang == 'ta':
            reply = "🌾 **வேளாண் AI மருத்துவ ஆலோசகர் பதில்**:\n\n" + reply
        elif lang == 'hi':
            reply = "🌾 **कृषि एआई डॉक्टर विशेषज्ञ सलाह**:\n\n" + reply
        elif lang == 'te':
            reply = "🌾 **వ్యవసాయ AI నిపుణుల సలహా**:\n\n" + reply
        elif lang == 'kn':
            reply = "🌾 **ಕೃಷಿ AI ತಜ್ಞರ ಸಲಹೆ**:\n\n" + reply
        elif lang == 'ml':
            reply = "🌾 **കൃഷി എഐ വിദഗ്ദ്ധോപദേശം**:\n\n" + reply
        elif lang == 'zh':
            reply = "🌾 **智慧农业AI专家诊断建议**:\n\n" + reply

        return AgriChatResponse(
            reply=reply,
            language=lang,
            suggested_followups=followups,
            key_takeaways=["Apply balanced plant nutrition", "Follow IPM pest scouting", "Adopt water-efficient irrigation"],
            related_govt_schemes=["PM-KISAN", "PM Krishi Sinchayee Yojana (Drip Subsidy)", "Soil Health Card Scheme"]
        )

    @staticmethod
    async def chat(request: AgriChatRequest) -> AgriChatResponse:
        # Check if Gemini API is configured
        if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY != "your_gemini_api_key_here":
            try:
                import google.generativeai as genai
                genai.configure(api_key=settings.GEMINI_API_KEY)
                
                model = genai.GenerativeModel(
                    model_name="gemini-1.5-flash",
                    system_instruction=AGRI_SYSTEM_PROMPT
                )

                farmer_ctx = request.farmer_context or {}
                prompt = (
                    f"FARMER QUESTION: {request.message}\n"
                    f"RESPONSE LANGUAGE: {request.language} (CRITICAL: You MUST write the ENTIRE answer in {request.language} language!)\n"
                    f"FARMER CONTEXT: Soil={farmer_ctx.get('soil_type', 'Unspecified')}, Water={farmer_ctx.get('water_source', 'Unspecified')}, Location={farmer_ctx.get('location_name', 'India')}, Active Crop={farmer_ctx.get('crop_name', 'General Farm')}\n"
                    f"TASK: Provide a precise, scientific, direct answer for this specific query. Include specific pest names, chemical dosages per liter, organic alternatives, and practical farmer steps."
                )

                response = model.generate_content(prompt)
                if response and response.text and len(response.text.strip()) > 10:
                    reply_text = response.text.strip()
                    followups = [
                        "What is the exact fertilizer dosage per acre?",
                        "What are the organic biocontrol methods?",
                        "Which government subsidy applies here?"
                    ]
                    return AgriChatResponse(
                        reply=reply_text,
                        language=request.language,
                        suggested_followups=followups,
                        key_takeaways=["Follow balanced NPK", "Maintain regular scout checks"],
                        related_govt_schemes=["PM-KISAN", "PMFBY", "SMAM Subsidy"]
                    )
            except Exception as e:
                print(f"Gemini API Exception, falling back to dynamic agronomic engine: {e}")

        # Intelligent dynamic agronomic engine fallback
        return GeminiService._generate_dynamic_crop_advisory(
            query=request.message,
            lang=request.language,
            context=request.farmer_context
        )

