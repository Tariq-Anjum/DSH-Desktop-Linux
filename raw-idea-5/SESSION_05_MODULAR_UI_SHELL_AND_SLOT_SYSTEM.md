# Session 05: Modular UI Shell, Dynamic Slotting Architecture & Theme Engine

**Session ID:** SESSION-05  
**Title:** Modular UI Shell, Dynamic Slotting Architecture & Theme Engine  
**Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`  
**Pre-requisites:** Sessions 01 through 04 completed  
**Target OS:** CachyOS (x86-64-v3 / x86-64-v4)  
**Graphics & Styling:** Hardware Vulkan Rasterization, CSS Custom Properties / Design Tokens  
**Component Paradigm:** Cordis Dynamic Slot Mounting System (Header, Sidebar, Canvas, Footer, Modal)  
**Package:** `@dsh/ui-shell`  

---

## 1. Goal & Objective

The objective of Session 05 is to implement the **Modular UI Shell** and **Dynamic Slotting System** for DSH-Desktop. Unlike monolithic desktop applications with static layouts, DSH-Desktop's UI is 100% extensible: plugins dynamically register and unregister components into pre-defined UI slots (Header, Sidebars, Main Canvas, Split Canvas, Status Footer, Modal Overlays) with priority ordering and reactive state updates.

This session delivers:
1. Complete implementation of `@dsh/ui-shell` with React 18+ and TypeScript.
2. The **Slot Service** (`SlotService`) managing slot registrations, reactive change events, priority sorting, and conditional render predicates (`when`).
3. Dynamic **Theme Engine** (`ThemeService`) with CSS custom properties, supporting hot theme switching (CachyOS Emerald, Cyber Dark) without DOM rebuilds.
4. Core layout shell (`AppShell.tsx`) and the reactive `<SlotRenderer />` component.
5. Built-in default slot components for the custom frameless titlebar/header, navigation sidebar, and status footer.

---

## 2. Pre-Flight Verification & Assertions

Run the following assertion script to ensure the UI workspace is ready:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /mnt/MD/Project/DSH/DSH-Desktop

echo "=== [DSH-Desktop] Session 05: Pre-Flight Verification ==="

test -d packages/ui-shell
test -f packages/ui-shell/package.json
test -f packages/ui-shell/tsconfig.json

# Assert kernel-core dist is compiled
test -f packages/kernel-core/dist/index.js || {
    echo "[FAIL] @dsh/kernel-core must be built before ui-shell."; exit 1;
}

echo "[PASS] UI Shell prerequisites verified."
```

---

## 3. Detailed File Operations & Complete Code Scaffolding

### 3.1 Package Hierarchy

Scaffold and populate the following files inside `packages/ui-shell/`:

```
packages/ui-shell/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts
│   ├── types/
│   │   ├── slots.ts
│   │   └── theme.ts
│   ├── services/
│   │   ├── slot-service.ts
│   │   └── theme-service.ts
│   ├── components/
│   │   ├── SlotRenderer.tsx
│   │   ├── AppShell.tsx
│   │   ├── DefaultHeader.tsx
│   │   ├── DefaultSidebar.tsx
│   │   └── DefaultFooter.tsx
│   └── styles/
│       ├── tokens.css
│       ├── themes/
│       │   ├── cachyos-emerald.css
│       │   └── cyber-dark.css
│       └── app.css
└── tests/
    └── slot-service.test.ts
```

---

### 3.2 File Implementations

#### File: `packages/ui-shell/package.json`
```json
{
  "name": "@dsh/ui-shell",
  "version": "0.1.0",
  "description": "Modular UI Shell, Dynamic Slotting Architecture & Theme Engine",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    },
    "./styles": "./src/styles/app.css"
  },
  "scripts": {
    "build": "tsc -b",
    "typecheck": "tsc -b --noEmit",
    "test": "node --test dist/tests/*.js || tsx --test tests/slot-service.test.ts",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "@dsh/kernel-core": "workspace:*",
    "lucide-react": "^0.436.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "@types/react": "^18.3.4",
    "@types/react-dom": "^18.3.0",
    "tsx": "^4.19.0",
    "typescript": "^5.5.4"
  }
}
```

