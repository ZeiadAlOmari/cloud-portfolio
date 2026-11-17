#!/usr/bin/env python3
"""Call the P10 HTTP API with or without a SigV4 signature.

Usage:
  call_api.py <api-endpoint> <METHOD> <path> [json-body] [--unsigned] [--role <client-role-arn>]

Signed calls use the default AWS credential chain, or assume --role first (the p10-api-client role).
Requires botocore (available in the Checkov virtual environment: ~/.venvs/checkov/bin/python).
"""
import json
import sys
import urllib.error
import urllib.request

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

REGION = "us-east-1"


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    unsigned = "--unsigned" in argv
    role = argv[argv.index("--role") + 1] if "--role" in argv else None
    if role in args:
        args.remove(role)
    if len(args) < 3:
        sys.exit(__doc__)
    endpoint, method, path = args[0].rstrip("/"), args[1].upper(), args[2]
    body = args[3] if len(args) > 3 else None
    url = f"{endpoint}{path}"
    headers = {"Content-Type": "application/json"} if body else {}

    if not unsigned:
        session = boto3.Session(region_name=REGION)
        if role:
            creds = session.client("sts").assume_role(RoleArn=role, RoleSessionName="p10-api-test")["Credentials"]
            session = boto3.Session(aws_access_key_id=creds["AccessKeyId"], aws_secret_access_key=creds["SecretAccessKey"],
                                    aws_session_token=creds["SessionToken"], region_name=REGION)
        request = AWSRequest(method=method, url=url, data=body, headers=headers)
        SigV4Auth(session.get_credentials().get_frozen_credentials(), "execute-api", REGION).add_auth(request)
        headers = dict(request.headers.items())

    req = urllib.request.Request(url, data=body.encode() if body else None, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            status, text = resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode()
    except urllib.error.URLError as e:
        sys.exit(f"could not reach {url}: {e.reason}")
    print(f"{method} {path} -> {status} {'(unsigned)' if unsigned else '(signed' + (' as client role)' if role else ')')}")
    try:
        print(json.dumps(json.loads(text), indent=2))
    except ValueError:
        print(text)


if __name__ == "__main__":
    main(sys.argv[1:])
