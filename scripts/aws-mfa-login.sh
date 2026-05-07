#!/bin/bash

set -e

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_PROFILE

REGION="ap-northeast-2"
DURATION_SECONDS=43200

SOURCE_PROFILE="${1:-base}"
MFA_PROFILE="default"

USERNAME=$(aws iam get-user \
--profile "${SOURCE_PROFILE}" \
--query 'User.UserName' \
--output text)

ACCOUNT_ID=$(aws sts get-caller-identity \
--profile "${SOURCE_PROFILE}" \
--query 'Account' \
--output text)

MFA_SERIAL=$(aws iam list-mfa-devices \
--profile "${SOURCE_PROFILE}" \
--user-name "${USERNAME}" \
--query 'MFADevices[0].SerialNumber' \
--output text)

if [ -z "$MFA_SERIAL" ] || [ "$MFA_SERIAL" = "None" ]; then
echo "ERROR: MFA device not found for user: ${USERNAME}"
exit 1
fi

echo "Source Profile: ${SOURCE_PROFILE}"
echo "MFA Profile: ${MFA_PROFILE}"
echo "IAM User: ${USERNAME}"
echo "MFA Device: ${MFA_SERIAL}"

read -p "MFA Code: " MFA_CODE

read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< $(aws sts get-session-token \
--profile "${SOURCE_PROFILE}" \
--serial-number "${MFA_SERIAL}" \
--token-code "${MFA_CODE}" \
--duration-seconds "${DURATION_SECONDS}" \
--region "${REGION}" \
--query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
--output text)

aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile "${MFA_PROFILE}"
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile "${MFA_PROFILE}"
aws configure set aws_session_token "${AWS_SESSION_TOKEN}" --profile "${MFA_PROFILE}"
aws configure set region "${REGION}" --profile "${MFA_PROFILE}"

echo "MFA session saved to profile: ${MFA_PROFILE}"
aws sts get-caller-identity --profile "${MFA_PROFILE}"

export AWS_PROFILE="${MFA_PROFILE}"
echo "AWS_PROFILE set to ${MFA_PROFILE}"