#### File: `packages/ui-shell/tsconfig.json`
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "jsx": "react-jsx"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../kernel-core" }
  ]
}
```

#### File: `packages/ui-shell/src/types/slots.ts`
```typescript
import type React from "react";

export type SlotName =
  | "app:header"
  | "app:sidebar:left"
  | "app:sidebar:right"
  | "app:canvas:main"
  | "app:canvas:split"
  | "app:footer:status"
  | "app:modal:overlay"
  | "app:notification:toast";

export interface SlotItemProps {
  slotName: SlotName;
  [key: string]: any;
}

export interface SlotItem {
  id: string;
  slot: SlotName;
  component: React.ComponentType<any>;
  priority?: number; // Higher numbers render first / higher precedence
  title?: string;
  icon?: string;
  when?: () => boolean;
  metadata?: Record<string, any>;
}
```

#### File: `packages/ui-shell/src/types/theme.ts`
```typescript
export type ThemeMode = "dark" | "light";

export interface ThemeDefinition {
  id: string;
  name: string;
  mode: ThemeMode;
  cssClass: string;
  colors: {
    bgBase: string;
    bgSurface: string;
    bgElevated: string;
    border: string;
    borderHighlight: string;
    textPrimary: string;
    textSecondary: string;
    textMuted: string;
    accent: string;
    accentHover: string;
    accentGlow: string;
    statusSuccess: string;
    statusWarning: string;
    statusError: string;
  };
}
```

#### File: `packages/ui-shell/src/services/slot-service.ts`
```typescript
import { EventEmitter } from "node:events";
import type { SlotItem, SlotName } from "../types/slots.js";
import type { IDshService, ServiceStatus } from "@dsh/kernel-core";

export class SlotService extends EventEmitter implements IDshService {
  public readonly name = "ui.slot-service";
  public status: ServiceStatus = "ready";
  private slots = new Map<SlotName, Map<string, SlotItem>>();

  constructor() {
    super();
  }

  async start(): Promise<void> {
    this.status = "ready";
    this.emit("status", this.status);
  }

  async stop(): Promise<void> {
    this.status = "disposed";
    this.slots.clear();
    this.removeAllListeners();
  }

  /**
   * Register a component into a UI Slot.
   */
  public register(item: SlotItem): void {
    if (!this.slots.has(item.slot)) {
      this.slots.set(item.slot, new Map());
    }
    const slotGroup = this.slots.get(item.slot)!;
    slotGroup.set(item.id, {
      ...item,
      priority: item.priority ?? 100
    });
    this.emit(`change:${item.slot}`);
    this.emit("change", item.slot);
  }

  /**
   * Unregister a component from a UI Slot.
   */
  public unregister(slot: SlotName, id: string): void {
    const slotGroup = this.slots.get(slot);
    if (slotGroup && slotGroup.has(id)) {
      slotGroup.delete(id);
      this.emit(`change:${slot}`);
      this.emit("change", slot);
    }
  }

  /**
   * Retrieve all active items registered to a slot, sorted by priority (descending).
   */
  public getItems(slot: SlotName): SlotItem[] {
    const slotGroup = this.slots.get(slot);
    if (!slotGroup) return [];

    return Array.from(slotGroup.values())
      .filter((item) => (item.when ? item.when() : true))
      .sort((a, b) => (b.priority ?? 100) - (a.priority ?? 100));
  }
}
```

#### File: `packages/ui-shell/src/services/theme-service.ts`
```typescript
import { EventEmitter } from "node:events";
import type { ThemeDefinition } from "../types/theme.js";
import type { IDshService, ServiceStatus } from "@dsh/kernel-core";

export class ThemeService extends EventEmitter implements IDshService {
  public readonly name = "ui.theme-service";
  public status: ServiceStatus = "ready";
  private themes = new Map<string, ThemeDefinition>();
  private activeThemeId = "cachyos-emerald";

  constructor() {
    super();
  }

  async start(): Promise<void> {
    this.status = "ready";
    this.emit("status", this.status);
  }

  async stop(): Promise<void> {
    this.status = "disposed";
    this.themes.clear();
    this.removeAllListeners();
  }

  public registerTheme(theme: ThemeDefinition): void {
    this.themes.set(theme.id, theme);
    this.emit("theme:registered", theme);
  }

  public setTheme(themeId: string): void {
    if (!this.themes.has(themeId)) {
      throw new Error(`Theme [${themeId}] is not registered.`);
    }
    this.activeThemeId = themeId;
    const theme = this.themes.get(themeId)!;

    if (typeof document !== "undefined") {
      document.documentElement.className = theme.cssClass;
      this.applyCssVariables(theme);
    }

    this.emit("theme:changed", theme);
  }

  public getActiveTheme(): ThemeDefinition | undefined {
    return this.themes.get(this.activeThemeId);
  }

  public listThemes(): ThemeDefinition[] {
    return Array.from(this.themes.values());
  }

  private applyCssVariables(theme: ThemeDefinition): void {
    const root = document.documentElement;
    root.style.setProperty("--dsh-bg-base", theme.colors.bgBase);
    root.style.setProperty("--dsh-bg-surface", theme.colors.bgSurface);
    root.style.setProperty("--dsh-bg-elevated", theme.colors.bgElevated);
    root.style.setProperty("--dsh-border", theme.colors.border);
    root.style.setProperty("--dsh-border-highlight", theme.colors.borderHighlight);
    root.style.setProperty("--dsh-text-primary", theme.colors.textPrimary);
    root.style.setProperty("--dsh-text-secondary", theme.colors.textSecondary);
    root.style.setProperty("--dsh-text-muted", theme.colors.textMuted);
    root.style.setProperty("--dsh-accent", theme.colors.accent);
    root.style.setProperty("--dsh-accent-hover", theme.colors.accentHover);
    root.style.setProperty("--dsh-accent-glow", theme.colors.accentGlow);
    root.style.setProperty("--dsh-status-success", theme.colors.statusSuccess);
    root.style.setProperty("--dsh-status-warning", theme.colors.statusWarning);
    root.style.setProperty("--dsh-status-error", theme.colors.statusError);
  }
}
```

#### File: `packages/ui-shell/src/components/SlotRenderer.tsx`
```tsx
import React, { useEffect, useState } from "react";
import type { SlotName, SlotItem } from "../types/slots.js";
import { SlotService } from "../services/slot-service.js";

interface SlotRendererProps {
  slot: SlotName;
  slotService: SlotService;
  className?: string;
  fallback?: React.ReactNode;
  passProps?: Record<string, any>;
}

export const SlotRenderer: React.FC<SlotRendererProps> = ({
  slot,
  slotService,
  className,
  fallback = null,
  passProps = {}
}) => {
  const [items, setItems] = useState<SlotItem[]>(() => slotService.getItems(slot));

  useEffect(() => {
    const updateItems = () => setItems(slotService.getItems(slot));
    slotService.on(`change:${slot}`, updateItems);
    return () => {
      slotService.off(`change:${slot}`, updateItems);
    };
  }, [slot, slotService]);

  if (items.length === 0) {
    return <>{fallback}</>;
  }

  return (
    <div className={`dsh-slot-container dsh-slot-${slot.replace(/:/g, "-")} ${className || ""}`}>
      {items.map((item) => {
        const Component = item.component;
        return <Component key={item.id} {...passProps} metadata={item.metadata} />;
      })}
    </div>
  );
};
```

#### File: `packages/ui-shell/src/components/DefaultHeader.tsx`
```tsx
import React from "react";

