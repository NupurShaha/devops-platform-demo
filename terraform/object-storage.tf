# ============================================================
# Object Storage Bucket — for database backups (Phase 5)
# ============================================================

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id        = var.compartment_id
  namespace             = data.oci_objectstorage_namespace.ns.namespace
  name                  = "devops-demo-backups"
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  object_events_enabled = false
  versioning            = "Disabled"

  freeform_tags = {
    Project   = "devops-demo"
    ManagedBy = "terraform"
  }
}
