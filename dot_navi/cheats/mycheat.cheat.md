```sh
% shortcut

# my shortcut list
cat ~/.shortcut/my_shortcut.csv | column -t -s, | fzf --no-sort
```
;--------------------------------------------------------------
; asdf
;--------------------------------------------------------------
```sh
% asdf

# plugin added list
asdf plugin list --urls

# plugin list all
asdf plugin list all | vim -

# plugin add [ex:asdf plugin add <name> <git-url>]
asdf plugin add <name> <git-url>

# install [ex:asdf install <name> <version>]
asdf install <name> <version>

# installed list [ex:asdf list <name>]
asdf list <name>

# current
asdf current

# set version in shell section [ex:asdf shell <name> <version>]
asdf shell <name> <version>

# which command
asdf which <command>
```
;--------------------------------------------------------------
; cspell
;--------------------------------------------------------------
```sh
% cspell

# lint [-c:config file][-e:exclude file]
cspell --no-progress -c ~/.cspell/cspell.json --gitignore . | vim -

# lint base-branch...HEAD [--root:root directory, defaults=current directory]
cspell --no-progress -c ~/.cspell/cspell.json --root ~ $(git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ $(git show-branch --merge-base master HEAD)...HEAD)

# search(show) dictionary [The word is found in a dictionary if * appears ex:sql *php]
cspell trace "<word>"
```
;--------------------------------------------------------------
; django
;--------------------------------------------------------------
```sh
% django

# show migration
python manage.py showmigrations

# show migration app [ex:python manage.py showmigrations issues]
python manage.py showmigrations <app_name>

# make migration
python manage.py makemigrations --name <name>

# migrate [ex:python manage.py migrate concierges 0031]
python manage.py migrate <app_name> <migration_name>

# check migration [ex:python manage.py sqlmigrate issues 0035]
python manage.py sqlmigrate <app_name> <migration_name>

# rollback migration [ex:python manage.py migrate concierges 0031]
python manage.py migrate <app_name> <rollback_to_migration_name>
```
;--------------------------------------------------------------
; docker
;--------------------------------------------------------------
```sh
% docker

# exec [ex:docker container exec -it <container_id> bash]
docker container exec -it <container_id> <command>

# ps [-a:all]
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.RunningFor}}"

# image list [-a:all]
docker images -a --format "table {{.Repository}}:{{.Tag}}\t{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"

# network list
docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.CreatedAt}}"

# inspect container
docker inspect <container_id> | vim -

# inspect image
docker image inspect <image_id> | vim -

# inspect network
docker network inspect <network_id> | vim -

# disk free
docker system df

# disk image [-s:file block size][-k:KB][file:Docker.raw or Docker.qcow2]
ls -sk ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw

# display no referenced images [-f:filter (dangling=not referenced by any containers)]
docker images -f dangling=true

# display no referenced volume [-f:filter (dangling=not referenced by any containers)]
docker volume ls -f dangling=true

# remove no referenced images [-q:only display volume names] [ex:docker rmi <image_id>]
docker rmi $(docker images -q -f dangling=true)

# remove container
docker rm <container_id>

# remove no referenced volume [-q:only display volume names]
docker volume rm $(docker volume ls -q -f dangling=true)

# remove(container/image/build cache)
docker system prune

# remove network
docker network prune

# remove unused build cache
docker builder prune

# run(create container&command) [-d:run background][-i:wait stdin][-t:tty][ex:docker run -it -d ubuntu:22.04 bash]
docker run -it -d --name <name> <image_id> <command>

# build[-t:tag][ex:docker run -it -d ubuntu:22.04 bash]
docker build -t <name> <image_id> <command>

```
$ container_id: docker ps -a \
  --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.RunningFor}}" \
  --- --headers 1 --column 1
$ network_id: docker network ls \
  --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.CreatedAt}}" \
  --- --headers 1 --column 1
$ image_id: docker images -a \
  --format "table {{.Repository}}:{{.Tag}}\t{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" \
  --- --headers 1 --column 1
;$

;--------------------------------------------------------------
; docker compose
;--------------------------------------------------------------
```sh
% docker compose

# ls [--all]
docker-compose ls --all

# ps [--all]
docker-compose -p <project> ps --all

# start
docker-compose -p <project> start <service>

# restart
docker-compose -p <project> restart <service>

# stop
docker-compose -p <project> stop <service>

# down
docker-compose -p <project> down <service>

# exec [--project-directory:][--env KEY=VALUE][--env-file:]
docker-compose -p <project> exec <service> <command>
```
$ project: docker-compose ls --all \
  --- --headers 1 --column 1
$ service: docker-compose -p <project> ps --all \
  --- --headers 1 --column 3

;--------------------------------------------------------------
; gcloud
;--------------------------------------------------------------
```sh
% gcloud

# display current config
gcloud config list

# display configs list
gcloud config configurations list

# display config
gcloud config configurations describe <name>

# switch config
gcloud config configurations activate <name>

# create config [ex:gcloud config configurations create staging]
gcloud config configurations create <name>

# set config [ex:gcloud config set compute/zone asia-northeast1-a]
gcloud config set <section>/<property> <value>
```
$ name: gcloud config configurations list \
  | awk '{print $1}' \
  --- --headers 1

