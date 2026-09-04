# BLUEPRINT: nvstudio-mcp (Fase 11 - Fitur Lanjutan & Ekspansi Ekosistem)

**Tujuan:** Memperluas kapabilitas `nvstudio-mcp` agar memiliki kesetaraan fungsional (feature parity) dengan ekosistem terdepan seperti `Chrrxs/robloxstudio-mcp` dan `weppy-roblox-mcp`, dengan menambahkan 5 fitur krusial:
1. **`get_properties`** (Inspeksi detail nilai properti instance)
2. **`script_grep`** (Pencarian isi teks/pattern ke seluruh script)
3. **`delete_instance`** (Penghapusan objek/script langsung via AI)
4. **`execute_luau`** (Eksekusi kode Luau dinamis secara langsung di Studio)
5. **`search_asset`** (Pencarian model/audio/decal di Roblox Creator Store Marketplace)

---

## 1. Arsitektur dan Alur Eksekusi Fitur

Semua fitur baru mengikuti arsitektur modular `nvstudio-mcp`:
* **Sisi Studio (`studio-plugin/`)**: Menambahkan file modul `.lua` independen yang di-load otomatis oleh `Main.server.lua`.
* **Sisi Core Server (`src/index.ts` & `src/roblox-bridge.ts`)**: Mendaftarkan schema parameter dan guardrail di server MCP.
* **Sisi AI Agent (`agent-plugin/` & rules)**: Menyediakan panduan operasional agar AI memanggil command dengan format data yang tepat.

```
                    ┌────────────────────────┐
                    │      AI ASSISTANT      │
                    └───────────┬────────────┘
                                │ JSON-RPC (call_mcp_tool)
                                ▼
                    ┌────────────────────────┐
                    │     CORE MCP SERVER    │ (Node.js Port 3055)
                    │  - search_asset (Web)  │
                    │  - Guardrails & Queue  │
                    └───────────┬────────────┘
                                │ HTTP Polling (Tasks API)
                                ▼
                    ┌────────────────────────┐
                    │  ROBLOX STUDIO PLUGIN  │
                    │  ├── get_properties    │
                    │  ├── script_grep       │
                    │  ├── delete_instance   │
                    │  └── execute_luau      │
                    └────────────────────────┘
```

---

## 2. Rincian Desain 5 Fitur Utama

### Fitur 1: `get_properties` (Inspeksi Detail Properti Instance)
* **Latar Belakang:** Saat ini AI hanya bisa melihat nama dan ClassName via `get_children`. AI sering perlu mengetahui posisi (`Position`), rotasi (`CFrame`), warna (`Color3`), status (`Anchored`, `CanCollide`), maupun atribut custom (`Attributes`).
* **Tantangan:** Roblox Engine tidak memiliki method universal `Instance:GetProperties()`.
* **Solusi Implementasi (`studio-plugin/get_properties.lua`):**
  1. Modul membaca properti umum universal (`Name`, `ClassName`, `Parent`).
  2. Membaca properti spesifik berdasarkan keluarga Class (misal `BasePart`, `TextLabel`, `Frame`, `Light`, `Sound`, dll).
  3. Membaca semua custom attributes via `targetInstance:GetAttributes()`.
  4. Membaca semua tags via `CollectionService:GetTags(targetInstance)`.
  5. Mengembalikan data dalam bentuk JSON terformat (string/number/boolean/array).

* **Contoh Pemanggilan MCP:**
  ```json
  {
    "command": "get_properties",
    "target": "Workspace.SpawnLocation",
    "data": ""
  }
  ```
* **Contoh Return:**
  ```json
  {
    "status": "success",
    "result": {
      "Name": "SpawnLocation",
      "ClassName": "SpawnLocation",
      "Anchored": true,
      "CanCollide": true,
      "Size": [6, 1, 6],
      "Position": [0, 0.5, 0],
      "Color": [163, 162, 165],
      "Material": "Plastic",
      "Attributes": {},
      "Tags": []
    }
  }
  ```

---

