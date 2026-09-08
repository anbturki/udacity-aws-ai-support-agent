resource "aws_bedrockagentcore_memory" "support" {
  name                  = "CustomerSupportMemory"
  event_expiry_duration = 30
}

resource "aws_bedrockagentcore_memory_strategy" "customer_facts" {
  memory_id           = aws_bedrockagentcore_memory.support.id
  name                = "customer_facts"
  type                = "SEMANTIC"
  namespace_templates = ["cs_agent/{actorId}/facts"]
}

resource "aws_bedrockagentcore_memory_strategy" "customer_preferences" {
  memory_id           = aws_bedrockagentcore_memory.support.id
  name                = "customer_preferences"
  type                = "USER_PREFERENCE"
  namespace_templates = ["cs_agent/{actorId}/preferences"]

  depends_on = [aws_bedrockagentcore_memory_strategy.customer_facts]
}

output "memory_id" {
  value = aws_bedrockagentcore_memory.support.id
}
