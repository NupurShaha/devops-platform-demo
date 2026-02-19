# ============================================================
# Ampere A1 Flex VM — Always-Free tier
# Current: 2 OCPUs, 12 GB (resize to 4/24 when capacity allows)
# ============================================================

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_arm" {
  compartment_id          = var.compartment_id
  operating_system        = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                   = "VM.Standard.A1.Flex"
  sort_by                 = "TIMECREATED"
  sort_order              = "DESC"
}

resource "oci_core_instance" "k3s_node" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = var.compartment_id
  display_name        = "devops-demo-k3s"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "primary-vnic"
    assign_public_ip = true
    hostname_label   = "devopsdemo"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/scripts/bootstrap.sh"))
  }

  freeform_tags = {
    Project     = "devops-demo"
    ManagedBy   = "terraform"
    Environment = "production"
  }

  lifecycle {
    prevent_destroy = true
  }
}
