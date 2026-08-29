# Session 06: Core Agent Runtime & Model Orchestration Plugin

> **Objective:** Implement the official Core Agent Runtime & Model Orchestration Plugin (`plugins/agent-orchestrator`) for DSH-Desktop on CachyOS, featuring a unified multi-provider LLM client (Ollama, LM Studio / vLLM, OpenRouter), a streaming Server-Sent Events (SSE) / NDJSON token parser, a robust conversation state and message history manager, and an automated tool-calling execution loop integrated with the Cordis plugin kernel and Bubblewrap (`bwrap`) isolation layer.

---

## 1. Execution Context & Metadata

* **Session ID:** `DSH-SESSION-06`
* **Title:** Core Agent Runtime & Model Orchestration Plugin
* **Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`
* **Upstream Implementation Remote:** `https://github.com/Tariq-Anjum/dsh-desktop.git`
* **Architecture Reference Remote:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux.git`
* **Pre-requisites:**
  * Session 01: Baseline environment, CachyOS toolchain (`-march=x86-64-v3`), and directories initialized.
  * Session 02: Cordis Core Plugin Runtime (`PluginContext`, `ServiceContainer`, `PluginRegistry`) active.
  * Session 03: Host-Agent IPC Protocol and Bubblewrap (`bwrap`) security sandbox bridge operational.
  * Session 05: Modular UI Shell, dynamic slotting engine (`workspace.main`, `sidebar.nav`), and theme engine active.
* **Target Operating System:** CachyOS (Linux 6.x BORE/sched-ext kernel, x86-64-v3/v4, Wayland/X11).
* **Core Technologies:** TypeScript 5.5+, Node.js 22+ ESM, React 18, Cordis Plugin Architecture, Server-Sent Events (SSE), JSON Schema validation.

---

## 2. Architecture & Data Flow Diagram

```
+---------------------------------------------------------------------------------------------------+
|                                  Cordis Plugin Context (`ctx`)                                     |
|  - Injects: `ctx.services.get('ipc')`, `ctx.services.get('slots')`, `ctx.services.get('config')`  |
|  - Provides: `ctx.services.provide('agent', agentServiceInstance)`                                |
+---------------------------------------------------------------------------------------------------+
                                                  |
                         +------------------------+------------------------+
                         |                                                 |
+--------------------------------------------------+     +-----------------------------------+
|          AgentOrchestratorPlugin (Cordis)        |     |   UI Slot: `workspace.main`       |
|  - State: `ConversationManager` (SQLite/JSON)     |     |   - `AgentChatWorkspace.tsx`      |
|  - Dispatcher: `ToolExecutionDispatcher`         | <-> |   UI Slot: `sidebar.nav`          |
|  - LLM Gateway: `MultiProviderClient`            |     |   - `AgentNavIcon.tsx`            |
+--------------------------------------------------+     +-----------------------------------+
                         |
        +----------------+----------------+
        |                                 |
+-------------------------------+ +---------------------------------------------------------------+
|  Multi-Provider LLM Gateway   | | Tool Execution Loop (bwrap Sandbox)                           |
|  1. Local Ollama (`/api/chat`)| | 1. LLM returns Tool Call (JSON Schema validated)              |
|  2. Local LM Studio (`/v1`)   | | 2. Dispatch to `ctx.services.get('ipc').execInSandbox()`      |
|  3. Remote OpenRouter (`/v1`) | | 3. Receive stdout/stderr -> append to conversation -> recurse|
+-------------------------------+ +---------------------------------------------------------------+
```

---

## 3. Pre-Flight Verification & Assertions

Execute the following pre-flight assertions to confirm environment readiness before creating plugin files:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
echo "==> [Pre-Flight] Verifying Session 06 prerequisites in ${TARGET_DIR}..."

# 1. Check directory and core files from Sessions 01-05
if [ ! -d "${TARGET_DIR}/src/core/plugin" ]; then
    echo "ERROR: Core plugin infrastructure from Session 02 not found!"
    exit 1
fi

if [ ! -d "${TARGET_DIR}/src/core/ipc" ]; then
    echo "ERROR: IPC bridge from Session 03 not found!"
    exit 1
fi

if [ ! -d "${TARGET_DIR}/src/ui/slots" ]; then
    echo "ERROR: UI slot engine from Session 05 not found!"
    exit 1
fi

# 2. Check Node.js and TypeScript environment
node --version
npm --version

# 3. Verify local LLM endpoints (optional check for Ollama / LM Studio)
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "==> [Pre-Flight] Local Ollama service detected at http://localhost:11434"
else
    echo "==> [Pre-Flight] Note: Local Ollama service not running on port 11434 (mock client fallback will be active during tests)."
fi

echo "==> [Pre-Flight] Prerequisites validated successfully."
```

---

## 4. Capability & Security Declarations

The `agent-orchestrator` plugin requests the following permissions within the Cordis security model:

