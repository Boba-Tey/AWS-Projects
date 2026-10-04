terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {}
data "aws_region" "current" {}

# Verification Bucket
resource "aws_s3_bucket" "verification_bucket" { 
  bucket = "hosted-img-hub"
  force_destroy = true
}

# Allow Public Access For Verification Bucket
resource "aws_s3_bucket_public_access_block" "verification_bucket" {
  bucket = aws_s3_bucket.verification_bucket.id

  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

# Verification Bucket CORS
resource "aws_s3_bucket_cors_configuration" "verification_bucket" {
  bucket = aws_s3_bucket.verification_bucket.id

  cors_rule {
    allowed_headers = ["Content-Type"]
    allowed_methods = ["PUT"]
    allowed_origins = ["http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"]
    max_age_seconds = 200
  }
}

# Verification Bucket Policy
resource "aws_s3_bucket_policy" "verification_policy" {
  bucket = aws_s3_bucket.verification_bucket.id
  policy = data.aws_iam_policy_document.verification_policy.json
  depends_on = [aws_s3_bucket_public_access_block.verification_bucket]
}

data "aws_iam_policy_document" "verification_policy" {
  statement {
    sid = "ReadPermissionForVerififedPrefix"

    principals {
      type = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.verification_bucket.arn}/public/*"]
  }
}

# Verification Bucket Lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "verification_lifecycle" {
  bucket = aws_s3_bucket.verification_bucket.id

  rule {
    id = "clean-up"
    status = "Enabled"

    filter { prefix = "unverified/" }
    expiration { days = 1 }
  }
}

# Website Bucket
resource "aws_s3_bucket" "website_bucket" { 
  bucket = "public-img-url" 
  force_destroy = true
}

# Allow Public Access For Website Bucket
resource "aws_s3_bucket_public_access_block" "website_bucket" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

# Website Bucket Policy
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.website_policy.json
  depends_on = [aws_s3_bucket_public_access_block.website_bucket]
}

data "aws_iam_policy_document" "website_policy" {
  statement {
    sid = "ReadPermissionForWebsite"

    principals {
      type = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
  }
}

# Website Configuration
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

# Process Static Website Files And Auto-Detect MIME Types
module "template_files" {
  source = "hashicorp/dir/template"
  base_dir = "${path.module}/webpage"
}

# Uploading Website Files To The Website Bucket
resource "aws_s3_object" "static_files" {
  for_each = module.template_files.files

  bucket = aws_s3_bucket.website_bucket.id
  key = each.key
  content_type = each.value.content_type

  source = each.key == "index.html" ? null : each.value.source_path
  content = each.key == "index.html" ? replace(file(each.value.source_path), "API_URL", aws_api_gateway_stage.api_gateway.invoke_url) : null
  etag = each.key == "index.html" ? null : each.value.digests.md5
}

# Dynamo DB
resource "aws_dynamodb_table" "tracker_dynamodb" {
  name = "image_tracker"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "image_name"

  attribute {
    name = "image_name"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled = true
  }
}

# IAM Assume Lambda Role
resource "aws_iam_role" "lambda_role" {
  name = "image_moderation_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Attach Lambda Basic Execution Policy To IAM Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Lambda Policy And Attaching It To Lambda Role
resource "aws_iam_policy" "lambda_custom_policy" {
  name   = "image_moderation_policy"
  policy = data.aws_iam_policy_document.lambda_custom_policy.json
}

data "aws_iam_policy_document" "lambda_custom_policy" {
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    effect = "Allow"
    resources = ["${aws_s3_bucket.verification_bucket.arn}/unverified/*"]
  }

  statement {
    actions = ["s3:PutObject"]
    effect = "Allow"
    resources = ["${aws_s3_bucket.verification_bucket.arn}/public/*"]
  }

  statement {
    actions = ["dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    effect = "Allow"
    resources = [aws_dynamodb_table.tracker_dynamodb.arn]
  }

  statement {
    actions = ["rekognition:DetectModerationLabels"]
    effect = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_custom_role" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_custom_policy.arn
}

# Package The Lambda Function Code
data "archive_file" "lambda_function" {
  type = "zip"
  source_file = "${path.module}/lambdacode/lambda_function.mjs"
  output_path = "${path.module}/lambdacode/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  filename = data.archive_file.lambda_function.output_path
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  function_name = "image_moderation_app"
  role = aws_iam_role.lambda_role.arn
  handler = "lambda_function.handler"
  runtime = "nodejs24.x"

  environment {
    variables = {
      DBNAME = aws_dynamodb_table.tracker_dynamodb.id
      BUCKETNAME = aws_s3_bucket.verification_bucket.id
      VERIFYINGURL = "https://${aws_s3_bucket.verification_bucket.id}.s3.${data.aws_region.current.region}.amazonaws.com"
      WEBSITEURL: "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
    }
  }
}

# Lambda Permission for Verification Bucket
resource "aws_lambda_permission" "verification_bucket_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.verification_bucket.arn
}

# Verification Bucket Notification
resource "aws_s3_bucket_notification" "verification_bucket_notification" {
  bucket = aws_s3_bucket.verification_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events = ["s3:ObjectCreated:Put"]
    filter_prefix = "unverified/"
  }

  depends_on = [aws_lambda_permission.verification_bucket_permission]
}

# REST API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" { name = "image_upload" }

# API Gateway Image Upload Resource
resource "aws_api_gateway_resource" "image_upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part = "image_upload"
}

# API Gateway OPTIONS Method
resource "aws_api_gateway_method" "option_method" {
  authorization = "NONE"
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = "OPTIONS"
}

# API Gateway OPTIONS Integration
resource "aws_api_gateway_integration" "option_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = aws_api_gateway_method.option_method.http_method
  type = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = aws_api_gateway_method.option_method.http_method

  status_code = "200"
  response_models = { "application/json" = "Empty" }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = false
    "method.response.header.Access-Control-Allow-Origin" = false
    "method.response.header.Access-Control-Allow-Methods" = false
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = aws_api_gateway_method.option_method.http_method
  status_code = aws_api_gateway_method_response.method_response_200.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Origin" = "'http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS, POST'"
  }

  depends_on = [aws_api_gateway_integration.option_integration]
}

# API Gateway Image Upload POST Method
resource "aws_api_gateway_method" "image_upload_method" {
  authorization = "NONE"
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = "POST"

  request_models = { "application/json" = aws_api_gateway_model.api_gateway.name }
  request_validator_id = aws_api_gateway_request_validator.api_gateway.id
}

# API Gateway Image Upload Lambda Integration
resource "aws_api_gateway_integration" "image_upload_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_upload_resource.id
  http_method = aws_api_gateway_method.image_upload_method.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.lambda_function.invoke_arn
}

# API Gateway Image Status Resource
resource "aws_api_gateway_resource" "image_status_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part = "image_status"
}

# API Gateway Image Status GET Method
resource "aws_api_gateway_method" "image_status_method" {
  authorization = "NONE"
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_status_resource.id
  http_method = "GET"

  request_parameters = { "method.request.querystring.image_name" = true }
  request_validator_id = aws_api_gateway_request_validator.api_gateway.id
}

# API Gateway Image Status Lambda Integration
resource "aws_api_gateway_integration" "image_status_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.image_status_resource.id
  http_method = aws_api_gateway_method.image_status_method.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.lambda_function.invoke_arn
}

# API Gateway Model
resource "aws_api_gateway_model" "api_gateway" {
  rest_api_id  = aws_api_gateway_rest_api.api_gateway.id
  name = "ImageUploadSchema"
  content_type = "application/json"

  schema = jsonencode({
    type = "object"
    properties = { file_extension: { type: "string" } },
    required = ["file_extension"],
    additionalProperties: false
  })
}

# API Gateway Validator
resource "aws_api_gateway_request_validator" "api_gateway" {
  name = "API Validator"
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  validate_request_body = true
  validate_request_parameters = true
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_gateway" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  lifecycle { create_before_destroy = true }

  depends_on = [
    aws_api_gateway_method.option_method,
    aws_api_gateway_integration.option_integration,
    aws_api_gateway_method_response.method_response_200,
    aws_api_gateway_integration_response.integration_response,
    aws_api_gateway_method.image_upload_method,
    aws_api_gateway_integration.image_upload_integration,
    aws_api_gateway_method.image_status_method,
    aws_api_gateway_integration.image_status_integration
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "api_gateway" {
  deployment_id = aws_api_gateway_deployment.api_gateway.id
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name = "Prod"
}

# Lambda Permission For Image Upload
resource "aws_lambda_permission" "image_upload_permission" {
  statement_id = "AllowAPIGatewayUpload"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/Prod/POST/image_upload"
}

# Lambda Permission For Image Status
resource "aws_lambda_permission" "image_status_permission" {
  statement_id = "AllowAPIGatewayStatus"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/Prod/GET/image_status"
}