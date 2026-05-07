param(
    [string]$SourceProfile = "base"
)

$ErrorActionPreference = "Stop"

Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
Remove-Item Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue

$Region = "ap-northeast-2"
$DurationSeconds = 43200
$MfaProfile = "default"

$Username = aws iam get-user `
    --profile $SourceProfile `
    --query "User.UserName" `
    --output text

$AccountId = aws sts get-caller-identity `
    --profile $SourceProfile `
    --query "Account" `
    --output text

$MfaSerial = aws iam list-mfa-devices `
    --profile $SourceProfile `
    --user-name $Username `
    --query "MFADevices[0].SerialNumber" `
    --output text

if ([string]::IsNullOrWhiteSpace($MfaSerial) -or $MfaSerial -eq "None") {
    Write-Host "ERROR: MFA device not found for user: $Username"
    exit 1
}

Write-Host "Source Profile: $SourceProfile"
Write-Host "MFA Profile: $MfaProfile"
Write-Host "IAM User: $Username"
Write-Host "MFA Device: $MfaSerial"

$MfaCode = Read-Host "MFA Code"

$SessionResult = aws sts get-session-token `
    --profile $SourceProfile `
    --serial-number $MfaSerial `
    --token-code $MfaCode `
    --duration-seconds $DurationSeconds `
    --region $Region `
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" `
    --output text

$Parts = $SessionResult -split "`t"

if ($Parts.Length -lt 3) {
    Write-Host "ERROR: Failed to retrieve session credentials."
    exit 1
}

$AccessKey = $Parts[0]
$SecretKey = $Parts[1]
$SessionToken = $Parts[2]

aws configure set aws_access_key_id $AccessKey --profile $MfaProfile
aws configure set aws_secret_access_key $SecretKey --profile $MfaProfile
aws configure set aws_session_token $SessionToken --profile $MfaProfile
aws configure set region $Region --profile $MfaProfile

Write-Host ""
Write-Host "MFA session saved to profile: $MfaProfile"
Write-Host ""

aws sts get-caller-identity --profile $MfaProfile

$env:AWS_PROFILE = $MfaProfile

Write-Host ""
Write-Host "AWS_PROFILE set to $MfaProfile"
