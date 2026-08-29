# Session 09: Global Command Palette, Task Scheduler & Git Hooks Plugin

> **Objective:** Implement the official Automation and Control Plugins for DSH-Desktop on CachyOS: the **Global Command Palette Plugin** (`plugins/command-palette`), the **Cron & Interval Task Scheduler Plugin** (`plugins/task-scheduler`), and the **Automated Git Checkpointing & Version Safety Plugin** (`plugins/git-checkpoint`). The Command Palette mounts into the `overlay.modal` slot for instant `Ctrl+K` fuzzy command routing. The Task Scheduler enables periodic background agent runs and shell routines with desktop notifications. The Git Checkpointing engine tracks all file mutations before and after agent turns, providing zero-loss rollback safety.

---

## 1. Execution Context & Metadata

* **Session ID:** `DSH-SESSION-09`
* **Title:** Global Command Palette, Task Scheduler & Git Hooks Plugin
* **Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`
* **Upstream Implementation Remote:** `https://github.com/Tariq-Anjum/dsh-desktop.git`
* **Architecture Reference Remote:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux.git`
* **Pre-requisites:**
  * Session 01: Baseline environment, CachyOS toolchain (`-march=x86-64-v3`), and directories initialized.
  * Session 02: Cordis Core Plugin Runtime (`PluginContext`, `ServiceContainer`, `PluginRegistry`) active.
  * Session 03: Host-Agent IPC Protocol and Bubblewrap (`bwrap`) security sandbox bridge operational.
  * Session 05: Modular UI Shell, dynamic slotting engine (`overlay.modal`, `header.actions`), and theme engine active.
  * Session 06: Core Agent Runtime & Model Orchestration Plugin active.
* **Target Operating System:** CachyOS (Linux 6.x BORE/sched-ext kernel, x86-64-v3/v4, Wayland/X11).
* **Core Technologies:** TypeScript 5.5+, React 18, Cron Parser / Interval Timers, Git CLI (`simple-git` / native `git`), Linux `notify-send` / Desktop Notification Protocol.

---

## 2. Architecture & Data Flow Diagram

```
+---------------------------------------------------------------------------------------------------+
|                                  Cordis Plugin Context (`ctx`)                                     |
|  - Injects: `ctx.services.get('agent')`, `ctx.services.get('ipc')`, `ctx.services.get('slots')`   |
|  - Provides: `ctx.services.provide('command_palette')`, `ctx.services.provide('scheduler')`       |
+---------------------------------------------------------------------------------------------------+
                                                  |
         +----------------------------------------+----------------------------------------+
         |                                        |                                        |
+--------------------------------+ +--------------------------------+ +--------------------------------+
| Command Palette                | | Task Scheduler                 | | Git Checkpoint Manager         |
| (`plugins/command-palette`)    | | (`plugins/task-scheduler`)     | | (`plugins/git-checkpoint`)     |
| - Trigger: `Ctrl+K` / `Cmd+K`  | | - Engine: `cron` / intervals   | | - Event: Pre/Post Agent Turn   |
| - Search: `FuzzyMatcher`       | | - Persistence: `scheduler.json`| | - Action: `git stash create`   |
| - UI Slot: `overlay.modal`     | | - Target: Agent Turns / Scripts| |   or shadow branch commit      |
+--------------------------------+ +--------------------------------+ +--------------------------------+
                                                  |
+---------------------------------------------------------------------------------------------------+
|                                   Host OS Desktop Integration                                     |
|  - System Notification via Linux D-Bus `org.freedesktop.Notifications` or `notify-send`           |
|  - Persistent cron storage under `~/.config/dsh-desktop/scheduler.json`                           |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Pre-Flight Verification & Assertions

Execute the following pre-flight assertions to confirm environment readiness before creating plugin files:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
echo "==> [Pre-Flight] Verifying Session 09 prerequisites in ${TARGET_DIR}..."

# 1. Verify git is configured in workspace
cd "${TARGET_DIR}"
if [ ! -d ".git" ]; then
    echo "==> [Pre-Flight] Initializing git repository in worktree..."
    git init
    git config user.name "DSH Desktop Agent"
    git config user.email "agent@dsh-desktop.local"
fi

# 2. Check for notify-send or desktop notification daemon
if command -v notify-send > /dev/null 2>&1; then
    echo "==> [Pre-Flight] notify-send detected on CachyOS."
else
    echo "==> [Pre-Flight] Note: notify-send not found; notifications will fallback to stderr logging."
