# mkpl — Générateur de playlist M3U8

Script Ruby qui parcourt un répertoire contenant des vidéos MP4, extrait leurs métadonnées (durée, titre) via `ffprobe` et produit un fichier `playlist.m3u8` prêt à être lu par tout lecteur multimédia compatible HLS (VLC, mpv, etc.).

## Fonctionnalités

- Détection des fichiers `.mp4` et `.MP4`
- Extraction de la durée et du titre avec `ffprobe`
- Tri alphabétique des entrées
- Remplacement automatique des virgules dans les titres (respect de la syntaxe M3U8)
- Chemins absolus dans la playlist pour éviter les problèmes de résolution
- Aucune dépendance Ruby externe pour l'exécution (seulement `ffprobe`)

## Prérequis

- Ruby ≥ 3.0
- `ffprobe` (fourni par le paquet `ffmpeg`)

```bash
# Debian / Ubuntu
sudo apt install ffmpeg

# macOS
brew install ffmpeg
```

## Installation

```bash
bundle install
```

## Utilisation

### Directement

```bash
ruby mkpl.rb /chemin/vers/le/repertoire
```

Exemple sur le répertoire courant :

```bash
ruby mkpl.rb .
```

### Via Rake

```bash
# Lancer les tests
bundle exec rake test

# Exécuter le script
bundle exec rake run[/chemin/vers/le/repertoire]
```

## Format de sortie

Le fichier `playlist.m3u8` est créé dans le répertoire cible :

```m3u8
#EXTM3U
#EXTINF:5749.38,lesson1.mp4
/home/greg/Videos/cours/lesson1.mp4
#EXTINF:51.50,lesson10.mp4
/home/greg/Videos/cours/lesson10.mp4
```

| Directive | Description |
|---|---|
| `#EXTM3U` | En-tête obligatoire de tout fichier M3U |
| `#EXTINF:<durée>,<titre>` | Métadonnées d'une entrée (durée en secondes, titre) |
| `<chemin>` | Chemin absolu vers le fichier vidéo |

## Structure du projet

```
.
├── mkpl.rb              # Script principal
├── Rakefile             # Tâches de test et d'exécution
├── Gemfile              # Dépendances (minitest, rake)
├── test/
│   └── mkpl_test.rb     # Suite de tests (11 tests)
├── playlist.m3u8        # Fichier généré (créé à la racine du répertoire cible)
├── lesson1.mp4          # … vidéos MP4 …
└── lesson2.mp4
```

## Tests

La suite utilise **minitest** et couvre :

- Erreur sur répertoire inexistant
- Absence de fichier vidéo → pas de playlist créée
- Cohérence du format M3U8 (en-tête, `#EXTINF`)
- Tri alphabétique des entrées
- Gestion des extensions `.MP4` majuscules
- Remplacement des virgules dans les titres

```bash
bundle exec rake test
```

## Licence

MIT
