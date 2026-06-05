#!/usr/bin/env bash

set -e

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
  -addext "subjectAltName=${SAN}"

echo "Certificate : ${CERT_FILE}"
echo "Private Key : ${KEY_FILE}"