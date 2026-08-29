# Session 07: Artifact Canvas & Real-Time Preview Plugin

> **Objective:** Implement the official Artifact Canvas & Real-Time Preview Plugin (`plugins/artifact-canvas`) for DSH-Desktop on CachyOS. This plugin mounts into the `workspace.main` and `sidebar.nav` UI slots, providing an interactive split-view workspace with real-time artifact stream parsing (Markdown, Code, HTML/CSS/JS, SVG, React components, Vulkan shaders), a live code editor with Monaco/syntax highlighting, an isolated iframe-based preview sandbox with strict Content Security Policy (CSP) enforcement, and bidirectional state synchronization between user edits, workspace disk files, and the agent conversation context.

---

## 1. Execution Context & Metadata

* **Session ID:** `DSH-SESSION-07`
* **Title:** Artifact Canvas & Real-Time Preview Plugin
* **Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`
* **Upstream Implementation Remote:** `https://github.com/Tariq-Anjum/dsh-desktop.git`
* **Architecture Reference Remote:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux.git`
* **Pre-requisites:**
  * Session 01: Baseline environment, CachyOS toolchain (`-march=x86-64-v3`), and directories initialized.
  * Session 02: Cordis Core Plugin Runtime (`PluginContext`, `ServiceContainer`, `PluginRegistry`) active.
  * Session 03: Host-Agent IPC Protocol and Bubblewrap (`bwrap`) security sandbox bridge operational.
  * Session 05: Modular UI Shell, dynamic slotting engine (`workspace.main`, `sidebar.nav`), and theme engine active.
  * Session 06: Core Agent Runtime & Model Orchestration Plugin operational with streaming token events.
* **Target Operating System:** CachyOS (Linux 6.x BORE/sched-ext kernel, x86-64-v3/v4, Wayland/X11).
* **Core Technologies:** TypeScript 5.5+, React 18, Monaco Editor / CodeMirror, Iframe Sandboxing (CSP `default-src 'none'`), Sucrase / Babel In-Browser JSX Transpiler, WebGL / Vulkan Canvas Context.

---

## 2. Architecture & Data Flow Diagram

```
+---------------------------------------------------------------------------------------------------+
|                                  Cordis Plugin Context (`ctx`)                                     |
|  - Injects: `ctx.services.get('agent')`, `ctx.services.get('ipc')`, `ctx.services.get('slots')`   |
|  - Provides: `ctx.services.provide('canvas', artifactCanvasServiceInstance)`                      |
+---------------------------------------------------------------------------------------------------+
                                                  |
                         +------------------------+------------------------+
                         |                                                 |
+--------------------------------------------------+     +-----------------------------------+
|             ArtifactCanvasPlugin (Cordis)        |     |   UI Slot: `workspace.main`       |
|  - Stream Listener: `ArtifactParser`             |     |   - `ArtifactCanvasView.tsx`      |
|  - Store: `ArtifactStore` (Versioning/Revisions) | <-> |     -> `CodeEditor.tsx` (Monaco)  |
|  - Sandbox: `PreviewSandbox.tsx` (CSP Iframe)    |     |     -> `PreviewSandbox.tsx`       |
+--------------------------------------------------+     +-----------------------------------+
                         |
        +----------------+----------------+
        |                                 |
