#!/bin/bash
set -e

echo "🚀 Configurando entorno virtual..."
python3 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
pip install "Django>=5.0,<6"

echo "📦 Creando proyecto Django..."
django-admin startproject moviereviews
cd moviereviews

echo "🎬 Creando app 'movies'..."
python manage.py startapp movies

echo "🗂️ Estructura de carpetas..."
mkdir -p templates/movies templates/reviews templates/news templates/registration static

########################################
# settings.py (proyecto)
########################################
cat > moviereviews/settings.py <<'EOF'
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = "dev-secret-key-change-me"
DEBUG = True
ALLOWED_HOSTS = []

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "movies",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "moviereviews.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "moviereviews.wsgi.application"

DATABASES = {
    "default": {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}
}

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = "es"
TIME_ZONE = "America/Bogota"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "login"
LOGIN_REDIRECT_URL = "home"
LOGOUT_REDIRECT_URL = "home"
EOF

########################################
# urls.py (proyecto)
########################################
cat > moviereviews/urls.py <<'EOF'
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

    # App
    path("", HomeView.as_view(), name="home"),
    path("movies/", include("movies.urls")),
]
EOF

########################################
# models.py (app)
########################################
cat > movies/models.py <<'EOF'
from django.db import models
from django.contrib.auth.models import User

class Movie(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField()
    url = models.URLField(help_text="Link externo (IMDb, tráiler, etc.)")
    image_url = models.URLField(blank=True, help_text="URL de póster/imagen")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Review(models.Model):
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name="reviews")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="reviews")
    content = models.TextField()
    watch_again = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Review by {self.user} on {self.movie}"


class News(models.Model):
    headline = models.CharField(max_length=255)
    story = models.TextField()
    published_at = models.DateField()

    class Meta:
        ordering = ["-published_at"]

    def __str__(self):
        return self.headline
EOF

########################################
# admin.py (app)
########################################
cat > movies/admin.py <<'EOF'
from django.contrib import admin
from .models import Movie, Review, News

@admin.register(Movie)
class MovieAdmin(admin.ModelAdmin):
    list_display = ("name", "url", "created_at")
    search_fields = ("name",)

@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("movie", "user", "watch_again", "created_at")
    list_filter = ("watch_again", "created_at")
    search_fields = ("movie__name", "user__username", "content")

@admin.register(News)
class NewsAdmin(admin.ModelAdmin):
    list_display = ("headline", "published_at")
    list_filter = ("published_at",)
    search_fields = ("headline", "story")
EOF

########################################
# forms.py (app)
########################################
cat > movies/forms.py <<'EOF'
from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User
from .models import Review

class MovieSearchForm(forms.Form):
    q = forms.CharField(label="Buscar película", required=False)

class ReviewForm(forms.ModelForm):
    class Meta:
        model = Review
        fields = ["content", "watch_again"]
        widgets = {
            "content": forms.Textarea(attrs={"rows": 4, "placeholder": "Escribe tu reseña..."}),
        }

class SignUpForm(UserCreationForm):
    class Meta:
        model = User
        fields = ("username",)
EOF

########################################
# urls.py (app)
########################################
cat > movies/urls.py <<'EOF'
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
EOF

########################################
# views.py (app)
########################################
cat > movies/views.py <<'EOF'
from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin, UserPassesTestMixin
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse_lazy
from django.views.generic import TemplateView, ListView, DetailView, CreateView, UpdateView, DeleteView, FormView
from django.contrib.auth import login

from .models import Movie, Review, News
from .forms import MovieSearchForm, ReviewForm, SignUpForm

class HomeView(TemplateView):
    template_name = "movies/home.html"
    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["latest_movies"] = Movie.objects.order_by("-created_at")[:6]
        ctx["latest_news"] = News.objects.order_by("-published_at")[:5]
        return ctx


class MovieListView(ListView):
    model = Movie
    template_name = "movies/movie_list.html"
    context_object_name = "movies"
    paginate_by = 10

    def get_queryset(self):
        qs = Movie.objects.all()
        self.search_form = MovieSearchForm(self.request.GET or None)
        if self.search_form.is_valid():
            q = self.search_form.cleaned_data.get("q")
            if q:
                qs = qs.filter(name__icontains=q)
        return qs

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["search_form"] = self.search_form
        return ctx


