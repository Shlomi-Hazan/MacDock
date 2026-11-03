#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="${1:-$script_dir/.local}"
mkdir -p "$output_dir"
umask 077

password_file="$output_dir/password.txt"
key_file="$output_dir/server.key.pem"
certificate_file="$output_dir/server.cer.pem"
p12_file="$output_dir/server.identity.p12"

if [ -e "$password_file" ] || [ -e "$key_file" ] || [ -e "$certificate_file" ] || [ -e "$p12_file" ]; then
  echo "Refusing to overwrite existing test identity files in $output_dir" >&2
  exit 1
fi

password="$(openssl rand -hex 24)"
printf '%s\n' "$password" > "$password_file"
openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1
openssl req -new -x509 -sha256 -days 7 -key "$key_file" -out "$certificate_file" \
  -subj "/CN=MacDock TLS Experiment" >/dev/null 2>&1
openssl pkcs12 -export -out "$p12_file" -inkey "$key_file" -in "$certificate_file" \
  -passout "pass:$password" -name "MacDock TLS Experiment" >/dev/null 2>&1

fingerprint="$(openssl x509 -in "$certificate_file" -outform DER | openssl dgst -sha256 -binary | xxd -p -c 256)"
printf '%s\n' "$fingerprint" > "$output_dir/fingerprint.txt"
chmod 600 "$password_file" "$key_file" "$p12_file" "$output_dir/fingerprint.txt"
printf 'Generated local test identity.\nCertificate fingerprint (SHA-256, lowercase hex):\n%s\n' "$fingerprint"
printf 'Copy only this fingerprint into the iOS experiment UI; never copy the private key or password.\n'
