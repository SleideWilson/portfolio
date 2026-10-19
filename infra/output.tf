output "pages_url" {
  description = "Adresse .pages.dev du projet"
  value       = "https://${cloudflare_pages_project.portfolio.subdomain}"
}

output "site_url" {
  value = "https://${var.domain}"
}