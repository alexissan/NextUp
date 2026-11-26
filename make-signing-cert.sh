#!/bin/bash
# Creates a self-signed code-signing certificate in your login keychain. Run it once.
#
# Without it, build.sh signs ad hoc, which ties the calendar permission to one exact build:
# every rebuild needs the permission granted again. With it, the permission follows the certificate,
# so rebuilds keep it. The certificate never leaves this Mac and is only good for signing locally.
set -euo pipefail

NAME="NextUp Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "\"$NAME\" is already in your login keychain."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
chmod 700 "$WORK"

cat > "$WORK/cert.conf" <<CONF
[req]
distinguished_name = name
x509_extensions = ext
prompt = no
[name]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF

# The system OpenSSL writes a PKCS#12 file the keychain can read; newer builds default to one it can't.
OPENSSL=/usr/bin/openssl
"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/cert.conf" \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

# A throwaway passphrase, used only to move the key from the temporary file into the keychain.
TRANSIT="$("$OPENSSL" rand -hex 16)"
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
    -out "$WORK/identity.p12" -passout "pass:$TRANSIT"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$TRANSIT" -T /usr/bin/codesign >/dev/null

echo "Created \"$NAME\" in your login keychain."
echo "Run ./build.sh. The first time, macOS asks whether codesign may use the key: choose Always Allow."
