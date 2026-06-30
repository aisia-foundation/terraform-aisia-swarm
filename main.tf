###############################################################################
# terraform-aisia-swarm — déploiement de la stack AISIA sur Docker Swarm
# existant. Cloud-agnostique (bare-metal ARM64, VM cloud, hybride).
#
# Architecture réelle AISIA :
#   aisia_api      → mode GLOBAL  (1 replica/nœud worker api)
#   aisia_agent    → mode GLOBAL  (1 replica/nœud worker, avec contrainte GPU si demandé)
#   aisia_bot      → mode REPLICATED (tier-aware, ≥1)
#   aisia_frontend → mode REPLICATED (tier-aware, ≥1)
#
# Prérequis :
#   - Docker Swarm initialisé (manager + workers déclarés).
#   - Provider kreuzwerker/docker configuré par le module racine appelant.
#   - Traefik déployé sur le même réseau overlay si domain est fourni.
###############################################################################

###############################################################################
# ID de déploiement — stable par (stack_name), rénové si le stack est
# détruit/recréé. Utilisé comme label de traçabilité.
###############################################################################
resource "random_id" "deploy_id" {
  byte_length = 6
  keepers = {
    stack_name = var.stack_name
  }
}

###############################################################################
# Réseau overlay partagé (API / bot / agent / frontend / Traefik).
###############################################################################
resource "docker_network" "aisia" {
  name   = "${var.stack_name}_net"
  driver = var.network_driver

  # attachable = true permet aux conteneurs standalone de rejoindre le réseau
  # (utile pour les outils d'administration et les tests locaux).
  attachable = true

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
  labels {
    label = "aisia.fr/deploy-id"
    value = random_id.deploy_id.hex
  }
  labels {
    label = "app.managed-by"
    value = "terraform"
  }
}

###############################################################################
# API AISIA — mode GLOBAL (un replica par nœud satisfaisant placement_api).
# Équivalent du Deployment K8s + HPA dans terraform-aisia-cluster.
# Sonde : GET /health (endpoint public, cf. feedback healthcheck_public_endpoint).
###############################################################################
resource "docker_service" "api" {
  name = "${var.stack_name}_api"

  task_spec {
    container_spec {
      image = "${var.image_registry}/aisia:${var.image_tag}"
      env   = concat(local.base_env_list, ["AISIA_COMPONENT=api"])

      healthcheck {
        test         = ["CMD", "wget", "--spider", "-q", "http://localhost:8000/health"]
        interval     = "30s"
        timeout      = "10s"
        retries      = 3
        start_period = "15s"
      }
    }

    networks_advanced {
      name = docker_network.aisia.id
    }

    placement {
      constraints = var.placement_api
    }

    restart_policy {
      condition    = "any"
      delay        = "5s"
      max_attempts = 5
      window       = "120s"
    }
  }

  mode {
    global = true
  }

  update_config {
    parallelism    = var.update_parallelism
    delay          = var.update_delay
    failure_action = "rollback"
    order          = "stop-first"
  }

  rollback_config {
    parallelism = 1
    delay       = "0s"
    order       = "stop-first"
  }

  # Labels Traefik (service-level, lus par Traefik Swarm provider).
  dynamic "labels" {
    for_each = local.traefik_api_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
  labels {
    label = "aisia.fr/component"
    value = "api"
  }
  labels {
    label = "aisia.fr/deploy-id"
    value = random_id.deploy_id.hex
  }
}

###############################################################################
# BOT AISIA — mode REPLICATED, tier-aware.
# Gère les interactions conversationnelles (app/bot/).
###############################################################################
resource "docker_service" "bot" {
  name = "${var.stack_name}_bot"

  task_spec {
    container_spec {
      image = "${var.image_registry}/aisia:${var.image_tag}"
      env   = concat(local.base_env_list, ["AISIA_COMPONENT=bot"])
    }

    networks_advanced {
      name = docker_network.aisia.id
    }

    placement {
      constraints = var.placement_bot
    }

    restart_policy {
      condition    = "any"
      delay        = "5s"
      max_attempts = 5
      window       = "120s"
    }
  }

  mode {
    replicated {
      replicas = local.effective_bot_replicas
    }
  }

  update_config {
    parallelism    = 1
    delay          = var.update_delay
    failure_action = "rollback"
    order          = "stop-first"
  }

  rollback_config {
    parallelism = 1
    delay       = "0s"
    order       = "stop-first"
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
  labels {
    label = "aisia.fr/component"
    value = "bot"
  }
  labels {
    label = "aisia.fr/deploy-id"
    value = random_id.deploy_id.hex
  }
}

###############################################################################
# AGENT AISIA — mode GLOBAL (orchestrateur de crews, app/agent/).
# Contrainte GPU optionnelle pour les nœuds équipés d'un GPU.
###############################################################################
resource "docker_service" "agent" {
  name = "${var.stack_name}_agent"

  task_spec {
    container_spec {
      image = "${var.image_registry}/aisia:${var.image_tag}"
      env   = concat(local.base_env_list, ["AISIA_COMPONENT=agent"])
    }

    networks_advanced {
      name = docker_network.aisia.id
    }

    placement {
      constraints = local.agent_constraints
    }

    restart_policy {
      condition    = "any"
      delay        = "5s"
      max_attempts = 5
      window       = "120s"
    }
  }

  mode {
    global = true
  }

  update_config {
    parallelism    = var.update_parallelism
    delay          = var.update_delay
    failure_action = "rollback"
    order          = "stop-first"
  }

  rollback_config {
    parallelism = 1
    delay       = "0s"
    order       = "stop-first"
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
  labels {
    label = "aisia.fr/component"
    value = "agent"
  }
  labels {
    label = "aisia.fr/deploy-id"
    value = random_id.deploy_id.hex
  }
}

###############################################################################
# FRONTEND AISIA — mode REPLICATED, tier-aware.
# Servi par nginx (image aisia-frontend), routé par Traefik si domain fourni.
###############################################################################
resource "docker_service" "frontend" {
  name = "${var.stack_name}_frontend"

  task_spec {
    container_spec {
      image = "${var.image_registry}/${var.image_frontend_name}:${var.image_tag}"
      env = concat(local.base_env_list, [
        "AISIA_COMPONENT=frontend",
        "AISIA_API_INTERNAL=http://${var.stack_name}_api:8000",
      ])

      healthcheck {
        test         = ["CMD", "wget", "--spider", "-q", "http://localhost:3000"]
        interval     = "30s"
        timeout      = "10s"
        retries      = 3
        start_period = "20s"
      }
    }

    networks_advanced {
      name = docker_network.aisia.id
    }

    placement {
      constraints = var.placement_frontend
    }

    restart_policy {
      condition    = "any"
      delay        = "5s"
      max_attempts = 5
      window       = "120s"
    }
  }

  mode {
    replicated {
      replicas = local.effective_frontend_replicas
    }
  }

  update_config {
    parallelism    = 1
    delay          = var.update_delay
    failure_action = "rollback"
    order          = "stop-first"
  }

  rollback_config {
    parallelism = 1
    delay       = "0s"
    order       = "stop-first"
  }

  # Labels Traefik (service-level).
  dynamic "labels" {
    for_each = local.traefik_frontend_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
  labels {
    label = "aisia.fr/component"
    value = "frontend"
  }
  labels {
    label = "aisia.fr/deploy-id"
    value = random_id.deploy_id.hex
  }
}
