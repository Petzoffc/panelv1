#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[MENU]${NC} $1"
}

# Configuration
APP_DIR="/var/www/pterodactyl"
MW_FILE="$APP_DIR/app/Http/Middleware/CustomSecurityCheck.php"
KERNEL="$APP_DIR/app/Http/Kernel.php"
API_CLIENT="$APP_DIR/routes/api-client.php"
ADMIN_ROUTES="$APP_DIR/routes/admin.php"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
fi

if [ ! -d "$APP_DIR" ]; then
    error "Pterodactyl directory not found: $APP_DIR"
fi

log "🚀 Installing Custom Security Middleware for Pterodactyl..."
log "📁 Pterodactyl directory: $APP_DIR"

STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="/root/pterodactyl-security-backup-$STAMP"
mkdir -p "$BACKUP_DIR"

bk() { [ -f "$1" ] && cp -a "$1" "$BACKUP_DIR/$(basename "$1").bak.$STAMP" && log "  backup: $1 -> $BACKUP_DIR"; }

echo "== MBUTT SECURITY INSTALLER (BOT VERSION) =="
echo "App: $APP_DIR"
echo "Backup: $BACKUP_DIR"

# --- 1) Buat middleware dengan proteksi FULL ADMIN PANEL ---
mkdir -p "$(dirname "$MW_FILE")"
bk "$MW_FILE"
cat >"$MW_FILE" <<'PHP'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Models\User;
use Illuminate\Support\Facades\Log;

class CustomSecurityCheck
{
    public function handle(Request $request, Closure $next)
    {
        $user   = $request->user();
        $path   = strtolower($request->path());
        $method = strtoupper($request->method());

        Log::debug('KingStore Security: incoming request', [
            'user_id'     => $user->id ?? null,
            'root_admin'  => $user->root_admin ?? false,
            'path'        => $path,
            'method'      => $method,
        ]);

        if (!$user) {
            return $next($request);
        }

        // 🔥 SUPER ADMIN CHECK - HANYA ID 1 YANG BISA AKSES SEMUA
        $isSuperAdmin = $user->id === 1;

        // Jika SUPER ADMIN, biarkan akses semua
        if ($isSuperAdmin) {
            Log::info('Super Admin access granted', ['user_id' => $user->id]);
            return $next($request);
        }

        // 🔒 BLOKIR SEMUA ADMIN PANEL ACCESS untuk selain Super Admin
        if ($this->isAccessingAdminPanel($path, $method)) {
            Log::warning('BLOCKED: Non-super admin accessing admin panel', [
                'user_id' => $user->id,
                'path' => $path,
                'method' => $method
            ]);
            return $this->deny($request, 'Hanya Super Admin (ID 1) yang boleh akses Admin Panel! - @MBUTT');
        }

        // 🔒 BLOKIR SEMUA ADMIN API ACCESS untuk selain Super Admin
        if ($this->isAccessingAdminAPI($path, $method)) {
            Log::warning('BLOCKED: Non-super admin accessing admin API', [
                'user_id' => $user->id,
                'path' => $path,
                'method' => $method
            ]);
            return $this->deny($request, 'Hanya Super Admin (ID 1) yang boleh akses Admin API! - @MBUTT');
        }

        // 🔒 BLOKIR SEMUA SETTINGS ACCESS untuk selain Super Admin
        if ($this->isAccessingSettings($path, $method)) {
            Log::warning('BLOCKED: Non-super admin accessing settings', [
                'user_id' => $user->id,
                'path' => $path,
                'method' => $method
            ]);
            return $this->deny($request, 'Hanya Super Admin (ID 1) yang boleh akses Settings! - @MBUTT');
        }

        // Untuk SERVER OPERATIONS, cek kepemilikan
        $server = $request->route('server');
        if ($server instanceof Server) {
            $isServerOwner = $user->id === $server->owner_id;
            
            // 🔒 BLOKIR START/STOP/RESTART untuk selain owner
            if (!$isServerOwner && $this->isServerPowerOperation($path, $method)) {
                Log::warning('BLOCKED: Non-owner attempting server power operation', [
                    'user_id' => $user->id,
                    'server_id' => $server->id,
                    'path' => $path,
                    'method' => $method
                ]);
                return $this->deny($request, 'Hanya pemilik server yang boleh kontrol power! - @MBUTT');
            }

            // 🔒 BLOKIR FILE MANAGER ACCESS untuk selain owner
            if (!$isServerOwner && $this->isAccessingFileManager($path, $method)) {
                Log::warning('BLOCKED: Non-owner accessing file manager', [
                    'user_id' => $user->id,
                    'server_id' => $server->id,
                    'path' => $path,
                    'method' => $method
                ]);
                return $this->deny($request, 'File manager tidak dapat diakses! - @MBUTT');
            }

            // 🔒 BLOKIR BACKUP OPERATIONS untuk selain owner
            if (!$isServerOwner && $this->isBackupOperation($path, $method)) {
                Log::warning('BLOCKED: Non-owner attempting backup operation', [
                    'user_id' => $user->id,
                    'server_id' => $server->id,
                    'path' => $path,
                    'method' => $method
                ]);
                return $this->deny($request, 'Hanya pemilik server yang boleh akses backup! - @MBUTT');
            }
        }

        return $next($request);
    }

