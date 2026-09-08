# Reflection

## A design decision: fetching memory namespaces instead of hardcoding them

`MemoryHook` does not carry the namespace strings `cs_agent/{actorId}/facts` and
`cs_agent/{actorId}/preferences` anywhere in the agent code. Its constructor calls
`get_namespaces()`, which reads `get_memory_strategies()` off the live memory resource and
maps each strategy type to its namespace template. Retrieval then loops over whatever that
returns, formats `{actorId}` with the caller's `customer_id`, and tags each hit with the
strategy type it came from.

I chose this because the namespace template is a property of the memory resource, not of the
agent. If someone adds a third strategy in the console, the hook picks it up with no code
change and no redeploy. Hardcoding the two strings would have been shorter and would have
worked in testing, but it puts the same fact in two places that can drift apart silently. The
helper also reads `namespaceTemplates` and falls back to the legacy `namespaces` field, so it
survives the API field rename.

## A challenge: the runtime role could not reach its own dependencies

The first `agentcore invoke` after deployment failed with `AccessDeniedException` on
`bedrock-agentcore:GetMemory`. The execution role that `agentcore configure` auto-creates
covers the runtime itself, not the services my agent calls out to.

I read the failing action out of the error rather than guessing, then worked out that the same
gap applied to three more integrations that had not been reached yet: `bedrock:Retrieve` for
the Knowledge Base, the Code Interpreter session actions, and the Browser session actions. I
attached one policy covering all four, scoped the Knowledge Base and Memory statements to
those specific resource ARNs, and re-ran. All six test scenarios then passed on the first
attempt, which confirmed the diagnosis was the whole problem and not one symptom of it.

## A production consideration: the vector store bills whether or not anyone asks a question

Every other component here is priced per use. Lambda, API Gateway, and Bedrock model
invocations all cost nothing while the agent is idle. The OpenSearch Serverless collection
backing `CustomerSupportKB` is different: it bills on provisioned capacity, so a support agent
answering ten questions a day and one answering ten thousand cost nearly the same to keep
running.

For a real deployment that changes the sizing question from "how many queries" to "how many
knowledge bases", and it makes an idle non-production environment a genuine line item. I would
share one collection across environments rather than give each its own, and put a budget alarm
on it, because the failure mode is not an outage that someone reports. It is a bill that
nobody looks at.
