#!/bin/sh

isAlpha="${isAlpha:-false}"

CORE_DST="box_bll/bin/clash"
CORE_TMP="clash_core.gz"
MIHOMO_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
MIHOMO_BASE="https://github.com/MetaCubeX/mihomo/releases/download"
MIHOMO_NAME="mihomo-android-arm64-v8"

EASYTIER_API="https://api.github.com/repos/EasyTier/EasyTier/releases/latest"
EASYTIER_BASE="https://github.com/EasyTier/EasyTier/releases/download"
EASYTIER_DST="box_bll/bin/easytier-core"
EASYTIER_TMP="easytier_core.zip"

ZASH_API="https://api.github.com/repos/Zephyruso/zashboard/releases/latest"
ZASH_DST="box_bll/clash/webroot/Zash"
ZASH_TMP="zash_dist.zip"

get_latest_tag() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL --retry 5 --retry-delay 5 \
            -H "Authorization: token $GITHUB_TOKEN" "$1"
    else
        curl -fsSL --retry 5 --retry-delay 5 "$1"
    fi \
        | grep '"tag_name":' | head -n 1 \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

latest_version=$(get_latest_tag "$MIHOMO_API")

if [ -z "$latest_version" ]; then
    echo "Error: Failed to fetch Mihomo version."
    exit 1
fi

echo "Latest Mihomo version: $latest_version"

download_url="${MIHOMO_BASE}/${latest_version}/${MIHOMO_NAME}-${latest_version}.gz"

echo "Downloading Mihomo core..."
if curl -fL --retry 5 --retry-delay 5 "$download_url" -o "$CORE_TMP"; then
    gunzip -c "$CORE_TMP" > "$CORE_DST"
    rm -f "$CORE_TMP"
    chmod +x "$CORE_DST"
else
    echo "Error: Mihomo download failed."
    exit 1
fi

easytier_version=$(get_latest_tag "$EASYTIER_API")

if [ -z "$easytier_version" ]; then
    echo "Error: Failed to fetch EasyTier version."
    exit 1
fi

echo "Latest EasyTier version: $easytier_version"
easytier_url="${EASYTIER_BASE}/${easytier_version}/Easytier-Magisk-${easytier_version}.zip"

echo "Downloading EasyTier core..."
if curl -fL --retry 5 --retry-delay 5 "$easytier_url" -o "$EASYTIER_TMP"; then
    if command -v unzip >/dev/null 2>&1; then
        easytier_entry=$(unzip -Z1 "$EASYTIER_TMP" | grep -E '(^|/)easytier-core$' | head -n 1)
        if [ -z "$easytier_entry" ]; then
            echo "Error: EasyTier core is missing from the release archive."
            rm -f "$EASYTIER_TMP"
            exit 1
        fi
        if ! unzip -p "$EASYTIER_TMP" "$easytier_entry" > "$EASYTIER_DST"; then
            echo "Error: Failed to extract EasyTier core."
            rm -f "$EASYTIER_TMP" "$EASYTIER_DST"
            exit 1
        fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$EASYTIER_TMP" "$EASYTIER_DST" <<'PY'
import sys
import zipfile

archive, destination = sys.argv[1:]
with zipfile.ZipFile(archive) as package:
    entry = next((name for name in package.namelist() if name.rstrip('/').endswith('/easytier-core') or name == 'easytier-core'), None)
    if entry is None:
        raise SystemExit('EasyTier core is missing from the release archive.')
    with package.open(entry) as source, open(destination, 'wb') as target:
        target.write(source.read())
PY
        if [ "$?" -ne 0 ]; then
            echo "Error: Failed to extract EasyTier core."
            rm -f "$EASYTIER_TMP" "$EASYTIER_DST"
            exit 1
        fi
    else
        echo "Error: Neither unzip nor python3 is available to extract EasyTier core."
        rm -f "$EASYTIER_TMP"
        exit 1
    fi
    rm -f "$EASYTIER_TMP"
    chmod +x "$EASYTIER_DST"
else
    echo "Error: EasyTier download failed."
    rm -f "$EASYTIER_TMP"
    exit 1
