from django.core.management.base import BaseCommand
from movies.models import Movie
from movies.ai_services import generate_image

class Command(BaseCommand):
    help = "Genera image_url para películas sin imagen usando IA."

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=20)

    def handle(self, *args, **opts):
        limit = opts["limit"]
        qs = Movie.objects.filter(image_url="")[:limit]
        count = 0
        for m in qs:
            prompt = f"Poster cinematográfico, sin texto, tema: {m.name}. {m.description[:200]}"
            try:
                url = generate_image(prompt)
                m.image_url = url
                m.save()
                count += 1
                self.stdout.write(self.style.SUCCESS(f"OK: {m.name}"))
            except Exception as e:
                self.stderr.write(f"Error {m.name}: {e}")
        self.stdout.write(self.style.SUCCESS(f"Imágenes generadas: {count}"))
