#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${1:-DeepOCRClip Local Code Signing}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
WORK_DIR="$(mktemp -d)"
CERT_PEM="$WORK_DIR/cert.pem"
KEY_PEM="$WORK_DIR/key.pem"
P12_FILE="$WORK_DIR/identity.p12"
OPENSSL_CONFIG="$WORK_DIR/openssl.cnf"
P12_PASSWORD="DeepOCRClipLocalSigning"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Signing identity already exists: $IDENTITY_NAME"
    exit 0
fi

cat >"$OPENSSL_CONFIG" <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_codesign
prompt = no

[ req_distinguished_name ]
CN = $IDENTITY_NAME

[ v3_codesign ]
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -x509 \
    -days 3650 \
    -keyout "$KEY_PEM" \
    -out "$CERT_PEM" \
    -config "$OPENSSL_CONFIG" >/dev/null 2>&1

openssl pkcs12 \
    -export \
    -legacy \
    -inkey "$KEY_PEM" \
    -in "$CERT_PEM" \
    -out "$P12_FILE" \
    -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

security import "$P12_FILE" \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -A \
    -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$CERT_PEM" >/dev/null

security add-trusted-cert \
    -r trustRoot \
    -k "$KEYCHAIN" \
    "$CERT_PEM" >/dev/null

echo "Created signing identity: $IDENTITY_NAME"
