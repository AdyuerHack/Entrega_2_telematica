from django.urls import path
from . import views

urlpatterns = [
    path("", views.MovieListView.as_view(), name="movie_list"),
    path("<int:pk>/", views.MovieDetailView.as_view(), name="movie_detail"),

    path("<int:movie_id>/reviews/create/", views.ReviewCreateView.as_view(), name="review_create"),
    path("reviews/<int:pk>/edit/", views.ReviewUpdateView.as_view(), name="review_edit"),
    path("reviews/<int:pk>/delete/", views.ReviewDeleteView.as_view(), name="review_delete"),

    path("news/", views.NewsListView.as_view(), name="news_list"),
]
