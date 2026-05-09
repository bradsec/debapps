#!/usr/bin/env bash

# Manifest-driven app install/remove helpers.
# Requires: generic.tmpl.sh, debian.tmpl.sh, and appimage.tmpl.sh as needed.

TEMPLATE_NAME="templates/apps.tmpl.sh"

declare -gA APP_NAME=()
declare -gA APP_TYPE=()
declare -gA APP_PACKAGE=()
declare -gA APP_RESOLVER=()
declare -gA APP_INSTALL_DIR=()
declare -gA APP_SAVE_EXT=()
declare -gA APP_FIX_BROKEN=()
declare -gA APP_KEY_URL=()
declare -gA APP_KEYRING_PATH=()
declare -gA APP_KEY_FINGERPRINT=()
declare -gA APP_SOURCE_URL=()
declare -gA APP_SOURCE_PATH=()
declare -gA APP_SOURCE_RESOLVER=()
declare -gA APP_REMOVE_FILES=()
declare -gA APP_PIN_PATH=()
declare -gA APP_PIN_RESOLVER=()

function register_app() {
    local app_id=""
    local app_name=""
    local app_type=""
    local app_package=""
    local app_resolver=""
    local app_install_dir=""
    local app_save_ext=""
    local app_fix_broken="false"
    local app_key_url=""
    local app_keyring_path=""
    local app_key_fingerprint=""
    local app_source_url=""
    local app_source_path=""
    local app_source_resolver=""
    local app_remove_files=""
    local app_pin_path=""
    local app_pin_resolver=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                app_id="$2"
                shift 2
                ;;
            --name)
                app_name="$2"
                shift 2
                ;;
            --type)
                app_type="$2"
                shift 2
                ;;
            --package)
                app_package="$2"
                shift 2
                ;;
            --resolver)
                app_resolver="$2"
                shift 2
                ;;
            --install-dir)
                app_install_dir="$2"
                shift 2
                ;;
            --save-ext)
                app_save_ext="$2"
                shift 2
                ;;
            --fix-broken)
                app_fix_broken="$2"
                shift 2
                ;;
            --key-url)
                app_key_url="$2"
                shift 2
                ;;
            --keyring-path)
                app_keyring_path="$2"
                shift 2
                ;;
            --key-fingerprint)
                app_key_fingerprint="$2"
                shift 2
                ;;
            --source-url)
                app_source_url="$2"
                shift 2
                ;;
            --source-path)
                app_source_path="$2"
                shift 2
                ;;
            --source-resolver)
                app_source_resolver="$2"
                shift 2
                ;;
            --remove-file)
                app_remove_files="${app_remove_files} $2"
                shift 2
                ;;
            --pin-path)
                app_pin_path="$2"
                shift 2
                ;;
            --pin-resolver)
                app_pin_resolver="$2"
                shift 2
                ;;
            *)
                print_message FAIL "Unknown register_app option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "${app_id}" || -z "${app_name}" || -z "${app_type}" ]]; then
        print_message FAIL "App manifest entry is missing id, name, or type."
        return 1
    fi

    APP_NAME["${app_id}"]="${app_name}"
    APP_TYPE["${app_id}"]="${app_type}"
    APP_PACKAGE["${app_id}"]="${app_package:-${app_id}}"
    APP_RESOLVER["${app_id}"]="${app_resolver}"
    APP_INSTALL_DIR["${app_id}"]="${app_install_dir:-/opt/${app_id}}"
    APP_SAVE_EXT["${app_id}"]="${app_save_ext}"
    APP_FIX_BROKEN["${app_id}"]="${app_fix_broken}"
    APP_KEY_URL["${app_id}"]="${app_key_url}"
    APP_KEYRING_PATH["${app_id}"]="${app_keyring_path}"
    APP_KEY_FINGERPRINT["${app_id}"]="${app_key_fingerprint}"
    APP_SOURCE_URL["${app_id}"]="${app_source_url}"
    APP_SOURCE_PATH["${app_id}"]="${app_source_path}"
    APP_SOURCE_RESOLVER["${app_id}"]="${app_source_resolver}"
    APP_REMOVE_FILES["${app_id}"]="${app_remove_files# }"
    APP_PIN_PATH["${app_id}"]="${app_pin_path}"
    APP_PIN_RESOLVER["${app_id}"]="${app_pin_resolver}"
}

