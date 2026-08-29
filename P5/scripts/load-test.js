import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 50 }, // Ramp-up to 50 users
        { duration: '1m', target: 100 }, // Ramp-up to 100 users (should trigger HPA)
        { duration: '30s', target: 0 },  // Ramp-down to 0 users
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
        http_req_failed: ['rate<0.01'],   // Error rate should be less than 1%
    }
};

export default function () {
    // Apuntamos al servicio interno de Kubernetes
    let res = http.get('http://sa-platform-api-gateway/api/transactions/upload');

    check(res, {
        'status was 200 or 404 (expected if empty)': (r) => r.status === 200 || r.status === 404,
    });

    sleep(1);
}
