from typing import List, Dict
import json
import os

from django.conf import settings
from openai import OpenAI

# Cliente OpenAI usando la API key que cargamos en settings
client = OpenAI(api_key=getattr(settings, "OPENAI_API_KEY", None))

# Modelos por defecto (puedes cambiar estos valores en openAI.env)
TEXT_MODEL = os.getenv("OPENAI_TEXT_MODEL", "gpt-4o-mini")
EMB_MODEL = os.getenv("OPENAI_EMB_MODEL", "text-embedding-3-small")
IMG_MODEL = os.getenv("OPENAI_IMAGE_MODEL", "gpt-image-1")


def generate_movie_descriptions(seed_titles: List[str]) -> List[Dict]:
    """
    Dado una lista de títulos, devuelve lista de dicts:
    [{name, description, url, prompt_image}]
    """
    system = "Eres un asistente que crea descripciones concisas de películas para una base de datos."
    user = (
        "Genera un JSON con este formato exacto:\n"
        "{ \"movies\": [ {\"name\": \"...\", \"description\": \"...\", \"url\": \"...\", \"prompt_image\": \"...\"}, ... ] }\n\n"
        "NO expliques nada, NO añadas texto fuera del JSON, solo devuelve el JSON.\n"
        "Para cada título dado crea:\n"
        "- name: el título de la película\n"
        "- description: máx 90 palabras, tono informativo\n"
        "- url: un enlace de referencia (por ejemplo IMDb o trailer oficial)\n"
        "- prompt_image: un prompt breve para una ilustración representativa, sin texto sobre la imagen.\n\n"
        f"Títulos: {seed_titles}"
    )

    resp = client.responses.create(
        model=TEXT_MODEL,
        input=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )

    # Sacar el texto de la respuesta (primer output)
    try:
        output_text = resp.output[0].content[0].text
    except Exception as e:
        print("No se pudo leer el texto de la respuesta:", e)
        return []

    # 🔧 LIMPIAR ``` y ```json si vienen como bloque de código
    output_text = output_text.strip()
    if output_text.startswith("```"):
        lines = output_text.splitlines()
        # quitar primera línea si empieza con ```
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        # quitar última línea si es ```
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        output_text = "\n".join(lines).strip()

    # Intentar parsear JSON
    try:
        data = json.loads(output_text)
    except Exception as e:
        print("La respuesta no es JSON válido. Texto recibido:")
        print(output_text)
        return []

    return data.get("movies", [])


def generate_image(prompt: str) -> str:
    """
    Genera una imagen y retorna una URL de la imagen generada.
    """
    img = client.images.generate(
        model=IMG_MODEL,
        prompt=prompt,
        size="1024x1024",
    )
    return img.data[0].url


def embed_text(text: str) -> List[float]:
    """
    Devuelve el embedding (lista de floats) para un texto.
    """
    emb = client.embeddings.create(model=EMB_MODEL, input=text)
    return emb.data[0].embedding
