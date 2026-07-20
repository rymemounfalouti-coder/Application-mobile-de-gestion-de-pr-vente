-- Restore the 20-product TeaSud catalog used by the Flutter demo.
--
-- This seed is intentionally additive and idempotent:
--   * existing products are matched by reference/ref/code;
--   * known category text and links are repaired when stale or misencoded;
--   * missing products receive fresh sequence-backed IDs;
--   * rerunning the file does not create duplicates.

BEGIN;

-- Repair legacy rows where UTF-8 text was decoded and encoded a second time.
-- Matching the stable suffix avoids carrying the corrupt byte sequence forward.
UPDATE public.categories
SET nom_cat = 'Thé vert en filaments'
WHERE LOWER(nom_cat) LIKE '%vert en filaments';

UPDATE public.categories
SET nom_cat = 'Thé vert en grains Gunpowder'
WHERE LOWER(nom_cat) LIKE '%vert en grains gunpowder';

INSERT INTO public.categories (nom_cat)
SELECT seed.nom_cat
FROM (
    VALUES
        ('Thé vert en filaments'),
        ('Thé vert en grains Gunpowder')
) AS seed(nom_cat)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.categories existing
    WHERE LOWER(existing.nom_cat) = LOWER(seed.nom_cat)
);

WITH catalog (
    name,
    reference,
    category,
    description,
    image,
    price,
    stock
) AS (
    VALUES
        ('Assil Chaara Premium 200g', '41022-200',  'Thé vert en filaments',          '200g', 'assets/images/products/chaara_premium_200g.jpeg',     22, 120),
        ('Assil Chaara Premium 250g', '41022-250',  'Thé vert en filaments',          '250g', 'assets/images/products/chaara_premium_250g.jpeg',     27, 100),
        ('Assil Chaara Premium 500g', '41022-500',  'Thé vert en filaments',          '500g', 'assets/images/products/chaara_premium_500g.jpeg',     52,  90),
        ('Assil Chaara Premium 1kg',  '41022-1000', 'Thé vert en filaments',          '1kg',  'assets/images/products/chaara_premium_1kg.jpeg',      98,  70),
        ('Assil Chaara Premium 2kg',  '41022-2000', 'Thé vert en filaments',          '2kg',  'assets/images/products/chaara_premium_2kg.jpeg',     185,  50),
        ('Assil Chaara Classique 200g', '9305-200',  'Thé vert en filaments',         '200g', 'assets/images/products/chaara_classique_200g.jpeg',   18, 140),
        ('Assil Chaara Classique 250g', '9305-250',  'Thé vert en filaments',         '250g', 'assets/images/products/chaara_classique_250g.jpeg',   23, 130),
        ('Assil Chaara Classique 500g', '9305-500',  'Thé vert en filaments',         '500g', 'assets/images/products/chaara_classique_500.jpeg',    44, 110),
        ('Assil Chaara Classique 1kg',  '9305-1000', 'Thé vert en filaments',         '1kg',  'assets/images/products/chaara_classique_1kg.jpeg',     85,  80),
        ('Assil Chaara Classique 2kg',  '9305-2000', 'Thé vert en filaments',         '2kg',  'assets/images/products/chaara_classique_2kg.jpeg',    160,  60),
        ('Assil Al-Lamma Premium 200g', 'ALP-200',  'Thé vert en grains Gunpowder',   '200g', 'assets/images/products/allamma_premium_200g.jpeg',    20, 120),
        ('Assil Al-Lamma Premium 250g', 'ALP-250',  'Thé vert en grains Gunpowder',   '250g', 'assets/images/products/allamma_premium_250g.jpeg',    25, 110),
        ('Assil Al-Lamma Premium 500g', 'ALP-500',  'Thé vert en grains Gunpowder',   '500g', 'assets/images/products/allamma_premium_500g.jpeg',    49,  95),
        ('Assil Al-Lamma Premium 1kg',  'ALP-1000', 'Thé vert en grains Gunpowder',   '1kg',  'assets/images/products/allamma_premium_1kg.jpeg',     92,  75),
        ('Assil Al-Lamma Premium 2kg',  'ALP-2000', 'Thé vert en grains Gunpowder',   '2kg',  'assets/images/products/allamma_premium_2kg.jpeg',    175,  55),
        ('Assil Al-Lamma Classique 200g', 'ALC-200',  'Thé vert en grains Gunpowder', '200g', 'assets/images/products/allamma_classique_200g.jpeg', 16, 150),
        ('Assil Al-Lamma Classique 250g', 'ALC-250',  'Thé vert en grains Gunpowder', '250g', 'assets/images/products/allamma_classique_250g.jpeg', 21, 140),
        ('Assil Al-Lamma Classique 500g', 'ALC-500',  'Thé vert en grains Gunpowder', '500g', 'assets/images/products/allamma_classique_500g.jpeg', 40, 120),
        ('Assil Al-Lamma Classique 1kg',  'ALC-1000', 'Thé vert en grains Gunpowder', '1kg',  'assets/images/products/allamma_classique_1kg.jpeg',  78,  90),
        ('Assil Al-Lamma Classique 2kg',  'ALC-2000', 'Thé vert en grains Gunpowder', '2kg',  'assets/images/products/allamma_classique_2kg.jpeg', 150,  70)
)
INSERT INTO public.produits (
    nom_produit,
    name,
    reference,
    ref,
    code,
    description,
    categorie,
    category,
    id_cat,
    prix,
    price,
    prix_vente,
    unit_price,
    stock,
    quantite_stock,
    status,
    statut,
    image,
    photo
)
SELECT
    catalog.name,
    catalog.name,
    catalog.reference,
    catalog.reference,
    catalog.reference,
    catalog.description,
    catalog.category,
    catalog.category,
    (
        SELECT category_row.id
        FROM public.categories category_row
        WHERE LOWER(category_row.nom_cat) = LOWER(catalog.category)
        ORDER BY category_row.id
        LIMIT 1
    ),
    catalog.price,
    catalog.price,
    catalog.price,
    catalog.price,
    catalog.stock,
    catalog.stock,
    'actif',
    'actif',
    catalog.image,
    catalog.image