function app_manifest_has() {
    local app_id="$1"
    [[ -n "${APP_NAME[${app_id}]+set}" ]]
}

function app_manifest_require() {
    local app_id="$1"
    if ! app_manifest_has "${app_id}"; then
        print_message FAIL "Unknown app manifest id: ${app_id}"
        return 1
    fi
}

function resolve_app_download_url() {
    local app_id="$1"
    local resolver="${APP_RESOLVER[${app_id}]}"

    if [[ -z "${resolver}" ]]; then
        print_message FAIL "No download resolver defined for ${APP_NAME[${app_id}]}."
        return 1
    fi

    if ! declare -F "${resolver}" >/dev/null 2>&1; then
        print_message FAIL "Download resolver does not exist: ${resolver}"
        return 1
    fi

    "${resolver}"
}

function debapps_config_file() {
    local user_name
    local user_home

    user_name=$(get_user)
    user_home=$(getent passwd "${user_name}" | cut -d: -f6)
    if [[ -z "${user_home}" ]]; then
        user_home="${HOME:-/root}"
    fi

    echo "${user_home}/.debapps_config"
}

function debapps_config_owner() {
    local user_name

    user_name=$(get_user)
    if id "${user_name}" >/dev/null 2>&1; then
        echo "${user_name}:${user_name}"
    else
        echo "root:root"
    fi
}

function debapps_config_ensure() {
    local config_file
    local config_dir

    config_file=$(debapps_config_file)
    config_dir=$(dirname "${config_file}")
    mkdir -p "${config_dir}"

    if [[ ! -f "${config_file}" ]]; then
        {
            echo "# DebApps managed applications"
            echo "# Format: app_id|name|type|package|installed_at"
        } > "${config_file}"
    fi

    chmod 600 "${config_file}"
    chown "$(debapps_config_owner)" "${config_file}" 2>/dev/null || true
}

function debapps_track_install() {
    local app_id="$1"
    local config_file
    local tmp_file
    local installed_at

    app_manifest_require "${app_id}" || return 1
    debapps_config_ensure
    config_file=$(debapps_config_file)
    tmp_file=$(mktemp)
    installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    awk -F'|' -v app_id="${app_id}" '($0 ~ /^#/ || $1 != app_id)' "${config_file}" > "${tmp_file}"
    printf '%s|%s|%s|%s|%s\n' \
        "${app_id}" \
        "${APP_NAME[${app_id}]}" \
        "${APP_TYPE[${app_id}]}" \
        "${APP_PACKAGE[${app_id}]}" \
        "${installed_at}" >> "${tmp_file}"
    install -m 0600 "${tmp_file}" "${config_file}"
    chown "$(debapps_config_owner)" "${config_file}" 2>/dev/null || true
    rm -f "${tmp_file}"
}

function debapps_untrack_app() {
    local app_id="$1"
    local config_file
    local tmp_file

    debapps_config_ensure
    config_file=$(debapps_config_file)
    tmp_file=$(mktemp)

    awk -F'|' -v app_id="${app_id}" '($0 ~ /^#/ || $1 != app_id)' "${config_file}" > "${tmp_file}"
    install -m 0600 "${tmp_file}" "${config_file}"
    chown "$(debapps_config_owner)" "${config_file}" 2>/dev/null || true
    rm -f "${tmp_file}"
}

function install_manifest_app() {
    local app_id="$1"
    local install_status

    app_manifest_require "${app_id}" || return 1

    case "${APP_TYPE[${app_id}]}" in
        appimage)
            install_manifest_appimage "${app_id}"
            install_status=$?
            ;;
        deb)
            install_manifest_deb "${app_id}"
            install_status=$?
            ;;
        apt)
            pkgmgr install "${APP_PACKAGE[${app_id}]}"
            install_status=$?
            ;;
        apt-repo)
            install_manifest_apt_repo "${app_id}"
            install_status=$?
            ;;
        *)
            print_message FAIL "Unsupported app manifest type: ${APP_TYPE[${app_id}]}"
            return 1
            ;;
    esac

    if [[ "${install_status}" -eq 0 ]]; then
        debapps_track_install "${app_id}"
    fi

    return "${install_status}"
}

