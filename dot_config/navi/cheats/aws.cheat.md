```sh
% aws

# setup [sso:aws configure sso]
aws configure

# setup : display profiles
aws configure list-profiles

# setup : display active profile
aws configure list

# sts(security token service) : display identity information [--profile:]
aws sts get-caller-identity --profile <profile>

# sso : login sso
aws sso login --profile <profile>

# iam : display iam users
aws iam list-users | fx

# iam : display iam groups
aws iam list-groups | fx

# iam : display iam policies [--scope:Local,AWS]
aws iam list-policies --scope Local | fx

# iam : display iam roles
aws iam list-roles | fx

# iam : display iam groups for login user
aws iam list-groups-for-user --user-name $(aws sts get-caller-identity --query "Arn" --output text | awk -F'/' '{print $2}')

# iam : display mfadevices
aws iam list-mfa-devices

# organization : display organization id [Organization.Id = o-xxx][Organization.MasterAccountId = YYYYYYYYYYYY(12)]
aws organizations describe-organization --query '<organization_id>' --output text --profile <profile>
```

$ profile: aws configure list-profiles
$ organization_id: echo -n 'Organization.Id\nOrganization.MasterAccountId'
;$
