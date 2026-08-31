#!/bin/bash
set -euo pipefail

# Determine repository root
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="$REPO_ROOT/src/os-mihomo"
OUTPUT_DIR="$REPO_ROOT/output"
WORK_DIR="$REPO_ROOT/work/build-pkg"
STAGE_DIR="$WORK_DIR/stage"
META_DIR="$WORK_DIR/meta"
PKG_ROOT="$WORK_DIR/pkg-root"
CACHE_DIR="$REPO_ROOT/work/cache"
VERSION_ENV="$SOURCE_DIR/build/mihomo-version.env"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Cross-platform SHA256 function: outputs raw hex digest of file
calc_sha256() {
    file_path="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$file_path"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
    else
        die "No sha256 calculation tool available (sha256sum, sha256, or shasum required)"
    fi
}

# Check required commands
command -v tar >/dev/null 2>&1 || die "tar command not found"
command -v gzip >/dev/null 2>&1 || die "gzip command not found"

# 1. Read PKG_NAME and VERSION
VERSION_FILE="$SOURCE_DIR/src/usr/local/opnsense/version/mihomo"
MAKEFILE="$SOURCE_DIR/Makefile"

PKG_NAME=""
VERSION=""

if [ -f "$VERSION_FILE" ]; then
    PKG_NAME="$(sed -n 's/.*"product_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$VERSION_FILE")"
    VERSION="$(sed -n 's/.*"product_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$VERSION_FILE")"
fi

if [ -z "$PKG_NAME" ] && [ -f "$MAKEFILE" ]; then
    PKG_NAME="$(sed -n 's/^PKG_NAME[[:space:]]*?*=[[:space:]]*//p' "$MAKEFILE" | tr -d '\r\n ')"
fi

if [ -z "$VERSION" ] && [ -f "$MAKEFILE" ]; then
    VERSION="$(sed -n 's/^VERSION[[:space:]]*?*=[[:space:]]*//p' "$MAKEFILE" | tr -d '\r\n ')"
fi

PKG_NAME="${PKG_NAME:-os-mihomo}"
VERSION="${VERSION:-1.0.2}"
ORIGIN="${ORIGIN:-opnsense/$PKG_NAME}"
COMMENT="${COMMENT:-Mihomo proxy integration for OPNsense}"
MAINTAINER="${MAINTAINER:-https://github.com/Opnwall/}"
WWW="${WWW:-https://github.com/MetaCubeX/mihomo}"
PREFIX="${PREFIX:-/usr/local}"
PKG_ABI="FreeBSD:*:amd64"
PKG_ARCH="freebsd:*:x86:64"
OUTPUT_PKG="$OUTPUT_DIR/${PKG_NAME}-${VERSION}.pkg"

echo "==> Building package $PKG_NAME-$VERSION"
echo "==> Source directory: $SOURCE_DIR"
echo "==> Output directory: $OUTPUT_DIR"

# Clean & Prepare directories
rm -rf "$WORK_DIR"
mkdir -p "$STAGE_DIR" "$META_DIR" "$PKG_ROOT" "$OUTPUT_DIR" "$CACHE_DIR"

# 2. Supply chain: Prepare official MetaCubeX Mihomo binary
[ -f "$VERSION_ENV" ] || die "Mihomo version env file not found: $VERSION_ENV"
# shellcheck source=/dev/null
. "$VERSION_ENV"

[ -n "${MIHOMO_VERSION:-}" ] || die "MIHOMO_VERSION not specified"
[ -n "${MIHOMO_SHA256:-}" ] || die "MIHOMO_SHA256 not specified"
[ -n "${MIHOMO_ASSET:-}" ] || die "MIHOMO_ASSET not specified"

CACHED_ASSET="$CACHE_DIR/$MIHOMO_ASSET"
CACHED_BIN="$CACHE_DIR/mihomo"

if [ ! -f "$CACHED_BIN" ]; then
    echo "==> Cached official binary not found, invoking update-mihomo.sh"
    "$REPO_ROOT/scripts/update-mihomo.sh" "$VERSION_ENV"
fi

# Verify cached binary SHA256 matches pinned unpacked hash or verify archive
if [ -n "${MIHOMO_UNPACKED_SHA256:-}" ]; then
    ACTUAL_UNPACKED="$(calc_sha256 "$CACHED_BIN")"
    if [ "$ACTUAL_UNPACKED" != "$MIHOMO_UNPACKED_SHA256" ]; then
        echo "==> Cached binary hash mismatch, re-downloading..."
        "$REPO_ROOT/scripts/update-mihomo.sh" "$VERSION_ENV"
    fi