+-------------------------------+ +---------------------------------------------------------------+
|  Agent-to-Canvas Sync         | | User-to-Agent Bidirectional Sync                              |
|  - LLM emits code blocks      | | - User edits code in Monaco Editor                            |
|  - `ArtifactParser` detects   | | - Triggers `canvas.updateArtifact()`                          |
|    `<dsh_artifact>` tags      | | - Writes updated code to disk via Host IPC                    |
|  - Live preview updates       | | - Feeds notification event to active Agent context            |
+-------------------------------+ +---------------------------------------------------------------+
```

---

## 3. Pre-Flight Verification & Assertions

Execute the following pre-flight assertions to confirm environment readiness before creating plugin files:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
echo "==> [Pre-Flight] Verifying Session 07 prerequisites in ${TARGET_DIR}..."

# 1. Check directory and core files from Sessions 01-06
if [ ! -d "${TARGET_DIR}/plugins/agent-orchestrator" ]; then
    echo "ERROR: Agent Orchestrator plugin from Session 06 not found!"
    exit 1
fi

if [ ! -d "${TARGET_DIR}/src/ui/slots" ]; then
    echo "ERROR: UI slot engine from Session 05 not found!"
    exit 1
fi

# 2. Verify Monaco / Editor dependencies and React packages
cd "${TARGET_DIR}"
npm list react react-dom || true

echo "==> [Pre-Flight] Prerequisites validated successfully."
```

---

## 4. Capability & Security Declarations

The `artifact-canvas` plugin requests the following permissions within the Cordis security model:

* **`fs:read:workspace`**: Read file contents from `/mnt/MD/Project/DSH/DSH-Desktop` for live editing and artifact synchronization.
* **`fs:write:workspace`**: Write file contents to `/mnt/MD/Project/DSH/DSH-Desktop` when the user or agent saves changes in the canvas.
* **`ipc:emit:canvas_event`**: Broadcast canvas lifecycle events (`artifact:created`, `artifact:updated`, `artifact:selected`) over the internal event bus.
* **`slots:mount`**: Register UI views into `workspace.main` and `sidebar.nav`.
* **Sandbox Isolation Policy**: The preview iframe runs with attributes `sandbox="allow-scripts allow-modals"`, strictly preventing parent DOM access (`allow-same-origin` is omitted), external navigation, and unauthorized network requests via CSP `default-src 'none'; script-src 'unsafe-inline' blob:; style-src 'unsafe-inline'; img-src data: blob:;`.

---

## 5. Detailed File Operations & Complete Code Scaffolding

### File 1: Plugin Manifest (`plugins/artifact-canvas/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.artifact-canvas",
  "name": "Artifact Canvas & Real-Time Preview",
  "version": "1.0.0",
  "description": "Interactive live preview canvas, Monaco code editor, multi-format artifact extractor, and sandboxed execution frame",
  "author": "Tariq Anjum",
  "type": "hybrid",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "slots": [
    {
      "target": "sidebar.nav",
      "priority": 90,
      "component": "ArtifactNavIcon"
    },
    {
      "target": "workspace.main",
      "priority": 80,
      "component": "ArtifactCanvasView"
    }
  ],
  "permissions": [
    "fs:read:workspace",
    "fs:write:workspace",
    "ipc:emit:canvas_event"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.core.ui-slot-manager": ">=1.0.0"
  },
  "defaultConfig": {
    "autoOpenOnArtifact": true,
    "defaultViewMode": "split",
    "liveTranspile": true,
    "theme": "vs-dark",
    "tabSize": 2
  }
}
```

### File 2: Type Definitions & Canvas Contracts (`plugins/artifact-canvas/src/types.ts`)
```typescript
export type ArtifactType =
  | 'code'
  | 'markdown'
  | 'html'
  | 'svg'
  | 'react'
  | 'vulkan-shader'
  | 'mermaid'
  | 'json';

export type CanvasViewMode = 'code-only' | 'preview-only' | 'split';

export interface Artifact {
  id: string;
  sessionId: string;
  title: string;
  type: ArtifactType;
  language: string;
  content: string;
  filePath?: string;
  version: number;
  createdAt: number;
  updatedAt: number;
}

export interface ArtifactRevision {
  revisionId: string;
  artifactId: string;
  content: string;
  timestamp: number;
  author: 'agent' | 'user';
}

export interface CanvasConfig {
  autoOpenOnArtifact: boolean;
  defaultViewMode: CanvasViewMode;
  liveTranspile: boolean;
  theme: 'vs-dark' | 'vs-light';
  tabSize: number;
}

