#!/usr/bin/env bash

# Test script to validate all download URLs in config/apps.json
# Tests AppImages, .deb files, tarballs, and other download sources
# Usage: ./test-links.sh [--quick]
#   --quick: Only validate URL format, don't test connectivity

set -euo pipefail

# Quick mode (no actual HTTP requests)
QUICK_MODE=false
if [[ "${1:-}" == "--quick" ]]; then
    QUICK_MODE=true
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source "${SCRIPT_DIR}/core/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/version.sh"

# Test results
declare -A RESULTS
TOTAL_TESTED=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Colors for output
TEST_PASS="${GREEN}✔${RESET}"
TEST_FAIL="${RED}✘${RESET}"
TEST_SKIP="${GREENDULL}⊘${RESET}"

# Test a single URL
# Returns: 0 if valid, 1 if invalid
test_url() {
    local url="${1:-}"
    local timeout="${2:-10}"

    if [[ -z "$url" ]]; then
        return 1
    fi

    # Skip non-HTTP URLs (like apt:package_name)
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 2  # Skip
    fi

    # Test URL with HEAD request (faster than GET)
    local http_code
    http_code=$(curl -sI -L --max-time "$timeout" -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")

    # 2xx or 3xx are considered valid
    if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Test a single app
test_app() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local install_method="${3:-}"

    ((TOTAL_TESTED++))

    printf "  Testing %s (%s)... " "${app_name}" "${install_method}"

    # Resolve version and get download URL
    local version_info
    version_info=$(resolve_version "$app_id" 2>&1)

    if [[ -z "$version_info" ]] || [[ "$version_info" == "null" ]]; then
        echo "${TEST_FAIL} Failed to resolve version"
        RESULTS["$app_id"]="FAIL: Version resolution failed"
        ((TOTAL_FAILED++))
        return 1
    fi

    # Check for errors in JSON
    local error
    error=$(echo "$version_info" | jq -r '.error // empty')

    if [[ -n "$error" ]]; then
        echo "${TEST_FAIL} Error: ${error}"
        RESULTS["$app_id"]="FAIL: ${error}"
        ((TOTAL_FAILED++))
        return 1
    fi

    local version
    version=$(echo "$version_info" | jq -r '.version // "unknown"')

    local download_url
    download_url=$(echo "$version_info" | jq -r '.download_url // empty')

    if [[ -z "$download_url" ]]; then
        echo "${TEST_FAIL} No download URL"
        RESULTS["$app_id"]="FAIL: No download URL"
        ((TOTAL_FAILED++))
        return 1
    fi

    # Test the URL
    if [[ "$QUICK_MODE" == true ]]; then
        # Quick mode - just validate URL format
        if [[ "$download_url" =~ ^https?:// ]]; then
            echo "${TEST_PASS} v${version} - URL format valid"
            RESULTS["$app_id"]="PASS: v${version} (format only)"
            ((TOTAL_PASSED++))
            return 0
        elif [[ "$download_url" =~ ^apt: ]]; then
            echo "${TEST_SKIP} Skipped (APT package)"
            RESULTS["$app_id"]="SKIP: APT package"
            ((TOTAL_SKIPPED++))
            return 0
        else
            echo "${TEST_FAIL} Invalid URL format: ${download_url}"
            RESULTS["$app_id"]="FAIL: Invalid URL format"
            ((TOTAL_FAILED++))
            return 1
        fi
    else
        # Full mode - test connectivity
        if test_url "$download_url" 15; then
            echo "${TEST_PASS} v${version} - URL valid"
            RESULTS["$app_id"]="PASS: v${version}"
            ((TOTAL_PASSED++))
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                echo "${TEST_SKIP} Skipped (non-HTTP: ${download_url})"
                RESULTS["$app_id"]="SKIP: ${download_url}"
                ((TOTAL_SKIPPED++))
                return 0
            else
                echo "${TEST_FAIL} URL unreachable: ${download_url}"
                RESULTS["$app_id"]="FAIL: URL unreachable - ${download_url}"
                ((TOTAL_FAILED++))
                return 1
            fi
        fi
    fi
}

# Main test function
main() {
    echo
    print_message INFOFULL "DEBAPPS Download Link Validator"
    if [[ "$QUICK_MODE" == true ]]; then
        print_message INFO "Running in QUICK mode (format validation only)"
    else
        print_message INFO "Running in FULL mode (testing connectivity - may take a while)"
    fi
    echo
    print_message INFO "Loading configuration..."

    # Load config
    if ! load_config "config/apps.json" >/dev/null 2>&1; then
        print_message FAIL "Failed to load configuration"
        exit 1
    fi

    print_message PASS "Configuration loaded"
    echo

    # Get all categories
    local categories
    categories=$(echo "$CONFIG_JSON" | jq -r '.categories[] | .id')

    # Test each category
    while IFS= read -r category_id; do
        local category_name
        category_name=$(echo "$CONFIG_JSON" | jq -r ".categories[] | select(.id==\"$category_id\") | .name")

        print_message INFOFULL "Category: ${category_name}"

        # Get apps in category
        local apps
        apps=$(echo "$CONFIG_JSON" | jq -r ".categories[] | select(.id==\"$category_id\") | .apps[] | @json")

        # Test each app
        if [[ -z "$apps" ]]; then
            echo "  No apps found in this category"
            continue
        fi

        while IFS= read -r app_json; do
            # Skip empty lines
            [[ -z "$app_json" ]] && continue

            local app_id
            app_id=$(echo "$app_json" | jq -r '.id')

            local app_name
            app_name=$(echo "$app_json" | jq -r '.name')

            local install_method
            install_method=$(echo "$app_json" | jq -r '.install_method')

            test_app "$app_id" "$app_name" "$install_method" || true
        done <<< "$apps"

        echo
    done <<< "$categories"

    # Print summary
    print_message INFOFULL "Test Summary"
    echo
    echo "  Total Apps Tested: ${TOTAL_TESTED}"
    echo "  ${TEST_PASS} Passed: ${TOTAL_PASSED}"
    echo "  ${TEST_FAIL} Failed: ${TOTAL_FAILED}"
    echo "  ${TEST_SKIP} Skipped: ${TOTAL_SKIPPED}"
    echo

    # Print failed tests
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        print_message WARN "Failed Tests:"
        echo
        for app_id in "${!RESULTS[@]}"; do
            if [[ "${RESULTS[$app_id]}" == FAIL:* ]]; then
                local app_name
                app_name=$(get_app_name "$app_id")
                echo "  ${TEST_FAIL} ${app_name}: ${RESULTS[$app_id]#FAIL: }"
            fi
        done
        echo
        exit 1
    else
        print_message PASS "All download links are valid!"
        echo
        exit 0
    fi
}

# Run tests
main "$@"
