---
date: '2026-10-19T21:34:38+02:00'
draft: false
title: 'Déploiement de ce site : Hugo, Terraform, Cloudflare Pages et GitHub Actions'
tags: ["terraform", "cloudflare", "ci-cd", "github-actions", "iac"]
summary: "Site statique dont l'infrastructure est décrite en Terraform et qui se déploie automatiquement à chaque push."
---

## Objectif

J'ai réalisé ce projet pour automatiser le déploiement de mon portfolio et gérer son infrastructure de manière reproductible. Aucune ressource n'est créée à la main dans le dashboard Cloudflare : l'hébergement et le DNS sont décrits en Terraform, et chaque modification du contenu poussée sur `main` est construite et publiée par GitHub Actions, sans intervention manuelle.

## Architecture

![Flux de déploiement](images/portfolio_rcloudh_flux.svg)

Le projet repose sur deux flux distincts :

- **Provisioning (ponctuel)** : Terraform, lancé depuis mon poste, crée via l'API Cloudflare le projet Pages, les domaines personnalisés et les enregistrements DNS. Il gère le *contenant*.
- **Déploiement (à chaque push)** : GitHub Actions récupère le code, génère le site avec Hugo et envoie le résultat à Cloudflare Pages. Il gère le *contenu*.

Les deux ne se chevauchent pas : Terraform ne touche jamais au contenu du site, et la CI n'a aucun droit sur le DNS.

Le dépôt est organisé en conséquence :

```text
portfolio/
├── site/                    # Hugo (contenu, configuration, thème en submodule)
├── infra/                   # Terraform (Pages, domaines, DNS)
└── .github/workflows/       # Pipeline de déploiement
```

## Choix techniques

### Pourquoi un site statique avec Hugo ?

Un portfolio présente du contenu qui évolue peu et ne nécessite ni comptes utilisateurs ni base de données. Hugo génère du HTML à partir de fichiers Markdown : il n'y a aucun serveur applicatif à maintenir ni à sécuriser. Le site est du code versionné dans Git, ce qui permet de le reconstruire à l'identique et d'automatiser sa publication.

### Pourquoi Cloudflare Pages ?

- **Le domaine est déjà géré par Cloudflare** : DNS et hébergement au même endroit, pilotables par le même provider Terraform.
- **Distribution via le CDN de Cloudflare** : les fichiers sont servis depuis le point de présence le plus proche du visiteur, avec HTTPS automatique.
- **Déploiements immuables** : chaque déploiement est conservé avec sa propre URL, ce qui rend un retour arrière immédiat.
- **Previews par branche** : une branche autre que `main` produit un déploiement de prévisualisation sans toucher à la production.

### Pourquoi le direct upload depuis GitHub Actions ?

Cloudflare Pages peut se connecter directement à GitHub et construire le site lui-même. J'ai préféré créer le projet sans intégration Git et confier le build à GitHub Actions : le workflow maîtrise explicitement la récupération du thème, la version de Hugo et le moment de la publication. Le pipeline est versionné dans le dépôt, lisible et modifiable, plutôt que configuré dans une interface tierce.

## Infrastructure as Code

Terraform crée cinq ressources : le projet Pages, deux domaines personnalisés (`rcloudh.com` et `www.rcloudh.com`) et les deux enregistrements DNS correspondants.

Extrait de `infra/main.tf` (les ressources `www` sont identiques, avec le préfixe `www.`) :

```hcl
resource "cloudflare_pages_project" "portfolio" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = "main"
}

resource "cloudflare_pages_domain" "apex" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.portfolio.name
  name         = var.domain
}

resource "cloudflare_dns_record" "apex" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "CNAME"
  content = cloudflare_pages_project.portfolio.subdomain
  proxied = true
  ttl     = 1
}
```

### DNS et domaine personnalisé : pourquoi les deux ?

Ces deux ressources répondent à deux besoins différents :

- **L'enregistrement DNS** dirige le visiteur vers Cloudflare. Le CNAME fait de `rcloudh.com` un alias de l'adresse `.pages.dev` du projet. Un CNAME sur le domaine racine n'est normalement pas autorisé en DNS ; Cloudflare le permet grâce au *CNAME flattening*. L'enregistrement est proxifié, donc le DNS renvoie directement les adresses de Cloudflare.
- **Le domaine personnalisé Pages** indique à Cloudflare quel projet servir lorsqu'une requête arrive avec l'en-tête `Host: rcloudh.com`. Les mêmes serveurs hébergent des milliers de sites ; c'est ce rattachement qui permet de router la requête vers le bon projet. Il déclenche aussi l'émission du certificat TLS.

