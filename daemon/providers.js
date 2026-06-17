"use strict";
// ---------------------------------------------------------------------------
// Per-agent model/provider routing — the office's "swappable brain".
//
// The agent runtime is ALWAYS the Claude Code CLI (`claude -p`): it owns the
// tools, the agentic loop, skills, sessions. Only the *model behind it* changes.
// `claude` is just a client — point ANTHROPIC_BASE_URL at another endpoint and it
// talks to that backend instead, authenticated with ANTHROPIC_AUTH_TOKEN. So
// switching an agent to GLM/Qwen/DeepSeek/MiniMax is purely env + --model.
//
//   • Anthropic-format providers (direct: true)  → ANTHROPIC_BASE_URL straight at
//     their Anthropic-compatible endpoint. No proxy.
//   • OpenAI-format providers   (needsProxy: true) → ANTHROPIC_BASE_URL at a local
//     LiteLLM gateway that translates Anthropic <-> OpenAI (wired in P3).
//
// FAIL-OPEN: an unconfigured, unknown, or "claude" provider returns empty
// overrides, so the spawn is byte-identical to today's plain-Claude behavior.
// (A *configured* provider with a bad token will fail that run — same as a bad
// Claude key today; we do not silently re-route to Claude.)
// ---------------------------------------------------------------------------

// Catalog. `baseUrl` filled only where the endpoint is confirmed; the rest are
// supplied via reg.providerConfig[id].baseUrl (verified per-provider in P2).
// `models` is a hint list for the settings UI — any string is accepted.
const PROVIDERS = {
  claude: {
    label: "Claude · Anthropic", format: "anthropic", direct: true, baseUrl: null,
    models: ["", "opus", "sonnet", "haiku",
             "claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"],
  },
  glm: {
    label: "GLM · Z.AI", format: "anthropic", direct: true,
    baseUrl: "https://api.z.ai/api/anthropic",          // confirmed (Z.AI docs)
    modelsUrl: "https://api.z.ai/api/paas/v4/models",   // OpenAI-compatible model list
    models: ["glm-4.6", "glm-4.5"],                     // hint only — live list is fetched on Connect
  },
  deepseek: {
    label: "DeepSeek", format: "anthropic", direct: true,
    baseUrl: "https://api.deepseek.com/anthropic",        // confirmed (DeepSeek docs)
    modelsUrl: "https://api.deepseek.com/models",
    models: ["deepseek-v4-pro", "deepseek-v4-flash"],     // chat/reasoner deprecated 2026-07-24
  },
  qwen: {
    label: "Qwen · Alibaba", format: "anthropic", direct: true,
    // confirmed (Alibaba Model Studio docs). International endpoint; mainland-China
    // is https://dashscope.aliyuncs.com/apps/anthropic — set reg.providerConfig.qwen.baseUrl.
    baseUrl: "https://dashscope-intl.aliyuncs.com/apps/anthropic",
    modelsUrl: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models",
    models: ["qwen3-coder-plus", "qwen3-coder-next", "qwen3-coder-flash"],
  },
  minimax: {
    label: "MiniMax", format: "anthropic", direct: true,
    // confirmed (MiniMax docs). International endpoint; mainland-China is
    // https://api.minimaxi.com/anthropic (extra "i") — set reg.providerConfig.minimax.baseUrl.
    baseUrl: "https://api.minimax.io/anthropic",
    models: ["MiniMax-M3"],
  },
  moonshot: {
    label: "Kimi · Moonshot", format: "anthropic", direct: true,
    // confirmed (Moonshot docs). International endpoint; mainland-China is
    // https://api.moonshot.cn/anthropic — set reg.providerConfig.moonshot.baseUrl.
    baseUrl: "https://api.moonshot.ai/anthropic",
    modelsUrl: "https://api.moonshot.ai/v1/models",
    models: ["kimi-k2.5", "kimi-k2", "kimi-latest"],
  },
  openai: {
    label: "OpenAI", format: "openai", needsProxy: true, baseUrl: null,
    models: ["gpt-4o", "gpt-4o-mini"],
  },
  gemini: {
    label: "Gemini", format: "openai", needsProxy: true, baseUrl: null,
    models: ["gemini-2.5-flash", "gemini-2.5-pro"],
  },
  openrouter: {
    label: "OpenRouter", format: "openai", needsProxy: true, baseUrl: null,
    models: ["openai/gpt-4o", "anthropic/claude-sonnet-4-6", "deepseek/deepseek-chat"],
  },
  nvidia: {
    label: "NVIDIA build", format: "openai", needsProxy: true, baseUrl: null,
    models: ["meta/llama-3.3-70b-instruct", "deepseek-ai/deepseek-v3"],
  },
};

