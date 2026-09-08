data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "cd14763-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "order_tracker" {
  type        = "zip"
  source_file = "${local.lambda_src}/order_tracker.py"
  output_path = "${path.module}/.build/order_tracker.zip"
}

data "archive_file" "refund_processor" {
  type        = "zip"
  source_file = "${local.lambda_src}/refund_processor.py"
  output_path = "${path.module}/.build/refund_processor.zip"
}

resource "aws_lambda_function" "order_tracker" {
  function_name    = "order-tracker"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "order_tracker.lambda_handler"
  filename         = data.archive_file.order_tracker.output_path
  source_code_hash = data.archive_file.order_tracker.output_base64sha256
  timeout          = 30
}

resource "aws_lambda_function" "refund_processor" {
  function_name    = "refund-processor"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "refund_processor.lambda_handler"
  filename         = data.archive_file.refund_processor.output_path
  source_code_hash = data.archive_file.refund_processor.output_base64sha256
  timeout          = 30
}

output "order_tracker_arn" {
  value = aws_lambda_function.order_tracker.arn
}

output "refund_processor_arn" {
  value = aws_lambda_function.refund_processor.arn
}
