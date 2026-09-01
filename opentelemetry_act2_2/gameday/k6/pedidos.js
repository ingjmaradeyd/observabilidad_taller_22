import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL || 'http://service-a:8000';
const testMode = __ENV.TEST_MODE || 'baseline';
const endpoint = `${baseUrl}/service-a/pedidos/crear`;
const metricTags = {
  experiment: 'latency-a-to-b',
  test_mode: testMode,
};

export const options = {
  vus: 20,
  duration: '2m',
  thresholds: {
    checks: ['rate>0.99'],
    http_req_failed: ['rate<0.01'],
    http_req_duration: [
      'p(95)<1000',
      'p(99)<1500',
    ],
  },
};

export default function () {
  const payload = JSON.stringify({
    id_cliente: 1,
    producto: 'GAMEDAY-LATENCY',
    cantidad: 1,
    valor: 100000,
  });

  const response = http.post(endpoint, payload, {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: metricTags,
  });

  check(
    response,
    {
      'status is 200': (result) => result.status === 200,
    },
    metricTags,
  );

  sleep(0.2);
}
