data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "gateway_assume" {
  statement {
    sid     = "GatewayAssumeRolePolicy"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${var.region}:${data.aws_caller_identity.current.account_id}:gateway/*"]
    }
  }
}

data "aws_iam_policy_document" "gateway_inline" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.refund_processor.arn]
  }
  statement {
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.order_api.execution_arn}/*"]
  }
}

resource "aws_iam_role" "gateway" {
  name               = "cd14763-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.gateway_assume.json
}

resource "aws_iam_role_policy" "gateway_targets" {
  name   = "gateway-targets"
  role   = aws_iam_role.gateway.id
  policy = data.aws_iam_policy_document.gateway_inline.json
}

resource "aws_bedrockagentcore_gateway" "support" {
  name            = "CustomerSupportGateway"
  role_arn        = aws_iam_role.gateway.arn
  protocol_type   = "MCP"
  authorizer_type = "NONE"
}

resource "aws_bedrockagentcore_gateway_target" "order_tracker" {
  gateway_identifier = aws_bedrockagentcore_gateway.support.gateway_id
  name               = "order-tracker"

  target_configuration {
    mcp {
      api_gateway {
        rest_api_id = aws_api_gateway_rest_api.order_api.id
        stage       = aws_api_gateway_stage.prod.stage_name

        api_gateway_tool_configuration {
          tool_filter {
            filter_path = "/orders/{order_id}"
            methods     = ["GET"]
          }
          tool_filter {
            filter_path = "/customers/{customer_id}/orders"
            methods     = ["GET"]
          }
          tool_filter {
            filter_path = "/customers/{customer_id}"
            methods     = ["GET"]
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}

resource "aws_bedrockagentcore_gateway_target" "refund_processor" {
  gateway_identifier = aws_bedrockagentcore_gateway.support.gateway_id
  name               = "refund-processor"

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.refund_processor.arn

        tool_schema {
          inline_payload {
            name        = "initiate_refund"
            description = "Initiate a refund for a customer order."
            input_schema {
              type = "object"
              property {
                name        = "order_id"
                type        = "string"
                description = "Order ID to refund"
                required    = true
              }
              property {
                name        = "reason"
                type        = "string"
                description = "Reason for refund"
                required    = true
              }
              property {
                name        = "amount"
                type        = "number"
                description = "Refund amount in USD"
                required    = false
              }
            }
          }

          inline_payload {
            name        = "check_refund_status"
            description = "Check the status of an existing refund."
            input_schema {
              type = "object"
              property {
                name        = "refund_id"
                type        = "string"
                description = "Refund ID to check"
                required    = true
              }
            }
          }

          inline_payload {
            name        = "get_return_label"
            description = "Generate a prepaid return shipping label for an order."
            input_schema {
              type = "object"
              property {
                name        = "order_id"
                type        = "string"
                description = "Order ID needing a label"
                required    = true
              }
            }
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.support.gateway_url
}
