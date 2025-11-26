from django.urls import path
from .views import RecommendView

app_name = "recs"

urlpatterns = [
    path("", RecommendView.as_view(), name="recommend"),
]
