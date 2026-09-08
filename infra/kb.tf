resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "catalog" {
  bucket        = "cd14763-product-catalog-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_object" "catalog" {
  bucket = aws_s3_bucket.catalog.id
  key    = "product_catalog.txt"
  source = "${path.module}/../cd14763-project-starter/starter/product_catalog.txt"
  etag   = filemd5("${path.module}/../cd14763-project-starter/starter/product_catalog.txt")
}

locals {
  collection_name = "cd14763-kb-${random_id.suffix.hex}"
  vector_index    = "bedrock-knowledge-base-default-index"
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = local.collection_name
  type = "encryption"
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${local.collection_name}"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = local.collection_name
  type = "network"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${local.collection_name}"]
      },
    ]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_access_policy" "data" {
  name = local.collection_name
  type = "data"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${local.collection_name}/*"]
        Permission   = ["aoss:*"]
      },
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
        Permission   = ["aoss:*"]
      },
    ]
    Principal = [
      aws_iam_role.kb.arn,
      data.aws_caller_identity.current.arn,
    ]
  }])
}

resource "aws_opensearchserverless_collection" "kb" {
  name = local.collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]
}

data "aws_iam_policy_document" "kb_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "kb_inline" {
  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"]
  }
  statement {
    actions   = ["aoss:APIAccessAll"]
    resources = [aws_opensearchserverless_collection.kb.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.catalog.arn, "${aws_s3_bucket.catalog.arn}/*"]
  }
}

resource "aws_iam_role" "kb" {
  name               = "cd14763-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume.json
}

resource "aws_iam_role_policy" "kb" {
  name   = "kb-access"
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_inline.json
}

output "collection_endpoint" {
  value = aws_opensearchserverless_collection.kb.collection_endpoint
}

output "collection_name" {
  value = local.collection_name
}

output "vector_index_name" {
  value = local.vector_index
}

output "catalog_bucket" {
  value = aws_s3_bucket.catalog.id
}

output "kb_role_arn" {
  value = aws_iam_role.kb.arn
}

resource "aws_bedrockagent_knowledge_base" "support" {
  name     = "CustomerSupportKB"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb.arn
      vector_index_name = local.vector_index

      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "catalog" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.support.id
  name              = "product-catalog"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.catalog.arn
    }
  }
}

output "kb_id" {
  value = aws_bedrockagent_knowledge_base.support.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.catalog.data_source_id
}
