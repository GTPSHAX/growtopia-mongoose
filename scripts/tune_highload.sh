#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Please run with sudo or as the root user."
  exit 1
fi


SYSCTL_FILE="/etc/sysctl.conf"
SYSCTL_BACKUP="${SYSCTL_FILE}.bak.$(date +%s)"

cp "$SYSCTL_FILE" "$SYSCTL_BACKUP"

update_sysctl() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}[[:space:]]*=" "$SYSCTL_FILE"; then
    sed -i "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "$SYSCTL_FILE"
  else
    echo "${key} = ${value}" >> "$SYSCTL_FILE"
  fi
}

update_sysctl "net.ipv4.tcp_tw_reuse" "1"
update_sysctl "net.ipv4.ip_local_port_range" "1024 65535"
update_sysctl "net.core.somaxconn" "10000"
update_sysctl "net.ipv4.tcp_max_syn_backlog" "10000"
update_sysctl "net.core.netdev_max_backlog" "50000"
update_sysctl "net.ipv4.tcp_max_tw_buckets" "200000"

sysctl -p > /dev/null 2>&1

LIMITS_FILE="/etc/security/limits.conf"
LIMITS_BACKUP="${LIMITS_FILE}.bak.$(date +%s)"

cp "$LIMITS_FILE" "$LIMITS_BACKUP"

sed -i '/^\*[[:space:]]\+soft[[:space:]]\+nofile/d' "$LIMITS_FILE"
sed -i '/^\*[[:space:]]\+hard[[:space:]]\+nofile/d' "$LIMITS_FILE"

cat <<EOF >> "$LIMITS_FILE"

# === Custom High-Load Benchmarking Limits ===
* soft    nofile          50000
* hard    nofile          50000
EOF

echo "System tuning for high-load benchmarking completed successfully."
echo "A backup of the original sysctl.conf is saved as: $SYSCTL_BACKUP"
echo "A backup of the original limits.conf is saved as: $LIMITS_BACKUP"
