const test = require("node:test");
const assert = require("node:assert");
const { toOpenAI, toAnthropic, pickModel, UPSTREAM } = require("../proxy");

test("toOpenAI: system + user text → system + user messages", () => {
  const o = toOpenAI({ system: "You are X", messages: [{ role: "user", content: "hi" }] }, "gpt-4o");
  assert.strictEqual(o.model, "gpt-4o");
  assert.deepStrictEqual(o.messages[0], { role: "system", content: "You are X" });
  assert.deepStrictEqual(o.messages[1], { role: "user", content: "hi" });
});

test("toOpenAI: array system blocks join into one system message", () => {
  const o = toOpenAI({ system: [{ type: "text", text: "A" }, { type: "text", text: "B" }], messages: [] }, "m");
  assert.strictEqual(o.messages[0].content, "A\nB");
});

test("toOpenAI: assistant tool_use → tool_calls; user tool_result → tool message", () => {
  const o = toOpenAI({ messages: [
    { role: "assistant", content: [{ type: "text", text: "let me check" },
      { type: "tool_use", id: "tu1", name: "get", input: { q: 1 } }] },
    { role: "user", content: [{ type: "tool_result", tool_use_id: "tu1", content: "42" }] },
  ] }, "m");
  const am = o.messages[0];
  assert.strictEqual(am.role, "assistant");
  assert.strictEqual(am.content, "let me check");
  assert.strictEqual(am.tool_calls[0].id, "tu1");
  assert.strictEqual(am.tool_calls[0].function.name, "get");
  assert.strictEqual(am.tool_calls[0].function.arguments, JSON.stringify({ q: 1 }));
  const tm = o.messages[1];
  assert.strictEqual(tm.role, "tool");
  assert.strictEqual(tm.tool_call_id, "tu1");
  assert.strictEqual(tm.content, "42");
});

test("toOpenAI: tools + tool_choice translate to OpenAI function shape", () => {
  const schema = { type: "object", properties: { q: { type: "string" } }, required: ["q"] };
  const o = toOpenAI({ messages: [{ role: "user", content: "x" }],
    tools: [{ name: "search", description: "d", input_schema: schema }],
    tool_choice: { type: "any" } }, "m");
  assert.strictEqual(o.tools[0].type, "function");
  assert.strictEqual(o.tools[0].function.name, "search");
  assert.deepStrictEqual(o.tools[0].function.parameters, schema);
  assert.strictEqual(o.tool_choice, "required");
});

test("toOpenAI: stream adds include_usage", () => {
  const o = toOpenAI({ stream: true, messages: [] }, "m");
  assert.strictEqual(o.stream, true);
  assert.deepStrictEqual(o.stream_options, { include_usage: true });
});

test("toAnthropic: text response → message with end_turn", () => {
  const a = toAnthropic({ id: "x", choices: [{ message: { content: "hello" }, finish_reason: "stop" }],
    usage: { prompt_tokens: 10, completion_tokens: 3 } }, "gpt-4o");
  assert.strictEqual(a.type, "message");
  assert.strictEqual(a.role, "assistant");
  assert.deepStrictEqual(a.content[0], { type: "text", text: "hello" });
  assert.strictEqual(a.stop_reason, "end_turn");
  assert.strictEqual(a.usage.input_tokens, 10);
  assert.strictEqual(a.usage.output_tokens, 3);
});

test("toAnthropic: tool_calls → tool_use blocks + stop_reason tool_use", () => {
  const a = toAnthropic({ choices: [{ message: { content: null,
    tool_calls: [{ id: "c1", function: { name: "get", arguments: '{"q":2}' } }] }, finish_reason: "tool_calls" }] }, "m");
  const tu = a.content.find((b) => b.type === "tool_use");
  assert.strictEqual(tu.id, "c1");
  assert.strictEqual(tu.name, "get");
  assert.deepStrictEqual(tu.input, { q: 2 });
  assert.strictEqual(a.stop_reason, "tool_use");
});

test("pickModel: claude-* and blank fall back; real model passes through", () => {
  assert.strictEqual(pickModel("claude-sonnet-4-6", UPSTREAM.openai), "gpt-4o-mini");
  assert.strictEqual(pickModel("", UPSTREAM.gemini), "gemini-2.5-flash");
  assert.strictEqual(pickModel("gpt-4o", UPSTREAM.openai), "gpt-4o");
});
