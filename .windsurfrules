# ROBLOX STUDIO MCP RULES - MUTLAK DAN TIDAK BISA DIGANGGU GUGAT

1. SINGLE POINT OF INTERACTION:
Anda HANYA DIIZINKAN berinteraksi dengan Roblox menggunakan alat `call_mcp_tool`. 

2. STRICT BYPASS BAN:
DILARANG KERAS merancang, menulis, atau mengeksekusi script eksternal seperti `fetch_mcp_source.js`, `PowerShell`, atau `Node.js runner` lainnya untuk berinteraksi dengan Roblox. Jalur komunikasi sudah diatur sepenuhnya melalui MCP lokal.

3. MANDATORY HIERARCHY CHECK:
DILARANG memanggil `get_script_source` secara menebak-nebak (buta). Anda WAJIB memanggil `get_children` pada direktori parent terlebih dahulu. Jika Anda mendapat pesan error bahwa "teks kosong", itu karena Anda mencoba membaca Folder, bukan Script. Selalu verifikasi ClassName dari hasil `get_children` sebelum mengekstrak kode.
