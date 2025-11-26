from django.core.management.base import BaseCommand
from movies.models import Movie
from movies.ai_services import generate_movie_descriptions

class Command(BaseCommand):
    help = "Genera o actualiza descripciones para títulos usando LLM."

    def add_arguments(self, parser):
        parser.add_argument(
            "--titles",
            nargs="+",
            help="Listado de títulos. Si no se pasa, usa los del DB sin descripción.",
        )

    def handle(self, *args, **opts):
        titles = opts.get("titles")
        if not titles:
            titles = list(
                Movie.objects.filter(description="").values_list("name", flat=True)
            )
            if not titles:
                self.stdout.write(
                    self.style.WARNING(
                        "No hay títulos sin descripción. Usa --titles ..."
                    )
                )
                return

        out = generate_movie_descriptions(titles)
        updated = 0
        for item in out:
            name = item.get("name")
            desc = item.get("description", "")
            url = item.get("url", "")
            if not name:
                continue
            m = Movie.objects.filter(name__iexact=name).first()
            if not m:
                m = Movie.objects.create(name=name, description=desc, url=url)
            else:
                if desc:
                    m.description = desc
                if url:
                    m.url = url
                m.save()
            updated += 1

        self.stdout.write(self.style.SUCCESS(f"Actualizados/creados: {updated}"))
