# Panduan Kompilasi Roblox Model (.rbxmx) Manual

Karena AI tidak dapat menulis file model Roblox (`.rbxmx` / `.rbxm`) secara langsung ke disk, Anda harus mengkompilasi file-file skrip Luau mentah yang telah dibuat ke format `.rbxmx` secara manual. Jangan khawatir, prosesnya sangat mudah.

## Langkah-Langkah

1. Buka **Roblox Studio** dan buat sebuah *Baseplate* / Place kosong baru.
2. Di jendela **Explorer**, klik kanan pada `ServerScriptService` -> Pilih `Insert Object` -> **`Folder`**.
3. Beri nama folder tersebut: **`nvstudio_mcp`**.
4. Di dalam folder `nvstudio_mcp` tersebut, klik ikon `+` lalu buat 1 buah **`Script`**. Beri nama script itu: **`Main`**.
5. Buka file `studio-plugin/Main.server.lua` menggunakan IDE Anda (VS Code/Cursor/Windsurf), lalu **copy semua isinya (Ctrl+C)** dan **paste (Ctrl+V)** ke dalam script `Main` di Studio.
6. Sekarang, kembali klik ikon `+` pada folder **`nvstudio_mcp`**, lalu tambahkan **10 buah `ModuleScript`** (sejajar dengan script `Main`).
7. Beri nama ke-10 *ModuleScript* tersebut sesuai dengan daftar berikut:
   - `ui_manager` (WAJIB, untuk antarmuka GUI modern)
   - `get_children`
   - `get_script_source`
   - `update_script_source`
   - `rollback_script`
   - `get_logs`
   - `search_instance`
   - `create_instance`
   - `insert_asset`
   - `generate_terrain`
8. Untuk **SETIAP** ModuleScript, buka file `.lua` yang bersesuaian di komputer Anda (di dalam folder `d:\Developer\nvstudio-mcp\studio-plugin\`), *copy* seluruh kodenya, dan *paste* ke dalam ModuleScript yang bersangkutan di Roblox Studio.
9. Pastikan struktur Anda di Explorer Studio sekarang terlihat seperti ini:
   ```text
   📂 nvstudio_mcp (Folder)
      📜 Main (Script)
      🧩 ui_manager (ModuleScript)
      🧩 create_instance (ModuleScript)
      🧩 generate_terrain (ModuleScript)
      ... (dan 7 ModuleScript lainnya)
   ```
10. Jika sudah, **klik kanan** tepat pada folder induk **`nvstudio_mcp`** di jendela Explorer.
11. Anda memiliki dua pilihan penyimpanan:
    - **Metode A (Save to File):** Pilih **"Save to File..."** -> beri nama **`nvstudio_mcp.rbxmx`** (tipe *Roblox XML Model (*.rbxmx)*) di folder `studio-plugin/`.
    - **Metode B (Save as Local Plugin):** Pilih **"Save as Local Plugin..."** -> Studio akan otomatis menyimpan file `.rbxmx` langsung ke folder plugins sistem lokal Roblox Anda.

Selesai! Sekarang file `.rbxmx` Anda yang berstruktur tingkat industri ini sudah siap. Skrip instalasi `install.sh` juga akan menyalinnya secara otomatis ke sistem Roblox Plugins di OS Anda jika file tersebut ditaruh di folder `studio-plugin/`!
