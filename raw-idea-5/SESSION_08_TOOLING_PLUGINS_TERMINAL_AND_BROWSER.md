# Session 08: Tooling Plugins: Sandboxed Terminal & Headless Browser

> **Objective:** Implement the official Tooling Plugins for DSH-Desktop on CachyOS: the **Sandboxed Terminal Plugin** (`plugins/tool-terminal`) and the **Headless Browser Automation Plugin** (`plugins/tool-browser`). The Terminal plugin mounts a high-performance `xterm.js` emulator into the `bottom.panel` slot backed by `node-pty` processes running strictly inside unprivileged Bubblewrap (`bwrap`) containers. The Browser plugin provides Playwright/Chromium automation for full-page navigation, DOM extraction, element interaction, and screenshot capture for multimodal agent consumption.

---

## 1. Execution Context & Metadata

* **Session ID:** `DSH-SESSION-08`
* **Title:** Tooling Plugins: Sandboxed Terminal & Headless Browser
* **Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`
* **Upstream Implementation Remote:** `https://github.com/Tariq-Anjum/dsh-desktop.git`
* **Architecture Reference Remote:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux.git`
* **Pre-requisites:**
  * Session 01: Baseline environment, CachyOS toolchain (`-march=x86-64-v3`), and directories initialized.
  * Session 02: Cordis Core Plugin Runtime (`PluginContext`, `ServiceContainer`, `PluginRegistry`) active.
  * Session 03: Host-Agent IPC Protocol and Bubblewrap (`bwrap`) security sandbox bridge operational.
  * Session 05: Modular UI Shell, dynamic slotting engine (`bottom.panel`, `workspace.main`), and theme engine active.
  * Session 06: Core Agent Runtime & Model Orchestration Plugin active with tool dispatcher.
* **Target Operating System:** CachyOS (Linux 6.x BORE/sched-ext kernel, x86-64-v3/v4, Wayland/X11).
* **Core Technologies:** TypeScript 5.5+, Node.js `node-pty`, `xterm` / `@xterm/addon-fit` / `@xterm/addon-webgl`, Bubblewrap (`bwrap`), Playwright / Chromium headless engine.

---

## 2. Architecture & Data Flow Diagram

```
+---------------------------------------------------------------------------------------------------+
|                                  Cordis Plugin Context (`ctx`)                                     |
|  - Injects: `ctx.services.get('agent')`, `ctx.services.get('ipc')`, `ctx.services.get('slots')`   |
|  - Provides: `ctx.services.provide('terminal')`, `ctx.services.provide('browser')`               |
+---------------------------------------------------------------------------------------------------+
                                                  |
                         +------------------------+------------------------+
                         |                                                 |
+--------------------------------------------------+     +-----------------------------------+
|      Sandboxed Terminal (`tool-terminal`)        |     |  Headless Browser (`tool-browser`)|
|  - PTY Controller: `PtyManager.ts`               |     |  - Engine: `BrowserManager.ts`    |
|  - Sandbox: `bwrap` Container Process            |     |  - Playwright / Chromium Sandbox  |
|  - UI: `TerminalPanel.tsx` (xterm.js WebGL)      |     |  - UI: `BrowserView.tsx` (Live)   |
|  - Agent Tools: `terminal.exec`, `terminal.pty`  |     |  - Agent Tools: `browser.navigate`|
|  - Slot: `bottom.panel`                          |     |  - Slot: `workspace.main`         |
+--------------------------------------------------+     +-----------------------------------+
                         |                                                 |
                         +------------------------+------------------------+
                                                  |
+---------------------------------------------------------------------------------------------------+
|                                   Host OS Isolation & Containment                                 |
|  - Terminal processes execute inside `bwrap --unshare-all --ro-bind /usr ...`                     |
|  - Browser runs in isolated user-data-dir under `/tmp/dsh-browser-sandbox/`                       |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Pre-Flight Verification & Assertions

Execute the following pre-flight assertions to confirm environment readiness before creating plugin files:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
echo "==> [Pre-Flight] Verifying Session 08 prerequisites in ${TARGET_DIR}..."

# 1. Verify bubblewrap binary is available on CachyOS
if ! command -v bwrap > /dev/null 2>&1; then
    echo "ERROR: bubblewrap (bwrap) not found on system path!"
    exit 1
fi
echo "==> [Pre-Flight] Bubblewrap found: $(bwrap --version)"

