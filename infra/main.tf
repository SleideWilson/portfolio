# HCL Hashicorp Configuration Language
# TYPE "LABEL" {
#   attribute = value
# }

# Projet Pages sans lien git
# Le déploiement se fera avec GitHub Actions

resource "cloudflare_pages_project" "portfolio" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = "main"
}

# Domaines personnalisés rattachés au projet
resource "cloudflare_pages_domain" "apex" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.portfolio.name
  name         = var.domain
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.portfolio.name
  name         = "www.${var.domain}"
}

# DNS: rcloudh.com et www pointent vers le projet Pages
resource "cloudflare_dns_record" "apex" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "CNAME"
  content = cloudflare_pages_project.portfolio.subdomain
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "www" {
  zone_id = var.zone_id
  name    = "www.${var.domain}"
  type    = "CNAME"
  content = cloudflare_pages_project.portfolio.subdomain
  proxied = true
  ttl     = 1
}
    