FROM catalog
WHERE NOT EXISTS (
    SELECT 1
    FROM public.produits existing
    WHERE LOWER(COALESCE(existing.reference, '')) = LOWER(catalog.reference)
       OR LOWER(COALESCE(existing.ref, '')) = LOWER(catalog.reference)
       OR LOWER(COALESCE(existing.code, '')) = LOWER(catalog.reference)
);

-- Existing products are not reinserted, but their duplicated category fields
-- still need to be canonicalized and linked to the repaired category row.
WITH category_repairs (reference, category) AS (
    VALUES
        ('41022-200',  'Thé vert en filaments'),
        ('41022-250',  'Thé vert en filaments'),
        ('41022-500',  'Thé vert en filaments'),
        ('41022-1000', 'Thé vert en filaments'),
        ('41022-2000', 'Thé vert en filaments'),
        ('9305-200',   'Thé vert en filaments'),
        ('9305-250',   'Thé vert en filaments'),
        ('9305-500',   'Thé vert en filaments'),
        ('9305-1000',  'Thé vert en filaments'),
        ('9305-2000',  'Thé vert en filaments'),
        ('ALP-200',    'Thé vert en grains Gunpowder'),
        ('ALP-250',    'Thé vert en grains Gunpowder'),
        ('ALP-500',    'Thé vert en grains Gunpowder'),
        ('ALP-1000',   'Thé vert en grains Gunpowder'),
        ('ALP-2000',   'Thé vert en grains Gunpowder'),
        ('ALC-200',    'Thé vert en grains Gunpowder'),
        ('ALC-250',    'Thé vert en grains Gunpowder'),
        ('ALC-500',    'Thé vert en grains Gunpowder'),
        ('ALC-1000',   'Thé vert en grains Gunpowder'),
        ('ALC-2000',   'Thé vert en grains Gunpowder')
)
UPDATE public.produits product
SET categorie = repair.category,
    category = repair.category,
    id_cat = (
        SELECT category_row.id
        FROM public.categories category_row
        WHERE LOWER(category_row.nom_cat) = LOWER(repair.category)
        ORDER BY category_row.id
        LIMIT 1
    )
FROM category_repairs repair
WHERE LOWER(COALESCE(product.reference, '')) = LOWER(repair.reference)
   OR LOWER(COALESCE(product.ref, '')) = LOWER(repair.reference)
   OR LOWER(COALESCE(product.code, '')) = LOWER(repair.reference);

SELECT setval(
    pg_get_serial_sequence('public.produits', 'id'),
    COALESCE((SELECT MAX(id) FROM public.produits), 1),
    (SELECT COUNT(*) > 0 FROM public.produits)
);

COMMIT;
