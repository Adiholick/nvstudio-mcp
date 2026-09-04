---
name: nvstudio-assets-terrain-guide
description: Panduan untuk memasukkan aset dan membuat terrain (landscape) di Roblox Studio.
---
# nvstudio-assets-terrain-guide

## Aturan insert_asset
1. Argumen/Data yang diberikan HARUS berupa angka numerik Asset ID (contoh: `8417937402`). 
2. DILARANG memasukkan prefix seperti `rbxassetid://` atau karakter non-numerik.
3. Jika gagal, berarti aset tidak dijual bebas / Anda tidak memiliki akses ke aset tersebut.
4. Aset yang berhasil dimasukkan akan langsung berpindah ke `game.Workspace`.

## Aturan generate_terrain
1. Anda wajib menyuplai parameter berupa string JSON ke argumen `data`.
2. Parameter yang diperlukan: `Size` (array angka), `Position` (array angka), dan `Material` (string valid `Enum.Material` seperti "Grass", "Water", "Sand", dsb).
Contoh payload JSON: `{"Size": [100, 10, 100], "Position": [0, -5, 0], "Material": "Grass"}`
