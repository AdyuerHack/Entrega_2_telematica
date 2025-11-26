from django.contrib import admin
from django.urls import path, include
from movies.views import HomeView, SignUpView
from django.contrib.auth import views as auth_views

urlpatterns = [
    path("admin/", admin.site.urls),

    # Auth
    path("login/", auth_views.LoginView.as_view(template_name="registration/login.html"), name="login"),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("signup/", SignUpView.as_view(), name="signup"),

    # App principal
    path("", HomeView.as_view(), name="home"),
    path("movies/", include("movies.urls")),

    # Recomendador IA
    path("recs/", include("recs.urls")),
]