function resolve_manifest_content() {
    local resolver="$1"

    if [[ -z "${resolver}" ]]; then
        print_message FAIL "No content resolver defined."
        return 1
    fi

    if ! declare -F "${resolver}" >/dev/null 2>&1; then
        print_message FAIL "Content resolver does not exist: ${resolver}"
        return 1
    fi

    "${resolver}"
}

function download_to_stdout() {
    local url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${url}"
        return $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO- "${url}"
        return $?
    fi

    print_message FAIL "Cannot download because neither curl nor wget is installed."
    return 1
}

function key_fingerprint_matches() {
    local key_file="$1"
    local expected_fingerprint="$2"
    local actual_fingerprint

    actual_fingerprint=$(gpg -n -q --import --import-options import-show "${key_file}" 2>/dev/null \
        | awk '/pub/{getline; gsub(/^ +| +$/,""); print; exit}' \
        | tr -d '[:space:]')
    expected_fingerprint=$(echo "${expected_fingerprint}" | tr -d '[:space:]')

    [[ -n "${actual_fingerprint}" && "${actual_fingerprint}" == "${expected_fingerprint}" ]]
}

function install_manifest_apt_repo_key() {
    local app_id="$1"
    local app_name="${APP_NAME[${app_id}]}"
    local key_url="${APP_KEY_URL[${app_id}]}"
    local keyring_path="${APP_KEYRING_PATH[${app_id}]}"
    local key_fingerprint="${APP_KEY_FINGERPRINT[${app_id}]}"
    local key_file
    local keyring_file

    if [[ -z "${key_url}" || -z "${keyring_path}" ]]; then
        print_message FAIL "${app_name} is missing key URL or keyring path."
        return 1
    fi

    key_file=$(mktemp)
    keyring_file=$(mktemp)
    print_message INFO "Fetching ${app_name} repository signing key..."
    download_to_stdout "${key_url}" > "${key_file}" || {
        rm -f "${key_file}" "${keyring_file}"
        print_message FAIL "Failed to fetch signing key: ${key_url}"
        return 1
    }

    if [[ -n "${key_fingerprint}" ]]; then
        if key_fingerprint_matches "${key_file}" "${key_fingerprint}"; then
            print_message PASS "${app_name} signing key fingerprint matches."
        else
            rm -f "${key_file}" "${keyring_file}"
            print_message FAIL "${app_name} signing key fingerprint does not match."
            return 1
        fi
    fi

    if file "${key_file}" | grep -q "PGP public key block"; then
        gpg --dearmor < "${key_file}" > "${keyring_file}" || {
            rm -f "${key_file}" "${keyring_file}"
            print_message FAIL "Failed to dearmor signing key for ${app_name}."
            return 1
        }
    else
        cp "${key_file}" "${keyring_file}"
    fi

    sudo install -D -o root -g root -m 0644 "${keyring_file}" "${keyring_path}"
    rm -f "${key_file}" "${keyring_file}"
}

function install_manifest_apt_repo_source() {
    local app_id="$1"
    local app_name="${APP_NAME[${app_id}]}"
    local source_url="${APP_SOURCE_URL[${app_id}]}"
    local source_path="${APP_SOURCE_PATH[${app_id}]}"
    local source_resolver="${APP_SOURCE_RESOLVER[${app_id}]}"
    local source_content
    local source_file

    if [[ -z "${source_path}" ]]; then
        print_message FAIL "${app_name} is missing source path."
        return 1
    fi

    print_message INFO "Adding ${app_name} apt source..."
    if [[ -n "${source_url}" ]]; then
        source_content=$(download_to_stdout "${source_url}") || {
            print_message FAIL "Failed to fetch apt source: ${source_url}"
            return 1
        }
    else
        source_content=$(resolve_manifest_content "${source_resolver}") || return 1
    fi

    if [[ -z "${source_content}" ]]; then
        print_message FAIL "${app_name} apt source content is blank."
        return 1
    fi

    source_file=$(mktemp)
    printf '%s\n' "${source_content}" > "${source_file}"
    sudo install -D -o root -g root -m 0644 "${source_file}" "${source_path}"
    rm -f "${source_file}"
}