### Fitur 2: `script_grep` (Pencarian Isi Teks di Seluruh Script)
* **Latar Belakang:** AI membutuhkan kemampuan untuk mencari di mana fungsi tertentu didefinisikan, variabel digunakan, atau string teks dipanggil di seluruh script game tanpa harus membuka script satu per satu.
* **Solusi Implementasi (`studio-plugin/script_grep.lua`):**
  1. Melakukan scanning pada service utama (`Workspace`, `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`, `StarterGui`).
  2. Memfilter turunan yang bertipe `LuaSourceContainer` (`Script`, `LocalScript`, `ModuleScript`).
  3. Memecah string `target.Source` per baris dan mencocokkan kata kunci (`string.find`).
  4. Menyertakan nomor baris (`line_number`) dan cuplikan baris (`snippet`).
  5. Memberikan batas maksimal kecocokan (maks. 50 matches) agar tidak membebani transport JSON-RPC.

* **Contoh Pemanggilan MCP:**
  ```json
  {
    "command": "script_grep",
    "target": "Workspace",
    "data": "CountdownGui"
  }
  ```
* **Contoh Return:**
  ```json
  {
    "status": "success",
    "matches": [
      {
        "script": "StarterPlayer.StarterPlayerScripts.HitungMajuGUI",
        "line": 6,
        "content": "screenGui.Name = \"CountdownGui\""
      }
    ]
  }
  ```

---

### Fitur 3: `delete_instance` (Penghapusan Objek via AI)
* **Latar Belakang:** Sebelumnya, jika AI ingin menghapus script atau part, AI hanya bisa mengosongkan isinya dan meminta pengguna menghapus manual di Explorer.
* **Solusi Implementasi (`studio-plugin/delete_instance.lua`):**
  1. Validasi keberadaan instance target.
  2. **Security Guardrail:** Melarang keras penghapusan Service tingkat atas (Root Services) seperti `Workspace`, `Players`, `Lighting`, `ReplicatedStorage`, `ServerScriptService`, `StarterGui`, dll.
  3. Menjalankan `targetInstance:Destroy()` di dalam blok `pcall`.
  4. Mengembalikan status sukses beserta nama dan path objek yang telah dimusnahkan.

* **Contoh Pemanggilan MCP:**
  ```json
  {
    "command": "delete_instance",
    "target": "StarterPlayer.StarterPlayerScripts.HitungMajuGUI",
    "data": ""
  }
  ```
* **Contoh Return:**
  ```json
  {
    "status": "success",
    "result": "Instance 'HitungMajuGUI' (LocalScript) berhasil dihapus dari StarterPlayer.StarterPlayerScripts."
  }
  ```

---

### Fitur 4: `execute_luau` (Eksekusi Kode Luau Langsung di Studio)
* **Latar Belakang:** Seringkali pengguna ingin AI melakukan operasi batch cepat (misalnya: mewarnai 50 part secara acak, mengatur CFrame kamera, atau menguji rumus math langsung di environment Studio).
* **Solusi Implementasi (`studio-plugin/execute_luau.lua`):**
  1. Menerima string kode Luau pada parameter `data`.
  2. Menjalankan kode secara dinamis menggunakan mekanisme `ModuleScript` sementara atau `loadstring` yang dibungkus `pcall`.
  3. **Guardrails Mutlak:**
     * Menangkap error sintaks dan runtime secara elegan tanpa memutus polling server.
     * Mengonversi return value ke tipe data primitif (string, number, boolean, table) dan melakukan serialize `HttpService:JSONEncode()` agar tidak mengembalikan raw Roblox Instance pointer (mencegah crash RPC).
     * Membatasi waktu eksekusi (timeout protection).

* **Contoh Pemanggilan MCP:**
  ```json
  {
    "command": "execute_luau",
    "target": "Workspace",
    "data": "local count = 0; for _, part in ipairs(workspace:GetChildren()) do if part:IsA('BasePart') then count += 1 end end; return { part_count = count }"
  }
  ```
