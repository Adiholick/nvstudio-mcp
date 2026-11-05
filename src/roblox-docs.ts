import fs from 'fs';
import path from 'path';
import YAML from 'yaml';

const BASE_URL = 'https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine';
const CACHE_DIR = path.join(__dirname, '..', '.cache', 'roblox-docs');

if (!fs.existsSync(CACHE_DIR)) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
}

export function cleanRobloxMarkdown(text: string): string {
  if (!text) return '';
  return text
    // Replace `Type.Target|Label` with `Label`
    .replace(/`(?:Class|Datatype|Enum|Library)\.[^|`]+\|([^`]+)`/g, '`$1`')
    // Replace `Type.Target` with `Target`
    .replace(/`(?:Class|Datatype|Enum|Library)\.([^`]+)`/g, '`$1`')
    .trim();
}

const CATEGORIES = ['classes', 'datatypes', 'enums', 'libraries'] as const;
type CategoryType = typeof CATEGORIES[number];

function getCategoryFolder(cat: string): CategoryType {
  const c = cat.toLowerCase();
  if (c.startsWith('class')) return 'classes';
  if (c.startsWith('data') || c.startsWith('type')) return 'datatypes';
  if (c.startsWith('enum')) return 'enums';
  if (c.startsWith('lib')) return 'libraries';
  return 'classes';
}

function getCachePath(category: string, name: string): string {
  const catFolder = path.join(CACHE_DIR, category);
  if (!fs.existsSync(catFolder)) {
    fs.mkdirSync(catFolder, { recursive: true });
  }
  return path.join(catFolder, `${name}.yaml`);
}

async function fetchFromNetwork(category: CategoryType, query: string): Promise<string | null> {
  const url = `${BASE_URL}/${category}/${query}.yaml`;
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'nvstudio-mcp-roblox-docs' } });
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  }
}

async function resolveDocYaml(query: string, categoryFilter: string = 'auto'): Promise<{ yamlText: string; category: CategoryType } | null> {
  // Normalize query casing (capitalized first letter standard)
  const normalizedQuery = query.trim();

  const searchCategories: CategoryType[] = categoryFilter !== 'auto'
    ? [getCategoryFolder(categoryFilter)]
    : ['classes', 'datatypes', 'enums', 'libraries'];

  // 1. Cek disk cache
  for (const cat of searchCategories) {
    const cacheFile = getCachePath(cat, normalizedQuery);
    if (fs.existsSync(cacheFile)) {
      try {
        const cached = fs.readFileSync(cacheFile, 'utf-8');
        if (cached && cached.length > 50) {
          return { yamlText: cached, category: cat };
        }
      } catch {
        // ignore cache read error
      }
    }
  }

  // 2. Fetch dari network
  for (const cat of searchCategories) {
    const rawYaml = await fetchFromNetwork(cat, normalizedQuery);
    if (rawYaml && rawYaml.length > 50) {
      // Simpan ke cache
      try {
        fs.writeFileSync(getCachePath(cat, normalizedQuery), rawYaml, 'utf-8');
      } catch {
        // ignore cache write error
      }
      return { yamlText: rawYaml, category: cat };
    }
  }

  return null;
}

function formatSingleMember(parentName: string, member: any, kind: string): string {
  const name = member.name || member.Name || 'Unknown';
  const summary = cleanRobloxMarkdown(member.summary || member.description || '');
  const desc = cleanRobloxMarkdown(member.description || '');

  let out = `## \`${name}\` (${kind})\n\n`;
  if (summary) out += `> ${summary}\n\n`;

  if (member.type) out += `* **Type:** \`${member.type}\`\n`;
  if (member.default !== undefined && member.default !== null) out += `* **Default:** \`${member.default}\`\n`;

  const tags = (member.tags || []).join(', ');
  if (tags) out += `* **Tags:** ${tags}\n`;

  if (member.deprecation_message) {
    out += `\n> ⚠️ **Deprecated:** ${cleanRobloxMarkdown(member.deprecation_message)}\n\n`;
  }

  // Parameters
  if (Array.isArray(member.parameters) && member.parameters.length > 0) {
    out += `\n### Parameters\n`;
    for (const p of member.parameters) {
      const def = p.default !== undefined && p.default !== null ? ` = \`${p.default}\`` : '';
      out += `* \`${p.name}\`: \`${p.type || 'any'}\`${def} — ${cleanRobloxMarkdown(p.summary || '')}\n`;
    }
  }

  // Returns
  if (Array.isArray(member.returns) && member.returns.length > 0) {
    out += `\n### Returns\n`;
    for (const r of member.returns) {
      out += `* \`${r.type || 'void'}\` — ${cleanRobloxMarkdown(r.summary || '')}\n`;
    }
  }

  if (desc && desc !== summary) {
    out += `\n### Details\n${desc}\n`;
  }

  return out;
}

