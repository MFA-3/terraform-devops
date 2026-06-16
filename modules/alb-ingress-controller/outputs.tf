output "service_account_name" {
  description = "Service account name for ALB Ingress Controller"
  value       = kubernetes_service_account.alb_ingress_controller.metadata[0].name
}

output "helm_release_name" {
  description = "Helm release name"
  value       = helm_release.alb_ingress_controller.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.alb_ingress_controller.status
}