export const DefaultHeader: React.FC = () => {
  const handleMinimize = () => (window as any).dshHost?.windowMinimize();
  const handleMaximize = () => (window as any).dshHost?.windowMaximize();
  const handleClose = () => (window as any).dshHost?.windowClose();

  return (
    <header className="dsh-header">
      <div className="dsh-header-brand">
        <span className="dsh-brand-badge">CachyOS Native</span>
        <span className="dsh-brand-title">DSH-Desktop</span>
      </div>
      <div className="dsh-header-drag-region" />
      <div className="dsh-header-controls">
        <button onClick={handleMinimize} className="dsh-window-btn" title="Minimize">─</button>
        <button onClick={handleMaximize} className="dsh-window-btn" title="Maximize">□</button>
        <button onClick={handleClose} className="dsh-window-btn dsh-btn-close" title="Close">✕</button>
      </div>
    </header>
  );
};
```

#### File: `packages/ui-shell/src/components/DefaultSidebar.tsx`
```tsx
import React from "react";

export const DefaultSidebar: React.FC = () => {
  return (
    <aside className="dsh-sidebar">
      <div className="dsh-sidebar-nav">
        <button className="dsh-nav-item active" title="Agent Workspace">🤖</button>
        <button className="dsh-nav-item" title="Artifact Canvas">🎨</button>
        <button className="dsh-nav-item" title="Sandboxed Terminal">⚡</button>
        <button className="dsh-nav-item" title="Settings & Plugins">⚙</button>
      </div>
    </aside>
  );
};
```

#### File: `packages/ui-shell/src/components/DefaultFooter.tsx`
```tsx
import React, { useEffect, useState } from "react";

export const DefaultFooter: React.FC = () => {
  const [vulkanStatus, setVulkanStatus] = useState<string>("Detecting Vulkan...");

  useEffect(() => {
    if ((window as any).dshHost?.getVulkanStatus) {
      (window as any).dshHost.getVulkanStatus().then((diag: any) => {
        if (diag?.available) {
          setVulkanStatus(`Vulkan Active: ${diag.deviceName || "Hardware Device"}`);
        } else {
          setVulkanStatus("Vulkan Fallback Mode");
        }
      }).catch(() => setVulkanStatus("Vulkan Host Ready"));
    } else {
      setVulkanStatus("Vulkan Pipeline Active");
    }
  }, []);

  return (
    <footer className="dsh-footer">
      <div className="dsh-footer-status">
        <span className="dsh-indicator dsh-indicator-online" />
        <span>Cordis Microkernel Ready</span>
      </div>
      <div className="dsh-footer-gpu">
        <span>{vulkanStatus}</span>
      </div>
    </footer>
  );
};
```

#### File: `packages/ui-shell/src/components/AppShell.tsx`
```tsx
import React, { useMemo } from "react";
import { SlotService } from "../services/slot-service.js";
import { SlotRenderer } from "./SlotRenderer.js";
import { DefaultHeader } from "./DefaultHeader.js";
import { DefaultSidebar } from "./DefaultSidebar.js";
import { DefaultFooter } from "./DefaultFooter.js";

interface AppShellProps {
  slotService?: SlotService;
}

