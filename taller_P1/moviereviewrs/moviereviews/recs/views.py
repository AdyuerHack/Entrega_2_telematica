# recs/views.py
import json
import math
from django.shortcuts import render
from django.views import View
from movies.ai_services import embed_text
from recs.models import MovieVector


def cosine(a, b):
    if not a or not b or len(a) != len(b):
        return -1.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return -1.0
    return dot / (na * nb)


class RecommendView(View):
    template_name = "recs/recommend.html"

    def get(self, request):
        query = request.GET.get("q", "").strip()
        ctx = {"query": query, "results": []}

        if not query:
            return render(request, self.template_name, ctx)

        # 1) embedding del prompt del usuario
        q_vec = embed_text(query)

        # 2) calculamos similitud con TODAS las películas
        candidatos = []
        for mv in MovieVector.objects.select_related("movie"):
            v = json.loads(mv.vector_json)
            s = cosine(q_vec, v)
            candidatos.append((s, mv.movie))

        # 3) ordenamos de mayor a menor similitud
        candidatos.sort(key=lambda x: x[0], reverse=True)

        # 4) nos quedamos con los TOP K (por ejemplo 5)
        TOP_K = 5
        resultados = []
        for score, movie in candidatos[:TOP_K]:
            resultados.append({
                "movie": movie,
                "score": round(score, 4),  # redondeo
            })

        ctx["results"] = resultados
        return render(request, self.template_name, ctx)