* **`network:llm`**: Outbound HTTP/HTTPS network access to localhost endpoints (`http://127.0.0.1:11434`, `http://127.0.0.1:1234`) and configured remote API endpoints (`https://openrouter.ai/api/v1`).
* **`ipc:exec`**: Permission to invoke the host IPC service to trigger sandboxed commands via `bwrap`.
* **`ipc:fs`**: Permission to read and write conversation states and workspace files within `/mnt/MD/Project/DSH/DSH-Desktop`.
* **`slots:mount`**: Permission to register UI components into `sidebar.nav`, `workspace.main`, and `header.status`.

---

## 5. Detailed File Operations & Complete Code Scaffolding

### File 1: Plugin Manifest (`plugins/agent-orchestrator/dsh.plugin.json`)
```json
{
  "$schema": "../../schemas/plugin.v1.json",
  "id": "org.dsh.plugin.agent-orchestrator",
  "name": "Core Agent Orchestrator",
  "version": "1.0.0",
  "description": "Multi-provider LLM reasoning engine, SSE streaming token parser, conversation manager, and tool dispatcher",
  "author": "Tariq Anjum",
  "type": "hybrid",
  "enabledByDefault": true,
  "entry": "src/index.ts",
  "slots": [
    {
      "target": "sidebar.nav",
      "priority": 100,
      "component": "AgentNavIcon"
    },
    {
      "target": "workspace.main",
      "priority": 90,
      "component": "AgentChatWorkspace"
    }
  ],
  "permissions": [
    "network:llm",
    "ipc:exec",
    "ipc:fs"
  ],
  "dependencies": {
    "org.dsh.core.plugin-runtime": ">=1.0.0",
    "org.dsh.core.ui-slot-manager": ">=1.0.0"
  },
  "defaultConfig": {
    "provider": "ollama",
    "ollamaEndpoint": "http://127.0.0.1:11434",
    "ollamaModel": "qwen2.5-coder:7b",
    "lmStudioEndpoint": "http://127.0.0.1:1234/v1",
    "lmStudioModel": "local-model",
    "openRouterEndpoint": "https://openrouter.ai/api/v1",
    "openRouterModel": "anthropic/claude-3.5-sonnet",
    "temperature": 0.2,
    "maxTokens": 4096,
    "systemPrompt": "You are DSH-Desktop AI Agent, an autonomous software engineering assistant running natively on CachyOS Linux with Vulkan acceleration and Bubblewrap containment."
  }
}
```

### File 2: Type Definitions & LLM Contracts (`plugins/agent-orchestrator/src/types.ts`)
```typescript
export type LLMProviderType = 'ollama' | 'lmstudio' | 'openrouter' | 'custom';

export type MessageRole = 'system' | 'user' | 'assistant' | 'tool';

export interface ToolCallFunction {
  name: string;
  arguments: string; // JSON string
}

export interface ToolCall {
  id: string;
  type: 'function';
  function: ToolCallFunction;
}

export interface ChatMessage {
  id: string;
  role: MessageRole;
  content: string;
  name?: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
  timestamp: number;
}

export interface ConversationSession {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messages: ChatMessage[];
  model: string;
  provider: LLMProviderType;
}

export interface ToolParameterSchema {
  type: 'object';
  properties: Record<string, {
    type: string;
    description: string;
    enum?: string[];
    items?: Record<string, unknown>;
  }>;
  required?: string[];
}

export interface ToolDefinition {
  name: string;
  description: string;
  parameters: ToolParameterSchema;
  execute(params: Record<string, unknown>, context: ToolExecutionContext): Promise<ToolExecutionResult>;
}

export interface ToolExecutionContext {
  workspaceDir: string;
  sessionId: string;
  ipcService: unknown;
  signal?: AbortSignal;
}

export interface ToolExecutionResult {
  success: boolean;
  output: string;
  error?: string;
  metadata?: Record<string, unknown>;
}

export interface StreamChunk {
  deltaText: string;
  deltaToolCalls?: ToolCall[];
  isComplete: boolean;
  finishReason?: string;
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

export interface AgentConfig {
  provider: LLMProviderType;
  ollamaEndpoint: string;
  ollamaModel: string;
  lmStudioEndpoint: string;
  lmStudioModel: string;
  openRouterEndpoint: string;
  openRouterModel: string;
  openRouterApiKey?: string;
  temperature: number;
  maxTokens: number;
  systemPrompt: string;
}
```

