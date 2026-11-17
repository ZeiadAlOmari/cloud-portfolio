"""SQS consumer - store each message and update per-source counters in one transaction.

Fixes from the Project 8 review:
- partial batch responses (ReportBatchItemFailures): only failed messages are retried, then reach the DLQ (F-45);
  previously failures were counted and the whole batch was reported as successful, so messages were lost
- idempotent writes: a redelivered message is not stored or counted twice
- counters live in a small stats table, so /stats no longer scans the data table (F-48)
"""
import json
import logging
import os
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ddb = boto3.client("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
STATS_TABLE_NAME = os.environ["STATS_TABLE_NAME"]
TOTAL_KEY = "__total__"


def _store(message):
    """Write the record and bump its counters atomically. Returns False if it was already stored."""
    now = datetime.now(timezone.utc).isoformat()
    counter_update = {
        "UpdateExpression": "ADD record_count :one",
        "ExpressionAttributeValues": {":one": {"N": "1"}},
    }
    try:
        ddb.transact_write_items(TransactItems=[
            {"Put": {
                "TableName": TABLE_NAME,
                "Item": {
                    "id": {"S": message["id"]},
                    "data": {"S": json.dumps(message["data"])},
                    "source": {"S": message["source"]},
                    "timestamp": {"S": message["timestamp"]},
                    "processed_at": {"S": now},
                    "status": {"S": "processed"},
                },
                "ConditionExpression": "attribute_not_exists(id)",
            }},
            {"Update": {"TableName": STATS_TABLE_NAME, "Key": {"source": {"S": message["source"]}}, **counter_update}},
            {"Update": {"TableName": STATS_TABLE_NAME, "Key": {"source": {"S": TOTAL_KEY}}, **counter_update}},
        ])
        return True
    except ddb.exceptions.TransactionCanceledException as e:
        reasons = [r.get("Code") for r in e.response.get("CancellationReasons", [])]
        if reasons and reasons[0] == "ConditionalCheckFailed":
            return False  # duplicate delivery: already stored and counted
        raise


def handler(event, context):
    failures = []
    stored = duplicates = 0
    for record in event.get("Records", []):
        try:
            message = json.loads(record["body"])
            for field in ("id", "data", "source", "timestamp"):
                if field not in message:
                    raise ValueError(f"missing field {field}")
            if _store(message):
                stored += 1
            else:
                duplicates += 1
        except Exception:
            logger.exception("failed to process SQS message %s", record.get("messageId"))
            failures.append({"itemIdentifier": record["messageId"]})

    logger.info("stored=%d duplicates=%d failed=%d", stored, duplicates, len(failures))
    return {"batchItemFailures": failures}