const DEFAULT_LITELLM = "http://127.0.0.1:4000";

// resolve(provider, model, reg) -> { ok, env, modelArgs, reason }
//   env       : object spread into the child's env (ANTHROPIC_BASE_URL/_AUTH_TOKEN)
//   modelArgs : [] or ["--model", "<id>"] pushed into the claude argv
//   reg.providerConfig = {
//     glm:      { token, baseUrl?, model? },
//     deepseek: { token, baseUrl?, model? },
//     litellm:  { baseUrl?, token? },          // for openai/gemini
//     ...
//   }
function resolve(provider, model, reg = {}, opts = {}) {
  const out = { ok: true, env: {}, modelArgs: [], reason: "claude-default" };
  const pConf = (reg && reg.providerConfig) || {};

  // Default brain: plain Claude. Optional explicit model only.
  if (!provider || provider === "claude") {
    if (model) out.modelArgs = ["--model", String(model)];
    return out;
  }

  const spec = PROVIDERS[provider];
  const pc = pConf[provider] || {};
  // "anthropic" (claude talks straight to the endpoint) or "openai" (via the
  // built-in proxy). Built-ins read it from the catalog; CUSTOM providers store
  // their kind/baseUrl/token in providerConfig[id].
  const kind = spec ? spec.format : pc.kind;
  if (!kind) return { ok: false, env: {}, modelArgs: [], reason: "unknown-provider" };

  let baseUrl, token;
  if (kind === "openai") {
    // Needs translation. openai/gemini may use an explicit LiteLLM gateway; everyone
    // else (openrouter/nvidia/custom) uses the daemon's built-in proxy, which resolves
    // the real upstream + key from providerConfig (proxy.js → upstreamFor).
    const builtinPair = provider === "openai" || provider === "gemini";
    const lc = pConf.litellm;
    const liteUrl = builtinPair && ((lc && lc.baseUrl) || reg.litellmUrl);
    if (liteUrl) {
      baseUrl = liteUrl;
      token = (lc && lc.token) || pc.token || "litellm";
    } else if (opts.proxyBase) {
      const mainKey = provider === "openai" ? (reg.apiKeys || {}).OPENAI_API_KEY
                    : provider === "gemini" ? (reg.apiKeys || {}).GEMINI_API_KEY : null;
      if (!pc.token && !mainKey) {
        return { ok: false, env: {}, modelArgs: [], reason: "key-not-set" };
      }
      baseUrl = `${opts.proxyBase}/proxy/${provider}`;
      token = "office";   // the proxy injects the real key; this value is ignored
    } else {
      return { ok: false, env: {}, modelArgs: [], reason: "no-proxy-available" };
    }
  } else {
    // anthropic-kind: direct.
    baseUrl = pc.baseUrl || (spec && spec.baseUrl);
    token = pc.token;
    if (!baseUrl || !token) {
      return { ok: false, env: {}, modelArgs: [], reason: "not-configured" };
    }
  }

  out.env = { ANTHROPIC_BASE_URL: baseUrl, ANTHROPIC_AUTH_TOKEN: token };
  let m = pc.model || model;
  if (!m && kind === "openai") {
    m = provider === "openai" ? "gpt-4o-mini" : provider === "gemini" ? "gemini-2.5-flash" : "";
  }
  if (m) out.modelArgs = ["--model", String(m)];
  out.reason = provider;
  return out;
}

module.exports = { PROVIDERS, DEFAULT_LITELLM, resolve };