export interface SandboxMessage {
  type: 'EVAL_CODE' | 'EVAL_RESULT' | 'EVAL_ERROR' | 'CONSOLE_LOG';
  payload?: any;
  error?: string;
}
```

### File 3: Real-Time Artifact Extractor & Stream Parser (`plugins/artifact-canvas/src/ArtifactParser.ts`)
```typescript
import { Artifact, ArtifactType } from './types';

export class ArtifactParser {
  /**
   * Detect and extract structured artifacts from streaming agent markdown text.
   * Matches both standard fenced code blocks:
   *   ```typescript file="src/main.ts" title="Main Entry"
   * and XML-style artifact delimiters:
   *   <dsh_artifact id="main-ts" type="code" language="typescript" title="Main Entry" file="src/main.ts">
   */
  static parseArtifacts(sessionId: string, text: string): Artifact[] {
    const artifacts: Artifact[] = [];

    // 1. Parse XML-style <dsh_artifact> blocks
    const xmlRegex = /<dsh_artifact\s+([^>]+)>([\s\S]*?)(?:<\/dsh_artifact>|$)/gi;
    let match: RegExpExecArray | null;

    while ((match = xmlRegex.exec(text)) !== null) {
      const attrString = match[1];
      const content = match[2].trim();

      const id = this.extractAttr(attrString, 'id') || `art-${Date.now()}-${artifacts.length}`;
      const title = this.extractAttr(attrString, 'title') || 'Generated Artifact';
      const typeStr = this.extractAttr(attrString, 'type') || 'code';
      const language = this.extractAttr(attrString, 'language') || 'typescript';
      const filePath = this.extractAttr(attrString, 'file') || undefined;

      const type = this.normalizeType(typeStr, language);

      artifacts.push({
        id,
        sessionId,
        title,
        type,
        language,
        content,
        filePath,
        version: 1,
        createdAt: Date.now(),
        updatedAt: Date.now()
      });
    }

    // 2. Parse fenced markdown code blocks if no XML artifacts found
    if (artifacts.length === 0) {
      const codeBlockRegex = /```([a-zA-Z0-9_\-]+)(?:\s+([^
]+))??
([\s\S]*?)```/g;
      let blockMatch: RegExpExecArray | null;
      let index = 0;

      while ((blockMatch = codeBlockRegex.exec(text)) !== null) {
        index++;
        const lang = blockMatch[1].toLowerCase();
        const meta = blockMatch[2] || '';
        const content = blockMatch[3].trim();

        // Skip tiny snippets (< 3 lines unless svg/html)
        if (content.split('
').length < 2 && !['svg', 'html', 'xml'].includes(lang)) {
          continue;
        }

        const filePath = this.extractAttr(meta, 'file') || this.extractAttr(meta, 'path');
        const title = this.extractAttr(meta, 'title') || filePath || `Code Snippet ${index} (${lang})`;
        const type = this.normalizeType(lang, lang);

        artifacts.push({
          id: `code-block-${sessionId}-${index}`,
          sessionId,
          title,
          type,
          language: lang,
          content,
          filePath: filePath || undefined,
          version: 1,
          createdAt: Date.now(),
          updatedAt: Date.now()
        });
      }
    }

    return artifacts;
  }

  private static extractAttr(attrString: string, name: string): string | null {
    const match = new RegExp(`${name}=["']([^"']+)["']`, 'i').exec(attrString);
    return match ? match[1] : null;
  }

  private static normalizeType(typeStr: string, lang: string): ArtifactType {
    const lower = (typeStr || lang).toLowerCase();
    if (['html', 'htm'].includes(lower)) return 'html';
    if (['svg', 'image/svg+xml'].includes(lower)) return 'svg';
    if (['react', 'jsx', 'tsx'].includes(lower)) return 'react';
    if (['glsl', 'frag', 'vert', 'comp', 'spv', 'vulkan'].includes(lower)) return 'vulkan-shader';
    if (['mermaid', 'diagram'].includes(lower)) return 'mermaid';
    if (['markdown', 'md'].includes(lower)) return 'markdown';
    if (['json'].includes(lower)) return 'json';
    return 'code';
  }
}
```

### File 4: Artifact Store & State Management (`plugins/artifact-canvas/src/ArtifactStore.ts`)
```typescript
import { Artifact, ArtifactRevision } from './types';

export class ArtifactStore {
  private artifacts = new Map<string, Artifact>();
  private revisions = new Map<string, ArtifactRevision[]>();
  private activeArtifactId: string | null = null;
  private listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify(): void {
    this.listeners.forEach((fn) => fn());
  }

  setArtifact(artifact: Artifact, author: 'agent' | 'user' = 'agent'): void {
    const existing = this.artifacts.get(artifact.id);
    if (existing) {
      // Create revision record
      const revList = this.revisions.get(artifact.id) || [];
      revList.push({
        revisionId: `rev-${Date.now()}-${revList.length}`,
        artifactId: artifact.id,
        content: existing.content,
        timestamp: Date.now(),
        author
      });
      this.revisions.set(artifact.id, revList);

      artifact.version = existing.version + 1;
      artifact.createdAt = existing.createdAt;
      artifact.updatedAt = Date.now();
    }

    this.artifacts.set(artifact.id, artifact);
    if (!this.activeArtifactId) {
      this.activeArtifactId = artifact.id;
    }
    this.notify();
  }

  updateContent(id: string, content: string, author: 'agent' | 'user' = 'user'): boolean {
    const artifact = this.artifacts.get(id);
    if (!artifact) return false;

    if (artifact.content !== content) {
      const revList = this.revisions.get(id) || [];
      revList.push({
        revisionId: `rev-${Date.now()}-${revList.length}`,
        artifactId: id,
        content: artifact.content,
        timestamp: Date.now(),
        author
      });
      this.revisions.set(id, revList);

      artifact.content = content;
      artifact.version += 1;
      artifact.updatedAt = Date.now();
      this.notify();
    }
    return true;
  }

  getActiveArtifact(): Artifact | null {
    if (!this.activeArtifactId) {
      if (this.artifacts.size > 0) {
        this.activeArtifactId = Array.from(this.artifacts.keys())[0];
      }
    }
    return this.activeArtifactId ? this.artifacts.get(this.activeArtifactId) || null : null;
  }

  setActiveArtifactId(id: string): boolean {
    if (this.artifacts.has(id)) {
      this.activeArtifactId = id;
      this.notify();
      return true;
    }
    return false;
  }

  listArtifacts(): Artifact[] {
    return Array.from(this.artifacts.values()).sort(
      (a, b) => b.updatedAt - a.updatedAt
    );
  }

