#!/bin/bash

echo "🗑️  Menghapus proteksi Anti Akses Admin Node View..."

CONTROLLER_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/NodeViewController.php"
BACKUP_PATTERN="${CONTROLLER_PATH}.bak_*"

# Cari dan restore backup terbaru
LATEST_BACKUP=$(ls -t $BACKUP_PATTERN 2>/dev/null | head -n1)

if [ -n "$LATEST_BACKUP" ]; then
    echo "🔄 Mengembalikan backup controller..."
    mv "$LATEST_BACKUP" "$CONTROLLER_PATH"
    echo "✅ Controller berhasil dikembalikan: $(basename $LATEST_BACKUP)"
else
    echo "⚠️  Tidak ada backup controller ditemukan"
    echo "ℹ️  File controller akan tetap seperti sekarang"
fi

# Hapus view files yang diproteksi
VIEWS_PATH="/var/www/pterodactyl/resources/views/admin/nodes/view"
VIEW_FILES=("settings.blade.php" "configuration.blade.php" "allocation.blade.php" "servers.blade.php")

for view_file in "${VIEW_FILES[@]}"; do
    if [ -f "$VIEWS_PATH/$view_file" ]; then
        rm "$VIEWS_PATH/$view_file"
        echo "✅ View file dihapus: $view_file"
    else
        echo "ℹ️  View file tidak ditemukan: $view_file"
    fi
done

# Clear cache
echo "🧹 Membersihkan cache..."
cd /var/www/pterodactyl
php artisan view:clear > /dev/null 2>&1 && echo "✅ View cache cleared" || echo "⚠️  Gagal clear view cache"
php artisan cache:clear > /dev/null 2>&1 && echo "✅ Application cache cleared" || echo "⚠️  Gagal clear app cache"

echo ""
echo "🎉 Uninstall proteksi berhasil diselesaikan!"
echo "🔓 Semua admin sekarang bisa mengakses halaman nodes view secara normal"
echo "💡 Jika ada masalah, restart queue worker: php artisan queue:restart"
