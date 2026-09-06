import json
from typing import List, Dict, Any, Optional
from app.config import settings
from app.models.schemas import AgriChatRequest, AgriChatResponse, ChatMessage

AGRI_SYSTEM_PROMPT = """You are 'Smart Agri AI' (விவசாய தோழன் / कृषि मित्र), an expert agricultural scientist, agronomist, and soil doctor.
Your mission is to assist young and experienced farmers with clear, practical, high-yield, sustainable, and cost-effective farming guidance.

CORE EXPERTISE & GUIDELINES:
1. **Soil & Fertilizers**:
   - Soil pH: Acidic (<6.0) -> Recommend Agricultural Lime (CaCO3) / Dolomite. Alkaline (>7.5) -> Recommend Gypsum (CaSO4) & green manuring with Daincha/Sunnhemp.
   - Soil Types: Red soil, Black soil, Alluvial, Laterite, Clayey, Sandy loam.
   - Organic inputs: Panchagavya (3% spray), Jeevamrutham (200 L/acre), Vermicompost (2 tonnes/acre), Neem Cake (200 kg/acre), Trichoderma viride & Pseudomonas fluorescens.
2. **Pest & Disease Control**:
   - Integrated Pest Management (IPM): Pheromone traps (5/acre), Yellow/Blue sticky traps (15/acre).
   - Bio-pesticides: 5% Neem seed kernel extract (NSKE), Beauveria bassiana.
   - Chemical remedies: Always specify exact dosage per liter of water (e.g. Chlorantraniliprole 0.3ml/L, Copper Oxychloride 2.5g/L).
3. **Irrigation & Weather**:
   - Drip irrigation, micro-sprinklers, Alternate Wetting and Drying (AWD) for rice.
4. **Government Schemes & Subsidies**:
   - PM-KISAN (₹6000/year income support), PM Fasal Bima Yojana (PMFBY crop insurance), Kisan Credit Card (KCC), Sub-Mission on Agricultural Mechanization (SMAM 40-50% subsidy for tractors/drones), National Mission on Micro Irrigation (Per Drop More Crop - 75-100% subsidy for drip).
5. **Tone & Formatting**:
   - Be warm, encouraging, respectful, and direct. Non-literate friendly phrasing with bullet points.
   - Answer in the requested language (Tamil, Malayalam, Telugu, Kannada, Hindi, English, Chinese).
"""

class GeminiService:
    @staticmethod
    def _get_localized_fallback(query: str, lang: str) -> AgriChatResponse:
        q_lower = query.lower()
        
        # Multilingual greetings and standard expert agricultural responses
        if any(w in q_lower for w in ["panchagavya", "panchakavya", "organic", "பஞ்சகாவ்யா", "पंचगव्य"]):
            reply = (
                "🌿 **Panchagavya Preparation & Application Guide**:\n\n"
                "**Ingredients (for 20 Liters)**:\n"
                "• Fresh Cow dung (5 kg) + Cow ghee (500g) -> Mix and ferment for 3 days.\n"
                "• Cow urine (3 Liters) + Water (10 Liters) -> Add on 4th day.\n"
                "• Cow milk (2 Liters) + Curd (2 Liters) + Tender coconut water (3 Liters) + Jaggery (500g) + 12 ripe bananas.\n"
                "• Stir clockwise twice daily. Ready in 21 days!\n\n"
                "**Dosage & Spray Schedule**:\n"
                "• **Foliar Spray**: 300ml Panchagavya in 10 Liters water (3% solution).\n"
                "• Spray at 15th, 30th, 45th, and 60th days after planting during morning or evening hours."
            )
            followups = ["How to prepare Jeevamrutham?", "What are the benefits of Neem Cake?", "How to get organic certification?"]
        elif any(w in q_lower for w in ["ph", "soil", "acid", "alkaline", "மண்", "मिट्टी"]):
            reply = (
                "🧪 **Soil Health & pH Management**:\n\n"
                "• **Ideal Soil pH**: 6.5 to 7.5 for maximum nutrient absorption.\n"
                "• **If Acidic Soil (pH < 6.0)**: Apply Agricultural Limestone or Dolomite @ 200 - 500 kg/acre during summer ploughing.\n"
                "• **If Alkaline / Saline Soil (pH > 8.0)**: Apply Gypsum @ 500 kg/acre + sow Daincha / Sunnhemp (green manure) and incorporate into soil at 45 days.\n"
                "• **Organic Carbon Boost**: Add 5 tonnes of well-rotted Farmyard Manure (FYM) or 2 tonnes Vermicompost per acre annually."
            )
            followups = ["How to do a Soil Health Card test?", "Best crops for Red Soil", "How to use Trichoderma in soil?"]
        elif any(w in q_lower for w in ["subsidy", "scheme", "loan", "kcc", "pm kisan", "மானியங்கள்", "योजना"]):
            reply = (
                "🏛️ **Government Agricultural Schemes & Subsidies (2025-2026)**:\n\n"
                "1. **PM-KISAN**: ₹6,000 annual direct income support in 3 equal installments of ₹2,000.\n"
                "2. **Micro-Irrigation Subsidy (PMKSY)**: Up to 100% subsidy for small/marginal farmers for Drip & Sprinkler setup.\n"
                "3. **Kisan Credit Card (KCC)**: Short-term crop loans up to ₹3 Lakhs at a subsidized interest rate of 4% (with timely repayment).\n"
                "4. **Agri Drone Subsidy**: 50% to 100% financial assistance under SMAM scheme for farmer groups and custom hiring centers.\n"
                "5. **PM Fasal Bima Yojana (PMFBY)**: Comprehensive crop insurance with only 1.5% - 2% premium."
            )
            followups = ["Documents required for PM-KISAN", "How to apply for Drip Irrigation subsidy?", "Crop insurance claim procedure"]
        else:
            reply = (
                f"🌾 **Agricultural Advisory for**: *'{query}'*\n\n"
                "1. **Soil & Nutrition**: Ensure adequate organic carbon (>0.75%) by adding compost and biofertilizers (Azospirillum & Phosphobacteria @ 2kg/acre).\n"
                "2. **Water Management**: Practice drip irrigation with fertigation to save 40% water and increase nutrient efficiency by 30%.\n"
                "3. **Pest Monitoring**: Install 5 pheromone traps and 15 yellow sticky traps per acre for early pest detection before spraying chemical pesticides.\n"
                "4. **Seasonal Timing**: Align sowing with current weather conditions to avoid rain during harvest."
            )
            followups = ["What fertilizer schedule should I follow?", "How to prevent pest attacks organically?", "Recommend high profit crops for my soil"]

        return AgriChatResponse(
            reply=reply,
            language=lang,
            suggested_followups=followups,
            key_takeaways=["Boost organic carbon", "Adopt micro-irrigation", "Follow IPM strategies"],
            related_govt_schemes=["PM-KISAN", "PM Krishi Sinchayee Yojana (Drip Subsidy)", "Soil Health Card Scheme"]
        )

    @staticmethod
    async def chat(request: AgriChatRequest) -> AgriChatResponse:
        # Check if Gemini API is available
        if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY != "your_gemini_api_key_here":
            try:
                import google.generativeai as genai
                genai.configure(api_key=settings.GEMINI_API_KEY)
                
                # Use gemini-1.5-flash or gemini-1.5-pro
                model = genai.GenerativeModel(
                    model_name="gemini-1.5-flash",
                    system_instruction=AGRI_SYSTEM_PROMPT
                )

                prompt = (
                    f"User Query: {request.message}\n"
                    f"Language: {request.language} (Respond directly in {request.language} language using natural native terms with English subtitles if helpful)\n"
                    f"Farmer Context: {json.dumps(request.farmer_context or {})}\n"
                    f"Format: Structure with clear headings, bullet points, dosages, organic remedies, chemical alternatives (with exact dosage/liter), and relevant government schemes."
                )

                response = model.generate_content(prompt)
                reply_text = response.text if response and response.text else "Unable to generate response."
                
                # Dynamic follow-ups
                followups = [
                    "What is the cost of cultivation per acre?",
                    "What are the best organic pest control methods?",
                    "Which government subsidy applies to this?"
                ]
                
                return AgriChatResponse(
                    reply=reply_text,
                    language=request.language,
                    suggested_followups=followups,
                    key_takeaways=["Follow balanced NPK", "Maintain regular scout checks"],
                    related_govt_schemes=["PM-KISAN", "PMFBY", "SMAM Subsidy"]
                )
            except Exception as e:
                print(f"Gemini API Exception, falling back: {e}")

        # Fallback
        return GeminiService._get_localized_fallback(request.message, request.language)
