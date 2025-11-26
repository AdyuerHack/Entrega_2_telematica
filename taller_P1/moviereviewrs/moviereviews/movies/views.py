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
