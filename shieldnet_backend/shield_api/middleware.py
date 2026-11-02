import uuid
import json
import logging
import contextvars
from django.core.cache import cache
from django.http import HttpResponse, JsonResponse
from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger('shieldnet.middleware')

# Context variable to hold the correlation ID per async/sync execution thread
_correlation_id_ctx = contextvars.ContextVar('correlation_id', default='-')


def get_current_correlation_id():
    """Returns the current request's correlation ID or '-'."""
    return _correlation_id_ctx.get()


class CorrelationIdLogFilter(logging.Filter):
    """
    Logging filter that injects the current request correlation ID into log records.
    """
    def filter(self, record):
        record.request_id = get_current_correlation_id()
        return True


class CorrelationIdMiddleware(MiddlewareMixin):
    """
    Enterprise-Grade Distributed Tracing Middleware (CWE-778).
    Attaches an X-Request-ID to every incoming request, propagates it across
    backend logs, and returns it in the HTTP response headers.
    """

    def process_request(self, request):
        request_id = request.headers.get('X-Request-ID') or request.headers.get('X-Correlation-ID')
        if not request_id or len(request_id) > 64:
            request_id = str(uuid.uuid4())
        
        request.correlation_id = request_id
        _correlation_id_ctx.set(request_id)

    def process_response(self, request, response):
        corr_id = getattr(request, 'correlation_id', None) or get_current_correlation_id()
        if corr_id and corr_id != '-':
            response['X-Request-ID'] = corr_id
            response['X-Correlation-ID'] = corr_id
        return response


class IdempotencyMiddleware(MiddlewareMixin):
    """
    Idempotency Middleware compliant with RFC 9421 / IETF Idempotency-Key spec.
    Prevents duplicate mutations (e.g. duplicate scam reports or blacklist entries)
    during network retries from mobile clients over unstable 4G/5G connections.
    """

    IDEMPOTENCY_HEADER = 'HTTP_IDEMPOTENCY_KEY'
    IDEMPOTENCY_HEADER_ALT = 'HTTP_X_IDEMPOTENCY_KEY'
    CACHE_PREFIX = 'idempotency:'
    CACHE_TIMEOUT_SECONDS = 86400  # 24 hours retention

    def process_request(self, request):
        if request.method not in ('POST', 'PUT', 'PATCH'):
            return None

        idempotency_key = (
            request.META.get(self.IDEMPOTENCY_HEADER) or 
            request.META.get(self.IDEMPOTENCY_HEADER_ALT)
        )
        if not idempotency_key:
            return None

        # Sanitize key length to avoid cache key exhaustion
        idempotency_key = idempotency_key.strip()
        if len(idempotency_key) > 128:
            return None

        request._idempotency_key = idempotency_key
        cache_key = f"{self.CACHE_PREFIX}{idempotency_key}"

        cached_entry = cache.get(cache_key)
        if cached_entry:
            logger.info(
                f"[IDEMPOTENCY] Cache HIT for key {idempotency_key} on {request.path}"
            )
            response = HttpResponse(
                content=cached_entry.get('content', b''),
                status=cached_entry.get('status', 200),
                content_type=cached_entry.get('content_type', 'application/json'),
            )
            response['X-Cache-Lookup'] = 'HIT'
            response['Idempotent-Replay'] = 'true'
            for header, value in cached_entry.get('headers', {}).items():
                response[header] = value
            return response

        return None

    def process_response(self, request, response):
        idempotency_key = getattr(request, '_idempotency_key', None)
        if not idempotency_key:
            return response

        # Only cache successful or client-side responses (2xx or 4xx idempotent results, never 5xx)
        if 200 <= response.status_code < 500:
            cache_key = f"{self.CACHE_PREFIX}{idempotency_key}"
            
            # Avoid re-caching if this response was itself a replay
            if response.get('Idempotent-Replay') != 'true':
                cached_data = {
                    'status': response.status_code,
                    'content': response.content,
                    'content_type': response.get('Content-Type', 'application/json'),
                    'headers': {
                        'Content-Type': response.get('Content-Type', 'application/json'),
                    }
                }
                cache.set(cache_key, cached_data, timeout=self.CACHE_TIMEOUT_SECONDS)
                response['X-Cache-Lookup'] = 'MISS'
                response['Idempotent-Saved'] = 'true'

        return response
