# DEV_DOC.md

# Inception — Documentation développeur

## 1. Architecture

Le projet est une infrastructure Docker composée de trois services :

```text
                         Client
                           |
                           | HTTPS :443
                           v
                    +--------------+
                    |    NGINX     |
                    |   SSL/TLS    |
                    +------+-------+
                           |
                           | FastCGI :9000
                           v
                    +--------------+
                    |  WORDPRESS   |
                    |   PHP-FPM    |
                    +------+-------+
                           |
                           | MySQL :3306
                           v
                    +--------------+
                    |   MARIADB    |
                    +--------------+
                           |
                           v
                       db_data
```

Les trois services appartiennent au réseau Docker :

```text
inception
```

Le seul port publié vers l'hôte est :

```text
443:443
```

pour NGINX.

---

## 2. Arborescence

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
│   ├── db_password.txt.example
│   ├── db_root_password.txt.example
│   └── credentials.txt.example
└── srcs/
    ├── docker-compose.yml
    ├── .env.example
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── tools/
        │       ├── install.sh
        │       └── init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── www.conf
        │   └── tools/
        │       ├── install.sh
        │       └── init.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/
            │   └── nginx.conf
            └── tools/
                └── install.sh
```

---

## 3. Makefile

Le Makefile centralise les opérations courantes.

### Variables

```makefile
LOGIN = $(or $(SUDO_USER),$(USER))
DATA_PATH = /home/$(LOGIN)/data
COMPOSE = docker-compose -f srcs/docker-compose.yml
```

`DATA_PATH` définit l'emplacement des données persistantes sur la machine hôte.

### Cibles

```text
all
 -> up

up
 -> création des dossiers db_data et wp_data
 -> docker-compose up --build -d

stop
 -> arrêt des conteneurs

down
 -> suppression des conteneurs et du réseau Compose

clean
 -> down + suppression des images

fclean
 -> clean + suppression des données persistantes

re
 -> fclean + all
```

`fclean` est destructif pour les données :

```text
/home/<utilisateur>/data/db_data
/home/<utilisateur>/data/wp_data
```

---

## 4. Docker Compose

Le fichier `srcs/docker-compose.yml` orchestre l'infrastructure.

Il définit :

- secrets ;
- volumes ;
- réseau ;
- services ;
- dépendances ;
- ports ;
- politique de redémarrage.

### 4.1 Secrets

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  credentials:
    file: ../secrets/credentials.txt
```

Les secrets sont ensuite disponibles dans les conteneurs sous :

```text
/run/secrets/
```

Ils évitent de mettre directement les mots de passe dans `docker-compose.yml`.

---

## 5. Volumes

Deux volumes bindés sont déclarés.

### `db_data`

```yaml
device: ${DATA_PATH}/db_data
```

Monté dans MariaDB :

```text
/var/lib/mysql
```

Il conserve les données de la base.

### `wp_data`

```yaml
device: ${DATA_PATH}/wp_data
```

Monté dans :

```text
WordPress : /var/www/wordpress
NGINX     : /var/www/wordpress
```

Le partage permet à NGINX de servir les fichiers WordPress présents dans le même volume que celui utilisé par le conteneur WordPress.

---

## 6. Réseau

Le réseau est :

```yaml
networks:
  inception:
    driver: bridge
```

Les trois conteneurs sont connectés à ce réseau.

Docker fournit une résolution DNS interne basée sur les noms de services. WordPress peut donc joindre MariaDB avec :

```text
mariadb
```

et NGINX peut joindre PHP-FPM avec :

```text
wordpress:9000
```

Aucune adresse IP statique n'est nécessaire.

---

# 7. Service MariaDB

## Dockerfile

```dockerfile
FROM debian:bullseye-slim
```

L'image part d'une Debian Bullseye Slim.

Le Dockerfile :

1. copie `tools/install.sh` ;
2. installe MariaDB ;
3. copie `tools/init.sh` ;
4. rend le script exécutable ;
5. utilise `init.sh` comme `ENTRYPOINT`.

