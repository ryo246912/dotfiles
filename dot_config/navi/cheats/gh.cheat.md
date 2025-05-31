```sh
% gh

# pr list search[--search:1)commithash,2)'created:<2011-01-01',3)'word in:title''word in:title,body',4)'involves:USERNAME',5)'reviewed-by:USERNAME'][--author:USERNAME][-s:open|closed|merged|all][--limit:--state all --limit 100]
gh pr list --author "" --assignee "" --search "<pr_search>" --state all --limit 100
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName
  --jq '
    ["no","title","author","state","draft","updatedAt","createdAt","branch"],
    ( .[] |
    [.number
    , .title[0:50]
    , .author.login
    , .state
    , (if .isDraft then "◯" else "☓" end )
    , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))
    , (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))
    , .headRefName])
    | @tsv
  ' \
  | column -ts $'\t' \
  | fzf --no-sort --header-lines=1

# pr view search[-s:open|closed|merged|all][--search:1)commithash,2)'created:<2011-01-01',3)'word in:title''word in:title,body',4)'involves:USERNAME',5)'reviewed-by:USERNAME']
for no in <pr_nos>; do
  gh pr view $no --comments -w;
done

# pr view search by file [-L <start>,<end>:<file>(ex:-L 10,+10:sample.py) : select line][-L :<func>:<file>(ex: :SampleClass:sample.py) : select func]
for commit in <commits_filter_by_file>; do
  gh pr view -w $(gh pr list --state "all" --search "$commit base:master" | head -n 1 | awk '{print $1}');
done

# pr view search by word [--pickaxe-regex -S:filter by word(regex) count][-G:filter by regex change line]
for commit in <commits_filter_by_word>; do
  gh pr view -w $(gh pr list --state "all" --search "$commit base:master" | head -n 1 | awk '{print $1}');
done

# pr create [--base:base-branch][--assignee "@me":assign me]
gh pr create --base "<base_branch>" --assignee "@me" --body-file "<pr_body>"

# pr review
gh pr review <pr_review_no>

# issues create[--assignee "@me":assign me]
gh issue create --assignee "@me" --body-file "<issue_body>"

# issues list search [owner:repository owner(ex:pytorch)][repository:repository name(ex:pytorch/pytorch)]
gh issue list --repo "<repository>" --search "<issue_search>" --state all --limit 100

# issues view search [repository:repository name(ex:pytorch/pytorch)]
for no in <issue_nos>; do
  gh issue view $no --repo "<repository>" --comments -w;
done

# list repository [owner:repository owner(ex:pytorch)][-L:max num]
gh repo list <owner> -L 100

# display repository [owner:repository owner(ex:pytorch)]
gh repo view <repository> -w

# create repository [--private,--public]
gh repo create <name> --private --push --source=.

# fork repository
gh repo fork <repository>

# project view [owner:repository owner(ex:pytorch)]
gh project view --owner <owner> -w <project_no>

# project list [owner:repository owner(ex:pytorch)][-L:max num]
gh project list --owner <owner> -L 100

# project item-list [owner:repository owner(ex:pytorch)][-L:max num]
gh project item-list --owner <owner> --format json -L 100 <project_no> | jq -r '["repo","no","type","status","assignee","title","url"] , (.items[] | [.content.repository,.content.number, .content.type ,(if has("status") then .status else "-" end), .assignees[0], .title , .content.url]) | @tsv' | column -ts $'\t'

# display authentication state[auth scope ex:gist,read:org,read:project,repo]
gh auth status
; https://docs.github.com/ja/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps

# add authentication [ex:gh auth refresh -s project]
gh auth refresh -s <scope>

# cache list
gh cache list

# open repository in the web browser[--branch:][ex.gh browse --branch "main",gh browse --settings]
gh browse<_browse_option>

# project item
open-cli <issue_url>

# display user star
gh api graphql<_--paginate> -f username="<username>" -f query='
  query ($username: String!, $endCursor: String) {
    user(login: $username) {
      starredRepositories(first: 100, after: $endCursor, orderBy: {field: STARRED_AT, direction: DESC}) {
        pageInfo {
          endCursor
          hasNextPage
        }
        nodes {
          name
          url
          description
          stargazerCount
          pushedAt
          languages(first:1) {
            nodes {
              name
            }
          }
        }
      }
    }
  }' \
  | jq -r -s '
     .[] |
    .data.user.starredRepositories.nodes[] |
    [
        .name,
        (.languages.nodes[0]?.name // "-"),
        (.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d_%H:%M:%S")),
        .stargazerCount,
        .url,
        .description
    ]
  | @tsv' \
  | column -ts $'\t' \
  | fzf --no-sort \
  | awk '{print $5}' \
  | xargs open-cli

# search repo [_query|stars:>=n|stars:<n]
open-cli <repo_url>
```
$ pr_search: echo -e "\
  user-review-requested:@me\n\
  reviewed-by:@me\n\
  involves:@me\n\
  <keyword> in:title\n\
  <keyword> in:title,body\n\
  <keyword> in:comment\n\
  base:$(git rev-parse --abbrev-ref origin/HEAD | sed 's|^origin/||')\n\
  mentions:@me\n\
  $(gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq -r '(.[] | "involves:\(.login)"+"\n"+"author:\(.login)" )')\
  " \
  | awk '{$1=$1; print}'
$ issue_search: echo -e "\
  <keyword> in:title\n\
  <keyword> in:title,body\n\
  <keyword> in:comment\n\
  is:open\n\
  is:closed\
  " \
  | awk '{$1=$1; print}' \
  --- --multi
; https://docs.github.com/ja/search-github/searching-on-github/searching-issues-and-pull-requests
$ base_branch: echo -e "$(git config branch.$(git symbolic-ref --short HEAD).base-branch | sed 's/^origin\///')\nmaster\nmain"
$ pr_body: find ~/private/Pull-Request -type f -path "*.md" | sort
$ issue_body: find ~/private/Issue -type f -path "*.md" | sort
$ user: echo -e "\n$(git config --get-all user.name)"
$ _-m_--merges_--first-parent : echo -e "\n -m --merges --first-parent"
$ file_option: echo -e "-- \n-L 1,+10:\n-L :func:"
$ search_option: echo -e "--pickaxe-regex -S\n-G"
$ _browse_option: echo -e "\n --settings\n --branch ''\n --commit ''"
$ _--paginate: echo -e "\n --paginate"
$ ls-files: git ls-files

$ commits_filter_by_file: git log<_-m_--merges_--first-parent> \
  --pretty=format:"%h; (%cd)%d [%an] %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  <file_option><ls-files> \
  --- --column 1 --delimiter ; --multi --expand
$ commits_filter_by_word: git log<_-m_--merges_--first-parent> \
  --pretty=format:"%h; (%cd)%d [%an] %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  <search_option> "<regex>" \
  --- --column 1 --delimiter ; --multi --expand
$ pr: gh pr list --state all --limit 100 \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq ' \
    ["no","title","author","state","draft","updatedAt","createdAt","branch"], \
    ( .[] | \
    [.number \
    , .title[0:50] \
    , .author.login \
    , .state \
    , (if .isDraft then "◯" else "☓" end ) \
    , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) \
    , (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) \
    , .headRefName]) \
    | @tsv \
  ' \
  | column -ts $'\t' \
  --- --headers 1
$ pr_no: echo "<pr>" --- --column 1
$ pr_nos: gh pr list --author "" --search "<pr_search>" --state all --limit 100 \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq ' \
    ["no","title","author","state","draft","updatedAt","createdAt","branch"], \
    ( .[] | \
    [.number \
    , .title[0:50] \
    , .author.login \
    , .state \
    , (if .isDraft then "◯" else "☓" end ) \
    , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) \
    , (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) \
    , .headRefName]) \
    | @tsv \
  ' \
  | column -ts $'\t' \
  --- --headers 1 --column 1 --multi --expand
$ issue_nos: gh issue list --repo "<repository>" --search "<issue_search>" --state all --limit 100 \
   --json number,title,state,createdAt \
   --jq ' \
     ["no","title","state","createdAt"], \
     ( .[] | \
     [.number \
     , .title[0:200] \
     , .state \
     , (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ]) \
     | @tsv \
   ' \
  | column -ts $'\t' \
  --- --headers 1 --column 1 --multi --expand
$ repository: gh search repos --sort stars --match name <repo_name> \
  --json fullName,stargazersCount,pushedAt,description \
  --jq '\
    ["repo","stars","pushedAt","description"] \
    , ( .[] | \
    [.fullName \
    ,.stargazersCount \
    ,(.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) \
    ,.description[0:50] \
    ]) | @tsv \
  '\
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ project_no: gh project list --owner <owner> \
  | column -ts $'\t' \
  --- --column 1
$ issue_url: gh project item-list --owner <owner> --format json -L 100 <project_no> \
  | jq -r '(.items[] | [.content.repository,.content.number, .content.type ,(if has("status") then .status else "-" end), .assignees[0], .title , .content.url]) ,["repo","no","type","status","assignee","title","url"] | @tsv' \
  | tail -r \
  | column -ts $'\t' \
  --- --headers 1 --column 7
$ repo_url: gh search repos "<word><_query>" --sort stars --limit 100 \
  --json fullName,description,language,pushedAt,stargazersCount,url \
  --jq '["repo","language","pushedAt","star","url","description"], (.[] | [.fullName,(if .language != "" then .language else "-" end),(.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")),.stargazersCount,.url,.description]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 5

```sh
% gh-rest-api

# list organization members [per_page:numbers]
gh api "/orgs/<org>/members?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/orgs/members?apiVersion=2022-11-28#list-organization-members

# list contributors [per_page:numbers] [api:/repos/{owner}/{repo}/contributors]
gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/repos/repos?apiVersion=2022-11-28#list-repository-contributors

# search [q:query ex:q=windows+label:bug+language:python+state:open&sort=created&order=asc]
gh api "/search/issues?q=<commithash>+type:pr+repo:$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')" | jq -r '.items[] | [.number , .title , .user.login , (.created_at | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ] | @tsv' | column -ts $'\t'
; https://docs.github.com/ja/rest/search/search?apiVersion=2022-11-28#search-issues-and-pull-requests
; https://docs.github.com/ja/search-github/searching-on-github/searching-issues-and-pull-requests

# user star [per_page:numbers]
gh api "/users/<user>/starred?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/activity/starring?apiVersion=2022-11-28#list-repositories-starred-by-a-user
```

$ xxx: echo xxx
;$
