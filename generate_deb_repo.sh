#!/bin/bash
# Yocto → Debian APT‑Repo Builder – arch‑spezifische Indizes mit Kompression

set -e

REPO_BASE="/repo"
WEBROOT="/www-root"
DIST="stable"
COMPONENT="main"
TMPROOT="/tmp/aptrepo"

echo "1) Webroot vorbereiten"
rm -rf "$WEBROOT/dists/$DIST" "$WEBROOT/pool"
mkdir -p "$WEBROOT/pool/$COMPONENT"
mkdir -p "$WEBROOT/dists/$DIST/$COMPONENT"

echo "2) Alte .deb‑Pakete entfernen (>14 Tage)"
find "$WEBROOT/pool/$COMPONENT" -type f -name '*.deb' -mtime +14 -exec rm -v {} \; || true

echo "3) Symlinks aller .deb aus Yocto nach pool/$COMPONENT"
for arch_dir in "$REPO_BASE"/*/; do
  [ -d "$arch_dir" ] || continue
  for deb in "$arch_dir"/*.deb; do
    [ -f "$deb" ] || continue
    ln -sf "$deb" "$WEBROOT/pool/$COMPONENT/$(basename "$deb")"
  done
done

echo "4) Architekturen ermitteln"
ARCH_LIST=()
for f in "$WEBROOT/pool/$COMPONENT"/*.deb; do
  base=$(basename "$f")
  arch="${base##*_}"
  arch="${arch%.deb}"
  ARCH_LIST+=("$arch")
done
ARCH_LIST=( $(printf "%s\n" "${ARCH_LIST[@]}" | sort -u) )
echo "   Gefundene Architekturen: ${ARCH_LIST[*]}"

echo "5) Erzeuge arch‑spezifische Package‑Indizes"
for arch in "${ARCH_LIST[@]}"; do
  echo "  → Architektur: $arch"
  BIN_DIR="$WEBROOT/dists/$DIST/$COMPONENT/binary-$arch"
  mkdir -p "$BIN_DIR"

  # Temp‑Verzeichnis mit pool-Layout
  TMPPOOL="$TMPROOT/$arch/pool/$COMPONENT"
  rm -rf "$TMPROOT/$arch"
  mkdir -p "$TMPPOOL"

  # nur passende Debs verlinken
  PATTERN="*_${arch}.deb"
  for deb in "$WEBROOT/pool/$COMPONENT"/$PATTERN; do
    [ -f "$deb" ] || continue
    ln -sf "$deb" "$TMPPOOL/$(basename "$deb")"
  done

  # Index erzeugen (im Temp‑Webroot, relativer Pfad pool/...)
  pushd "$TMPROOT/$arch" > /dev/null
  dpkg-scanpackages "pool/$COMPONENT" > "Packages"
  echo "    → Packages erzeugt"

  # Komprimierte Varianten direkt im BIN_DIR
  gzip -c9   "$TMPROOT/$arch/Packages" > "$BIN_DIR/Packages.gz"
  bzip2 -c   "$TMPROOT/$arch/Packages" > "$BIN_DIR/Packages.bz2"
  xz -c      "$TMPROOT/$arch/Packages" > "$BIN_DIR/Packages.xz"
  lzma -c    "$TMPROOT/$arch/Packages" > "$BIN_DIR/Packages.lzma"

  # verschiebe
  mv         "$TMPROOT/$arch/Packages"   "$BIN_DIR/Packages"

  echo "    Packages und Kompression in binary-$arch erstellt"
  popd > /dev/null
done

echo "6) Erzeuge zentrale Release‑Datei"
ARCH_STRING=$(printf "%s\n" "${ARCH_LIST[@]}" | xargs)
cat > "$WEBROOT/dists/$DIST/Release.conf" <<EOF
APT::FTPArchive::Release {
  Origin "Raspilab";
  Label "Raspilab Repo";
  Suite "$DIST";
  Codename "$DIST";
  Architectures "$ARCH_STRING";
  Components "$COMPONENT";
  Description "Raspilab DEB repo for Yocto builds";
};
EOF

apt-ftparchive -c "$WEBROOT/dists/$DIST/Release.conf" release "$WEBROOT/dists/$DIST" \
  > "$WEBROOT/dists/$DIST/Release"
rm "$WEBROOT/dists/$DIST/Release.conf"

echo "7) Aufräumen temporäre Verzeichnisse"
rm -rf "$TMPROOT"

echo "Fertig: Repository verfügbar unter $WEBROOT"