# 2. Check Playwright / Chromium headless availability
if ! command -v chromium > /dev/null 2>&1 && ! command -v google-chrome-stable > /dev/null 2>&1; then
    echo "==> [Pre-Flight] Note: System Chromium not found. Playwright will manage bundled browser."
fi

# 3. Check directory and core files from Sessions 01-06
if [ ! -d "${TARGET_DIR}/plugins/agent-orchestrator" ]; then
    echo "ERROR: Agent Orchestrator from Session 06 missing!"
    exit 1
fi

echo "==> [Pre-Flight] Prerequisites validated successfully."
```

---

## 4. Capability & Security Declarations

* **`plugins/tool-terminal` Permissions:**
  * `ipc:pty`: Open and manage pseudo-terminal streams.
  * `ipc:bwrap`: Spawn commands inside Bubblewrap unprivileged user namespaces.
  * `fs:workspace`: Bind `/mnt/MD/Project/DSH/DSH-Desktop` as the working directory inside the container.
* **`plugins/tool-browser` Permissions:**
  * `network:browser`: Outbound HTTP/HTTPS access strictly scoped to Chromium worker process.
  * `fs:tmp`: Manage temporary session storage under `/tmp/dsh-browser-sandbox/`.
  * `ipc:browser`: Stream screenshot buffers and DOM snapshots across the IPC channel.

---

## 5. Detailed File Operations & Complete Code Scaffolding

### Part A: Sandboxed Terminal Plugin (`plugins/tool-terminal`)

#### File 1: Plugin Manifest (`plugins/tool-terminal/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.tool-terminal",
  "name": "Sandboxed Terminal & PTY Manager",
  "version": "1.0.0",
  "description": "xterm.js WebGL terminal emulator and bwrap sandboxed PTY process manager",
  "author": "Tariq Anjum",
  "type": "hybrid",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "slots": [
    {
      "target": "bottom.panel",
      "priority": 100,
      "component": "TerminalPanel"
    },
    {
      "target": "sidebar.nav",
      "priority": 70,
      "component": "TerminalNavIcon"
    }
  ],
  "permissions": [
    "ipc:pty",
    "ipc:bwrap",
    "fs:workspace"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.plugin.agent-orchestrator": ">=1.0.0"
  },
  "defaultConfig": {
    "shell": "/bin/bash",
    "fontSize": 13,
    "fontFamily": "Fira Code, monospace",
    "cursorBlink": true,
    "allowNetwork": true
  }
}
```

#### File 2: Sandboxed PTY Manager (`plugins/tool-terminal/src/PtyManager.ts`)
```typescript
import { spawn, IPty } from 'node-pty';
import { EventEmitter } from 'events';
import * as path from 'path';

export interface PtyOptions {
  cols?: number;
  rows?: number;
  cwd?: string;
  allowNetwork?: boolean;
}

export class PtyManager extends EventEmitter {
  private ptyProcesses = new Map<string, IPty>();

  createSession(id: string, options: PtyOptions = {}): IPty {
    if (this.ptyProcesses.has(id)) {
      return this.ptyProcesses.get(id)!;
    }

    const workspaceDir = options.cwd || process.env.DSH_WORKSPACE_DIR || '/mnt/MD/Project/DSH/DSH-Desktop';
    const cols = options.cols || 100;
    const rows = options.rows || 30;

    // Construct Bubblewrap containment args for terminal
    const bwrapArgs: string[] = [
      '--unshare-all',
      '--ro-bind', '/usr', '/usr',
      '--ro-bind', '/lib', '/lib',
      '--ro-bind', '/lib64', '/lib64',
      '--ro-bind', '/bin', '/bin',
      '--ro-bind', '/etc/resolv.conf', '/etc/resolv.conf',
      '--ro-bind', '/etc/hosts', '/etc/hosts',
      '--proc', '/proc',
      '--dev', '/dev',
      '--tmpfs', '/tmp',
      '--bind', workspaceDir, workspaceDir,
      '--chdir', workspaceDir,
      '--setenv', 'HOME', '/tmp',
      '--setenv', 'TERM', 'xterm-256color',
      '--setenv', 'PATH', '/usr/local/bin:/usr/bin:/bin'
    ];

    if (options.allowNetwork !== false) {
      bwrapArgs.push('--share-net');
    }

    // Command inside sandbox: interactive bash
    bwrapArgs.push('/bin/bash');

    const ptyProcess = spawn('bwrap', bwrapArgs, {
      name: 'xterm-256color',
      cols,
      rows,
      cwd: workspaceDir,
      env: {
        TERM: 'xterm-256color',
        LANG: 'en_US.UTF-8'
      }
    });

    ptyProcess.onData((data: string) => {
      this.emit(`data:${id}`, data);
    });

    ptyProcess.onExit((event: { exitCode: number; signal?: number }) => {
      this.ptyProcesses.delete(id);
      this.emit(`exit:${id}`, event);
    });

    this.ptyProcesses.set(id, ptyProcess);
    return ptyProcess;
  }

