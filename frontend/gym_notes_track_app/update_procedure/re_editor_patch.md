# re_editor Patch Documentation

## Problem

The `re_editor` package (v0.8.0) intentionally **hides the cursor handle on single tap** on mobile devices. This is different from standard mobile text editor behavior where:

- **Single tap** → Places cursor AND shows the draggable cursor handle
- **Double tap** → Selects word and shows selection handles
- **Long press** → Selects word and shows selection handles + toolbar

In re_editor's default behavior:
- **Single tap** → Places cursor but **hides** the handle ❌
- **Double tap** → Shows handles ✓
- **Long press** → Shows handles ✓

This makes it impossible to reposition the cursor by dragging after a single tap.

## Solution

We patch one line in `lib/src/_code_selection.dart` in the `_onMobileTapUp` method.

### File: `lib/src/_code_selection.dart`

### Location: `_onMobileTapUp` method (around line 178-193)

### Original Code:
```dart
void _onMobileTapUp(Offset position) {
  final DateTime now = DateTime.now();
  if (_pointerTapTimestamp != null && ...) {
    // Double tap - shows handle
    _onDoubleTap(position);
    widget.selectionOverlayController.showHandle(context);
    widget.selectionOverlayController.showToolbar(context, position);
  } else {
    // Single tap - HIDES handle (the problem)
    _pointerTapTimestamp = now;
    _pointerTapPosition = position;
    _selectPosition(position, _SelectionChangedCause.tapUp);
    widget.selectionOverlayController.hideHandle();  // ← PROBLEM
    widget.selectionOverlayController.hideToolbar();
  }
  widget.inputController.ensureInput();
}
```

### Patched Code:
```dart
void _onMobileTapUp(Offset position) {
  final DateTime now = DateTime.now();
  if (_pointerTapTimestamp != null && ...) {
    // Double tap - shows handle
    _onDoubleTap(position);
    widget.selectionOverlayController.showHandle(context);
    widget.selectionOverlayController.showToolbar(context, position);
  } else {
    // Single tap - NOW SHOWS handle (the fix)
    _pointerTapTimestamp = now;
    _pointerTapPosition = position;
    _selectPosition(position, _SelectionChangedCause.tapUp);
    widget.selectionOverlayController.showHandle(context);  // ← FIXED
    widget.selectionOverlayController.hideToolbar();
  }
  widget.inputController.ensureInput();
}
```

### Change Summary:
```diff
- widget.selectionOverlayController.hideHandle();
+ widget.selectionOverlayController.showHandle(context);
```

## How to Apply

### Automatic (Recommended)

Run the update script from the project root:

**Windows (PowerShell):**

If you get an execution policy error, use one of these options:

Option 1 - Bypass for this script only (recommended):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update_re_editor.ps1
flutter pub get
```

Option 2 - Enable scripts for current user (one-time setup):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\update_re_editor.ps1
flutter pub get
```

**macOS/Linux (Bash):**
```bash
chmod +x scripts/update_re_editor.sh
./scripts/update_re_editor.sh
flutter pub get
```

### Manual

1. Copy `re_editor` from pub cache to `packages/re_editor`
2. Delete `example`, `test`, `arts`, `.dart_tool` folders
3. Edit `lib/src/_code_selection.dart` line ~189
4. Change `hideHandle()` to `showHandle(context)`
5. Run `flutter pub get`

## Configuration

The patched package is used via `dependency_overrides` in `pubspec.yaml`:

```yaml
dependency_overrides:
  re_editor:
    path: packages/re_editor
```

## When to Re-apply

Re-run the update script when:
- Upgrading to a new version of `re_editor`
- After accidentally reverting the `packages/re_editor` folder
- If the patch gets lost for any reason

Update the version parameter if upgrading:
```powershell
.\scripts\update_re_editor.ps1 -Version "0.9.0"
```
