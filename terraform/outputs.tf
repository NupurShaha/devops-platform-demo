output "instance_public_ip" {
  description = "Public IP of K3s node — use this for DNS and SSH"
  value       = oci_core_instance.k3s_node.public_ip
}

output "instance_private_ip" {
  description = "Private IP — used for Prometheus node_exporter scraping"
  value       = oci_core_instance.k3s_node.private_ip
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${oci_core_instance.k3s_node.public_ip}"
}

output "availability_domain" {
  description = "AD where the instance was created"
  value       = oci_core_instance.k3s_node.availability_domain
}

output "backup_bucket" {
  description = "Backup bucket name"
  value       = oci_objectstorage_bucket.backups.name
}

output "backup_namespace" {
  description = "Object storage namespace"
  value       = data.oci_objectstorage_namespace.ns.namespace
}
