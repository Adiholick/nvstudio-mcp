# API Contract (nvstudio-mcp)

Dokumen ini adalah spesifikasi baku komunikasi antara Local Bridge Server (Node.js) dan Plugin Roblox Studio (Luau).

#### 1. Endpoint Polling (GET)
- **URL:** `GET http://localhost:3000/api/tasks`
- **Fungsi:** Dipanggil oleh Plugin Roblox Studio setiap 1 detik untuk mengambil tugas.
- **Response (Jika ada tugas dalam antrean):**
  ```json
  {
    "id": "string (UUID)",
    "command": "string (Perintah eksekusi)",
    "target": "string (Path absolut dari objek)",
    "data": "string (Opsional)"
  }
  ```
- **Response (Jika antrean kosong):**
  ```json
  {
    "id": null
  }
  ```

#### 2. Endpoint Respons (POST)
- **URL:** `POST http://localhost:3000/api/response`
- **Fungsi:** Dipanggil oleh Plugin Studio untuk mengirim hasil eksekusi kembali ke server Node.js.
- **Headers:** `Content-Type: application/json`
- **Request Body (Jika Sukses):**
  ```json
  {
    "id": "string (Wajib sama dengan UUID tugas)",
    "status": "success",
    "result": "any (Hasil data)"
  }
  ```
- **Request Body (Jika Gagal):**
  ```json
  {
    "id": "string (Wajib sama dengan UUID tugas)",
    "status": "error",
    "error": "string (Pesan error dari Luau)"
  }
  ```

#### 3. Daftar Perintah (Commands) Standar
Parser plugin wajib mendukung 3 perintah dasar ini:
1. `get_children`: Mengembalikan array string nama dan ClassName dari children target.
2. `get_script_source`: Mengembalikan teks murni properti Source (hanya berlaku untuk LuaSourceContainer).
3. `update_script_source`: Menimpa properti Source pada target dengan string dari parameter data.
4. `search_instance`: Mencari path absolut dari sebuah objek berdasarkan namanya secara semantik di direktori pencarian. Target `game`. Data `string` (nama instance).
5. `create_instance`: Membuat instance baru secara native melalui script json config. Target path (misal `"Workspace"`). Data format JSON `{ "ClassName": "Part", "Properties": { "Name": "Part" } }`.
6. `rollback_script`:
   - **Fungsi:** Mengembalikan properti `Source` pada target ke versi sebelumnya jika AI berhalusinasi atau AST Validation gagal.
   - **Parameter target:** Path absolut instance.
   - **Parameter data:** Kosongkan.
7. `get_logs`:
   - **Fungsi:** Mengambil 50 baris terakhir dari Output Console Roblox Studio. Sangat penting digunakan setelah memodifikasi script untuk memastikan tidak ada runtime error.
   - **Parameter target:** `"game"`
   - **Parameter data:** Kosongkan.
