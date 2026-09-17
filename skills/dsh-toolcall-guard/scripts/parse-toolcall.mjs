#!/usr/bin/env node
/**
 * parse-toolcall — deterministic extractor for the pseudo-XML `<tool_call>`
 * text blocks some models emit instead of native function calls.
 *
 * CLI: reads all of stdin, prints JSON to stdout:
 *   {"name":"...","parameters":{...},"raw":"..."}  — or —  null
 *
 * Rules (single source of truth: references/parsing-rules.md):
 * - last `<tool_call>` block in the text wins;
 * - function name from `<function=NAME>`; no match → null;
 * - `<parameter=KEY>...</parameter>` pairs, values trimmed, order preserved;
 * - unknown tags inside the block are ignored.
 */

function extractToolCall(text) {
  if (typeof text !== 'string' || text.length === 0) return null
  const start = text.lastIndexOf('<tool_call>')
  if (start === -1) return null
  const close = text.indexOf('</tool_call>', start)
  const raw = close === -1 ? text.slice(start) : text.slice(start, close + '</tool_call>'.length)

  const fnMatch = raw.match(/<function=([A-Za-z0-9_.\-]+)>/)
  if (fnMatch === null) return null
  const name = fnMatch[1]

  const parameters = {}
  const paramPattern = /<parameter=([A-Za-z0-9_.\-]+)>([\s\S]*?)<\/parameter>/g
  let match = null
  while ((match = paramPattern.exec(raw)) !== null) {
    parameters[match[1]] = match[2].trim()
  }
  return { name, parameters, raw }
}

const input = await new Promise((resolve) => {
  let data = ''
  process.stdin.setEncoding('utf8')
  process.stdin.on('data', (chunk) => { data += chunk })
  process.stdin.on('end', () => resolve(data))
})

process.stdout.write(`${JSON.stringify(extractToolCall(input))}\n`)
