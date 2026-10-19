# rcloudh.com

Portfolio personnel, servi sur [rcloudh.com](https://rcloudh.com).

Site statique généré avec **Hugo**, hébergé sur **Cloudflare Pages**. L'infrastructure (projet Pages, domaines, DNS) est décrite en **Terraform** et le site est déployé automatiquement par **GitHub Actions** à chaque push sur `main`.

Explication détaillée des choix techniques : [Déploiement de ce site](https://rcloudh.com/projets/portfolio-iac/)

## Architecture

```text
Provisioning (ponctuel)   Terraform ──► API Cloudflare ──► projet Pages + domaines + DNS
Déploiement (à chaque push)   git push ──► GitHub Actions ──► hugo build ──► Cloudflare Pages
```

## Structure

```text
.
├── site/                  # Hugo : contenu, configuration, thème PaperMod (submodule)
├── infra/                 # Terraform : projet Pages, domaines personnalisés, DNS
└── .github/workflows/     # Pipeline de build et de déploiement
```

## Prérequis

- [Hugo](https://gohugo.io/) extended 0.168.0
- [Terraform](https://developer.hashicorp.com/terraform) >= 1.6
- Un compte Cloudflare avec la zone du domaine

## Développement local

```bash
git clone --recurse-submodules https://github.com/SleideWilson/portfolio.git
cd portfolio/site
hugo server
```

Le site est disponible sur http://localhost:1313.

## Infrastructure

Le token API Cloudflare est lu depuis une variable d'environnement, jamais depuis un fichier :

```bash
read -s CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN
```

Créer `infra/terraform.tfvars` (exclu du dépôt) :

```hcl
account_id = "<account_id>"
zone_id    = "<zone_id>"
```

Puis :

```bash
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Permissions du token : `Account / Cloudflare Pages / Edit`, `Zone / DNS / Edit`, `Zone / Zone / Read`, limitées à la zone concernée.

## Déploiement

Automatique à chaque push sur `main` modifiant `site/` ou le workflow. Lancement manuel possible depuis l'onglet **Actions** (`workflow_dispatch`).

Secrets GitHub requis :

| Secret | Contenu |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Token limité à `Account / Cloudflare Pages / Edit` |
| `CLOUDFLARE_ACCOUNT_ID` | Identifiant du compte Cloudflare |

## Améliorations prévues

- [ ] Backend distant pour le state Terraform
- [ ] `terraform plan` automatique sur les pull requests touchant `infra/`
- [ ] Redirection `www` → domaine apex
- [ ] Actions GitHub épinglées par hash de commit