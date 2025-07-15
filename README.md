# 🚀 AWS CDN Infrastructure with Terraform

AWS CloudFront + S3를 사용한 CDN 인프라를 Terraform으로 구축하는 프로젝트입니다.
폰트, 이미지 등의 정적 자산을 전 세계적으로 빠르게 배포할 수 있습니다.

## ✨ 구성 요소

- **S3**: 정적 자산 저장소
- **CloudFront**: 글로벌 CDN 배포
- **ACM**: HTTPS SSL/TLS 인증서
- **Route53**: 커스텀 도메인 연결

## 🎯 결과물

배포 완료 후 다음과 같은 CDN URL을 얻을 수 있습니다:
```
https://cdn.your-domain.com/your-assets.woff
```

## 🚀 빠른 시작

### 1️⃣ 사전 준비

```bash
# 필수 도구 설치
brew install terraform awscli  # macOS
# 또는
apt install terraform awscli   # Ubuntu

# AWS 인증 설정
aws configure  # 또는 aws sso configure
```

### 2️⃣ 변수 설정

```bash
# 예제 파일을 복사하여 본인의 설정으로 변경
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일을 편집하여 다음 값들을 설정:
# - aws_profile: AWS 프로필 이름
# - host_domain: 본인의 도메인 (예: example.com)
# - cdn_domain: CDN 서브도메인 (예: cdn.example.com)  
# - s3_bucket_name: 고유한 S3 버킷 이름
```

📝 **상세한 변수 설정 가이드는 `terraform.tfvars.example` 파일을 참고하세요.**

### 3️⃣ 배포 실행

```bash
# 초기화
terraform init

# 배포 계획 확인
terraform plan

# 배포 실행
terraform apply
```

### 4️⃣ 파일 업로드 및 테스트

```bash
# S3에 파일 업로드
aws s3 sync ./assets s3://your-bucket-name/

# CDN URL로 접근 테스트
curl -I https://cdn.your-domain.com/test-file.png
```

## 📋 주요 명령어

| 작업 | 명령어 |
|------|--------|
| **S3 파일 동기화** | `aws s3 sync ./assets s3://bucket-name/` |
| **CDN 캐시 무효화** | `aws cloudfront create-invalidation --distribution-id DIST_ID --paths "/*"` |
| **배포 정보 확인** | `terraform output` |
| **인프라 삭제** | `terraform destroy` |

## 🔧 사용 예시

### CSS에서 폰트 사용
```css
@font-face {
  font-family: 'CustomFont';
  src: url('https://cdn.your-domain.com/fonts/font.woff2') format('woff2');
}
```

### HTML에서 이미지 사용
```html
<img src="https://cdn.your-domain.com/images/logo.png" alt="Logo">
```

## 💰 예상 비용

| 서비스 | 비용 | 무료 한도 |
|--------|------|----------|
| **CloudFront** | 데이터 전송량 기준 | 첫 1TB 무료 |
| **S3** | 저장 용량 + 요청 수 | 첫 5GB 무료 |
| **Route53** | 호스팅 영역 월 $0.50 | - |
| **ACM** | SSL 인증서 무료 | 무료 |

소규모 프로젝트의 경우 대부분 **월 $1 이하**로 운영 가능합니다.

## 📁 프로젝트 구조

```
aws-cdn-tr/
├── main.tf                    # 메인 Terraform 설정
├── terraform.tfvars.example   # 변수 설정 예제 (📝 상세 가이드)
├── terraform.tfvars          # 실제 변수 설정 (Git 제외)
├── .gitignore                # Git 제외 파일 목록
└── README.md                 # 이 파일
```

## 🛡️ 보안 특징

- ✅ S3 버킷 완전 비공개 (CloudFront OAI를 통해서만 접근)
- ✅ HTTPS 강제 적용 (HTTP 요청 자동 리디렉션)  
- ✅ 최신 TLS 1.2+ 프로토콜 사용
- ✅ 민감한 정보 Git 추적 제외

## 🔍 문제 해결

### ❌ AWS 인증 오류
```bash
aws sso login --profile your-profile-name
# 또는
aws configure
```

### ❌ Terraform 초기화 실패
```bash
rm -rf .terraform*
terraform init
```

### ❌ S3 버킷 이름 충돌
- S3 버킷 이름은 전 세계적으로 고유해야 합니다
- `terraform.tfvars`에서 `s3_bucket_name`을 다른 이름으로 변경하세요

### ❌ 도메인 연결 실패
- Route53에 해당 도메인의 호스팅 영역이 생성되어 있는지 확인
- 도메인 네임서버가 AWS Route53을 가리키고 있는지 확인

## 🤝 기여하기

1. Fork this repository
2. Create a feature branch
3. Commit your changes  
4. Push to the branch
5. Create a Pull Request

---

⭐ **도움이 되었다면 스타를 눌러주세요!** 