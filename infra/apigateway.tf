resource "aws_api_gateway_rest_api" "order_api" {
  name = "cd14763-order-api"
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_resource" "order_id" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{order_id}"
}

resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "customers"
}

resource "aws_api_gateway_resource" "customer_id" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_resource.customers.id
  path_part   = "{customer_id}"
}

resource "aws_api_gateway_resource" "customer_orders" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_resource.customer_id.id
  path_part   = "orders"
}

locals {
  order_operations = {
    get_order = {
      resource_id = aws_api_gateway_resource.order_id.id
      path_param  = "order_id"
    }
    get_customer_orders = {
      resource_id = aws_api_gateway_resource.customer_orders.id
      path_param  = "customer_id"
    }
    get_customer = {
      resource_id = aws_api_gateway_resource.customer_id.id
      path_param  = "customer_id"
    }
  }
}

resource "aws_api_gateway_method" "get" {
  for_each = local.order_operations

  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = each.value.resource_id
  http_method   = "GET"
  authorization = "NONE"
  operation_name = each.key

  request_parameters = {
    "method.request.path.${each.value.path_param}" = true
  }
}

resource "aws_api_gateway_integration" "get" {
  for_each = local.order_operations

  rest_api_id             = aws_api_gateway_rest_api.order_api.id
  resource_id             = each.value.resource_id
  http_method             = aws_api_gateway_method.get[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.order_tracker.invoke_arn
}

resource "aws_api_gateway_method_response" "ok" {
  for_each = local.order_operations

  rest_api_id = aws_api_gateway_rest_api.order_api.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.get[each.key].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_tracker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.order_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "order_api" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_method.get,
      aws_api_gateway_integration.get,
      aws_api_gateway_method_response.ok,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  deployment_id = aws_api_gateway_deployment.order_api.id
  stage_name    = "prod"
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.order_api.id
}

output "rest_api_stage" {
  value = aws_api_gateway_stage.prod.stage_name
}

output "rest_api_invoke_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}