function install_manifest_apt_repo_pin() {
    local app_id="$1"
    local pin_path="${APP_PIN_PATH[${app_id}]}"
    local pin_resolver="${APP_PIN_RESOLVER[${app_id}]}"
    local pin_content
    local pin_file

    if [[ -z "${pin_path}" || -z "${pin_resolver}" ]]; then
        return 0
    fi

    pin_content=$(resolve_manifest_content "${pin_resolver}") || return 1
    if [[ -z "${pin_content}" ]]; then
        print_message FAIL "${APP_NAME[${app_id}]} apt pin content is blank."
        return 1
    fi

    pin_file=$(mktemp)
    printf '%s\n' "${pin_content}" > "${pin_file}"
    sudo install -D -o root -g root -m 0644 "${pin_file}" "${pin_path}"
    rm -f "${pin_file}"
}

function install_manifest_apt_repo() {
    local app_id="$1"

    print_message INFO "Installing ${APP_NAME[${app_id}]} from its apt repository..."
    pkgmgr install apt-transport-https curl wget gpg
    install_manifest_apt_repo_key "${app_id}" || return 1
    install_manifest_apt_repo_source "${app_id}" || return 1
    install_manifest_apt_repo_pin "${app_id}" || return 1
    run_command sudo apt -y update
    pkgmgr install "${APP_PACKAGE[${app_id}]}"
}

function install_manifest_appimage() {
    local app_id="$1"
    local app_name="${APP_NAME[${app_id}]}"
    local install_dir="${APP_INSTALL_DIR[${app_id}]}"
    local download_url

    print_message INFOFULL "This script will install ${app_name} using the latest AppImage."
    print_message WARN "Any existing ${app_name} settings or configuration may be lost."
    wait_for user_continue

    print_message INFO "Checking for required packages..."
    run_command sudo apt -y update
    pkgmgr install curl wget
    pkgmgr install libfuse2
    pkgmgr remove "${APP_PACKAGE[${app_id}]}"

    download_url=$(resolve_app_download_url "${app_id}") || return 1
    if [[ -z "${download_url}" ]]; then
        print_message FAIL "Unable to resolve download URL for ${app_name}."
        return 1
    fi

    if [[ -d "${install_dir}" ]]; then
        print_message WARN "A directory for ${install_dir} already exists. Any existing files may be overwritten."
        wait_for user_continue
    else
        run_command mkdir -p "${install_dir}"
    fi

    local appimage_save_file="${install_dir}/${app_id}.AppImage"
    download_file "${appimage_save_file}" "${download_url}"
    setup_app_image "${appimage_save_file}"
}

function install_manifest_deb() {
    local app_id="$1"
    local app_name="${APP_NAME[${app_id}]}"
    local download_url
    local save_ext="${APP_SAVE_EXT[${app_id}]:-.deb}"
    local save_file="/tmp/${app_id}${save_ext}"

    print_message INFO "Installing ${app_name}..."
    download_url=$(resolve_app_download_url "${app_id}") || return 1
    if [[ -z "${download_url}" ]]; then
        print_message FAIL "Unable to resolve download URL for ${app_name}."
        return 1
    fi

    download_file "${save_file}" "${download_url}"
    pkgmgr install "${save_file}"
    if [[ "${APP_FIX_BROKEN[${app_id}]}" == "true" ]]; then
        run_command_verbose sudo apt -y --fix-broken install
    fi
}

