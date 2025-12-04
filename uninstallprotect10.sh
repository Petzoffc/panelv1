#!/bin/bash

echo "🛠️  Menghapus proteksi Anti Tautan Server..."

# File paths
INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
VIEW_DIR="/var/www/pterodactyl/resources/views/admin/servers/view"

# Restore index file
INDEX_BACKUP=$(ls -t "${INDEX_FILE}.bak_"* 2>/dev/null | head -n1)
if [ -n "$INDEX_BACKUP" ]; then
    echo "✅ Memulihkan index file dari backup: $INDEX_BACKUP"
    cp -f "$INDEX_BACKUP" "$INDEX_FILE"
    echo "📦 Index file berhasil dipulihkan"
else
    echo "⚠️  Backup index tidak ditemukan, membuat file default..."
    cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle"><strong>{{ $server->name }}</strong></td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">{{ $server->user->username }}</td>
                                <td class="middle">{{ $server->node->name }}</td>
                                <td class="middle"><code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code></td>
                                <td class="text-center">
                                    <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                        <i class="fa fa-wrench"></i> Manage
                                    </a>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>
    </div>
</div>
@endsection
EOF
fi

# Restore semua view files
echo "🔄 Memulihkan semua view server..."
find "$VIEW_DIR" -name "*.blade.php.bak_*" | while read backup_file; do
    original_file="${backup_file%.bak_*}"
    echo "✅ Memulihkan: $(basename "$original_file")"
    cp -f "$backup_file" "$original_file"
done

# Hapus file protected yang tidak ada backup
find "$VIEW_DIR" -name "*.blade.php" | while read view_file; do
    if grep -q "SERVER MANAGEMENT RESTRICTED" "$view_file" 2>/dev/null; then
        echo "🗑️  Menghapus protected view: $(basename "$view_file")"
        rm -f "$view_file"
    fi
done

# Set permissions
chmod 644 "$INDEX_FILE"

# Clear cache
echo "🔄 Membersihkan cache..."
cd /var/www/pterodactyl
php artisan view:clear
php artisan cache:clear

echo ""
echo "🎉 UNINSTALL BERHASIL!"
echo "✅ Proteksi telah dihapus"
echo "✅ Semua admin sekarang bisa akses semua fitur"
echo "✅ Create New dan Manage Existing bisa untuk semua admin"
echo "🔓 Sistem kembali normal untuk semua admin"
