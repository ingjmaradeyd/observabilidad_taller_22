import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '2m',

  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: [
      'p(95)<1000',
      'p(99)<1500',
    ],
  },
};

const url =
  'http://otel-fargate-lab-lab-alb-1195356616.us-east-1.elb.amazonaws.com/service-a/pedidos/crear';

export default function () {
  const payload = JSON.stringify({
    id_cliente: 1,
    producto: 'BENCHMARK-OTEL',
    cantidad: 1,
    valor: 100000,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Idempotency-Key': `performance-${__VU}-${__ITER}`,
    },
  };

  const response = http.post(url, payload, params);

  check(response, {
    'status 200': (r) => r.status === 200,
  });

  sleep(0.2);
}
