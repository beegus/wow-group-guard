#!/usr/bin/env bash
set -euo pipefail

addon_name=GroupGuard
toc_file="${addon_name}.toc"

if [[ ! -f .pkgmeta ]] || ! grep -Fxq "package-as: $addon_name" .pkgmeta; then
    echo "Expected .pkgmeta to set package-as: $addon_name." >&2
    exit 1
fi

if [[ ! -f "$toc_file" ]]; then
    echo "Missing TOC file: $toc_file" >&2
    exit 1
fi

toc_contents="$(sed 's/\r$//' "$toc_file")"
grep -Eq '^## Interface: [0-9]+(, [0-9]+)*$' <<< "$toc_contents"
grep -Eq '^## Title: .+$' <<< "$toc_contents"
grep -Eq '^## Version: [0-9]+(\.[0-9]+){2}$' <<< "$toc_contents"

mapfile -t lua_files < <(printf '%s\n' "$toc_contents" | sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /\.lua$/p')
if (( ${#lua_files[@]} == 0 )); then
    echo 'TOC does not reference any Lua files.' >&2
    exit 1
fi

for lua_file in "${lua_files[@]}"; do
    if [[ ! -f "$lua_file" ]]; then
        echo "TOC references missing file: $lua_file" >&2
        exit 1
    fi
done

echo 'TOC validation passed.'