class MovieDetailView(DetailView):
    model = Movie
    template_name = "movies/movie_detail.html"
    context_object_name = "movie"

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["reviews"] = self.object.reviews.select_related("user").all()
        ctx["form"] = ReviewForm()
        return ctx


class ReviewCreateView(LoginRequiredMixin, CreateView):
    model = Review
    form_class = ReviewForm

    def post(self, request, *args, **kwargs):
        movie = get_object_or_404(Movie, pk=kwargs["movie_id"])
        form = ReviewForm(request.POST)
        if form.is_valid():
            review = form.save(commit=False)
            review.user = request.user
            review.movie = movie
            review.save()
            messages.success(request, "¡Reseña publicada!")
        else:
            messages.error(request, "Corrige el formulario.")
        return redirect("movie_detail", pk=movie.pk)


class OwnerRequiredMixin(UserPassesTestMixin):
    def test_func(self):
        obj = self.get_object()
        return obj.user_id == self.request.user.id


class ReviewUpdateView(LoginRequiredMixin, OwnerRequiredMixin, UpdateView):
    model = Review
    form_class = ReviewForm
    template_name = "reviews/review_form.html"

    def get_success_url(self):
        return reverse_lazy("movie_detail", kwargs={"pk": self.object.movie_id})

    def handle_no_permission(self):
        messages.error(self.request, "No puedes editar reseñas de otros usuarios.")
        return redirect("movie_detail", pk=self.get_object().movie_id)


class ReviewDeleteView(LoginRequiredMixin, OwnerRequiredMixin, DeleteView):
    model = Review
    template_name = "reviews/review_confirm_delete.html"

    def get_success_url(self):
        messages.success(self.request, "Reseña eliminada.")
        return reverse_lazy("movie_detail", kwargs={"pk": self.object.movie_id})

    def handle_no_permission(self):
        messages.error(self.request, "No puedes eliminar reseñas de otros usuarios.")
        return redirect("movie_detail", pk=self.get_object().movie_id)


class NewsListView(ListView):
    model = News
    template_name = "news/news_list.html"
    context_object_name = "news_list"
    paginate_by = 10
    queryset = News.objects.order_by("-published_at")


class SignUpView(FormView):
    template_name = "registration/signup.html"
    form_class = SignUpForm
    success_url = reverse_lazy("home")

    def form_valid(self, form):
        user = form.save()
        login(self.request, user)
        messages.success(self.request, "Cuenta creada. ¡Bienvenido!")
        return super().form_valid(form)
EOF

########################################
# TEMPLATES
########################################

# base.html
cat > templates/base.html <<'EOF'
{% load static %}
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8">
    <title>Movie Reviews</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  </head>
  <body>
    <nav class="navbar navbar-expand-lg bg-dark navbar-dark">
      <div class="container">
        <a class="navbar-brand" href="{% url 'home' %}">🎬 Movie Reviews</a>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#nav">
          <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="nav">
          <ul class="navbar-nav ms-auto">
            <li class="nav-item"><a class="nav-link" href="{% url 'movie_list' %}">Películas</a></li>
            <li class="nav-item"><a class="nav-link" href="{% url 'news_list' %}">Noticias</a></li>
            {% if user.is_authenticated %}
              <li class="nav-item"><span class="navbar-text me-2">Hola, {{ user.username }}</span></li>
              <li class="nav-item"><a class="nav-link" href="{% url 'logout' %}">Salir</a></li>
            {% else %}
              <li class="nav-item"><a class="nav-link" href="{% url 'login' %}">Ingresar</a></li>
              <li class="nav-item"><a class="nav-link" href="{% url 'signup' %}">Crear cuenta</a></li>
            {% endif %}
          </ul>
        </div>
      </div>
    </nav>

    <div class="container mt-4">
      {% for message in messages %}
        <div class="alert alert-{{ message.tags }}">{% if message.tags == 'error' %}⚠️ {% endif %}{{ message }}</div>
      {% endfor %}
      {% block content %}{% endblock %}
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
EOF

# home.html
cat > templates/movies/home.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h1 class="mb-3">Bienvenido</h1>

<h4 class="mt-4">Últimas películas</h4>
<div class="row row-cols-1 row-cols-md-3 g-3">
  {% for m in latest_movies %}
  <div class="col">
    <div class="card h-100">
      {% if m.image_url %}<img src="{{ m.image_url }}" class="card-img-top" alt="{{ m.name }}">{% endif %}
      <div class="card-body">
        <h5 class="card-title">{{ m.name }}</h5>
        <p class="card-text">{{ m.description|truncatechars:120 }}</p>
        <a href="{% url 'movie_detail' m.pk %}" class="btn btn-primary">Ver</a>
      </div>
    </div>
  </div>
  {% empty %}
  <p>No hay películas aún.</p>
  {% endfor %}
