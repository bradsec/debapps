#!/usr/bin/env bash

# Configuration management for DEBAPPS
# Handles JSON parsing and app configuration queries
# Requires: core/common.sh, jq

set -euo pipefail

# Global variable to store loaded config
CONFIG_JSON=""

# Load and validate JSON configuration
# Usage: load_config "/path/to/apps.json"
load_config() {
    local config_file="${1:-}"

    if [[ -z "$config_file" ]]; then
        print_message FAIL "load_config requires a config file path"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        print_message FAIL "Config file not found: ${config_file}"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        print_message FAIL "jq is required but not installed. Installing..."
        pkgmgr install jq || {
            print_message FAIL "Failed to install jq"
            return 1
        }
    fi

    # Load and validate JSON
    print_message INFO "Loading configuration from: ${config_file}"

    CONFIG_JSON=$(cat "$config_file")

    # Validate JSON syntax
    if ! echo "$CONFIG_JSON" | jq empty &>/dev/null; then
        print_message FAIL "Invalid JSON in config file: ${config_file}"
        return 1
    fi

    # Validate schema version
    local schema_version
    schema_version=$(echo "$CONFIG_JSON" | jq -r '.schema_version // "unknown"')

    if [[ "$schema_version" != "2.0" ]]; then
        print_message WARN "Config schema version is ${schema_version}, expected 2.0"
    fi

    # Count apps
    local total_apps
    total_apps=$(echo "$CONFIG_JSON" | jq '[.categories[].apps[]] | length')

    print_message PASS "Configuration loaded successfully: ${total_apps} applications"
}

# Get all categories
# Usage: get_categories
# Output format: "id:name:description" (one per line)
get_categories() {
    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    echo "$CONFIG_JSON" | jq -r '.categories[] | "\(.id):\(.name):\(.description // "")"'
}

# Get apps by category ID
# Usage: get_apps_by_category "category_id"
# Output format: "app_id:app_name:description" (one per line)
get_apps_by_category() {
    local category_id="${1:-}"

    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    if [[ -z "$category_id" ]]; then
        print_message FAIL "get_apps_by_category requires a category_id"
        return 1
    fi

    echo "$CONFIG_JSON" | jq -r \
        ".categories[] | select(.id==\"${category_id}\") | .apps[] | \"\(.id):\(.name):\(.description)\""
}

# Get single app configuration as JSON
# Usage: get_app_config "app_id"
# Output: JSON object with app configuration
get_app_config() {
    local app_id="${1:-}"

    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    if [[ -z "$app_id" ]]; then
        print_message FAIL "get_app_config requires an app_id"
        return 1
    fi

    local config
    config=$(echo "$CONFIG_JSON" | jq ".categories[].apps[] | select(.id==\"${app_id}\")")

    if [[ -z "$config" ]] || [[ "$config" == "null" ]]; then
        print_message FAIL "App not found: ${app_id}"
        return 1
    fi

    echo "$config"
}

# Get category name by ID
# Usage: get_category_name "category_id"
get_category_name() {
    local category_id="${1:-}"

    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    if [[ -z "$category_id" ]]; then
        print_message FAIL "get_category_name requires a category_id"
        return 1
    fi

    echo "$CONFIG_JSON" | jq -r ".categories[] | select(.id==\"${category_id}\") | .name"
}

# Validate app configuration
# Usage: validate_app_config "app_id"
validate_app_config() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "validate_app_config requires an app_id"
        return 1
    fi

    local config
    config=$(get_app_config "$app_id") || return 1

    # Check required fields
    local required_fields=("name" "install_method" "source" "detection")

    for field in "${required_fields[@]}"; do
        local value
        value=$(echo "$config" | jq -r ".${field} // empty")

        if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
            print_message FAIL "App ${app_id} missing required field: ${field}"
            return 1
        fi
    done

    print_message PASS "App ${app_id} configuration is valid"
    return 0
}

# Get all app IDs
# Usage: get_all_apps
# Output: List of app IDs (one per line)
get_all_apps() {
    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    echo "$CONFIG_JSON" | jq -r '.categories[].apps[] | .id'
}

# Get app install method
# Usage: get_app_install_method "app_id"
get_app_install_method() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "get_app_install_method requires an app_id"
        return 1
    fi

    local config
    config=$(get_app_config "$app_id") || return 1

    echo "$config" | jq -r '.install_method'
}

# Get app name
# Usage: get_app_name "app_id"
get_app_name() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "get_app_name requires an app_id"
        return 1
    fi

    local config
    config=$(get_app_config "$app_id") || return 1

    echo "$config" | jq -r '.name'
}

# Get app description
# Usage: get_app_description "app_id"
get_app_description() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "get_app_description requires an app_id"
        return 1
    fi

    local config
    config=$(get_app_config "$app_id") || return 1

    echo "$config" | jq -r '.description // ""'
}

# Search apps by keyword
# Usage: search_apps "keyword"
# Output: "app_id:app_name:description" (one per line)
search_apps() {
    local keyword="${1:-}"

    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded. Call load_config first."
        return 1
    fi

    if [[ -z "$keyword" ]]; then
        print_message FAIL "search_apps requires a keyword"
        return 1
    fi

    echo "$CONFIG_JSON" | jq -r \
        ".categories[].apps[] | select(.name | ascii_downcase | contains(\"${keyword,,}\")) | \"\(.id):\(.name):\(.description)\""
}
