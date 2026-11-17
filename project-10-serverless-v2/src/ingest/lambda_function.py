"""POST /ingest - validate the request and queue it for processing.

Fixes from the Project 8 review: input is validated (400 instead of 500 on bad JSON),
internal errors are logged rather than returned to the caller, and timestamps are timezone-aware.
"""
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]
MAX_BODY_BYTES = 10 * 1024
SOURCE_MAX_LEN = 50


def _response(status, body):
    return {"statusCode": status, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}


def handler(event, context):
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        return _response(400, {"error": "body must be JSON text"})
    if len(raw.encode("utf-8")) > MAX_BODY_BYTES:
        return _response(413, {"error": f"body larger than {MAX_BODY_BYTES} bytes"})
    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        return _response(400, {"error": "body is not valid JSON"})
    if not isinstance(body, dict) or "data" not in body:
        return _response(400, {"error": "body must be a JSON object with a 'data' field"})

    source = body.get("source", "api")
    if not isinstance(source, str) or not source.strip() or len(source) > SOURCE_MAX_LEN:
        return _response(400, {"error": f"'source' must be a non-empty string up to {SOURCE_MAX_LEN} characters"})

    message = {
        "id": str(uuid.uuid4()),
        "data": body["data"],
        "source": source.strip(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    try:
        sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(message))
    except Exception:
        logger.exception("failed to queue message %s", message["id"])
        return _response(500, {"error": "internal error"})

    logger.info("queued message %s from source %s", message["id"], message["source"])
    return _response(202, {"status": "accepted", "message_id": message["id"], "timestamp": message["timestamp"]})