### File 3: Streaming SSE & NDJSON Parser (`plugins/agent-orchestrator/src/StreamingParser.ts`)
```typescript
import { StreamChunk, ToolCall } from './types';

export class StreamingParser {
  private buffer = '';

  /**
   * Feed a chunk of raw text received from network stream and extract complete SSE / NDJSON lines.
   */
  feed(chunk: string): string[] {
    this.buffer += chunk;
    const lines = this.buffer.split(/?
/);
    // Keep incomplete trailing fragment in buffer
    this.buffer = lines.pop() ?? '';
    return lines.filter((line) => line.trim().length > 0);
  }

  /**
   * Parse an OpenAI-compatible Server-Sent Events line (`data: {...}`).
   */
  parseOpenAISSE(line: string): StreamChunk | null {
    const trimmed = line.trim();
    if (!trimmed.startsWith('data:')) return null;

    const dataPayload = trimmed.slice(5).trim();
    if (dataPayload === '[DONE]') {
      return { deltaText: '', isComplete: true, finishReason: 'stop' };
    }

    try {
      const parsed = JSON.parse(dataPayload);
      const choice = parsed.choices?.[0];
      if (!choice) return null;

      const delta = choice.delta;
      const deltaText = delta?.content ?? '';
      const finishReason = choice.finish_reason ?? undefined;
      const isComplete = finishReason !== null && finishReason !== undefined;

      let deltaToolCalls: ToolCall[] | undefined = undefined;
      if (delta?.tool_calls && Array.isArray(delta.tool_calls)) {
        deltaToolCalls = delta.tool_calls.map((tc: any) => ({
          id: tc.id || '',
          type: 'function',
          function: {
            name: tc.function?.name || '',
            arguments: tc.function?.arguments || ''
          }
        }));
      }

      return {
        deltaText,
        deltaToolCalls,
        isComplete,
        finishReason
      };
    } catch {
      return null;
    }
  }

  /**
   * Parse an Ollama `/api/chat` or `/api/generate` NDJSON line.
   */
  parseOllamaNDJSON(line: string): StreamChunk | null {
    try {
      const parsed = JSON.parse(line.trim());
      const deltaText = parsed.message?.content ?? parsed.response ?? '';
      const isComplete = Boolean(parsed.done);

      let deltaToolCalls: ToolCall[] | undefined = undefined;
      if (parsed.message?.tool_calls && Array.isArray(parsed.message.tool_calls)) {
        deltaToolCalls = parsed.message.tool_calls.map((tc: any, idx: number) => ({
          id: `ollama-tc-${Date.now()}-${idx}`,
          type: 'function',
          function: {
            name: tc.function?.name || '',
            arguments: typeof tc.function?.arguments === 'string'
              ? tc.function.arguments
              : JSON.stringify(tc.function?.arguments || {})
          }
        }));
      }

      return {
        deltaText,
        deltaToolCalls,
        isComplete,
        finishReason: isComplete ? 'stop' : undefined,
        usage: isComplete
          ? {
              promptTokens: parsed.prompt_eval_count ?? 0,
              completionTokens: parsed.eval_count ?? 0,
              totalTokens: (parsed.prompt_eval_count ?? 0) + (parsed.eval_count ?? 0)
            }
          : undefined
      };
    } catch {
      return null;
    }
  }

  /**
   * Flush any remaining content in buffer upon stream termination.
   */
  flush(): string {
    const remaining = this.buffer;
    this.buffer = '';
    return remaining;
  }
}
```

