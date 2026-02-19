variable "tenancy_ocid" {
  description = "OCI tenancy OCID — from Profile → Tenancy"
  type        = string
  sensitive   = true

  validation {
    condition     = startswith(var.tenancy_ocid, "ocid1.tenancy")
    error_message = "Must start with ocid1.tenancy"
  }
}

variable "user_ocid" {
  description = "OCI user OCID — from Profile → My Profile"
  type        = string
  sensitive   = true

  validation {
    condition     = startswith(var.user_ocid, "ocid1.user")
    error_message = "Must start with ocid1.user"
  }
}

variable "fingerprint" {
  description = "API key fingerprint — from Profile → API Keys"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to OCI API private key PEM file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region identifier"
  type        = string
  default     = "ap-mumbai-1"
}

variable "compartment_id" {
  description = "OCI compartment OCID (root or dedicated)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
  sensitive   = true
}

variable "my_ip_cidr" {
  description = "Your IP in CIDR format for SSH/K8s API access, e.g. 1.2.3.4/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.my_ip_cidr))
    error_message = "Must be a valid CIDR block, e.g. 203.0.113.5/32"
  }
}

variable "availability_domain_index" {
  description = "Availability Domain index (0, 1, or 2). Try another if A1 capacity is unavailable."
  type        = number
  default     = 0

  validation {
    condition     = var.availability_domain_index >= 0 && var.availability_domain_index <= 2
    error_message = "Must be 0, 1, or 2"
  }
}