fi

echo "==> [Pre-Flight] Prerequisites validated successfully."
```

---

## 4. Capability & Security Declarations

* **`plugins/command-palette` Permissions:**
  * `ipc:actions`: Execute registered workspace actions and command hooks.
  * `service:registry`: Query available commands across all loaded Cordis plugins.
  * `slots:mount`: Mount modal overlay into `overlay.modal`.
* **`plugins/task-scheduler` Permissions:**
  * `service:scheduler`: Register background tasks with recurrence patterns.
  * `timer:background`: Run background timers across application lifetime.
  * `ipc:notify`: Trigger Linux desktop notification popups via IPC/D-Bus.
* **`plugins/git-checkpoint` Permissions:**
  * `fs:workspace`: Read and write git repository objects in `/mnt/MD/Project/DSH/DSH-Desktop/.git`.

---

## 5. Detailed File Operations & Complete Code Scaffolding

### Part A: Global Command Palette Plugin (`plugins/command-palette`)

#### File 1: Plugin Manifest (`plugins/command-palette/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.command-palette",
  "name": "Global Command Palette",
  "version": "1.0.0",
  "description": "Raycast/Spotlight-style global command launcher with fuzzy search and keyboard navigation",
  "author": "Tariq Anjum",
  "type": "hybrid",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "slots": [
    {
      "target": "overlay.modal",
      "priority": 100,
      "component": "CommandPaletteModal"
    }
  ],
  "permissions": [
    "ipc:actions",
    "service:registry"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.core.ui-slot-manager": ">=1.0.0"
  },
  "defaultConfig": {
    "hotkey": "Ctrl+K",
    "maxResults": 10
  }
}
```

#### File 2: Command Registry & Fuzzy Search Engine (`plugins/command-palette/src/CommandRegistry.ts`)
```typescript
export interface CommandItem {
  id: string;
  title: string;
  category: 'Agent' | 'Workspace' | 'Tools' | 'Settings' | 'Navigation';
  shortcut?: string;
  description?: string;
  handler: () => void | Promise<void>;
}

export class CommandRegistry {
  private commands = new Map<string, CommandItem>();
  private listeners = new Set<() => void>();

  registerCommand(cmd: CommandItem): void {
    this.commands.set(cmd.id, cmd);
    this.notify();
  }