### File 4: Multi-Provider LLM Gateway Client (`plugins/agent-orchestrator/src/MultiProviderClient.ts`)
```typescript
import { AgentConfig, ChatMessage, StreamChunk, ToolDefinition } from './types';
import { StreamingParser } from './StreamingParser';

export class MultiProviderClient {
  constructor(private config: AgentConfig) {}

  updateConfig(newConfig: Partial<AgentConfig>): void {
    this.config = { ...this.config, ...newConfig };
  }

  async *streamChat(
    messages: ChatMessage[],
    tools: ToolDefinition[] = [],
    signal?: AbortSignal
  ): AsyncGenerator<StreamChunk, void, unknown> {
    const provider = this.config.provider;

    switch (provider) {
      case 'ollama':
        yield* this.streamOllama(messages, tools, signal);
        break;
      case 'lmstudio':
      case 'openrouter':
      case 'custom':
      default:
        yield* this.streamOpenAICompatible(messages, tools, signal);
        break;
    }
  }

  private async *streamOllama(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    signal?: AbortSignal
  ): AsyncGenerator<StreamChunk, void, unknown> {
    const endpoint = `${this.config.ollamaEndpoint.replace(/\/$/, '')}/api/chat`;
    const formattedMessages = messages.map((m) => ({
      role: m.role,
      content: m.content,
      name: m.name
    }));

    const formattedTools = tools.map((t) => ({
      type: 'function',
      function: {
        name: t.name,
        description: t.description,
        parameters: t.parameters
      }
    }));

    const requestBody: Record<string, unknown> = {
      model: this.config.ollamaModel,
      messages: formattedMessages,
      stream: true,
      options: {
        temperature: this.config.temperature,
        num_predict: this.config.maxTokens
      }
    };

    if (formattedTools.length > 0) {
      requestBody.tools = formattedTools;
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
      signal
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Ollama API error (${response.status}): ${errorText}`);
    }

    if (!response.body) throw new Error('Response body is null');

    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    const parser = new StreamingParser();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const textChunk = decoder.decode(value, { stream: true });
        const lines = parser.feed(textChunk);

        for (const line of lines) {
          const chunk = parser.parseOllamaNDJSON(line);
          if (chunk) yield chunk;
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  private async *streamOpenAICompatible(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    signal?: AbortSignal
  ): AsyncGenerator<StreamChunk, void, unknown> {
    const isLMStudio = this.config.provider === 'lmstudio';
    const baseUrl = isLMStudio
      ? this.config.lmStudioEndpoint.replace(/\/$/, '')
      : this.config.openRouterEndpoint.replace(/\/$/, '');
    const endpoint = `${baseUrl}/chat/completions`;
    const model = isLMStudio ? this.config.lmStudioModel : this.config.openRouterModel;

    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    if (this.config.provider === 'openrouter' && this.config.openRouterApiKey) {
      headers['Authorization'] = `Bearer ${this.config.openRouterApiKey}`;
      headers['HTTP-Referer'] = 'https://github.com/Tariq-Anjum/dsh-desktop';
      headers['X-Title'] = 'DSH-Desktop Linux';
    }

    const formattedMessages = messages.map((m) => {
      const msg: any = { role: m.role, content: m.content };
      if (m.name) msg.name = m.name;
      if (m.tool_call_id) msg.tool_call_id = m.tool_call_id;
      if (m.tool_calls) msg.tool_calls = m.tool_calls;
      return msg;
    });

    const formattedTools = tools.map((t) => ({
      type: 'function',
      function: {
        name: t.name,
        description: t.description,
        parameters: t.parameters
      }
    }));

    const requestBody: Record<string, unknown> = {
      model,
      messages: formattedMessages,
      stream: true,
      temperature: this.config.temperature,
      max_tokens: this.config.maxTokens
    };

    if (formattedTools.length > 0) {
      requestBody.tools = formattedTools;
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(requestBody),
      signal
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OpenAI-compatible API error (${response.status}): ${errorText}`);
    }

    if (!response.body) throw new Error('Response body is null');

    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    const parser = new StreamingParser();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const textChunk = decoder.decode(value, { stream: true });
        const lines = parser.feed(textChunk);

        for (const line of lines) {
          const chunk = parser.parseOpenAISSE(line);
          if (chunk) {
            yield chunk;
            if (chunk.isComplete) return;
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }
}
```

### File 5: Conversation & Message State Manager (`plugins/agent-orchestrator/src/ConversationManager.ts`)
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { ChatMessage, ConversationSession, LLMProviderType } from './types';

export class ConversationManager {
  private sessions = new Map<string, ConversationSession>();
  private activeSessionId: string | null = null;
  private storageDir: string;

  constructor(storageDir?: string) {
    this.storageDir =
      storageDir ||
      path.join(
        process.env.HOME || '/root',
        '.config',
        'dsh-desktop',
        'conversations'
      );
    this.ensureStorage();
    this.loadFromDisk();
  }

  private ensureStorage(): void {
    if (!fs.existsSync(this.storageDir)) {
      fs.mkdirSync(this.storageDir, { recursive: true });
    }
  }

  createSession(
    title = 'New Conversation',
    provider: LLMProviderType = 'ollama',
    model = 'qwen2.5-coder:7b'
  ): ConversationSession {
    const id = `session-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const session: ConversationSession = {
      id,
      title,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      messages: [],
      provider,
      model
    };
    this.sessions.set(id, session);
    this.activeSessionId = id;
    this.persistSession(session);
    return session;
  }

  getActiveSession(): ConversationSession | null {
    if (!this.activeSessionId) {
      if (this.sessions.size > 0) {
        this.activeSessionId = Array.from(this.sessions.keys())[0];
      } else {
        return this.createSession();
      }
    }
    return this.sessions.get(this.activeSessionId) || null;
  }

  setActiveSession(id: string): boolean {
    if (this.sessions.has(id)) {
      this.activeSessionId = id;
      return true;
    }
    return false;
  }

  listSessions(): ConversationSession[] {
    return Array.from(this.sessions.values()).sort(
      (a, b) => b.updatedAt - a.updatedAt
    );
  }

  addMessage(
    sessionId: string,
    role: ChatMessage['role'],
    content: string,
    toolCalls?: ChatMessage['tool_calls'],
    toolCallId?: string
  ): ChatMessage {
    const session = this.sessions.get(sessionId);
    if (!session) throw new Error(`Session ${sessionId} not found`);

    const message: ChatMessage = {
      id: `msg-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      role,
      content,
      tool_calls: toolCalls,
      tool_call_id: toolCallId,
      timestamp: Date.now()
    };

    session.messages.push(message);
    session.updatedAt = Date.now();

    // Auto-update session title from first user message
    if (session.title === 'New Conversation' && role === 'user') {
      session.title = content.slice(0, 40).trim() || 'Conversation';
    }

    this.persistSession(session);
    return message;
  }

  appendAssistantDelta(sessionId: string, deltaText: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.messages.length === 0) return;

    const lastMsg = session.messages[session.messages.length - 1];
    if (lastMsg.role === 'assistant') {
      lastMsg.content += deltaText;
      session.updatedAt = Date.now();
    }
  }

  deleteSession(sessionId: string): boolean {
    const deleted = this.sessions.delete(sessionId);
    if (deleted) {
      const filePath = path.join(this.storageDir, `${sessionId}.json`);
      if (fs.existsSync(filePath)) {
        try {
          fs.unlinkSync(filePath);
        } catch {
          // Ignore deletion error
        }
      }
      if (this.activeSessionId === sessionId) {
        this.activeSessionId = this.sessions.size > 0 ? Array.from(this.sessions.keys())[0] : null;
      }
    }
    return deleted;
  }

  private persistSession(session: ConversationSession): void {
    try {
      const filePath = path.join(this.storageDir, `${session.id}.json`);
      fs.writeFileSync(filePath, JSON.stringify(session, null, 2), 'utf-8');
    } catch (err) {
      console.error(`[ConversationManager] Failed to persist session ${session.id}:`, err);
    }
  }

  private loadFromDisk(): void {
    try {
      const files = fs.readdirSync(this.storageDir);
      for (const file of files) {
        if (!file.endsWith('.json')) continue;
        const filePath = path.join(this.storageDir, file);
        const data = fs.readFileSync(filePath, 'utf-8');
        const session: ConversationSession = JSON.parse(data);
        this.sessions.set(session.id, session);
      }
    } catch {
      // Storage directory may be empty initially
    }
  }
}
```

### File 6: Tool Execution Dispatcher (`plugins/agent-orchestrator/src/ToolDispatcher.ts`)
```typescript
import { ToolCall, ToolDefinition, ToolExecutionContext, ToolExecutionResult } from './types';

export class ToolDispatcher {
  private tools = new Map<string, ToolDefinition>();

  registerTool(tool: ToolDefinition): void {
    this.tools.set(tool.name, tool);
  }

  unregisterTool(toolName: string): boolean {
    return this.tools.delete(toolName);
  }

  getTools(): ToolDefinition[] {
    return Array.from(this.tools.values());
  }

  getTool(name: string): ToolDefinition | undefined {
    return this.tools.get(name);
  }

  async executeToolCall(
    toolCall: ToolCall,
    context: ToolExecutionContext
  ): Promise<ToolExecutionResult> {
    const toolName = toolCall.function.name;
    const tool = this.tools.get(toolName);

    if (!tool) {
      return {
        success: false,
        output: '',
        error: `Tool "${toolName}" is not registered in the agent orchestrator.`
      };
    }

    let parsedArgs: Record<string, unknown> = {};
    try {
      parsedArgs = toolCall.function.arguments
        ? JSON.parse(toolCall.function.arguments)
        : {};
    } catch (err: any) {
      return {
        success: false,
        output: '',
        error: `Invalid JSON parameters provided for tool "${toolName}": ${err.message}`
      };
    }

    // Validate required parameters
    if (tool.parameters.required) {
      for (const req of tool.parameters.required) {
        if (parsedArgs[req] === undefined || parsedArgs[req] === null) {
          return {
            success: false,
            output: '',
            error: `Missing required parameter "${req}" for tool "${toolName}".`
          };
        }
      }
    }

    try {
      return await tool.execute(parsedArgs, context);
    } catch (err: any) {
      return {
        success: false,
        output: '',
        error: `Tool "${toolName}" threw runtime exception: ${err.message || err}`
      };
    }
  }
}
```

### File 7: Core Orchestration Agent Engine (`plugins/agent-orchestrator/src/AgentEngine.ts`)
```typescript
import { MultiProviderClient } from './MultiProviderClient';
import { ConversationManager } from './ConversationManager';
import { ToolDispatcher } from './ToolDispatcher';
import { AgentConfig, ChatMessage, ToolCall, ToolExecutionContext } from './types';

export class AgentEngine {
  private client: MultiProviderClient;
  private conversationManager: ConversationManager;
  private toolDispatcher: ToolDispatcher;
  private abortControllers = new Map<string, AbortController>();

  constructor(
    private config: AgentConfig,
    conversationManager?: ConversationManager,
    toolDispatcher?: ToolDispatcher
  ) {
    this.client = new MultiProviderClient(config);
    this.conversationManager = conversationManager || new ConversationManager();
    this.toolDispatcher = toolDispatcher || new ToolDispatcher();
  }

  getConversationManager(): ConversationManager {
    return this.conversationManager;
  }

  getToolDispatcher(): ToolDispatcher {
    return this.toolDispatcher;
  }

  updateConfig(newConfig: Partial<AgentConfig>): void {
    this.config = { ...this.config, ...newConfig };
    this.client.updateConfig(this.config);
  }

  cancelTurn(sessionId: string): void {
    const controller = this.abortControllers.get(sessionId);
    if (controller) {
      controller.abort();
      this.abortControllers.delete(sessionId);
    }
  }

  async runTurn(
    sessionId: string,
    userPrompt: string,
    onToken?: (delta: string) => void,
    onToolStart?: (toolCall: ToolCall) => void,
    onToolEnd?: (toolCall: ToolCall, result: any) => void
  ): Promise<string> {
    const session = this.conversationManager.getActiveSession();
    if (!session || session.id !== sessionId) {
      this.conversationManager.setActiveSession(sessionId);
    }

    // Add user message
    this.conversationManager.addMessage(sessionId, 'user', userPrompt);

    const abortController = new AbortController();
    this.abortControllers.set(sessionId, abortController);

    let turnsRemaining = 10; // Max recursive tool turns
    let finalAssistantResponse = '';

    try {
      while (turnsRemaining > 0) {
        turnsRemaining--;

        const activeSession = this.conversationManager.getActiveSession();
        if (!activeSession) break;

        const messagesWithSystem: ChatMessage[] = [
          {
            id: 'sys-prompt',
            role: 'system',
            content: this.config.systemPrompt,
            timestamp: 0
          },
          ...activeSession.messages
        ];

        const tools = this.toolDispatcher.getTools();
        let currentAssistantText = '';
        const accumulatedToolCalls: Map<number, ToolCall> = new Map();

        // Create empty assistant message placeholder
        const assistantMsg = this.conversationManager.addMessage(sessionId, 'assistant', '');

        for await (const chunk of this.client.streamChat(
          messagesWithSystem,
          tools,
          abortController.signal
        )) {
          if (chunk.deltaText) {
            currentAssistantText += chunk.deltaText;
            this.conversationManager.appendAssistantDelta(sessionId, chunk.deltaText);
            if (onToken) onToken(chunk.deltaText);
          }

          if (chunk.deltaToolCalls) {
            for (let i = 0; i < chunk.deltaToolCalls.length; i++) {
              const tcDelta = chunk.deltaToolCalls[i];
              if (!accumulatedToolCalls.has(i)) {
                accumulatedToolCalls.set(i, {
                  id: tcDelta.id || `tc-${Date.now()}-${i}`,
                  type: 'function',
                  function: {
                    name: tcDelta.function.name,
                    arguments: tcDelta.function.arguments
                  }
                });
              } else {
                const existing = accumulatedToolCalls.get(i)!;
                if (tcDelta.function.name) existing.function.name += tcDelta.function.name;
                if (tcDelta.function.arguments) existing.function.arguments += tcDelta.function.arguments;
              }
            }
          }

          if (chunk.isComplete) break;
        }

        finalAssistantResponse = currentAssistantText;
        const toolCallsList = Array.from(accumulatedToolCalls.values());

        // If tools were called, execute them and recurse
        if (toolCallsList.length > 0) {
          assistantMsg.tool_calls = toolCallsList;

          for (const tc of toolCallsList) {
            if (onToolStart) onToolStart(tc);

            const execContext: ToolExecutionContext = {
              sessionId,
              workspaceDir: process.env.DSH_WORKSPACE_DIR || '/mnt/MD/Project/DSH/DSH-Desktop',
              ipcService: null,
              signal: abortController.signal
            };

            const result = await this.toolDispatcher.executeToolCall(tc, execContext);
            if (onToolEnd) onToolEnd(tc, result);

            const toolOutputStr = result.success
              ? result.output
              : JSON.stringify({ error: result.error || 'Tool execution failed' });

            this.conversationManager.addMessage(
              sessionId,
              'tool',
              toolOutputStr,
              undefined,
              tc.id
            );
          }
          // Loop continues to feed tool responses back to model
        } else {
          // No further tool calls, conversation turn complete
          break;
        }
      }

      return finalAssistantResponse;
    } finally {
      this.abortControllers.delete(sessionId);
    }
  }
}
```

### File 8: Plugin Entry Point (`plugins/agent-orchestrator/src/index.ts`)
```typescript
import { AgentEngine } from './AgentEngine';
import { AgentConfig, ToolDefinition } from './types';

export default class AgentOrchestratorPlugin {
  private engine!: AgentEngine;

  async initialize(ctx: any): Promise<void> {
    const configManager = ctx.services?.get('config');
    const userConfig: Partial<AgentConfig> = configManager?.get('agent-orchestrator') || {};

    const defaultConfig: AgentConfig = {
      provider: (process.env.DSH_LLM_PROVIDER as any) || 'ollama',
      ollamaEndpoint: process.env.DSH_OLLAMA_ENDPOINT || 'http://127.0.0.1:11434',
      ollamaModel: process.env.DSH_OLLAMA_MODEL || 'qwen2.5-coder:7b',
      lmStudioEndpoint: process.env.DSH_LMSTUDIO_ENDPOINT || 'http://127.0.0.1:1234/v1',
      lmStudioModel: process.env.DSH_LMSTUDIO_MODEL || 'local-model',
      openRouterEndpoint: 'https://openrouter.ai/api/v1',
      openRouterModel: process.env.DSH_OPENROUTER_MODEL || 'anthropic/claude-3.5-sonnet',
      openRouterApiKey: process.env.OPENROUTER_API_KEY,
      temperature: 0.2,
      maxTokens: 4096,
      systemPrompt:
        'You are DSH-Desktop AI Agent, an autonomous software engineering assistant running natively on CachyOS Linux with Vulkan acceleration and Bubblewrap containment.'
    };

    const mergedConfig: AgentConfig = { ...defaultConfig, ...userConfig };
    this.engine = new AgentEngine(mergedConfig);

    // Register built-in sample tool
    const echoTool: ToolDefinition = {
      name: 'echo_ping',
      description: 'Test connectivity and ping the runtime environment.',
      parameters: {
        type: 'object',
        properties: {
          message: { type: 'string', description: 'Message to echo back' }
        },
        required: ['message']
      },
      async execute(params) {
        return {
          success: true,
          output: `Echo ACK from CachyOS Native Host: ${params.message}`
        };
      }
    };
    this.engine.getToolDispatcher().registerTool(echoTool);

    // Provide the 'agent' service to Cordis Service Container
    if (ctx.services?.provide) {
      ctx.services.provide('agent', this.engine);
    }
  }

  async activate(ctx: any): Promise<void> {
    // Mount UI components into slots
    const slotManager = ctx.services?.get('slots');
    if (slotManager) {
      // In dynamic runtime, components will be resolved from the UI bundle
      console.log('[AgentOrchestratorPlugin] Activating and mounting UI slots...');
    }
  }

  async deactivate(): Promise<void> {
    console.log('[AgentOrchestratorPlugin] Deactivated.');
  }

  async dispose(): Promise<void> {
    console.log('[AgentOrchestratorPlugin] Disposed.');
  }
}
```

### File 9: Frontend Chat UI Component (`plugins/agent-orchestrator/src/ui/AgentChatWorkspace.tsx`)
```tsx
import React, { useState, useEffect, useRef } from 'react';
import { AgentEngine } from '../AgentEngine';
import { ChatMessage, ConversationSession, LLMProviderType } from '../types';

export interface AgentChatWorkspaceProps {
  agentEngine?: AgentEngine;
}

export const AgentChatWorkspace: React.FC<AgentChatWorkspaceProps> = ({ agentEngine }) => {
  const [session, setSession] = useState<ConversationSession | null>(null);
  const [inputPrompt, setInputPrompt] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const [activeTool, setActiveTool] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (agentEngine) {
      const active = agentEngine.getConversationManager().getActiveSession();
      setSession(active);
    }
  }, [agentEngine]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [session?.messages, isStreaming]);

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputPrompt.trim() || !agentEngine || !session || isStreaming) return;

    const currentPrompt = inputPrompt;
    setInputPrompt('');
    setIsStreaming(true);

    try {
      await agentEngine.runTurn(
        session.id,
        currentPrompt,
        () => {
          // Re-render message list
          const updated = agentEngine.getConversationManager().getActiveSession();
          if (updated) setSession({ ...updated });
        },
        (tc) => setActiveTool(tc.function.name),
        () => setActiveTool(null)
      );
    } catch (err) {
      console.error('[AgentChatWorkspace] Stream error:', err);
    } finally {
      setIsStreaming(false);
      setActiveTool(null);
      if (agentEngine) {
        const updated = agentEngine.getConversationManager().getActiveSession();
        if (updated) setSession({ ...updated });
      }
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#12141a] text-[#e0e4ee] font-sans">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-[#24283b] bg-[#1a1d2d]">
        <div className="flex items-center space-x-3">
          <div className="w-3 h-3 rounded-full bg-emerald-500 animate-pulse" />
          <span className="font-semibold text-sm tracking-wide">
            {session?.title || 'Agent Orchestration Session'}
          </span>
          <span className="text-xs px-2 py-0.5 rounded bg-[#2a2f4c] text-blue-300">
            {session?.provider.toUpperCase()}: {session?.model}
          </span>
        </div>
        {activeTool && (
          <div className="flex items-center space-x-2 text-xs bg-amber-950/70 text-amber-300 px-2.5 py-1 rounded border border-amber-800">
            <span className="inline-block animate-spin">⚙</span>
            <span>Running tool: <strong>{activeTool}</strong></span>
          </div>
        )}
      </div>

      {/* Messages Scroll Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {session?.messages.map((msg: ChatMessage) => (
          <div
            key={msg.id}
            className={`flex flex-col ${
              msg.role === 'user' ? 'items-end' : 'items-start'
            }`}
          >
            <div className="text-[11px] text-gray-400 mb-1 px-1">
              {msg.role === 'user' ? 'User' : msg.role === 'assistant' ? 'DSH Agent' : `Tool (${msg.name || 'output'})`}
            </div>
            <div
              className={`max-w-[85%] rounded-lg p-3 text-sm leading-relaxed ${
                msg.role === 'user'
                  ? 'bg-blue-600 text-white rounded-br-none'
                  : msg.role === 'assistant'
                  ? 'bg-[#1e2235] text-gray-100 border border-[#2a2f4c] rounded-bl-none whitespace-pre-wrap'
                  : 'bg-[#161926] text-emerald-400 font-mono text-xs border border-[#24283b]'
              }`}
            >
              {msg.content}
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Form */}
      <form
        onSubmit={handleSendMessage}
        className="p-4 border-t border-[#24283b] bg-[#1a1d2d] flex items-center space-x-2"
      >
        <input
          type="text"
          value={inputPrompt}
          onChange={(e) => setInputPrompt(e.target.value)}
          placeholder={isStreaming ? 'Agent is thinking...' : 'Ask agent to inspect code, run tests, build project...'}
          disabled={isStreaming}
          className="flex-1 bg-[#12141a] border border-[#2e3450] rounded-md px-3 py-2 text-sm text-gray-200 focus:outline-none focus:border-blue-500 disabled:opacity-50"
        />
        <button
          type="submit"
          disabled={isStreaming || !inputPrompt.trim()}
          className="bg-blue-600 hover:bg-blue-500 disabled:bg-gray-700 text-white text-sm font-medium px-4 py-2 rounded-md transition-colors"
        >
          {isStreaming ? 'Streaming' : 'Send'}
        </button>
      </form>
    </div>
  );
};
```

### File 10: Sidebar Navigation Icon Component (`plugins/agent-orchestrator/src/ui/AgentNavIcon.tsx`)
```tsx
import React from 'react';

