#!/usr/bin/env bash

# Functions/commands compatible with most Linux or macOS terminals.
# Note: This template needs to be imported first.
clear

TEMPLATE_NAME="templates/generic.tmpl.sh"

term_colors() {
    # Set colors for use in print_message TASK terminal output functions
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        CYAN=$(printf '\033[36m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        ORANGE=$(printf '\033[38;5;208m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[0m')
        CLEAR_LINE=$(tput el)
    else
        RED=""
        GREEN=""
        CYAN=""
        YELLOW=""
        BLUE=""
        ORANGE=""
        BOLD=""
        RESET=""
        CLEAR_LINE=""
    fi
}

# Initialise global terminal colors
term_colors

# Print formated terminal messages
print_message() {
    local option=${1}
    local text=${2}
    local terminal_width=$(tput cols)
    local max_chars=$((terminal_width - 8))
    local truncated_text=$(truncate_text "$text" $max_chars)

    local border_sym=$' '
    local info_sym=$'i'
    local task_sym=$'i'
    local pass_sym=$'\u2714'      
    local fail_sym=$'\u2718'      
    local warn_sym=$'\u26A0'      
    local skip_sym=$'s'      
    local user_sym=$'u' 
    local done_sym=$'\u2714'     
    local blank_sym=$' '         


    # Preserve newline or carriage return at the end, if present
    local preserved_chars=""
    if [[ "$text" =~ [[:space:]]$ ]]; then
        preserved_chars=${text: -1}
    fi

    case "${option}" in
        INFOFULL)
            format="${border_sym}${BOLD}${CYAN}${info_sym} %s${RESET}\n"
            ;;
        INFO)
            format="${border_sym}${BOLD}${CYAN}${info_sym}${RESET} %s\n"
            ;;
        TASK)
            format="${border_sym}${BOLD}${task_sym}${RESET} %s"
            ;;
        WARN)
            format="${border_sym}${YELLOW}${warn_sym} %s${RESET}\n"
            ;;
        USER)
            format="${border_sym}${BOLD}${GREEN}${user_sym}${RESET} %s\n"
            ;;
        SKIP)
            format="${border_sym}${BOLD}${BLUE}${skip_sym}${RESET} %s\n"
            ;;
        FAIL)
            format="${border_sym}${RED}${fail_sym} %s${RESET}\n"
            ;;
        BLANK)
            format="${border_sym}${blank_sym} %s\n"
            ;;
        DONE)
            format="${border_sym}${BOLD}${GREEN}${done_sym} %s${RESET}\n"
            ;;
        PASS)
            format="${border_sym}${GREEN}${pass_sym} %s${RESET}\n"
            ;;
        *)
            format="%s"
            ;;
    esac

    printf "\r${format}${CLEAR_LINE}" "${truncated_text}${preserved_chars}"
}


# Function to truncate text if it exceeds the maximum length
truncate_text() {
    local text="$1"
    local max_chars="$2"
    local ellipsis="..."

    if [ ${#text} -gt $max_chars ]; then
        echo -n "${text:0:$max_chars}${ellipsis}"
    else
        echo -n "$text"
    fi
}

# Date/time formatting
# Example output: 04-May-2022 21:04:14
function get_date_time() {
	print_message INFO "$(date +"%d-%b-%Y %H:%M:%S")"
}

# Function to return OS and hardware details
# Usage example 1: get_os summary
# Usage example 2: thisvar=$(get_os release)
function get_os() {
	if [[ $(command -v lsb_release) ]] >/dev/null 2>&1; then
        local codename=$(lsb_release -c --short)
        local release=$(lsb_release -r --short)
        local dist=$(lsb_release -d --short)
        local distid=$(lsb_release -i --short)
        local arch=$(uname -m)
        local dpkg_arch=$(dpkg --print-architecture)
        local check_cpu=$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)
        local check_model=$(cat /proc/cpuinfo | grep Model | head -1 | cut -d':' -f2 | xargs)
        if [[ -z "${check_cpu}" ]]; then
            local hardware="${check_model}"
        else
            local hardware="${check_cpu}"
        fi

        case ${1} in
            
            codename)
                echo -ne ${codename}
            ;;
            release)
                echo -ne ${release}
            ;;
            dist)
                echo -ne ${distro}
            ;;
            distid)
                echo -ne ${distid}
            ;;
            arch)
                echo -ne ${arch}
            ;;
            dpkg_arch)
                echo -ne ${dpkg_arch}
            ;;
            hardware)
                echo -ne ${hardware}
            ;;
            summary)
                print_message INFO "OS Detected: ${dist} ${arch}"
                print_message INFO "Hardware Detected: ${hardware}"
            ;;
            *) print_message WARN "Invalid get_os() function usage."
            ;;
        esac
    elif [[ $(sysctl -n machdep.cpu.brand_string) ]] >/dev/null 2>&1; then
        local hardware=$(sysctl -n machdep.cpu.brand_string | xargs)
        local dist=$(sw_vers -productVersion | xargs)
            case ${1} in
                summary)
                print_message INFO "OS Detected: macOS ${dist} ${arch}"
                print_message INFO "Hardware Detected: ${hardware}"
                ;;
                *) print_message WARN "Invalid get_os() function usage."
                ;;
            esac
    fi
}

# Display press any key or do you wish to continue y/N.
# Example usage: wait_for user_anykey OR wait_for user_continue
function wait_for() {
    echo
    if [ -z "${2}" ]; then
        message="Do you wish to continue"
    else
        message="${2}"
    fi

    case "${1}" in
        user_anykey) read -n 1 -s -r -p "[${GREEN}USER${RESET}] Press any key to continue. "
        echo -e "\n"
        ;;
        user_continue) local response
        while true; do
            read -r -p "[${GREEN}USER${RESET}] ${message} (y/N)?${RESET} " response
            case "${response}" in
            [yY][eE][sS] | [yY])
                echo
                break
                ;;
            *)
                echo
                exit
                ;;
            esac
        done;;
        *) message FAIL "Invalid function usage.";;
    esac
}

# Check if script is being run as superuser
function check_superuser() {
    if [[ $(id -u) -ne 0 ]]; then
        print_message FAIL "Script must be run by superuser or using sudo command."
        exit 1
    fi
}

# Get non-root user
function get_user() {
    if [[ $(command -v logname) ]] >/dev/null 2>&1; then
        echo -ne "$(logname)"
    elif [[ ! -z ${SUDO_USER} ]]; then
        echo -ne "${SUDO_USER}"
    elif [[ $(command -v whoami) ]] >/dev/null 2>&1; then
        echo -ne "$(whoami)"
    else
        echo -ne "${USER}"
    fi
}

# Function runs commands and suppresses output.
# Best for commands with short execution time.
# A true or 0 result can be forced to prevent a fail message.
function run_command() {
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
                if [ -z "${command_string}" ]; then
                    command_string="$1"
                else
                    command_string+=" $1"
                fi
                shift
                ;;
        esac
    done

    command_string=$(trim "${command_string}")
    
    print_message TASK "${command_string}"
    if [ "$force_zero" = true ]; then
        command_output=$( "${command[@]}" >/dev/null 2>&1 )
        print_message PASS
    else
        command_output=$( "${command[@]}" 2>&1 )
        local exit_status=$?
        if [ $exit_status -eq 0 ]; then
            print_message PASS "${command_string}"
        else
            if [ -n "$command_output" ]; then
                print_message FAIL "${command_string}"
                print_message BLANK "${RED}${command_output}${RESET}"
            else
                print_message FAIL "${command_string}"
            fi
        fi
    fi
}

# Function runs commands with full output.
# Best for commands with long execution time or signicant output.
function run_command_verbose() {
    local command=("$@")
    local command_string="${command[*]}"

    print_message TASK "${command_string}"
    echo
    "${command[@]}"
}

# Function to trim leading and trailing whitespace
function trim() {
    var="$*"
    var="$(echo "$var" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo -n "$var"
}

# Write text config to a file
# Example usage: write_config "this text" "thisfile.txt"
function write_config_file() {
    local filename=${2}
    local content=${1}
    print_message INFO "Writing config file ${filename}..."  
    cat > ${filename} << EOL
${content}
EOL
}

# Display file hash information
# Example usage 1: file_hash all "thisfile.ext"
# Example usage 2: thishash=$(file_hash sha256 "thisfile.ext")
function file_hash(){
    local option=${1}
    local filename=${2}
    case "${option}" in
        all) print_message INFO "File hash values for ${filename}..."
            echo -e "   MD5 $(md5sum ${filename} | cut -d ' ' -f 1)"
            echo -e "  SHA1 $(sha1sum ${filename} | cut -d ' ' -f 1)"
            echo -e "SHA256 $(sha256sum ${filename} | cut -d ' ' -f 1)\n";;
        md5) echo -ne "$(md5sum ${filename} | cut -d ' ' -f 1)";;
        sha1) echo -ne "$(sha1sum ${filename} | cut -d ' ' -f 1)";;
        sha256) "SHA256 $(sha256sum ${filename} | cut -d ' ' -f 1)\n";;
        *) print_message FAIL "Invalid function usage.";;
    esac
}

# Custom progress function for curl
function custom_curl_progress() {
  local downloaded=$2
  local total=$3
  local percentage=$(echo "scale=2; $downloaded * 100 / $total" | bc)
  echo -ne "Progress: ${downloaded}/${total} (${percentage}%)  \r"
}

function download_file() {
    local dst_file=${1}
    local src_url=${2}

    # Check if the source URL is blank
    if [[ -z ${src_url} ]]; then
        print_message FAIL "Unable to get the latest application source URL. The application source URL may have changed or moved."
        exit 1
    fi

    print_message INFO "Downloading file..."
    print_message INFO "SRC: ${src_url}"
    print_message INFO "DEST: ${dst_file}"

    # Check if the source URL is valid
    if [[ ! ${src_url} =~ ^(http|https|ftp):// ]]; then
        print_message FAIL "Invalid source URL. Only URLs starting with 'http://', 'https://', or 'ftp://' are supported."
        exit 1
    fi

    if wget --user-agent=Mozilla --content-disposition -c -E -O \
    "${dst_file}" "${src_url}" -q --show-progress --progress=bar:force 2>&1; then
        echo
        print_message DONE "File successfully downloaded."
    else
        print_message WARN "There was a problem downloading the file. Trying another method..."
        print_message INFO "Trying wget without resume option..."
        if wget --user-agent=Mozilla --content-disposition -E -O \
            "${dst_file}" "${src_url}" -q --show-progress --progress=bar:force 2>&1; then
            echo
            print_message DONE "File successfully downloaded."# Requires: generic.sh template to be loaded first.
            if curl -L -J "${src_url}" -o "${dst_file}" --progress-bar; then
                echo
                print_message DONE "File successfully downloaded."
            else
                print_message FAIL "There was a problem downloading the file. Check URL and source file."
                exit 1
            fi
        fi
    fi
    file_hash all ${dst_file}
}


# Compare two values
# Example usage: compare_hashes "hashvalue1" "hashvalue2"
function compare_values(){
    if [ "${1}" == "${2}" ]; then
        message PASS "The two values match."
    else
        print_message FAIL "The two values did not match."
        exit 1
    fi
}

# Download url plaintext or similar type content and output to screen
# Example usage: download_content "https://urlofplaintextcontent"
function download_content() {
	local src_url=${1}
	print_message INFO "Downloading required plain text content..."
    print_message INFO "Source: ${src_url}"
	if output=$(wget -qO- ${src_url} 1> /dev/null); then
		echo "${output}"
	else
		print_message FAIL "Unable to fetch content."
	fi
}

print_message PASS "${TEMPLATE_NAME} imported."

function about() {
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
    check_superuser
}