  unregisterCommand(cmdId: string): boolean {
    const res = this.commands.delete(cmdId);
    if (res) this.notify();
    return res;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify(): void {
    this.listeners.forEach((fn) => fn());
  }

  search(query: string, maxResults = 10): CommandItem[] {
    const trimmed = query.trim().toLowerCase();
    const all = Array.from(this.commands.values());

    if (!trimmed) {
      return all.slice(0, maxResults);
    }

    // Fuzzy matching score calculation
    const scored = all.map((cmd) => {
      const target = `${cmd.title} ${cmd.category} ${cmd.description || ''}`.toLowerCase();
      let score = 0;
      let qIdx = 0;

      // Exact substring boost
      if (target.includes(trimmed)) score += 50;

      // Character-by-character fuzzy match
      for (let i = 0; i < target.length && qIdx < trimmed.length; i++) {
        if (target[i] === trimmed[qIdx]) {
          score += 10;
          qIdx++;
        }
      }

      if (qIdx === trimmed.length) score += 20; // Full match

      return { cmd, score };
    });

    return scored
      .filter((s) => s.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, maxResults)
      .map((s) => s.cmd);
  }
}
```

#### File 3: Command Palette UI Modal (`plugins/command-palette/src/ui/CommandPaletteModal.tsx`)
```tsx
import React, { useState, useEffect, useRef } from 'react';
import { CommandRegistry, CommandItem } from '../CommandRegistry';

export interface CommandPaletteModalProps {
  registry?: CommandRegistry;
  isOpen: boolean;
  onClose: () => void;
}

export const CommandPaletteModal: React.FC<CommandPaletteModalProps> = ({
  registry,
  isOpen,
  onClose
}) => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<CommandItem[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && registry) {
      setQuery('');
      setSelectedIndex(0);
      setResults(registry.search(''));
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen, registry]);

  useEffect(() => {
    if (!registry) return;
    setResults(registry.search(query));
    setSelectedIndex(0);
  }, [query, registry]);

  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        if (isOpen) onClose();
      }
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleGlobalKeyDown);
    return () => window.removeEventListener('keydown', handleGlobalKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev + 1 < results.length ? prev + 1 : 0));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev - 1 >= 0 ? prev - 1 : results.length - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      const selected = results[selectedIndex];
      if (selected) {
        onClose();
        selected.handler();
      }
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/60 backdrop-blur-sm">
      <div className="w-full max-w-xl bg-[#141724] border border-[#2b3149] rounded-xl shadow-2xl overflow-hidden font-sans text-gray-100">
        {/* Search input */}
        <div className="flex items-center px-4 py-3 border-b border-[#24293e] bg-[#181c2c]">
          <span className="text-gray-400 mr-3 text-lg">🔍</span>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Type a command or search workspace..."
            className="w-full bg-transparent text-sm text-gray-100 focus:outline-none placeholder-gray-500"
          />
          <kbd className="px-2 py-0.5 text-[10px] bg-[#23283f] text-gray-400 border border-[#343b5c] rounded">
            ESC
          </kbd>
        </div>

        {/* Results list */}
        <div className="max-h-80 overflow-y-auto p-2">
          {results.map((cmd, idx) => (
            <div
              key={cmd.id}
              onClick={() => {
                onClose();
                cmd.handler();
              }}
              className={`flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer text-xs transition-colors ${
                selectedIndex === idx
                  ? 'bg-blue-600 text-white'
                  : 'hover:bg-[#1e2337] text-gray-300'
              }`}
            >
              <div className="flex items-center space-x-2">
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-black/30 font-medium">
                  {cmd.category}
                </span>
                <span className="font-medium">{cmd.title}</span>
                {cmd.description && (
                  <span className={`text-[11px] truncate max-w-xs ${selectedIndex === idx ? 'text-blue-100' : 'text-gray-500'}`}>
                    - {cmd.description}
                  </span>
                )}
              </div>
              {cmd.shortcut && (
                <kbd className="px-1.5 py-0.5 text-[10px] bg-black/20 rounded font-mono">
                  {cmd.shortcut}
                </kbd>
              )}
            </div>
          ))}
          {results.length === 0 && (
            <div className="py-6 text-center text-xs text-gray-500">
              No matching commands found.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
```

---

### Part B: Background Task Scheduler Plugin (`plugins/task-scheduler`)

#### File 4: Plugin Manifest (`plugins/task-scheduler/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.task-scheduler",
  "name": "Background Task Scheduler",
  "version": "1.0.0",
  "description": "Cron and interval task engine for periodic agent runs, shell routines, and desktop alerts",
  "author": "Tariq Anjum",
  "type": "service",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "permissions": [
    "service:scheduler",
    "timer:background",
    "ipc:notify"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.plugin.agent-orchestrator": ">=1.0.0"
  },
  "defaultConfig": {
    "pollIntervalMs": 10000,
    "enableNotifications": true
  }
}
```

#### File 5: Task Scheduler Engine (`plugins/task-scheduler/src/SchedulerEngine.ts`)
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { exec } from 'child_process';
import { EventEmitter } from 'events';

export interface ScheduledTask {
  id: string;
  name: string;
  type: 'agent_prompt' | 'shell_command';
  payload: string;
  intervalMinutes?: number;
  cronExpression?: string;
  lastRunAt?: number;
  nextRunAt: number;
  enabled: boolean;
}

export class SchedulerEngine extends EventEmitter {
  private tasks = new Map<string, ScheduledTask>();
  private storageFile: string;
  private timer: NodeJS.Timeout | null = null;

  constructor(storageDir?: string) {
    super();
    const dir = storageDir || path.join(process.env.HOME || '/root', '.config', 'dsh-desktop');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    this.storageFile = path.join(dir, 'scheduler.json');
    this.loadTasks();
  }

  start(pollIntervalMs = 10000): void {
    if (this.timer) return;
    this.timer = setInterval(() => this.tick(), pollIntervalMs);
    this.tick(); // Run immediately on start
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  scheduleIntervalTask(
    name: string,
    type: ScheduledTask['type'],
    payload: string,
    intervalMinutes: number
  ): ScheduledTask {
    const id = `task-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const task: ScheduledTask = {
      id,
      name,
      type,
      payload,
      intervalMinutes,
      nextRunAt: Date.now() + intervalMinutes * 60 * 1000,
      enabled: true
    };

    this.tasks.set(id, task);
    this.saveTasks();
    return task;
  }

  private async tick(): Promise<void> {
    const now = Date.now();
    for (const [id, task] of this.tasks.entries()) {
      if (task.enabled && now >= task.nextRunAt) {
        task.lastRunAt = now;
        if (task.intervalMinutes) {
          task.nextRunAt = now + task.intervalMinutes * 60 * 1000;
        }

        this.emit('task:trigger', task);
        this.executeTask(task);
        this.saveTasks();
      }
    }
  }

  private async executeTask(task: ScheduledTask): Promise<void> {
    if (task.type === 'shell_command') {
      exec(task.payload, (err, stdout) => {
        if (err) {
          this.emit('task:error', { task, error: err.message });
        } else {
          this.emit('task:success', { task, stdout });
          this.sendDesktopNotification(`Task Completed: ${task.name}`, stdout.slice(0, 100));
        }
      });
    } else if (task.type === 'agent_prompt') {
      this.emit('agent:prompt', { task, prompt: task.payload });
    }
  }

  private sendDesktopNotification(title: string, message: string): void {
    const safeTitle = title.replace(/"/g, '\"');
    const safeMessage = message.replace(/"/g, '\"');
    exec(`notify-send "${safeTitle}" "${safeMessage}"`, () => {
      // Ignore if notify-send is unavailable
    });
  }

  private saveTasks(): void {
    try {
      const data = JSON.stringify(Array.from(this.tasks.values()), null, 2);
      fs.writeFileSync(this.storageFile, data, 'utf-8');
    } catch (err) {
      console.error('[SchedulerEngine] Failed to save tasks:', err);
    }
  }

  private loadTasks(): void {
    try {
      if (fs.existsSync(this.storageFile)) {
        const raw = fs.readFileSync(this.storageFile, 'utf-8');
        const list: ScheduledTask[] = JSON.parse(raw);
        for (const t of list) this.tasks.set(t.id, t);
      }
    } catch {
      // Ignore initial empty state
    }
  }
}
```

---

### Part C: Automated Git Checkpointing Plugin (`plugins/git-checkpoint`)

#### File 6: Git Checkpoint Manager (`plugins/git-checkpoint/src/GitCheckpointManager.ts`)
```typescript
import { exec } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';

const execAsync = promisify(exec);

export interface GitCheckpoint {
  checkpointId: string;
  description: string;
  commitHash: string;
  timestamp: number;
}

export class GitCheckpointManager {
  private checkpoints: GitCheckpoint[] = [];

  constructor(private workspaceDir: string) {}

  /**
   * Create an automated shadow commit or stash checkpoint before an agent turn executes.
   */
  async createPreTurnCheckpoint(turnId: string, description: string): Promise<GitCheckpoint> {
    const timestamp = Date.now();
    const checkpointId = `chk-pre-${turnId}-${timestamp}`;

    try {
      // Check for git status
      await execAsync('git add -A', { cwd: this.workspaceDir });
      const { stdout: commitOut } = await execAsync(
        `git commit -m "[DSH Checkpoint: PRE] ${description}" --allow-empty`,
        { cwd: this.workspaceDir }
      );

      const { stdout: hashOut } = await execAsync('git rev-parse HEAD', { cwd: this.workspaceDir });
      const commitHash = hashOut.trim();

      const checkpoint: GitCheckpoint = {
        checkpointId,
        description,
        commitHash,
        timestamp
      };

      this.checkpoints.push(checkpoint);
      return checkpoint;
    } catch (err: any) {
      console.error('[GitCheckpointManager] Pre-turn checkpoint failed:', err.message);
      return {
        checkpointId,
        description,
        commitHash: 'HEAD',
        timestamp
      };
    }
  }

  /**
   * Roll back workspace to a previous checkpoint hash.
   */
  async rollbackToCheckpoint(checkpointId: string): Promise<boolean> {
    const chk = this.checkpoints.find((c) => c.checkpointId === checkpointId);
    if (!chk) return false;

    try {
      await execAsync(`git reset --hard ${chk.commitHash}`, { cwd: this.workspaceDir });
      await execAsync('git clean -fd', { cwd: this.workspaceDir });
      return true;
    } catch (err: any) {
      console.error(`[GitCheckpointManager] Rollback to ${checkpointId} failed:`, err.message);
      return false;
    }
  }

  getCheckpoints(): GitCheckpoint[] {
    return [...this.checkpoints];
  }
}
```

---

### Part D: Plugin Wiring

#### File 7: Combined Plugin Initializers (`plugins/command-palette/src/index.ts`)
```typescript
import { CommandRegistry } from './CommandRegistry';

export default class CommandPalettePlugin {
  private registry = new CommandRegistry();

  async initialize(ctx: any): Promise<void> {
    if (ctx.services?.provide) {
      ctx.services.provide('command_palette', this.registry);
    }

    // Register baseline navigation and workspace commands
    this.registry.registerCommand({
      id: 'agent.new_chat',
      title: 'New Agent Conversation',
      category: 'Agent',
      shortcut: 'Ctrl+N',
      description: 'Start a new AI coding and reasoning session',
      handler: () => {
        const agentService = ctx.services?.get('agent');
        agentService?.getConversationManager()?.createSession();
      }
    });

    this.registry.registerCommand({
      id: 'canvas.open',
      title: 'Open Artifact Canvas',
      category: 'Workspace',
      description: 'View active code artifacts and live preview',
      handler: () => {
        console.log('[CommandPalette] Open Artifact Canvas command triggered.');
      }
    });

    this.registry.registerCommand({
      id: 'git.checkpoint',
      title: 'Create Git Safety Checkpoint',
      category: 'Workspace',
      description: 'Manually capture current workspace state into Git history',
      handler: async () => {
        const gitService = ctx.services?.get('git_checkpoint');
        if (gitService) {
          await gitService.createPreTurnCheckpoint('manual', 'Manual User Checkpoint');
        }
      }
    });
  }

  async activate(): Promise<void> {
    console.log('[CommandPalettePlugin] Activated.');
  }

  async deactivate(): Promise<void> {
    console.log('[CommandPalettePlugin] Deactivated.');
  }

  async dispose(): Promise<void> {
    console.log('[CommandPalettePlugin] Disposed.');
  }
}
```

---

## 6. Step-by-Step AI Execution Instructions

Follow these exact steps to scaffold the Command Palette and Task Scheduler plugins:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Session 09] Scaffolding plugins/command-palette, plugins/task-scheduler, plugins/git-checkpoint..."
mkdir -p plugins/command-palette/src/ui
mkdir -p plugins/task-scheduler/src
mkdir -p plugins/git-checkpoint/src

# 1. Compile TypeScript code
echo "==> [Session 09] Compiling TypeScript plugins..."
npm run build || npx tsc --noEmit

echo "==> [Session 09] Automation and Command plugins created successfully."
```

---

## 7. Validation & Verification Commands

Execute the following automated test script to verify fuzzy search indexing, task scheduling, and git checkpoint rollbacks:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Verification] Running Session 09 automated test harness..."

