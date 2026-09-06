import os
from typing import List, Dict, Any, Optional
from app.config import settings
from app.models.schemas import AgriChatRequest, AgriChatResponse, ChatMessage

AGRI_SYSTEM_PROMPT = """You are 'Smart Agri AI Doctor' (விவசாய தோழன் / कृषि मित्र), an expert agricultural scientist, agronomist, plant pathologist, and soil doctor.
Your mission is to provide direct, specific, highly actionable, and cost-effective agricultural guidance to farmers.

CRITICAL INSTRUCTIONS:
1. Address the farmer's EXACT question directly. If they send a greeting ('hello', 'வணக்கம்', 'नमस्ते', 'yeppadi irukka', etc.), greet them warmly and introduce your agricultural capabilities.
2. If they ask about a crop, disease, pest, or fertilizer, provide specific, practical advice including exact dosages, organic solutions, and preventive measures.
3. Factor in the farmer's soil type, water source, current season, and GPS location if provided in context.
4. STRICTLY respond in the EXACT same language used by the farmer (Tamil, English, Hindi, Telugu, Kannada, Malayalam, etc.). Never switch languages without instruction.
5. Format your answer with clean markdown bullet points and bold highlights for readability.
6. Keep responses concise and practical — farmers are busy people.
"""


class GeminiService:
    @staticmethod
    async def chat(request: AgriChatRequest) -> AgriChatResponse:
        user_query = request.get_query()
        lang = request.language or "en"
        farmer_ctx = request.farmer_context or {}

        api_key = (
            settings.GEMINI_API_KEY
            or os.environ.get("GEMINI_API_KEY")
            or os.environ.get("GOOGLE_API_KEY")
        )

        if not api_key or api_key.strip() in ("", "your_gemini_api_key_here"):
            error_text = (
                "⚠️ **AI Doctor Unavailable**: Gemini API key is not configured on the server.\n\n"
                "Please contact the app administrator to set up the GEMINI_API_KEY environment variable."
            )
            return AgriChatResponse(
                reply=error_text,
                response=error_text,
                language=lang,
                suggested_followups=[],
                key_takeaways=[],
                related_govt_schemes=[]
            )

        try:
            import google.generativeai as genai
            genai.configure(api_key=api_key)

            model = genai.GenerativeModel(
                model_name="gemini-1.5-flash",
                system_instruction=AGRI_SYSTEM_PROMPT
            )

            # Build a rich contextual prompt
            prompt_parts = []

            if farmer_ctx:
                ctx_info = ", ".join(
                    f"{k}: {v}" for k, v in farmer_ctx.items()
                    if v and str(v).strip() and str(v) != "None"
                )
                if ctx_info:
                    prompt_parts.append(f"[Farmer Context — {ctx_info}]")

            if lang and lang != "en":
                prompt_parts.append(
                    f"[IMPORTANT: Respond ONLY in the farmer's language: {lang}]"
                )

            prompt_parts.append(f"Farmer Query: {user_query}")

            prompt = "\n".join(prompt_parts)
            response = model.generate_content(prompt)

            if response and response.text and response.text.strip():
                text = response.text.strip()
                return AgriChatResponse(
                    reply=text,
                    response=text,
                    language=lang,
                    suggested_followups=[
                        "How to prevent this organically?",
                        "What is the fertilizer schedule for this crop?",
                        "Are there government subsidies available for this?",
                    ],
                    key_takeaways=[],
                    related_govt_schemes=["PM-KISAN", "PMFBY", "SMAM Subsidy"],
                )
            else:
                # Gemini returned empty content — could be safety filter
                empty_text = (
                    "🌾 I wasn't able to generate a response for that query. "
                    "Please try rephrasing your question or ask about a specific crop, disease, or farming practice."
                )
                return AgriChatResponse(
                    reply=empty_text,
                    response=empty_text,
                    language=lang,
                    suggested_followups=[
                        "What crops grow best in red soil?",
                        "How to control tomato leaf curl virus?",
                        "Best organic fertilizer for paddy?",
                    ],
                    key_takeaways=[],
                    related_govt_schemes=[]
                )

        except Exception as e:
            print(f"[GeminiService] Gemini API call failed: {e}")
            error_text = (
                f"⚠️ **AI Doctor Error**: The Gemini API returned an error.\n\n"
                f"Details: `{str(e)}`\n\n"
                "Please try again in a moment. If this persists, check server logs."
            )
            return AgriChatResponse(
                reply=error_text,
                response=error_text,
                language=lang,
                suggested_followups=[],
                key_takeaways=[],
                related_govt_schemes=[]
            )
