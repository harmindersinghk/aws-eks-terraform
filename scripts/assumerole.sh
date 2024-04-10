export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
$(aws sts assume-role \
--role-arn arn:aws:iam::{$ACCOUNT_NUM}:role/ex-iam-github-oidc \
--role-session-name eks-access \
--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
--output text))