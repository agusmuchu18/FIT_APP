const USDA_BASE = 'https://api.nal.usda.gov/fdc/v1';
const MAX_RESPONSE_BYTES = 2_000_000;

export function isAllowedOrigin(origin) {
  if (!origin) return false;
  return origin === 'https://agusmuchu18.github.io' ||
    origin === 'https://fit-app-63796.web.app' ||
    origin === 'https://fit-app-63796.firebaseapp.com' ||
    /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

export function buildUpstreamUrl(searchParams, apiKey) {
  const operation = searchParams.get('operation') || '';
  if (operation === 'search') {
    const term = (searchParams.get('query') || '').trim();
    if (term.length < 2 || term.length > 100) throw new Error('invalid_query');
    const pageSize = Math.min(Math.max(Number(searchParams.get('pageSize')) || 25, 1), 25);
    const pageNumber = Math.min(Math.max(Number(searchParams.get('pageNumber')) || 1, 1), 20);
    const url = new URL(`${USDA_BASE}/foods/search`);
    url.search = new URLSearchParams({
      api_key: apiKey,
      query: term,
      pageSize: String(pageSize),
      pageNumber: String(pageNumber),
      dataType: 'Foundation,SR Legacy,Branded,Survey (FNDDS)',
    });
    return {url, cacheSeconds: 300};
  }
  if (operation === 'detail') {
    const fdcId = Number(searchParams.get('fdcId'));
    if (!Number.isSafeInteger(fdcId) || fdcId <= 0) throw new Error('invalid_id');
    const url = new URL(`${USDA_BASE}/food/${fdcId}`);
    url.search = new URLSearchParams({
      api_key: apiKey,
      format: 'full',
      nutrients: '208,957,958,203,204,205,291,269,606,645,646,307,601,306,301,303,304,401,328',
    });
    return {url, cacheSeconds: 86400};
  }
  throw new Error('invalid_operation');
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  };
}

function jsonResponse(origin, status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {'Content-Type': 'application/json', ...corsHeaders(origin)},
  });
}

export function createHandler(fetchImpl = fetch) {
  return async function handle(request, env, ctx) {
    const origin = request.headers.get('Origin') || '';
    if (!isAllowedOrigin(origin)) return jsonResponse('', 403, {error: 'origin_not_allowed'});
    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: corsHeaders(origin)});
    if (request.method !== 'GET') return jsonResponse(origin, 405, {error: 'method_not_allowed'});
    if (!env.USDA_API_KEY) return jsonResponse(origin, 503, {error: 'service_not_configured'});

    const clientIp = request.headers.get('CF-Connecting-IP') || 'unknown';
    if (env.RATE_LIMITER) {
      const {success} = await env.RATE_LIMITER.limit({key: clientIp});
      if (!success) return jsonResponse(origin, 429, {error: 'rate_limit_exceeded'});
    }

    let target;
    try {
      target = buildUpstreamUrl(new URL(request.url).searchParams, env.USDA_API_KEY);
    } catch (_) {
      return jsonResponse(origin, 400, {error: 'invalid_request'});
    }

    const cache = globalThis.caches?.default;
    const cacheKey = new Request(`${request.url}&nutritionSchema=2&allowedOrigin=${encodeURIComponent(origin)}`);
    const cached = cache ? await cache.match(cacheKey) : null;
    if (cached) return cached;

    try {
      let upstream = await fetchImpl(target.url, {signal: AbortSignal.timeout(12_000)});
      // FoodData Central occasionally returns a 5xx for otherwise valid searches
      // when its combined dataType filter is present. Retry once without that
      // optional filter so a provider-side indexing issue does not break search.
      if (!upstream.ok && upstream.status >= 500 &&
          target.url.pathname.endsWith('/foods/search') &&
          target.url.searchParams.has('dataType')) {
        const fallbackUrl = new URL(target.url);
        fallbackUrl.searchParams.delete('dataType');
        upstream = await fetchImpl(fallbackUrl, {signal: AbortSignal.timeout(12_000)});
      }
      if (!upstream.ok) {
        const status = upstream.status === 429 ? 429 : 502;
        return jsonResponse(origin, status, {error: status === 429 ? 'provider_rate_limit' : 'provider_error'});
      }
      const text = await upstream.text();
      if (new TextEncoder().encode(text).byteLength > MAX_RESPONSE_BYTES) {
        return jsonResponse(origin, 502, {error: 'provider_response_too_large'});
      }
      JSON.parse(text);
      const response = new Response(text, {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': `public, max-age=${target.cacheSeconds}`,
          ...corsHeaders(origin),
        },
      });
      if (cache) ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    } catch (_) {
      return jsonResponse(origin, 504, {error: 'provider_timeout'});
    }
  };
}

const handle = createHandler();

export default {
  fetch(request, env, ctx) {
    return handle(request, env, ctx);
  },
};