```text
Dockerfile
   |
   +--> install.sh
   |
   +--> init.sh
```

`EXPOSE 3306` documente le port utilisé par MariaDB dans le conteneur. Le port n'est pas publié dans Compose.

---

## install.sh

Le script :

```bash
apt-get update
apt-get install -y mariadb-server
rm -rf /var/lib/mysql/*
```

installe le serveur MariaDB et prépare le répertoire de données pour son initialisation.

---

## init.sh

Le script initialise MariaDB au premier démarrage.

### Préparation

```bash
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
```

### Écoute réseau

La configuration MariaDB est modifiée pour utiliser :

```text
bind-address = 0.0.0.0
```

Cela permet aux autres conteneurs du réseau Docker de se connecter.

### Lecture des secrets

```bash
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
```

Le mot de passe administrateur WordPress est récupéré depuis `credentials`.

### Initialisation conditionnelle

Le script vérifie :

```text
/var/lib/mysql/mysql
```

Si ce répertoire n'existe pas, la base est initialisée.

### Création de la base et des utilisateurs

Le script crée :

```text
wordpress
```

ainsi que l'utilisateur :

```text
MYSQL_USER
```

avec ses droits sur :

```text
wordpress.*
```

Il crée également :

```text
MYSQL_ADMIN_USER
```

avec des droits sur la base WordPress.

Les comptes anonymes sont supprimés et le mot de passe du root local est configuré.

### Arrêt puis lancement final

Après l'initialisation, le serveur MariaDB temporaire est arrêté :

```bash
mysqladmin shutdown
```

Puis MariaDB devient le processus principal :

```bash
exec mysqld --user=mysql
```

Le `exec` remplace le shell par le processus MariaDB.

---

# 8. Service WordPress

## Dockerfile

Le conteneur part de :

```dockerfile
FROM debian:bullseye-slim
```

Le Dockerfile :

1. installe PHP-FPM et les extensions nécessaires ;
2. installe le client MariaDB ;
3. installe curl et Netcat ;
4. télécharge WP-CLI ;
5. télécharge WordPress ;
6. copie la configuration PHP-FPM ;
7. copie le script d'initialisation ;
8. expose le port interne 9000 ;
9. utilise `init.sh` comme `ENTRYPOINT`.

---

## install.sh

Les principaux paquets installés sont :

```text
php-fpm
php-mysql
php-curl
php-gd
php-xml
php-mbstring
curl
netcat-openbsd
mariadb-client
```

Le client MariaDB est nécessaire pour tester la disponibilité de MariaDB depuis WordPress.

WP-CLI est téléchargé et installé dans :

```text
/usr/local/bin/wp
```

---

## Installation de WordPress

WordPress est téléchargé dans :

```text
/usr/src/wordpress
```

Au premier démarrage, les fichiers sont copiés vers :

```text
/var/www/wordpress
```

qui correspond au volume `wp_data`.

---

## Attente de MariaDB

Avant de configurer WordPress, le script exécute une boucle :

```bash
mysqladmin ping -h mariadb ...
```

Cette vérification est nécessaire car :

```text
depends_on
```

garantit l'ordre de démarrage des services, mais pas que MariaDB soit déjà prête à accepter des connexions.

Le script attend donc que MariaDB réponde réellement.

---

## Configuration WordPress

WP-CLI crée `wp-config.php` avec :

```text
database = MYSQL_DATABASE
user     = MYSQL_USER
password = db_password
host     = mariadb
```

Le hostname :

```text
mariadb
```

est résolu par le DNS Docker interne.

---

## Installation du site

Le script utilise :

```bash
wp core install
```

avec :

```text
DOMAIN_NAME
WP_ADMIN_USER
WP_ADMIN_PASSWORD
```

Le titre du site est :

```text
Inception
```

L'adresse e-mail est générée à partir du domaine.

Un deuxième utilisateur WordPress est ensuite créé avec le rôle :

```text
author
```

L'installation est conditionnelle : elle n'est effectuée que si le fichier :

