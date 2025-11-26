from django.db import models
from movies.models import Movie

class MovieVector(models.Model):
    movie = models.OneToOneField(Movie, on_delete=models.CASCADE, related_name="vector")
    dim = models.IntegerField(default=1536)
    vector_json = models.TextField()  # guardamos la lista de floats en JSON
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Vec({self.movie.name})"
