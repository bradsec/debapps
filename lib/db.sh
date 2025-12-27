#!/usr/bin/env bash

# Database management for DEBAPPS
# SQLite-based tracking of installed applications
# Requires: core/common.sh, sqlite3

set -euo pipefail

# Global database path (set by db_init)
DB_PATH=""

# Initialize database and create schema
# Usage: db_init "/path/to/installed-apps.db"
db_init() {
    local db_file="${1:-}"

    if [[ -z "$db_file" ]]; then
        print_message FAIL "db_init requires a database file path"
        return 1
    fi

    # Check if sqlite3 is available
    if ! command -v sqlite3 &>/dev/null; then
        print_message INFO "sqlite3 is required but not installed. Installing..."
        pkgmgr install sqlite3 || {
            print_message FAIL "Failed to install sqlite3"
            return 1
        }
    fi

    # Create directory if it doesn't exist
    local db_dir
    db_dir="$(dirname "$db_file")"
    if [[ ! -d "$db_dir" ]]; then
        mkdir -p "$db_dir"
    fi

    DB_PATH="$db_file"

    print_message INFO "Initializing database: ${DB_PATH}"

    # Create schema
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS installed_apps (
    app_id TEXT PRIMARY KEY,
    app_name TEXT NOT NULL,
    install_method TEXT NOT NULL,
    version TEXT,
    install_date INTEGER,
    install_location TEXT,
    metadata TEXT
);

CREATE TABLE IF NOT EXISTS install_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT,
    FOREIGN KEY(app_id) REFERENCES installed_apps(app_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_app_id ON install_files(app_id);
CREATE INDEX IF NOT EXISTS idx_install_method ON installed_apps(install_method);
EOF

    if [[ $? -eq 0 ]]; then
        print_message PASS "Database initialized successfully"
    else
        print_message FAIL "Failed to initialize database"
        return 1
    fi
}

# Insert or update app installation record
# Usage: db_insert_app "app_id" "app_name" "install_method" "version" "install_location" "metadata_json"
db_insert_app() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local install_method="${3:-}"
    local version="${4:-unknown}"
    local install_location="${5:-}"
    local metadata="${6:-{}}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]] || [[ -z "$app_name" ]] || [[ -z "$install_method" ]]; then
        print_message FAIL "db_insert_app requires: app_id, app_name, install_method"
        return 1
    fi

    # Sanitize inputs by escaping single quotes (SQL injection prevention)
    app_id="${app_id//\'/\'\'}"
    app_name="${app_name//\'/\'\'}"
    install_method="${install_method//\'/\'\'}"
    version="${version//\'/\'\'}"
    install_location="${install_location//\'/\'\'}"
    metadata="${metadata//\'/\'\'}"

    local install_date
    install_date=$(date +%s)

    sqlite3 "$DB_PATH" << EOF
INSERT OR REPLACE INTO installed_apps
    (app_id, app_name, install_method, version, install_date, install_location, metadata)
VALUES
    ('${app_id}', '${app_name}', '${install_method}', '${version}', ${install_date}, '${install_location}', '${metadata}');
EOF

    if [[ $? -eq 0 ]]; then
        print_message PASS "Database: Recorded installation of ${app_name}"
    else
        print_message FAIL "Database: Failed to record installation"
        return 1
    fi
}

# Remove app from database
# Usage: db_remove_app "app_id"
db_remove_app() {
    local app_id="${1:-}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]]; then
        print_message FAIL "db_remove_app requires an app_id"
        return 1
    fi

    # Sanitize input (SQL injection prevention)
    app_id="${app_id//\'/\'\'}"

    # Delete from installed_apps (cascade will delete from install_files)
    sqlite3 "$DB_PATH" "DELETE FROM installed_apps WHERE app_id='${app_id}';"

    if [[ $? -eq 0 ]]; then
        print_message PASS "Database: Removed ${app_id} from tracking"
    else
        print_message FAIL "Database: Failed to remove ${app_id}"
        return 1
    fi
}

# Get app details from database
# Usage: db_get_app "app_id"
# Output: JSON-formatted app details
db_get_app() {
    local app_id="${1:-}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]]; then
        print_message FAIL "db_get_app requires an app_id"
        return 1
    fi

    # Sanitize input (SQL injection prevention)
    app_id="${app_id//\'/\'\'}"

    sqlite3 "$DB_PATH" << EOF
.mode json
SELECT * FROM installed_apps WHERE app_id='${app_id}';
EOF
}

# List all installed apps
# Usage: db_list_installed
# Output: JSON array of installed apps
db_list_installed() {
    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    sqlite3 "$DB_PATH" << 'EOF'
.mode json
SELECT app_id, app_name, install_method, version, install_date, install_location
FROM installed_apps
ORDER BY install_date DESC;
EOF
}

