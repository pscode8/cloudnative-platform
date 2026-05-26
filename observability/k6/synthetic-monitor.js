import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate   = new Rate('errors');
const apiLatency  = new Trend('api_latency', true);

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_duration: ['p99<500'],
    errors:            ['rate<0.01'],
    api_latency:       ['p95<300'],
  },
};

const BASE_URL = __ENV.API_URL || 'https://api.cloudnative.dev';

export default function () {
  group('Health checks', () => {
    const liveness = http.get(`${BASE_URL}/healthz`);
    check(liveness, {
      'liveness 200':    (r) => r.status === 200,
      'liveness fast':   (r) => r.timings.duration < 200,
      'liveness body ok':(r) => JSON.parse(r.body).status === 'ok',
    });
    errorRate.add(liveness.status !== 200);

    const readiness = http.get(`${BASE_URL}/readyz`);
    check(readiness, {
      'readiness 200':      (r) => r.status === 200,
      'database connected': (r) => JSON.parse(r.body).database === 'connected',
    });
    errorRate.add(readiness.status !== 200);
  });

  group('API endpoints', () => {
    const products = http.get(`${BASE_URL}/api/v1/products`);
    check(products, {
      'products 200':  (r) => r.status === 200,
      'products array':(r) => Array.isArray(JSON.parse(r.body)),
      'products fast': (r) => r.timings.duration < 300,
    });
    apiLatency.add(products.timings.duration);
    errorRate.add(products.status !== 200);
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'observability/k6/last-run-summary.json': JSON.stringify(data, null, 2),
  };
}
