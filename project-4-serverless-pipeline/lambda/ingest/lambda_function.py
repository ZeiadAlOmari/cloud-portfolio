import json
import boto3
import os
import uuid
from datetime import datetime

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]

def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        message = {
            "id": str(uuid.uuid4()),
            "data": body.get("data", {}),
            "source": body.get("source", "api"),
            "timestamp": datetime.utcnow().isoformat()
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message)
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "status": "accepted",
                "message_id": message["id"],
                "timestamp": message["timestamp"]
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }
