# BLUEPRINT: nvstudio-mcp (Fase 2 - API Contract)

**Tujuan:** Instruksi ini dirancang untuk dieksekusi oleh AI Agent. Eksekusi instruksi ini untuk membangun dokumen spesifikasi API (API Contract) di dalam proyek.

### Langkah 1: Setup Direktori
1. Di dalam root direktori proyek `nvstudio-mcp`, buat folder bernama `docs`.
2. Buat file baru bernama `API_CONTRACT.md` di dalam folder tersebut dan isi persis dengan konten pada Langkah 2.

### Langkah 2: Konten File API_CONTRACT.md
Tuliskan spesifikasi baku berikut ke dalam file `API_CONTRACT.md`:

#### 1. Endpoint Polling (GET)
- **URL:** `GET http://localhost:3000/api/tasks`
- **Fungsi:** Dipanggil oleh Plugin Roblox Studio setiap 1 detik untuk mengambil tugas.
- **Response (Jika ada tugas dalam antrean):**
  {
    "id": "string (UUID)",
    "command": "string (Perintah eksekusi)",
    "target": "string (Path absolut dari objek)",
    "data": "string (Opsional)"
  }
- **Response (Jika antrean kosong):**
  {
    "id": null
  }

#### 2. Endpoint Respons (POST)
- **URL:** `POST http://localhost:3000/api/response`
- **Fungsi:** Dipanggil oleh Plugin Studio untuk mengirim hasil eksekusi kembali ke server Node.js.
- **Headers:** `Content-Type: application/json`
- **Request Body (Jika Sukses):**
  {
    "id": "string (Wajib sama dengan UUID tugas)",
    "status": "success",
    "result": "any (Hasil data)"
  }
- **Request Body (Jika Gagal):**
  {
    "id": "string (Wajib sama dengan UUID tugas)",
    "status": "error",
    "error": "string (Pesan error dari Luau)"
  }

#### 3. Daftar Perintah (Commands) Standar
Parser plugin wajib mendukung 3 perintah dasar ini:
1. `get_children`: Mengembalikan array string nama dan ClassName dari children target.
2. `get_script_source`: Mengembalikan teks murni properti Source (hanya berlaku untuk LuaSourceContainer).
3. `update_script_source`: Menimpa properti Source pada target dengan string dari parameter data.

### Langkah 3: Eksekusi
Simpan file `docs/API_CONTRACT.md`. File ini bersifat mengikat dan wajib dirujuk saat membuat parser HttpService di Plugin Luau. Eksekusi penulisan file ini sekarang.