</div>

<h4 class="mt-5">Últimas noticias</h4>
<ul class="list-group">
  {% for n in latest_news %}
    <li class="list-group-item d-flex justify-content-between align-items-start">
      <div>
        <strong>{{ n.headline }}</strong>
        <div class="small text-muted">{{ n.published_at }}</div>
      </div>
    </li>
  {% empty %}
    <li class="list-group-item">No hay noticias.</li>
  {% endfor %}
</ul>
{% endblock %}
EOF

# movie_list.html
cat > templates/movies/movie_list.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Películas</h2>
<form method="get" class="row g-2 my-3">
  <div class="col-auto">
    {{ search_form.q }}
  </div>
  <div class="col-auto">
    <button class="btn btn-outline-primary" type="submit">Buscar</button>
  </div>
</form>

<div class="row row-cols-1 row-cols-md-2 g-3">
  {% for m in movies %}
  <div class="col">
    <div class="card h-100">
      {% if m.image_url %}<img src="{{ m.image_url }}" class="card-img-top" alt="{{ m.name }}">{% endif %}
      <div class="card-body">
        <h5 class="card-title">{{ m.name }}</h5>
        <p class="card-text">{{ m.description|truncatechars:160 }}</p>
        <a class="btn btn-primary" href="{% url 'movie_detail' m.pk %}">Detalles</a>
      </div>
    </div>
  </div>
  {% empty %}
  <p>No se encontraron resultados.</p>
  {% endfor %}
</div>

{% if is_paginated %}
<nav class="mt-4">
  <ul class="pagination">
    {% if page_obj.has_previous %}
      <li class="page-item"><a class="page-link" href="?page={{ page_obj.previous_page_number }}{% if request.GET.q %}&q={{ request.GET.q }}{% endif %}">Anterior</a></li>
    {% endif %}
    <li class="page-item active"><span class="page-link">{{ page_obj.number }}</span></li>
    {% if page_obj.has_next %}
      <li class="page-item"><a class="page-link" href="?page={{ page_obj.next_page_number }}{% if request.GET.q %}&q={{ request.GET.q }}{% endif %}">Siguiente</a></li>
    {% endif %}
  </ul>
</nav>
{% endif %}
{% endblock %}
EOF

# movie_detail.html
cat > templates/movies/movie_detail.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<div class="row">
  <div class="col-md-5">
    {% if movie.image_url %}
      <img src="{{ movie.image_url }}" class="img-fluid rounded mb-3" alt="{{ movie.name }}">
    {% endif %}
    <a href="{{ movie.url }}" target="_blank" class="btn btn-outline-secondary w-100">Ver enlace</a>
  </div>
  <div class="col-md-7">
    <h2>{{ movie.name }}</h2>
    <p>{{ movie.description }}</p>

    <hr>
    <h4>Reseñas</h4>

    {% if user.is_authenticated %}
    <form action="{% url 'review_create' movie.id %}" method="post" class="mb-4">
      {% csrf_token %}
      {{ form.as_p }}
      <button class="btn btn-success" type="submit">Publicar reseña</button>
    </form>
    {% else %}
      <p><a href="{% url 'login' %}?next={{ request.path }}">Inicia sesión</a> para escribir una reseña.</p>
    {% endif %}

    {% for r in reviews %}
      <div class="border rounded p-3 mb-3">
        <div class="d-flex justify-content-between">
          <strong>{{ r.user.username }}</strong>
          <small class="text-muted">{{ r.created_at|date:"Y-m-d H:i" }}</small>
        </div>
        <p class="mb-1">{{ r.content }}</p>
        <div class="small">{{ r.watch_again|yesno:"👀 Vería de nuevo,No vería de nuevo" }}</div>
        {% if user.is_authenticated and r.user_id == user.id %}
          <div class="mt-2">
            <a href="{% url 'review_edit' r.pk %}" class="btn btn-sm btn-outline-primary">Editar</a>
            <a href="{% url 'review_delete' r.pk %}" class="btn btn-sm btn-outline-danger">Eliminar</a>
          </div>
        {% endif %}
      </div>
    {% empty %}
      <p>No hay reseñas todavía.</p>
    {% endfor %}
  </div>