* **Contoh Return:**
  ```json
  {
    "status": "success",
    "result": {
      "part_count": 12
    }
  }
  ```

---

### Fitur 5: `search_asset` (Pencarian Creator Store / Marketplace)
* **Latar Belakang:** Saat ini `nvstudio-mcp` sudah memiliki `insert_asset`, tetapi pengguna harus mencari Asset ID secara manual di website Roblox. AI memerlukan kemampuan mencari aset berdasarkan kata kunci langsung dari chat.
* **Solusi Implementasi (Sisi Bridge Server `src/` atau `studio-plugin/`):**
  1. Fitur ini dieksekusi di sisi **Node.js Core Bridge Server** menggunakan HTTP API publik Roblox Toolbox / Creator Store (atau via `InsertService` jika di dalam Studio).
  2. Menerima keyword pencarian (misal: `"Tree"`, `"Car"`, `"Medieval Sword"`), kategori (Model, Audio, Decal), dan limit hasil.
  3. Mengembalikan daftar Asset ID, Nama Aset, dan Pembuat (Creator).
  4. AI dapat langsung meneruskan Asset ID hasil pencarian ke perintah `insert_asset`.

* **Contoh Pemanggilan MCP:**
  ```json
  {
    "command": "search_asset",
    "target": "Workspace",
    "data": "{\"keyword\": \"pine tree\", \"category\": \"Model\", \"limit\": 5}"
  }
  ```
* **Contoh Return:**
  ```json
  {
    "status": "success",
    "results": [
      { "id": "12345678", "name": "Realistic Pine Tree", "creator": "RobloxDev" },
      { "id": "87654321", "name": "Low Poly Pine", "creator": "ModelMaster" }
    ]
  }
  ```

---

## 3. Matriks Roadmap & Rencana Implementasi Bertahap

Implementasi dibagi menjadi 3 Sub-Fase terukur:

### Sub-Fase 11.1: Manipulasi Instance & Pembersihan (Prioritas Utama)
* [ ] Buat file `studio-plugin/delete_instance.lua` dengan guardrail anti-hapus service utama.
* [ ] Buat file `studio-plugin/get_properties.lua` dengan ekstraksi properti standar + Attributes & Tags.
* [ ] Daftarkan validasi parameter di `src/index.ts`.
* [ ] Uji coba penghapusan `HitungMajuGUI` dan verifikasi bahwa Explorer Studio langsung terupdate.

### Sub-Fase 11.2: Inspeksi Kode & Pencarian Massal
* [ ] Buat file `studio-plugin/script_grep.lua` dengan traversal multi-service dan pemotongan baris.
* [ ] Tambahkan limitasi hasil pencarian (max 50 baris) agar response ringan.
* [ ] Uji coba pencarian kata kunci tertentu di seluruh script Roblox Studio.

### Sub-Fase 11.3: Eksekusi Dinamis & Integrasi Creator Store
* [ ] Buat file `studio-plugin/execute_luau.lua` dengan sandboxing `pcall` dan JSON encoding.
* [ ] Tambahkan integrasi `search_asset` di bridge server Node.js ke API publik Creator Store Roblox.
* [ ] Perbarui `nvstudio_mcp.rbxmx` dan deploy ke folder plugin Studio pengguna.
* [ ] Perbarui skill markdown AI Agent (`nvstudio-mcp-guide`) agar AI otomatis memanfaatkan kelima fitur baru ini.

---

## 4. Keuntungan Setelah Fase 11 Selesai

1. **Paritas Penuh dengan Chrrxs & Weppy:** `nvstudio-mcp` memiliki semua fungsionalitas inti yang dimiliki MCP Roblox terpopuler di dunia.
2. **Kelebihan Eksklusif:** Tetap mempertahankan keunggulan unik `nvstudio-mcp` yang tidak dimiliki oleh MCP lain:
   * **Web Dashboard GUI interaktif** (Port 3055).
   * **Auto-Rollback & Session History** bawaan.
   * **Arsitektur Modular** yang aman dan mudah diperluas tanpa kompilasi binary `.exe`.
