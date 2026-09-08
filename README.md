# AI Support Agent with Amazon Bedrock AgentCore

Udacity **Future AWS Agent Engineer** (nd905), project cd14763. Submitted and passed.

An e-commerce customer support agent built on Amazon Bedrock AgentCore and the
Strands SDK, combining six capabilities in one conversational interface:

- **Order tracking and refunds** through AgentCore Gateway over MCP, hitting both
  an API Gateway target and a Lambda target
- **Grounded answers** via Retrieval Augmented Generation over a Bedrock
  Knowledge Base
- **Cross-session memory** with AgentCore Memory, retrieving customer context
  before each response and persisting each completed turn
- **Exact arithmetic** for loyalty discounts in the AgentCore Code Interpreter
  sandbox
- **Live web browsing** through the AgentCore Browser tool

## Layout

| Path | What it is |
|---|---|
| `submission/main.py` | the deliverable: all 8 TODO sections implemented |
| `submission/lambda/` | provided Lambda handlers, deployed unmodified |
| `submission/REFLECTION.md` | the written reflection |
| `infra/` | Terraform for the whole stack, so teardown is one command |

## Infrastructure

The classroom describes console clicks; `infra/` builds the same resources as
code: both Lambdas, the REST API with three named operations, the AgentCore
Gateway with an API Gateway target and a Lambda target, the Knowledge Base on
OpenSearch Serverless, and AgentCore Memory with two strategies.

`infra/create_vector_index.py` creates the OpenSearch vector index that a Bedrock
Knowledge Base requires before it can be created via API.

## Notes

This repository holds the source only. Test transcripts and screenshots were part
of the Udacity submission and are not published here.

Config values in `main.py` point at resources that have since been destroyed. No
account IDs or credentials are present.
