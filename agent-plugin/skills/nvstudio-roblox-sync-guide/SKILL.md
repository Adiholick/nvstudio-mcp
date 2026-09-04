---
name: nvstudio-roblox-sync-guide
description: Aturan anti-halusinasi untuk membaca, mengedit, dan me-rollback script Roblox.
---
# nvstudio-roblox-sync-guide

Panduan sinkronisasi dan manajemen skrip (properti `.Source`) di Roblox Studio.

## Aturan update_script_source
1. **PENTING:** Anda WAJIB melakukan `get_script_source` terlebih dahulu sebelum mengedit script apa pun. Ini agar Anda memahami kode apa yang ada saat ini dan mencegah hilangnya kode krusial.
2. Operasi ini menimpa KESELURUHAN kode di dalam skrip.
3. Server jembatan memiliki "Luau AST Validator" internal. Jika script Anda mengandung syntax error fatal (seperti lupa `end`), file tidak akan diupdate dan Anda akan menerima pesan error. 

## Aturan rollback_script
1. Anda dapat membatalkan perubahan terakhir pada script dengan memanggil `rollback_script`.
2. Pastikan target path cocok persis dengan script yang baru saja Anda edit.