# Check if app is in database
# Usage: db_is_installed "app_id"
# Returns: 0 if installed, 1 if not
db_is_installed() {
    local app_id="${1:-}"

    if [[ -z "$DB_PATH" ]]; then
        return 1
    fi

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    # Sanitize input (SQL injection prevention)
    app_id="${app_id//\'/\'\'}"

    local count
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM installed_apps WHERE app_id='${app_id}';")

    if [[ "$count" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Insert file associated with app installation
# Usage: db_insert_file "app_id" "file_path" "file_type"
db_insert_file() {
    local app_id="${1:-}"
    local file_path="${2:-}"
    local file_type="${3:-unknown}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]] || [[ -z "$file_path" ]]; then
        print_message FAIL "db_insert_file requires: app_id, file_path"
        return 1
    fi

    # Sanitize inputs (SQL injection prevention)
    app_id="${app_id//\'/\'\'}"
    file_path="${file_path//\'/\'\'}"
    file_type="${file_type//\'/\'\'}"

    sqlite3 "$DB_PATH" << EOF
INSERT INTO install_files (app_id, file_path, file_type)
VALUES ('${app_id}', '${file_path}', '${file_type}');
EOF

    if [[ $? -ne 0 ]]; then
        print_message WARN "Failed to record file: ${file_path}"
        return 1
    fi
}

# Get all files associated with an app
# Usage: db_get_install_files "app_id"
# Output: List of file paths (one per line)
db_get_install_files() {
    local app_id="${1:-}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]]; then
        print_message FAIL "db_get_install_files requires an app_id"
        return 1
    fi

    sqlite3 "$DB_PATH" "SELECT file_path FROM install_files WHERE app_id='${app_id}';"
}

# Update app version
# Usage: db_update_version "app_id" "new_version"
db_update_version() {
    local app_id="${1:-}"
    local version="${2:-}"

    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    if [[ -z "$app_id" ]] || [[ -z "$version" ]]; then
        print_message FAIL "db_update_version requires: app_id, version"
        return 1
    fi

    sqlite3 "$DB_PATH" "UPDATE installed_apps SET version='${version}' WHERE app_id='${app_id}';"

    if [[ $? -eq 0 ]]; then
        print_message PASS "Database: Updated version for ${app_id} to ${version}"
    else
        print_message FAIL "Database: Failed to update version"
        return 1
    fi
}

# Get statistics
# Usage: db_get_stats
db_get_stats() {
    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    local total_apps
    total_apps=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM installed_apps;")

    local by_method
    by_method=$(sqlite3 "$DB_PATH" << 'EOF'
SELECT install_method, COUNT(*) as count
FROM installed_apps
GROUP BY install_method;
EOF
)

    print_message INFO "Database Statistics:"
    echo "  Total installed apps: ${total_apps}"
    echo "  By install method:"
    echo "$by_method" | while IFS='|' read -r method count; do
        echo "    ${method}: ${count}"
    done
}

# Export database to JSON
# Usage: db_export_json
db_export_json() {
    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    sqlite3 "$DB_PATH" << 'EOF'
.mode json
SELECT * FROM installed_apps;
EOF
}

# Vacuum database (optimize)
# Usage: db_vacuum
db_vacuum() {
    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    print_message INFO "Optimizing database..."
    sqlite3 "$DB_PATH" "VACUUM;"

    if [[ $? -eq 0 ]]; then
        print_message PASS "Database optimized"
    else
        print_message FAIL "Database optimization failed"
        return 1
    fi
}

# Sync database versions with actual installed versions
# Usage: db_sync_versions
db_sync_versions() {
    if [[ -z "$DB_PATH" ]]; then
        print_message FAIL "Database not initialized. Call db_init first."
        return 1
    fi

    print_message INFO "Syncing database versions with installed packages..."

    local updated_count=0
    local checked_count=0

    # Get all apps from database
    local db_apps
    db_apps=$(sqlite3 "$DB_PATH" "SELECT app_id, install_method, metadata FROM installed_apps;")

    if [[ -z "$db_apps" ]]; then
        print_message INFO "No apps in database to sync"
        return 0
    fi

    while IFS='|' read -r app_id install_method metadata; do
        ((checked_count++))

        case "$install_method" in
            apt_repo|apt|apt_package)
                # Extract package name from metadata
                local package_name
                package_name=$(echo "$metadata" | jq -r '.package // empty' 2>/dev/null)

                if [[ -z "$package_name" ]] || [[ "$package_name" == "null" ]]; then
                    # Try to get from config
                    package_name=$(get_app_config "$app_id" 2>/dev/null | jq -r '.source.package_name // empty')
                fi

                if [[ -n "$package_name" ]] && [[ "$package_name" != "null" ]]; then
                    # Get current installed version
                    if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
                        local current_version
                        current_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null)

                        # Get database version
                        local db_version
                        db_version=$(sqlite3 "$DB_PATH" "SELECT version FROM installed_apps WHERE app_id='${app_id}';")

                        # Update if different
                        if [[ "$current_version" != "$db_version" ]]; then
                            sqlite3 "$DB_PATH" "UPDATE installed_apps SET version='${current_version//\'/\'\'}' WHERE app_id='${app_id//\'/\'\'}';"
                            print_message INFO "Updated ${app_id}: ${db_version} → ${current_version}"
                            ((updated_count++))
                        fi
                    fi
                fi
                ;;
            deb)
                # Extract package name from metadata
                local package_name
                package_name=$(echo "$metadata" | jq -r '.package // empty' 2>/dev/null)

                if [[ -n "$package_name" ]] && [[ "$package_name" != "null" ]]; then
                    if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
                        local current_version
                        current_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null)

                        local db_version
                        db_version=$(sqlite3 "$DB_PATH" "SELECT version FROM installed_apps WHERE app_id='${app_id}';")

                        if [[ "$current_version" != "$db_version" ]]; then
                            sqlite3 "$DB_PATH" "UPDATE installed_apps SET version='${current_version//\'/\'\'}' WHERE app_id='${app_id//\'/\'\'}';"
                            print_message INFO "Updated ${app_id}: ${db_version} → ${current_version}"
                            ((updated_count++))
                        fi
                    fi
                fi
                ;;
            *)
                # AppImage, tarball, installer - versions don't auto-update via apt
                ;;
        esac
    done <<< "$db_apps"

    if [[ $updated_count -gt 0 ]]; then
        print_message PASS "Synced ${updated_count} of ${checked_count} package versions"
    else
        print_message INFO "All ${checked_count} package versions are current"
    fi
}
