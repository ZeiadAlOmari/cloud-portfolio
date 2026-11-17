"""GET /data, GET /data/{id}, GET /stats.

Fixes from the Project 8 review: /stats reads the small stats table instead of scanning every record (F-48);
'limit' is validated and capped; routing uses API Gateway's route key and path parameters;
internal errors are logged rather than returned to the caller.
"""
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])
stats_table = dynamodb.Table(os.environ["STATS_TABLE_NAME"])
TOTAL_KEY = "__total__"
DEFAULT_LIMIT, MAX_LIMIT = 20, 100


def _response(status, body):
    return {"statusCode": status, "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body, default=str)}


def _list(params):
    raw = params.get("limit", str(DEFAULT_LIMIT))
    if not raw.isdigit() or not 1 <= int(raw) <= MAX_LIMIT:
        return _response(400, {"error": f"'limit' must be a whole number from 1 to {MAX_LIMIT}"})
    items = table.scan(Limit=int(raw)).get("Items", [])
    return _response(200, {"count": len(items), "items": items})


def _get(record_id):
    if not record_id or len(record_id) > 64:
        return _response(400, {"error": "invalid id"})
    item = table.get_item(Key={"id": record_id}).get("Item")
    return _response(200, item) if item else _response(404, {"error": "record not found"})


def _stats():
    rows = stats_table.scan().get("Items", [])  # one row per source plus a total: small and bounded
    counts = {r["source"]: int(r.get("record_count", 0)) for r in rows}
    total = counts.pop(TOTAL_KEY, 0)
    return _response(200, {"total_records": total, "by_source": counts})


def handler(event, context):
    route = event.get("routeKey", "")
    try:
        if route == "GET /data":
            return _list(event.get("queryStringParameters") or {})
        if route == "GET /data/{id}":
            return _get((event.get("pathParameters") or {}).get("id", ""))
        if route == "GET /stats":
            return _stats()
        return _response(404, {"error": "unknown route"})
    except Exception:
        logger.exception("query failed for route %s", route)
        return _response(500, {"error": "internal error"})
