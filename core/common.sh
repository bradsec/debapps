#!/usr/bin/env bash

# Core utilities for DEBAPPS
# Refactored from src/templates/generic.tmpl.sh
# Functions compatible with most Linux or macOS terminals

set -euo pipefail

# Terminal color variables (script-wide, not exported to avoid gum conflicts)
# Retro green CRT terminal color scheme - ANSI 256-color for compatibility
if [[ -t 1 ]]; then
    GREEN=$(printf '\033[38;5;83m')
    GREENDULL=$(printf '\033[38;5;28m')
    RED=$(printf '\033[38;5;203m')

    BOLD=$(printf '\033[1m')
    # Reset to green instead of terminal default (maintains retro CRT aesthetic)
    RESET=$(printf '\033[38;5;28m')
    CLEAR_LINE=$(tput el)
else
    RED="" GREEN="" GREENDULL="" BOLD="" RESET="" CLEAR_LINE=""
fi

# Truncate text if it exceeds maximum length
truncate_text() {
    local text="$1"
    local max_chars="$2"
    local ellipsis="..."

    if [[ ${#text} -gt "$max_chars" ]]; then
        echo -n "${text:0:$max_chars}${ellipsis}"
    else
        echo -n "$text"
    fi
}

# Print formatted terminal messages
# Usage: print_message INFO "message text"
# Options: INFOFULL, INFO, TASK, WARN, USER, SKIP, FAIL, BLANK, DONE, PASS
print_message() {
    local option="${1:-INFO}"
    local text="${2:-}"

    # Validate inputs
    if [[ -z "$text" ]] && [[ "$option" != "BLANK" ]]; then
        echo "Error: print_message requires message text" >&2
        return 1
    fi

    local terminal_width
    terminal_width=$(tput cols 2>/dev/null || echo 80)
    local max_chars=$((terminal_width - 8))
    local truncated_text
    truncated_text=$(truncate_text "$text" "$max_chars")

    local border_sym=' '
    local info_sym='i'
    local task_sym='i'
    local pass_sym=$'\u2714'
    local fail_sym=$'\u2718'
    local warn_sym=$'\u26A0'
    local skip_sym='s'
    local user_sym='u'
    local done_sym=$'\u2714'
    local blank_sym=' '

    # Preserve newline or carriage return at the end, if present
    local preserved_chars=""
    if [[ "$text" =~ [[:space:]]$ ]]; then
        preserved_chars="${text: -1}"
    fi

    case "${option}" in
        INFOFULL)
            format="${border_sym}${GREENDULL}${info_sym} %s${RESET}\n"
            ;;
        INFO)
            format="${border_sym}${GREENDULL}${info_sym}${RESET} %s\n"
            ;;
        TASK)
            format="${border_sym}${task_sym}${RESET} %s"
            ;;
        WARN)
            format="${border_sym}${GREENDULL}${warn_sym} %s${RESET}\n"
            ;;
        USER)
            format="${border_sym}${GREEN}${user_sym}${RESET} %s\n"
            ;;
        SKIP)
            format="${border_sym}${GREENDULL}${skip_sym}${RESET} %s\n"
            ;;
        FAIL)
            format="${border_sym}${RED}${fail_sym} %s${RESET}\n"
            ;;
        BLANK)
            format="${border_sym}${blank_sym} %s\n"
            ;;
        DONE)
            format="${border_sym}${GREEN}${done_sym} %s${RESET}\n"
            ;;
        PASS)
            format="${border_sym}${GREEN}${pass_sym} %s${RESET}\n"
            ;;
        *)
            format="%s\n"
            ;;
    esac

    printf "${format}" "${truncated_text}${preserved_chars}"
}

# Date/time formatting
# Output: 04-May-2022 21:04:14
get_date_time() {
    print_message INFO "$(date +"%d-%b-%Y %H:%M:%S")"
}

# Return OS and hardware details
# Usage: get_os summary | get_os release | get_os arch | etc.
get_os() {
    local option="${1:-summary}"

    if command -v lsb_release &>/dev/null; then
        local codename
        codename=$(lsb_release -c --short)
        local release
        release=$(lsb_release -r --short)
        local dist
        dist=$(lsb_release -d --short)
        local distid
        distid=$(lsb_release -i --short)
        local arch
        arch=$(uname -m)
        local dpkg_arch
        dpkg_arch=$(dpkg --print-architecture 2>/dev/null || echo "unknown")

        local check_cpu
        check_cpu=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)
        local check_model
        check_model=$(grep Model /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)

        local hardware
        if [[ -z "${check_cpu}" ]]; then
            hardware="${check_model}"
        else
            hardware="${check_cpu}"
        fi

        case "${option}" in
            codename)
                echo -n "${codename}"
                ;;
            release)
                echo -n "${release}"
                ;;
            dist)
                echo -n "${dist}"
                ;;
            distid)
                echo -n "${distid}"
                ;;
            arch)
                echo -n "${arch}"
                ;;
            dpkg_arch)
                echo -n "${dpkg_arch}"
                ;;
            hardware)
                echo -n "${hardware}"
                ;;
            summary)
                print_message INFO "OS Detected: ${dist} ${arch}"
                print_message INFO "Hardware Detected: ${hardware}"
                ;;
            *)
                print_message WARN "Invalid get_os() usage: ${option}"
                return 1
                ;;
        esac
    elif command -v sw_vers &>/dev/null; then
        # macOS
        local hardware
        hardware=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | xargs)
        local dist
        dist=$(sw_vers -productVersion 2>/dev/null | xargs)

        case "${option}" in
            summary)
                print_message INFO "OS Detected: macOS ${dist}"
                print_message INFO "Hardware Detected: ${hardware}"
                ;;
            *)
                print_message WARN "Invalid get_os() usage for macOS: ${option}"
                return 1
                ;;
        esac
    fi
}

# Display press any key or continue prompt
# Usage: wait_for user_anykey | wait_for user_continue ["custom message"]
wait_for() {
    local option="${1:-user_continue}"
    local message="${2:-Do you wish to continue}"

    echo

    case "${option}" in
        user_anykey)
            read -n 1 -s -r -p "[${GREEN}USER${RESET}] Press any key to continue. "
            echo -e "\n"
            ;;
        user_continue)
            local response
            while true; do
                read -r -p "[${GREEN}USER${RESET}] ${message} (y/N)? " response
                case "${response}" in
                    [yY][eE][sS]|[yY])
                        echo
                        break
                        ;;
                    *)
                        echo
                        exit 0
                        ;;
                esac
            done
            ;;
        *)
            print_message FAIL "Invalid wait_for() usage: ${option}"
            return 1
            ;;
    esac
}

# Check if script is being run as superuser
check_superuser() {
    if [[ $(id -u) -ne 0 ]]; then
        echo
        print_message FAIL "Script must be run by superuser or using sudo command."
        echo
        print_message INFO "Please run: sudo ./debapps"
        echo
        exit 1
    fi
}

# Get non-root user
get_user() {
    if command -v logname &>/dev/null; then
        logname 2>/dev/null || echo "${SUDO_USER:-${USER}}"
    elif [[ -n ${SUDO_USER:-} ]]; then
        echo -n "${SUDO_USER}"
    elif command -v whoami &>/dev/null; then
        whoami
    else
        echo -n "${USER}"
    fi
}

# Trim leading and trailing whitespace
trim() {
    local var="$*"
    var="$(echo "$var" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo -n "$var"
}

# Run command and suppress output
# Best for commands with short execution time
# Usage: run_command command args OR run_command -z command args (force zero/pass)
run_command() {
    local command_output
    local force_zero=false
    local command=()
    local command_string=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -z|--force-zero)
                force_zero=true
                shift
                ;;
            *)
                command+=("$1")
                if [[ -z "${command_string}" ]]; then
                    command_string="$1"
                else
                    command_string+=" $1"
                fi
                shift
                ;;
        esac
    done

    command_string=$(trim "${command_string}")

    if [[ ${#command[@]} -eq 0 ]]; then
        print_message FAIL "run_command requires a command"
        return 1
    fi

    print_message TASK "${command_string}"

    if [[ "$force_zero" == true ]]; then
        command_output=$( "${command[@]}" >/dev/null 2>&1 )
        print_message PASS "${command_string}"
    else
        command_output=$( "${command[@]}" 2>&1 )
        local exit_status=$?

        if [[ $exit_status -eq 0 ]]; then
            print_message PASS "${command_string}"
        else
            print_message FAIL "${command_string}"
            if [[ -n "$command_output" ]]; then
                print_message BLANK "${RED}${command_output}${RESET}"
            fi
            return 1
        fi
    fi
}

# Run command with full output
# Best for commands with long execution time or significant output
run_command_verbose() {
    local command=("$@")
    local command_string="${command[*]}"

    if [[ ${#command[@]} -eq 0 ]]; then
        print_message FAIL "run_command_verbose requires a command"
        return 1
    fi

    print_message TASK "${command_string}"
    echo
    "${command[@]}"
}

# Write text config to a file
# Usage: write_config_file "content" "filepath"
write_config_file() {
    local content="${1:-}"
    local filename="${2:-}"

    if [[ -z "$filename" ]] || [[ -z "$content" ]]; then
        print_message FAIL "write_config_file requires both content and filename"
        return 1
    fi

    print_message INFO "Writing config file ${filename}..."
    cat > "${filename}" << EOL
${content}
EOL
}

# Display file hash information
# Usage: file_hash all "file.ext" | file_hash sha256 "file.ext"
file_hash() {
    local option="${1:-all}"
    local filename="${2:-}"

    if [[ -z "$filename" ]]; then
        print_message FAIL "file_hash requires a filename"
        return 1
    fi

    if [[ ! -f "$filename" ]]; then
        print_message FAIL "File not found: ${filename}"
        return 1
    fi

    case "${option}" in
        all)
            print_message INFO "File hash values for ${filename}..."
            echo -e "   MD5 $(md5sum "${filename}" | cut -d ' ' -f 1)"
            echo -e "  SHA1 $(sha1sum "${filename}" | cut -d ' ' -f 1)"
            echo -e "SHA256 $(sha256sum "${filename}" | cut -d ' ' -f 1)\n"
            ;;
        md5)
            md5sum "${filename}" | cut -d ' ' -f 1
            ;;
        sha1)
            sha1sum "${filename}" | cut -d ' ' -f 1
            ;;
        sha256)
            sha256sum "${filename}" | cut -d ' ' -f 1
            ;;
        *)
            print_message FAIL "Invalid file_hash option: ${option}"
            return 1
            ;;
    esac
}

# Download file from URL
# Usage: download_file "dest_file" "source_url"
download_file() {
    local dst_file="${1:-}"
    local src_url="${2:-}"

    # Validate inputs
    if [[ -z "${src_url}" ]]; then
        print_message FAIL "Unable to get application source URL. The URL may have changed or moved."
        return 1
    fi

    if [[ -z "${dst_file}" ]]; then
        print_message FAIL "Destination file path is required"
        return 1
    fi

    # Validate URL format
    if [[ ! ${src_url} =~ ^(http|https|ftp):// ]]; then
        print_message FAIL "Invalid source URL. Only URLs starting with 'http://', 'https://', or 'ftp://' are supported."
        return 1
    fi

    print_message INFO "Downloading file..."
    print_message INFO "SRC: ${src_url}"
    print_message INFO "DEST: ${dst_file}"

    # Try wget first
    if wget --user-agent=Mozilla --content-disposition -c -E -O \
        "${dst_file}" "${src_url}" -q --show-progress --progress=bar:force 2>&1; then
        echo
        print_message DONE "File successfully downloaded."
    else
        print_message WARN "There was a problem downloading the file. Trying another method..."

        # Try wget without resume
        if wget --user-agent=Mozilla --content-disposition -E -O \
            "${dst_file}" "${src_url}" -q --show-progress --progress=bar:force 2>&1; then
            echo
            print_message DONE "File successfully downloaded."
        else
            # Try curl as fallback
            print_message INFO "Trying curl..."
            if curl -L -J "${src_url}" -o "${dst_file}" --progress-bar; then
                echo
                print_message DONE "File successfully downloaded."
            else
                print_message FAIL "Download failed. Check URL and network connection."
                return 1
            fi
        fi
    fi

    file_hash all "${dst_file}"
}

# Compare two values
# Usage: compare_values "value1" "value2"
compare_values() {
    local value1="${1:-}"
    local value2="${2:-}"

    if [[ -z "$value1" ]] || [[ -z "$value2" ]]; then
        print_message FAIL "compare_values requires two values"
        return 1
    fi

    if [[ "${value1}" == "${value2}" ]]; then
        print_message PASS "The two values match."
        return 0
    else
        print_message FAIL "The two values did not match."
        return 1
    fi
}

# Download plain text content from URL and output to screen
# Usage: download_content "https://example.com/file.txt"
download_content() {
    local src_url="${1:-}"

    if [[ -z "$src_url" ]]; then
        print_message FAIL "download_content requires a URL"
        return 1
    fi

    print_message INFO "Downloading plain text content..."
    print_message INFO "Source: ${src_url}"

    local output
    if output=$(wget -qO- "${src_url}" 2>&1); then
        echo "${output}"
    else
        print_message FAIL "Unable to fetch content."
        return 1
    fi
}

# Display DEBAPPS banner
about() {
    clear
    echo "${GREEN}"
    cat << "EOF"
     ____  __________  ___    ____  ____  _____
    / __ \/ ____/ __ )/   |  / __ \/ __ \/ ___/
   / / / / __/ / __  / /| | / /_/ / /_/ /\__ \
  / /_/ / /___/ /_/ / ___ |/ ____/ ____/___/ /
 /_____/_____/_____/_/  |_/_/   /_/    /____/

EOF
    echo " ${RESET}Bash scripts to simplify Linux app installations."
    echo " Compatible with most [x64] Debian based distros."
    echo
    get_date_time
    get_os summary
}
