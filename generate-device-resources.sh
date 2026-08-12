#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ASSETS_DIR="$SCRIPT_DIR/assets"
BASE_RES="$SCRIPT_DIR/resources/drawables/drawables.xml"

declare -a LINK_NAMES=(
  "launcher_icon.png"
)

declare -A LINK_TO_ASSET_BASE=(
  ["launcher_icon.png"]="launcher_icon"
)

# launcher_icon (first dimension) derived from:
# Garmin/ConnectIQ/Devices/<device>/compiler.json launcherIcon
read -r -d '' INPUT_DATA << EOM
edge530 35x35
edge540 35x35
edge550 56x56
edge830 35x35
edge840 35x35
edge850 56x56
edge1030 36x36
edge1030plus 36x36
edge1040 40x40
edge1050 68x68
edgeexplore2 36x36
edgemtb 36x36
EOM

generate_image()
{
  local input="$1"
  local size="$2"
  local basename="${input%.*}"
  local output="${ASSETS_DIR}/${basename}-${size}.png"

  if [[ ! -f "$ASSETS_DIR/$input" ]]; then
    echo "  Error: Source file '$ASSETS_DIR/$input' not found" >&2
    return 1
  fi

  echo "  Generating $output"

  convert "$ASSETS_DIR/$input" -background none \
    -brightness-contrast 15x25 \
    -resize "$size" -gravity center -extent "$size" \
    -strip "$output"
}

while read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  read -ra parts <<< "$line"
  device="${parts[0]}"
  sizes=("${parts[@]:1}")

  device_dir="$SCRIPT_DIR/resources-$device/drawables"
  rm -r "$device_dir"
  mkdir -p "$device_dir"
  cp "$BASE_RES" "$device_dir/drawables.xml"

  echo "Processing device: $device"

  for i in "${!sizes[@]}"; do
    size="${sizes[$i]}"
    echo "  Handling size $i: $size"

    if [[ -n "${LINK_NAMES[$i]}" ]]; then
      for link_name in ${LINK_NAMES[$i]}; do
        asset_base="${LINK_TO_ASSET_BASE[$link_name]}"
        asset_input="${asset_base}.png"
        asset_file="$ASSETS_DIR/${asset_base}-${size}.png"
        target_link="$device_dir/$link_name"

        generate_image "$asset_input" "$size"

        if [[ -f "$asset_file" ]]; then
          relative_path=$(realpath --relative-to="$device_dir" "$asset_file")
          ln -sf "$relative_path" "$target_link"
          echo "    Linked $target_link -> $relative_path"
        else
          echo "    Warning: Missing asset: $asset_file"
        fi
      done
    else
      echo "    Warning: No link names defined for position $i"
    fi
  done

done <<< "$INPUT_DATA"
