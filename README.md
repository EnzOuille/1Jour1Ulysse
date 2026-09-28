# 1 Jour 1 Ulysse

Chaque jour, une photo d'Ulysse, berger australien noir tricolore né le 10 juillet 2023.

## Ajouter des photos

1. Copiez les photos dans le dossier **`originaux/`** (JPG, PNG, HEIC, WebP… ; sous-dossiers acceptés).
   Si vous les déposez dans `photos/` par erreur, le script les déplace automatiquement dans `originaux/`.
2. Double-cliquez sur :
   - **`Mettre à jour les photos.bat`** pour voir le résultat sur votre PC (ouvrez `index.html`) ;
   - **`Publier le site.bat`** pour mettre en ligne sur GitHub Pages.

Le script (`update-photos.ps1`, nécessite [ImageMagick](https://imagemagick.org)) :
- crée dans `photos/` une copie **nettoyée** de chaque photo : aucune métadonnée (GPS, date, modèle de téléphone…), taille réduite (2000 px), nom anonyme, plus une miniature dans `photos/mini/` ;
- met à jour le **calendrier** dans `photos.js` : un jour passé garde toujours sa photo ; les jours suivants montrent d'abord les photos jamais vues, puis piochent au hasard sans répétition rapprochée.

## Confidentialité

- `originaux/` est exclu de git (`.gitignore`) : **les originaux ne quittent jamais le PC**.
- Avant chaque publication, le script vérifie octet par octet que chaque photo publiée ne contient aucun bloc de métadonnées, et refuse de publier toute image qui ne vient pas du traitement.
- **Identité git** : chaque publication enregistre un nom et une adresse e-mail, visibles publiquement. La publication est bloquée tant que l'adresse n'est pas l'adresse anonyme de GitHub. Pour la configurer, **pour ce projet uniquement** :
  1. Sur GitHub : *Settings → Emails* → cochez **Keep my email addresses private** (et *Block command line pushes that expose my email*). Copiez l'adresse affichée, du type `12345678+pseudo@users.noreply.github.com`.
  2. Dans ce dossier :
     ```
     git config user.email "12345678+pseudo@users.noreply.github.com"
     git config user.name "pseudo"
     ```

## Mise en ligne (une seule fois)

1. Sur GitHub, le dépôt doit être **public** (GitHub Pages gratuit l'exige).
2. Lancez `Publier le site.bat` une première fois.
3. Sur GitHub : *Settings → Pages* → *Deploy from a branch* → `main` / `(root)` → *Save*.
4. Le site est en ligne à l'adresse `https://<pseudo>.github.io/1Jour1Ulysse/`.

## Réglages

- `START_DATE` (en haut de `app.js`) : le « Jour 1 » du site.
- Photo de la présentation : déposez un fichier nommé **`portrait.jpg`** (ou .png, .heic…) dans `photos/` ou `originaux/`, puis lancez le script. L'original est rangé dans `originaux/portrait/` et une copie nettoyée devient `photos/portrait.jpg`.
- Le texte de présentation se modifie dans `index.html`.
