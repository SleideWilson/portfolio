terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  # Ld token est lu depuis la variable d'environnement CLOUDFLARE_API_TOKEN par le provider
  # on pourrait aussi le passer en dur ici mais c'est moins sûr (api_token = "<API_TOKEN>")
}