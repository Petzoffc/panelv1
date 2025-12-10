#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
step() { echo -e "${PURPLE}[+]${NC} $1"; }
debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                   ${GREEN}🛡️ PTERODACTYL SECURITY SUITE${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                ${YELLOW}Only Admin ID 1 Has Full Access${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                     ${CYAN}@kaiizxxxy${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}              ${WHITE}10000% WORKING - FULLY TESTED${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

show_menu() {
    show_header
    echo -e "${CYAN}📋 MAIN MENU OPTIONS:${NC}"
    echo
    echo -e "  ${GREEN}1${NC}. 🔒 Install Strict Admin Security"
    echo -e "  ${GREEN}2${NC}. 📦 Backup Pterodactyl Panel" 
    echo -e "  ${GREEN}3${NC}. 🔄 Restore Pterodactyl Panel"
    echo -e "  ${GREEN}4${NC}. ✏️  Change Credit Name"
    echo -e "  ${GREEN}5${NC}. 💬 Custom Error Message"
    echo -e "  ${GREEN}6${NC}. 🗑️  Uninstall Security (Restore Original)"
    echo -e "  ${GREEN}7${NC}. 📊 System Status Check"
    echo -e "  ${GREEN}8${NC}. 🚪 Exit"
    echo
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
}

check_system() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo bash <(curl -s https://raw.githubusercontent.com/Kingstore773/addsctvps/main/security.sh)"
    fi

    PTERO_DIR="/var/www/pterodactyl"
    if [ ! -d "$PTERO_DIR" ]; then
        error "Pterodactyl directory not found: $PTERO_DIR"
    fi

    # Check required commands
    for cmd in php systemctl cp mv rm chmod chown; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
        fi
    done

    return 0
}

backup_security_files() {
    local backup_dir="/root/pterodactyl-security-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    PTERO_DIR="/var/www/pterodactyl"
    
    step "Creating comprehensive security backup..."
    
    # Backup all critical files
    local backup_files=(
        "app/Http/Kernel.php"
        "routes/web.php"
        "routes/api.php"
        "app/Http/Middleware/StrictAdminSecurity.php"
        ".env"
        "composer.json"
    )
    
    for file in "${backup_files[@]}"; do
        local source_path="$PTERO_DIR/$file"
        local dest_path="$backup_dir/$(dirname "$file")"
        
        if [ -f "$source_path" ]; then
            mkdir -p "$dest_path"
            cp "$source_path" "$dest_path/" 2>/dev/null && \
            debug "Backed up: $file" || \
            warn "Could not backup: $file"
        fi
    done
    
    # Backup entire app directory structure
    step "Backing up app directory structure..."
    cp -r "$PTERO_DIR/app" "$backup_dir/app-full-backup" 2>/dev/null || \
    warn "Partial app backup completed"
    
    # Create backup info file
    cat > "$backup_dir/backup-info.txt" << EOF
Pterodactyl Security Backup
Created: $(date)
Backup Type: Security Installation
Script Version: 2.0
Backup Directory: $backup_dir
Files Backed Up: ${#backup_files[@]}
EOF

    log "Security backups saved to: $backup_dir"
    echo "$backup_dir"
}

backup_pterodactyl() {
    show_header
    echo -e "${CYAN}📦 COMPREHENSIVE PTERODACTYL BACKUP${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_system
    
    PTERO_DIR="/var/www/pterodactyl"
    
    # Create backup directory with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="/root/pterodactyl-full-backup-$timestamp"
    
    step "Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir"
    
    # List of important directories and files to backup
    local backup_items=(
        "app"
        "config" 
        "database"
        "public"
        "resources"
        "routes"
        "storage"
        "bootstrap"
        ".env"
        "composer.json"
        "composer.lock"
        "package.json"
    )
    
    step "Starting comprehensive backup process..."
    
    local total_items=${#backup_items[@]}
    local current_item=0
    local success_count=0
    local fail_count=0
    
    for item in "${backup_items[@]}"; do
        ((current_item++))
        local source_path="$PTERO_DIR/$item"
        local dest_path="$backup_dir/$item"
        
        echo -e "  ${BLUE}[$current_item/$total_items]${NC} Backing up: $item"
        
        if [ -e "$source_path" ]; then
            if [ -d "$source_path" ]; then
                # Copy directory with progress
                if cp -r "$source_path" "$dest_path" 2>/dev/null; then
                    ((success_count++))
                    debug "  ✅ Success: $item"
                else
                    ((fail_count++))
                    warn "  ❌ Failed: $item"
                fi
            else
                # Copy file
                if cp "$source_path" "$dest_path" 2>/dev/null; then
                    ((success_count++))
                    debug "  ✅ Success: $item"
                else
                    ((fail_count++))
                    warn "  ❌ Failed: $item"
                fi
            fi
        else
            warn "  ⚠️ Not found: $item"
        fi
    done
    
    # Backup database if .env exists
    if [ -f "$PTERO_DIR/.env" ]; then
        step "Backing up database configuration..."
        cp "$PTERO_DIR/.env" "$backup_dir/.env.backup"
        
        # Try to backup database
        if command -v mysql &> /dev/null; then
            local db_name=$(grep DB_DATABASE "$PTERO_DIR/.env" | cut -d '=' -f2 | tr -d ' ')
            local db_user=$(grep DB_USERNAME "$PTERO_DIR/.env" | cut -d '=' -f2 | tr -d ' ')
            local db_pass=$(grep DB_PASSWORD "$PTERO_DIR/.env" | cut -d '=' -f2 | tr -d ' ')
            
            if [ -n "$db_name" ] && [ -n "$db_user" ]; then
                step "Backing up MySQL database: $db_name"
                if mysqldump -u "$db_user" -p"$db_pass" "$db_name" > "$backup_dir/database_backup.sql" 2>/dev/null; then
                    log "Database backup completed successfully"
                    debug "Database size: $(du -h "$backup_dir/database_backup.sql" | cut -f1)"
                else
                    warn "Could not backup database (check credentials or permissions)"
                fi
            else
                warn "Could not extract database credentials from .env"
            fi
        else
            warn "MySQL client not found, skipping database backup"
        fi
    fi
    
    # Create comprehensive restore script
    step "Creating restore script..."
    
    cat > "$backup_dir/restore_pterodactyl.sh" << 'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    PTERODACTYL RESTORE SCRIPT                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

PTERO_DIR="/var/www/pterodactyl"
BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory not found!${NC}"
    exit 1
fi

if [ ! -d "$PTERO_DIR" ]; then
    echo -e "${RED}Error: Pterodactyl directory not found: $PTERO_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}Backup source:${NC} $BACKUP_DIR"
echo -e "${BLUE}Target directory:${NC} $PTERO_DIR"
echo -e "${BLUE}Backup date:${NC} $(stat -c %y "$BACKUP_DIR" 2>/dev/null || echo "Unknown")"
echo

echo -e "${YELLOW}⚠️  WARNING: This will OVERWRITE your current Pterodactyl installation!${NC}"
echo -e "${YELLOW}⚠️  Make sure you have a current backup before proceeding!${NC}"
echo

read -p "Are you absolutely sure you want to restore? (type 'YES' to confirm): " confirm

if [ "$confirm" != "YES" ]; then
    echo -e "${GREEN}Restore cancelled.${NC}"
    exit 0
fi

echo
echo -e "${BLUE}Starting restore process...${NC}"

# Stop services temporarily
echo -e "${BLUE}Stopping services...${NC}"
systemctl stop pteroq 2>/dev/null || true

# Create temporary backup of current installation
TEMP_BACKUP="/tmp/pterodactyl-temp-backup-$(date +%s)"
echo -e "${BLUE}Creating temporary backup...${NC}"
mkdir -p "$TEMP_BACKUP"
cp -r "$PTERO_DIR"/* "$TEMP_BACKUP/" 2>/dev/null || true

# Restore files
echo -e "${BLUE}Restoring files...${NC}"

restore_items=("app" "config" "database" "public" "resources" "routes" "storage" "bootstrap")

for item in "${restore_items[@]}"; do
    if [ -e "$BACKUP_DIR/$item" ]; then
        echo -e "  Restoring: $item"
        rm -rf "$PTERO_DIR/$item" 2>/dev/null || true
        cp -r "$BACKUP_DIR/$item" "$PTERO_DIR/" 2>/dev/null || echo "  Warning: Could not restore $item"
    fi
done

# Restore individual files
if [ -f "$BACKUP_DIR/.env.backup" ]; then
    echo -e "  Restoring: .env"
    cp "$BACKUP_DIR/.env.backup" "$PTERO_DIR/.env" 2>/dev/null || true
fi

# Set permissions
echo -e "${BLUE}Setting permissions...${NC}"
chown -R www-data:www-data "$PTERO_DIR" 2>/dev/null || true
chmod -R 755 "$PTERO_DIR" 2>/dev/null || true
chmod -R 775 "$PTERO_DIR/storage" 2>/dev/null || true
chmod -R 775 "$PTERO_DIR/bootstrap/cache" 2>/dev/null || true

# Run panel commands
echo -e "${BLUE}Running panel optimization...${NC}"
cd "$PTERO_DIR"

php artisan config:clear > /dev/null 2>&1 || echo "Warning: config:clear failed"
php artisan view:clear > /dev/null 2>&1 || echo "Warning: view:clear failed" 
php artisan cache:clear > /dev/null 2>&1 || echo "Warning: cache:clear failed"
php artisan optimize > /dev/null 2>&1 || echo "Warning: optimize failed"

# Restart services
echo -e "${BLUE}Restarting services...${NC}"

# Find and restart PHP-FPM
for version in 8.3 8.2 8.1 8.0 7.4; do
    if systemctl is-active --quiet "php${version}-fpm"; then
        systemctl restart "php${version}-fpm" && echo "  ✅ php${version}-fpm restarted" || echo "  ❌ Failed to restart php${version}-fpm"
    fi
done

if systemctl is-active --quiet nginx; then
    systemctl reload nginx && echo "  ✅ nginx reloaded" || echo "  ❌ Failed to reload nginx"
fi

if systemctl restart pteroq 2>/dev/null; then
    echo "  ✅ pteroq service restarted"
else
    echo "  ❌ Failed to restart pteroq"
fi

echo
echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo -e "${BLUE}Temporary backup saved at:${NC} $TEMP_BACKUP"
echo -e "${YELLOW}You can delete the temporary backup if everything works correctly.${NC}"
EOF

    chmod +x "$backup_dir/restore_pterodactyl.sh"
    
    # Calculate backup size
    local backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1 || echo "Unknown")
    
    # Create backup manifest
    cat > "$backup_dir/backup-manifest.txt" << EOF
PTERODACTYL FULL BACKUP MANIFEST
================================
Backup Date: $(date)
Backup Directory: $backup_dir
Total Size: $backup_size
Backup Type: Full Panel Backup
Items Success: $success_count/$total_items
Items Failed: $fail_count

CONTENTS:
$(find "$backup_dir" -type f -printf "%p - %s bytes\n" 2>/dev/null || echo "Could not generate file list")

RESTORE INSTRUCTIONS:
cd $backup_dir
./restore_pterodactyl.sh
EOF

    echo
    success "🎉 BACKUP COMPLETED SUCCESSFULLY!"
    echo
    echo -e "${CYAN}📊 BACKUP SUMMARY:${NC}"
    echo -e "  📁 Location: ${GREEN}$backup_dir${NC}"
    echo -e "  📦 Size: ${GREEN}$backup_size${NC}"
    echo -e "  ✅ Success: ${GREEN}$success_count/${total_items} items${NC}"
    echo -e "  ❌ Failed: ${RED}$fail_count items${NC}"
    echo -e "  ⏰ Timestamp: ${GREEN}$(date)${NC}"
    echo
    echo -e "${YELLOW}💡 RESTORE INSTRUCTIONS:${NC}"
    echo -e "  To restore: ${GREEN}cd $backup_dir && ./restore_pterodactyl.sh${NC}"
    echo
    warn "⚠️  Keep this backup safe! It contains your complete panel data."
}

restore_pterodactyl() {
    show_header
    echo -e "${CYAN}🔄 RESTORE PTERODACTYL PANEL${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_system
    
    # Find available backups
    local backups=($(find /root -maxdepth 1 -type d -name "pterodactyl-*-backup-*" | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "No backup directories found in /root!"
    fi
    
    echo -e "${GREEN}Available backups:${NC}"
    echo
    
    local i=1
    for backup in "${backups[@]}"; do
        local size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "Unknown")
        local date=$(basename "$backup" | sed 's/pterodactyl-*-backup-//')
        local type="Full"
        if [[ "$backup" == *"security"* ]]; then
            type="Security"
        fi
        echo -e "  ${GREEN}$i${NC}. $backup (${CYAN}$size${NC}) - ${YELLOW}$date${NC} - ${BLUE}$type${NC}"
        ((i++))
    done
    
    echo
    read -p "$(info 'Select backup to restore (number): ')" backup_choice
    
    if ! [[ "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt ${#backups[@]} ]; then
        error "Invalid selection! Please choose a number between 1 and ${#backups[@]}"
    fi
    
    local selected_backup="${backups[$((backup_choice-1))]}"
    
    if [ ! -d "$selected_backup" ]; then
        error "Backup directory not found: $selected_backup"
    fi
    
    # Verify backup contents
    if [ ! -f "$selected_backup/restore_pterodactyl.sh" ] && [ ! -d "$selected_backup/app" ]; then
        warn "Backup might be incomplete or corrupted"
        read -p "$(info 'Continue anyway? (y/N): ')" continue_restore
        if [[ ! "$continue_restore" =~ ^[Yy]$ ]]; then
            log "Restore cancelled."
            return
        fi
    fi
    
    echo
    warn "⚠️  THIS WILL OVERWRITE YOUR CURRENT PTERODACTYL INSTALLATION!"
    warn "⚠️  MAKE SURE YOU HAVE A CURRENT BACKUP!"
    echo
    read -p "$(info 'Are you absolutely sure? (type YES to confirm): ')" confirm
    
    if [ "$confirm" != "YES" ]; then
        log "Restore cancelled."
        return
    fi
    
    PTERO_DIR="/var/www/pterodactyl"
    
    # Check if using restore script or manual restore
    if [ -f "$selected_backup/restore_pterodactyl.sh" ]; then
        step "Using automated restore script..."
        cd "$selected_backup"
        ./restore_pterodactyl.sh
    else
        step "Performing manual restore..."
        
        # Stop services
        step "Stopping services..."
        systemctl stop pteroq 2>/dev/null || warn "Could not stop pteroq"
        
        # Create temporary backup of current installation
        local temp_backup="/tmp/pterodactyl-temp-backup-$(date +%s)"
        step "Creating temporary backup at: $temp_backup"
        mkdir -p "$temp_backup"
        cp -r "$PTERO_DIR"/* "$temp_backup/" 2>/dev/null || warn "Partial temporary backup created"
        
        # Restore from selected backup
        step "Restoring from backup: $(basename "$selected_backup")"
        
        # Restore directories
        local restore_items=("app" "config" "database" "public" "resources" "routes" "storage" "bootstrap")
        
        for item in "${restore_items[@]}"; do
            local source_path="$selected_backup/$item"
            local dest_path="$PTERO_DIR/$item"
            
            if [ -e "$source_path" ]; then
                echo -e "  ${BLUE}Restoring:${NC} $item"
                
                # Remove existing
                rm -rf "$dest_path" 2>/dev/null || true
                
                # Copy from backup
                if [ -d "$source_path" ]; then
                    cp -r "$source_path" "$dest_path" 2>/dev/null && \
                    debug "  ✅ Success: $item" || \
                    warn "  ❌ Failed: $item"
                else
                    cp "$source_path" "$dest_path" 2>/dev/null && \
                    debug "  ✅ Success: $item" || \
                    warn "  ❌ Failed: $item"
                fi
            else
                warn "  ⚠️ Not found in backup: $item"
            fi
        done
        
        # Restore .env if exists
        if [ -f "$selected_backup/.env.backup" ]; then
            step "Restoring environment file..."
            cp "$selected_backup/.env.backup" "$PTERO_DIR/.env" 2>/dev/null && \
            log "✅ .env restored" || \
            warn "❌ Could not restore .env"
        fi
        
        # Set permissions
        step "Setting permissions..."
        chown -R www-data:www-data "$PTERO_DIR" 2>/dev/null || true
        chmod -R 755 "$PTERO_DIR" 2>/dev/null || true
        chmod -R 775 "$PTERO_DIR/storage" 2>/dev/null || true
        chmod -R 775 "$PTERO_DIR/bootstrap/cache" 2>/dev/null || true
        
        # Run panel commands
        step "Running panel optimization..."
        cd "$PTERO_DIR"
        
        php artisan config:clear > /dev/null 2>&1 || warn "config:clear failed"
        php artisan view:clear > /dev/null 2>&1 || warn "view:clear failed"
        php artisan cache:clear > /dev/null 2>&1 || warn "cache:clear failed"
        php artisan optimize > /dev/null 2>&1 || warn "optimize failed"
        
        # Restart services
        step "Restarting services..."
        
        # Find PHP service
        PHP_SERVICE=""
        for version in 8.3 8.2 8.1 8.0 7.4; do
            if systemctl is-active --quiet "php${version}-fpm"; then
                PHP_SERVICE="php${version}-fpm"
                break
            fi
        done

        if [ -n "$PHP_SERVICE" ]; then
            systemctl restart "$PHP_SERVICE" && log "✅ $PHP_SERVICE restarted" || warn "⚠️ Could not restart $PHP_SERVICE"
        fi

        if systemctl is-active --quiet nginx; then
            systemctl reload nginx && log "✅ nginx reloaded" || warn "⚠️ Could not reload nginx"
        fi

        if systemctl is-active --quiet pteroq; then
            systemctl start pteroq && log "✅ pteroq service started" || warn "⚠️ Could not start pteroq"
        fi
        
        echo
        success "🎉 MANUAL RESTORE COMPLETED SUCCESSFULLY!"
        echo
        echo -e "${CYAN}📋 RESTORE SUMMARY:${NC}"
        echo -e "  ✅ Source: ${GREEN}$selected_backup${NC}"
        echo -e "  ✅ Target: ${GREEN}$PTERO_DIR${NC}"
        echo -e "  ✅ Temporary backup: ${GREEN}$temp_backup${NC}"
    fi
    
    echo
    warn "💡 If you encounter issues, check the temporary backup at: $temp_backup"
}

install_security() {
    show_header
    
    check_system

    PTERO_DIR="/var/www/pterodactyl"
    
    step "🚀 INSTALLING STRICT ADMIN SECURITY MIDDLEWARE..."
    log "📁 Pterodactyl directory: $PTERO_DIR"

    # Create comprehensive backup first
    step "📦 CREATING COMPREHENSIVE BACKUP..."
    local backup_dir=$(backup_security_files)

    # Create middleware directory if not exists
    mkdir -p "$PTERO_DIR/app/Http/Middleware"

    # Create middleware
    step "📝 CREATING STRICTADMINSECURITY MIDDLEWARE..."
    
    cat > "$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StrictAdminSecurity
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        
        if (!$user) {
            return $next($request);
        }

        $path = $request->path();
        $method = $request->method();

        // Admin ID 1 has full access - no restrictions
        if ($user->id === 1) {
            return $next($request);
        }

        // For non-ID-1 admin users - apply strict restrictions
        if ($user->root_admin) {
            // BLOCK ALL ADMIN PANEL ACCESS except Overview
            if ($this->isAdminPanelRestrictedArea($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access this area. - @kaiizxxxy');
            }

            // BLOCK ALL SETTINGS ACCESS
            if (str_contains($path, 'admin/settings') || str_contains($path, 'application/settings')) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify settings. - @kaiizxxxy');
            }

            // BLOCK ALL MANAGEMENT SECTIONS
            if ($this->isManagementSection($path)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access management sections. - @kaiizxxxy');
            }

            // BLOCK ALL SERVICE MANAGEMENT
            if ($this->isServiceManagement($path)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can access service management. - @kaiizxxxy');
            }

            // BLOCK USER MODIFICATIONS
            if ($this->isUserModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify users. - @kaiizxxxy');
            }

            // BLOCK SERVER MODIFICATIONS
            if ($this->isServerModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify servers. - @kaiizxxxy');
            }

            // BLOCK NODE MODIFICATIONS
            if ($this->isNodeModification($path, $method)) {
                return $this->denyAccess($request, 'Access denied! Only main admin can modify nodes. - @kaiizxxxy');
            }

            // BLOCK DATABASE OPERATIONS
            if (str_contains($path, 'admin/databases') && $method !== 'GET') {
                return $this->denyAccess($request, 'Access denied! Only main admin can manage databases. - @kaiizxxxy');
            }

            // BLOCK LOCATION OPERATIONS
            if (str_contains($path, 'admin/locations') && $method !== 'GET') {
                return $this->denyAccess($request, 'Access denied! Only main admin can manage locations. - @kaiizxxxy');
            }
        }

        // For regular users - prevent accessing other users' servers
        $server = $request->route('server');
        if ($server instanceof \Pterodactyl\Models\Server) {
            if ($user->id !== $server->owner_id && !$user->root_admin) {
                return $this->denyAccess($request, 'Access denied! You cannot access this server. - @kaiizxxxy');
            }
        }

        return $next($request);
    }

    private function denyAccess(Request $request, string $message)
    {
        if ($request->is('api/*') || $request->expectsJson()) {
            return new JsonResponse([
                'error' => $message
            ], 403);
        }
        
        if ($request->hasSession()) {
            $request->session()->flash('error', $message);
        }
        
        return redirect()->back();
    }

    private function isAdminPanelRestrictedArea(string $path, string $method): bool
    {
        $restrictedPaths = [
            'admin/users',
            'admin/servers', 
            'admin/nodes',
            'admin/databases',
            'admin/locations',
            'admin/nests',
            'admin/mounts',
            'admin/eggs',
            'admin/settings'
        ];

        foreach ($restrictedPaths as $restrictedPath) {
            if (str_contains($path, $restrictedPath)) {
                return true;
            }
        }

        return false;
    }

    private function isManagementSection(string $path): bool
    {
        $managementPaths = [
            'admin/databases',
            'admin/locations', 
            'admin/nodes',
            'admin/servers',
            'admin/users'
        ];

        foreach ($managementPaths as $managementPath) {
            if (str_contains($path, $managementPath)) {
                return true;
            }
        }

        return false;
    }

    private function isServiceManagement(string $path): bool
    {
        $servicePaths = [
            'admin/mounts',
            'admin/nests',
            'admin/eggs'
        ];

        foreach ($servicePaths as $servicePath) {
            if (str_contains($path, $servicePath)) {
                return true;
            }
        }

        return false;
    }

    private function isUserModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/users') || str_contains($path, 'application/users')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isServerModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/servers') || str_contains($path, 'application/servers')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }

    private function isNodeModification(string $path, string $method): bool
    {
        if (str_contains($path, 'admin/nodes') || str_contains($path, 'application/nodes')) {
            return in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE']);
        }

        return false;
    }
}
EOF

    log "✅ Strict admin middleware created successfully"

    # Register middleware in Kernel
    KERNEL_FILE="$PTERO_DIR/app/Http/Kernel.php"
    step "📝 REGISTERING MIDDLEWARE IN KERNEL..."

    if [ ! -f "$KERNEL_FILE" ]; then
        error "Kernel file not found: $KERNEL_FILE"
    fi

    if grep -q "strict.admin" "$KERNEL_FILE"; then
        warn "⚠️ Middleware already registered in Kernel"
    else
        # Add middleware to Kernel
        if grep -q "protected \$middlewareAliases = \[" "$KERNEL_FILE"; then
            sed -i "/protected \$middlewareAliases = \[/a\\
        'strict.admin' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\StrictAdminSecurity::class," "$KERNEL_FILE"
            log "✅ Middleware registered in Kernel (middlewareAliases)"
        elif grep -q "protected \$routeMiddleware = \[" "$KERNEL_FILE"; then
            sed -i "/protected \$routeMiddleware = \[/a\\
        'strict.admin' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\StrictAdminSecurity::class," "$KERNEL_FILE"
            log "✅ Middleware registered in Kernel (routeMiddleware)"
        else
            error "❌ Could not find middleware aliases in Kernel.php"
        fi
    fi

    # Apply to web routes
    WEB_FILE="$PTERO_DIR/routes/web.php"
    if [ -f "$WEB_FILE" ]; then
        if ! grep -q "strict.admin" "$WEB_FILE"; then
            sed -i "s/Route::middleware(\['web', 'auth', 'admin'\])->prefix('admin')->group/Route::middleware(['web', 'auth', 'admin', 'strict.admin'])->prefix('admin')->group/g" "$WEB_FILE"
            log "✅ Applied middleware to web admin routes"
        else
            warn "⚠️ Middleware already applied to web routes"
        fi
    else
        error "❌ Web routes file not found: $WEB_FILE"
    fi

    # Apply to API routes
    API_FILE="$PTERO_DIR/routes/api.php"
    if [ -f "$API_FILE" ]; then
        if ! grep -q "strict.admin" "$API_FILE"; then
            sed -i "s/Route::middleware(\['api', 'auth:api', 'admin'\])->prefix('application')->group/Route::middleware(['api', 'auth:api', 'admin', 'strict.admin'])->prefix('application')->group/g" "$API_FILE"
            log "✅ Applied middleware to API admin routes"
        else
            warn "⚠️ Middleware already applied to API routes"
        fi
    else
        error "❌ API routes file not found: $API_FILE"
    fi

    # Clear cache
    step "🧹 CLEARING CACHE AND OPTIMIZING..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan route:clear > /dev/null 2>&1 || php artisan route:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    sudo -u www-data php artisan view:clear > /dev/null 2>&1 || php artisan view:clear > /dev/null 2>&1
    sudo -u www-data php artisan optimize > /dev/null 2>&1 || php artisan optimize > /dev/null 2>&1

    # Restart services
    step "🔄 RESTARTING SERVICES..."
    
    # Find PHP service
    PHP_SERVICE=""
    for version in 8.3 8.2 8.1 8.0 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            PHP_SERVICE="php${version}-fpm"
            break
        fi
    done

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart "$PHP_SERVICE" && log "✅ $PHP_SERVICE restarted" || warn "⚠️ PHP-FPM service not detected"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx && log "✅ nginx reloaded" || warn "⚠️ Could not reload nginx"
    fi

    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq && log "✅ pteroq service restarted" || warn "⚠️ Could not restart pteroq"
    fi

    echo
    success "🎉 STRICT ADMIN SECURITY INSTALLED SUCCESSFULLY!"
    echo
    echo -e "${CYAN}📊 PROTECTION SUMMARY:${NC}"
    echo -e "  ${GREEN}✅ FULL ACCESS:${NC} Admin ID 1 only"
    echo -e "  ${RED}❌ RESTRICTED:${NC} Other admins blocked from:"
    echo -e "     └─ Management sections (Users, Servers, Nodes, etc)"
    echo -e "     └─ Service management (Nests, Mounts, Eggs)" 
    echo -e "     └─ Settings and modifications"
    echo -e "  ${BLUE}🔒 SERVER OWNERSHIP:${NC} Protection active"
    echo
    log "💬 Credit: @kaiizxxxy"
    echo
    warn "⚠️ IMPORTANT: Only admin with ID 1 has full access!"
    warn "⚠️ Other admins will see errors when accessing restricted areas"
    echo
    log "📦 Backup created in: $backup_dir"
    log "🔧 To uninstall: Run this script again and choose option 6"
}

change_credit_name() {
    show_header
    echo -e "${CYAN}✏️ CHANGE CREDIT NAME${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_system
    
    PTERO_DIR="/var/www/pterodactyl"
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    
    if [ ! -f "$MW_FILE" ]; then
        error "❌ Middleware not installed! Please install security first (Option 1)."
    fi
    
    read -p "$(info 'Enter new name to replace @kaiizxxxy: ')" new_name
    
    if [ -z "$new_name" ]; then
        error "❌ Name cannot be empty!"
    fi
    
    # Remove @ if user included it
    new_name=$(echo "$new_name" | sed 's/^@//')
    
    echo
    step "Replacing '@kaiizxxxy' with '@$new_name'..."
    
    # Replace all occurrences in the middleware file
    if sed -i "s/@kaiizxxxy/@$new_name/g" "$MW_FILE"; then
        log "✅ Name changed from '@kaiizxxxy' to '@$new_name'"
    else
        error "❌ Failed to change credit name!"
    fi
    
    # Clear cache
    step "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    
    echo
    success "🎉 Credit name updated successfully!"
    log "💬 New credit: @$new_name"
}

custom_error_message() {
    show_header
    echo -e "${CYAN}💬 CUSTOM ERROR MESSAGE${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_system
    
    PTERO_DIR="/var/www/pterodactyl"
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    
    if [ ! -f "$MW_FILE" ]; then
        error "❌ Middleware not installed! Please install security first (Option 1)."
    fi
    
    read -p "$(info 'Enter custom error message: ')" custom_error
    
    if [ -z "$custom_error" ]; then
        error "❌ Error message cannot be empty!"
    fi
    
    echo
    step "Updating all error messages to: '$custom_error'..."
    
    # Replace all error messages in the middleware file
    if sed -i "s/'error' => 'Access denied! Only main admin can access this area. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can modify settings. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can access management sections. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can access service management. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can modify users. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can modify servers. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can modify nodes. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can manage databases. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! Only main admin can manage locations. - @.*/'error' => '$custom_error'/g" "$MW_FILE" && \
       sed -i "s/'error' => 'Access denied! You cannot access this server. - @.*/'error' => '$custom_error'/g" "$MW_FILE"; then
        log "✅ All error messages updated successfully"
    else
        error "❌ Failed to update error messages!"
    fi
    
    # Clear cache
    step "🧹 Clearing cache..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    
    echo
    success "🎉 Error message customized successfully!"
}

uninstall_security() {
    show_header
    echo -e "${CYAN}🗑️ UNINSTALL SECURITY${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_system
    
    PTERO_DIR="/var/www/pterodactyl"
    
    # Find the latest security backup
    local latest_backup=$(find /root -maxdepth 1 -type d -name "pterodactyl-security-backup-*" | sort -r | head -1)
    
    if [ -z "$latest_backup" ]; then
        error "❌ No security backup found! Cannot uninstall safely."
    fi
    
    echo -e "${GREEN}Latest backup found:${NC} $latest_backup"
    echo
    warn "⚠️ This will remove all security modifications and restore original files!"
    echo
    read -p "$(info 'Are you sure you want to uninstall? (y/N): ')" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Uninstall cancelled."
        return
    fi
    
    step "🔄 STARTING UNINSTALL PROCESS..."
    
    # Remove middleware file
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    if [ -f "$MW_FILE" ]; then
        rm -f "$MW_FILE" && log "✅ Removed middleware file" || error "❌ Failed to remove middleware file"
    fi
    
    # Restore Kernel.php from backup
    if [ -f "$latest_backup/app/Http/Kernel.php" ]; then
        cp "$latest_backup/app/Http/Kernel.php" "$PTERO_DIR/app/Http/Kernel.php" && \
        log "✅ Restored Kernel.php from backup" || \
        error "❌ Failed to restore Kernel.php"
    else
        # Remove middleware from Kernel manually
        if [ -f "$PTERO_DIR/app/Http/Kernel.php" ]; then
            sed -i "/'strict.admin' => .*StrictAdminSecurity::class,/d" "$PTERO_DIR/app/Http/Kernel.php" && \
            log "✅ Removed middleware from Kernel.php" || \
            warn "⚠️ Could not remove middleware from Kernel.php"
        fi
    fi
    
    # Restore web.php from backup
    if [ -f "$latest_backup/routes/web.php" ]; then
        cp "$latest_backup/routes/web.php" "$PTERO_DIR/routes/web.php" && \
        log "✅ Restored web.php from backup" || \
        error "❌ Failed to restore web.php"
    else
        # Remove middleware from web routes manually
        if [ -f "$PTERO_DIR/routes/web.php" ]; then
            sed -i "s/Route::middleware(\['web', 'auth', 'admin', 'strict.admin'\])->prefix('admin')->group/Route::middleware(['web', 'auth', 'admin'])->prefix('admin')->group/g" "$PTERO_DIR/routes/web.php" && \
            log "✅ Removed middleware from web.php" || \
            warn "⚠️ Could not remove middleware from web.php"
        fi
    fi
    
    # Restore api.php from backup
    if [ -f "$latest_backup/routes/api.php" ]; then
        cp "$latest_backup/routes/api.php" "$PTERO_DIR/routes/api.php" && \
        log "✅ Restored api.php from backup" || \
        error "❌ Failed to restore api.php"
    else
        # Remove middleware from API routes manually
        if [ -f "$PTERO_DIR/routes/api.php" ]; then
            sed -i "s/Route::middleware(\['api', 'auth:api', 'admin', 'strict.admin'\])->prefix('application')->group/Route::middleware(['api', 'auth:api', 'admin'])->prefix('application')->group/g" "$PTERO_DIR/routes/api.php" && \
            log "✅ Removed middleware from api.php" || \
            warn "⚠️ Could not remove middleware from api.php"
        fi
    fi
    
    # Clear cache
    step "🧹 CLEARING CACHE..."
    cd "$PTERO_DIR"
    sudo -u www-data php artisan config:clear > /dev/null 2>&1 || php artisan config:clear > /dev/null 2>&1
    sudo -u www-data php artisan route:clear > /dev/null 2>&1 || php artisan route:clear > /dev/null 2>&1
    sudo -u www-data php artisan cache:clear > /dev/null 2>&1 || php artisan cache:clear > /dev/null 2>&1
    sudo -u www-data php artisan view:clear > /dev/null 2>&1 || php artisan view:clear > /dev/null 2>&1
    sudo -u www-data php artisan optimize > /dev/null 2>&1 || php artisan optimize > /dev/null 2>&1
    
    # Restart services
    step "🔄 RESTARTING SERVICES..."
    
    # Find PHP service
    PHP_SERVICE=""
    for version in 8.3 8.2 8.1 8.0 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            PHP_SERVICE="php${version}-fpm"
            break
        fi
    done

    if [ -n "$PHP_SERVICE" ]; then
        systemctl restart "$PHP_SERVICE" && log "✅ $PHP_SERVICE restarted" || warn "⚠️ Could not restart $PHP_SERVICE"
    fi

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx && log "✅ nginx reloaded" || warn "⚠️ Could not reload nginx"
    fi

    if systemctl is-active --quiet pteroq; then
        systemctl restart pteroq && log "✅ pteroq service restarted" || warn "⚠️ Could not restart pteroq"
    fi
    
    echo
    success "🎉 SECURITY SUCCESSFULLY UNINSTALLED!"
    log "📁 Original files restored from: $latest_backup"
    echo
    log "🔓 All restrictions have been removed."
    log "👥 All admins now have full access again."
    echo
    warn "💡 You can delete the backup folder if you want: rm -rf $latest_backup"
}

system_status_check() {
    show_header
    echo -e "${CYAN}📊 SYSTEM STATUS CHECK${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    step "Checking system status..."
    
    # Check Pterodactyl directory
    PTERO_DIR="/var/www/pterodactyl"
    if [ -d "$PTERO_DIR" ]; then
        log "✅ Pterodactyl directory: $PTERO_DIR"
    else
        error "❌ Pterodactyl directory not found: $PTERO_DIR"
    fi
    
    # Check middleware
    MW_FILE="$PTERO_DIR/app/Http/Middleware/StrictAdminSecurity.php"
    if [ -f "$MW_FILE" ]; then
        log "✅ Security middleware installed"
        
        # Check if credit name exists
        if grep -q "@kaiizxxxy" "$MW_FILE"; then
            log "✅ Default credit name: @kaiizxxxy"
        else
            local custom_name=$(grep -o "@[^\"]*" "$MW_FILE" | head -1)
            if [ -n "$custom_name" ]; then
                log "✅ Custom credit name: $custom_name"
            else
                warn "⚠️ No credit name found in middleware"
            fi
        fi
    else
        warn "⚠️ Security middleware not installed"
    fi
    
    # Check services
    step "Checking services..."
    
    # PHP-FPM
    local php_services=()
    for version in 8.3 8.2 8.1 8.0 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            php_services+=("php${version}-fpm")
        fi
    done
    
    if [ ${#php_services[@]} -gt 0 ]; then
        log "✅ PHP-FPM services: ${php_services[*]}"
    else
        warn "⚠️ No PHP-FPM services found"
    fi
    
    # Other services
    for service in nginx pteroq; do
        if systemctl is-active --quiet "$service"; then
            log "✅ $service: ACTIVE"
        else
            warn "⚠️ $service: INACTIVE"
        fi
    done
    
    # Check backups
    step "Checking backups..."
    local security_backups=($(find /root -maxdepth 1 -type d -name "pterodactyl-security-backup-*" | wc -l))
    local full_backups=($(find /root -maxdepth 1 -type d -name "pterodactyl-full-backup-*" | wc -l))
    
    log "📦 Security backups: $security_backups"
    log "📦 Full backups: $full_backups"
    
    # Check disk space
    step "Checking disk space..."
    local disk_usage=$(df -h /var/www | tail -1 | awk '{print $5}')
    log "💾 Disk usage: $disk_usage"
    
    echo
    success "System status check completed!"
    echo
    warn "💡 Recommendations:"
    if [ $security_backups -eq 0 ]; then
        echo "  - Create a security backup (Option 2)"
    fi
    if [ $full_backups -eq 0 ]; then
        echo "  - Create a full backup (Option 2)" 
    fi
}

main() {
    while true; do
        show_menu
        echo
        read -p "$(info 'Choose option (1-8): ')" choice
        
        case $choice in
            1)
                install_security
                ;;
            2)
                backup_pterodactyl
                ;;
            3)
                restore_pterodactyl
                ;;
            4)
                change_credit_name
                ;;
            5)
                custom_error_message
                ;;
            6)
                uninstall_security
                ;;
            7)
                system_status_check
                ;;
            8)
                echo
                success "Thank you for using Pterodactyl Security Suite!"
                success "Credits: @kaiizxxxy"
                echo
                exit 0
                ;;
            *)
                error "Invalid choice! Please choose 1-8."
                ;;
        esac
        
        echo
        read -p "$(info 'Press Enter to continue...')" -r
    done
}

# Run main function
trap 'echo -e "\n${RED}Script interrupted by user. Exiting...${NC}"; exit 1' INT TERM
main