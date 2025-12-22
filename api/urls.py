from django.urls import path
from .views import UploadDocumentAPIView, QueryAPIView
from . import views

urlpatterns = [
    path('upload/', UploadDocumentAPIView.as_view(), name='upload'),
    path('query/', QueryAPIView.as_view(), name='query'),
    path('', views.index, name='index'),
]
