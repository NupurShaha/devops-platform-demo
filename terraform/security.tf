# ============================================================
# Security List (OCI firewall rules at VCN level)
# ============================================================
# NOTE: OCI Security Lists are STATEFUL for TCP/UDP by default.
# Response traffic for established connections is automatically allowed.
# ============================================================

resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.devops_vcn.id
  display_name   = "devops-security-list"

  # ── INGRESS RULES ──

  # HTTP — Cloudflare proxies all public traffic
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "HTTP from anywhere (Cloudflare proxy)"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTPS from anywhere"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # SSH — restricted to your IP only
  ingress_security_rules {
    protocol    = "6"
    source      = var.my_ip_cidr
    description = "SSH from admin IP only"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # K8s API — restricted to your IP only (for remote kubectl)
  ingress_security_rules {
    protocol    = "6"
    source      = var.my_ip_cidr
    description = "K8s API server from admin IP only"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # ICMP — Path MTU discovery (required for networking to work properly)
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP path MTU discovery"

    icmp_options {
      type = 3
      code = 4
    }
  }

  # ICMP — Destination unreachable
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP destination unreachable"

    icmp_options {
      type = 3
    }
  }

  # ── EGRESS RULES ──

  # Allow all outbound (K3s needs to pull images, etc.)
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  freeform_tags = {
    Project   = "devops-demo"
    ManagedBy = "terraform"
  }
}
