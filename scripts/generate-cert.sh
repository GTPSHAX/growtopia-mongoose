#!/usr/bin/env bash

set -e

# Color definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
NC=$(tput sgr0) # No Color

CERT_FILE="dist/certs/server.crt"
KEY_FILE="dist/certs/server.key"
CN="localhost"
DAYS=365
RSA_BITS=2048
SAN="DNS:localhost,IP:127.0.0.1"

usage() {
  cat <<EOF
Usage:
  $0 [options]

Options:
  -c, --cn <name>         Common Name (default: localhost)
  -d, --days <days>       Certificate validity (default: 365)
  -b, --bits <bits>       RSA key size (default: 2048)
  -s, --san <value>       SubjectAltName
                          Example:
                          DNS:localhost,IP:127.0.0.1
  --cert <file>           Certificate output path
  --key <file>            Key output path
  -h, --help              Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cn)
      CN="$2"
      shift 2
      ;;
    -d|--days)
      DAYS="$2"
      shift 2
      ;;
    -b|--bits)
      RSA_BITS="$2"
      shift 2
      ;;
    -s|--san)
      SAN="$2"
      shift 2
      ;;
    --cert)
      CERT_FILE="$2"
      shift 2
      ;;
    --key)
      KEY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
esac
done

mkdir -p "$(dirname "$CERT_FILE")"
mkdir -p "$(dirname "$KEY_FILE")"

openssl req \
  -x509 \
  -newkey rsa:${RSA_BITS} \
  -nodes \
  -days "${DAYS}" \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -subj "/CN=${CN}" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "subjectAltName=${SAN}"

echo "${CYAN}Certificate : ${CERT_FILE}${NC}"
echo "${CYAN}Private Key : ${KEY_FILE}${NC}"

# Register the certificate to the system trust store
echo "---"
echo "${GREEN}Attempting to register certificate to the system trust store...${NC}"

if [[ ! -f "${CERT_FILE}" ]]; then
  echo "${RED}Error: Certificate file not found at ${CERT_FILE}${NC}"
  exit 1
fi

if command -v update-ca-certificates >/dev/null 2>&1; then
  echo "${YELLOW}Detected Debian/Ubuntu-based system.${NC}"
  sudo rm -f "/usr/local/share/ca-certificates/growtopia-mongoose-local.crt"
  sudo cp "${CERT_FILE}" "/usr/local/share/ca-certificates/growtopia-mongoose-local.crt"
  sudo update-ca-certificates
  echo "${GREEN}System certificate successfully registered.${NC}"

elif command -v update-ca-trust >/dev/null 2>&1; then
  echo "${YELLOW}Detected RHEL/Fedora-based system.${NC}"
  sudo rm -f "/etc/pki/ca-trust/source/anchors/growtopia-mongoose-local.crt"
  sudo cp "${CERT_FILE}" "/etc/pki/ca-trust/source/anchors/growtopia-mongoose-local.crt"
  sudo update-ca-trust
  echo "${GREEN}System certificate successfully registered.${NC}"

elif command -v trust >/dev/null 2>&1; then
  echo "${YELLOW}Detected system using trust (p11-kit).${NC}"
  sudo trust anchor --store "${CERT_FILE}"
  echo "${GREEN}System certificate successfully registered.${NC}"

else
  echo "${RED}Could not automatically determine how to update the system trust store.${NC}"
  echo "Please manually install '${CERT_FILE}' to your OS trusted root certificates."
fi

echo "---"
echo "${YELLOW}NOTE FOR FIREFOX USERS:${NC}"
echo "Firefox on Linux does NOT use the system certificate store by default."
echo "To trust this certificate in Firefox, follow these steps:"
echo "  1. Open Firefox and go to: ${CYAN}about:preferences#privacy${NC}"
echo "  2. Scroll to the bottom and click ${CYAN}'View Certificates...'"
echo "  3. In the 'Authorities' tab, click ${CYAN}'Import...'"
echo "  4. Select this file: ${CYAN}${CERT_FILE}${NC}"
echo "  5. Check the box: ${CYAN}'Trust this CA to identify websites'${NC}"
echo "  6. Click OK. The warning will be gone."
echo ""
echo "${GREEN}Setup complete!${NC}"
