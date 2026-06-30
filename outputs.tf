output "stack_name" {
  description = "Nom du stack Docker Swarm déployé."
  value       = var.stack_name
}

output "network_id" {
  description = "ID du réseau overlay AISIA créé."
  value       = docker_network.aisia.id
}

output "network_name" {
  description = "Nom du réseau overlay AISIA."
  value       = docker_network.aisia.name
}

output "api_service_name" {
  description = "Nom du service Docker Swarm de l'API AISIA."
  value       = docker_service.api.name
}

output "bot_service_name" {
  description = "Nom du service Docker Swarm du bot AISIA."
  value       = docker_service.bot.name
}

output "agent_service_name" {
  description = "Nom du service Docker Swarm de l'agent AISIA."
  value       = docker_service.agent.name
}

output "frontend_service_name" {
  description = "Nom du service Docker Swarm du frontend AISIA."
  value       = docker_service.frontend.name
}

output "public_url" {
  description = "URL publique du frontend (si domain fourni)."
  value       = var.domain != "" ? "https://${var.domain}" : null
}

output "api_url" {
  description = "URL publique de l'API REST (si domain fourni)."
  value       = local.effective_api_domain != "" ? "https://${local.effective_api_domain}" : null
}

output "tier" {
  description = "Tier d'exploitation appliqué."
  value       = var.tier
}

output "effective_bot_replicas" {
  description = "Nombre de replicas effectif du bot (après dérivation tier)."
  value       = local.effective_bot_replicas
}

output "effective_frontend_replicas" {
  description = "Nombre de replicas effectif du frontend (après dérivation tier)."
  value       = local.effective_frontend_replicas
}

output "deploy_id" {
  description = "ID unique de ce déploiement Terraform (stable par stack_name, utile pour le debugging)."
  value       = random_id.deploy_id.hex
}
