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
