import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  vus: 1,
  duration: '30s',

  thresholds: {
    http_req_duration: ['p(99)<500'],
    errors: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.API_URL || 'https://api.cloudnative.dev';

export default function () {

  const liveness = http.get(`${BASE_URL}/healthz`);

  check(liveness, {
    'liveness 200': (r) => r.status === 200,
    'liveness fast': (r) => r.timings.duration < 200,
  });

  const readiness = http.get(`${BASE_URL}/readyz`);

  check(readiness, {
    'readiness 200': (r) => r.status === 200,
    'database connected': (r) =>
      JSON.parse(r.body).database === 'connected',
  });

  const products = http.get(`${BASE_URL}/api/v1/products`);

  check(products, {
    'products 200': (r) => r.status === 200,
    'products fast': (r) => r.timings.duration < 300,
  });

  errorRate.add(
    liveness.status !== 200 || readiness.status !== 200
  );

  sleep(1);
}