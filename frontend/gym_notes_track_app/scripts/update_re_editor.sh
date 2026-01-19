#!/bin/bash
# Script to update re_editor package with cursor handle patch
# Run from the project root: ./scripts/update_re_editor.sh
# Works on macOS and Linux

set -e

VERSION="${1:-0.8.0}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$PROJECT_ROOT/packages"
RE_EDITOR_DEST="$PACKAGES_DIR/re_editor"

# Function to find pub cache
find_pub_cache() {
    local package_name="$1"
    local package_version="$2"
    local search_paths=()
    
    # Check PUB_CACHE environment variable
    if [[ -n "$PUB_CACHE" && -d "$PUB_CACHE" ]]; then
        search_paths+=("$PUB_CACHE/hosted/pub.dev")
    fi
    
    # Default pub cache location (~/.pub-cache)
    if [[ -d "$HOME/.pub-cache" ]]; then
        search_paths+=("$HOME/.pub-cache/hosted/pub.dev")
    fi
    
    # Flutter SDK bundled cache
    if command -v flutter &> /dev/null; then
        local flutter_path
        flutter_path="$(which flutter)"
        local flutter_root
        flutter_root="$(dirname "$(dirname "$flutter_path")")"
        if [[ -d "$flutter_root/.pub-cache" ]]; then
            search_paths+=("$flutter_root/.pub-cache/hosted/pub.dev")
        fi
    fi
    
    # Search for the package
    for base_path in "${search_paths[@]}"; do
        local full_path="$base_path/$package_name-$package_version"
        if [[ -d "$full_path" ]]; then
            echo "$full_path"
            return 0
        fi
    done
    
    return 1
}

echo -e "\033[36mLooking for re_editor v$VERSION in pub cache...\033[0m"

PUB_CACHE_PATH=$(find_pub_cache "re_editor" "$VERSION") || {
    echo -e "\033[31mError: re_editor v$VERSION not found in pub cache. Run 'flutter pub get' first.\033[0m"
    exit 1
}

echo -e "\033[36mUpdating re_editor from: $PUB_CACHE_PATH\033[0m"

# Remove existing
if [[ -d "$RE_EDITOR_DEST" ]]; then
    echo -e "\033[33mRemoving existing re_editor...\033[0m"
    rm -rf "$RE_EDITOR_DEST"
fi

# Create packages directory if needed
mkdir -p "$PACKAGES_DIR"

# Copy fresh version
echo -e "\033[33mCopying re_editor v$VERSION...\033[0m"
cp -R "$PUB_CACHE_PATH" "$RE_EDITOR_DEST"

# Remove unnecessary folders
echo -e "\033[33mCleaning up unnecessary files...\033[0m"
for folder in example test arts .dart_tool; do
    if [[ -d "$RE_EDITOR_DEST/$folder" ]]; then
        rm -rf "$RE_EDITOR_DEST/$folder"
        echo -e "\033[90m  Removed: $folder\033[0m"
    fi
done

# Apply the cursor handle patch
echo -e "\033[33mApplying cursor handle patch...\033[0m"
SELECTION_FILE="$RE_EDITOR_DEST/lib/src/_code_selection.dart"

if [[ ! -f "$SELECTION_FILE" ]]; then
    echo -e "\033[31mError: Could not find _code_selection.dart\033[0m"
    exit 1
fi

# Check if already patched
if grep -q "showHandle(context);" "$SELECTION_FILE" && grep -q "_selectPosition(position, _SelectionChangedCause.tapUp);" "$SELECTION_FILE"; then
    # Check if it's our specific patch location (in the else branch after _selectPosition)
    if grep -A2 "_selectPosition(position, _SelectionChangedCause.tapUp);" "$SELECTION_FILE" | grep -q "showHandle(context);"; then
        echo -e "\033[32m  Patch already applied.\033[0m"
    else
        # Apply patch: replace hideHandle() with showHandle(context) after _selectPosition in _onMobileTapUp
        sed -i.bak 's/widget\.selectionOverlayController\.hideHandle();/widget.selectionOverlayController.showHandle(context);/' "$SELECTION_FILE"
        rm -f "$SELECTION_FILE.bak"
        echo -e "\033[32m  Patch applied successfully!\033[0m"
    fi
elif grep -q "hideHandle();" "$SELECTION_FILE"; then
    # Apply patch: replace hideHandle() with showHandle(context)
    sed -i.bak 's/widget\.selectionOverlayController\.hideHandle();/widget.selectionOverlayController.showHandle(context);/' "$SELECTION_FILE"
    rm -f "$SELECTION_FILE.bak"
    echo -e "\033[32m  Patch applied successfully!\033[0m"
else
    echo -e "\033[33mWarning: Could not find the code to patch. The re_editor version may have changed.\033[0m"
fi

echo -e "\n\033[36mDone! Run 'flutter pub get' to apply changes.\033[0m"