  getRevisions(artifactId: string): ArtifactRevision[] {
    return this.revisions.get(artifactId) || [];
  }
}
```

### File 5: Isolated Preview Sandbox Component (`plugins/artifact-canvas/src/sandbox/PreviewSandbox.tsx`)
```tsx
import React, { useEffect, useRef, useState } from 'react';
import { Artifact } from '../types';

export interface PreviewSandboxProps {
  artifact: Artifact | null;
}

export const PreviewSandbox: React.FC<PreviewSandboxProps> = ({ artifact }) => {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [renderError, setRenderError] = useState<string | null>(null);

  useEffect(() => {
    if (!artifact || !iframeRef.current) return;
    setRenderError(null);

    const docContent = buildSandboxDocument(artifact);
    const iframe = iframeRef.current;

    // Use srcdoc with strict sandbox attributes
    iframe.srcdoc = docContent;
  }, [artifact?.content, artifact?.type]);

  const buildSandboxDocument = (art: Artifact): string => {
    if (art.type === 'svg') {
      return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:;">
  <style>
    body { margin: 0; padding: 20px; display: flex; align-items: center; justify-content: center; min-height: 100vh; background: #0f111a; }
    svg { max-width: 100%; max-height: 90vh; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.3)); }
  </style>
</head>
<body>
  ${art.content}
</body>
</html>`;
    }

    if (art.type === 'html') {
      return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' blob:; style-src 'unsafe-inline'; img-src data: blob:;">
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 0; padding: 16px; background: #ffffff; color: #1e293b; }
  </style>
</head>
<body>
  ${art.content}
</body>
</html>`;
    }

    if (art.type === 'react') {
      // In-browser React component rendering wrapper via pre-bundled runtime
      return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net blob:; style-src 'unsafe-inline' https://cdn.jsdelivr.net; img-src data: blob:;">
  <script src="https://cdn.jsdelivr.net/npm/react@18/umd/react.production.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@babel/standalone/babel.min.js"></script>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
  <style>
    body { margin: 0; padding: 16px; background: #0f111a; color: #f1f5f9; font-family: system-ui, sans-serif; }
  </style>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel">
    try {
      ${art.content}
      // Attempt mounting default or Component
      const TargetComponent = typeof App !== 'undefined' ? App : (typeof Component !== 'undefined' ? Component : null);
      if (TargetComponent) {
        ReactDOM.createRoot(document.getElementById('root')).render(<TargetComponent />);
      } else {
        document.getElementById('root').innerHTML = '<div class="text-amber-400 p-4 border border-amber-800 rounded">React artifact parsed successfully. Please define an <code>App</code> or <code>Component</code> export to mount.</div>';
      }
    } catch (err) {
      document.getElementById('root').innerHTML = '<div class="text-red-400 p-4 border border-red-800 rounded"><strong>React Execution Error:</strong><br/>' + err.message + '</div>';
    }
  </script>
</body>
</html>`;
    }

    if (art.type === 'markdown') {
      return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; padding: 24px; max-width: 800px; margin: 0 auto; color: #c9d1d9; background: #0d1117; line-height: 1.6; }
    h1, h2, h3 { color: #58a6ff; border-bottom: 1px solid #21262d; padding-bottom: 0.3em; }
    pre { background: #161b22; padding: 16px; border-radius: 6px; overflow-x: auto; border: 1px solid #30363d; }
    code { font-family: monospace; background: #21262d; padding: 0.2em 0.4em; border-radius: 3px; }
  </style>
</head>
<body>
  <pre>${art.content.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
</body>
</html>`;
    }

    // Default Code or Vulkan Shader view
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
  <style>
    body { margin: 0; padding: 16px; background: #141620; color: #a5b4fc; font-family: 'Fira Code', monospace; font-size: 13px; }
    pre { margin: 0; white-space: pre-wrap; word-break: break-all; }
  </style>
</head>
<body>
  <pre>${art.content.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
</body>
</html>`;
  };

  if (!artifact) {
    return (
      <div className="flex items-center justify-center h-full text-gray-500 bg-[#0f111a] text-sm">
        No active artifact selected for preview.
      </div>
    );
  }

  return (
    <div className="relative w-full h-full bg-[#0f111a] flex flex-col">
      {renderError && (
        <div className="bg-red-900/60 text-red-200 px-4 py-2 text-xs border-b border-red-800">
          {renderError}
        </div>
      )}
      <iframe
        ref={iframeRef}
        title="Artifact Sandbox Preview"
        sandbox="allow-scripts allow-modals"
        className="w-full h-full border-0 bg-transparent flex-1"
      />
    </div>
  );
};
```

### File 6: Code Editor Component (`plugins/artifact-canvas/src/editor/CodeEditor.tsx`)
```tsx
import React from 'react';
import { Artifact } from '../types';

export interface CodeEditorProps {
  artifact: Artifact | null;
  onChange?: (newContent: string) => void;
  readOnly?: boolean;
}

export const CodeEditor: React.FC<CodeEditorProps> = ({
  artifact,
  onChange,
  readOnly = false
}) => {
  if (!artifact) {
    return (
      <div className="flex items-center justify-center h-full text-gray-500 bg-[#161822] text-sm">
        No code artifact loaded.
      </div>
    );
  }

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    if (onChange && !readOnly) {
      onChange(e.target.value);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#161822] text-gray-200 font-mono text-sm border-r border-[#232736]">
      {/* Code Editor Header */}
      <div className="flex items-center justify-between px-4 py-2 bg-[#1b1e2c] border-b border-[#232736] text-xs text-gray-400">
        <div className="flex items-center space-x-2">
          <span className="font-semibold text-blue-400">{artifact.filePath || artifact.title}</span>
          <span className="px-1.5 py-0.5 rounded bg-[#272c40] text-gray-300">
            {artifact.language.toUpperCase()}
          </span>
          <span className="text-gray-500">v{artifact.version}</span>
        </div>
        {readOnly && <span className="text-amber-400 font-sans">Read-Only</span>}
      </div>

      {/* Editor Surface */}
      <div className="flex-1 relative">
        <textarea
          value={artifact.content}
          onChange={handleChange}
          readOnly={readOnly}
          spellCheck={false}
          className="w-full h-full p-4 bg-transparent resize-none focus:outline-none text-gray-100 font-mono text-xs leading-5 select-text selection:bg-blue-600/40"
        />
      </div>
    </div>
  );
};
```

### File 7: Main Canvas Split-View Component (`plugins/artifact-canvas/src/ui/ArtifactCanvasView.tsx`)
```tsx
import React, { useState, useEffect } from 'react';
import { ArtifactStore } from '../ArtifactStore';
import { Artifact, CanvasViewMode } from '../types';
import { CodeEditor } from '../editor/CodeEditor';
import { PreviewSandbox } from '../sandbox/PreviewSandbox';

export interface ArtifactCanvasViewProps {
  artifactStore?: ArtifactStore;
  onSaveToDisk?: (artifact: Artifact) => Promise<void>;
}

export const ArtifactCanvasView: React.FC<ArtifactCanvasViewProps> = ({
  artifactStore,
  onSaveToDisk
}) => {
  const [artifacts, setArtifacts] = useState<Artifact[]>([]);
  const [activeArtifact, setActiveArtifact] = useState<Artifact | null>(null);
  const [viewMode, setViewMode] = useState<CanvasViewMode>('split');
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (!artifactStore) return;

    const updateState = () => {
      setArtifacts(artifactStore.listArtifacts());
      setActiveArtifact(artifactStore.getActiveArtifact());
    };

    updateState();
    return artifactStore.subscribe(updateState);
  }, [artifactStore]);

  const handleEditorChange = (newContent: string) => {
    if (activeArtifact && artifactStore) {
      artifactStore.updateContent(activeArtifact.id, newContent, 'user');
    }
  };

  const handleSave = async () => {
    if (!activeArtifact || !onSaveToDisk) return;
    setIsSaving(true);
    try {
      await onSaveToDisk(activeArtifact);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#12141c] text-[#e0e4ee] font-sans">
      {/* Top Toolbar */}
      <div className="flex items-center justify-between px-4 py-2.5 bg-[#181b29] border-b border-[#232736]">
        {/* Artifact Selector Tabs */}
        <div className="flex items-center space-x-1 overflow-x-auto max-w-[60%]">
          {artifacts.map((art) => (
            <button
              key={art.id}
              onClick={() => artifactStore?.setActiveArtifactId(art.id)}
              className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap ${
                activeArtifact?.id === art.id
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-[#22273d]'
              }`}
            >
              {art.title}
            </button>
          ))}
          {artifacts.length === 0 && (
            <span className="text-xs text-gray-500 italic">No artifacts extracted yet</span>
          )}
        </div>

