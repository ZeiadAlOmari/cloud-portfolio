"""Unit tests for the P10 Lambda functions against moto's in-memory SQS and DynamoDB."""
import importlib.util
import json
import os
import pathlib

import boto3
import pytest
from moto import mock_aws

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"


def load(name):
    spec = importlib.util.spec_from_file_location(f"fn_{name}", SRC / name / "lambda_function.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def aws():
    os.environ.update(AWS_DEFAULT_REGION="us-east-1", AWS_ACCESS_KEY_ID="testing", AWS_SECRET_ACCESS_KEY="testing")
    with mock_aws():
        sqs = boto3.client("sqs")
        url = sqs.create_queue(QueueName="q")["QueueUrl"]
        ddb = boto3.client("dynamodb")
        for t, k in (("data", "id"), ("stats", "source")):
            ddb.create_table(TableName=t, BillingMode="PAY_PER_REQUEST",
                             KeySchema=[{"AttributeName": k, "KeyType": "HASH"}],
                             AttributeDefinitions=[{"AttributeName": k, "AttributeType": "S"}])
        os.environ.update(QUEUE_URL=url, TABLE_NAME="data", STATS_TABLE_NAME="stats")
        yield {"sqs": sqs, "url": url}


def sqs_event(sqs, url):
    msgs = sqs.receive_message(QueueUrl=url, MaxNumberOfMessages=10).get("Messages", [])
    return {"Records": [{"messageId": m["MessageId"], "body": m["Body"]} for m in msgs]}


def test_ingest_rejects_bad_input(aws):
    ingest = load("ingest")
    assert ingest.handler({"body": "{not json"}, None)["statusCode"] == 400
    assert ingest.handler({"body": "[1,2]"}, None)["statusCode"] == 400
    assert ingest.handler({"body": json.dumps({"x": 1})}, None)["statusCode"] == 400
    assert ingest.handler({"body": json.dumps({"data": 1, "source": ""})}, None)["statusCode"] == 400
    assert ingest.handler({"body": "x" * 20000}, None)["statusCode"] == 413
    r = ingest.handler({"body": "{not json"}, None)
    assert "Expecting" not in r["body"]  # no internal error text leaked


def test_end_to_end_and_stats(aws):
    ingest, process, query = load("ingest"), load("process"), load("query")
    for src in ("sensor-a", "sensor-a", "sensor-b"):
        r = ingest.handler({"body": json.dumps({"data": {"t": 21}, "source": src})}, None)
        assert r["statusCode"] == 202
    out = process.handler(sqs_event(aws["sqs"], aws["url"]), None)
    assert out == {"batchItemFailures": []}
    stats = json.loads(query.handler({"routeKey": "GET /stats"}, None)["body"])
    assert stats == {"total_records": 3, "by_source": {"sensor-a": 2, "sensor-b": 1}}
    listed = json.loads(query.handler({"routeKey": "GET /data", "queryStringParameters": {"limit": "2"}}, None)["body"])
    assert listed["count"] == 2
    rid = listed["items"][0]["id"]
    one = query.handler({"routeKey": "GET /data/{id}", "pathParameters": {"id": rid}}, None)
    assert one["statusCode"] == 200
    assert query.handler({"routeKey": "GET /data/{id}", "pathParameters": {"id": "nope"}}, None)["statusCode"] == 404


def test_duplicate_delivery_is_idempotent(aws):
    process, query = load("process"), load("query")
    body = json.dumps({"id": "fixed-1", "data": {}, "source": "s", "timestamp": "2026-01-01T00:00:00+00:00"})
    event = {"Records": [{"messageId": "m1", "body": body}]}
    assert process.handler(event, None) == {"batchItemFailures": []}
    assert process.handler(event, None) == {"batchItemFailures": []}  # redelivery
    stats = json.loads(query.handler({"routeKey": "GET /stats"}, None)["body"])
    assert stats["total_records"] == 1


def test_partial_batch_failure_reported(aws):
    process = load("process")
    good = json.dumps({"id": "ok-1", "data": {}, "source": "s", "timestamp": "t"})
    event = {"Records": [{"messageId": "good", "body": good},
                         {"messageId": "bad-json", "body": "{oops"},
                         {"messageId": "missing", "body": json.dumps({"id": "x"})}]}
    out = process.handler(event, None)
    assert sorted(f["itemIdentifier"] for f in out["batchItemFailures"]) == ["bad-json", "missing"]


def test_query_validates_limit_and_route(aws):
    query = load("query")
    for bad in ("abc", "0", "101", "-5"):
        r = query.handler({"routeKey": "GET /data", "queryStringParameters": {"limit": bad}}, None)
        assert r["statusCode"] == 400, bad
    assert query.handler({"routeKey": "DELETE /data"}, None)["statusCode"] == 404
    assert json.loads(query.handler({"routeKey": "GET /stats"}, None)["body"]) == {"total_records": 0, "by_source": {}}
