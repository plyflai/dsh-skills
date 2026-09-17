import { test } from 'node:test'
import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const script = fileURLToPath(new URL('../scripts/parse-toolcall.mjs', import.meta.url))

async function run(stdin) {
  const child = execFile(process.execPath, [script])
  child.stdin.end(stdin)
  let stdout = ''
  let stderr = ''
  child.stdout.on('data', (chunk) => { stdout += chunk })
  child.stderr.on('data', (chunk) => { stderr += chunk })
  const code = await new Promise((resolve, reject) => {
    child.on('close', resolve)
    child.on('error', reject)
  })
  if (code !== 0) throw new Error(`parse-toolcall exited ${code}: ${stderr}`)
  return JSON.parse(stdout)
}

test('plain text without tool_call returns null', async () => {
  assert.equal(await run('just some normal text'), null)
})

test('empty input returns null', async () => {
  assert.equal(await run(''), null)
})

test('block without function name returns null', async () => {
  const input = '<tool_call>\n<parameter=foo>\nbar\n</parameter>\n</tool_call>'
  assert.equal(await run(input), null)
})

test('full block parses name and trimmed parameters', async () => {
  const input = [
    '<tool_call>',
    '<function=auto_dev_delivery_route>',
    '<parameter=architecture_boundary>',
    'False',
    '</parameter>',
    '<parameter=target>',
    '  some path  ',
    '</parameter>',
    '</function>',
    '</tool_call>',
  ].join('\n')
  const result = await run(input)
  assert.equal(result.name, 'auto_dev_delivery_route')
  assert.deepEqual(result.parameters, { architecture_boundary: 'False', target: 'some path' })
  assert.ok(result.raw.includes('<tool_call>'))
})

test('last block wins when repeated', async () => {
  const input = [
    '<tool_call><function=first><parameter=k>1</parameter></function></tool_call>',
    'text between',
    '<tool_call><function=second><parameter=k>2</parameter></function></tool_call>',
  ].join('\n')
  const result = await run(input)
  assert.equal(result.name, 'second')
  assert.deepEqual(result.parameters, { k: '2' })
})

test('unclosed block still yields function name', async () => {
  const input = '<tool_call>\n<function=open_call>\n<parameter=k>\nv\n</parameter>'
  const result = await run(input)
  assert.equal(result.name, 'open_call')
  assert.deepEqual(result.parameters, { k: 'v' })
})

test('multiline and unicode values are preserved', async () => {
  const input = '<tool_call><function=note><parameter=msg>\n第一行\n第二行\n</parameter></function></tool_call>'
  const result = await run(input)
  assert.equal(result.parameters.msg, '第一行\n第二行')
})

test('unknown tags inside block are ignored', async () => {
  const input = '<tool_call><thinking>x</thinking><function=ok><parameter=k>1</parameter></function></tool_call>'
  const result = await run(input)
  assert.equal(result.name, 'ok')
  assert.deepEqual(result.parameters, { k: '1' })
})
