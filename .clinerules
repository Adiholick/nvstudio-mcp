# ROBLOX STUDIO MCP RULES - MUTLAK DAN TIDAK BISA DIGANGGU GUGAT

1. INTERAKSI MCP RESMI:
Anda HANYA DIIZINKAN berinteraksi dengan Roblox menggunakan native MCP tools `nvstudio-mcp` (seperti `execute_luau`, `batch_create_instances`, `batch_set_properties`, `preview_asset`, `scan_security`, `get_roblox_docs`, `get_script_source`, `patch_script_source`, dll.) atau melalui dispatcher `call_mcp_tool`.

2. STRICT BYPASS BAN:
DILARANG KERAS merancang, menulis, atau mengeksekusi script eksternal seperti `fetch_mcp_source.js`, `PowerShell`, atau `Node.js runner` ad-hoc lainnya untuk berinteraksi dengan Roblox. Jalur komunikasi sudah diatur sepenuhnya melalui MCP lokal.

3. MANDATORY HIERARCHY CHECK:
DILARANG memanggil `get_script_source` secara menebak-nebak (buta). Anda WAJIB memanggil `get_children` pada direktori parent terlebih dahulu. Jika Anda mendapat pesan error bahwa "teks kosong", itu karena Anda mencoba membaca Folder, bukan Script. Selalu verifikasi ClassName dari hasil `get_children` sebelum mengekstrak kode.

4. STARTERGUI & NV-SERIES DESIGN TASTE:
Setiap pembuatan atau modifikasi GUI di `StarterGui` WAJIB mematuhi standar NV-Series:
- GUI dibuat sebagai Instance Roblox nyata (gunakan `batch_create_instances` dengan mode `tree`, BUKAN pure script runtime generator).
- ScreenGui selalu memiliki `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, dan berpusat pada `MainFrame`.
- Setiap Frame WAJIB memiliki `UIListLayout` dan `UIPadding`. Semua child item diatur `LayoutOrder`-nya secara eksplisit.
- Setiap `ScrollingFrame` WAJIB memiliki Frame transparan `Spacer` dengan `LayoutOrder = 99999`.
- Wajib menggunakan Smart Device Detection `GetDeviceType` milik `NVSelfTitle` / `NVDance`.
- Estetika tema gelap: Background `#1C1C1E`, card `#191919`, accent Cyan `#00AAFF`, stroke border `#3F3F3F`, UICorner (`0, 8` - `0, 10`), font GothamBold/Gotham.
