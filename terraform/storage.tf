# ============================================================
# Extra Block Volume — 50 GB for K8s persistent volumes
# Always-Free allows 200 GB total. Boot = 50 GB, this = 50 GB.
# ============================================================

resource "oci_core_volume" "data_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = var.compartment_id
  display_name        = "devops-data-volume"
  size_in_gbs         = 50
  vpus_per_gb         = 0 # 0 = Lower Cost performance tier (free)

  freeform_tags = {
    Project   = "devops-demo"
    ManagedBy = "terraform"
  }
}

resource "oci_core_volume_attachment" "data_attach" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.k3s_node.id
  volume_id       = oci_core_volume.data_volume.id
  is_read_only    = false
  is_shareable    = false
}
