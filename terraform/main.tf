# ============================================================
# Terraform Backend — State stored in OCI Object Storage
# ============================================================
# IMPORTANT: Replace the address below with your PAR URL.
# The PAR URL should end with /terraform.tfstate
# ============================================================

terraform {
  backend "http" {
    # Replace this ENTIRE address with your PAR URL from Part B
    address       = "https://objectstorage.ap-mumbai-1.oraclecloud.com/p/c7TzUE6y4vM5iC_HQ7-AQOEWFw3kcuZThTTY9NUZYeva5PgkO5rEsDE6MXw96xHV/n/bmj66jg2ptf7/b/devops-tf-state/o/terraform.tfstate"
    update_method = "PUT"
    # No lock support on OCI free tier — acceptable for single operator
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
