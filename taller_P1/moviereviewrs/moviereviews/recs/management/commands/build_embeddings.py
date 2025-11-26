import json
from django.core.management.base import BaseCommand
from movies.models import Movie
from movies.ai_services import embed_text
from recs.models import MovieVector

class Command(BaseCommand):
    help = "Crea o actualiza embeddings para todas las películas."

    def handle(self, *args, **opts):
        created, updated = 0, 0
        for m in Movie.objects.all():
            vec = embed_text(f"{m.name}. {m.description}")
            payload = json.dumps(vec)
            obj, was_created = MovieVector.objects.update_or_create(
                movie=m,
                defaults={"dim": len(vec), "vector_json": payload},
            )
            if was_created:
                created += 1
            else:
                updated += 1
        self.stdout.write(self.style.SUCCESS(
            f"Embeddings -> creados: {created}, actualizados: {updated}"
        ))
