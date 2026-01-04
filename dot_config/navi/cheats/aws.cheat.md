```sh
% aws

# setup [sso:aws configure sso]
aws configure

# setup : display profiles
aws configure list-profiles

# setup : display active profile
aws configure list

# sts(security token service) : display current identity(profile) information
aws sts get-caller-identity

# sts(security token service) : display identity(profile) information [--profile:]
aws sts get-caller-identity --profile <profile>

# sso : login sso
aws sso login --profile <profile> && export AWS_PROFILE=<profile>

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

# organization : display organization account
aws organizations describe-organization

# organization : display organization id [Organization.Id = o-xxx][Organization.MasterAccountId = YYYYYYYYYYYY(12)]
aws organizations describe-organization --query '<organization_id>' --output text

# log : display log groups
aws logs describe-log-groups --query 'logGroups[].logGroupName' | jq -r '.[]'

# log : display log streams [--log-stream-name-prefix:filter name prefix]
LOG_GROUP=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' | jq -r '.[]' | fzf) && aws logs describe-log-streams --log-group-name "$LOG_GROUP"

# awslogs : [--start=<time> ex.2m,5h,1d,2w,YYYY/MM/DD]
LOG_GROUP=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' | jq -r '.[]' | fzf) && awslogs get "$LOG_GROUP" --timestamp --start=6h | lnav -c ':set-text-view-mode raw'

# aws option : [--filter:filter by server][--query: filter by client(jq)][--output:text,json,table]
<option>
; https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/cli-usage-filter.html#cli-usage-filter-combining
; https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/cli-usage-output-format.html
```

$ profile: aws configure list-profiles
$ organization_id: echo -n 'Organization.Id\nOrganization.MasterAccountId'
$ option: echo -n '--filter\n--query\n--output'
;$
