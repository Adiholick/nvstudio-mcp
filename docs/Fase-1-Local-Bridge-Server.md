# BLUEPRINT: nvstudio-mcp (Fase 1 - Local Bridge Server)

**Tujuan:** Instruksi ini dirancang untuk dieksekusi oleh AI Agent. Pahami dan eksekusi instruksi pembangunan sistem jembatan lokal (Node.js) di bawah ini langkah demi langkah.

## INSTRUKSI PEMBANGUNAN: LOCAL BRIDGE SERVER (NODE.JS)

### Langkah 1: Setup Lingkungan & Dependensi
1. Buat direktori bernama `nvstudio-mcp` dan inisialisasi proyek Node.js baru.
2. Instal dependensi produksi: `@modelcontextprotocol/sdk`, `express`, dan `uuid`.
3. Instal dependensi pengembangan: `typescript`, `@types/node`, `@types/express`, `@types/uuid`, dan `ts-node`.
4. Inisialisasi `tsconfig.json` dan atur direktori output (`outDir`) ke `./dist`.
5. Buat folder `src` untuk menampung seluruh file TypeScript.

### Langkah 2: Buat Logika Antrean (src/task-queue.ts)
Tulis file `task-queue.ts` dengan spesifikasi logika berikut:
1. Buat sebuah array untuk menampung antrean tugas (*task queue*).
2. Buat sebuah Map untuk menyimpan *Promise* dari tugas yang sedang menunggu (*pending tasks*).
3. Buat fungsi asynchronous `addTaskToQueue` yang menerima argumen: `command`, `target`, dan `data`.
4. Di dalam fungsi tersebut, buat ID unik (UUID), masukkan tugas ke dalam antrean, dan kembalikan sebuah *Promise*.
5. *Promise* tersebut harus tertahan sampai ada penyelesaian dari Map, ATAU berikan *timeout* otomatis selama 30 detik yang mengembalikan error: "Timeout: Roblox Studio tidak merespons".

### Langkah 3: Buat Jembatan HTTP (src/roblox-bridge.ts)
Tulis file `roblox-bridge.ts` dengan spesifikasi logika berikut:
1. Gunakan Express.js untuk membuat server lokal yang berjalan di port 3000.
2. Buat endpoint `GET /api/tasks`. Logikanya: Jika array antrean tugas memiliki isi, ambil dan kembalikan tugas pertama (shift). Jika kosong, kembalikan JSON dengan nilai `id: null`.
3. Buat endpoint `POST /api/response`. Logikanya: Ekstrak `id`, `status`, `result`, dan `error` dari *request body*. Cari `id` tersebut di dalam Map *pending tasks*. Jika ada, selesaikan (*resolve*) *Promise* tersebut sesuai status (success atau error), lalu hapus dari Map.
4. Pastikan server memberikan log terminal saat berhasil berjalan.

### Langkah 4: Buat Entry Point MCP (src/index.ts)
Tulis file `index.ts` dengan spesifikasi logika berikut:
1. Impor dan jalankan server Express dari `roblox-bridge.ts`.
2. Inisialisasi objek Server MCP dengan nama `nvstudio-mcp` dan versi `1.0.0`.
3. Daftarkan tool menggunakan `ListToolsRequestSchema` bernama `call_mcp_tool`.
4. Definisikan input schema tool tersebut untuk menerima parameter: `command` (string, wajib), `target` (string path absolut, wajib), dan `data` (string opsional).
5. Buat *handler* menggunakan `CallToolRequestSchema` untuk menangani eksekusi `call_mcp_tool`.
6. Terapkan validasi target: Jika `command` adalah `get_script_source`, pastikan target mengarah ke file spesifik. Jika target tidak spesifik, tolak eksekusi dan kembalikan instruksi agar AI menggunakan `get_children` terlebih dahulu.
7. Jika lolos validasi, teruskan perintah ke `addTaskToQueue` dan kembalikan hasilnya sebagai string JSON.
8. Jalankan koneksi MCP menggunakan `StdioServerTransport`.

### Langkah 5: Finalisasi Eksekusi
1. Tambahkan *scripts* di `package.json` untuk menjalankan kompilasi TypeScript (`build`) dan menjalankan file hasil kompilasi (`start`).
2. Jalankan proses penulisan file dan kompilasi sekarang.