export async function getRobloxDocs(
  query: string,
  member?: string,
  category: string = 'auto'
): Promise<string> {
  const resolved = await resolveDocYaml(query, category);

  if (!resolved) {
    return `❌ Dokumentasi Roblox untuk "${query}" tidak ditemukan di Classes, Data types, Enums, maupun Libraries.\nPastikan ejaan ClassName atau Enum sudah benar (case-sensitive, contoh: 'TweenService', 'CanvasGroup', 'Vector3', 'EasingStyle').`;
  }

  let doc: any;
  try {
    doc = YAML.parse(resolved.yamlText);
  } catch (err: any) {
    return `❌ Gagal mem-parse format YAML untuk "${query}": ${err.message}`;
  }

  const name = doc.name || query;
  const docType = doc.type || resolved.category;
  const summary = cleanRobloxMarkdown(doc.summary || '');
  const description = cleanRobloxMarkdown(doc.description || '');

  // JIKA MEMBER SPESIFIK DICARI (Contoh: 'Create', 'GroupTransparency')
  if (member) {
    const memberNorm = member.trim().toLowerCase();
    const allMembers: { item: any; kind: string }[] = [];

    const collect = (arr: any[], kind: string) => {
      if (Array.isArray(arr)) {
        for (const item of arr) allMembers.push({ item, kind });
      }
    };

    collect(doc.constructors, 'Constructor');
    collect(doc.properties, 'Property');
    collect(doc.methods, 'Method');
    collect(doc.functions, 'Function');
    collect(doc.events, 'Event');
    collect(doc.callbacks, 'Callback');
    collect(doc.items, 'Enum Item');
    collect(doc.constants, 'Constant');

    const matched = allMembers.find(({ item }) => {
      const full = String(item.name || '').toLowerCase();
      return full === memberNorm || full.endsWith(`.${memberNorm}`) || full.endsWith(`:${memberNorm}`);
    });

    if (matched) {
      let out = `# ${name} : ${matched.item.name || member}\n\n`;
      out += formatSingleMember(name, matched.item, matched.kind);
      return out;
    }

    return `⚠️ Member "${member}" tidak ditemukan di dalam ${name}.\nAnggota yang tersedia: ` +
      allMembers.slice(0, 15).map(({ item }) => `\`${item.name}\``).join(', ') +
      (allMembers.length > 15 ? ` ...dan ${allMembers.length - 15} lainnya.` : '');
  }

  // TAMPILAN PENUH OVERVIEW DOKUMENTASI
  let md = `# Roblox Engine: ${name} (${docType})\n\n`;

  if (doc.deprecation_message) {
    md += `> ⚠️ **DEPRECATED:** ${cleanRobloxMarkdown(doc.deprecation_message)}\n\n`;
  }

  if (summary) {
    md += `> ${summary}\n\n`;
  }

  if (doc.inherits) {
    md += `* **Inherits from:** \`${doc.inherits}\`\n`;
  }
  if (doc.memory_category) {
    md += `* **Memory Category:** \`${doc.memory_category}\`\n`;
  }
  if (Array.isArray(doc.tags) && doc.tags.length > 0) {
    md += `* **Tags:** ${doc.tags.join(', ')}\n`;
  }
  md += `\n---\n\n`;

  if (description && description !== summary) {
    md += `### Description\n${description}\n\n`;
  }

  // CONSTRUCTORS
  if (Array.isArray(doc.constructors) && doc.constructors.length > 0) {
    md += `### Constructors\n`;
    for (const c of doc.constructors) {
      const params = (c.parameters || []).map((p: any) => `${p.name}: ${p.type || 'any'}`).join(', ');
      md += `* \`${c.name}(${params})\`\n  ${cleanRobloxMarkdown(c.summary || '')}\n`;
    }
    md += `\n`;
  }

  // PROPERTIES TABLE
  if (Array.isArray(doc.properties) && doc.properties.length > 0) {
    md += `### Properties\n\n`;
    md += `| Property | Type | Security | Summary |\n`;
    md += `| :--- | :--- | :--- | :--- |\n`;
    for (const p of doc.properties) {
      const pName = p.name ? p.name.replace(/^[^.]+\./, '') : 'Unknown';
      const pType = `\`${p.type || 'any'}\``;
      const sec = p.security?.read ? `${p.security.read}` : 'None';
      const pSummary = cleanRobloxMarkdown(p.summary || '').replace(/[\r\n]+/g, ' ').slice(0, 100);
      md += `| **\`${pName}\`** | ${pType} | ${sec} | ${pSummary} |\n`;
    }
    md += `\n`;
  }

  // METHODS
  if (Array.isArray(doc.methods) && doc.methods.length > 0) {
    md += `### Methods\n`;
    for (const m of doc.methods) {
      const params = (m.parameters || []).map((p: any) => `${p.name}: ${p.type || 'any'}`).join(', ');
      const returns = (m.returns || []).map((r: any) => r.type || 'void').join(', ') || 'void';
      md += `* \`${m.name}(${params}) -> ${returns}\`\n  ${cleanRobloxMarkdown(m.summary || '')}\n`;
    }
    md += `\n`;
  }

  // FUNCTIONS (Libraries / Static)
  if (Array.isArray(doc.functions) && doc.functions.length > 0) {
    md += `### Functions\n`;
    for (const f of doc.functions) {
      const params = (f.parameters || []).map((p: any) => `${p.name}: ${p.type || 'any'}`).join(', ');
      const returns = (f.returns || []).map((r: any) => r.type || 'void').join(', ') || 'void';
      md += `* \`${f.name}(${params}) -> ${returns}\`\n  ${cleanRobloxMarkdown(f.summary || '')}\n`;
    }
    md += `\n`;
  }

  // EVENTS
  if (Array.isArray(doc.events) && doc.events.length > 0) {
    md += `### Events\n`;
    for (const e of doc.events) {
      const params = (e.parameters || []).map((p: any) => `${p.name}: ${p.type || 'any'}`).join(', ');
      md += `* \`${e.name}(${params})\`\n  ${cleanRobloxMarkdown(e.summary || '')}\n`;
    }
    md += `\n`;
  }

  // ENUM ITEMS
  if (Array.isArray(doc.items) && doc.items.length > 0) {
    md += `### Enum Items\n\n`;
    md += `| Item | Value | Summary |\n`;
    md += `| :--- | :--- | :--- |\n`;
    for (const it of doc.items) {
      const itSummary = cleanRobloxMarkdown(it.summary || '').replace(/[\r\n]+/g, ' ');
      md += `| **\`${it.name}\`** | \`${it.value}\` | ${itSummary} |\n`;
    }
    md += `\n`;
  }

  return md.trim();
}

