"""Regression checks for the TeaSud product seed's category encoding repair."""

from pathlib import Path


SEED_SQL = (
    Path(__file__).resolve().parents[1] / "seed_demo_products.sql"
).read_text(encoding="utf-8")


def test_seed_uses_canonical_french_category_names():
    assert "Thé vert en filaments" in SEED_SQL
    assert "Thé vert en grains Gunpowder" in SEED_SQL
    assert "ThÃ" not in SEED_SQL


def test_seed_repairs_existing_categories_and_products():
    assert "UPDATE public.categories" in SEED_SQL
    assert "UPDATE public.produits product" in SEED_SQL
    assert "SET categorie = repair.category" in SEED_SQL
