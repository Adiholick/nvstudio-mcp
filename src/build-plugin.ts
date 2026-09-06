import fs from 'fs';
import path from 'path';
import os from 'os';

const PLUGIN_DIR = path.join(process.cwd(), 'studio-plugin');
const OUTPUT_FILE = path.join(PLUGIN_DIR, 'nvstudio_mcp.rbxmx');

// Helper to escape XML special characters
function escapeXml(unsafe: string): string {
    return unsafe.replace(/[<>&'"]/g, function (c) {
        switch (c) {
            case '<': return '&lt;';
            case '>': return '&gt;';
            case '&': return '&amp;';
            case '\'': return '&apos;';
            case '"': return '&quot;';
            default: return c;
        }
    });
}

function buildRbxmx() {
    console.log('[Build] Memulai kompilasi nvstudio_mcp.rbxmx...');
    
    if (!fs.existsSync(PLUGIN_DIR)) {
        console.error(`[Build] Folder ${PLUGIN_DIR} tidak ditemukan.`);
        process.exit(1);
    }

    const files = fs.readdirSync(PLUGIN_DIR).filter(file => file.endsWith('.lua'));
    
    // RBXMX Header
    let xml = `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n`;
    xml += `\t<External>null</External>\n\t<External>nil</External>\n`;
    
    // Main Folder
    xml += `\t<Item class="Folder" referent="RBX0497167F99814CA6A2096BB729707905">\n`;
    xml += `\t\t<Properties>\n`;
    xml += `\t\t\t<BinaryString name="AttributesSerialize"></BinaryString>\n`;
    xml += `\t\t\t<SecurityCapabilities name="Capabilities">0</SecurityCapabilities>\n`;
    xml += `\t\t\t<bool name="DefinesCapabilities">false</bool>\n`;
    xml += `\t\t\t<string name="Name">nvstudio_mcp</string>\n`;
    xml += `\t\t\t<int64 name="SourceAssetId">-1</int64>\n`;
    xml += `\t\t\t<BinaryString name="Tags"></BinaryString>\n`;
    xml += `\t\t</Properties>\n`;

    // Process files
    for (const file of files) {
        const filePath = path.join(PLUGIN_DIR, file);
        const source = fs.readFileSync(filePath, 'utf-8');
        const name = file.replace('.lua', '');
        
        // Main.server.lua is a Script, others are ModuleScripts
        const isMain = name === 'Main.server';
        const className = isMain ? 'Script' : 'ModuleScript';
        const scriptName = isMain ? 'Main' : name;
        
        // Use a clean referent
        const referent = `RBX_${scriptName.replace(/[^a-zA-Z0-9]/g, '_')}`;
        
        xml += `\t\t<Item class="${className}" referent="${referent}">\n`;
        xml += `\t\t\t<Properties>\n`;
        xml += `\t\t\t\t<BinaryString name="AttributesSerialize"></BinaryString>\n`;
        xml += `\t\t\t\t<SecurityCapabilities name="Capabilities">0</SecurityCapabilities>\n`;
        xml += `\t\t\t\t<bool name="DefinesCapabilities">false</bool>\n`;
        xml += `\t\t\t\t<bool name="Disabled">false</bool>\n`;
        xml += `\t\t\t\t<Content name="LinkedSource"><null></null></Content>\n`;
        xml += `\t\t\t\t<string name="Name">${scriptName}</string>\n`;
        xml += `\t\t\t\t<int64 name="SourceAssetId">-1</int64>\n`;
        xml += `\t\t\t\t<BinaryString name="Tags"></BinaryString>\n`;
        
        if (isMain) {
            xml += `\t\t\t\t<token name="RunContext">0</token>\n`;
        }
        
        // Wrap source in CDATA to avoid XML escaping issues for the code itself
        // Ensure no ]]> appears inside the CDATA
        const safeSource = source.replace(/\]\]>/g, ']]]]><![CDATA[>');
        xml += `\t\t\t\t<ProtectedString name="Source"><![CDATA[${safeSource}]]></ProtectedString>\n`;
        xml += `\t\t\t</Properties>\n`;
        xml += `\t\t</Item>\n`;
    }

    // Close Folder
    xml += `\t</Item>\n`;
    
    // Close Roblox root (No SharedStrings block needed when all Tags are empty)
    xml += `</roblox>\n`;

    fs.writeFileSync(OUTPUT_FILE, xml, 'utf-8');
    console.log(`[Build] Berhasil membuat ${OUTPUT_FILE}`);
    
    copyToRobloxPlugins();
}

function copyToRobloxPlugins() {
    let pluginsDir = '';
    
    if (process.platform === 'win32') {
        const localAppData = process.env.LOCALAPPDATA;
        if (localAppData) {
            pluginsDir = path.join(localAppData, 'Roblox', 'Plugins');
        }
    } else if (process.platform === 'darwin') {
        pluginsDir = path.join(os.homedir(), 'Documents', 'Roblox', 'Plugins');
    }

    if (pluginsDir) {
        if (!fs.existsSync(pluginsDir)) {
            console.log(`[Build] Folder plugin Roblox tidak ditemukan di ${pluginsDir}. Melewati penyalinan otomatis.`);
            return;
        }

        const targetFile = path.join(pluginsDir, 'nvstudio_mcp.rbxmx');
        try {
            fs.copyFileSync(OUTPUT_FILE, targetFile);
            console.log(`[Build] ✅ Berhasil menyalin nvstudio_mcp.rbxmx ke ${targetFile}`);
        } catch (err: any) {
            console.error(`[Build] Gagal menyalin ke ${targetFile}:`, err.message);
        }
    } else {
        console.log(`[Build] Platform ${process.platform} tidak didukung untuk auto-copy plugin.`);
    }

    // Also update ~/.nvstudio-mcp/studio-plugin/nvstudio_mcp.rbxmx if present
    const homeClonePlugin = path.join(os.homedir(), '.nvstudio-mcp', 'studio-plugin', 'nvstudio_mcp.rbxmx');
    if (fs.existsSync(path.dirname(homeClonePlugin))) {
        try {
            fs.copyFileSync(OUTPUT_FILE, homeClonePlugin);
            console.log(`[Build] ✅ Berhasil memperbarui ${homeClonePlugin}`);
        } catch {}
    }
}

buildRbxmx();
