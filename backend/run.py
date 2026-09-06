# pyrefly: ignore [missing-import]
import uvicorn
from app.config import settings

if __name__ == "__main__":
    print(f"🌱 Starting Smart Agri Backend API on http://{settings.HOST}:{settings.PORT}")
    print(f"📖 Swagger Interactive Documentation: http://localhost:{settings.PORT}/docs")
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
