# aws-hackathon-resources
해커톤 참가자 대상 aws 리소스 배포용

# 공지사항
## AWS MFA 인증 정책 변경 안내 (2026.05.07)

해커톤 AWS 환경의 보안 및 비용 보호 강화를 위해 MFA(다중 인증) 정책이 적용됩니다.

### 변경 전

* 콘솔 웹: ID/PW 로그인
* AWS CLI / SDK / CloudShell: Access Key만으로 사용 가능

### 변경 후

* 콘솔 웹: MFA 인증 필수
* AWS CLI / SDK / CloudShell: MFA 인증된 세션에서만 사용 가능

---

## 적용 이유

AWS CLI 및 CloudShell은 자동화가 쉬워:

* 대량 리소스 생성
* 반복 API 호출
* Bedrock 과다 사용

등으로 비용 및 보안 이슈가 발생할 수 있습니다.

또한 Access Key가 외부에 노출되더라도, MFA 기반 임시 세션(STS)이 없으면 실제 AWS 접근이 불가능하도록 MFA 인증을 적용합니다.

즉, Access Key만으로는 AWS 리소스 접근이 불가능합니다.

---

## 참고 사항

* MFA는 매 요청마다 필요한 것이 아닙니다.
* 한 번 인증하면 일정 시간 동안 계속 사용할 수 있습니다.
* 콘솔 웹, AWS CLI, CloudShell 모두 동일하게 적용됩니다.

---

# MFA 기반 임시 세션(STS) 사용 방법
1. MFA 인증 (aws sts get-session-token)
2. 쉘 스크립트로 MFA 인증

## 1. MFA 인증 (쉘 스크립트 X)
> `<ACCOUNT_ID>` : aws계정 정보의 계정 ID  
> `<USERNAME>` : aws계정 정보의 계정 별칭   
> `<MFA 인증 값>`  

#### serial-number 정보 조회
```
aws iam list-mfa-devices 
```
```
{
    "MFADevices": [
        {
            "UserName": "~~",
            "SerialNumber": "arn:aws:iam::456~~:mfa/aws-cis",
            "EnableDate": "2026-04-19T13:04:36+00:00"
        }
    ]
}

<ACCOUNT_ID> : 456~~ 
<USERNAME> : aws-cis
```
#### MFA 인증
```
aws sts get-session-token \
  --serial-number arn:aws:iam::<ACCOUNT_ID>:mfa/<USERNAME> \
  --token-code <MFA 인증 값>
```

## 2.쉘 스크립트 적용 방법
> aws-mfa-login.sh : 로컬에서 MFA 코드만 입력하면 자동으로 세션 갱신되는 스크립트

### 2-1. 스크립트 다운로드
Linux/macOS/Git bash에서 실행
```
curl -O https://raw.githubusercontent.com/inschoi-cmpy/aws-hackathon-resources/refs/heads/main/scripts/aws-mfa-login.sh
```
Window PowerShell
```
curl.exe -L "https://raw.githubusercontent.com/inschoi-cmpy/aws-hackathon-resources/refs/heads/main/scripts/aws-mfa-login-win.ps1" -o aws-mfa-login-win.ps1
```

### 2-2. 실행 권한
Linux/macOS/Git
```
chmod +x aws-mfa-login.sh
```
Window PowerShell
```
Set-ExecutionPolicy -Scope Process Bypass
```
### 2-3. 최초 1회 - base 프로필 생성
최초 1회 base 프로필 생성 -> MFA 인증 -> default 프로필에 저장  
> base    = 원본 Access Key 저장  
> default = MFA 인증된 임시 세션 저장  
```
aws configure --profile base
```
> AWS Access Key ID: 입력  
> AWS Secret Access Key: 입력  
> Default region name: ap-northeast-2  
> Default output format: json  

### 2-4. 스크립트 실행 - 사용할 때마다 (만료 시간 이전까지 지속 사용 가능)
base 프로필로 MFA 인증  
Linux/macOS/Git
```
./aws-mfa-login.sh
```
Window PowerShell
```
.\aws-mfa-login-win.ps1
```

별도의 profile이 있는 경우
```
./aws-mfa-login.sh <profile 이름>
```
> Source Profile: base  
> MFA Profile: default  
> IAM User: ~~  
> MFA Device: arn:aws:iam::~~:mfa/aws-cis  
> MFA Code: 입력하기  

### 2-5. CLI 사용 확인
```
aws s3 ls
aws ec2 describe-instances
```

### Error Case
1. iam사용자의 MFA가 활성화 안된 경우(미등록)
```
ERROR: MFA device not found for user: 
```
2. 권한 없는 경우
```
aws: [ERROR]: An error occurred (AccessDenied) when calling the ListBuckets operation: User: arn:aws:iam::~~:user/~~ is not authorized to perform: s3:ListAllMyBuckets with an explicit deny in an identity-based policy
```