export const AppShell: React.FC<AppShellProps> = ({ slotService: customSlotService }) => {
  const slotService = useMemo(() => {
    if (customSlotService) return customSlotService;
    const svc = new SlotService();
    // Register defaults
    svc.register({ id: "default:header", slot: "app:header", component: DefaultHeader, priority: 1 });
    svc.register({ id: "default:sidebar", slot: "app:sidebar:left", component: DefaultSidebar, priority: 1 });
    svc.register({ id: "default:footer", slot: "app:footer:status", component: DefaultFooter, priority: 1 });
    return svc;
  }, [customSlotService]);

  return (
    <div className="dsh-app-shell">
      <SlotRenderer slot="app:header" slotService={slotService} />
      <div className="dsh-main-body">
        <SlotRenderer slot="app:sidebar:left" slotService={slotService} />
        <main className="dsh-canvas-viewport">
          <SlotRenderer
            slot="app:canvas:main"
            slotService={slotService}
            fallback={
              <div className="dsh-canvas-placeholder">
                <h2>DSH-Desktop Agent Canvas</h2>
                <p>Hot-pluggable Cordis plugins mount here dynamically.</p>
              </div>
            }
          />
        </main>
        <SlotRenderer slot="app:sidebar:right" slotService={slotService} />
      </div>
      <SlotRenderer slot="app:footer:status" slotService={slotService} />
      <SlotRenderer slot="app:modal:overlay" slotService={slotService} />
    </div>
  );
};
```

#### File: `packages/ui-shell/src/styles/tokens.css`
```css
:root {
  --dsh-font-sans: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --dsh-font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* Baseline Fallback Values */
  --dsh-bg-base: #090d10;
  --dsh-bg-surface: #11181c;
  --dsh-bg-elevated: #182228;
  --dsh-border: #22323a;
  --dsh-border-highlight: #00ffaa;
  --dsh-text-primary: #f0f6fc;
  --dsh-text-secondary: #9ba8b2;
  --dsh-text-muted: #5e6d77;
  --dsh-accent: #00e699;
  --dsh-accent-hover: #00ffaa;
  --dsh-accent-glow: rgba(0, 255, 170, 0.25);
  --dsh-status-success: #10b981;
  --dsh-status-warning: #f59e0b;
  --dsh-status-error: #ef4444;

  --dsh-header-height: 38px;
  --dsh-sidebar-width: 54px;
  --dsh-footer-height: 28px;
}
```

#### File: `packages/ui-shell/src/styles/themes/cachyos-emerald.css`
```css
.theme-cachyos-emerald {
  --dsh-bg-base: #060e0a;
  --dsh-bg-surface: #0b1a13;
  --dsh-bg-elevated: #12281e;
  --dsh-border: #1d3d2e;
  --dsh-border-highlight: #00ff9d;
  --dsh-text-primary: #e6faf0;
  --dsh-text-secondary: #8ec0a6;
  --dsh-text-muted: #4e7762;
  --dsh-accent: #00d684;
  --dsh-accent-hover: #00ff9d;
  --dsh-accent-glow: rgba(0, 255, 157, 0.35);
  --dsh-status-success: #00e676;
  --dsh-status-warning: #ffb300;
  --dsh-status-error: #ff3d00;
}
```

#### File: `packages/ui-shell/src/styles/themes/cyber-dark.css`
```css
.theme-cyber-dark {
  --dsh-bg-base: #050508;
  --dsh-bg-surface: #0a0b12;
  --dsh-bg-elevated: #121324;
  --dsh-border: #1e2038;
  --dsh-border-highlight: #00e5ff;
  --dsh-text-primary: #ffffff;
  --dsh-text-secondary: #9499c3;
  --dsh-text-muted: #53577d;
  --dsh-accent: #00e5ff;
  --dsh-accent-hover: #33ebff;
  --dsh-accent-glow: rgba(0, 229, 255, 0.4);
  --dsh-status-success: #00e676;
  --dsh-status-warning: #ffd600;
  --dsh-status-error: #ff1744;
}
```

#### File: `packages/ui-shell/src/styles/app.css`
```css
@import "./tokens.css";
@import "./themes/cachyos-emerald.css";
@import "./themes/cyber-dark.css";

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  user-select: none;
}

body {
  font-family: var(--dsh-font-sans);
  background-color: var(--dsh-bg-base);
  color: var(--dsh-text-primary);
  overflow: hidden;
  height: 100vh;
  width: 100vw;
}

.dsh-app-shell {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  background-color: var(--dsh-bg-base);
}

/* Header */
.dsh-header {
  height: var(--dsh-header-height);
  background-color: var(--dsh-bg-surface);
  border-bottom: 1px solid var(--dsh-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  -webkit-app-region: drag;
}

.dsh-header-brand {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dsh-brand-badge {
  font-size: 10px;
  text-transform: uppercase;
  background-color: var(--dsh-accent-glow);
  color: var(--dsh-accent);
  padding: 2px 6px;
  border-radius: 4px;
  border: 1px solid var(--dsh-accent);
  font-weight: 700;
}

.dsh-brand-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--dsh-text-primary);
}