fi

zash_latest_version=$(get_latest_tag "$ZASH_API")
if [ -n "$zash_latest_version" ]; then
    echo "Latest Zashboard version: $zash_latest_version"
    zash_url="https://github.com/Zephyruso/zashboard/releases/download/${zash_latest_version}/dist.zip"
    echo "Downloading Zashboard..."
    if curl -fL --retry 5 --retry-delay 5 "$zash_url" -o "$ZASH_TMP"; then
        rm -rf dist Zash "$ZASH_DST"
        mkdir -p "$(dirname "$ZASH_DST")"
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$ZASH_TMP" -d "./zash_temp"
        elif command -v python3 >/dev/null 2>&1; then
            python3 - "$ZASH_TMP" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as package:
    package.extractall("./zash_temp")
PY
        else
            echo "Error: Neither unzip nor python3 is available to extract Zashboard."
            rm -f "$ZASH_TMP"
            exit 1
        fi
        if [ -d "./zash_temp/dist" ]; then
            mv "./zash_temp/dist" "$ZASH_DST"
            echo "Zashboard deployed to $ZASH_DST"
        else
            echo "Error: Unexpected ZIP structure in Zashboard."
        fi
        rm -rf zash_temp "$ZASH_TMP"
    else
        echo "Error: Zashboard download failed."
    fi
else
    echo "Error: Failed to fetch Zashboard version."
fi

APK_DIR="app/version/com.surfing.tile"
TILE_DST="SurfingTile/system/app/com.surfing.tile"
TILE_PROP="SurfingTile/module.prop"

mkdir -p "$TILE_DST"
latest_apk=$(find "$APK_DIR" -maxdepth 1 -name "SurfingTile_*_release.apk" 2>/dev/null | sort -V | tail -n 1)
if [ -f "$latest_apk" ]; then
    tile_version=$(basename "$latest_apk" | sed -E 's/^SurfingTile_(.*)_release\.apk$/\1/')
    cp -f "$latest_apk" "$TILE_DST/com.surfing.tile.apk"
    sed -i "s/^version=.*/version=v$tile_version/" "$TILE_PROP"
fi

version=$(grep '^version=' module.prop | tr -d '\r' | awk -F '=' '{print $2}' | sed 's/ (.*//')
short_hash=${SHORT_HASH:-$(git rev-parse --short=7 HEAD)}

if [ "$isAlpha" = "true" ]; then
    new_version="${version} (alpha-${short_hash})"
    filename="Surfing_alpha_${short_hash}.zip"
else
    new_version="${version} (release-${short_hash})"
    filename="Surfing_${version}_release.zip"
fi

sed -i "s/^version=.*/version=${new_version}/" module.prop

if command -v zip >/dev/null 2>&1; then
    (cd SurfingTile && zip -r -o -X ../SurfingTile.zip ./*)
    zip -r -o -X "$filename" ./ \
        -x 'SurfingTile/*' \
        -x 'app/*' \
        -x '.git/*' \
        -x '.github/*' \
        -x 'folder/*' \
        -x 'build.sh' \
        -x 'Surfing.json' \
        -x 'Surfing_*.zip' \
        -x '.mumu-*'
elif command -v python3 >/dev/null 2>&1; then
    python3 - "$filename" <<'PY'
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

def create_zip(filename, root, excluded):
    root = Path(root)
    with ZipFile(filename, "w", ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob("*")):
            rel = path.relative_to(root).as_posix()
            if any(rel == item or rel.startswith(item + "/") for item in excluded):
                continue
            if rel.startswith("Surfing_") and rel.endswith(".zip"):
                continue
            if rel.startswith(".mumu-"):
                continue
            if path.is_dir():
                continue
            info = ZipInfo.from_file(path, rel)
            info.compress_type = ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())

create_zip("SurfingTile.zip", "SurfingTile", [])
create_zip(sys.argv[1], ".", ["SurfingTile", "app", ".git", ".github", "folder", "build.sh", "Surfing.json"])
PY
else
    echo "Error: Neither zip nor python3 is available to create the release archive."
    exit 1
fi

echo "Build Completed: $filename"
