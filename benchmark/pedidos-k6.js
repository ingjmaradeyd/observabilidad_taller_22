import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '60s', target: 30 },
    { duration: '60s', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
};

const baseUrl = __ENV.BASE_URL || 'http://localhost:8000';

export default function () {
  const payload = JSON.stringify({
    id_cliente: Number(__ENV.CLIENTE_ID || 1),
    producto: 'Benchmark-OTel',
    cantidad: 1,
    valor: 1000
  });

  const res = http.post(`${baseUrl}/pedidos/crear`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(res, {
    'pedido creado': (r) => r.status === 200,
  });
}