fi

# 3. Stage src/os-mihomo/src/ contents
echo "==> Staging files from $SOURCE_DIR/src"
(cd "$SOURCE_DIR/src" && tar --exclude '.DS_Store' --exclude '._*' --exclude '*.xz' --exclude '*.gz' -cf - .) | (cd "$STAGE_DIR" && tar -xf -)

# 4. Install official verified Mihomo binary
mkdir -p "$STAGE_DIR/usr/local/bin"
cp -f "$CACHED_BIN" "$STAGE_DIR/usr/local/bin/mihomo"
chmod 0755 "$STAGE_DIR/usr/local/bin/mihomo"
[ -s "$STAGE_DIR/usr/local/bin/mihomo" ] || die "Staged mihomo binary is empty"

MIHOMO_FINAL_SHA256="$(calc_sha256 "$STAGE_DIR/usr/local/bin/mihomo")"

# 5. Set executable permissions
[ -f "$STAGE_DIR/usr/local/etc/mihomo/sub/sub.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/etc/mihomo/sub/sub.sh"
[ -f "$STAGE_DIR/usr/bin/mihomo_sub" ] && chmod 0755 "$STAGE_DIR/usr/bin/mihomo_sub"
[ -f "$STAGE_DIR/usr/local/etc/rc.d/mihomo" ] && chmod 0755 "$STAGE_DIR/usr/local/etc/rc.d/mihomo"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_unbound.php" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_unbound.php"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_firewall.php" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_firewall.php"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/watchdog.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/watchdog.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_firewall.php" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/mihomo/setup_firewall.php"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh"
[ -f "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh" ] && chmod 0755 "$STAGE_DIR/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh"

# 6. Compute SHA256 and flatsize for all staged files
PLIST="$WORK_DIR/pkg-plist"
(cd "$STAGE_DIR" && find . -type f | sed 's#^\.##' | sort) > "$PLIST"

FLATSIZE=0
while IFS= read -r file; do
    [ -n "$file" ] || continue
    size="$(wc -c < "$STAGE_DIR$file" | tr -d ' ')"
    FLATSIZE=$((FLATSIZE + size))
done < "$PLIST"

echo "==> Generating metadata (+MANIFEST)"
{
    printf 'name: "%s"\n' "$PKG_NAME"
    printf 'origin: "%s"\n' "$ORIGIN"
    printf 'version: "%s"\n' "$VERSION"
    printf 'comment: "%s"\n' "$COMMENT"
    printf 'maintainer: "%s"\n' "$MAINTAINER"
    printf 'www: "%s"\n' "$WWW"
    printf 'abi: "%s"\n' "$PKG_ABI"
    printf 'arch: "%s"\n' "$PKG_ARCH"
    printf 'prefix: "%s"\n' "$PREFIX"
    printf 'flatsize: %s\n' "$FLATSIZE"
    printf 'deps: {\n'
    printf '    jq: { origin: "textproc/jq", version: ">=0" }\n'
    printf '    curl: { origin: "ftp/curl", version: ">=0" }\n'
    printf '}\n'
    printf 'desc: <<EOD\n'
    if [ -f "$SOURCE_DIR/packaging/freebsd/pkg-descr" ]; then
        cat "$SOURCE_DIR/packaging/freebsd/pkg-descr"
    fi
    printf '\nEOD\n'
    printf 'files: {\n'
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        checksum="$(calc_sha256 "$STAGE_DIR$file")"
        printf '    "%s": "1$%s"\n' "$file" "$checksum"
    done < "$PLIST"
    printf '}\n'
    printf 'scripts: {\n'
    printf '    "post-install": <<EOS\n'
    if [ -f "$SOURCE_DIR/packaging/freebsd/+POST_INSTALL" ]; then
        cat "$SOURCE_DIR/packaging/freebsd/+POST_INSTALL"
    fi
    printf '\nEOS\n'
    printf '    "pre-deinstall": <<EOS\n'
    if [ -f "$SOURCE_DIR/packaging/freebsd/+PRE_DEINSTALL" ]; then
        cat "$SOURCE_DIR/packaging/freebsd/+PRE_DEINSTALL"
    fi
    printf '\nEOS\n'
    printf '    "post-deinstall": <<EOS\n'
    if [ -f "$SOURCE_DIR/packaging/freebsd/+POST_DEINSTALL" ]; then
        cat "$SOURCE_DIR/packaging/freebsd/+POST_DEINSTALL"
    fi
    printf '\nEOS\n'
    printf '}\n'
} > "$META_DIR/+MANIFEST"

cp "$META_DIR/+MANIFEST" "$META_DIR/+COMPACT_MANIFEST"

# 7. Package into FreeBSD pkg (tar.gz format)
echo "==> Packaging into $OUTPUT_PKG"
install -m 0644 "$META_DIR/+COMPACT_MANIFEST" "$PKG_ROOT/+COMPACT_MANIFEST"
install -m 0644 "$META_DIR/+MANIFEST" "$PKG_ROOT/+MANIFEST"
(cd "$STAGE_DIR" && tar -cf - .) | (cd "$PKG_ROOT" && tar -xf -)

TARLIST="$WORK_DIR/pkg-tarlist"
{
    printf '%s\n' '+COMPACT_MANIFEST' '+MANIFEST'
    find "$PKG_ROOT" -type f ! -name '+COMPACT_MANIFEST' ! -name '+MANIFEST' |
        sed "s#^$PKG_ROOT/##" |
        sort
} > "$TARLIST"

if tar --version 2>&1 | grep -q 'GNU'; then
    tar -czf "$OUTPUT_PKG" \
        -C "$PKG_ROOT" \
        --transform='s,^,/,g' \
        -T "$TARLIST"
else
    tar -cPzf "$OUTPUT_PKG" \
        -C "$PKG_ROOT" \
        -s ',^etc,/etc,' \
        -s ',^usr,/usr,' \
        -s ',^+MANIFEST,/\+MANIFEST,' \
        -s ',^+COMPACT_MANIFEST,/\+COMPACT_MANIFEST,' \
        -T "$TARLIST"
fi

# 8. Compute SHA256SUMS for output files
echo "==> Generating SHA256SUMS"
PKG_BASENAME="$(basename "$OUTPUT_PKG")"
(cd "$OUTPUT_DIR" && {
    pkg_hash="$(calc_sha256 "$PKG_BASENAME")"
    printf '%s  %s\n' "$pkg_hash" "$PKG_BASENAME" > "SHA256SUMS"
})

# 9. Generate build-info.json
echo "==> Generating build-info.json"
GIT_COMMIT="unknown"
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse HEAD >/dev/null 2>&1; then
    GIT_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
fi

BUILD_ENV="Ubuntu/Linux (Cross-Package)"
if [ "$(uname -s)" = "FreeBSD" ]; then
    BUILD_ENV="FreeBSD (Native)"
fi

cat <<EOF > "$OUTPUT_DIR/build-info.json"
{
  "plugin_version": "$VERSION",
  "mihomo_version": "$MIHOMO_VERSION",
  "mihomo_commit": "$MIHOMO_COMMIT",
  "mihomo_sha256": "$MIHOMO_FINAL_SHA256",
  "target_os": "FreeBSD",
  "target_arch": "amd64",
  "build_environment": "$BUILD_ENV",
  "source_commit": "$GIT_COMMIT"
}
EOF

# 10. Summary
PKG_FILE_SIZE="$(wc -c < "$OUTPUT_PKG" | tr -d ' ')"
PKG_FINAL_HASH="$(calc_sha256 "$OUTPUT_PKG")"

echo "============================================================"
echo "                   BUILD SUCCESS SUMMARY                    "
echo "============================================================"
echo " Package Name       : $PKG_NAME"
echo " Package Version    : $VERSION"
echo " Package File       : $OUTPUT_PKG"
echo " Package Size       : $PKG_FILE_SIZE bytes"
echo " Package SHA256     : $PKG_FINAL_HASH"
echo " Mihomo Version     : $MIHOMO_VERSION (commit: $MIHOMO_COMMIT)"
echo " Mihomo SHA256      : $MIHOMO_FINAL_SHA256"
echo " Target OS/Arch     : FreeBSD / amd64"
echo " Build Environment  : $BUILD_ENV"
echo " Source Commit      : $GIT_COMMIT"
echo " Manifest Flatsize  : $FLATSIZE bytes"
echo " Files Packaged     : $(wc -l < "$PLIST" | tr -d ' ') files"
echo "============================================================"