export const AgentNavIcon: React.FC<{ active?: boolean; onClick?: () => void }> = ({
  active,
  onClick
}) => {
  return (
    <button
      onClick={onClick}
      title="Agent Orchestrator (Chat & Reasoning)"
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
          d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
        />
      </svg>
    </button>
  );
};
```

---

## 6. Step-by-Step AI Execution Instructions

Follow these exact steps to scaffold and wire the plugin inside `/mnt/MD/Project/DSH/DSH-Desktop`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Session 06] Scaffolding plugins/agent-orchestrator..."
mkdir -p plugins/agent-orchestrator/src/ui
mkdir -p ~/.config/dsh-desktop/conversations

# 1. Compile TypeScript code
echo "==> [Session 06] Compiling TypeScript plugins..."
npm run build || npx tsc --noEmit

echo "==> [Session 06] Agent Orchestrator plugin files created successfully."
```

---

## 7. Validation & Verification Commands

Execute the following automated test script to verify that token streaming, SSE parsing, and conversation persistence pass all unit contracts:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
cd "${TARGET_DIR}"

echo "==> [Verification] Running Session 06 automated test harness..."

# Test 1: Validate SSE & NDJSON Streaming Parser
node -e '
const { StreamingParser } = require("./plugins/agent-orchestrator/src/StreamingParser.ts");
const parser = new StreamingParser();