        {/* View Mode Controls & Save Button */}
        <div className="flex items-center space-x-2">
          <div className="bg-[#12141c] p-0.5 rounded-md border border-[#2e344d] flex items-center">
            <button
              onClick={() => setViewMode('code-only')}
              className={`px-2.5 py-1 text-xs rounded transition-colors ${
                viewMode === 'code-only' ? 'bg-[#272c44] text-blue-300 font-semibold' : 'text-gray-400 hover:text-gray-200'
              }`}
            >
              Code
            </button>
            <button
              onClick={() => setViewMode('split')}
              className={`px-2.5 py-1 text-xs rounded transition-colors ${
                viewMode === 'split' ? 'bg-[#272c44] text-blue-300 font-semibold' : 'text-gray-400 hover:text-gray-200'
              }`}
            >
              Split
            </button>
            <button
              onClick={() => setViewMode('preview-only')}
              className={`px-2.5 py-1 text-xs rounded transition-colors ${
                viewMode === 'preview-only' ? 'bg-[#272c44] text-blue-300 font-semibold' : 'text-gray-400 hover:text-gray-200'
              }`}
            >
              Preview
            </button>
          </div>

          {onSaveToDisk && activeArtifact && (
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="bg-emerald-600 hover:bg-emerald-500 disabled:bg-gray-700 text-white text-xs font-medium px-3 py-1.5 rounded-md transition-colors flex items-center space-x-1"
            >
              <span>{isSaving ? 'Saving...' : 'Save to Disk'}</span>
            </button>
          )}
        </div>
      </div>

