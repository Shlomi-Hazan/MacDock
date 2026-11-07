#!/bin/sh
set -eu

output_dir="${1:?usage: generate-test-identities.sh /private/tmp/output-directory}"
if [ -e "$output_dir" ]; then
  echo "Refusing to overwrite existing directory: $output_dir" >&2
  exit 1
fi
mkdir -p "$output_dir"
chmod 700 "$output_dir"
umask 077

make_identity() {
  name="$1"
  cn="$2"
  key="$output_dir/$name.key.pem"
  cert="$output_dir/$name.cer.pem"
  der="$output_dir/$name.cer.der"
  p12="$output_dir/$name.identity.p12"
  password_file="$output_dir/$name.password"
  password="$(openssl rand -hex 24)"
  printf '%s\n' "$password" > "$password_file"
  openssl genrsa -out "$key" 2048 >/dev/null 2>&1
  openssl req -new -x509 -sha256 -days 2 -key "$key" -out "$cert" \
    -subj "/CN=$cn" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    -addext "keyUsage=digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth,clientAuth" >/dev/null 2>&1
  openssl x509 -in "$cert" -outform DER -out "$der"
  openssl pkcs12 -export -out "$p12" -inkey "$key" -in "$cert" \
    -passout "pass:$password" -name "MacDock mTLS $name" >/dev/null 2>&1
  openssl x509 -in "$cert" -outform DER | openssl dgst -sha256 -binary | xxd -p -c 256 > "$output_dir/$name.fingerprint"
}

make_identity server "MacDock mTLS Test Server"
make_identity client "MacDock mTLS Test Client"
printf 'Generated test-only identities under %s. Keep the directory outside Git.\n' "$output_dir"
printf 'Public fingerprints:\nserver: '; cat "$output_dir/server.fingerprint"
printf 'client: '; cat "$output_dir/client.fingerprint"
