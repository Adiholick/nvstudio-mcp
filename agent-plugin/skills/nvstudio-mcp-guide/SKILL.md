---
name: nvstudio-mcp-guide
description: Panduan umum untuk berinteraksi dengan Roblox Studio menggunakan MCP nvstudio-mcp.
---
# nvstudio-mcp-guide

Gunakan skill ini sebagai referensi umum saat bekerja dengan Roblox Studio via `nvstudio-mcp`.

## Dasar Pemanggilan
1. Jika target path tidak diketahui, gunakan perintah eksplorasi seperti `get_children` atau `search_instance` (khusus pencarian berdasarkan nama) terlebih dahulu.
2. Tentukan target path string yang valid (misalnya `game.Workspace.Model.Part`). LLM/Agent tidak bisa berinteraksi menggunakan reference Luau langsung.
