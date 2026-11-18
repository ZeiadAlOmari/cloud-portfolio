import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    processed = 0
    errors = 0

    for record in event.get("Records", []):
        try:
            message = json.loads(record["body"])

            item = {
                "id": message["id"],
                "data": json.dumps(message["data"]),
                "source": message["source"],
                "timestamp": message["timestamp"],
                "processed_at": datetime.utcnow().isoformat(),
                "status": "processed"
            }

            table.put_item(Item=item)
            processed += 1

        except Exception as e:
            print(f"Error processing record: {str(e)}")
            errors += 1

    return {
        "statusCode": 200,
        "processed": processed,
        "errors": errors
    }
