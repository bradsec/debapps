#!/usr/bin/env bash

# Functions/commands specific to macOS systems.
# Requires: generic.sh template to be loaded first.

TEMPLATE_NAME="MACOS"

# Check if Xcode command line tools are installed.
function check_xcode() {
    print_message INFO "Checking for Xcode command line tools..."
    if xcode-select -p >/dev/null 2>&1; then
        print_message DONE "Xcode command line tools are already installed."
    else
        print_message WARN "Xcode command line tools are not installed."
        print_message INFO "Attempting to install Xcode command line tools..."
        if xcode-select --install >/dev/null 2>&1; then
            print_message INFO "Xcode command line tools are now installing..."
        else
            print_message FAIL "Xcode command line tools installation failed."
            exit 1
        fi
    fi
}

print_message INFO "${TEMPLATE_NAME} TEMPLATE IMPORTED."