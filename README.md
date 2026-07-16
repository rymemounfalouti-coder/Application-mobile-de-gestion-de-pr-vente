# TeaSud Prévente

## Présentation hors ligne (recommandé)

Le mode démo contient ses propres utilisateurs et données. Il ne dépend ni de
PostgreSQL ni du backend Flask.

```powershell
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Comptes de démonstration (mot de passe commun : `123456`) :

- Commercial : `sara@presales.ma`
- Manager : `manager@presales.ma`
- Administrateur : `admin@presales.ma`

Les modifications réalisées pendant la démo restent disponibles jusqu'au
redémarrage de l'application. Un redémarrage remet les données de démonstration
dans leur état initial.

## Vérifications avant la présentation

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define=DEMO_MODE=true
```

## Mode connecté au backend

Le mode normal exige une base PostgreSQL. Le script `backend/setup_db.py`
installe le schéma, le compte administrateur et le catalogue TeaSud de 20
produits.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt

$env:DB_HOST='localhost'
$env:DB_NAME='prevente_db'
$env:DB_USER='postgres'
$env:DB_PASSWORD='<mot-de-passe-local>'
$env:JWT_SECRET_KEY='<secret-long-et-aléatoire>'
$env:CORS_ALLOWED_ORIGINS='http://localhost:3000,http://localhost:8080'

python app.py
```

Pour restaurer uniquement les données initiales dans une base déjà créée,
sans modifier ni dupliquer les produits existants :

```powershell
cd backend
python setup_db.py --seed-only
```

Sous Windows, le catalogue seul peut aussi être restauré avec une invite de
mot de passe locale (le mot de passe n'est ni affiché ni enregistré) :

```powershell
.\backend\restore_demo_products.ps1
```

Dans un second terminal :

```powershell
flutter run -d chrome
```

Tests backend :

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
pytest -q
```

Les tests marqués comme intégration PostgreSQL nécessitent en plus
`$env:RUN_DB_TESTS='1'` et une base compatible accessible.