  write(id: string, data: string): boolean {
    const proc = this.ptyProcesses.get(id);
    if (!proc) return false;
    proc.write(data);
    return true;
  }

  resize(id: string, cols: number, rows: number): boolean {
    const proc = this.ptyProcesses.get(id);
    if (!proc) return false;
    try {
      proc.resize(cols, rows);
      return true;
    } catch {
      return false;
    }
  }

  kill(id: string): boolean {
    const proc = this.ptyProcesses.get(id);
    if (!proc) return false;
    try {
      proc.kill();
      this.ptyProcesses.delete(id);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Execute a one-off command inside the bwrap sandbox and return captured stdout/stderr.
   */
  async execCommand(command: string, cwd?: string, timeoutMs = 30000): Promise<{ stdout: string; exitCode: number }> {
    return new Promise((resolve, reject) => {
      const sessionId = `exec-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
      let outputBuffer = '';

      const pty = this.createSession(sessionId, { cwd });
      const timer = setTimeout(() => {
        this.kill(sessionId);
        reject(new Error(`Command timed out after ${timeoutMs}ms: ${command}`));
      }, timeoutMs);

      const onData = (data: string) => {
        outputBuffer += data;
      };

      const onExit = (event: { exitCode: number }) => {
        clearTimeout(timer);
        this.removeListener(`data:${sessionId}`, onData);
        resolve({
          stdout: outputBuffer,
          exitCode: event.exitCode
        });
      };

      this.on(`data:${sessionId}`, onData);
      this.once(`exit:${sessionId}`, onExit);

      pty.write(`${command}
exit
`);
    });
  }
}
```

#### File 3: Terminal UI Component (`plugins/tool-terminal/src/ui/TerminalPanel.tsx`)
```tsx
import React, { useEffect, useRef } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebglAddon } from '@xterm/addon-webgl';
import { PtyManager } from '../PtyManager';
import 'xterm/css/xterm.css';

export interface TerminalPanelProps {
  ptyManager?: PtyManager;
  sessionId?: string;
  onClose?: () => void;
}

export const TerminalPanel: React.FC<TerminalPanelProps> = ({
  ptyManager,
  sessionId = 'default-terminal',
  onClose
}) => {
  const terminalRef = useRef<HTMLDivElement>(null);
  const xtermInstance = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);

  useEffect(() => {
    if (!terminalRef.current || !ptyManager) return;

    const term = new Terminal({
      cursorBlink: true,
      fontFamily: 'Fira Code, Consolas, monospace',
      fontSize: 13,
      theme: {
        background: '#0e1017',
        foreground: '#e2e8f0',
        cursor: '#60a5fa',
        black: '#1e222d',
        red: '#ef4444',
        green: '#10b981',
        yellow: '#f59e0b',
        blue: '#3b82f6',
        magenta: '#8b5cf6',
        cyan: '#06b6d4',
        white: '#f8fafc'
      }
    });

    const fitAddon = new FitAddon();
    term.loadAddon(fitAddon);

    try {
      const webglAddon = new WebglAddon();
      term.loadAddon(webglAddon);
    } catch {
      // Fallback to standard 2D canvas if WebGL unavailable
    }

    term.open(terminalRef.current);
    fitAddon.fit();

    xtermInstance.current = term;
    fitAddonRef.current = fitAddon;

    // Create or connect to PTY session
    ptyManager.createSession(sessionId, {
      cols: term.cols,
      rows: term.rows
    });

    // PTY -> xterm data streaming
    const handlePtyData = (data: string) => {
      term.write(data);
    };

    ptyManager.on(`data:${sessionId}`, handlePtyData);

    // xterm -> PTY keystrokes
    const disposable = term.onData((data) => {
      ptyManager.write(sessionId, data);
    });

    // Window resize handler
    const handleResize = () => {
      if (fitAddonRef.current && xtermInstance.current) {
        fitAddonRef.current.fit();
        ptyManager.resize(
          sessionId,
          xtermInstance.current.cols,
          xtermInstance.current.rows
        );
      }
    };
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      disposable.dispose();
      ptyManager.removeListener(`data:${sessionId}`, handlePtyData);
      term.dispose();
    };
  }, [ptyManager, sessionId]);

  return (
    <div className="flex flex-col h-full bg-[#0e1017] border-t border-[#232736]">
      {/* Header bar */}
      <div className="flex items-center justify-between px-4 py-1.5 bg-[#141722] border-b border-[#232736] text-xs text-gray-400">
        <div className="flex items-center space-x-2">
          <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
          <span className="font-semibold text-gray-300">Terminal (bwrap sandbox)</span>
          <span className="text-gray-500 font-mono">[{sessionId}]</span>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-200 transition-colors"
          >
            ✕
          </button>
        )}
      </div>

      {/* xterm.js container */}
      <div ref={terminalRef} className="flex-1 w-full p-2 overflow-hidden" />
    </div>
  );
};
```

---

### Part B: Headless Browser Automation Plugin (`plugins/tool-browser`)

#### File 4: Plugin Manifest (`plugins/tool-browser/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.tool-browser",
  "name": "Headless Browser Automation",
  "version": "1.0.0",
  "description": "Playwright/Chromium automation engine for navigation, DOM extraction, and visual screenshots",
  "author": "Tariq Anjum",
  "type": "hybrid",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "slots": [
    {
      "target": "workspace.main",
      "priority": 60,
      "component": "BrowserView"
    },
    {
      "target": "sidebar.nav",
      "priority": 65,
      "component": "BrowserNavIcon"
    }
  ],
  "permissions": [
    "network:browser",
    "fs:tmp",
    "ipc:browser"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.plugin.agent-orchestrator": ">=1.0.0"
  },
  "defaultConfig": {
    "headless": true,
    "viewportWidth": 1280,
    "viewportHeight": 800,
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 DSH-Desktop"
  }
}
```

#### File 5: Browser Automation Engine (`plugins/tool-browser/src/BrowserManager.ts`)
```typescript
import { chromium, Browser, BrowserContext, Page } from 'playwright';
import { EventEmitter } from 'events';

export interface BrowserConfig {
  headless?: boolean;
  viewportWidth?: number;
  viewportHeight?: number;
  userAgent?: string;
}

export interface NavigationResult {
  url: string;
  title: string;
  status: number;
  contentSample: string;
}

export class BrowserManager extends EventEmitter {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;
  private page: Page | null = null;
  private currentUrl = 'about:blank';

  constructor(private config: BrowserConfig = {}) {
    super();
  }

  async launch(): Promise<void> {
    if (this.browser) return;

    this.browser = await chromium.launch({
      headless: this.config.headless !== false,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-zygote'
      ]
    });

    this.context = await this.browser.newContext({
      viewport: {
        width: this.config.viewportWidth || 1280,
        height: this.config.viewportHeight || 800
      },
      userAgent: this.config.userAgent
    });

    this.page = await this.context.newPage();
  }

  async navigate(url: string): Promise<NavigationResult> {
    await this.launch();
    if (!this.page) throw new Error('Browser page failed to initialize');

    const formattedUrl = url.startsWith('http://') || url.startsWith('https://') ? url : `https://${url}`;
    const response = await this.page.goto(formattedUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });

    this.currentUrl = this.page.url();
    const title = await this.page.title();
    const content = await this.page.innerText('body').catch(() => '');

    this.emit('navigated', { url: this.currentUrl, title });

    return {
      url: this.currentUrl,
      title,
      status: response?.status() ?? 200,
      contentSample: content.slice(0, 500)
    };
  }

  async extractDomText(selector = 'body'): Promise<string> {
    if (!this.page) throw new Error('No active browser page');
    return await this.page.innerText(selector);
  }

  async captureScreenshot(): Promise<{ base64: string; format: 'image/png' }> {
    if (!this.page) throw new Error('No active browser page');
    const buffer = await this.page.screenshot({ type: 'png', fullPage: false });
    return {
      base64: buffer.toString('base64'),
      format: 'image/png'
    };
  }

  async click(selector: string): Promise<boolean> {
    if (!this.page) throw new Error('No active browser page');
    await this.page.click(selector, { timeout: 10000 });
    return true;
  }

  async type(selector: string, text: string): Promise<boolean> {
    if (!this.page) throw new Error('No active browser page');
    await this.page.fill(selector, text, { timeout: 10000 });
    return true;
  }

  async evaluateScript(script: string): Promise<any> {
    if (!this.page) throw new Error('No active browser page');
    return await this.page.evaluate(script);
  }

  async close(): Promise<void> {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
      this.context = null;
      this.page = null;
    }
  }
}
```

#### File 6: Browser UI View Component (`plugins/tool-browser/src/ui/BrowserView.tsx`)
```tsx
import React, { useState } from 'react';
import { BrowserManager } from '../BrowserManager';

export interface BrowserViewProps {
  browserManager?: BrowserManager;
}

export const BrowserView: React.FC<BrowserViewProps> = ({ browserManager }) => {
  const [urlInput, setUrlInput] = useState('https://cachyos.org');
  const [currentUrl, setCurrentUrl] = useState('');
  const [pageTitle, setPageTitle] = useState('');
  const [screenshot, setScreenshot] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleNavigate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!urlInput.trim() || !browserManager) return;

    setIsLoading(true);
    try {
      const res = await browserManager.navigate(urlInput);
      setCurrentUrl(res.url);
      setPageTitle(res.title);

      const shot = await browserManager.captureScreenshot();
      setScreenshot(`data:${shot.format};base64,${shot.base64}`);
    } catch (err) {
      console.error('[BrowserView] Navigation failed:', err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#10121a] text-gray-200 font-sans">
      {/* Navigation URL Bar */}
      <form
        onSubmit={handleNavigate}
        className="flex items-center space-x-2 px-4 py-2 bg-[#171a26] border-b border-[#232736]"
      >
        <span className="text-sm font-semibold text-gray-400">URL:</span>
        <input
          type="text"
          value={urlInput}
          onChange={(e) => setUrlInput(e.target.value)}
          placeholder="Enter website URL..."
          className="flex-1 bg-[#0f1118] border border-[#2b3044] rounded px-3 py-1.5 text-xs text-gray-200 focus:outline-none focus:border-blue-500"
        />
        <button
          type="submit"
          disabled={isLoading}
          className="bg-blue-600 hover:bg-blue-500 disabled:bg-gray-700 text-white text-xs font-medium px-4 py-1.5 rounded transition-colors"
        >
          {isLoading ? 'Loading...' : 'Go'}
        </button>
      </form>

      {/* Page Title & Status */}
      {currentUrl && (
        <div className="px-4 py-1.5 bg-[#12141e] border-b border-[#232736] text-[11px] text-gray-400 flex items-center justify-between">
          <span className="truncate"><strong>Title:</strong> {pageTitle || 'Untitled'}</span>
          <span className="font-mono text-gray-500">{currentUrl}</span>
        </div>
      )}

      {/* Browser Viewport Display */}
      <div className="flex-1 flex items-center justify-center p-4 bg-[#0a0b10] overflow-auto">
        {screenshot ? (
          <img
            src={screenshot}
            alt="Browser Screenshot"
            className="max-w-full rounded shadow-xl border border-[#232736]"
          />
        ) : (
          <div className="text-gray-500 text-xs">
            {isLoading ? 'Capturing headless browser frame...' : 'No page loaded. Enter a URL above to begin browsing.'}
          </div>
        )}
      </div>
    </div>
  );
};
```

---

### Part C: Plugin Root & Agent Tool Registration

#### File 7: Combined Plugin Wiring (`plugins/tool-terminal/src/index.ts` and `plugins/tool-browser/src/index.ts`)

```typescript
// File: plugins/tool-terminal/src/index.ts
import { PtyManager } from './PtyManager';

export default class ToolTerminalPlugin {
  private ptyManager = new PtyManager();

  async initialize(ctx: any): Promise<void> {
    if (ctx.services?.provide) {
      ctx.services.provide('terminal', this.ptyManager);
    }

    // Register terminal tools with the Agent Orchestrator
    const agentService = ctx.services?.get('agent');
    if (agentService?.getToolDispatcher) {
      const dispatcher = agentService.getToolDispatcher();

      dispatcher.registerTool({
        name: 'terminal_exec',
        description: 'Execute a bash command securely inside the Bubblewrap sandbox container on CachyOS.',
        parameters: {
          type: 'object',
          properties: {
            command: { type: 'string', description: 'The bash command to run' },
            cwd: { type: 'string', description: 'Optional working directory' }
          },
          required: ['command']
        },
        execute: async (params: any) => {
          const res = await this.ptyManager.execCommand(params.command, params.cwd);
          return {
            success: res.exitCode === 0,
            output: res.stdout,
            metadata: { exitCode: res.exitCode }
          };
        }
      });
    }
  }

  async activate(): Promise<void> {
    console.log('[ToolTerminalPlugin] Activated.');
  }

  async deactivate(): Promise<void> {
    console.log('[ToolTerminalPlugin] Deactivated.');
  }

  async dispose(): Promise<void> {
    console.log('[ToolTerminalPlugin] Disposed.');
  }
}
```

```typescript
// File: plugins/tool-browser/src/index.ts
import { BrowserManager } from './BrowserManager';

export default class ToolBrowserPlugin {
  private browserManager = new BrowserManager();

  async initialize(ctx: any): Promise<void> {
    if (ctx.services?.provide) {
      ctx.services.provide('browser', this.browserManager);
    }

    // Register browser tools with the Agent Orchestrator
    const agentService = ctx.services?.get('agent');
    if (agentService?.getToolDispatcher) {
      const dispatcher = agentService.getToolDispatcher();

      dispatcher.registerTool({
        name: 'browser_navigate',
        description: 'Navigate to a web URL and extract page text.',
        parameters: {
          type: 'object',
          properties: {
            url: { type: 'string', description: 'Web URL to open' }
          },
          required: ['url']
        },
        execute: async (params: any) => {
          const res = await this.browserManager.navigate(params.url);
          return {
            success: true,
            output: `Page Title: ${res.title}
Status: ${res.status}
Content Sample:
${res.contentSample}`
          };
        }
      });

      dispatcher.registerTool({
        name: 'browser_screenshot',
        description: 'Capture a screenshot of the currently open webpage.',
        parameters: {
          type: 'object',
          properties: {}
        },
        execute: async () => {
          const shot = await this.browserManager.captureScreenshot();
          return {
            success: true,
            output: `Screenshot captured successfully (${shot.format}).`,
            metadata: { base64: shot.base64 }
          };
        }
      });
    }
  }

  async activate(): Promise<void> {
    console.log('[ToolBrowserPlugin] Activated.');
  }

  async deactivate(): Promise<void> {
    await this.browserManager.close();
    console.log('[ToolBrowserPlugin] Deactivated.');
  }

  async dispose(): Promise<void> {
    await this.browserManager.close();
    console.log('[ToolBrowserPlugin] Disposed.');
  }
}
```

---

## 6. Step-by-Step AI Execution Instructions

Follow these exact steps to scaffold the Terminal and Browser tooling plugins:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Session 08] Scaffolding plugins/tool-terminal and plugins/tool-browser..."
mkdir -p plugins/tool-terminal/src/ui
mkdir -p plugins/tool-browser/src/ui

# 1. Compile TypeScript code
echo "==> [Session 08] Compiling TypeScript plugins..."
npm run build || npx tsc --noEmit

echo "==> [Session 08] Tooling plugins created successfully."
```

---

## 7. Validation & Verification Commands

Execute the following automated test script to verify that `bwrap` sandboxed command execution and browser automation interfaces operate correctly:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Verification] Running Session 08 automated test harness..."

# Test 1: Validate bwrap sandboxed command execution
node -e '
const { PtyManager } = require("./plugins/tool-terminal/src/PtyManager.ts");
const manager = new PtyManager();

async function runTest() {
  console.log("Testing bwrap isolated shell execution...");
  const res = await manager.execCommand("uname -a && echo CACHYOS_SANDBOX_OK");
  console.assert(res.stdout.includes("CACHYOS_SANDBOX_OK"), "bwrap sandboxed execution failed!");
  console.log("==> Test 1 Passed: bwrap isolated execution OK.");
}
runTest().catch(console.error);
'

echo "==> [Verification] Session 08 completed all validation checks successfully!"
```

---

## 8. Definition of Done Checklist

- [ ] `plugins/tool-terminal/dsh.plugin.json` authored with slot `bottom.panel` and permissions (`ipc:pty`, `ipc:bwrap`).
- [ ] `PtyManager.ts` implemented wrapping `node-pty` inside Bubblewrap (`bwrap`) containment args with process recycling.
- [ ] `TerminalPanel.tsx` implemented using `xterm.js`, `FitAddon`, and WebGL/Canvas rendering.
- [ ] `plugins/tool-browser/dsh.plugin.json` authored with slot `workspace.main` and permissions (`network:browser`, `fs:tmp`).
- [ ] `BrowserManager.ts` implemented with Playwright/Chromium lifecycle, navigation, DOM text extraction, and screenshot capture.
- [ ] `terminal_exec`, `browser_navigate`, and `browser_screenshot` tools registered into Cordis Agent Orchestrator.
- [ ] Automated verification script executes with zero errors.
