# Suivi Rapport PFE — fichier de reprise

Dernière mise à jour : 2026-07-10. Ce fichier remplace/complète `README_suivi_corrections.md` (qui vivait uniquement dans un dossier temporaire de session et ne survivait pas d'une conversation à l'autre). Celui-ci est sauvegardé à la racine de ton dossier projet — il doit être là à chaque nouvelle conversation.

## 🔴 REPRENDRE ICI

**Fichier de rapport le plus à jour : `Rapport_RYME_cited_v3.docx`** (à la racine du dossier projet). Contient tout ce que v2 avait (numérotation, Gantt, bibliographie 19/20, fuite WhatsApp nettoyée, page blanche corrigée, Tableau 3 + API Gateway) PLUS la nouvelle section 2.1.4 "Solutions existantes sur le marché" (remarque #12) déjà insérée et vérifiée par rendu PDF (voir détail plus bas). `Rapport_RYME_cited_v2.docx` reste dans le dossier mais est dépassé — **repars de v3**.

⚠️ **Avant toute chose, ouvrir v3 dans Word et faire Ctrl+A puis F9** pour rafraîchir la Liste des tableaux/figures et la table des matières (elles pointent encore vers l'ancien contenu tant que Word ne les a pas recalculées — comportement normal, déjà documenté plus bas).

Ce qu'il reste à faire, dans l'ordre logique :
1. **[10/07] Revirement sur le chapitre captures d'écran : ilyass a fourni un tout nouveau jeu de 44 vraies captures réelles** (dossier `C:\Users\Admin\Desktop\Personal\Screenshots`, organisé par rôle), bien meilleur que les 20 initiales. Mapping complet fait sur les 19 emplacements requis — voir section dédiée plus bas "Chapitre 4.1.2/4.1.3/4.1.4 — captures réelles, mapping complet (10/07)". 14 des 19 emplacements sont couverts par du réel ; 5 restent introuvables (flux de commande en 3 étapes, notifications, facture, et les 2 scénarios avant/après incomplets). Décision à prendre par ilyass : soit il recapture ces 5 cas précis dans l'app, soit on retombe sur des mockups ChatGPT seulement pour ceux-là (le brief `Brief_captures_ChatGPT.md` reste valable comme référence de style pour ce fallback ciblé).
2. Décider et appliquer le fix Flask (§3.1.3) et le paragraphe JWT/HTTPS — textes déjà rédigés plus bas dans ce fichier, prêts à coller (à repasser au `/humanizer` avant insertion finale).
3. Une fois les 5 emplacements manquants tranchés : insérer les 19 images dans le rapport avec titres/légendes (même format que les autres figures, numérotation Figure X automatique).
4. Toujours en attente : les 3 diagrammes §2.1 (remarque #13, rôles/outils/solution) régénérés par ChatGPT ont été collés dans le chat mais jamais enregistrés en fichier — donc toujours pas insérables. Il faut qu'ilyass les sauvegarde quelque part et donne le chemin.

⚠️ **Dossier `captures_pour_rapport/`** : en voulant vérifier son contenu aujourd'hui, j'ai eu des résultats incohérents (le dossier apparaît puis "n'existe plus" selon la commande utilisée — probablement un souci de synchronisation du dossier monté, pas forcément un vrai problème sur ton disque). **Vérifie toi-même dans l'explorateur de fichiers Windows** si les captures triées et `Brief_captures_ChatGPT.md` y sont encore. Par sécurité, j'ai remis une copie de `Brief_captures_ChatGPT.md` directement à la racine du projet.

⚠️ **Git** : la branche `temp` locale et `origin/temp` (GitHub) pointent sur le même commit — ton push a l'air d'être passé (le problème de compte/403 dont on parlait semble résolu). À confirmer de ton côté à l'ouverture. Note technique : `git status` échoue dans mon environnement sandbox ("index file corrupt") à cause d'une incompatibilité de version d'outil, pas d'un vrai souci sur ton repo — ignore ce message si tu le revois via moi, fie-toi à ton propre terminal.

---

## Fichiers du projet — où est quoi

| Fichier | Emplacement | Statut |
|---|---|---|
| `Rapport_RYME_cited_v2.docx` | racine du dossier projet | ✅ Version la plus à jour, à utiliser |
| `Brief_captures_ChatGPT.md` | racine du dossier projet | ✅ Brief complet pour générer les 19 images du chapitre 4.2 |
| `SUIVI_RAPPORT_PFE.md` (ce fichier) | racine du dossier projet | ✅ Ce fichier |
| `captures_pour_rapport/` (vraies captures triées + doublon du brief) | sous-dossier du projet | ⚠️ Existence à reconfirmer manuellement (voir note ci-dessus) |
| `Review_MOUNFALOUTI.docx` (la revue du jury) | — | Pas dans le dossier projet — le ré-uploader si besoin dans une prochaine conversation |

## Suivi des remarques (tracker complet)

| # | Thème | Remarque | Statut | Notes / décisions |
|---|-------|----------|--------|--------------------|
| 1 | Structure générale | Décalage de numérotation : Introduction et Conclusion générale comptées comme chapitres 1 et 6 | ✅ Fait | Styles corrigés (Intro/Conclusion non numérotés) + paragraphe roadmap réécrit et humanisé, confirmé par ilyass. |
| 2 | Structure générale | Chapitre Réalisation déséquilibré (que la BDD + tests, pas d'interfaces, pas de Gantt) | 🔧 En cours — 14/19 images réglées | Gantt + renommage + BDD : ✅ fait. Sous-sections confirmées : 4.1.2 Interfaces principales / 4.1.3 Fonctionnalités développées / 4.1.4 Scénarios d'exécution, sous 4.1 Implémentation de la solution. **[10/07] Revirement** : ilyass a fourni 44 vraies captures (dossier `Screenshots/`), bien meilleures que les 20 initiales → mapping complet fait, 14/19 emplacements couverts par du réel, 5 gaps identifiés (détail dans la section dédiée plus bas). Le brief ChatGPT reste en réserve pour ces 5 cas seulement si ilyass ne peut pas les recapturer. |
| 3 | UML / conception | 14 classes en conception (§3.6) vs tables documentées en réalisation (§4.1.1), écart non expliqué | 🔧 Remis en question le 09/07 | Résolu initialement en AJOUTANT de la doc (sous-sections 4.1.1.1 à 4.1.1.11, une par table). ⚠️ ilyass reconsidère (09/07) : le jury avait littéralement demandé de SUPPRIMER les tables de la partie Réalisation, pas d'en rajouter. Discuté 3 options (suppression totale / suppression avec explications gardées en prose / ne rien faire pour l'instant) — ilyass a choisi de laisser en pause pour l'instant, décision pas encore prise. Ne pas toucher aux sous-sections 4.1.1.1-4.1.1.11 tant que ce n'est pas tranché. |
| 4 | UML / conception | Diagramme de séquence §3.9 fusionne 4 scénarios (envoi/consultation/commentaire/téléchargement) | ✅ Fait | Scindé en 4 diagrammes (Figures 16-19), confirmé. Titres + description de chaque diagramme fournis (contenu détaillé conservé dans le journal ci-dessous si besoin de le regénérer). |
| 5 | Architecture logicielle | "API Gateway" (§3.3.2) ambigu — vrai composant ou juste routeur REST ? | ✅ Fait | Vérifié dans le vrai code (backend/app.py, Flask monolithique, pas de Kong/Nginx/Traefik) — paragraphe de remplacement fourni et appliqué par ilyass. |
| 6 | Mise en forme | Tableau 3 (§2.5.2) titré "besoin non fonctionnelle" au lieu de "besoins fonctionnels" | ✅ Fait | Confirmé par ilyass. |
| 7 | Mise en forme | Figure "Table Commande..." — double deux-points | ✅ Fait | Déjà réglé, plus de double deux-points nulle part. |
| 8 | Mise en forme | Légendes avec noms de fichiers WhatsApp / chemins Windows visibles | ✅ Fait | Le vrai problème était le texte alternatif (`descr`) de 10 images (Figures 9, 10, 11, 20-26), invisible à la lecture mais présent dans le XML. Nettoyé sur les 20 occurrences concernées. |
| 9 | Bibliographie | Aucune des 20 références appelée dans le corps du texte | ✅ Fait | 19/20 citations `[n]` insérées directement dans le fichier. `[12]` Scrum volontairement laissé de côté (aucun ancrage légitime dans le texte). Vérifié programmatiquement : chaque numéro 1-20 apparaît exactement 2 fois (citation + entrée bibliographie), sauf 12 (1 fois). |
| 10 | Autre | Framework backend Python non précisé (Flask/Django/FastAPI ?) | ⏳ Pas encore appliqué | Confirmé comme vraie remarque du jury (pas une déduction). Le code EST du Flask. Texte prêt à coller, voir section dédiée plus bas. |
| 11 | Autre | JWT / HTTPS listés dans les abréviations mais jamais développés dans le texte | ⏳ Pas encore appliqué | Vérifié dans le vrai code : ni JWT ni HTTPS ne sont implémentés (seulement hachage Werkzeug + CORS). Deux options + texte détaillé prêts plus bas. |
| 12 | Analyse de l'existant | Analyse de l'existant limitée au client (pas d'étude comparative des solutions du marché, pas d'argumentaire "pourquoi développer plutôt qu'acheter") | ✅ Fait | Nouvelle sous-section 2.1.4 "Solutions existantes sur le marché" insérée directement dans le docx (entre 2.1.3 et 2.2 Problématique), avec Tableau 1 (comparatif Odoo / VanGo Van Sales / solutions marocaines de caisse) + paragraphe de synthèse build-vs-buy. Style du titre, du tableau et de la légende répliqués exactement depuis le fichier réel (style `1--Titre3` pour le titre = numérotation auto en 2.1.4, style `2--Tableauprofessionnel` pour le tableau, légende avec champ SEQ Tableau = renumérotation automatique des Tableaux 1-6 existants en 2-7 confirmée par rendu PDF). Livré dans `Rapport_RYME_cited_v3.docx`. |
| 13 | Analyse de l'existant (bonus) | §2.1 n'a aucune figure — 3 diagrammes existent mais seulement dans les slides de présentation (rôles Commercial/Manager/Admin, outils/limites, aperçu solution) | 🔧 Bloqué sur fichiers image | Ilyass a regénéré les 3 diagrammes via ChatGPT dans le bon style (vérifié : correspond bien aux Figures 2/4 déjà dans le rapport). **Blocage : ces 3 images ont été collées directement dans le chat, donc aucun fichier accessible pour les insérer dans le docx.** Pour débloquer : ilyass doit enregistrer les 3 PNG dans le dossier projet (n'importe quel sous-dossier), puis dire à Claude où ils sont. Une fois ça fait : deviennent Figure 7 (rôles, fin 2.1.1), Figure 8 (outils/limites, fin 2.1.3), Figure 9 (solution, fin 2.3) — décale les Figures 7-31 existantes en 10-34. Aucune référence "Figure X" en dur trouvée dans le corps du texte → renumérotation 100% sûre via Ctrl+A puis F9 une fois les images posées. |

Légende : ✅ Fait · 🔧 En cours · ⏳ Pas encore appliqué · 🆕 Nouveau, pas cadré

---

## Textes prêts à coller

### Remarque #10 — nommer Flask explicitement (§3.1.3, sous-section Python)
À ajouter à la phrase existante sur Python :

> Le framework backend retenu est Flask, un micro-framework Python léger, choisi pour sa simplicité de mise en œuvre et son adéquation avec le développement d'une API REST comme celle de ce projet.

### Remarque #11 — JWT/HTTPS

**Option A (rapide) :** supprimer "JWT" et "HTTPS" de la liste des abréviations, puisqu'ils ne sont pas implémentés — évite le problème sans rien affirmer de faux.

**Option B (paragraphe honnête, plus complet)** — à ajouter dans la section sécurité/backend :

> Concernant la sécurité des accès, l'authentification repose actuellement sur un hachage des mots de passe via la bibliothèque Werkzeug (fonctions generate_password_hash et check_password_hash), sans mécanisme de jeton JWT pour la gestion des sessions. La communication entre l'application mobile et le serveur n'est pas encore chiffrée via HTTPS dans l'environnement de développement actuel ; l'API est toutefois protégée contre les requêtes cross-origin non autorisées grâce à CORS. Le passage à une authentification par jeton JWT et à un déploiement en HTTPS constitue une amélioration prioritaire identifiée pour une mise en production.

⚠️ Les deux textes ci-dessus n'ont pas encore été repassés au skill `/humanizer` — à faire avant de les coller dans le rapport final.

---

## Diagnostics techniques détaillés (à garder pour référence/soutenance)

### Remarque 3 — répartition des 14 classes vs tables réelles
- Utilisateur/Commercial/Manager/Administrateur (4 classes) → une seule table `users` + colonne `role` (single table inheritance, choix valide non justifié à l'écrit à l'origine, maintenant documenté).
- Client, Produit, Commande, Activité, RapportJournalier → tables présentes, documentées.
- LigneCommande → implémentée sous le nom `details_facture`, désormais documentée.
- Notification → table `notifications`, désormais documentée.
- Objectif, Paramètre, JournalActivité → pas de table correspondante trouvée, positionnées comme non implémentées / perspectives d'évolution.

### Remarque 4 — contenu des 4 diagrammes de séquence (vérifié dans le vrai code, pas inventé)
1. **Envoi du rapport (Commercial)** — Commercial → App → `POST /rapports` (backend/app.py L1111) → BDD (insert `rapports`) → Service Notification → notifie Manager.
2. **Consultation du rapport (Manager)** — Manager → App → `GET /rapports` (L1111) → BDD (lecture) → affichage liste ; puis `PATCH /rapports/<id>/read` (L1193) → BDD (statut lu).
3. **Ajout d'un commentaire (Manager)** — Manager → App → `POST /rapports/<id>/comments` (L1213) → BDD (insert commentaire) → Service Notification → notifie Commercial.
4. **Téléchargement PDF (Manager)** — 100% local, pas d'appel backend : génération via `PdfService`/`Printing` (`lib/screens/manager/home_manager_screen.dart::_downloadPdf`/`_buildReportPdf`) → `Printing.sharePdf`.

### Bug page blanche (déjà corrigé)
Cause : saut de page manuel (`<w:br w:type="page"/>`) cumulé avec le saut de page automatique du style du titre "Liste des figures" (`1-- Titre1sn` → `1-- Titre1` → `pageBreakBefore`). Fix : suppression du paragraphe de saut manuel superflu. ⚠️ Si ça se reproduit ailleurs (Bibliographie, Conclusion générale utilisent le même style à saut auto) : ne jamais ajouter Ctrl+Entrée avant un titre "1-- Titre 1 sn"/"1-- Titre 1", le style s'en charge déjà.

### Table des matières (TOC) — règle d'or
Ne JAMAIS supprimer/réinsérer le TOC via le ruban Word (Références > Table des matières) — ça remplace le champ custom par un champ générique et casse le mapping de styles. Toujours : clic droit dans le TOC existant → "Mettre à jour les champs" → "Toute la table".

---

## Chapitre 4.2 — pivot vers mockups ChatGPT (contexte complet)

Les vraies captures d'écran de l'app (20 fournies) ont été auditées image par image. Verdict : plusieurs incomplètes (coupées avant la fin du contenu), une cassée (spinner de chargement vide), deux doublons mal étiquetés (fichiers "16" et "16a" identiques au dashboard admin malgré des noms suggérant "Clients"/"drawer"). Décision d'ilyass : abandonner ces captures entièrement et regénérer un jeu complet et cohérent via ChatGPT (qui génère du code/HTML, pas de l'image IA — donc bugs = bugs CSS à corriger, pas des artefacts de génération d'image).

`Brief_captures_ChatGPT.md` (racine du projet) contient : contraintes techniques (ratio portrait ~780×1690px, écrans jamais coupés), charte de couleurs stricte par rôle (Commercial=bleu, Manager=bleu marine+bleu, Admin=bleu marine+**vert**, distinct exprès), toutes les données à réutiliser partout pour la cohérence (noms, montants, IDs de commandes), et la liste complète des 19 images à générer réparties en §4.2.1 (4 images), §4.2.2 (13 images, y compris les écrans jamais capturés avant : notifications, flux de création de commande en 3 étapes, écran facture), §4.2.3 (2 scénarios avant/après).

Premier essai de ChatGPT : bug CSS repéré (texte empilé verticalement lettre par lettre, probablement `flex-direction: column` ou conteneur trop étroit) + dérive sur noms de marque/données par rapport au brief — à corriger avant de regénérer le jeu complet.

**[10/07] Ce plan B n'a plus lieu d'être pour la majorité des cas** : voir section suivante, ilyass a fourni un nouveau jeu de vraies captures bien plus complet.

---

## Chapitre 4.1.2/4.1.3/4.1.4 — captures réelles, mapping complet (10/07)

Nouveau dossier fourni par ilyass : `C:\Users\Admin\Desktop\Personal\Screenshots` — 44 fichiers réels (login + 13 Admin + 15 Commercial + 15 Manager), organisés par rôle. Chaque image vérifiée individuellement (ouverte une par une, pas juste les noms de fichiers) : rendu propre partout, aucun écran coupé/cassé/dupliqué comme sur le lot précédent. Toutes les données (noms, montants, IDs commandes) sont cohérentes avec ce qui est déjà dans le rapport (ex. 87 900 DH, 20 clients, 20 produits).

Mode guidage uniquement — rien n'a été touché dans le docx, juste la correspondance ci-dessous.

### §4.1.2 — Interfaces principales (4/4 couverts)

| # | Écran demandé | Fichier(s) | Note |
|---|---|---|---|
| 1 | Écran de connexion | `login.png` | Correspond exactement. |
| 2 | Accueil Commercial | `Commercial/home.png` + `home_2.png` | Écran scrollé en 2 captures (perf + stats, puis graphique + actions rapides + dernières commandes). Utilisateur réel = Sara, pas Ahmed — sans importance. Empiler les deux comme Figure (a)/(b), ou choisir `home.png` seul si une seule image suffit. |
| 3 | Accueil Manager | `Manager/home.png` + `home_2.png` + `home_3.png` | Scrollé en 3. Les 2 premières couvrent l'essentiel (8 cartes stats + graphique + répartition + top commerciaux) ; `home_3.png` (activités récentes + actions rapides) est un bonus, pas indispensable si tu veux limiter à 2 images. |
| 4 | Accueil Administrateur | `Admin/home.png` | Une seule capture complète, rien à ajouter. |

### §4.1.3 — Fonctionnalités développées (9/13 couverts)

| # | Module demandé | Fichier(s) | Note |
|---|---|---|---|
| 5 | Gestion des clients (Commercial) | `Commercial/clients.png` | OK. |
| 6 | Gestion des commandes (Commercial) | `Commercial/commandes.png` | OK (seulement 2 commandes visibles pour Sara, c'est la vraie donnée — pas un défaut). |
| 7 | Création commande — étape 1 (client + infos) | ❌ **Manquant** | Aucun fichier de type "nouvelle commande" dans `Commercial/`. |
| 8 | Création commande — étape 2 (produits) | ❌ **Manquant** | Idem. |
| 9 | Création commande — étape 3 (panier) | ❌ **Manquant** | Idem. |
| 10 | Gestion des activités | `Commercial/activities.png` | OK. |
| 11 | Rapports — envoi (Commercial) | `Commercial/rapport_journalier.png` | ⚠️ Capturé un jour à zéro (0 visite, 0 commande, "Aucune visite planifiée") — fonctionnel mais moins parlant qu'un jour avec de vraies données. Utilisable tel quel, ou à reprendre si tu as 2 minutes après avoir loggé une visite. |
| 12 | Rapports — réception (Manager) | `Manager/rapports.png` + `rapports_2.png` | OK, montre bien 3 commerciaux avec statut. |
| 13 | Panneau de notifications | ❌ **Manquant** | Aucun fichier "notifications" dans tout le dossier. |
| 14 | Gestion des objectifs (Manager) | `Manager/objectifs.png` (+ `objectifs_info.png` en bonus, détail d'un commercial) | OK. |
| 15 | Gestion des utilisateurs (Admin) | `Admin/utilisateurs.png` | OK, les 5 utilisateurs visibles. |
| 16 | Gestion des produits (Admin) | `Admin/produits.png` | OK, 5 produits visibles. |
| 17 | Gestion des factures (InvoiceScreen) | ❌ **Manquant** | Aucun écran facture dédié capturé. Le détail de commande (`*/commandes_info*.png`) a un bouton PDF qui peut servir de repli si l'app n'a pas d'écran facture séparé — à confirmer. |

### §4.1.4 — Scénarios d'exécution (2/2 demandés, mais incomplets)

| # | Scénario | Disponible | Note |
|---|---|---|---|
| 18 | Commande : en attente → validée | Partiel | Pas de même commande capturée dans les 2 états. On peut illustrer avec 2 commandes différentes (une "En attente", une "Validée" dans `Manager/commandes.png`/`commandes_info.png`) mais ce n'est pas un vrai avant/après de la même commande — dépend de si tu veux la rigueur du "même objet" ou juste illustrer les 2 états. |
| 19 | Rapport : envoyé → lu | Partiel | `rapport_journalier.png` montre le bouton "Envoyer au manager" mais grisé (rien à envoyer ce jour-là) ; côté Manager, `rapports.png`/`rapports_2.png` montre l'état "non lu", mais aucune capture ne montre l'état "lu" après consultation. |

### Bilan : 14/19 couverts par du réel, 5 gaps (items 7, 8, 9, 13, 17 + les 2 scénarios imparfaits)

Deux options pour les gaps, à décider par ilyass :
1. Recapturer ces écrans précis dans l'app (le plus rapide si l'app tourne encore en local — 5 captures + reprendre le rapport journalier un jour avec activité).
2. Générer ces cas précis (et seulement ceux-là) via le brief ChatGPT existant, en copiant la charte de couleur/style depuis les captures réelles plutôt que l'ancien brief générique, pour que ça se fonde avec le reste.

---

## Préférences ilyass (contraintes permanentes, à respecter dans toute nouvelle conversation)

- Toujours passer par le skill `/humanizer` pour tout texte rédigé destiné au rapport (paragraphes, phrases de remplacement) avant de le livrer.
- Mode par défaut = **guidage texte uniquement** (quoi écrire, où, quel style) — ne PAS modifier/repacker le .docx directement sauf demande explicite d'ilyass. (Exception déjà appliquée plusieurs fois ce mois-ci quand demandé explicitement : bug page blanche, citations bibliographie, nettoyage alt-text.)
- Ne pas sur-livrer / ne pas supposer le scope maximal par défaut — présenter les compromis honnêtement plutôt que de choisir à sa place.
- Exigence de rigueur : ne pas se contenter d'un premier passage superficiel (ex. audit des captures d'écran) — vérifier vraiment avant d'affirmer que quelque chose est fait/correct.

## Journal (résumé chronologique)
- Diagnostic et correction remarques #1, #2 (partiel), #3, #4, #5, #6, #7, #8, #9 — voir tableau ci-dessus pour détail.
- Découverte remarque #12 (analyse de l'existant) dans le tableau détaillé de la revue, cadrée puis section 2.1.4 rédigée et insérée dans `Rapport_RYME_cited_v3.docx` (comparatif Odoo/VanGo/solutions marocaines).
- Audit complet des 20 premières captures d'écran réelles → défauts multiples identifiés → décision d'abandonner cette voie et de passer par génération ChatGPT.
- `Brief_captures_ChatGPT.md` rédigé et livré ; premier essai ChatGPT avec bug CSS (texte vertical) — diagnostic donné.
- 3 diagrammes §2.1 (remarque #13) régénérés par ChatGPT dans le bon style, collés dans le chat mais jamais enregistrés en fichier → toujours bloqué.
- Bug d'espacement numéro/titre des headings (Titre1-4) diagnostiqué sur plusieurs rounds (tab-stop, puis largeur de tabulation, puis piste police de substitution) — fix le plus robuste (`w:suff="space"` + suppression des espaces manuels redondants) resté inachevé en sandbox, jamais livré comme fichier final. À reprendre si le sujet revient.
- Question structurelle tranchée : Interfaces principales / Fonctionnalités développées / Scénarios d'exécution → sous-sections 4.1.2/4.1.3/4.1.4 de "4.1 Implémentation de la solution" (pas sous Tests et résultats).
- **[10/07] Nouveau dossier de 44 vraies captures fourni** (`Screenshots/`, organisé par rôle) → chaque image vérifiée individuellement, mapping complet fait sur les 19 emplacements requis (14 couverts, 5 gaps) — détail dans la section dédiée ci-dessus. Bien meilleur que le lot des 20 initiales, remet les vraies captures au centre du jeu pour la majorité des cas.
- Tangente Git : branche `temp` créée, stash/checkout/fetch pour éviter de perdre le travail, push bloqué par une erreur 403 (mauvais compte GitHub identifié) → d'après l'état du repo vérifié début juillet, le push semble être passé depuis (local `temp` = `origin/temp`).
