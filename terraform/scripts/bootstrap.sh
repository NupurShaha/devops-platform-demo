#!/bin/bash
# ============================================================
# bootstrap.sh — Cloud-init for Oracle Cloud ARM Ubuntu 22.04
# Runs as root on first boot. Takes ~8-12 minutes.
# Monitor: sudo tail -f /var/log/bootstrap.log
# ============================================================
set -euo pipefail
exec > >(tee /var/log/bootstrap.log) 2>&1

echo "[bootstrap] ========================================="
echo "[bootstrap] Starting at $(date)"
echo "[bootstrap] ========================================="

# ── 1. CRITICAL: Flush Oracle's default iptables ──────────
# Oracle Cloud ARM instances ship with restrictive iptables
# that BREAK Kubernetes pod networking.
echo "[bootstrap] Step 1/13: Flushing Oracle iptables..."
iptables -F && iptables -X && iptables -Z
iptables -t nat -F && iptables -t nat -X
iptables -t mangle -F && iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
ip6tables -F 2>/dev/null || true

DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
netfilter-persistent save
echo "[bootstrap] iptables flushed and persisted"

# ── 2. System update ──────────────────────────────────────
echo "[bootstrap] Step 2/13: System update..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# ── 3. Essential packages ─────────────────────────────────
echo "[bootstrap] Step 3/13: Installing essential packages..."
apt-get install -y \
  curl wget git vim htop jq unzip \
  net-tools dnsutils nmap \
  fail2ban ufw nfs-common

# ── 4. Swap (4 GB — helps with burst situations) ─────────
echo "[bootstrap] Step 4/13: Configuring swap..."
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "[bootstrap] 4 GB swap created"
else
  echo "[bootstrap] Swap already exists"
fi

# ── 5. Format & mount data volume ────────────────────────
echo "[bootstrap] Step 5/13: Setting up data volume..."
DATAVOL=/dev/sdb
# Wait for volume to appear (can take a few seconds after boot)
for i in $(seq 1 30); do
  [ -b "$DATAVOL" ] && break
  echo "[bootstrap] Waiting for $DATAVOL... ($i/30)"
  sleep 2
done

if [ -b "$DATAVOL" ]; then
  if ! blkid "$DATAVOL" > /dev/null 2>&1; then
    echo "[bootstrap] Formatting $DATAVOL..."
    mkfs.ext4 -F "$DATAVOL"
  fi
  mkdir -p /mnt/data
  if ! grep -q '/mnt/data' /etc/fstab; then
    echo "$DATAVOL /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a || true
  echo "[bootstrap] Data volume mounted at /mnt/data"
else
  echo "[bootstrap] WARNING: $DATAVOL not found. Proceeding without extra volume."
  mkdir -p /mnt/data
fi

# Create subdirectories for K8s persistent volumes
mkdir -p /mnt/data/{postgresql,redis,rabbitmq,loki,prometheus,grafana,argocd,k3s,k3s-storage}
chmod 777 /mnt/data
echo "[bootstrap] Data directories created"

# ── 6. SSH hardening ──────────────────────────────────────
echo "[bootstrap] Step 6/13: Hardening SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl restart ssh
echo "[bootstrap] SSH hardened: no root login, no password auth, max 3 attempts"

# ── 7. Fail2ban ───────────────────────────────────────────
echo "[bootstrap] Step 7/13: Configuring Fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2B_EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
F2B_EOF
systemctl enable fail2ban
systemctl restart fail2ban
echo "[bootstrap] Fail2ban active: 5 failed SSH attempts = 1 hour ban"

# ── 8. Install K3s ────────────────────────────────────────
echo "[bootstrap] Step 8/13: Installing K3s (this takes 2-3 minutes)..."
PUBLIC_IP=$(curl -s checkip.amazonaws.com)
echo "[bootstrap] Public IP detected: $PUBLIC_IP"

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="v1.28.4+k3s2" \
  INSTALL_K3S_EXEC="--tls-san $PUBLIC_IP \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --data-dir /mnt/data/k3s \
    --default-local-storage-path /mnt/data/k3s-storage" sh -

# Wait for K3s to be ready
echo "[bootstrap] Waiting for K3s to become ready..."
for i in $(seq 1 60); do
  if kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml 2>/dev/null | grep -q " Ready"; then
    echo "[bootstrap] K3s is Ready"
    break
  fi
  echo "[bootstrap] Waiting for K3s... ($i/60)"
  sleep 5
done

# ── 9. Kubeconfig for ubuntu user ─────────────────────────
echo "[bootstrap] Step 9/13: Setting up kubeconfig..."
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sed -i "s/127.0.0.1/$PUBLIC_IP/g" /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "[bootstrap] Kubeconfig configured for ubuntu user"

# ── 10. Install Helm ──────────────────────────────────────
echo "[bootstrap] Step 10/13: Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "[bootstrap] Helm installed: $(helm version --short)"

# ── 11. UFW firewall ──────────────────────────────────────
echo "[bootstrap] Step 11/13: Configuring UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 6443/tcp comment 'K8s API'
# K3s flannel networking
ufw allow in on flannel.1
ufw allow in on cni0
ufw allow from 10.42.0.0/16 to any comment 'K3s Pod CIDR'
ufw allow from 10.43.0.0/16 to any comment 'K3s Service CIDR'
ufw --force enable
echo "[bootstrap] UFW enabled with K3s rules"

# ── 12. node_exporter (host metrics for Prometheus) ──────
echo "[bootstrap] Step 12/13: Installing node_exporter..."
useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-arm64.tar.gz
tar xf node_exporter-1.7.0.linux-arm64.tar.gz
cp node_exporter-1.7.0.linux-arm64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'NE_EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.systemd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
NE_EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
echo "[bootstrap] node_exporter running on :9100"

# ── 13. Auto-fix iptables on reboot (Oracle Cloud issue) ─
echo "[bootstrap] Step 13/13: Setting up reboot iptables fix..."
cat > /etc/cron.d/flush-iptables << 'CRON_EOF'
# Oracle Cloud sometimes reapplies restrictive iptables on reboot
@reboot root sleep 30 && iptables -F && iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && netfilter-persistent save && systemctl restart k3s
CRON_EOF

# Automatic security updates (no auto-reboot)
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades

echo "[bootstrap] ========================================="
echo "[bootstrap] COMPLETE at $(date)"
echo "[bootstrap] Public IP: $PUBLIC_IP"
echo "[bootstrap] K3s node: Ready"
echo "[bootstrap] SSH: ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP"
echo "[bootstrap] ========================================="
