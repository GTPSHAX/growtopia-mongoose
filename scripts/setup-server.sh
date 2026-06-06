#!/usr/bin/env bash

set -euo pipefail

CLOUDFLARE_URL="https://www.cloudflare.com/ips-v4/"
PORT=8080
CHAIN="INPUT"

log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "This script must be run as root (use sudo)."
}

fetch_ips() {
  log "Fetching Cloudflare IPv4 ranges from ${CLOUDFLARE_URL} ..."
  if command -v curl &>/dev/null; then
    curl -fsSL "$CLOUDFLARE_URL"
  elif command -v wget &>/dev/null; then
    wget -qO- "$CLOUDFLARE_URL"
  else
    die "Neither curl nor wget is available. Install one and retry."
  fi
}

apply_ufw() {
  log "Using ufw to allow TCP ${PORT} for Cloudflare ranges."
  while IFS= read -r cidr; do
    [[ -z "$cidr" ]] && continue
    log "  ufw allow from ${cidr} to any port ${PORT} proto tcp"
    ufw allow from "$cidr" to any port "$PORT" proto tcp
  done <<< "$1"
  log "Reloading ufw ..."
  ufw reload
  log "Done (ufw)."
}

apply_iptables() {
  log "Using iptables to allow TCP ${PORT} for Cloudflare ranges."
  while IFS= read -r cidr; do
    [[ -z "$cidr" ]] && continue
    # Skip if rule already exists
    if iptables -C "$CHAIN" -s "$cidr" -p tcp --dport "$PORT" -j ACCEPT &>/dev/null 2>&1; then
      warn "  Rule already exists for ${cidr}, skipping."
    else
      log "  iptables -A ${CHAIN} -s ${cidr} -p tcp --dport ${PORT} -j ACCEPT"
      iptables -A "$CHAIN" -s "$cidr" -p tcp --dport "$PORT" -j ACCEPT
    fi
  done <<< "$1"

  if command -v netfilter-persistent &>/dev/null; then
    log "Saving rules with netfilter-persistent ..."
    netfilter-persistent save
  elif command -v iptables-save &>/dev/null; then
    local rules_file="/etc/iptables/rules.v4"
    if [[ -d /etc/iptables ]]; then
      log "Saving rules to ${rules_file} ..."
      iptables-save > "$rules_file"
    else
      warn "Could not auto-save iptables rules. Run 'iptables-save' manually."
    fi
  fi

  log "Done (iptables)."
}

require_root

IP_LIST="$(fetch_ips)"

if [[ -z "$IP_LIST" ]]; then
  die "No IP ranges retrieved. Check your internet connection."
fi

log "Retrieved IP ranges:"
echo "$IP_LIST" | sed 's/^/  /'

if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  apply_ufw "$IP_LIST"
elif command -v iptables &>/dev/null; then
  apply_iptables "$IP_LIST"
else
  die "No supported firewall tool found (ufw or iptables required)."
fi