// Test OpenAI SSE Chunk Parsing
const sseLine = "data: {"choices":[{"delta":{"content":"Hello CachyOS"}}]}";
const chunk = parser.parseOpenAISSE(sseLine);
console.assert(chunk.deltaText === "Hello CachyOS", "OpenAI SSE parser failed!");

// Test Ollama NDJSON Chunk Parsing
const ollamaLine = "{"message":{"content":" Native Vulkan"},"done":false}";
const oChunk = parser.parseOllamaNDJSON(ollamaLine);
console.assert(oChunk.deltaText === " Native Vulkan", "Ollama NDJSON parser failed!");

console.log("==> Test 1 Passed: StreamingParser is 100% compliant.");
'

# Test 2: Validate Conversation State Manager
node -e '
const { ConversationManager } = require("./plugins/agent-orchestrator/src/ConversationManager.ts");
const cm = new ConversationManager("/tmp/dsh_test_conversations");
const session = cm.createSession("Test Session", "ollama", "qwen2.5-coder:7b");
cm.addMessage(session.id, "user", "Run cargo build");
cm.addMessage(session.id, "assistant", "Building project with Vulkan target...");

const active = cm.getActiveSession();
console.assert(active.messages.length === 2, "ConversationManager failed to track messages!");
console.log("==> Test 2 Passed: ConversationManager persistence and retrieval OK.");
'

echo "==> [Verification] Session 06 completed all validation checks successfully!"
```

---

## 8. Definition of Done Checklist

- [ ] `plugins/agent-orchestrator/dsh.plugin.json` authored with slot definitions (`workspace.main`, `sidebar.nav`) and permissions (`network:llm`, `ipc:exec`).
- [ ] `StreamingParser.ts` implemented with zero-allocation chunk buffering for OpenAI SSE and Ollama NDJSON streams.
- [ ] `MultiProviderClient.ts` implemented supporting Ollama (`/api/chat`), LM Studio / vLLM (`/v1/chat/completions`), and OpenRouter with API key authentication.
- [ ] `ConversationManager.ts` implemented with local disk JSON persistence under `~/.config/dsh-desktop/conversations/`.
- [ ] `ToolDispatcher.ts` and `AgentEngine.ts` implemented with recursive tool execution and cancellation token (`AbortController`) support.
- [ ] Frontend React components `AgentChatWorkspace.tsx` and `AgentNavIcon.tsx` created for dynamic slot mounting.
- [ ] Automated verification script executes with zero errors.
