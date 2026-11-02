import json
from django.test import TestCase, RequestFactory
from django.http import HttpResponse, JsonResponse
from django.core.cache import cache
from shield_api.middleware import CorrelationIdMiddleware, IdempotencyMiddleware, get_current_correlation_id


class EnterpriseMiddlewareTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        cache.clear()

    def test_correlation_id_generated_when_absent(self):
        middleware = CorrelationIdMiddleware(lambda req: HttpResponse(b"OK"))
        request = self.factory.get('/api/v1/health/')
        
        response = middleware(request)
        
        self.assertIn('X-Request-ID', response)
        self.assertTrue(len(response['X-Request-ID']) > 10)
        self.assertEqual(response['X-Request-ID'], response['X-Correlation-ID'])

    def test_correlation_id_propagated_when_present(self):
        custom_id = "req-custom-trace-uuid-1234"
        middleware = CorrelationIdMiddleware(lambda req: HttpResponse(b"OK"))
        request = self.factory.get('/api/v1/health/', HTTP_X_REQUEST_ID=custom_id)
        
        response = middleware(request)
        
        self.assertEqual(response['X-Request-ID'], custom_id)
        self.assertEqual(request.correlation_id, custom_id)

    def test_idempotency_middleware_caches_and_replays_post(self):
        call_count = {'count': 0}
        
        def fake_view(req):
            call_count['count'] += 1
            return JsonResponse({'message': 'Created', 'iteration': call_count['count']}, status=201)

        middleware = IdempotencyMiddleware(fake_view)
        key = "idemp-key-unique-98765"

        # Première requête : calcul effectif
        request1 = self.factory.post(
            '/api/v1/reports/',
            data=json.dumps({'phone_number': '+15145550199'}),
            content_type='application/json',
            HTTP_IDEMPOTENCY_KEY=key
        )
        response1 = middleware(request1)
        self.assertEqual(response1.status_code, 201)
        self.assertEqual(call_count['count'], 1)
        self.assertEqual(response1.get('X-Cache-Lookup'), 'MISS')

        # Deuxième requête : rejeu idempotent sans réexécuter la vue
        request2 = self.factory.post(
            '/api/v1/reports/',
            data=json.dumps({'phone_number': '+15145550199'}),
            content_type='application/json',
            HTTP_IDEMPOTENCY_KEY=key
        )
        response2 = middleware(request2)
        self.assertEqual(response2.status_code, 201)
        self.assertEqual(call_count['count'], 1)  # La vue n'a PAS été réexécutée
        self.assertEqual(response2.get('X-Cache-Lookup'), 'HIT')
        self.assertEqual(response2.get('Idempotent-Replay'), 'true')

    def test_idempotency_ignored_on_get(self):
        middleware = IdempotencyMiddleware(lambda req: HttpResponse(b"GET result"))
        request = self.factory.get('/api/v1/threats/regional/', HTTP_IDEMPOTENCY_KEY="key-get")
        
        response = middleware(request)
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.get('Idempotent-Replay'))
