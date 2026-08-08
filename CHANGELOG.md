# Changelog — terraform-aisia-swarm

Format : [Keep a Changelog](https://keepachangelog.com/) · Versioning : SemVer AISIA-couplé.

## [Unreleased] — correction pré-publication (2026-08-05)

### Fixed
- `image_tag` default et `VERSION` rétablis à `v6.12.80` (dernière version AISIA
  **certifiée LIVE**, DEPLOY-REPORT all-green — `project_facts.json:prod_live_version`).
  Le commit `5a5ab47fa` (bump global « prepare v6.12.81 ») avait fait passer le default
  à `v6.12.81`, alors que cette version est encore 🟡 **PRÉPARÉE** (code seulement — build
  multi-arch, déploiement et DEPLOY-REPORT tous PENDING, cf.
  `artifacts/prepare-v6.12.81.md`). Le commit `8d818d7826e` avait déjà corrigé le texte
  de description (« ex. v6.12.80 ») et les exemples, mais pas la valeur fonctionnelle
  `default`, laissant le module publié avec une incohérence interne (README annonçait
  v6.12.80 partout, le default réel déployait v6.12.81 — tag d'image potentiellement
  inexistant sur `registry.aisia.fr`). Gate `run_terraform_modules_gate` de nouveau vert
  (`VERSION == prod_live_version`). ⚠️ **registry.terraform.io a déjà ingéré une version
  `6.12.81` immuable avec le défaut fautif** — cette correction locale ne la retire pas ;
  elle doit être republiée dans une future version (ex. `6.12.82`, une fois qu'une release
  AISIA plus récente que 6.12.80 est certifiée LIVE, ou via un hotfix dédié) pour que les
  nouveaux `terraform init` récupèrent le default sûr.

## [6.12.80] — 2026-08-05

### Changed
- Sync `image_tag` default -> `v6.12.80` (release AISIA v6.12.80 LIVE, DEPLOY-REPORT
  all-green). Entrée rétroactive (bump réel non documenté au moment du commit
  `38058f47f`). Aucun changement fonctionnel des resources/variables/outputs.

## [6.12.79] — 2026-08-04

### Changed
- Sync `image_tag` default -> `v6.12.79` (bump AISIA patch, jamais déployé isolément —
  englobé par la chaîne v6.12.80). Entrée rétroactive (bump réel non documenté au moment
  du commit `0ac97ec9d`). Aucun changement fonctionnel des resources/variables/outputs.

## [6.12.78] — 2026-08-04

### Changed
- Sync `image_tag` default -> `v6.12.78` (release AISIA v6.12.78 LIVE). Rattrape aussi le
  saut `v6.12.77` (VERSION + image_tag bumpés en v6.12.77 par le commit `ad31e4ac8` sans
  entrée CHANGELOG, jamais publié au registry). Aucun changement fonctionnel des
  resources/variables/outputs (patch de synchronisation de version).

## [6.12.76] — 2026-08-02

### Changed
- Sync `image_tag` default -> `v6.12.76` (release AISIA v6.12.76 LIVE). Aucun changement
  fonctionnel des resources/variables/outputs (patch de synchronisation de version).

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