;--------------------------------------------------------------
; git
;--------------------------------------------------------------
```sh
% git

# diff option [--no-pager][--pickaxe-regex -S:filter by word(regex) count][-G:filter by regex change line][--no-patch:not display diff][-U(--unified):display num line ex:git diff -U0][--no-renames:ignore rename file][-M -- file1 file2:rename file diff]
git --no-pager diff --pickaxe-regex -S <regex> -U0

# diff staging file [--cached(staged):diff staging and commit][--stat/numstat/patch-with-stat:show stat]
git diff --cached<_stat> -- <staging_filename> | delta<_no-gitconfig>

# diff between base-branch...HEAD
git diff<_--name-only> $(git show-branch --merge-base <base_branch> HEAD)...HEAD -- <base-head_diff_filename> | delta<_no-gitconfig>

# diff between commits [ex:master...HEAD]
git diff<_--name-only> <commit1>...<commit2> | delta<_no-gitconfig>

# diff between commits filter by file [ex:master...HEAD]
git diff<_--name-only> <commit1>...<commit2> -- <commit1-commit2_filename> | delta<_no-gitconfig>

# diff between merge commit
git diff<_--name-only> HEAD~1...HEAD | delta<_no-gitconfig>

# show commit [--stat/numstat/patch-with-stat:show stat]
git show <commit1><_stat> | delta<_no-gitconfig>

# show commit file
git show <commit1>:<git_filename>

# show commit (contributor)
git show <contributor_commit> | delta<_no-gitconfig>

# show parents commit [ex:git show HEAD^^,HEAD~2]
git show HEAD~<num> | delta<_no-gitconfig>

# show children commit [ex:git show HEAD^^,HEAD~2]
git show $(git log -n $((<num>+1)) --pretty=format:"%h" HEAD^...HEAD | tail -n 1) | delta<_no-gitconfig>

# cherry-pick
git cherry-pick -n <cherry_commit>

# cherry-pick file
git checkout <commit1> <diff_filename>

# create branch
git branch <branch_name> <commit1>

# create branch & checkout
git checkout -b <branch_name> <commit1>

# set upstream branch [-u:upstream branch] [ex:git branch -r origin/feature-branch]
git branch -u origin/$(git symbolic-ref --short HEAD)

# branch list
git for-each-ref --sort=-committerdate --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t' | vim -

# restore(default)
git checkout <checkout_commit>

# merge dry-run
git merge --no-commit --no-ff <all_branch> && git diff --cached --name-only

# commit fixup
git commit --fixup <commit1>

# commit default message
git commit --no-edit

# rename git file/directory
git mv <ls-files> <ls-files>

# rename local branch
git branch -m <branch> <branch>

# rename remote branch
git push origin :<branch> <branch>

# revert
git revert <commit1>

# revert merge commit [-m:mainline parent-number(1,2..)]
git revert -m 1 <commit1>

# reset recent commit
git reset --soft HEAD^

# clear working directory file
git checkout <modified_files>

# clear working directory
git checkout . && git clean -f

# clear staging
git reset --mixed HEAD

# list tag [-l "pattern":list]
git tag -l "*<tag_search>*" --sort=-creatordate --format='%(if) %(*objectname) %(then) %(*objectname:short) %(else) %(objectname:short) %(end) %09 %(objecttype) %09 %(refname:short) %09 %(creatordate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | head -n 5 | column -ts $'\t'

# create tag [-a:annotated][-m:message][ex:git tag -a v1.0 -m 'message']
git tag <tag_name>

# push tag [--tag:push all tag][ex:git push origin v1.0]
git push origin --tag

# delete branch
git branch --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t' | fzf | awk '{print $1}' | grep -vE '^\*|master$' | xargs -I % git branch -<delete_flag> %

# delete branch --merged
git branch --merged origin/master --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t' | fzf | awk '{print $1}' | grep -vE '^\*|^archived.*|master$' | xargs -I % git branch -D %

# delete remote branch
git push origin :<branch>

# rebase
git rebase --autosquash -i <commit1>

# git grep [-i:ignore upper&lower][-P:perl regex]
git grep -iP "<regex>" <grep_commit> -- <dir>

# git grep look{ahead,behind} regex [positive ahead:X(?=Y)] [negative ahead:X(?!Y)][positive behind:(?<=Y)X][negative behind:(?<!Y)X]
git grep -P "<look_regex>" <grep_commit> -- <dir>

# git grep only filename [-l:only filename]
git grep -lP "<regex>" <grep_commit> -- <dir>

# git grep not match [-v:output not match]
git grep -lvP "<regex>" <grep_commit> -- <dir>

# git grep between commit [-i:ignore upper&lower]
git grep -iP "<regex>" $(git rev-list <commit1>...<commit2>) --

# git grep files
git grep -iP "<regex>" $(git rev-list master -- <ls-tree-files>) -- <ls-tree-files>

# git-jump grep
() { local hash_file_num ; hash_file_num=$(<git_grep_command> | cut -d ' ' -f 1 | rev | cut -c 2- | rev | fzf) && git cat-file -p $(echo $hash_file_num | cut -d : -f -2) | vim +$(echo $hash_file_num | cut -d : -f 3-) -}

# cat-file
git cat-file -p <commit1>:<ls-tree-files><_pipe>

# log contributor
git log -n 30 --author="<contributor>" --all --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s" --date=format:"%Y/%m/%d %H:%M:%S"

# log graph
git log --date-order --graph --pretty=format:"%C(auto)%>|(60)%h (%C(blue)%cd%C(auto)) %<(15,trunc)%cN%d %s" --date=format:"%Y/%m/%d %H:%M:%S" <all_branch>

# log file [-L <start>,<end>:<file>(ex:-L 10,+10:sample.py) : select line][-L :<func>:<file>(ex: :SampleClass:sample.py) : select func]
git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d [%C(magenta)%an%C(auto)] %s" --date=format:"%Y/%m/%d %H:%M:%S" <all_branch> <file_option><ls-files>

# log change word or line [--pickaxe-regex -S:filter by word(regex) count][-G:filter by regex change line]
git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d [%C(magenta)%an%C(auto)] %s" --date=format:"%Y/%m/%d %H:%M:%S" <search_option> <regex>

# log delete file
git log --diff-filter=D --name-only --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s" --date=format:"%Y/%m/%d %H:%M:%S"

# stash working file
git commit -m 'commit staging' && git stash --message "<message>" -- <working_filename> && git reset --soft HEAD^

# stash file
git stash --message "<message>" -- <working_filename>

# list stash
git stash list

# show stash [-p:patch]
git stash show <stash_num> -p

# pop stash
git stash pop <stash_num>

# pop stash file
git checkout <stash_num> <stash_file>

# clone [--depth:shallow clone][--filter=blob:none ;blob-less clone][--filter=tree:0 ;tree-less clone]
git clone<_shallow-option> <repo_url>

# config list [-l:list]
git config -l --show-origin<_--option> | column -ts $'\t'

# meta : display HEAD branch
git symbolic-ref --short HEAD

# meta : display merge-base [ex:git merge-base master HEAD]
git merge-base <base_branch> HEAD

# meta : display HEAD hash [HEAD^@:all parents]
git rev-parse --short HEAD

# meta : display relative path to git top-level directory
git rev-parse --show-cdup

# meta : display relative path to pwd
git rev-parse --show-prefix

# meta : display absolute path to git top-level directory
git rev-parse --show-toplevel
```
$ _no-gitconfig: echo -e " --no-gitconfig\n"
$ _--name-only: echo -e "\n --name-only\n --name-status"
$ _--option: echo -e "\n --global\n --local\n --system"
$ _stat: echo -e "\n --stat\n --numstat\n --patch-with-stat"
$ _shallow-option: echo -e "\n --depth 1\n --filter=blob:none\n --filter=tree:0"
$ tag_search: echo -e "staging\nrelease"
$ delete_flag: echo -e "d\nD"
$ base_branch: echo -e "\nmaster"
$ file_option: echo -e "-- \n-L 1,+10:\n-L :class:"
$ search_option: echo -e "--pickaxe-regex -S\n-G"
$ look_regex: echo -e "<search_word>(?=(<look_word>))\n<search_word>(?!(<look_word>))\n(?<=(<look_word>))<search_word>\n(?<!(<look_word>))<search_word>"