```text
/var/www/wordpress/wp-config-sample.php
```

n'est pas déjà présent.

Cela évite de réinitialiser WordPress à chaque démarrage lorsque le volume existe déjà.

---

# 9. PHP-FPM

La configuration :

```text
srcs/requirements/wordpress/conf/www.conf
```

définit le pool PHP-FPM `www`.

Le point principal est :

```text
listen = 0.0.0.0:9000
```

PHP-FPM écoute donc sur le port interne 9000.

Le mode de gestion des processus est :

```text
pm = dynamic
```

avec :

```text
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

Le processus final est lancé au premier plan :

```bash
exec php-fpm7.4 -F
```

Cela permet à PHP-FPM de rester le processus principal du conteneur.

---

# 10. Service NGINX

## Dockerfile

Le conteneur NGINX part de :

```dockerfile
FROM debian:bullseye-slim
```

Le script d'installation installe :

```text
nginx
openssl
```

Un certificat auto-signé est ensuite généré avec OpenSSL :

```text
/etc/nginx/ssl/wordpress.key
/etc/nginx/ssl/wordpress.crt
```

Le certificat utilise :

```text
CN=shapetit.42.fr
```

Le fichier de configuration NGINX est copié dans :

```text
/etc/nginx/sites-available/default
```

NGINX expose le port interne :

```text
443
```

et le Compose publie :

```text
443:443
```

---

# 11. Configuration NGINX

NGINX écoute avec :

```nginx
listen 443 ssl;
```

et utilise :

```text
TLS 1.2
TLS 1.3
```

Le serveur est associé à :

```text
shapetit.42.fr
```

La racine du site est :

```text
/var/www/wordpress
```

Ce répertoire provient du volume partagé `wp_data`.

---

## 11.1 Routage des requêtes

```nginx
location / {
    try_files $uri $uri/ /index.php?$args;
}
```

NGINX cherche d'abord le fichier ou répertoire demandé.

Si rien n'est trouvé, la requête est redirigée logiquement vers :

```text
index.php
```

Ce comportement permet à WordPress de gérer ses routes.

---

## 11.2 PHP et FastCGI

Pour les fichiers PHP :

```nginx
location ~ \\.php$ {
    fastcgi_pass wordpress:9000;
    ...
}
```

NGINX transmet la requête à :

```text
wordpress:9000
```

qui correspond à PHP-FPM dans le conteneur WordPress.

Le chemin du script est transmis avec :

```nginx
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
```

---

# 12. Parcours complet d'une requête

Lorsqu'un utilisateur demande :

```text
https://shapetit.42.fr
```

le parcours est :

```text
1. Navigateur
       |
       | HTTPS :443
       v
2. NGINX
       |
       | FastCGI :9000
       v
3. PHP-FPM
       |
       | exécution de WordPress
       v
4. WordPress
       |
       | requête SQL
       v
5. MariaDB
       |
       | données
       v
4. WordPress
       |
       v
3. PHP-FPM
       |
       v
2. NGINX
       |
       | HTTPS
       v
1. Navigateur
```

NGINX ne communique donc pas directement avec MariaDB. WordPress est l'application qui interagit avec la base de données.

---

# 13. Pourquoi les ports ne sont pas tous publiés ?

Compose publie uniquement :

```yaml
ports:
  - "443:443"
```

pour NGINX.

MariaDB et PHP-FPM sont accessibles sur le réseau Docker mais leurs ports ne sont pas publiés sur l'hôte.

Cela donne :

```text
Internet
   |
   v
NGINX :443
   |
   +----> WordPress/PHP-FPM :9000
   |
   +----> MariaDB :3306 via WordPress
```

PHP-FPM et MariaDB ne sont donc pas directement exposés à Internet.

---

# 14. Persistance

Les données importantes sont séparées du cycle de vie des conteneurs.

```text
MariaDB
  |
  v
/var/lib/mysql
  |
  v
db_data
  |
  v
/home/<user>/data/db_data
```

et :

```text
WordPress
  |
  v
