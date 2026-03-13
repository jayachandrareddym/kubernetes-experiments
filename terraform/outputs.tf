output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "ingress_controller_hint" {
  description = "Get external endpoint for ingress-nginx"
  value       = "kubectl get svc -n ingress-nginx ingress-nginx-controller"
}