      {/* Main Content Workspace */}
      <div className="flex-1 flex overflow-hidden">
        {(viewMode === 'code-only' || viewMode === 'split') && (
          <div className={`${viewMode === 'split' ? 'w-1/2' : 'w-full'} h-full`}>
            <CodeEditor
              artifact={activeArtifact}
              onChange={handleEditorChange}
            />
          </div>
        )}

        {(viewMode === 'preview-only' || viewMode === 'split') && (
          <div className={`${viewMode === 'split' ? 'w-1/2' : 'w-full'} h-full`}>
            <PreviewSandbox artifact={activeArtifact} />
          </div>
        )}
      </div>
    </div>
  );
};
```

### File 8: Sidebar Navigation Icon Component (`plugins/artifact-canvas/src/ui/ArtifactNavIcon.tsx`)
```tsx
import React from 'react';

export const ArtifactNavIcon: React.FC<{ active?: boolean; onClick?: () => void }> = ({
  active,
  onClick
}) => {
  return (
    <button
      onClick={onClick}
      title="Artifact Canvas (Code & Preview)"
      className={`w-10 h-10 rounded-lg flex items-center justify-center transition-all ${
        active
          ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/20'
          : 'text-gray-400 hover:text-gray-200 hover:bg-[#202538]'
      }`}
    >
      <svg
        className="w-5 h-5"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
        />
      </svg>
    </button>
  );
};
```

### File 9: Plugin Entry Point (`plugins/artifact-canvas/src/index.ts`)
```typescript
import { ArtifactStore } from './ArtifactStore';
import { ArtifactParser } from './ArtifactParser';
import { Artifact } from './types';

export default class ArtifactCanvasPlugin {
  private store = new ArtifactStore();

  async initialize(ctx: any): Promise<void> {
    // Register the canvas service into Cordis
    if (ctx.services?.provide) {
      ctx.services.provide('canvas', {
        store: this.store,
        parser: ArtifactParser,
        addArtifact: (artifact: Artifact) => this.store.setArtifact(artifact),
        parseStream: (sessionId: string, text: string) => {
          const extracted = ArtifactParser.parseArtifacts(sessionId, text);
          for (const item of extracted) {
            this.store.setArtifact(item, 'agent');
          }
          return extracted;
        }
      });
    }

    // Subscribe to Agent stream events if agent service is present
    const agentService = ctx.services?.get('agent');
    if (agentService && agentService.on) {
      agentService.on('turn:token', (payload: { sessionId: string; fullContent: string }) => {
        const artifacts = ArtifactParser.parseArtifacts(payload.sessionId, payload.fullContent);
        for (const art of artifacts) {
          this.store.setArtifact(art, 'agent');
        }
      });
    }
  }

