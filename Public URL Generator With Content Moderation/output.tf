output "website_url" {
  description = "Website URL"
  value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "api_gateway_endpoint" {
  description = "API Gateway's Base URL"
  value = "https://${aws_api_gateway_rest_api.api_gateway.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${aws_api_gateway_stage.api_gateway.stage_name}"
}