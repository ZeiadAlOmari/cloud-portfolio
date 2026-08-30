import json
import boto3
import os

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    try:
        path = event.get("rawPath", event.get("path", ""))
        params = event.get("queryStringParameters", {}) or {}

        # GET /data — list all records
        if path == "/data" or path.endswith("/data"):
            limit = int(params.get("limit", 20))
            response = table.scan(Limit=limit)
            items = response.get("Items", [])

            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "count": len(items),
                    "items": items
                }, default=str)
            }

        # GET /data/{id} — get single record
        elif "/data/" in path:
            record_id = path.split("/data/")[-1]
            response = table.get_item(Key={"id": record_id})
            item = response.get("Item")

            if item:
                return {
                    "statusCode": 200,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps(item, default=str)
                }
            else:
                return {
                    "statusCode": 404,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": "Record not found"})
                }

        # GET /stats — summary statistics
        elif path == "/stats" or path.endswith("/stats"):
            response = table.scan()
            items = response.get("Items", [])

            sources = {}
            for item in items:
                src = item.get("source", "unknown")
                sources[src] = sources.get(src, 0) + 1

            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "total_records": len(items),
                    "by_source": sources
                })
            }

        else:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Unknown endpoint"})
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }
