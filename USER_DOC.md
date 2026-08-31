# USER_DOC.md

# Inception — Guide utilisateur

## 1. Présentation

Ce projet met en place une infrastructure WordPress composée de trois services Docker :

- **NGINX** : serveur web et point d'entrée HTTPS.
- **WordPress + PHP-FPM** : application web et exécution du code PHP.
- **MariaDB** : serveur de base de données utilisé par WordPress.

L'architecture est organisée ainsi :

```text
Navigateur
    |
    | HTTPS :443
    v
  NGINX
    |
    | FastCGI :9000
    v
WordPress / PHP-FPM
    |
    | MySQL :3306 (réseau Docker)
    v
 MariaDB
```

Seul NGINX expose un port vers la machine hôte. WordPress/PHP-FPM et MariaDB communiquent uniquement sur le réseau Docker `inception`.

---

## 2. Prérequis

Avant de lancer le projet, il faut disposer de :

- Docker
- Docker Compose
- `make`
- un système Linux/VM adapté au projet 42
- un nom de domaine local configuré vers la machine, ici `shapetit.42.fr`

Le projet utilise Debian Bullseye Slim comme base des trois images.

---

## 3. Configuration

Le dépôt contient des fichiers d'exemple :

```text
secrets/
├── db_password.txt.example
├── db_root_password.txt.example
└── credentials.txt.example

srcs/
└── .env.example
```

Il faut créer les vrais fichiers à partir des exemples.

### 3.1 Fichier `.env`

Créer :

```text
srcs/.env
```

avec par exemple :

```env
DOMAIN_NAME=shapetit.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=shapetit_user

MYSQL_ADMIN_USER=shapetit
```

### 3.2 Secrets

Créer :

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/credentials.txt
```

Le fichier `credentials.txt` doit contenir :

```env
WP_ADMIN_USER=shapetit_wp
WP_ADMIN_PASSWORD=<mot_de_passe>
WP_USER=user_wp
WP_USER_PASSWORD=<mot_de_passe>
```

Les fichiers réels de secrets et `.env` sont ignorés par Git grâce au `.gitignore`.

> Pour un usage réel, utiliser des mots de passe forts et ne jamais publier les fichiers secrets.

---

## 4. Lancer le projet

Depuis la racine du projet :

```bash
make
```

ou :

```bash
make up
```

Le Makefile :

1. crée les dossiers persistants ;
2. définit `DATA_PATH` ;
3. construit les images ;
4. démarre les trois conteneurs en arrière-plan.

Les données sont stockées dans :

```text
/home/<utilisateur>/data/db_data
/home/<utilisateur>/data/wp_data
```

---

## 5. Accéder au site

Une fois les conteneurs démarrés, le site est accessible en HTTPS :

```text
https://shapetit.42.fr
```

Le port utilisé est :

```text
443
```

Le certificat TLS est auto-signé et généré lors de la construction de l'image NGINX. Un avertissement du navigateur peut donc apparaître. Dans le cadre d'un environnement local de projet, il faut accepter l'exception de sécurité pour accéder au site.

---

## 6. Utilisateurs WordPress

L'installation automatique crée :

### Administrateur WordPress

Les identifiants sont ceux définis dans :

```text
secrets/credentials.txt
```

avec :

```env
WP_ADMIN_USER=...
WP_ADMIN_PASSWORD=...
```

### Utilisateur auteur

Il est également créé automatiquement :

```env
WP_USER=...
WP_USER_PASSWORD=...
```

Son rôle WordPress est :

```text
author
```

---

## 7. Commandes principales

### Démarrer

```bash
make
```

ou :

```bash
make up
```

### Arrêter les conteneurs

```bash
make stop
```

Cette commande arrête les conteneurs sans les supprimer.

### Supprimer les conteneurs et le réseau

```bash
make down
```

Les données persistantes ne sont pas supprimées par cette commande.

### Supprimer les conteneurs et les images

```bash
make clean
```

### Réinitialiser complètement les données

```bash
make fclean
```

Cette commande supprime également :

```text
/home/<utilisateur>/data/db_data
/home/<utilisateur>/data/wp_data
```

Les données MariaDB et les fichiers WordPress persistants sont donc perdus.

### Reconstruire depuis zéro

```bash
make re
```

Équivalent à :

```text
fclean
+
all
```

---

## 8. Vérifier l'état des conteneurs

Pour voir les conteneurs en cours d'exécution :

```bash
docker ps
```

Les trois services attendus sont :

```text
nginx
wordpress
mariadb
```

Pour voir les logs :

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Pour entrer dans un conteneur :

```bash
docker exec -it nginx bash
docker exec -it wordpress bash
docker exec -it mariadb bash
```

---

## 9. Persistance des données

Deux volumes sont utilisés :

```text
db_data
    -> /var/lib/mysql

wp_data
    -> /var/www/wordpress
```

Ils sont liés aux dossiers de la machine :

```text
/home/<utilisateur>/data/db_data
/home/<utilisateur>/data/wp_data
```

Ainsi, supprimer les conteneurs avec :

```bash
make down
```

ne supprime pas automatiquement les données.

Lors d'un nouveau démarrage, les volumes sont remontés et les données sont récupérées.

---

## 10. Dépannage

### Le site ne répond pas

Vérifier :

```bash
docker ps
```

Puis les logs :

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Vérifier également que le port 443 est disponible :

```bash
ss -lntp | grep 443
```

### WordPress attend MariaDB

Le conteneur WordPress attend que MariaDB soit réellement disponible avant de continuer son initialisation. Le script utilise `mysqladmin ping`.

Vérifier les logs :

```bash
docker logs wordpress
docker logs mariadb
```

### Le site demande à nouveau une installation

Vérifier que le volume WordPress existe toujours :

```bash
ls -la /home/<utilisateur>/data/wp_data
```

et que `wp-config.php` est présent dans :

```text
/var/www/wordpress
```

### Les données ont disparu

Vérifier si `make fclean` ou une suppression des volumes/dossiers persistants a été effectuée.

---

## 11. Résumé

Pour une utilisation normale :

```bash
make
```

Puis ouvrir :

```text
https://shapetit.42.fr
```

Pour arrêter temporairement :

```bash
make stop
```

Pour supprimer les conteneurs tout en conservant les données :

```bash
make down
```

Pour repartir complètement de zéro :

```bash
make re
```

Attention : `make re` entraîne la suppression des données persistantes.
