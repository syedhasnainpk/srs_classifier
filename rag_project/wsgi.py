import os
import dotenv

dotenv.load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'rag_project.settings')

from django.core.wsgi import get_wsgi_application

application = get_wsgi_application()