</div>
{% endblock %}
EOF

# review_form.html
cat > templates/reviews/review_form.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h3>Editar reseña</h3>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button class="btn btn-primary">Guardar</button>
  <a class="btn btn-secondary" href="{% url 'movie_detail' object.movie.id %}">Cancelar</a>
</form>
{% endblock %}
EOF

# review_confirm_delete.html
cat > templates/reviews/review_confirm_delete.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h3>Eliminar reseña</h3>
<p>¿Seguro que quieres eliminar esta reseña?</p>
<form method="post">
  {% csrf_token %}
  <button class="btn btn-danger">Sí, eliminar</button>
  <a class="btn btn-secondary" href="{% url 'movie_detail' object.movie.id %}">Cancelar</a>
</form>
{% endblock %}
EOF

# news_list.html
cat > templates/news/news_list.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Noticias</h2>
<ul class="list-group">
  {% for n in news_list %}
    <li class="list-group-item">
      <div class="d-flex justify-content-between">
        <strong>{{ n.headline }}</strong>
        <span class="text-muted">{{ n.published_at }}</span>
      </div>
      <p class="mb-0">{{ n.story }}</p>
    </li>
  {% empty %}
    <li class="list-group-item">No hay noticias.</li>
  {% endfor %}
</ul>

{% if is_paginated %}
<nav class="mt-4">
  <ul class="pagination">
    {% if page_obj.has_previous %}
      <li class="page-item"><a class="page-link" href="?page={{ page_obj.previous_page_number }}">Anterior</a></li>
    {% endif %}
    <li class="page-item active"><span class="page-link">{{ page_obj.number }}</span></li>
    {% if page_obj.has_next %}
      <li class="page-item"><a class="page-link" href="?page={{ page_obj.next_page_number }}">Siguiente</a></li>
    {% endif %}
  </ul>
</nav>
{% endif %}
{% endblock %}
EOF

# login.html
cat > templates/registration/login.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Ingresar</h2>
<form method="post">
  {% csrf_token %}
  <div class="mb-3">
    <label class="form-label">Usuario</label>
    <input type="text" name="username" class="form-control" autofocus required>
  </div>
  <div class="mb-3">
    <label class="form-label">Contraseña</label>
    <input type="password" name="password" class="form-control" required>
  </div>
  <button class="btn btn-primary">Entrar</button>
  <p class="mt-3">¿No tienes cuenta? <a href="{% url 'signup' %}">Regístrate</a></p>
</form>
{% endblock %}
EOF

# signup.html
cat > templates/registration/signup.html <<'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Crear cuenta</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button class="btn btn-success">Registrarme</button>
</form>
{% endblock %}
EOF

########################################
# Migraciones y datos de ejemplo
########################################
echo "🧱 Migrando base de datos..."
python manage.py makemigrations
python manage.py migrate

echo "🌱 Cargando datos de ejemplo..."
python manage.py shell <<'PY'
from movies.models import Movie, News
from datetime import date, timedelta

if not Movie.objects.exists():
    Movie.objects.create(
        name="Inception",
        description="Dom Cobb es un ladrón con la rara habilidad de entrar en los sueños.",
        url="https://www.imdb.com/title/tt1375666/",
        image_url="https://m.media-amazon.com/images/I/51s+0w+qKLL._AC_.jpg",
    )
    Movie.objects.create(
        name="Interstellar",
        description="Un grupo de exploradores viaja a través de un agujero de gusano.",
        url="https://www.imdb.com/title/tt0816692/",
        image_url="https://m.media-amazon.com/images/I/71n58ZsQf1L._AC_SL1024_.jpg",
    )

if not News.objects.exists():
    News.objects.create(headline="Festival de cine abre inscripciones", story="El festival anual anunció sus fechas.", published_at=date.today())
    News.objects.create(headline="Nuevo tráiler sorprende a fans", story="El avance causó furor en redes.", published_at=date.today()-timedelta(days=3))

print("Datos de ejemplo cargados.")
PY

echo ""
echo "✅ Listo. Pasos finales:"
echo "1) Activar entorno si no lo está: source venv/bin/activate"
echo "2) (Opcional) Crear superusuario para /admin: python manage.py createsuperuser"
echo "3) Ejecutar servidor: python manage.py runserver"
echo "🌐 Abre: http://127.0.0.1:8000/"
