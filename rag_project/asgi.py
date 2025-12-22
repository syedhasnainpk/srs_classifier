import os
import dotenv

dotenv.load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'rag_project.settings')

from django.core.asgi import get_asgi_application

application = get_asgi_application()
