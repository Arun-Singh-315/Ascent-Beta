#!/usr/bin/env bash
# ==============================================================================
# Ascent Test Pipeline & Quality Gate Runner
# Usage:
#   ./scripts/test_pipeline.sh smoke            - Fast sanity suite (<15s)
#   ./scripts/test_pipeline.sh integrity        - UI overflow & completeness tests
#   ./scripts/test_pipeline.sh feature <name>   - Tests for specific domain
#   ./scripts/test_pipeline.sh gate             - Pre-merge gate (analyze + smoke + integrity)
#   ./scripts/test_pipeline.sh all              - Complete test suite
# ==============================================================================

set -e

MODE="${1:-all}"
FEATURE_TARGET="$2"

echo "=========================================================="
echo " Ascent CI/CD Quality Pipeline: mode [$MODE]"
echo "=========================================================="

case "$MODE" in
  smoke)
    echo "Running smoke tests (Target <15s)..."
    flutter test test/smoke/app_smoke_test.dart test/widget_test.dart
    ;;

  integrity|ui)
    echo "Running UI integrity, accessibility, and 320px overflow guard tests..."
    flutter test \
      test/home_day_layout_test.dart \
      test/ui_integrity/interactive_completeness_test.dart \
      test/mindspace_accessible_layout_test.dart \
      test/day_surface_screen_audit_test.dart \
      test/home_card_border_theme_test.dart \
      test/planning_accessibility_test.dart \
      test/plan_collection_service_test.dart \
      test/planning_migration_test.dart
    ;;

  feature)
    if [ -z "$FEATURE_TARGET" ]; then
      echo "Error: Please specify a feature target. Examples:"
      echo "  ./scripts/test_pipeline.sh feature home"
      echo "  ./scripts/test_pipeline.sh feature plan"
      echo "  ./scripts/test_pipeline.sh feature reminder"
      echo "  ./scripts/test_pipeline.sh feature learning"
      echo "  ./scripts/test_pipeline.sh feature chai"
      echo "  ./scripts/test_pipeline.sh feature medicine"
      echo "  ./scripts/test_pipeline.sh feature momentum"
      exit 1
    fi

    echo "Running targeted tests for feature [$FEATURE_TARGET]..."
    MATCHING_TESTS=$(find test -name "*${FEATURE_TARGET}*.dart")
    if [ -z "$MATCHING_TESTS" ]; then
      echo "No test files matched pattern '*${FEATURE_TARGET}*.dart'"
      exit 1
    fi
    echo "Matched test files:"
    echo "$MATCHING_TESTS"
    flutter test $MATCHING_TESTS
    ;;

  gate|pre-merge)
    echo "==> Step 1/3: Running Flutter static analysis..."
    flutter analyze

    echo "==> Step 2/3: Running fast smoke tests..."
    flutter test test/smoke/app_smoke_test.dart test/widget_test.dart

    echo "==> Step 3/3: Running UI layout & overflow integrity tests..."
    flutter test \
      test/home_day_layout_test.dart \
      test/ui_integrity/interactive_completeness_test.dart \
      test/mindspace_accessible_layout_test.dart \
      test/planning_accessibility_test.dart \
      test/plan_collection_service_test.dart \
      test/planning_migration_test.dart
    echo "=========================================================="
    echo " SUCCESS: Pre-merge quality gate passed cleanly!"
    echo "=========================================================="
    ;;

  all)
    echo "Running complete test suite..."
    flutter test
    ;;

  *)
    echo "Unknown mode: $MODE"
    echo "Available commands: smoke | integrity | feature <name> | gate | all"
    exit 1
    ;;
esac

echo "=========================================================="
echo " Pipeline execution completed successfully."
echo "=========================================================="
