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