    private function deny(Request $request, string $message)
    {
        if ($request->is('api/*') || $request->expectsJson()) {
            return response()->json(['error' => $message], 403);
        }
        if ($request->hasSession()) {
            $request->session()->flash('error', $message);
        }
        return redirect()->back();
    }

    /**
     * 🔒 Deteksi akses ke SEMUA ADMIN PANEL
     * BASIC ADMINISTRATION + MANAGEMENT + SERVICE MANAGEMENT
     */
    private function isAccessingAdminPanel(string $path, string $method): bool
    {
        // BASIC ADMINISTRATION
        $basicAdminPaths = [
            'admin', // Dashboard utama
            'admin/overview',
            'admin/settings',
            'admin/application/api',
            'admin/api'
        ];

        // MANAGEMENT SECTION  
        $managementPaths = [
            'admin/databases',
            'admin/locations', 
            'admin/nodes',
            'admin/servers',
            'admin/users'
        ];

        // SERVICE MANAGEMENT
        $servicePaths = [
            'admin/mounts',
            'admin/nests',
            'admin/eggs'
        ];

        $allAdminPaths = array_merge($basicAdminPaths, $managementPaths, $servicePaths);

        foreach ($allAdminPaths as $adminPath) {
            if (str_starts_with($path, $adminPath)) {
                return true;
            }
        }

        // Blokir semua route yang mengandung 'admin'
        if (str_contains($path, 'admin/') && !str_contains($path, 'admin/api')) {
            return true;
        }

        return false;
    }