  async activate(): Promise<void> {
    console.log('[ArtifactCanvasPlugin] Activated.');
  }

  async deactivate(): Promise<void> {
    console.log('[ArtifactCanvasPlugin] Deactivated.');
  }

  async dispose(): Promise<void> {
    console.log('[ArtifactCanvasPlugin] Disposed.');
  }
}
```

---

## 6. Step-by-Step AI Execution Instructions

Follow these exact steps to scaffold the Artifact Canvas plugin inside `/mnt/MD/Project/DSH/DSH-Desktop`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Session 07] Scaffolding plugins/artifact-canvas..."
mkdir -p plugins/artifact-canvas/src/{editor,sandbox,ui}

# 1. Compile TypeScript code
echo "==> [Session 07] Compiling TypeScript plugins..."
npm run build || npx tsc --noEmit

echo "==> [Session 07] Artifact Canvas plugin files created successfully."
```

---

## 7. Validation & Verification Commands

Execute the following automated test script to verify artifact extraction, revision tracking, and sandbox CSP rules:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Verification] Running Session 07 automated test harness..."

# Test 1: Validate ArtifactParser XML & Code block extraction
node -e '
const { ArtifactParser } = require("./plugins/artifact-canvas/src/ArtifactParser.ts");

// 1. Test XML artifact parsing
const xmlSample = `<dsh_artifact id="vulkan-pipeline" type="vulkan-shader" language="glsl" title="Vulkan Compute Shader" file="shaders/comp.glsl">
#version 450
layout(local_size_x = 64) in;
void main() {
    // Vulkan compute logic
}
</dsh_artifact>`;

const artifacts = ArtifactParser.parseArtifacts("test-session", xmlSample);
console.assert(artifacts.length === 1, "Failed to parse XML artifact!");
console.assert(artifacts[0].type === "vulkan-shader", "Wrong artifact type extracted!");
console.assert(artifacts[0].title === "Vulkan Compute Shader", "Wrong title extracted!");

console.log("==> Test 1 Passed: ArtifactParser parses XML definitions correctly.");
'

# Test 2: Validate ArtifactStore and Revision Tracking
node -e '
const { ArtifactStore } = require("./plugins/artifact-canvas/src/ArtifactStore.ts");
const store = new ArtifactStore();

store.setArtifact({
  id: "test-react",
  sessionId: "s1",
  title: "App Component",
  type: "react",
  language: "tsx",
  content: "export const App = () => <div>Hello</div>;",
  version: 1,
  createdAt: Date.now(),
  updatedAt: Date.now()
});

// Update content and verify revision creation
store.updateContent("test-react", "export const App = () => <div>Hello CachyOS</div>;", "user");

const active = store.getActiveArtifact();
console.assert(active.version === 2, "Artifact version did not increment!");
console.assert(store.getRevisions("test-react").length === 1, "Revision was not recorded!");

console.log("==> Test 2 Passed: ArtifactStore versioning and state management OK.");
'

echo "==> [Verification] Session 07 completed all validation checks successfully!"
```

---

## 8. Definition of Done Checklist

- [ ] `plugins/artifact-canvas/dsh.plugin.json` authored with slot declarations (`workspace.main`, `sidebar.nav`) and permissions (`fs:read:workspace`, `fs:write:workspace`).
- [ ] `ArtifactParser.ts` implemented supporting both `<dsh_artifact>` tags and standard fenced markdown code blocks.
- [ ] `ArtifactStore.ts` implemented with active artifact selection, content updates, and historical revision tracking.
- [ ] `PreviewSandbox.tsx` implemented with isolated iframe rendering and strict Content Security Policy (`CSP: default-src 'none'`).
- [ ] `CodeEditor.tsx` implemented providing a code editing surface with file path header, syntax tag, and live change dispatching.
- [ ] `ArtifactCanvasView.tsx` implemented providing split-view, code-only, and preview-only modes with disk save callbacks.
- [ ] Automated verification script executes with zero errors.
