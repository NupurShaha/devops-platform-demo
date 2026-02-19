# ============================================================
# VCN, Subnet, Internet Gateway, Route Table
# ============================================================

resource "oci_core_vcn" "devops_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "devops-demo-vcn"
  dns_label      = "devopsdemo"

  freeform_tags = {
    Project   = "devops-demo"
    ManagedBy = "terraform"
  }
}

resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.devops_vcn.id
  display_name   = "devops-demo-ig"
  enabled        = true
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.devops_vcn.id
  display_name   = "public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.ig.id
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.devops_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = {
    Project   = "devops-demo"
    ManagedBy = "terraform"
  }
}
