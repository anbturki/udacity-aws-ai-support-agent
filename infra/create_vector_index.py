"""Create the Bedrock Knowledge Base vector index in an OpenSearch Serverless collection."""
import hashlib
import json
import sys
import urllib.request

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

TITAN_V2_DIMENSION = 1024

endpoint, index_name, region = sys.argv[1], sys.argv[2], sys.argv[3]

body = json.dumps({
    "settings": {"index": {"knn": True}},
    "mappings": {
        "properties": {
            "bedrock-knowledge-base-default-vector": {
                "type": "knn_vector",
                "dimension": TITAN_V2_DIMENSION,
                "method": {
                    "name": "hnsw",
                    "engine": "faiss",
                    "space_type": "l2",
                    "parameters": {"ef_construction": 512, "m": 16},
                },
            },
            "AMAZON_BEDROCK_TEXT_CHUNK": {"type": "text", "index": True},
            "AMAZON_BEDROCK_METADATA": {"type": "text", "index": False},
        }
    },
}).encode()

url = f"{endpoint}/{index_name}"
request = AWSRequest(method="PUT", url=url, data=body, headers={
    "Content-Type": "application/json",
    "x-amz-content-sha256": hashlib.sha256(body).hexdigest(),
})
SigV4Auth(boto3.Session().get_credentials(), "aoss", region).add_auth(request)

try:
    with urllib.request.urlopen(
        urllib.request.Request(url, data=body, headers=dict(request.headers), method="PUT")
    ) as resp:
        print(resp.status, resp.read().decode())
except urllib.error.HTTPError as err:
    detail = err.read().decode()
    if "resource_already_exists_exception" in detail:
        print("index already exists")
    else:
        print(err.code, detail)
        raise
