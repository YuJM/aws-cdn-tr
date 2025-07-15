# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_profile" {
  description = "AWS Profile to use for authentication"
  type        = string
  # default 값을 제거하면 실행시 입력받게 됩니다
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "host_domain" {
  description = "Main domain name (e.g., example.com)"
  type        = string
}

variable "cdn_domain" {
  description = "CDN subdomain name (e.g., cdn.example.com)"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing assets (must be globally unique)"
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Provider 설정 (SSO Profile 사용)
# 사용 전에 다음 명령을 실행하세요:
# aws sso login --profile <your-profile-name>
# 또는 환경 변수 설정: export AWS_PROFILE=<your-profile-name>
# -----------------------------------------------------------------------------
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# -----------------------------------------------------------------------------
# 1. S3 Bucket (폰트 및 이미지 저장)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "assets_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "Your Assets Bucket"
    Environment = "Production"
    Purpose     = "CDN_Assets"
  }
}

# S3 버킷 소유권 제어 설정 (ACL 대신 사용)
resource "aws_s3_bucket_ownership_controls" "assets_bucket_acl_ownership" {
  bucket = aws_s3_bucket.assets_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 버킷 ACL 설정 (새로운 방식)
resource "aws_s3_bucket_acl" "assets_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.assets_bucket_acl_ownership]
  bucket = aws_s3_bucket.assets_bucket.id
  acl    = "private"
}

# S3 버킷 퍼블릭 접근 차단 설정 (보안 강화)
resource "aws_s3_bucket_public_access_block" "assets_bucket_public_access_block" {
  bucket = aws_s3_bucket.assets_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 정책 (CloudFront OAI가 접근할 수 있도록 허용)
resource "aws_s3_bucket_policy" "assets_bucket_policy" {
  bucket = aws_s3_bucket.assets_bucket.id

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "AWS" = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.assets_oai.id}"
        },
        "Action" = "s3:GetObject",
        "Resource" = [
          "${aws_s3_bucket.assets_bucket.arn}/*",
          aws_s3_bucket.assets_bucket.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 2. AWS Certificate Manager (ACM) - HTTPS를 위한 SSL/TLS 인증서
# CloudFront는 us-east-1 리전의 인증서만 지원하므로, provider 설정을 별도로 합니다.
# -----------------------------------------------------------------------------
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1" # CloudFront는 us-east-1 리전의 ACM 인증서만 지원
  profile = var.aws_profile
}

resource "aws_acm_certificate" "assets_cert" {
  provider        = aws.us_east_1
  domain_name     = var.cdn_domain
  validation_method = "DNS"

  tags = {
    Name = "Assets CDN SSL Certificate"
  }
}

# ACM 인증서 검증을 위한 Route53 레코드 생성
resource "aws_route53_record" "assets_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.assets_cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      type    = dvo.resource_record_type
      records = [dvo.resource_record_value]
      zone_id = data.aws_route53_zone.main.zone_id
    }
  }

  name            = each.value.name
  type            = each.value.type
  records         = each.value.records
  zone_id         = each.value.zone_id
  ttl             = 60
  allow_overwrite = true

  lifecycle {
    create_before_destroy = true
  }
}

# ACM 인증서가 완전히 검증될 때까지 대기
resource "aws_acm_certificate_validation" "assets_cert_validation" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.assets_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.assets_cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# 3. CloudFront Distribution (CDN 구성)
# -----------------------------------------------------------------------------
# CloudFront Origin Access Identity (OAI) - S3 버킷에 안전하게 접근하기 위함
resource "aws_cloudfront_origin_access_identity" "assets_oai" {
  comment = "OAI for assets S3 bucket access"
}

resource "aws_cloudfront_distribution" "assets_distribution" {
  origin {
    domain_name = aws_s3_bucket.assets_bucket.bucket_regional_domain_name
    origin_id   = "s3_origin_your_assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.assets_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for fonts and images"
  # default_root_object는 정적 웹사이트가 아니므로 필수는 아니지만,
  # 특정 경로로 접근 시 기본 파일을 제공하고 싶다면 설정할 수 있습니다.
  # 예: default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3_origin_your_assets"

    forwarded_values {
      query_string = false
      headers      = ["Origin"] # 필요한 경우 다른 헤더 추가
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # HTTP 요청을 HTTPS로 리디렉션
    min_ttl                = 0
    default_ttl            = 86400 # 24시간 (자산 캐싱 시간)
    max_ttl                = 31536000 # 1년 (오래 변경되지 않는 자산에 유리)
  }

  # 폰트 파일에 대한 캐싱 정책 (CORS 헤더 포함)
  ordered_cache_behavior {
    path_pattern     = "*.woff2" # WOFF2 폰트
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3_origin_your_assets"

    forwarded_values {
      query_string = false
      headers      = ["Origin"] # CORS를 위해 Origin 헤더를 전달
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true # 폰트 파일 압축

    # CORS 헤더 추가 (Lambda@Edge 또는 CloudFront Functions 사용 시)
    # 여기서는 CloudFront Functions를 사용하여 CORS 헤더를 추가하는 예시를 주석으로 남깁니다.
    # CloudFront Functions는 별도로 생성해야 합니다.
    # function_association {
    #   event_type   = "viewer-response"
    #   function_arn = "arn:aws:lambda:us-east-1:123456789012:function:your-cors-function:1"
    # }
  }

  ordered_cache_behavior {
    path_pattern     = "*.woff" # WOFF 폰트
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3_origin_your_assets"

    forwarded_values {
      query_string = false
      headers      = ["Origin"] # CORS를 위해 Origin 헤더를 전달
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.ttf" # TTF 폰트 (필요한 경우)
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3_origin_your_assets"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.eot" # EOT 폰트 (필요한 경우)
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3_origin_your_assets"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  price_class = "PriceClass_100" # 가격 등급 (PriceClass_All, PriceClass_200, PriceClass_100)

  restrictions {
    geo_restriction {
      restriction_type = "none" # "blacklist" 또는 "whitelist"로 특정 국가 제한 가능
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate_validation.assets_cert_validation.certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2019" # 최신 보안 프로토콜 사용 권장
  }

  aliases = [var.cdn_domain]

  tags = {
    Name = "Your Assets CloudFront CDN"
  }
}

# -----------------------------------------------------------------------------
# 4. Route53 (도메인 연결)
# -----------------------------------------------------------------------------
# 기존 Route53 호스팅 영역 가져오기 (이미 생성되어 있는 경우)
data "aws_route53_zone" "main" {
  name         = "${var.host_domain}."
  private_zone = false
}

# 서브도메인 CDN A 레코드
resource "aws_route53_record" "assets_subdomain_a_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.cdn_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.assets_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.assets_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# -----------------------------------------------------------------------------
# Outputs (배포 후 확인을 위한 정보)
# -----------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "The name of the S3 bucket for assets."
  value       = aws_s3_bucket.assets_bucket.bucket
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution for assets."
  value       = aws_cloudfront_distribution.assets_distribution.domain_name
}

output "cloudfront_id" {
  description = "The ID of the CloudFront distribution for assets."
  value       = aws_cloudfront_distribution.assets_distribution.id
}

output "assets_cdn_url_https" {
  description = "The HTTPS URL for your assets CDN."
  value       = "https://${aws_route53_record.assets_subdomain_a_record.name}"
}