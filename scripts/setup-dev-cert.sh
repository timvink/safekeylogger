#!/bin/bash

# Setup a persistent self-signed certificate for development
# This allows the app to maintain Accessibility permissions across rebuilds

CERT_NAME="SafeKeylogger Development"
KEYCHAIN="login.keychain"

# Check if identity already exists and is valid for codesigning
if security find-identity -v -p codesigning | grep -q "${CERT_NAME}"; then
    echo "✅ Code signing identity '${CERT_NAME}' already exists and is valid"
    exit 0
fi

echo "📝 Creating self-signed certificate for development..."
echo "This certificate will be used to sign the app, allowing it to maintain"
echo "Accessibility permissions across rebuilds."
echo ""

# Create a self-signed certificate
# The certificate will be valid for 10 years
security create-keychain -p "" "${KEYCHAIN}" 2>/dev/null || true

cat > /tmp/cert.cfg << 'EOF'
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
prompt             = no
x509_extensions    = codesign

[ req_distinguished_name ]
CN = SafeKeylogger Development

[ codesign ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# Generate private key and certificate
openssl req -x509 -newkey rsa:2048 -keyout /tmp/dev.key -out /tmp/dev.crt \
    -days 3650 -nodes -config /tmp/cert.cfg

# Convert to p12 format for import
# Use -legacy for compatibility with macOS keychain if using OpenSSL 3
openssl pkcs12 -export -out /tmp/dev.p12 -inkey /tmp/dev.key -in /tmp/dev.crt \
    -passout pass:safekeylogger -legacy

# Import into keychain
security import /tmp/dev.p12 -k "${KEYCHAIN}" -P safekeylogger -T /usr/bin/codesign

# Trust the certificate for code signing
echo ""
echo "⚠️  You may be prompted to trust the certificate."
echo "   Click 'Always Trust' to allow code signing."
security add-trusted-cert -d -r trustRoot -k "${KEYCHAIN}" /tmp/dev.crt 2>/dev/null || true

# Cleanup
rm -f /tmp/cert.cfg /tmp/dev.key /tmp/dev.crt /tmp/dev.p12

echo ""
echo "✅ Development certificate '${CERT_NAME}' created successfully!"
echo ""
echo "The build script will now use this certificate to sign the app."
echo "This should preserve Accessibility permissions across rebuilds."
