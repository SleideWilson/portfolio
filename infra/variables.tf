variable "account_id" {
  type        = string
  description = "ID du compte cloudflare"
}

variable "zone_id" {
  type        = string
  description = "ID de la zone cloudflare"
}

variable "domain" {
  type        = string
  description = "Domaine principal"
  default     = "rcloudh.com"
}

variable "project_name" {
  type        = string
  description = "Nom du projet Cloudflare Pages"
  default     = "rcloudh-portfolio"
}