output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "eks cluster security group" 
  value = aws_security_group.eks_cluster.id
}
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}