function remove_manifest_app() {
    local app_id="$1"
    local remove_status

    app_manifest_require "${app_id}" || return 1

    case "${APP_TYPE[${app_id}]}" in
        appimage)
            print_message WARN "This will delete and remove all files, settings and configuration for ${APP_NAME[${app_id}]}."
            wait_for user_continue
            remove_app_image "${APP_INSTALL_DIR[${app_id}]}"
            remove_status=$?
            ;;
        deb|apt)
            pkgmgr remove "${APP_PACKAGE[${app_id}]}"
            remove_status=$?
            ;;
        apt-repo)
            pkgmgr remove "${APP_PACKAGE[${app_id}]}"
            if [[ -n "${APP_REMOVE_FILES[${app_id}]}" ]]; then
                # shellcheck disable=SC2086
                run_command sudo rm -f ${APP_REMOVE_FILES[${app_id}]}
            fi
            run_command sudo apt -y update
            remove_status=$?
            ;;
        *)
            print_message FAIL "Unsupported app manifest type: ${APP_TYPE[${app_id}]}"
            return 1
            ;;
    esac

    if [[ "${remove_status}" -eq 0 ]]; then
        debapps_untrack_app "${app_id}"
    fi

    return "${remove_status}"
}

function debapps_managed_entries() {
    local config_file
    local app_id

    debapps_config_ensure
    config_file=$(debapps_config_file)

    while IFS='|' read -r app_id app_name app_type app_package installed_at; do
        [[ -z "${app_id}" || "${app_id}" == \#* ]] && continue
        app_manifest_has "${app_id}" || continue
        printf '%s|%s|%s|%s|%s\n' "${app_id}" "${app_name}" "${app_type}" "${app_package}" "${installed_at}"
    done < "${config_file}"
}

function managed_app_action_menu() {
    local app_id="$1"
    local menu_options
    local choice

    app_manifest_require "${app_id}" || return 1
    menu_options=(
        "Upgrade/Reinstall ${APP_NAME[${app_id}]}"
        "Remove ${APP_NAME[${app_id}]}"
        "Back"
    )

    while :; do
        choice=$(menu_select "${APP_NAME[${app_id}]}" "${menu_options[@]}")
        case "${choice}" in
            1)
                clear
                install_manifest_app "${app_id}"
                wait_for user_anykey
                return 0
                ;;
            2)
                clear
                remove_manifest_app "${app_id}"
                wait_for user_anykey
                return 0
                ;;
            3)
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    done
}

function managed_apps_menu() {
    local entries=()
    local options=()
    local line
    local app_id
    local app_name
    local app_type
    local app_package
    local installed_at
    local choice
    local selected_entry

    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        entries+=("${line}")
        IFS='|' read -r app_id app_name app_type app_package installed_at <<< "${line}"
        options+=("${app_name} (${app_type}: ${app_package}, ${installed_at})")
    done < <(debapps_managed_entries)

    if [[ "${#entries[@]}" -eq 0 ]]; then
        print_message INFO "No DebApps-managed manifest applications are recorded."
        print_message INFO "Tracking file: $(debapps_config_file)"
        wait_for user_anykey
        return 0
    fi

    options+=("Back")

    while :; do
        choice=$(menu_select "DebApps Managed Applications" "${options[@]}")
        if [[ "${choice}" -eq "${#options[@]}" ]]; then
            return 0
        fi

        selected_entry="${entries[$((choice - 1))]}"
        IFS='|' read -r app_id app_name app_type app_package installed_at <<< "${selected_entry}"
        managed_app_action_menu "${app_id}"
        return 0
    done
}

function validate_url_reachable() {
    local url="$1"

    if [[ -z "${url}" ]]; then
        return 1
    fi

    if command -v wget >/dev/null 2>&1; then
        wget --user-agent=Mozilla --max-redirect=10 --timeout=15 --tries=1 -q --spider "${url}"
        return $?
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsIL --max-redirs 10 --connect-timeout 15 "${url}" >/dev/null
        return $?
    fi

    print_message FAIL "Cannot validate URLs because neither wget nor curl is installed."
    return 1
}

