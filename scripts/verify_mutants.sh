#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "=========================================================="
echo " VFlow Clean-Room 3-Mutant Protocol Verification"
echo " Workspace: $WORKSPACE_ROOT"
echo " Developer Dir: $DEVELOPER_DIR"
echo "=========================================================="

# Backup originals in a temporary directory outside Sources
BACKUP_DIR=$(mktemp -d /tmp/vflow_backup.XXXXXX)
ENGINE_ORIG="$WORKSPACE_ROOT/Sources/VFlowCore/Engine/VietnameseInputEngine.swift"
CARETLOC_ORIG="$WORKSPACE_ROOT/Sources/VFlowPlatform/Accessibility/CaretLocator.swift"
POLISHER_ORIG="$WORKSPACE_ROOT/Sources/VFlowCore/Polish/VietnameseTextPolisher.swift"

cp "$ENGINE_ORIG" "$BACKUP_DIR/VietnameseInputEngine.swift"
cp "$CARETLOC_ORIG" "$BACKUP_DIR/CaretLocator.swift"
cp "$POLISHER_ORIG" "$BACKUP_DIR/VietnameseTextPolisher.swift"

cleanup() {
    echo "Restoring all original files..."
    if [ -f "$BACKUP_DIR/VietnameseInputEngine.swift" ]; then
        cp "$BACKUP_DIR/VietnameseInputEngine.swift" "$ENGINE_ORIG"
    fi
    if [ -f "$BACKUP_DIR/CaretLocator.swift" ]; then
        cp "$BACKUP_DIR/CaretLocator.swift" "$CARETLOC_ORIG"
    fi
    if [ -f "$BACKUP_DIR/VietnameseTextPolisher.swift" ]; then
        cp "$BACKUP_DIR/VietnameseTextPolisher.swift" "$POLISHER_ORIG"
    fi
    rm -rf "$BACKUP_DIR"
    # Clean up any stray .bak files in Sources/Tests if any existed
    find "$WORKSPACE_ROOT/Sources" "$WORKSPACE_ROOT/Tests" -name "*.bak" -delete 2>/dev/null || true
}
trap cleanup EXIT

# 1. Clean Main Build Verification
echo ""
echo "[Step 1/5] Testing Clean Main Codebase (Must PASS 100%)..."
swift test --package-path "$WORKSPACE_ROOT" > /tmp/main_test.log 2>&1
MAIN_CODE=$?
if [ $MAIN_CODE -eq 0 ]; then
    echo "✅ Clean Main: 100% PASS"
else
    echo "❌ Clean Main: FAILED (Exit code $MAIN_CODE)"
    cat /tmp/main_test.log
    exit 1
fi

# 2. Mutant 1: Sabotaged Tone Removal ('z' / '0')
echo ""
echo "[Step 2/5] Testing Mutant 1 (Tone Removal Sabotage - Must FAIL)..."
cp "$WORKSPACE_ROOT/clean-room/mutants/mutant-1/VietnameseInputEngine.swift" "$ENGINE_ORIG"
set +e
swift test --package-path "$WORKSPACE_ROOT" > /tmp/mutant1_test.log 2>&1
M1_CODE=$?
set -e
cp "$BACKUP_DIR/VietnameseInputEngine.swift" "$ENGINE_ORIG"

if [ $M1_CODE -ne 0 ]; then
    echo "✅ Mutant 1 KILLED! (Tests correctly detected mutant failure, exit code $M1_CODE)"
    grep -E "Test Case .* failed" /tmp/mutant1_test.log || true
else
    echo "❌ Mutant 1 SURVIVED! (Tests unexpectedly passed)"
    exit 1
fi

# 3. Mutant 2: Sabotaged Auto-English Restore
echo ""
echo "[Step 3/5] Testing Mutant 2 (Auto-English Restore Bypassed - Must FAIL)..."
cp "$WORKSPACE_ROOT/clean-room/mutants/mutant-2/VietnameseInputEngine.swift" "$ENGINE_ORIG"
set +e
swift test --package-path "$WORKSPACE_ROOT" > /tmp/mutant2_test.log 2>&1
M2_CODE=$?
set -e
cp "$BACKUP_DIR/VietnameseInputEngine.swift" "$ENGINE_ORIG"

if [ $M2_CODE -ne 0 ]; then
    echo "✅ Mutant 2 KILLED! (Tests correctly detected mutant failure, exit code $M2_CODE)"
    grep -E "Test Case .* failed" /tmp/mutant2_test.log || true
else
    echo "❌ Mutant 2 SURVIVED! (Tests unexpectedly passed)"
    exit 1
fi

# 4. Mutant 3: Sabotaged CaretLocator Flip Logic
echo ""
echo "[Step 4/5] Testing Mutant 3 (CaretLocator Screen Flip Sabotaged - Must FAIL)..."
cp "$WORKSPACE_ROOT/clean-room/mutants/mutant-3/CaretLocator.swift" "$CARETLOC_ORIG"
set +e
swift test --package-path "$WORKSPACE_ROOT" > /tmp/mutant3_test.log 2>&1
M3_CODE=$?
set -e
cp "$BACKUP_DIR/CaretLocator.swift" "$CARETLOC_ORIG"

if [ $M3_CODE -ne 0 ]; then
    echo "✅ Mutant 3 KILLED! (Tests correctly detected mutant failure, exit code $M3_CODE)"
    grep -E "Test Case .* failed" /tmp/mutant3_test.log || true
else
    echo "❌ Mutant 3 SURVIVED! (Tests unexpectedly passed)"
    exit 1
fi

# 5. Final Clean Main Verification
echo ""
echo "[Step 5/5] Re-verifying Clean Main Codebase (Must PASS 100%)..."
swift test --package-path "$WORKSPACE_ROOT" > /tmp/final_main_test.log 2>&1
FINAL_CODE=$?
if [ $FINAL_CODE -eq 0 ]; then
    echo "✅ Final Clean Main: 100% PASS"
else
    echo "❌ Final Clean Main: FAILED (Exit code $FINAL_CODE)"
    cat /tmp/final_main_test.log
    exit 1
fi

echo ""
echo "=========================================================="
echo " 🎉 ALL MUTATION TESTS COMPLETED SUCCESSFULLY!"
echo " Primary Build: 100% PASS"
echo " Mutant 1 (Telex/VNI 'z'/'0'): KILLED"
echo " Mutant 2 (Auto-English Restore): KILLED"
echo " Mutant 3 (CaretLocator Flip Logic): KILLED"
echo "=========================================================="
