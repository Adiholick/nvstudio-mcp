import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

export interface VfxItem {
  id: string;
  name: string;
  category: string; // "Slash" | "Explosion" | "Aura" | "Projectile" | "Magic" | "Impact" | "Beam" | "Ambient"
  tags: string[];
  description?: string;
  author?: string;
  sourcePlaceId?: number;
  createdAt: string;
  nodeCount: number;
  stats: {
    emitters: number;
    beams: number;
    trails: number;
    lights: number;
  };
  data: any; // Serialized pure node graph
}

const DATA_DIR = path.join(process.cwd(), 'data');
const DB_FILE = path.join(DATA_DIR, 'vfx-database.json');
const BUNDLED_DB_FILE = path.join(__dirname, '..', 'data', 'vfx-database.json');

// ── Default Seed Presets ───────────────────────────────────────────────────────
const DEFAULT_PRESETS: VfxItem[] = [
  {
    id: 'preset-cyan-slash',
    name: 'Cyan Horizon Slash',
    category: 'Slash',
    tags: ['sword', 'cyan', 'combat', 'slash', 'beam'],
    description: 'High-speed sharp cybernetic slash effect with dual-layer brightness beams.',
    author: 'NVStudio',
    createdAt: new Date().toISOString(),
    nodeCount: 5,
    stats: { emitters: 0, beams: 2, trails: 0, lights: 0 },
    data: {
      version: 1,
      rootName: 'CyanHorizonSlash',
      rootClass: 'Folder',
      nodeCount: 5,
      stats: { emitters: 0, beams: 2, trails: 0, lights: 0 },
      nodes: [
        { class: 'Folder', name: 'CyanHorizonSlash', properties: { Name: 'CyanHorizonSlash' } },
        {
          parent: 1,
          class: 'Attachment',
          name: 'Att0',
          properties: {
            Name: 'Att0',
            Visible: false,
            CFrame: { t: 'CFrame', v: [2, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1] },
          },
        },
        {
          parent: 1,
          class: 'Attachment',
          name: 'Att1',
          properties: {
            Name: 'Att1',
            Visible: false,
            CFrame: { t: 'CFrame', v: [-2, -0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1] },
          },
        },
        {
          parent: 1,
          class: 'Beam',
          name: 'SlashCore',
          properties: {
            Name: 'SlashCore',
            Enabled: true,
            Attachment0: { t: 'Ref', v: 2 },
            Attachment1: { t: 'Ref', v: 3 },
            Brightness: 3000,
            LightEmission: 1,
            LightInfluence: 0,
            Width0: 1.2,
            Width1: 0.1,
            Texture: 'rbxassetid://85772363699785',
            TextureSpeed: 5,
            TextureLength: 1,
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [0, 0.8, 1] }],
                [1, { t: 'Color3', v: [0, 1, 0.8] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0, 0],
                [1, 1, 0],
              ],
            },
          },
        },
        {
          parent: 1,
          class: 'Beam',
          name: 'SlashGlow',
          properties: {
            Name: 'SlashGlow',
            Enabled: true,
            Attachment0: { t: 'Ref', v: 2 },
            Attachment1: { t: 'Ref', v: 3 },
            Brightness: 1500,
            LightEmission: 0.8,
            Width0: 2.5,
            Width1: 0.5,
            TextureSpeed: 3,
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [0.1, 0.5, 1] }],
                [1, { t: 'Color3', v: [0.2, 0.8, 1] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0.2, 0],
                [1, 1, 0],
              ],
            },
          },
        },
      ],
    },
  },
  {
    id: 'preset-solar-burst',
    name: 'Solar Flare Burst',
    category: 'Explosion',
    tags: ['fire', 'orange', 'explosion', 'particles', 'burst'],
    description: 'Radial fiery shockwave burst with expanding sparks and heat glow.',
    author: 'NVStudio',
    createdAt: new Date().toISOString(),
    nodeCount: 3,
    stats: { emitters: 2, beams: 0, trails: 0, lights: 1 },
    data: {
      version: 1,
      rootName: 'SolarFlareBurst',
      rootClass: 'Folder',
      nodeCount: 3,
      stats: { emitters: 2, beams: 0, trails: 0, lights: 1 },
      nodes: [
        { class: 'Folder', name: 'SolarFlareBurst', properties: { Name: 'SolarFlareBurst' } },
        {
          parent: 1,
          class: 'ParticleEmitter',
          name: 'Sparks',
          properties: {
            Name: 'Sparks',
            Enabled: true,
            Rate: 200,
            Speed: { t: 'NumberRange', v: [25, 45] },
            SpreadAngle: { t: 'Vector2', v: [180, 180] },
            Lifetime: { t: 'NumberRange', v: [0.4, 0.8] },
            LightEmission: 1,
            LightInfluence: 0,
            Brightness: 10,
            Size: {
              t: 'NumberSequence',
              v: [
                [0, 1.2, 0],
                [0.7, 0.4, 0],
                [1, 0, 0],
              ],
            },
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [1, 0.9, 0.5] }],
                [0.5, { t: 'Color3', v: [1, 0.4, 0] }],
                [1, { t: 'Color3', v: [0.8, 0.1, 0] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0, 0],
                [1, 1, 0],
              ],
            },
            Texture: 'rbxassetid://244221448',
          },
        },
        {
          parent: 1,
          class: 'PointLight',
          name: 'ExplosionLight',
          properties: {
            Name: 'ExplosionLight',
            Enabled: true,
            Brightness: 8,
            Range: 24,
            Color: { t: 'Color3', v: [1, 0.5, 0.1] },
            Shadows: true,
          },
        },
      ],
    },
  },
  {
    id: 'preset-dragon-aura',
    name: 'Azure Dragon Aura',
    category: 'Aura',
    tags: ['aura', 'magic', 'energy', 'cyan', 'blue'],
    description: 'Swirling ethereal flame aura for boss phases, charging states, and powerups.',
    author: 'NVStudio',
    createdAt: new Date().toISOString(),
    nodeCount: 2,
    stats: { emitters: 1, beams: 0, trails: 0, lights: 1 },
    data: {
      version: 1,
      rootName: 'AzureDragonAura',
      rootClass: 'Folder',
      nodeCount: 2,
      stats: { emitters: 1, beams: 0, trails: 0, lights: 1 },
      nodes: [
        { class: 'Folder', name: 'AzureDragonAura', properties: { Name: 'AzureDragonAura' } },
        {
          parent: 1,
          class: 'ParticleEmitter',
          name: 'FlameAura',
          properties: {
            Name: 'FlameAura',
            Enabled: true,
            Rate: 35,
            Speed: { t: 'NumberRange', v: [2, 5] },
            EmissionDirection: { t: 'EnumItem', e: 'NormalId', v: 'Top' },
            Lifetime: { t: 'NumberRange', v: [0.8, 1.4] },
            LightEmission: 0.9,
            LightInfluence: 0,
            Brightness: 5,
            Drag: 2,
            Acceleration: { t: 'Vector3', v: [0, 8, 0] },
            Size: {
              t: 'NumberSequence',
              v: [
                [0, 0.5, 0],
                [0.5, 2.5, 0],
                [1, 0.2, 0],
              ],
            },
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [0, 0.7, 1] }],
                [0.6, { t: 'Color3', v: [0.2, 0.2, 0.9] }],
                [1, { t: 'Color3', v: [0.05, 0, 0.4] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0.8, 0],
                [0.3, 0.2, 0],
                [1, 1, 0],
              ],
            },
            Texture: 'rbxassetid://258128463',
          },
        },
      ],
    },
  },
  {
    id: 'preset-arcane-rune',
    name: 'Arcane Summoning Circle',
    category: 'Magic',
    tags: ['magic', 'spell', 'circle', 'rune', 'purple'],
    description: 'Luminous spinning arcane circle with floating magical motes.',
    author: 'NVStudio',
    createdAt: new Date().toISOString(),
    nodeCount: 3,
    stats: { emitters: 1, beams: 0, trails: 0, lights: 1 },
    data: {
      version: 1,
      rootName: 'ArcaneSummoningCircle',
      rootClass: 'Folder',
      nodeCount: 3,
      stats: { emitters: 1, beams: 0, trails: 0, lights: 1 },
      nodes: [
        { class: 'Folder', name: 'ArcaneSummoningCircle', properties: { Name: 'ArcaneSummoningCircle' } },
        {
          parent: 1,
          class: 'ParticleEmitter',
          name: 'MagicSparks',
          properties: {
            Name: 'MagicSparks',
            Enabled: true,
            Rate: 40,
            Speed: { t: 'NumberRange', v: [1, 4] },
            Lifetime: { t: 'NumberRange', v: [1, 2] },
            LightEmission: 1,
            Size: {
              t: 'NumberSequence',
              v: [
                [0, 0.2, 0],
                [0.5, 0.6, 0],
                [1, 0, 0],
              ],
            },
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [0.8, 0.2, 1] }],
                [1, { t: 'Color3', v: [0.4, 0.8, 1] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0, 0],
                [1, 1, 0],
              ],
            },
            Texture: 'rbxassetid://244221448',
          },
        },
        {
          parent: 1,
          class: 'PointLight',
          name: 'RuneGlow',
          properties: {
            Name: 'RuneGlow',
            Enabled: true,
            Brightness: 4,
            Range: 16,
            Color: { t: 'Color3', v: [0.7, 0.2, 1] },
          },
        },
      ],
    },
  },
  {
    id: 'preset-emerald-beam',
    name: 'Emerald Laser Beam',
    category: 'Beam',
    tags: ['beam', 'laser', 'emerald', 'green', 'energy'],
    description: 'High-density focused energy beam with glowing outer edge.',
    author: 'NVStudio',
    createdAt: new Date().toISOString(),
    nodeCount: 4,
    stats: { emitters: 0, beams: 1, trails: 0, lights: 1 },
    data: {
      version: 1,
      rootName: 'EmeraldLaserBeam',
      rootClass: 'Folder',
      nodeCount: 4,
      stats: { emitters: 0, beams: 1, trails: 0, lights: 1 },
      nodes: [
        { class: 'Folder', name: 'EmeraldLaserBeam', properties: { Name: 'EmeraldLaserBeam' } },
        {
          parent: 1,
          class: 'Attachment',
          name: 'Origin',
          properties: { Name: 'Origin', CFrame: { t: 'CFrame', v: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1] } },
        },
        {
          parent: 1,
          class: 'Attachment',
          name: 'Target',
          properties: { Name: 'Target', CFrame: { t: 'CFrame', v: [0, 0, -30, 1, 0, 0, 0, 1, 0, 0, 0, 1] } },
        },
        {
          parent: 1,
          class: 'Beam',
          name: 'LaserCore',
          properties: {
            Name: 'LaserCore',
            Enabled: true,
            Attachment0: { t: 'Ref', v: 2 },
            Attachment1: { t: 'Ref', v: 3 },
            Brightness: 2500,
            LightEmission: 1,
            Width0: 1.5,
            Width1: 1.5,
            TextureSpeed: 8,
            Color: {
              t: 'ColorSequence',
              v: [
                [0, { t: 'Color3', v: [0.2, 1, 0.4] }],
                [1, { t: 'Color3', v: [0, 0.8, 0.2] }],
              ],
            },
            Transparency: {
              t: 'NumberSequence',
              v: [
                [0, 0.1, 0],
                [1, 0.1, 0],
              ],
            },
          },
        },
      ],
    },
  },
];

