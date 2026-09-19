import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,
  duration: '10s',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01']
  }
};

export default function() {
  let res = http.get(__ENV.TARGET_URL + '/health');
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(1);
}