Sans DNS, personne n'arrive jusqu'au site. Sans domaine personnalisé, la requête arrive chez Cloudflare mais aucun projet ne revendique ce nom.

### Dépendances implicites

Le domaine personnalisé et le CNAME référencent des attributs du projet Pages (`name`, `subdomain`). Terraform en déduit l'ordre de création : le projet d'abord, puis les quatre autres ressources en parallèle, sans `depends_on` explicite. Le `subdomain` n'étant connu qu'après la création du projet, il apparaît comme `(known after apply)` dans le plan.

Le provider est épinglé (`version = "~> 5.0"`) et le fichier `.terraform.lock.hcl` est versionné, afin que chaque exécution utilise exactement la même version du provider.

## Pipeline CI/CD

Workflow complet (`.github/workflows/deploy.yml`) :

```yaml
name: Deploy site

on:
  push:
    branches: [main]
    paths:
      - "site/**"
      - ".github/workflows/deploy.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Récupérer le code (avec le thème)
        uses: actions/checkout@v4
        with:
          submodules: true

      - name: Installer Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: "0.168.0"
          extended: true

      - name: Construire le site
        working-directory: site
        run: hugo --minify

      - name: Déployer sur Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy site/public --project-name=rcloudh-portfolio --branch=main
```

Points notables :

- **Déclenchement ciblé** : le filtre `paths` ne lance le workflow que si le site ou le workflow lui-même changent. Une modification de l'infrastructure ne redéploie pas le site. `workflow_dispatch` permet un lancement manuel.
- **Moindre privilège** : `permissions: contents: read` restreint le token interne de GitHub à la lecture du dépôt.
- **Pas de déploiements concurrents** : `concurrency` annule un déploiement en cours si un nouveau push arrive, pour que le dernier commit soit toujours celui publié.
- **Thème en submodule** : le thème Hugo est référencé comme submodule Git. Sans `submodules: true`, son dossier serait vide et le build échouerait.
- **Version de Hugo épinglée** : la même qu'en local. Le rendu en ligne correspond exactement à ce que je vérifie sur mon poste, et une mise à jour de Hugo ne peut pas casser le site à mon insu.
- **Publication en production** : `--branch=main` correspond à la `production_branch` déclarée dans Terraform ; le déploiement est donc servi directement sur le domaine.

## Sécurité

- **Deux tokens Cloudflare distincts, au périmètre minimal** :
  - le token Terraform peut gérer Pages et le DNS, uniquement sur la zone `rcloudh.com` ;
  - le token de la CI ne peut que déployer sur Pages. S'il fuitait, il ne permettrait pas de rediriger le domaine.
- **Aucun secret dans le code** : le token Terraform est chargé en variable d'environnement au moment de l'exécution (`read -s`), sans jamais être écrit dans un fichier ni dans l'historique du shell. Le token de déploiement est stocké dans les secrets GitHub, chiffré et masqué dans les logs.
- **Fichiers sensibles exclus du dépôt** : `terraform.tfvars`, le state Terraform et les plans enregistrés sont listés dans `.gitignore`.
- **Plan relu avant application** : les changements d'infrastructure passent par `terraform plan -out` puis `terraform apply` sur ce plan enregistré, pour appliquer exactement ce qui a été vérifié.

## Limites et améliorations prévues

- **State Terraform local** : il est sauvegardé manuellement. Un backend distant le centraliserait, le protégerait et permettrait le verrouillage en cas d'exécutions concurrentes.
- **Infrastructure appliquée depuis mon poste** : un `terraform plan` automatique en CI sur chaque pull request touchant `infra/` permettrait de relire les changements avant de les appliquer.
- **Deux URL pour un même site** : `rcloudh.com` et `www.rcloudh.com` servent le même contenu. Une redirection de `www` vers le domaine apex garantirait une URL canonique unique.
- **Actions tierces référencées par version majeure** : les épingler par hash de commit renforcerait la protection contre une modification malveillante d'une action.

## Code source

Le code complet est disponible sur [GitHub](https://github.com/SleideWilson/portfolio).