export function normalizeVfxCategory(rawCategory?: string): string {
  if (!rawCategory || typeof rawCategory !== 'string') return 'Ambient';
  const trimmed = rawCategory.trim();
  if (!trimmed) return 'Ambient';
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
}

export class VfxDatabase {
  private items: Map<string, VfxItem> = new Map();

  constructor() {
    this.ensureDirectory();
    this.loadDatabase();
  }

  private ensureDirectory() {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
  }

  private loadDatabase() {
    let targetFile = DB_FILE;
    if (!fs.existsSync(targetFile) && fs.existsSync(BUNDLED_DB_FILE)) {
      targetFile = BUNDLED_DB_FILE;
    }

    if (fs.existsSync(targetFile)) {
      try {
        const raw = fs.readFileSync(targetFile, 'utf-8');
        const list: VfxItem[] = JSON.parse(raw);
        for (const item of list) {
          item.category = normalizeVfxCategory(item.category);
          this.items.set(item.id, item);
        }
      } catch (err) {
        console.error('[VfxDatabase] Gagal membaca vfx-database.json, menggunakan preset default:', err);
        this.seedPresets();
      }
    } else {
      this.seedPresets();
    }
  }

  private seedPresets() {
    for (const preset of DEFAULT_PRESETS) {
      this.items.set(preset.id, preset);
    }
    this.saveToFile();
  }