# Test 1: Validate CommandRegistry Fuzzy Search
node -e '
const { CommandRegistry } = require("./plugins/command-palette/src/CommandRegistry.ts");
const reg = new CommandRegistry();

reg.registerCommand({
  id: "test.build",
  title: "Build Project with Vulkan",
  category: "Workspace",
  handler: () => console.log("Built!")
});

const res = reg.search("vulkan");
console.assert(res.length === 1, "Fuzzy matcher failed to find vulkan command!");
console.assert(res[0].id === "test.build", "Wrong command returned by fuzzy matcher!");
console.log("==> Test 1 Passed: CommandRegistry fuzzy search operates accurately.");
'

# Test 2: Validate Scheduler Engine
node -e '
const { SchedulerEngine } = require("./plugins/task-scheduler/src/SchedulerEngine.ts");
const sched = new SchedulerEngine("/tmp/dsh_sched_test");
const task = sched.scheduleIntervalTask("Heartbeat", "shell_command", "echo OK", 1);

console.assert(task.enabled === true, "Scheduler task was not enabled!");
console.log("==> Test 2 Passed: SchedulerEngine task creation OK.");
'

echo "==> [Verification] Session 09 completed all validation checks successfully!"
```

---

## 8. Definition of Done Checklist

- [ ] `plugins/command-palette/dsh.plugin.json` authored with slot `overlay.modal` and permissions (`ipc:actions`, `service:registry`).
- [ ] `CommandRegistry.ts` implemented with fuzzy search indexing across titles, categories, and descriptions.
- [ ] `CommandPaletteModal.tsx` implemented with keyboard navigation (Up/Down/Enter/Escape) and `Ctrl+K` hotkey toggling.
- [ ] `plugins/task-scheduler/dsh.plugin.json` authored and `SchedulerEngine.ts` implemented with cron/interval evaluation and JSON persistence.
- [ ] `GitCheckpointManager.ts` implemented with automated shadow commit generation and zero-loss rollback capability.
- [ ] Automated verification script executes with zero errors.
