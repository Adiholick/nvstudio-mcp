---
name: nvstudio-assets-terrain-guide
description: Panduan untuk memasukkan aset aman, audit keamanan backdoor, dan membuat terrain di Roblox Studio.
---
# nvstudio-assets-terrain-guide

## Alur Kerja Aman Creator Store & Asset Security

### 1. Pratinjau & Audit Keamanan (`preview_asset`)
Sebelum memasukkan model publik dari Creator Store, **selalu jalankan `preview_asset` terlebih dahulu**:
- Memuat aset di lingkungan terisolasi sementara untuk memeriksa struktur hierarki dan memindai skrip berbahaya (backdoor `require`, obfuscation byte/hex, webhook discord, loadstring, atau off-screen hidden code).
- Model sementara akan langsung dihapus dari memori secara otomatis.

### 2. Memasukkan Aset Secara Aman (`insert_asset`)
- **Sanitasi Skrip Otomatis (`strip_scripts = true`):**
  - Secara default bernilai `true`. Seluruh skrip di dalam model 3D/bangunan/furnitur akan otomatis dihapus sebelum model diletakkan di `Workspace`.
  - Jika Anda memasukkan kit sistem yang terpercaya dan memang membutuhkan skrip untuk berfungsi, setel `strip_scripts = false`.
- **Target Parent:** Tentukan target tujuan (default: `game.Workspace`).

### 3. Audit Keamanan Tempat Kerja (`scan_security`)
- Gunakan `scan_security` untuk memindai model, folder, atau seluruh `Workspace` yang sudah ada di game untuk mendeteksi virus lama atau infeksi terselubung.
- Opsi `clean_threats = true` dapat digunakan untuk secara otomatis memusnahkan skrip berbahaya yang terdeteksi.

## Aturan generate_terrain
1. Suplai parameter berupa string JSON ke argumen `data`.
2. Parameter yang diperlukan: `Size` (array angka), `Position` (array angka), dan `Material` (string valid `Enum.Material` seperti "Grass", "Water", "Sand", dsb).
Contoh payload JSON: `{"Size": [100, 10, 100], "Position": [0, -5, 0], "Material": "Grass"}`
