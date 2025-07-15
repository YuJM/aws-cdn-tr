# AWS CDN Infrastructure with Terraform

이 프로젝트는 AWS S3, CloudFront, ACM, Route53를 사용하여 CDN 인프라를 구성하는 Terraform 코드입니다.

## 🚀 주요 기능

- **S3 버킷**: 폰트 및 이미지 파일 저장
- **CloudFront**: CDN 배포로 전 세계 캐싱
- **ACM**: HTTPS를 위한 SSL/TLS 인증서
- **Route53**: 커스텀 도메인 연결

## 📋 사전 요구사항

- Terraform 설치
- AWS CLI 설치 및 SSO 설정
- Route53 호스팅 영역 (vibelist.click)

## 🔧 AWS Profile 변수 사용 방법

### 1. 기본 설정

`main.tf`에서 다음과 같이 변수를 정의했습니다:

```hcl
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
```

### 2. 사용 방법

#### 방법 1: terraform.tfvars 파일 사용 (권장)

프로젝트 루트에 `terraform.tfvars` 파일을 생성:

```hcl
aws_profile = "boot-polcaneli"
aws_region  = "ap-northeast-2"
```

실행:
```bash
terraform plan
terraform apply
```

#### 방법 2: 명령행 인자로 전달

```bash
terraform plan -var="aws_profile=my-profile"
terraform apply -var="aws_profile=my-profile" -var="aws_region=us-west-2"
```

#### 방법 3: 환경 변수 사용

```bash
export TF_VAR_aws_profile="my-profile"
export TF_VAR_aws_region="us-west-2"
terraform plan
terraform apply
```

#### 방법 4: 대화형 입력

변수에 `default` 값이 없으면 실행시 직접 입력받습니다:

```bash
terraform plan
# 실행시 다음과 같이 입력을 요청합니다:
# var.aws_profile
#   AWS Profile to use for authentication
#   Enter a value: boot-polcaneli
```

#### 방법 5: 프로필별 tfvars 파일

다양한 환경을 위해 여러 tfvars 파일을 생성할 수 있습니다:

```bash
# dev.tfvars
aws_profile = "dev-profile"
aws_region  = "ap-northeast-2"

# prod.tfvars
aws_profile = "prod-profile"
aws_region  = "ap-northeast-2"
```

사용:
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

## 🔐 AWS SSO 인증

### 1. AWS SSO 로그인

```bash
aws sso login --profile boot-polcaneli
```

### 2. 환경 변수 설정 (선택사항)

매번 `--profile` 옵션을 사용하지 않으려면:

```bash
# 현재 세션용
export AWS_PROFILE=boot-polcaneli

# 영구적으로 설정 (zsh 사용자)
echo 'export AWS_PROFILE=boot-polcaneli' >> ~/.zshrc
source ~/.zshrc
```

## 📂 S3 파일 업로드

### 현재 폴더의 모든 파일 업로드

```bash
# 모든 파일 동기화
aws s3 sync . s3://vibelist-cdn-assets/

# 특정 폴더 구조로 업로드
aws s3 sync . s3://vibelist-cdn-assets/fonts/

# 특정 파일 형식만 업로드
aws s3 sync . s3://vibelist-cdn-assets/fonts/ --include "*.woff*" --include "*.ttf"

# 제외 파일 설정
aws s3 sync . s3://vibelist-cdn-assets/ --exclude "*.tf" --exclude "*.tfstate*"
```

### 재귀적 복사

```bash
aws s3 cp . s3://vibelist-cdn-assets/ --recursive
```

## 🌐 배포 후 확인

### 출력 확인

```bash
terraform output
```

결과:
```
assets_cdn_url_https = "https://cdn.vibelist.click"
cloudfront_domain_name = "dan47lq6a73h9.cloudfront.net"
cloudfront_id = "ENXMZDWGXQNOY"
s3_bucket_name = "vibelist-cdn-assets"
```

### CDN 사용 예시

```css
@font-face {
  font-family: 'Pretendard';
  src: url('https://cdn.vibelist.click/fonts/Pretendard-Black.subset.woff') format('woff');
}
```

### CloudFront 캐시 무효화

```bash
aws cloudfront create-invalidation --distribution-id ENXMZDWGXQNOY --paths "/*"
```

## 🔄 인프라 관리

### 변경사항 미리보기

```bash
terraform plan
```

### 변경사항 적용

```bash
terraform apply
```

### 리소스 삭제

```bash
terraform destroy
```

## 🛡️ 보안 고려사항

1. **S3 버킷**: private 액세스, CloudFront OAI를 통한 접근만 허용
2. **SSL/TLS**: ACM 인증서로 HTTPS 강제
3. **CloudFront**: 최신 TLS 프로토콜 (TLSv1.2_2019) 사용
4. **Route53**: DNS 레코드 보안 설정

## 📝 주의사항

- S3 버킷 이름은 전 세계적으로 고유해야 합니다
- CloudFront 배포는 생성/수정에 5-10분 소요됩니다
- ACM 인증서는 us-east-1 리전에서만 CloudFront에 사용 가능합니다
- Route53 호스팅 영역이 미리 생성되어 있어야 합니다

## 🆘 문제 해결

### SSO 로그인 실패
```bash
aws sso login --profile boot-polcaneli
```

### S3 ACL 오류
- 최신 AWS S3는 ACL을 기본적으로 비활성화합니다
- 코드에서 `ownership_controls`를 사용하여 해결

### Route53 레코드 충돌
- `allow_overwrite = true` 옵션 사용
- 기존 레코드가 있는 경우 자동 덮어쓰기

---

## 📞 연락처

문의사항이나 개선 제안이 있으시면 언제든지 연락주세요! 