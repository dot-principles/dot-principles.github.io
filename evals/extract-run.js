// extract-run.js <stream.jsonl> <outdir>
// Reads the output of `claude -p --output-format stream-json` and writes, into <outdir>:
//   result.txt  the final answer
//   tools.txt   one line per tool call (shows what the agent read, e.g. review.md)
//   meta.txt    tokens, output_tokens, seconds, cost, turns, is_error as key=value lines
const fs = require("fs");

const [, , file, out] = process.argv;
if (!file || !out) {
  console.error("usage: node extract-run.js <stream.jsonl> <outdir>");
  process.exit(2);
}

const events = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).flatMap(line => {
  try { return [JSON.parse(line)]; } catch { return []; }
});
const result = events.find(e => e.type === "result") || {};

const calls = [];
for (const e of events) {
  if (e.type !== "assistant") continue;
  for (const c of (e.message && e.message.content) || []) {
    if (c.type === "tool_use") calls.push(c.name + " " + JSON.stringify(c.input).slice(0, 200));
  }
}

const u = result.usage || {};
const tokens = (u.input_tokens || 0) + (u.output_tokens || 0)
  + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);

fs.writeFileSync(out + "/result.txt", result.result || "");
fs.writeFileSync(out + "/tools.txt", calls.join("\n") + "\n");
fs.writeFileSync(out + "/meta.txt", [
  `tokens=${tokens}`,
  `output_tokens=${u.output_tokens || 0}`,
  `seconds=${Math.round((result.duration_ms || 0) / 1000)}`,
  `cost=${result.total_cost_usd || 0}`,
  `turns=${result.num_turns || 0}`,
  `is_error=${result.is_error === undefined ? "unknown" : result.is_error}`,
].join("\n") + "\n");