    /**
     * 🔒 Deteksi akses ke ADMIN API
     */
    private function isAccessingAdminAPI(string $path, string $method): bool
    {
        $adminAPIPaths = [
            'api/application',
            'application/api'
        ];

        foreach ($adminAPIPaths as $apiPath) {
            if (str_starts_with($path, $apiPath)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 🔒 Deteksi akses ke SETTINGS
     */
    private function isAccessingSettings(string $path, string $method): bool
    {
        $settingsPaths = [
            'admin/settings',
            'application/settings',
            'account/settings',
            'user/settings',
            'server/settings'
        ];

        foreach ($settingsPaths as $settingsPath) {
            if (str_contains($path, $settingsPath)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 🔒 Deteksi server power operations (start/stop/restart)
     */
    private function isServerPowerOperation(string $path, string $method): bool
    {
        $powerOperations = [
            'power/start',
            'power/stop', 
            'power/restart',
            'power/kill',
            'server/power'
        ];

        foreach ($powerOperations as $operation) {
            if (str_contains($path, $operation) && $method === 'POST') {
                return true;
            }
        }

        // API power operations
        if (preg_match('#api/client/servers/[^/]+/power#', $path) && $method === 'POST') {
            return true;
        }

        return false;
    }

    /**
     * 🔒 Deteksi akses file manager
     */
    private function isAccessingFileManager(string $path, string $method): bool
    {
        $fileManagerPaths = [
            'files',
            'filemanager',
            'server/files',
            'api/client/servers/' && str_contains($path, '/files')
        ];

        foreach ($fileManagerPaths as $filePath) {
            if (str_contains($path, $filePath) && $method === 'GET') {
                return true;
            }
        }

        return false;
    }

    /**
     * 🔒 Deteksi backup operations
     */
    private function isBackupOperation(string $path, string $method): bool
    {
        $backupPaths = [
            'backups',
            'server/backups',
            'backup',
            'api/client/servers/' && str_contains($path, '/backups')
        ];

        foreach ($backupPaths as $backupPath) {
            if (str_contains($path, $backupPath)) {
                return true;
            }
        }

        return false;
    }
}
PHP
    log "1) Security Middleware written: $MW_FILE"

    # --- 2) Kernel alias ---
    if [ -f "$KERNEL" ]; then
      bk "$KERNEL"
      php <<PHP
<?php
\$f = '$KERNEL';
\$s = file_get_contents(\$f);
\$alias = "'custom.security' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\CustomSecurityCheck::class,";
if (strpos(\$s, "'custom.security'") !== false) { echo "2) Kernel alias already present\n"; exit; }

\$patterns = [
    '/(\\\$middlewareAliases\\s*=\\s*\\[)([\\s\\S]*?)(\\n\\s*\\];)/',
    '/(\\\$routeMiddleware\\s*=\\s*\\[)([\\s\\S]*?)(\\n\\s*\\];)/',
];
\$done = false;
foreach (\$patterns as \$p) {
    \$s2 = preg_replace_callback(\$p, function(\$m) use (\$alias){
        \$body = rtrim(\$m[2]);
        if (\$body !== '' && substr(trim(\$body), -1) !== ',') \$body .= ',';
        \$body .= "\\n        " . \$alias;
        return \$m[1] . \$body . \$m[3];
    }, \$s, 1, \$cnt);
    if (\$cnt > 0) { \$s = \$s2; \$done = true; break; }
}
if (!\$done) { fwrite(STDERR, "2) ERROR: \$middlewareAliases / \$routeMiddleware not found\n"); exit(1); }
file_put_contents(\$f, \$s);
echo "2) Kernel alias inserted\n";
PHP
    else
      echo "2) WARN: Kernel.php not found, skipped"
    fi

    # --- 3) api-client.php patch ---
    if [ -f "$API_CLIENT" ]; then
      bk "$API_CLIENT"
      php <<PHP
<?php
\$f = '$API_CLIENT';
\$s = file_get_contents(\$f);
if (stripos(\$s, "custom.security") !== false) { echo "3) api-client.php already has custom.security\n"; exit; }

\$changed = false;
\$s = preg_replace_callback('/(middleware\\s*=>\\s*\\[)([\\s\\S]*?)(\\])/i', function(\$m) use (&\$changed) {
    \$body = \$m[2];
    if (stripos(\$body, 'AuthenticateServerAccess::class') !== false) {
        if (stripos(\$body, 'custom.security') === false) {
            \$b = rtrim(\$body);
            if (\$b !== '' && substr(trim(\$b), -1) !== ',') \$b .= ',';
            \$b .= "\\n        'custom.security'";
            \$changed = true;
            return \$m[1] . \$b . \$m[3];
        }
    }
    return \$m[0];
}, \$s, -1);

if (\$changed) {
    file_put_contents(\$f, \$s);
    echo "3) api-client.php patched\n";
} else {
    echo "3) NOTE: middleware array w/ AuthenticateServerAccess::class not found — no change\n";
}
PHP
    else
      echo "3) WARN: $API_CLIENT not found, skipped"
    fi

    # --- 4) admin.php patch ---
    if [ -f "$ADMIN_ROUTES" ]; then
      bk "$ADMIN_ROUTES"
      php <<PHP
<?php
\$f = '$ADMIN_ROUTES';
\$s = file_get_contents(\$f);

// Apply middleware ke SEMUA admin routes
\$s = preg_replace_callback(
    '/Route::group\\s*\\(\\s*\\[([^\\]]*prefix\\s*=>\\s*\'admin\'[^\\]]*)\\]\\s*,\\s*function\\s*\\(\\)\\s*\\{/is',
    function(\$m){
        \$head = \$m[1];
        if (stripos(\$head, 'middleware') === false) {
            return str_replace(\$m[1], \$head . ", 'middleware' => ['custom.security']", \$m[0]);
        }
        \$head2 = preg_replace_callback('/(middleware\\s*=>\\s*\\[)([\\s\\S]*?)(\\])/i', function(\$mm){
            if (stripos(\$mm[2], 'custom.security') !== false) return \$mm[0];
            \$b = rtrim(\$mm[2]);
            if (\$b !== '' && substr(trim(\$b), -1) !== ',') \$b .= ',';
            \$b .= "\\n        'custom.security'";
            return \$mm[1] . \$b . \$mm[3];
        }, \$head, 1);
        return str_replace(\$m[1], \$head2, \$m[0]);
    },
    \$s
);

// Juga apply ke individual admin routes yang mungkin tidak dalam group
\$s = preg_replace_callback(
    '/Route::(get|post|put|patch|delete)\\s*\\(\\s*[\'"](admin\\/[^\'"]*)[\'"]/i',
    function(\$m) {
        \$route = \$m[0];
        // Jika belum ada middleware, tambahkan
        if (!str_contains(\$route, '->middleware')) {
            \$route = str_replace(\$m[2] . "'", \$m[2] . "')->middleware(['custom.security'])", \$route);
        }
        return \$route;
    },
    \$s
);

file_put_contents(\$f, \$s);
echo "4) admin.php patched - applied to ALL admin routes\n";
PHP
    else
      echo "4) WARN: $ADMIN_ROUTES not found, skipped"
    fi

    # --- 5) Clear caches & reload ---
    cd "$APP_DIR"
    php artisan config:clear || true
    php artisan route:clear || true
    php artisan view:clear || true
    php artisan cache:clear || true
    php artisan optimize || true
    systemctl reload nginx || service nginx reload || true

    log "✅ MBUTT SECURITY installed successfully!"
    echo
    log "🛡️  FULL ADMIN PANEL PROTECTION ACTIVATED:"
    log ""
    log "   👑 HANYA ADMIN ID 1 yang bisa akses:"
    log "   📊 BASIC ADMINISTRATION:"
    log "      - Overview ❌ DIBLOKIR"
    log "      - Settings ❌ DIBLOKIR" 
    log "      - Application API ❌ DIBLOKIR"
    log ""
    log "   📦 MANAGEMENT SECTION:"
    log "      - Databases ❌ DIBLOKIR"
    log "      - Locations ❌ DIBLOKIR"
    log "      - Nodes ❌ DIBLOKIR"
    log "      - Servers ❌ DIBLOKIR"
    log "      - Users ❌ DIBLOKIR"
    log ""
    log "   🔧 SERVICE MANAGEMENT:"
    log "      - Mounts ❌ DIBLOKIR"
    log "      - Nests ❌ DIBLOKIR"
    log "      - Eggs ❌ DIBLOKIR"
    log ""
    log "   💬 Error Message: 'Hanya Super Admin (ID 1) yang boleh akses Admin Panel!'"
    log ""
    log "💬 Created by MBUTT - VVIP TOOLS"
