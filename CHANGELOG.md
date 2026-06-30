# Changelog — terraform-aisia-swarm

Format : [Keep a Changelog](https://keepachangelog.com/) · Versioning : SemVer AISIA-couplé.

## [6.9.61] — 2026-06-30

### Added
- Module initial publiable (Terraform Registry) : déploiement de la stack AISIA
  sur un Docker Swarm **existant**, cloud-agnostique (bare-metal ARM64,
  VM cloud, hybride).
- **Parité dual-substrate** avec `terraform-aisia-cluster` (K8s) — comble le
  manque identifié dans la famille registry `ai-aisia-lab/infra/terraform-registry/`.
- **Services** : `aisia_api` (mode GLOBAL), `aisia_agent` (mode GLOBAL, GPU
  optionnel), `aisia_bot` (REPLICATED, tier-aware), `aisia_frontend` (REPLICATED,
  tier-aware — image `aisia-frontend`).
- **Réseau overlay** : `docker_network` attachable avec labels de traçabilité.
- **Rolling update sécurisé** : `update_parallelism=1`, `delay=60s`,
  `failure_action=rollback` par défaut (règle AISIA gravée dans le marbre
  suite à un retour d'expérience (cascade I/O sous parallélisme élevé)).
- **Traefik** : labels auto-générés (service-level) sur API et frontend
  si `domain` est fourni ; supporte le mode Swarm de Traefik v2/v3.
- **Tiers** (`free/saas/baas/paas`) : dérivation automatique des réplicas
  bot/frontend avec possibilité de surcharge explicite.
- **GPU** : contrainte `node.labels.gpu == true` sur l'agent si `gpu_enabled=true`
  (nœuds GPU / edge).
- **Déploiement ID** : `random_id.deploy_id` stable par `stack_name`,
  injecté comme label sur tous les services (traçabilité Terraform).
- **Healthchecks** : `wget --spider /health` sur l'API (endpoint public,
  cf. bonne pratique : healthcheck sur endpoint public) et `/` sur le frontend ; bot/agent sans
  healthcheck HTTP (workers Python sans serveur HTTP).
- Variables d'entrée normalisées : `docker_host`, `stack_name`, `image_tag`
  (default `v6.9.61`), `image_registry`, `image_frontend_name`, `domain`,
  `api_domain`, `tier`, `bot_replicas`, `frontend_replicas`, `gpu_enabled`,
  `extra_env`, `placement_*`, `update_parallelism`, `update_delay`,
  `network_driver`.
- Outputs : `stack_name`, `network_id`, `network_name`, `api_service_name`,
  `bot_service_name`, `agent_service_name`, `frontend_service_name`,
  `public_url`, `api_url`, `tier`, `effective_bot_replicas`,
  `effective_frontend_replicas`, `deploy_id`.
- README avec tableaux Inputs/Outputs, usage, prérequis, architecture.
- LICENSE MPL-2.0, VERSION 6.9.61, exemple `examples/basic`.
- Providers : `kreuzwerker/docker >= 3.0.2` + `hashicorp/random >= 3.5.0`.
