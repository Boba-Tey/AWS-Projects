# Setup
terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 5.92"
        }
    }
    required_version = ">= 1.2"
}

provider "aws" {
    region = "ap-south-1"
}

# Step 1: Create your Lambda Function
resource "aws_lambda_function" "lambda_function" {
    function_name = "lambda_function"
    filename      = "lambda_function.zip"
    role          = "arn:aws:iam::1234567890:role/lambda_apps"
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.10"
    timeout       =  10
    source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_lambda_function_url" "lambda_url" {
    function_name      = aws_lambda_function.lambda_function.function_name
    authorization_type = "NONE"
}

data "template_file" "script_js" {
    template = file("${path.module}/webpage/script.js")
    vars = {
        lambda_url = aws_lambda_function_url.lambda_url.function_url
    }
}

# Step 2: Create an S3 bucket for storing user uploaded images
resource "aws_s3_bucket" "img_bucket" {
    bucket = "public-url-store101"
    force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "img_bucket" {
    bucket = aws_s3_bucket.img_bucket.id
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "img_policy" {
    bucket = aws_s3_bucket.img_bucket.id
    policy = data.aws_iam_policy_document.img_policy.json
}

data "aws_iam_policy_document" "img_policy" {
    statement {
        sid = "PublicReadGetObject"
        effect = "Allow"

        principals {
            type        = "AWS"
            identifiers = ["*"]
        }

        actions = [
            "s3:GetObject"
        ]

        resources = [
            "${aws_s3_bucket.img_bucket.arn}/*"
        ]
    }
}

# Step 3: Create an S3 bucket to host your static website
resource "aws_s3_bucket" "web_bucket" {
    bucket = "public-url-gen101"
    force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "web_bucket" {
    bucket = aws_s3_bucket.web_bucket.id
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "web_policy" {
    bucket = aws_s3_bucket.web_bucket.id
    policy = data.aws_iam_policy_document.web_policy.json
}

data "aws_iam_policy_document" "web_policy" {
    statement {
        sid = "PublicReadGetObject"
        effect = "Allow"

        principals {
            type        = "AWS"
            identifiers = ["*"]
        }

        actions = [
            "s3:GetObject"
        ]

        resources = [
            "${aws_s3_bucket.web_bucket.arn}/*"
        ]
    }
}

resource "aws_s3_bucket_website_configuration" "web_bucket" {
    bucket = aws_s3_bucket.web_bucket.id

    index_document {
        suffix = "index.html"
    }
}

resource "aws_s3_object" "html" {
    bucket       = aws_s3_bucket.web_bucket.id
    key          = "index.html"
    source       = "webpage/index.html"
    content_type = "text/html"
}

resource "aws_s3_object" "css" {
    bucket       = aws_s3_bucket.web_bucket.id
    key          = "style.css"
    source       = "webpage/style.css"
    content_type = "text/css"
}

resource "aws_s3_object" "js" {
    bucket       = aws_s3_bucket.web_bucket.id
    key          = "script.js"
    content      = data.template_file.script_js.rendered
    content_type = "application/javascript"
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.web_bucket.website_endpoint
}