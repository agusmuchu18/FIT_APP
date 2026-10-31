import assert from 'node:assert/strict';
import test from 'node:test';
import {buildUpstreamUrl, createHandler, isAllowedOrigin} from '../src/index.js';

test('only permits FIT_APP and local origins', () => {
  assert.equal(isAllowedOrigin('https://agusmuchu18.github.io'), true);
  assert.equal(isAllowedOrigin('http://localhost:5173'), true);
  assert.equal(isAllowedOrigin('https://attacker.example'), false);
});

test('builds a bounded USDA URL without accepting an injected key', () => {
  const params = new URLSearchParams({
    operation: 'search', query: 'apple', pageSize: '999', pageNumber: '999', api_key: 'attacker',
  });
  const {url} = buildUpstreamUrl(params, 'server-secret');
  assert.equal(url.searchParams.get('pageSize'), '25');
  assert.equal(url.searchParams.get('pageNumber'), '20');
  assert.equal(url.searchParams.get('api_key'), 'server-secret');
});

test('returns safe errors and does not expose the USDA key', async () => {
  const handler = createHandler(async () => new Response('private provider body', {status: 500}));
  const response = await handler(
    new Request('https://worker.example/?operation=search&query=apple', {
      headers: {Origin: 'https://agusmuchu18.github.io', 'CF-Connecting-IP': '127.0.0.1'},
    }),
    {USDA_API_KEY: 'server-secret', RATE_LIMITER: {limit: async () => ({success: true})}},
    {waitUntil() {}},
  );
  const body = await response.text();
  assert.equal(response.status, 502);
  assert.equal(body.includes('server-secret'), false);
  assert.equal(body.includes('private provider body'), false);
});

test('retries a failed USDA search without the optional data type filter', async () => {
  const requestedUrls = [];
  const handler = createHandler(async (url) => {
    requestedUrls.push(url);
    if (requestedUrls.length === 1) return new Response('upstream failure', {status: 500});
    return new Response(JSON.stringify({foods: [{fdcId: 1}]}), {
      status: 200,
      headers: {'Content-Type': 'application/json'},
    });
  });
  const response = await handler(
    new Request('https://worker.example/?operation=search&query=apple', {
      headers: {Origin: 'https://agusmuchu18.github.io', 'CF-Connecting-IP': '127.0.0.1'},
    }),
    {USDA_API_KEY: 'server-secret', RATE_LIMITER: {limit: async () => ({success: true})}},
    {waitUntil() {}},
  );

  assert.equal(response.status, 200);
  assert.equal(requestedUrls.length, 2);
  assert.equal(requestedUrls[0].searchParams.has('dataType'), true);
  assert.equal(requestedUrls[1].searchParams.has('dataType'), false);
});

test('details preserve portions, labels and reported Atwater energy without client overrides', () => {
  const {url} = buildUpstreamUrl(new URLSearchParams({operation:'detail',fdcId:'123',format:'abridged',nutrients:'208'}),'server-secret');
  assert.equal(url.searchParams.get('format'),'full');
  const nutrients = url.searchParams.get('nutrients').split(',');
  for (const number of ['957','958','401','328','203']) assert.ok(nutrients.includes(number));
  assert.ok(nutrients.length<=25);
});