  private saveToFile() {
    try {
      this.ensureDirectory();
      const list = Array.from(this.items.values());
      fs.writeFileSync(DB_FILE, JSON.stringify(list, null, 2), 'utf-8');
    } catch (err) {
      console.error('[VfxDatabase] Gagal menyimpan ke vfx-database.json:', err);
    }
  }

  public saveVfx(item: Omit<VfxItem, 'id' | 'createdAt'> & { id?: string; createdAt?: string }): VfxItem {
    const id = item.id || `vfx-${uuidv4().slice(0, 8)}`;
    const createdAt = item.createdAt || new Date().toISOString();
    const category = normalizeVfxCategory(item.category);
    const vfxItem: VfxItem = {
      ...item,
      id,
      category,
      createdAt,
      tags: Array.isArray(item.tags) ? item.tags : [category.toLowerCase()],
      nodeCount: item.nodeCount || (item.data?.nodes ? item.data.nodes.length : 1),
      stats: item.stats || { emitters: 0, beams: 0, trails: 0, lights: 0 },
    };
    this.items.set(id, vfxItem);
    this.saveToFile();
    return vfxItem;
  }

  public getVfx(id: string): VfxItem | undefined {
    return this.items.get(id);
  }

  public listVfx(filter?: { category?: string; query?: string }): VfxItem[] {
    let result = Array.from(this.items.values());

    if (filter?.category && filter.category !== 'All' && filter.category !== 'Semua') {
      const catLower = filter.category.toLowerCase();
      result = result.filter(item => item.category.toLowerCase() === catLower);
    }

    if (filter?.query && filter.query.trim()) {
      const q = filter.query.toLowerCase().trim();
      result = result.filter(item =>
        item.name.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q) ||
        (item.description && item.description.toLowerCase().includes(q)) ||
        (item.tags && item.tags.some(t => t.toLowerCase().includes(q)))
      );
    }

    return result.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }

  public deleteVfx(id: string): boolean {
    const deleted = this.items.delete(id);
    if (deleted) {
      this.saveToFile();
    }
    return deleted;
  }

  public getCategories(): { name: string; count: number }[] {
    const counts = new Map<string, number>();
    for (const item of this.items.values()) {
      const cat = normalizeVfxCategory(item.category);
      counts.set(cat, (counts.get(cat) || 0) + 1);
    }
    const categories: { name: string; count: number }[] = [];
    for (const [name, count] of counts.entries()) {
      categories.push({ name, count });
    }
    return categories.sort((a, b) => b.count - a.count);
  }
}

let instance: VfxDatabase | null = null;
export function getVfxDatabase(): VfxDatabase {
  if (!instance) {
    instance = new VfxDatabase();
  }
  return instance;
}

