#!/bin/bash
set -e

# Config
VERSION="1.0.1"
BUILD_SUFFIX="2"
ARCH="amd64"
DEBEMAIL="chuck@nordheim.online"
PACKAGE_NAME="upscayl_${VERSION}-${BUILD_SUFFIX}_${ARCH}"
BUILD_DIR="build/linux/deb/${PACKAGE_NAME}"

# Build flutter
echo "Building Flutter Desktop for Linux..."
flutter build linux --release

# Prepare DEB structure
mkdir -p "${BUILD_DIR}/DEBIAN"
mkdir -p "${BUILD_DIR}/usr/bin"
mkdir -p "${BUILD_DIR}/usr/share/applications"
mkdir -p "${BUILD_DIR}/usr/share/pixmaps"
mkdir -p "${BUILD_DIR}/usr/lib/upscayl"
mkdir -p "${BUILD_DIR}/usr/share/doc/upscayl"

# Control file
cat <<EOF > "${BUILD_DIR}/DEBIAN/control"
Package: upscayl
Version: ${VERSION}-${BUILD_SUFFIX}
Section: graphics
Priority: optional
Architecture: ${ARCH}
Maintainer: Chuck Talk <chuck@nordheim.online>
Description: AI Image Upscaler Native Rewrite
 Free and Open Source AI Image Upscaler (Flutter Rewrite)
EOF

# Copy binaries
cp -r build/linux/x64/release/bundle/* "${BUILD_DIR}/usr/lib/upscayl/"

# Wrapper
cat <<'EOF' > "${BUILD_DIR}/usr/bin/upscayl"
#!/bin/bash
exec /usr/lib/upscayl/upscayl "$@"
EOF
chmod +x "${BUILD_DIR}/usr/bin/upscayl"

# Ensure upscayl-bin dependency is executable from the flutter assets out
chmod +x "${BUILD_DIR}/usr/lib/upscayl/data/flutter_assets/assets/linux/bin/upscayl-bin" || true

# Icons
mkdir -p "${BUILD_DIR}/usr/share/icons/hicolor/512x512/apps"
if [ -f "/home/freecode/github/upscayl/resources/icons/512x512.png" ]; then
    cp /home/freecode/github/upscayl/resources/icons/512x512.png "${BUILD_DIR}/usr/share/icons/hicolor/512x512/apps/upscayl.png"
    cp /home/freecode/github/upscayl/resources/icons/512x512.png "${BUILD_DIR}/usr/share/pixmaps/upscayl.png"
fi

# Licenses
cp LICENSE "${BUILD_DIR}/usr/share/doc/upscayl/copyright"

cat <<EOF > "${BUILD_DIR}/usr/share/applications/upscayl.desktop"
[Desktop Entry]
Name=Upscayl
Comment=AI Image Upscaler
Exec=/usr/bin/upscayl
Icon=upscayl
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;ImageProcessing;
Keywords=system;monitor;observability;metrics;
EOF

dpkg-deb --build --root-owner-group "${BUILD_DIR}"
echo "Created build/linux/deb/${PACKAGE_NAME}.deb"

# ── Signing and Hashing ──────────────────────────────────────────────
cd build/linux/deb/
sha512sum "${PACKAGE_NAME}.deb" > "${PACKAGE_NAME}.deb.sha512"

if gpg --list-keys "${DEBEMAIL}" &> /dev/null; then
  gpg --armor --detach-sign --local-user "${DEBEMAIL}" --output "${PACKAGE_NAME}.deb.asc" "${PACKAGE_NAME}.deb"
  gpg --armor --export "${DEBEMAIL}" > chuck_pubkey.asc
fi

echo "==================================="
echo "  Build complete in build/linux/deb"
echo "==================================="
