# resource "aws_acm_certificate" "n8n_cert" {
#   domain_name       = "n8n.datium.fr" # Use a domain you control, or replace with a placeholder
#   validation_method = "DNS"
#   lifecycle {
#     create_before_destroy = true
#   }
#   tags = {
#     Name = "n8n-cert"
#   }
# }

# resource "aws_acm_certificate_validation" "n8n_cert_validation" {
#   certificate_arn = aws_acm_certificate.n8n_cert.arn
# }