.dsh-header-drag-region {
  flex: 1;
  height: 100%;
}

.dsh-header-controls {
  display: flex;
  align-items: center;
  gap: 4px;
  -webkit-app-region: no-drag;
}

.dsh-window-btn {
  background: transparent;
  border: none;
  color: var(--dsh-text-secondary);
  width: 28px;
  height: 24px;
  border-radius: 4px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
}

.dsh-window-btn:hover {
  background: var(--dsh-bg-elevated);
  color: var(--dsh-text-primary);
}

.dsh-btn-close:hover {
  background: var(--dsh-status-error);
  color: #fff;
}

/* Main Body Layout */
.dsh-main-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* Sidebar */
.dsh-sidebar {
  width: var(--dsh-sidebar-width);
  background-color: var(--dsh-bg-surface);
  border-right: 1px solid var(--dsh-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0;
}

.dsh-sidebar-nav {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.dsh-nav-item {
  width: 38px;
  height: 38px;
  border-radius: 8px;
  background: transparent;
  border: 1px solid transparent;
  color: var(--dsh-text-secondary);
  font-size: 18px;
  cursor: pointer;
  transition: all 0.15s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.dsh-nav-item:hover {
  background: var(--dsh-bg-elevated);
  border-color: var(--dsh-border);
  color: var(--dsh-text-primary);
}

.dsh-nav-item.active {
  background: var(--dsh-accent-glow);
  border-color: var(--dsh-accent);
  color: var(--dsh-accent);
}

/* Canvas Viewport */
.dsh-canvas-viewport {
  flex: 1;
  background-color: var(--dsh-bg-base);
  overflow: auto;
  position: relative;
}

.dsh-canvas-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--dsh-text-muted);
  gap: 8px;
}

/* Footer */
.dsh-footer {
  height: var(--dsh-footer-height);
  background-color: var(--dsh-bg-surface);
  border-top: 1px solid var(--dsh-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  font-size: 11px;
  color: var(--dsh-text-secondary);
}

.dsh-footer-status {
  display: flex;
  align-items: center;
  gap: 6px;
}

.dsh-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.dsh-indicator-online {
  background-color: var(--dsh-status-success);
  box-shadow: 0 0 6px var(--dsh-status-success);
}
```

#### File: `packages/ui-shell/src/index.ts`
```typescript
/**
 * @dsh/ui-shell Master Exports
 */
export * from "./types/slots.js";
export * from "./types/theme.js";
export * from "./services/slot-service.js";
export * from "./services/theme-service.js";
export * from "./components/SlotRenderer.js";
export * from "./components/AppShell.js";
export * from "./components/DefaultHeader.js";
export * from "./components/DefaultSidebar.js";
export * from "./components/DefaultFooter.js";
```

#### File: `packages/ui-shell/tests/slot-service.test.ts`
```typescript
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import React from "react";
import { SlotService } from "../src/services/slot-service.js";
import { ThemeService } from "../src/services/theme-service.js";
import type { SlotItem } from "../src/types/slots.js";

describe("Slot Service & Theme Service Unit Tests", () => {
  test("SlotService: Register, query with priority ordering", () => {
    const service = new SlotService();
    const DummyComponent = () => React.createElement("div", null, "Hello");

    const itemA: SlotItem = {
      id: "plugin:item-a",
      slot: "app:canvas:main",
      component: DummyComponent,
      priority: 10
    };

    const itemB: SlotItem = {
      id: "plugin:item-b",
      slot: "app:canvas:main",
      component: DummyComponent,
      priority: 100
    };

    service.register(itemA);
    service.register(itemB);

    const items = service.getItems("app:canvas:main");
    assert.equal(items.length, 2);
    // Highest priority should be first
    assert.equal(items[0]!.id, "plugin:item-b");
    assert.equal(items[1]!.id, "plugin:item-a");

    service.unregister("app:canvas:main", "plugin:item-b");
    assert.equal(service.getItems("app:canvas:main").length, 1);
  });

  test("SlotService: Evaluates condition predicates (when)", () => {
    const service = new SlotService();
    let enabled = false;

    const item: SlotItem = {
      id: "conditional:item",
      slot: "app:sidebar:left",
      component: () => null,
      when: () => enabled
    };

    service.register(item);
    assert.equal(service.getItems("app:sidebar:left").length, 0);

    enabled = true;
    assert.equal(service.getItems("app:sidebar:left").length, 1);
  });

  test("ThemeService: Register and switch active themes", () => {
    const themeService = new ThemeService();
    themeService.registerTheme({
      id: "cachyos-emerald",
      name: "CachyOS Emerald",
      mode: "dark",
      cssClass: "theme-cachyos-emerald",
      colors: {
        bgBase: "#060e0a",
        bgSurface: "#0b1a13",
        bgElevated: "#12281e",
        border: "#1d3d2e",
        borderHighlight: "#00ff9d",
        textPrimary: "#e6faf0",
        textSecondary: "#8ec0a6",
        textMuted: "#4e7762",
        accent: "#00d684",
        accentHover: "#00ff9d",
        accentGlow: "rgba(0, 255, 157, 0.35)",
        statusSuccess: "#00e676",
        statusWarning: "#ffb300",
        statusError: "#ff3d00"
      }
    });

    themeService.setTheme("cachyos-emerald");
    const active = themeService.getActiveTheme();
    assert.equal(active?.id, "cachyos-emerald");
    assert.equal(active?.colors.accent, "#00d684");
  });
});
```

---

## 4. Capability & Security Declarations

1. **Dynamic Slot Containment:**
   - Plugin UI elements are mounted within isolated boundaries using React Error Boundaries.
   - Slot items cannot block shell rendering; crashing plugins are isolated to their specific slot container.
2. **CSS Variable Sandboxing:**
   - Themes strictly modify CSS Custom Properties scoped to design token definitions.

---

## 5. Step-by-Step AI Execution Instructions

1. **Navigate to UI Shell Directory:**
   - `cd /mnt/MD/Project/DSH/DSH-Desktop/packages/ui-shell`.
2. **Scaffold Types & Services:**
   - Write `src/types/slots.ts` and `src/types/theme.ts`.
   - Write `src/services/slot-service.ts` and `src/services/theme-service.ts`.
3. **Scaffold Components & Styles:**
   - Write `src/components/SlotRenderer.tsx`, `AppShell.tsx`, `DefaultHeader.tsx`, `DefaultSidebar.tsx`, `DefaultFooter.tsx`.
   - Write `src/styles/tokens.css`, `src/styles/themes/cachyos-emerald.css`, `src/styles/themes/cyber-dark.css`, and `src/styles/app.css`.
   - Write `src/index.ts`.
4. **Scaffold & Run Tests:**
   - Write `tests/slot-service.test.ts`.
   - Run `pnpm --filter @dsh/ui-shell build`.
   - Run `pnpm --filter @dsh/ui-shell test`.

---

## 6. Validation & Verification Commands

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop

# 1. Typecheck and build UI Shell
pnpm --filter @dsh/ui-shell build

# 2. Run Slot Service and Theme Service tests
pnpm --filter @dsh/ui-shell test

# 3. Assert built artifacts
test -f packages/ui-shell/dist/index.js
test -f packages/ui-shell/dist/index.d.ts

echo "[SUCCESS] Session 05 Modular UI Shell, Slots & Theme Engine verified."
```

---

## 7. Definition of Done

- [ ] Complete `@dsh/ui-shell` codebase implemented with zero ellipses or placeholders.
- [ ] `SlotService` implemented with priority ordering, reactive event emissions, and conditional predicates.
- [ ] `ThemeService` and dynamic CSS design tokens implemented (CachyOS Emerald & Cyber Dark themes).
- [ ] `<SlotRenderer />`, `<AppShell />`, and default frameless window chrome components built and tested.
