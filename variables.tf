###############################################################################
# terraform-aisia-swarm — variables d'entrée
# Déploie la stack AISIA sur un Docker Swarm EXISTANT (cloud-agnostique).
# Parité Swarm de terraform-aisia-cluster (K8s).
###############################################################################

# --------------------------------------------------------------------------- #
# Connexion Swarm                                                              #
# --------------------------------------------------------------------------- #

variable "docker_host" {
  description = <<-EOT
    URL du Swarm manager à utiliser lors de la configuration du provider 'docker'
    dans le module racine appelant (ex. "ssh://user@swarm-manager.example.com" ou
    "tcp://manager:2376"). Non utilisé directement dans les ressources du module :
    configurer le provider kreuzwerker/docker avec cette valeur en amont.
  EOT
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "stack_name" {
  description = "Nom du stack Docker Swarm — préfixe des services (aisia_api, aisia_bot…). Doit correspondre au nom passé à 'docker stack deploy'."
  type        = string
  default     = "aisia"
}

# --------------------------------------------------------------------------- #
# Image                                                                        #
# --------------------------------------------------------------------------- #

variable "image_registry" {
  description = "Registry des images AISIA (ex. registry.aisia.fr ou ghcr.io/aisia)."
  type        = string
  default     = "registry.aisia.fr"
}

variable "image_tag" {
  description = "Tag d'image AISIA à déployer (ex. v6.9.61). Doit être un manifest multi-arch (arm64 + amd64)."
  type        = string
  default     = "v6.9.75"
}

variable "image_frontend_name" {
  description = "Nom de l'image frontend (sans registry ni tag). Ex. 'aisia-frontend' → registry/aisia-frontend:tag."
  type        = string
  default     = "aisia-frontend"
}

# --------------------------------------------------------------------------- #
# Exposition publique                                                          #
# --------------------------------------------------------------------------- #

variable "domain" {
  description = "Domaine public de l'instance (ex. client.aisia.fr). Vide = pas de labels Traefik auto-générés."
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "Sous-domaine de l'API REST AISIA. Vide = 'api.<domain>' si domain est fourni, sinon désactivé."
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------- #
# Tier & scaling                                                               #
# --------------------------------------------------------------------------- #

variable "tier" {
  description = "Tier d'exploitation : free | saas | baas | paas. Pilote les réplicas par défaut du bot et du frontend."
  type        = string
  default     = "saas"
  validation {
    condition     = contains(["free", "saas", "baas", "paas"], var.tier)
    error_message = "tier doit être l'un de : free, saas, baas, paas."
  }
}

variable "bot_replicas" {
  description = "Replicas du service bot. null = dérivé du tier (free/saas→1, baas/paas→2)."
  type        = number
  default     = null
}

variable "frontend_replicas" {
  description = "Replicas du service frontend. null = dérivé du tier (free→1, saas→2, baas→2, paas→4)."
  type        = number
  default     = null
}

# --------------------------------------------------------------------------- #
# Contraintes de placement                                                     #
# --------------------------------------------------------------------------- #

variable "placement_api" {
  description = "Contraintes de placement Swarm pour l'API (mode global). Ex. ['node.labels.aisia-role == api']."
  type        = list(string)
  default     = ["node.role == worker"]
}

variable "placement_agent" {
  description = "Contraintes de placement pour l'agent (mode global)."
  type        = list(string)
  default     = ["node.role == worker"]
}

variable "placement_bot" {
  description = "Contraintes de placement pour le bot (mode replicated)."
  type        = list(string)
  default     = ["node.role == worker"]
}

variable "placement_frontend" {
  description = "Contraintes de placement pour le frontend (mode replicated). Ex. ['node.labels.aisia-role == frontend']."
  type        = list(string)
  default     = ["node.role == worker"]
}

variable "gpu_enabled" {
  description = "Ajoute la contrainte 'node.labels.gpu == true' sur le service agent (nœuds équipés d'un GPU)."
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------- #
# Réseau overlay                                                               #
# --------------------------------------------------------------------------- #

variable "network_driver" {
  description = "Driver réseau Docker (overlay recommandé pour Swarm multi-nœuds)."
  type        = string
  default     = "overlay"
}

# --------------------------------------------------------------------------- #
# Rolling update                                                               #
# --------------------------------------------------------------------------- #

variable "update_parallelism" {
  description = "Tâches mises à jour en parallèle. Règle AISIA : toujours 1 (jamais >= 2 --force ; un parallélisme élevé peut cascader en I/O)."
  type        = number
  default     = 1
}

variable "update_delay" {
  description = "Délai entre chaque lot de rolling update (ex. '60s', '2m')."
  type        = string
  default     = "60s"
}

# --------------------------------------------------------------------------- #
# Environnement applicatif                                                     #
# --------------------------------------------------------------------------- #

variable "extra_env" {
  description = "Variables d'environnement supplémentaires injectées dans tous les services backend AISIA."
  type        = map(string)
  default     = {}
}

# --------------------------------------------------------------------------- #
# Locals : dérivation des valeurs effectives                                   #
# --------------------------------------------------------------------------- #

locals {
  # Scaling par tier.
  tier_scaling = {
    free = { bot = 1, frontend = 1 }
    saas = { bot = 1, frontend = 2 }
    baas = { bot = 2, frontend = 2 }
    paas = { bot = 2, frontend = 4 }
  }

  effective_bot_replicas      = coalesce(var.bot_replicas, local.tier_scaling[var.tier].bot)
  effective_frontend_replicas = coalesce(var.frontend_replicas, local.tier_scaling[var.tier].frontend)

  # Exposition Traefik.
  traefik_enabled = var.domain != ""
  effective_api_domain = (
    var.api_domain != "" ? var.api_domain :
    (var.domain != "" ? "api.${var.domain}" : "")
  )

  # Variables d'environnement communes (liste ["KEY=VALUE"]).
  base_env = merge(
    { AISIA_TIER = var.tier },
    var.extra_env
  )
  base_env_list = [for k, v in local.base_env : "${k}=${v}"]

  # Labels Traefik pour l'API.
  traefik_api_labels = local.traefik_enabled && local.effective_api_domain != "" ? {
    "traefik.enable"                                                       = "true"
    "traefik.http.routers.${var.stack_name}-api.rule"                      = "Host(`${local.effective_api_domain}`)"
    "traefik.http.routers.${var.stack_name}-api.entrypoints"               = "websecure"
    "traefik.http.routers.${var.stack_name}-api.tls.certresolver"          = "letsencrypt"
    "traefik.http.services.${var.stack_name}-api.loadbalancer.server.port" = "8000"
  } : {}

  # Labels Traefik pour le frontend.
  traefik_frontend_labels = local.traefik_enabled ? {
    "traefik.enable"                                                            = "true"
    "traefik.http.routers.${var.stack_name}-frontend.rule"                      = "Host(`${var.domain}`)"
    "traefik.http.routers.${var.stack_name}-frontend.entrypoints"               = "websecure"
    "traefik.http.routers.${var.stack_name}-frontend.tls.certresolver"          = "letsencrypt"
    "traefik.http.services.${var.stack_name}-frontend.loadbalancer.server.port" = "3000"
  } : {}

  # Contraintes agent + GPU éventuel.
  agent_constraints = var.gpu_enabled ? concat(var.placement_agent, ["node.labels.gpu == true"]) : var.placement_agent
}