function validate_manifest_app() {
    local app_id="$1"
    local download_url

    app_manifest_require "${app_id}" || return 1

    case "${APP_TYPE[${app_id}]}" in
        appimage|deb|archive)
            print_message TASK "Checking ${APP_NAME[${app_id}]} download link..."
            download_url=$(resolve_app_download_url "${app_id}") || {
                print_message FAIL "Unable to resolve download URL for ${APP_NAME[${app_id}]}."
                return 1
            }
            if [[ -z "${download_url}" ]]; then
                print_message FAIL "Resolved blank download URL for ${APP_NAME[${app_id}]}."
                return 1
            fi
            print_message INFO "URL: ${download_url}"
            if validate_url_reachable "${download_url}"; then
                print_message PASS "${APP_NAME[${app_id}]} download link is reachable."
                return 0
            fi
            print_message FAIL "${APP_NAME[${app_id}]} download link is not reachable."
            return 1
            ;;
        apt)
            print_message SKIP "${APP_NAME[${app_id}]} uses apt repositories; direct link validation is not required."
            return 0
            ;;
        apt-repo)
            validate_manifest_apt_repo "${app_id}"
            ;;
        *)
            print_message FAIL "Unsupported app manifest type: ${APP_TYPE[${app_id}]}"
            return 1
            ;;
    esac
}

function validate_manifest_apt_repo() {
    local app_id="$1"
    local failed=0
    local source_content
    local pin_content

    print_message TASK "Checking ${APP_NAME[${app_id}]} apt repository metadata..."
    if [[ -z "${APP_PACKAGE[${app_id}]}" ]]; then
        print_message FAIL "${APP_NAME[${app_id}]} package name is not configured."
        failed=1
    fi

    if [[ -z "${APP_REMOVE_FILES[${app_id}]}" ]]; then
        print_message FAIL "${APP_NAME[${app_id}]} cleanup paths are not configured."
        failed=1
    fi

    if [[ -n "${APP_KEY_URL[${app_id}]}" ]]; then
        print_message INFO "Key URL: ${APP_KEY_URL[${app_id}]}"
        validate_url_reachable "${APP_KEY_URL[${app_id}]}" || failed=1
    else
        print_message FAIL "${APP_NAME[${app_id}]} key URL is not configured."
        failed=1
    fi

    if [[ -n "${APP_SOURCE_URL[${app_id}]}" ]]; then
        print_message INFO "Source URL: ${APP_SOURCE_URL[${app_id}]}"
        validate_url_reachable "${APP_SOURCE_URL[${app_id}]}" || failed=1
    else
        source_content=$(resolve_manifest_content "${APP_SOURCE_RESOLVER[${app_id}]}") || failed=1
        [[ -n "${source_content}" ]] || failed=1
    fi

    if [[ -n "${APP_PIN_RESOLVER[${app_id}]}" ]]; then
        pin_content=$(resolve_manifest_content "${APP_PIN_RESOLVER[${app_id}]}") || failed=1
        [[ -n "${pin_content}" ]] || failed=1
    fi

    if [[ "${failed}" -eq 0 ]]; then
        print_message PASS "${APP_NAME[${app_id}]} apt repository metadata is valid."
    else
        print_message FAIL "${APP_NAME[${app_id}]} apt repository metadata validation failed."
    fi

    return "${failed}"
}

function validate_manifest_apps() {
    local failed=0
    local app_id

    for app_id in "$@"; do
        validate_manifest_app "${app_id}" || failed=1
    done

    return "${failed}"
}

function validate_all_manifest_apps() {
    local failed=0
    local app_id

    for app_id in "${!APP_NAME[@]}"; do
        validate_manifest_app "${app_id}" || failed=1
    done

    return "${failed}"
}

function import_app_manifest() {
    local manifest_file="${1:-${SCRIPT_DIR}/app-manifest.sh}"
    local manifest_remote="${2:-https://raw.githubusercontent.com/bradsec/debapps/main/src/app-manifest.sh}"

    if [[ -f "${manifest_file}" ]]; then
        # shellcheck disable=SC1090
        source "${manifest_file}"
        return $?
    fi

    if wget -q --spider "${manifest_remote}"; then
        local tmp_manifest_file
        tmp_manifest_file=$(mktemp)
        wget -qO "${tmp_manifest_file}" "${manifest_remote}"

        # shellcheck disable=SC1090
        source "${tmp_manifest_file}"
        local source_status=$?
        rm -f "${tmp_manifest_file}"
        return "${source_status}"
    fi

    print_message FAIL "App manifest not found: ${manifest_file}"
    return 1
}

print_message PASS "${TEMPLATE_NAME} imported."