/var/www/wordpress
  |
  v
wp_data
  |
  v
/home/<user>/data/wp_data
```

La suppression d'un conteneur ne supprime donc pas automatiquement ces données.

---

# 15. Sécurité

Le projet applique plusieurs mesures :

### HTTPS

NGINX utilise TLS sur le port 443.

### Réseau interne

MariaDB et PHP-FPM ne publient pas leurs ports vers l'extérieur.

### Utilisateur MariaDB dédié

WordPress utilise `MYSQL_USER` plutôt que le compte root de MariaDB.

### Secrets

Les mots de passe sont fournis par Docker secrets et accessibles dans :

```text
/run/secrets/
```

### Suppression des comptes anonymes

L'initialisation MariaDB supprime les comptes anonymes.

### Versions TLS

NGINX limite TLS à :

```text
1.2
1.3
```

---

# 16. Image, conteneur et Docker Compose

Ces trois notions doivent être distinguées.

### Dockerfile

Décrit comment construire une image.

```text
Dockerfile
    |
    | docker build
    v
  Image
```

### Image

Modèle contenant l'environnement nécessaire au service.

```text
Image
    |
    | docker run
    v
Container
```

### Conteneur

Instance en exécution de l'image.

### Docker Compose

Compose orchestre plusieurs services et configure leurs :

- réseaux ;
- volumes ;
- secrets ;
- ports ;
- dépendances ;
- images ;
- politiques de redémarrage.

---

# 17. Cycle de démarrage

L'ordre logique est :

```text
docker-compose up
        |
        v
    MariaDB
        |
        | MariaDB devient disponible
        v
    WordPress
        |
        | vérifie MariaDB avec mysqladmin ping
        |
        | initialise WordPress si nécessaire
        v
     PHP-FPM
        |
        v
      NGINX
```

Compose utilise :

```text
wordpress depends_on mariadb
nginx depends_on wordpress
```

mais les scripts vérifient eux-mêmes la disponibilité réelle des services lorsqu'une connexion est nécessaire.

---

# 18. Maintenance et diagnostic

### Lister les conteneurs

```bash
docker ps
```

### Voir tous les conteneurs

```bash
docker ps -a
```

### Voir les images

```bash
docker images
```

### Voir les réseaux

```bash
docker network ls
```

### Voir les volumes

```bash
docker volume ls
```

### Logs

```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

### Entrer dans un conteneur

```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash
```

### Vérifier le réseau

```bash
docker network inspect inception
```

---

# 19. Points importants pour modifier le projet

### Modifier NGINX

Modifier :

```text
srcs/requirements/nginx/conf/nginx.conf
```

Puis reconstruire :

```bash
make re
```

ou reconstruire les images avec Compose.

### Modifier PHP-FPM

Modifier :

```text
srcs/requirements/wordpress/conf/www.conf
```

### Modifier l'installation WordPress

Modifier :

```text
srcs/requirements/wordpress/tools/init.sh
```

### Modifier MariaDB

Modifier :

```text
srcs/requirements/mariadb/tools/init.sh
```

### Modifier l'orchestration

Modifier :

```text
srcs/docker-compose.yml
```

### Modifier les commandes de gestion

Modifier :

```text
Makefile
```

---

# 20. Résumé technique

Le projet repose sur la séparation suivante :

```text
NGINX
  = HTTPS + serveur web
          |
          v
PHP-FPM
  = exécution PHP
          |
          v
WordPress
  = application web
          |
          v
MariaDB
  = données
```

Les responsabilités sont séparées dans trois conteneurs.

```text
Images
  |
  +--> mariadb:inception
  +--> wordpress:inception
  +--> nginx:inception
```

Les conteneurs partagent :

```text
Network
  -> communication

Volumes
  -> persistance

Secrets
  -> données sensibles
```

Le seul accès extérieur est :

```text
HTTPS :443 -> NGINX
```

Cette architecture permet d'obtenir une infrastructure modulaire, isolée et persistante.
