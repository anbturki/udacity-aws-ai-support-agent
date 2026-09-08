variable "runtime_role_name" {
  type        = string
  description = "Execution role auto-created by `agentcore configure`."
  default     = ""
}

data "aws_iam_policy_document" "runtime_extra" {
  statement {
    sid = "AgentCoreMemory"
    actions = [
      "bedrock-agentcore:GetMemory",
      "bedrock-agentcore:ListMemories",
      "bedrock-agentcore:CreateEvent",
      "bedrock-agentcore:ListEvents",
      "bedrock-agentcore:RetrieveMemoryRecords",
      "bedrock-agentcore:ListMemoryRecords",
      "bedrock-agentcore:GetMemoryRecord",
    ]
    resources = [
      aws_bedrockagentcore_memory.support.arn,
      "${aws_bedrockagentcore_memory.support.arn}/*",
    ]
  }

  statement {
    sid = "CodeInterpreterAndBrowser"
    actions = [
      "bedrock-agentcore:StartCodeInterpreterSession",
      "bedrock-agentcore:InvokeCodeInterpreter",
      "bedrock-agentcore:StopCodeInterpreterSession",
      "bedrock-agentcore:GetCodeInterpreterSession",
      "bedrock-agentcore:ListCodeInterpreterSessions",
      "bedrock-agentcore:StartBrowserSession",
      "bedrock-agentcore:StopBrowserSession",
      "bedrock-agentcore:GetBrowserSession",
      "bedrock-agentcore:ListBrowserSessions",
      "bedrock-agentcore:ConnectBrowserAutomationStream",
      "bedrock-agentcore:ConnectBrowserLiveViewStream",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "runtime_extra" {
  count = var.runtime_role_name == "" ? 0 : 1

  name   = "cd14763-runtime-extra"
  role   = var.runtime_role_name
  policy = data.aws_iam_policy_document.runtime_extra.json
}
