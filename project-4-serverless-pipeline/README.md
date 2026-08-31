# Serverless Data Pipeline

A fully serverless, event-driven data pipeline built on AWS and provisioned entirely with Terraform. Ingests data through an API, processes it asynchronously via SQS, stores it in DynamoDB, and exposes it through a query API.

## Architecture

    Client
      |
      v
    API Gateway (HTTP API)
      |
      +-- POST /ingest --> Lambda (ingest) --> SQS Queue --> Lambda (process) --> DynamoDB
      |                                              |                                |
      |                                              v                                |
      |                                       SQS Dead-Letter Queue                   |
      |                                       (after 3 failed attempts)               |
      |                                                                               v
      +-- GET /data <----------------------------------------------------- Lambda (query)
      +-- GET /data/{id}
      +-- GET /stats

## API Endpoints

| Method | Endpoint     | Description                    |
|--------|--------------|---------------------------------|
| POST   | /ingest      | Submit data                    |
| GET    | /data        | List all records                |
| GET    | /data/{id}   | Get a single record by ID       |
| GET    | /stats       | Summary statistics by source    |

### Example: Ingest data

    curl -X POST https://<api-url>/ingest \
      -H "Content-Type: application/json" \
      -d '{"data": {"temperature": 25.5, "humidity": 60}, "source": "sensor-1"}'

Response:

    {
      "status": "accepted",
      "message_id": "c69f29d0-4e15-45cc-9149-aa12d3c26bea",
      "timestamp": "2026-08-31T15:09:40.923580"
    }

### Example: Query a record

    curl https://<api-url>/data/c69f29d0-4e15-45cc-9149-aa12d3c26bea

Response:

    {
      "id": "c69f29d0-4e15-45cc-9149-aa12d3c26bea",
      "source": "sensor-1",
      "data": "{\"temperature\": 25.5, \"humidity\": 60}",
      "status": "processed",
      "timestamp": "2026-08-31T15:09:40.923580",
      "processed_at": "2026-08-31T15:09:42.026509"
    }

## Tech Stack

- Terraform - Infrastructure as Code, sole owner of all resources below
- API Gateway - HTTP API (v2) for routing
- AWS Lambda - Python 3.12, three functions (ingest, process, query)
- Amazon SQS - Async message queue with a dead-letter queue
- Amazon DynamoDB - NoSQL storage, on-demand capacity

## Project Structure

    project-4-serverless-pipeline/
      terraform/
        providers.tf       - AWS provider configuration
        lambda.tf          - Lambda functions + IAM role/policy
        api_gateway.tf     - HTTP API, routes, integrations
        storage.tf         - DynamoDB table, SQS queues + redrive policy
        outputs.tf         - API endpoint, function names, queue URL
      lambda/
        ingest/lambda_function.py   - Receives data, sends to SQS
        process/lambda_function.py  - Reads from SQS, writes to DynamoDB
        query/lambda_function.py    - Reads from DynamoDB, returns via API
      docs/
      diagrams/

## Design Decisions

**Why SQS between ingest and process?**
Decoupling the ingest endpoint from database writes means the API responds instantly. If the process function fails, messages retry automatically (up to 3 times) before moving to the dead-letter queue. No data is lost.

**Why a dead-letter queue?**
Failed messages do not disappear silently. They land in the DLQ for inspection and manual replay.

**Why DynamoDB on-demand?**
No capacity planning needed. Scales from zero to thousands of requests per second with no provisioning.

**Why HTTP API over REST API?**
Lower latency, lower cost, and simpler configuration for this use case.

**Why Terraform over AWS SAM/CloudFormation?**
Terraform is cloud-agnostic - the same workflow (init / plan / apply / destroy) applies whether the target is AWS, Azure, or GCP. Standardizing on it here keeps infrastructure automation consistent across every project in this portfolio.

## Deployment

### Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.9

### Deploy

    cd terraform
    terraform init
    terraform plan
    terraform apply

### Tear down

    cd terraform
    terraform destroy

## What I Learned

- Designing event-driven architectures with async processing via SQS
- Managing infrastructure as code with Terraform, including reading and resolving state drift
- Debugging Lambda permissions (resource policies for API Gateway invocation)
- Configuring SQS visibility timeouts relative to Lambda execution time
- Why resource naming collisions matter when two IaC tools target the same account/region, and how to resolve them safely