$ commit1: git log <branch> \
  --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  --- --column 1 --delimiter ; \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ commit2: git log <branch> \
  --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  --- --column 1 --delimiter ; \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ cherry_commit: git log <branch> \
  --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  --- --column 1 --delimiter ;  --multi --expand \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ contributor_commit: git log --all --author="<contributor>" \
  --pretty=format:"%C(auto)%h; (%Cblue%cd%C(auto)) %<(15,trunc)%cN%d %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  --- --column 1 --delimiter ; \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ checkout_commit: git branch | awk '{print $NF}' ; \
  git log <branch> \
  --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  --- --column 1 --delimiter ; \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ branch: cat \
  <(git rev-parse --abbrev-ref HEAD) \
  <(git branch --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t') \
  --- --column 1
$ all_branch: cat \
  <(git rev-parse --abbrev-ref HEAD) \
  <(git branch -a --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t') \
  --- --column 1
$ contributor: git log --format="%cn:%ce" \
  | sort -fu \
  | column -ts ":" \
  --- --column 1
$ grep_commit: git log <branch> \
  --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" -- <ls-files> \
  --- --column 1 --delimiter ; \
  --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ dir: git ls-tree <grep_commit> --name-only -dr
$ stash_num: git stash list \
  --- --column 1 --delimiter : \
  --preview "git stash show {1} ; git stash show {1} -p | delta --no-gitconfig"
$ stash_file: echo . && \
  git stash show --name-only <stash_num> \
  --- --multi --expand
$ modified_files: echo . && \
  git ls-files -m \
  --- --multi --expand
$ ls-files: git ls-files
$ ls-tree-files: git ls-tree --name-only --full-name -r <commit1> $(git rev-parse --show-toplevel)
$ extension: echo <ls-tree-files> | sed 's/^.*\.\([^\.]*\)$/\1/'
$ _pipe: echo -e " | bat -l <extension>\n > <ls-tree-files>"
$ base-head_diff_filename: git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ $(git show-branch --merge-base <base_branch> HEAD)...HEAD \
  | xargs -I % echo "<base_branch>;%" \
  --- --delimiter ; --column 2 \
  --preview "git diff $(git show-branch --merge-base {1} HEAD)...HEAD -- {2} | delta --no-gitconfig"
$ commit1-commit2_filename: echo . && \
  git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ <commit1>...<commit2> \
  --- --multi --expand
$ git_filename: git ls-tree -r --name-only <commit1>
$ diff_filename: git diff --name-only <commit1> \
  | xargs -I % echo "<commit1>;%" \
  --- --delimiter ; --column 2 \
  --preview "git show {1}:{2} | delta --no-gitconfig"
$ working_filename: echo . && \
  git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ HEAD \
  --- --multi --expand \
  --preview "git diff HEAD -- {1} | delta --no-gitconfig"
$ staging_filename: echo . && \
  git diff --cached --name-only --line-prefix=$(git rev-parse --show-toplevel)/ \
  --- --multi --expand \
  --preview "git diff --cached -- {1} | delta --no-gitconfig"
$ repo_url: gh search repos "<word><_query>" --sort stars --limit 100 \
  --json fullName,description,language,pushedAt,stargazersCount,url \
  --jq '["repo","language","pushedAt","star","url","description"], (.[] | [.fullName,(if .language != "" then .language else "-" end),(.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")),.stargazersCount,.url,.description]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 5

```sh
% git-tool

# dura serve
dura serve | jq '"\(.time) \(.fields.operation.Snapshot.op.commit_hash) \(.fields.operation.Snapshot.repo)"'

# dura watch
(cd $(z | sort -rn | cut -c 12- | fzf) && ghq list --full-path | xargs -I % sh -c "cd % && dura watch")

# dura unwatch
(cd $(z | sort -rn | cut -c 12- | fzf) && ghq list --full-path | xargs -I % sh -c "cd % && dura unwatch")

# dura delete branch [optional:git branch -l "dura*" | grep -vE "dura/$(git rev-parse HEAD)"]
git branch -l "dura*" | xargs -I % git branch -D %

# ghq clone [ex:ghq get x-motemen/ghq , ghq get https://github.com/x-motemen/ghq]
ghq get <url>
```

;--------------------------------------------------------------
; GitHub
;--------------------------------------------------------------
```sh
% gh

# pr list [-s:open|closed|merged|all]
gh pr list --author "<author>" --assignee "" --search "<search>" --state <state>

# pr branch copy
echo -n <pr_branch> | cb

# pr view [--author:USERNAME][--search:commithash,'created:<2011-01-01',''word in:title,body ','involves:USERNAME','reviewed-by:USERNAME'][-s:open|closed|merged|all]
gh pr view <pr_no> --comments<_web>
; https://docs.github.com/ja/search-github/searching-on-github/searching-issues-and-pull-requests

# pr view search by file [-L <start>,<end>:<file>(ex:-L 10,+10:sample.py) : select line][-L :<func>:<file>(ex: :SampleClass:sample.py) : select func]
for commit in <commits_filter_by_file>; do gh pr view -w $(gh pr list --state "all" --search "$commit base:master" | head -n 1 | awk '{print $1}') ; done

# pr view search by word [--pickaxe-regex -S:filter by word(regex) count][-G:filter by regex change line]
for commit in <commits_filter_by_word>; do gh pr view -w $(gh pr list --state "all" --search "$commit base:master" | head -n 1 | awk '{print $1}') ; done

# pr diff
gh pr view <pr_no> | sed -n 11,12p ; read ; gh pr diff <pr_no><_--name-only> | delta<_no-gitconfig>

# pr checks
gh pr checks <pr_no><_--watch><_web>

# pr checkout
gh pr checkout <pr_no>

# pr create [--base:base-branch]
gh pr create --base <base_branch>

# pr edit
gh pr edit <pr_my_no>

# pr review
gh pr review <pr_review_no>

# status
gh status

# pr & issue status
gh pr status ; gh issue status

# issues view
gh issue view <issue_no> --comments<_web>

# issues create
gh issue create

# issues list(HOST)
gh issue list --assignee "<author>" --state <state>

# issues list [owner:repository owner(ex:pytorch)][repository:repository name(ex:pytorch/pytorch)]
gh issue list --repo "<repository>" --state <state> --search "<search>"

# workflow summary view
gh workflow view<_web>

# workflow list [-w:filter workflow][--branch:filter branch][--user:filter user]
gh run list -L 100 -w "<workflow>" --user "<author>"

# workflow view [-v:show job steps][--log,--log-failed:view log]
gh run view <run_id> -v <_web><_--log_>--job=<job_id>

# workflow watch
gh run watch <run_id>

# workflow rerun error
gh run rerun <run_id> --failed

# list repository [owner:repository owner(ex:pytorch)][-L:max num]
gh repo list <owner> -L 100

# display repository [owner:repository owner(ex:pytorch)]
gh repo view <repository> -w

# project list [owner:repository owner(ex:pytorch)][-L:max num]
gh project list --owner <owner> -L 100

# project item-list [owner:repository owner(ex:pytorch)][-L:max num]
gh project item-list --owner <owner> --format json -L 100 <project_no> | jq -r '["repo","no","type","status","assignee","title","url"] , (.items[] | [.content.repository,.content.number, .content.type ,(if has("status") then .status else "-" end), .assignees[0], .title , .content.url]) | @tsv' | column -ts $'\t'

# project item
open-cli <issue_url>

# display user star
open-cli <starred_url>

# search repo [_query|stars:>=n|stars:<n]
open-cli <repo_url>
```
$ author: echo -e "\n@me\n$(gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq -r '(.[] | .login )')"
$ search: echo -e "\nuser-review-requested:@me\nreviewed-by:@me\ninvolves:@me\n$(gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq -r '(.[] | "involves:"+.login )')"
$ approve_comment: echo -e "\n--comment\n--request-changes\n--approve"
$ _no-gitconfig: echo -e " --no-gitconfig\n"
$ _--watch: echo -e "\n --watch"
$ _--name-only: echo -e "\n --name-only"
$ state: echo -e "open\nall\nclosed\nmerged"
$ _web: echo -e "\n -w"
$ base_branch: echo -e "\nmaster"
$ _--log_: echo -e "\n --log \n --log-failed "
$ user: echo -e "\n$(git config --get-all user.name)"
$ _--first-parent: echo -e "\n --first-parent"
$ file_option: echo -e "-- \n-L 1,+10:\n-L :func:"
$ search_option: echo -e "--pickaxe-regex -S\n-G"
$ ls-files: git ls-files
$ all_branch: cat \
  <(git rev-parse --abbrev-ref HEAD) \
  <(git branch -a --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t') \
  --- --column 1

$ commits_filter_by_file: git log --no-patch<_--first-parent> \
  --pretty=format:"%h; (%cd)%d [%an] %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  <all_branch> <file_option><ls-files> \
  --- --column 1 --delimiter ; --multi --expand
$ commits_filter_by_word: git log --no-patch<_--first-parent> \
  --pretty=format:"%h; (%cd)%d [%an] %s" --date=format:"%Y/%m/%d %H:%M:%S" \
  <search_option> <regex> \
  --- --column 1 --delimiter ; --multi --expand
$ pr_no: gh pr list --author "<author>" --search "<search>" --state <state> --limit 100 \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq '["no","title","author","state","draft","updatedAt","createdAt","branch"], (.[] | [.number , .title , .author.login , .state , (if .isDraft then "◯" else "☓" end ) , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) , .headRefName]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ pr_branch: gh pr list --search "user-review-requested:@me" --state open \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq '["no","title","author","state","draft","updatedAt","createdAt","branch"], (.[] | [.number , .title , .author.login , .state , (if .isDraft then "◯" else "☓" end ) , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) , .headRefName]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 8
$ pr_my_no: gh pr list --author "@me" --state <state> --limit 100 \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq '["no","title","author","state","draft","updatedAt","createdAt","branch"], (.[] | [.number , .title , .author.login , .state , (if .isDraft then "◯" else "☓" end ) , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) , .headRefName]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ pr_review_no: gh pr list --search "user-review-requested:@me" --state open \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq '["no","title","author","state","draft","updatedAt","createdAt","branch"], (.[] | [.number , .title , .author.login , .state , (if .isDraft then "◯" else "☓" end ) , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) , .headRefName]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ issue_no: gh issue list --assignee "<author>" --state <state> \
  --json number,title,author,state,updatedAt,createdAt \
  --jq '["no","title","author","state","updatedAt","createdAt"], (.[] | [.number , .title , .author.login , .state , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ workflow: gh workflow list \
  | column -ts $'\t' \
  --- --column 1
$ run_id: gh run list -L 100 -w "<workflow>" --user "<author>" \
  | column -ts $'\t' \
  --- --column 7
$ job_id: gh run view <run_id> --json jobs \
  --jq '["id","name","status","url"] , (.jobs[] | [.databaseId,.name,.status,.url]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1
$ repository: gh repo list <owner> -L 100 \
  --json nameWithOwner,isArchived,isPrivate,pushedAt,description \
  --jq '["repo","isArchived","isPrivate","pushedAt","description"], ( sort_by(.pushedAt) | reverse | .[] | [.nameWithOwner ,(if .isArchived then "◯" else "☓" end),(if .isPrivate then "◯" else "☓" end),(.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")),.description]) | @tsv' \
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
$ starred_url: for page in {1..5}; do result=$(gh api "/users/<user>/starred?per_page=100&page=$page") ; [ -z "$result" ] && break ; echo "$result" ; done | jq -r '(.[] | [.full_name,(.pushed_at | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")),.stargazers_count,.html_url,.description]) | @tsv' | column -ts $'\t' --- --column 4
$ repo_url: gh search repos "<word><_query>" --sort stars --limit 100 \
  --json fullName,description,language,pushedAt,stargazersCount,url \
  --jq '["repo","language","pushedAt","star","url","description"], (.[] | [.fullName,(if .language != "" then .language else "-" end),(.pushedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")),.stargazersCount,.url,.description]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 5

```sh
% gh-rest-api

#  list organization members [per_page:numbers]
gh api "/orgs/<org>/members?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/orgs/members?apiVersion=2022-11-28#list-organization-members

#  list contributors [per_page:numbers] [api:/repos/{owner}/{repo}/contributors]
gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/repos/repos?apiVersion=2022-11-28#list-repository-contributors

#  search [q:query ex:q=windows+label:bug+language:python+state:open&sort=created&order=asc]
gh api "/search/issues?q=<commithash>+type:pr+repo:$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')" | jq -r '.items[] | [.number , .title , .user.login , (.created_at | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ] | @tsv' | column -ts $'\t'
; https://docs.github.com/ja/rest/search/search?apiVersion=2022-11-28#search-issues-and-pull-requests
; https://docs.github.com/ja/search-github/searching-on-github/searching-issues-and-pull-requests

#  user star [per_page:numbers]
gh api "/users/<user>/starred?per_page=100" | jq '.'
; https://docs.github.com/ja/rest/activity/starring?apiVersion=2022-11-28#list-repositories-starred-by-a-user
```

```sh
% gh-tool

# act : list workflows for a specific event [-l:list]
act -l <event>

# act : dry-run workflows for a specific event[-n:dry-run]
act -n <event> -W <workflow>

# act : run workflows for a specific event
act <event> -W <workflow>

```
$ event: echo -e "push\npull_request\nissues"
$ workflow: find .github/workflows

;--------------------------------------------------------------
; mySQL
;--------------------------------------------------------------
```sh
% mySQL

# login [-u:user][-p:database]
echo -n "mysql -u <user> -p <database>" | cb
```
;--------------------------------------------------------------
; node
;--------------------------------------------------------------
```sh
% node

# nodenv display current version & installed versions
nodenv versions

# nodenv installable versions
nodenv install --list | vim -

# nodenv install version
nodenv install <version>
```

```sh
% npm

# display bin directory [ex: $(npm bin)/cspell]
npm bin

# open package files [ex:npm edit axios]
npm edit <package>

# open package homepage [ex:npm home axios]
npm home <package>

# open package repo [ex:npm repo axios]
npm repo <package>

# open package issue page [ex:npm bugs axios]
npm bugs <package>

# prune unnecessary package
npm prune
```

```sh
% npx

# sort package-json
npx sort-package-json
```
;--------------------------------------------------------------
; OSX : macOS
;--------------------------------------------------------------
```sh
% brew

# list [--cask|--formula][-1:one column]
brew list --versions | vim -

# (dry-run) install app [-n:dry-run][ex:brew install -n fzf]
brew install --dry-run <app_name>

# upgrade app
brew upgrade <app>

# app dependence [--tree:][ex:brew deps --tree ruby]
brew deps --tree <app_name>

# display install formula [ex:bat -l rb $(brew edit --print-path ruby)]
bat -l rb $(brew edit --print-path <app_name>)

# open app homegage [ex:brew home colordiff]
brew home <app_name>
```

```sh
% blueutil

# turn on-off bluetooth
blueutil --power <on_off>

# connect device
blueutil --power 1 && blueutil --connect <device>

# disconnect device
blueutil --disconnect <device> && blueutil --power 0

# connect/disconnect device
blueutil --paired --format json-pretty
```
$ on_off: echo -e "1\n0"
$ device: blueutil --paired --format json-pretty \
  | jq -r '["address","name","connected"] , (.[] | [.address , .name , (if .connected then "◯" else "☓" end)]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1

;--------------------------------------------------------------
; python
;--------------------------------------------------------------
```sh
% Python

# delete .pyc files
find . -name \*.pyc -delete;

# http server
python -m http.server 8888

# pyenv display current version & installed versions
pyenv versions

# pyenv installable versions
pyenv install --list | vim -

# pyenv install version
pyenv install <version>
```
;--------------------------------------------------------------
; shell (pipe-command)
;--------------------------------------------------------------
```sh
% shell:pipe-command

# awk : print $no field
awk '{print $<no>}'

# awk : print $no multi field
awk '{print $<no>,$<no2>}'

# awk : print filter [ex:awk '$5 >= 1000 {print $1}'][ex:awk '/^l/ {print $1}']
awk '<condition> {print $<no>}'

# awk : [-F:separater,default=' ']
awk -F "<separator>" '{print $<no>}'

# basename : [-s:remove extension] [ex:basename -s .git repo-name.git]
basename -s <extension> <path>

# bat : [-l:language]
bat -l <extension>

# cat :
bat -

# column : [-t:multi column=determine the number of columns][-s:separater][ex:column -t -s,]
column -t -s<separater>

# column : tab to table
column -ts $'\t'

# column : csv to table
column -ts,

# cut : extract input by bytes [-c:char,-b:byte][cut_list:start-end,start-,-end]
cut -<cb> <cut_list>

# cut : extract input by field [-d:separater,default='\t'][-f:cut by field:no1,no2][ex:cut -f 1,7]
cut -d "<separater>" -f <cut_no>

# dirname : [ex:dirname $(which dirname)]
dirname <path>

# fzf [-m:multi select]
fzf

# less
less

# grep : normal [-r:recursive][-n:output rows number][-E:extend regex,*/+/{n}/(X|Y)][-P:perl regex] [ex: grep -r "navi" ./**/*dot* , grep -E "(X|Y)" apps/**/*.py]
grep -Enr "<regex>" ./**/*

# grep : [-i:ignore upper&lower]
grep -Einr "<regex>" ./**/*

# grep : [-l:only filename] [ex:grep -il "" apps/**/*.py]
grep -Elnr "<regex>" ./**/*

# grep : [-B/A/C n:(before/after/both)output {n} lines] [ex:grep -C 1 -in "" apps/**/*.py]
grep -<line_output_option> <n> -Enr "<regex>" ./**/*

# grep : [-v:output not match]
grep -vEr "<regex>" ./**/*

# head : [-n:output number]
head -n <num>

# jq : [-r:raw output]['.[]':expand array]['.[i:j]':expand array]['.key1,.key2':expand value]
jq -r '.'

# sed : replace [-e:multi command][ex:sed 's| |!|'][ex:sed -e 1d -e '$ s/$/\n/']
sed -e 's/<before>/<after>/g'

# sed : extract word [-r:regex \(\) -> ()][¥1:first()][&:word] [ex:sed -r 's/.*github.com.(.*).git/\1/']
sed -r 's/<before>/\1/'

# sed : output selected line [-n:print only applied][ex:sed -n 10,11p]
sed -n <start>,<end>p

# sed : output matched line [-n:print only applied][ex:sed -n /^-/p]
sed -n /<regex>/p

# sed : delete selected line [-e:multi command][ex:sed 1,5d][ex:sed -e 1d -e '$ s/$/\n/']
sed <start>,<end>d

# sed : delete matched line [ex:sed /^d/d]
sed /<regex>/d

# sort : sort [-r:reverse][-n:numeric-sort][-k:field (ex:-k 2)][-t:delimiter (-t ,)][-u:unique] [ex:sort -rn -k 2 -t ,]
sort -nu

# tail : [-n:output number]
tail -n <num>

# tail : [-r:reverse]
tail -r

# tr : replace char [ex:tr 012 abc]
tr <before> <after>

# tr : delete char [ex:tr -d '\n']
tr -d '<char>'

# up
up

# vim
vim -

# wc : word count [-m:count chars][-l:count lines]
wc -lm

# xargs : output to args [-I:arg replace][ex:xargs -I % git branch -d %]
xargs -I % <command> %

# redirect : redirect std output(1>) to other [ex:command 1> stdout.txt]
1>

# redirect : redirect error output(2>) to null [ex:find . 2> /dev/null]
2> /dev/null

# redirect : merge error output(2>) to std output(&1) [ex:ls > file 2>&1]
2>&1

```

$ no: echo -e "1\n(NF-1)\nNF"
$ no2: echo -e "1\n(NF-1)\nNF"
$ cb: echo -e "c\nb"
$ cut_list: echo -e "<start_no>\n<start_no>-<end_no>\n<start_no>-\n-<end_no>"
$ line_output_option: echo -e "A\nB\nC"
;$

;--------------------------------------------------------------
; shell
;--------------------------------------------------------------
```sh
% shell:ssh

# ssh : login by .ssh/config [-T:config HOST][-l:login user][-A:Forward Agent][ex:ssh -A user@example.com]
ssh -AT <HOST>

# ssh-add : add secret key [--apple-use-keychain(ex:-K):add OS keychain store][default=add {id_rsa,id_dsa,identify}]
ssh-add

# ssh-add : display secret key
ssh-add -l

# ssh-keyscan : get public ssh key [ex:ssh-keyscan github.com >> ~/.ssh/known_hosts]
ssh-keyscan <HOST> >> ~/.ssh/known_hosts

# ssh-agent : ssh-add [eval $(ssh-agent):terminate ssh-agent=ssh-agent -k][exec ssh-agent $SHELL:terminate ssh-agent=exit]
eval $(ssh-agent) && ssh-add ~/.ssh/{id_rsa,id_ed25519}

# ssh-agent : terminate ssh-agent [-k:kill]
ssh-agent -k
```

```sh
% shell:jq-script

# if
jq -r '. | (if .<key> then "◯" else "☓" end)'

# key-value output [ex:jq -r '.scripts | to_entries[] | [.key,.value] | @csv']
jq -r '.<key> | to_entries[] | [.key,.value]'

# sort [ex:jq 'sort_by(.updatedAt) | reverse | .[] | [.nameWithOwner ,.updatedAt]']
jq -r 'sort_by(.<key>) | reverse | .[]'

# str + str [ex:jq '"\(.time) \(.fields.operation.Snapshot.op.commit_hash) \(.fields.operation.Snapshot.repo)"']
jq -r '"\(.<key>) \(.<key2>)"'

# format time [ex:(.pushed_at | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))]
jq -r '(.<key> | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))'

# header
jq -r '["<key1>","<key2>"], (.[] | [.<key1> , .<key2>]) | @tsv'
```

```sh
% shell:command

# cal : calendar[-y:year]
cal -3

# cal : calendar
cal <month_year>

# cat : concatenate command output(process substitution)
cat <(<command1>) <(<command2>)

# cat : output file(hear document)
cat << EOF > <filename>
```
```sh
# curl : download file[-O:remote-name][-o:output filename][-s:silence][-S:show error when -s]
curl -sS -O '<url>'

# curl : curl http header[-I:display only header][-H:header ex: -H 'Content-Type: application/json']
curl -sI '<url>' -H '<header>'

# curl : POST [-X:request method][-d:post data ex: -d 'key=value&key2=value2']
curl -X 'POST' '<url>' -H '<header>' -d '<data>'

# chsh : change shell
chsh -s $(which zsh)

# echo args[$@:args(array)][$*:args(string)]
echo $* $@

# echo exit status
echo $?

# df : disk free [--total:linux only][-h:human-readable]
df -h<_--total>

# du : disk usage [-c:display total][-s:display only depth0 directory][-h:human-readable]
du -csh

# find : find path (option) [ex:find . -name "*.app"][-depth,-maxdepth,-mindepth:directory depth][-printf:print format]
find . --depth 1

# find : output directory [-type:d,f,l=link][-path:pathname ex:./app/src/models/users][-not:not operator]
find . -type d -path "*" -not -path ".*"

# find : output file [-type:d,f,l=link][-path:pathname ex:./app/src/models/users][-name:filename ex:user.py][-not:not operator]
find . -type f -path "*" -name "*" -not -name ".*"

# find : output file [-regex:filename regex]
find . -type f -path "*" -regex ".*"

# find : and condition [-a:and]
find . -regex ".*" -a -not -regex ".*"

# find : prune or print [-prune:not search recursively,"condition1 -prune" -o "condition2 -print"][-o:or][-print:default action][-exec:command(ex:-exec sha1sum {} \;)]
find $PWD -type d -path "$PWD/.*" -prune -o -type <file_or_directory> -name "*" -print

# find : exclude ".*" directory&file
find $PWD -type d -path "$PWD/.*" -prune -o -not -name ".*" -type <file_or_directory> -name "*" -print

# kill : [-s:signal,9=KILL,15=TERM(default)]
kill -s <pid>

# killall : [-s:signal,9=KILL,15=TERM(default)][ex:killall mysqld]
killall <command_name>

# ln : link [-s:symbolic][-f:force(overwrite)][-b:create backup][ex:ln -sf ~/.private/.zprofile.secret ~]
ln -s <file> <dir>

# lsof(=list open files) : display file,pid,user[-i:port]
lsof -i:<port>

# ps : [a:other tty process][x:no tty process][u:user-friendly=USER,PID,%CPU,%MEM,VSZ,RSS,TT,STAT,STARTED,TIME,COMMAND]
ps axu | vim -

# ps : [o:format][pgid:process group id][sess:session id]
ps axo pid,ppid,pgid,sess,tty,user,start,command | vim -

# set : set shell option [-o:set option][+o:unset option][ex:set -o noclobber]
set -o <option>

# set : display shell option command
set +o

# tar : display contents [-t(--list):display content][-v:verbose][-f:archive file][ex:tar -tvf libs.tar.gz]
tar -tvf <file>

# tar : create archive [-c:create archive][-z(--gzip):extract or compress gzip][ex:tar -czvf libs.tgz *]
tar -czvf <name>.<extension> *

# tar : extract archive [-x:extract archive][ex:tar -xzvf libs.tgz "*.txt"]
tar -xzvf <file>

# type : [a:all][ex:type -a python]
type -a <command>

# unset : unset shell variable
unset <var>
```

$ _--total: echo -e "\n --total"
$ header: echo -e "\naccept: application/json\nCookie: X-CSRF-Token="
$ file_or_directory: echo -e "f\nd"
;$ file: find $PWD -type d -path "$PWD/.*" -prune -o -not -name ".*" -type f -name "*" -print
;$ dir: find $PWD -type d -path "$PWD/.*" -prune -o -not -name ".*" -type d -name "*" -print
$ extension: echo -e "tar.gz\ntgz"
;$
;--------------------------------------------------------------
; shell : macOS
;--------------------------------------------------------------

```sh
% shell:macOS

# display system defaults
defaults read | vim -

# display running application
lsappinfo list | vim -

# display macOS version
sw_vers

# display system profile
system_profiler <datatype>

# kill Finder
defaults write com.apple.Finder QuitMenuItem -boolean true && killall Finder

# delete cache memory
sudo purge

# open app(macOS)
open-cli <url_or_file> -- <app>
```
$ datatype : system_profiler -listDataTypes \
  --- --multi --expand
$ app : system_profiler "SPApplicationsDataType" -json \
  | jq -r '["app","path"] ,(.SPApplicationsDataType[] | [._name , .path]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 2

```sh
% shell:display

# display shells
cat /etc/shells

# display linux os version
cat /etc/os-release

# display kernel version
uname -a
```

```sh
% shell:syntax

# array [${array[@]}:array][${array[*]}:string][${#array[@]}:items]
() {local array ; array=(0 1 2 3 4 5) && for i in "${array[@]}"; do echo "item:$i" ; done && for i in "${array[*]}"; do echo "string:$i" ; done && echo "item_no:${#array[@]}" }

# if
if <condition> ; then <true_command> ; else <false_command> ;fi

# if : [a != b:not equal][-n "$var":not zero][-e path:exist file]
[ <condition> ] && <true_command> || <false_command>

# for : [ex:for code in {000..255}; do print -nP -- "%F{$code}$code %f"; [ $((${code} % 16)) -eq 15 ] && echo; done]
for i in {1..<num>}; do <command> ; done

# for : [ex:for i in "${array[@]}"; do echo "[${i}]" ; done]
for i in "${<array>[@]}"; do <command> ; done

# while : [ex:while read -r LINE; do echo "${LINE}" ; done]
while <condition>; do <command> ; done

# function : [ex:() { local file ; file=$(chezmoi list -p source-absolute -i files | fzf) ; [ -n "$file" ] && vim $file }]
() { local <var> ; <command1> ; <command2> }
```

```sh
% shell:bash

# var : shell current process
echo $$

# var : shell parent process
echo $PPID

# var : pipestatus
echo ${PIPESTATUS[@]}
```

;--------------------------------------------------------------
; SQL
;--------------------------------------------------------------
```sh
% SQL

# show variables
echo -n "SHOW VARIABLES;" | cb
# show databases
SHOW DATABASES;
```
;--------------------------------------------------------------
; tmux
;--------------------------------------------------------------
```sh
% tmux
# keys
tmux list-keys | vim -

# pane move [-h:yoko,-v:tate]
tmux join-pane -<hv> -s <pane_from> -t <pane_to>

# respawn-pane [-k:kill existing command,-c:start-directory]
tmux respawn-pane -k -c '#{pane_current_path}'

# pipe-pane
tmux pipe-pane -t <pane_from> 'cat | grep "<word>" >> <tty>' ; read ; tmux pipe-pane -t <pane_from>
```
$ hv: echo -e "v\nh"
$ pane_from: echo "." && \
  tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 1
$ pane_to: echo "." && \
  tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 1
$ tty: tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 6

;--------------------------------------------------------------
; zinit
;--------------------------------------------------------------
```sh
% zinit
# report plugin
zi report

# report plugin loading time
zi times

# update plugin [ex:zinit update sharkdp/bat]
zi update <plugin>

# edit plugin [ex:zinit edit sharkdp/bat]
zi edit <plugin>

# delete plugin [ex:zinit delete sharkdp/bat]
zi delete <plugin>
```
