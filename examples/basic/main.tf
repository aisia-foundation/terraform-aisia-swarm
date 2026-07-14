###############################################################################
# Exemple basique — déployer AISIA sur un Docker Swarm existant.
#
# Prérequis :
#   - Docker Swarm initialisé (docker swarm init sur le manager).
#   - Traefik déployé sur le même réseau overlay "aisia_net" si domain est fourni.
#   - Clé SSH ou accès TCP au Swarm manager.
#
# Usage :
#   terraform init
#   terraform plan
#   # terraform apply  ← exécuté par l'opérateur (nécessite accès Swarm réel)
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.2"
    }
  }
}

# Configurer le provider kreuzwerker/docker avec l'adresse du Swarm manager.
# SSH est recommandé (pas d'exposition TCP non-TLS).
provider "docker" {
  host = "ssh://deploy@swarm-manager.example.com"
}

module "aisia" {
  source = "../../"

  # Image
  image_tag      = "v6.12.30"
  image_registry = "registry.aisia.fr"

  # Stack
  stack_name = "aisia"
  tier       = "saas" # free | saas | baas | paas

  # Exposition publique via Traefik (laisser vide si pas de Traefik).
  domain     = "client.aisia.fr"
  api_domain = "api.client.aisia.fr"

  # Placement — adapter aux labels de vos nœuds Swarm.
  placement_api      = ["node.role == worker", "node.labels.aisia-role == api"]
  placement_agent    = ["node.role == worker", "node.labels.aisia-role == api"]
  placement_bot      = ["node.role == worker"]
  placement_frontend = ["node.role == worker", "node.labels.aisia-role == frontend"]

  # Rolling update sécurisé (jamais parallelism >= 2 --force ; risque de cascade I/O).
  update_parallelism = 1
  update_delay       = "60s"

  # Variables d'environnement supplémentaires.
  extra_env = {
    LOG_LEVEL               = "INFO"
    DATASET_MAX_PER_STARTUP = "0"
  }
}

output "aisia_stack_name" {
  description = "Nom du stack déployé."
  value       = module.aisia.stack_name
}

output "aisia_public_url" {
  description = "URL publique du frontend."
  value       = module.aisia.public_url
}

output "aisia_api_url" {
  description = "URL publique de l'API REST."
  value       = module.aisia.api_url
}

output "aisia_deploy_id" {
  description = "ID de déploiement Terraform (traçabilité)."
  value       = module.aisia.deploy_id
}
