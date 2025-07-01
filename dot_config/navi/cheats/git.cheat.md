```sh
% git

# diff option [--no-pager][--pickaxe-regex -S:filter by word(regex) count][-G:filter by regex change line][--no-patch:not display diff][-U(--unified):display num line ex:git diff -U0][--no-renames:ignore rename file][-M -- file1 file2:rename file diff]
git --no-pager diff --pickaxe-regex -S '<regex>' -U0

# diff staging file [--cached(staged):diff staging and commit][--stat/numstat/patch-with-stat:show stat]
git diff --cached<_stat> -- <staging_filename> | delta<_no-gitconfig>

# diff merge conflict file
git diff --diff-filter=U

# diff between base-branch...HEAD
git diff<_--name-only> $(git merge-base <base_branch> HEAD)...HEAD -- <base-head_diff_filename> | delta<_no-gitconfig>

# diff between base-branch...HEAD(difft)
GIT_EXTERNAL_DIFF="difft" git diff $(git merge-base <base_branch> HEAD)...HEAD -- <base-head_diff_filename>

# diff between merge-base...origin/master
git diff<_--name-only> $(git merge-base origin/<base_branch> HEAD)...origin/<base_branch> | delta<_no-gitconfig>

# diff between commits [ex:master...HEAD]
git diff<_--name-only> <commit1>...<commit2> | delta<_no-gitconfig>

# diff between commits filter by file [ex:master...HEAD]
git diff<_--name-only> <commit1>...<commit2> -- <commit1-commit2_filename> | delta<_no-gitconfig>

# diff between merge commit
git diff<_--name-only> HEAD~1...HEAD | delta<_no-gitconfig>

# show commit [--stat/numstat/patch-with-stat:show stat]
git show <commit1><_stat> | delta<_no-gitconfig>

# show commit(difft)
GIT_EXTERNAL_DIFF=difft git show <commit1> --ext-diff

# show commit file
git show <commit1>:<git_filename>

# show commit (contributor)
git show <contributor_commit> | delta<_no-gitconfig>

# show parents commit [^n:n-th parent][~n:n n-th first-parent][ex:git show HEAD^^,HEAD~2]
git show HEAD~<num> | delta<_no-gitconfig>

# show children commit [^n:n-th parent][~n:n n-th first-parent][ex:git show HEAD^^,HEAD~2]
git show $(git log -n $((<num>+1)) --pretty=format:"%h" HEAD^...HEAD | tail -n 1) | delta<_no-gitconfig>

# cherry-pick
git cherry-pick -n <cherry_commit>

# cherry-pick multi commits [two dots diff:(cherry-pick commit1)^..(cherry-pick commit2)]
git cherry-pick <commit1>^..<commit2>

# cherry-pick file
git checkout <commit1> <diff_filename>

# create branch
git branch <branch_name> <commit1>

# git chechout detached branch
git checkout HEAD~0

# create branch & checkout
git checkout -b <branch_name> <commit1>

# create branch & checkout(record base-branch)
git checkout -b <branch_name> <all_branch> && git config "branch.$(git symbolic-ref --short HEAD).base-branch" <all_branch>

# checkout remote branch
git checkout -b <remote_branch> origin/<remote_branch>

# record base-branch
git config "branch.$(git symbolic-ref --short HEAD).base-branch" <current_branch>

# set upstream branch [-u:upstream branch] [ex:git branch -r origin/feature-branch]
git branch -u origin/$(git symbolic-ref --short HEAD)

# branch & tag list[--sort=-committerdate]
git for-each-ref --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t' | less -iRMW --use-color

# restore(default)
git checkout <checkout_commit>

# merge dry-run
git merge --no-commit --no-ff <all_branch> && git diff --cached --name-only

# merge --no-commit
git merge --no-commit origin/<merge_branch>

# merge ours/theirs
git checkout<_--ours_theirs> -- <conflict_files> && git add <conflict_files>

# commit fixup
git commit --fixup <commit1> && git -c sequence.editor=true rebase -i --autostash --autosquash --quiet <commit1>~

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

# reset recent commit [^n:n-th parent][~n:n n-th first-parent]
git reset --soft HEAD~

# clear working directory file
git checkout <modified_files>

# clear working directory[-f:force][-d:directory]
git checkout . && git clean -df

# clear staging
git reset --mixed HEAD

# list tag [-l "pattern":list]
git tag -l '*<tag_search>*' --sort=-creatordate --format='%(if) %(*objectname) %(then) %(*objectname:short) %(else) %(objectname:short) %(end) %09 %(objecttype) %09 %(refname:short) %09 %(creatordate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | head -n 5 | column -ts $'\t'

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

# rebase interactive
git rebase --autosquash --autostash -i <commit1>

# rebase onto [--onto: --onto <base_branch> <pick_start_commit>^ ~ <pick_end_commit>(HEAD)] [ex.git rebase --onto release/xxx abcdef^]
git rebase --autosquash --autostash --onto <all_branch> <commit1>^

# git grep [-i:ignore upper&lower][-P:perl regex]
git grep -iP '<regex>' <grep_commit> -- <dir>

# git grep look{ahead,behind} regex [positive ahead:X(?=Y)] [negative ahead:X(?!Y)][positive behind:(?<=Y)X][negative behind:(?<!Y)X]
git grep -P '<look_regex>' <grep_commit> -- <dir>

# git grep only filename [-l:only filename]
git grep -lP '<regex>' <grep_commit> -- <dir>

# git grep not match [-v:output not match]
git grep -lvP '<regex>' <grep_commit> -- <dir>

# git grep between commit [-i:ignore upper&lower]
git grep -iP '<regex>' $(git rev-list <commit1>...<commit2>) --

# git grep files
git grep -iP '<regex>' $(git rev-list master -- <ls-tree-files>) -- <ls-tree-files>

# cat-file
git cat-file -p <commit1>:<ls-tree-files><_pipe>

# log contributor
git log -n 30 --author="<contributor>" --all --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"

# log graph [--all:all branch]
git log --date-order --graph --pretty=format:"%C(auto)%>|(60)%h (%C(blue)%cd%C(auto)) %<(15,trunc)%cN%d %s" --date=format:"%Y/%m/%d %H:%M:%S" <all_branch>

# log commit
git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S" <all_branch> | grep -C 3 --color=auto <commit>

# log file [-L <start>,<end>:<file>(ex:-L 10,+10:sample.py) : select line][-L :<func>:<file>(ex: :SampleClass:sample.py) : select func]
git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d [%C(magenta)%an%C(auto)] %s" --date=format:"%Y/%m/%d %H:%M:%S" <all_branch> <file_option><ls-files>

# log change word [-S --pickaxe-regex:filter by word(regex) word count change in diff][-G:filter by regex in diff]
git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d [%C(magenta)%an%C(auto)] %s" --date=format:"%Y/%m/%d %H:%M:%S" <search_option> '<regex>'

# log delete file
git log --diff-filter=D --name-only --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"

# log unreachable commit
git fsck --unreachable | awk '/commit/ {print $3}' | xargs git log --merges --no-walk --grep='<regex>' --all-match --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d [%C(magenta)%an%C(auto)] %s" --date=format:"%Y/%m/%d %H:%M:%S"

# log commit(difft)
GIT_EXTERNAL_DIFF=difft git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S" --ext-diff -p -n 10

# stash working file
git commit -m 'commit staging' && git stash --include-untracked --message "<prefix><message>" -- <working_filename> && git reset --soft HEAD^

# stash file[--include-untracked: untrack file]
git stash --include-untracked --message "<prefix><message>" -- <working_filename>

# list stash
git stash list --pretty=format:"%C(green)%gd %C(auto)%h%d %s" --date=format:"%Y/%m/%d-%H:%M:%S"

# show stash [-p:patch][-u:--include-untracked]
git stash show <stash_num> -u -p

# pop stash
git stash pop <stash_num>

# pop stash file
git checkout <stash_num> <stash_file>

# cherry-pick stash
git cherry-pick -n <stash_num>

# bisect start [ex:git bisect start <bad-commit> <good-commit>]
git bisect start <commit1> <commit2>

# bisect show now commit
git bisect view

# clone [--depth:shallow clone][--filter=blob:none ;blob-less=commit&tree only][--filter=tree:0 ;tree-less=commit only] [repo_url:(ssh)git@github.com:<user>/<repo>.git(http)https://github.com/<user>/<repo>.git]
git clone<_shallow-option> <repo_url>

# display remote
git remote -v

# set remote url [ex:git remote set-url origin git@github.com:<user>/<repo>.git]
git remote set-url <shortname> git@github.com:<user>/<repo>.git

# add remote url [ex:git remote add upstream git@github.com:<user>/<repo>.git]
git remote add <shortname> git@github.com:<user>/<repo>.git

# add upstream remote url [ex:git remote add upstream git@github.com:<user>/<repo>.git]
git remote add upstream https://github.com/$(git remote get-url upstream |sed -e 's/https:\/\/github.com\///' -e 's/\.git$//')

# add origin/HEAD (-> git symbolic-ref refs/remotes/origin/HEAD)
git remote set-head origin -a

# check-ignore
git check-ignore -v <file>

# config list [-l:list]
git config -l --show-origin<_--option> | column -ts $'\t'

# meta : display HEAD branch
git symbolic-ref --short HEAD

# meta : display base-branch
git config branch.$(git symbolic-ref --short HEAD).base-branch

# meta : display merge-base [ex:git merge-base master HEAD]
git merge-base <base_branch> HEAD

# meta : display HEAD commit hash [HEAD^@:all parents]
git rev-parse --short HEAD

# meta : display relative path to git top-level directory
git rev-parse --show-cdup

# meta : display relative path to pwd
git rev-parse --show-prefix

# meta : display absolute path to git top-level directory
git rev-parse --show-toplevel

# meta : count-object
git count-objects -v

# git no config
GIT_CONFIG_GLOBAL=/dev/null
```
$ _no-gitconfig: echo -e " --no-gitconfig\n"
$ _--name-only: echo -e "\n --name-only\n --name-status"
$ _--option: echo -e "\n --global\n --local\n --system"
$ _stat: echo -e "\n --stat\n --numstat\n --patch-with-stat"
$ _shallow-option: echo -e "\n --depth 1\n --filter=blob:none\n --filter=tree:0"
$ _--ours_theirs: echo -e " --ours\n --theirs"
$ tag_search: echo -e "staging\nrelease"
$ delete_flag: echo -e "d\nD"
$ base_branch: echo -e "$(git config branch.$(git symbolic-ref --short HEAD).base-branch | sed 's/^origin\///')\nmaster\nmain"
$ file_option: echo -e "-- \n-L 1,+10:\n-L :class:"
$ search_option: echo -e "--pickaxe-regex -S\n-G"
$ look_regex: echo -e "<search_word>(?=(<look_word>))\n<search_word>(?!(<look_word>))\n(?<=(<look_word>))<search_word>\n(?<!(<look_word>))<search_word>"
$ repo_url: echo -e "\ngit@github.com:\nhttps://github.com/"
$ prefix: echo -e "wip: \nmemo: \n"
$ author: echo -e "\n@me\n$(gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq -r '(.[] | .login )')"
$ search: echo -e "\nuser-review-requested:@me\nreviewed-by:@me\ninvolves:@me\n$(gh api "/repos/$(git config remote.origin.url | sed -e 's/.*github.com.\(.*\).*/\1/' -e 's/\.git//')/contributors?per_page=100" | jq -r '(.[] | "involves:"+.login )')"
$ state: echo -e "open\nall\nclosed\nmerged"

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
$ remote_branch: git branch -r --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t' \
  --- --column 1 --map "sed s'|origin/||'"
$ all_branch: cat \
  <(git rev-parse --abbrev-ref HEAD) \
  <(git branch -a --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' | column -ts $'\t') \
  --- --column 1
$ merge_branch: git fetch -p --tags && \
  gh pr list --author "<author>" --search "<pr_search>" --state <state> --limit 100 \
  --json number,title,author,state,isDraft,updatedAt,createdAt,headRefName \
  --jq '["no","title","author","state","draft","updatedAt","createdAt","branch"], (.[] | [.number , .title , .author.login , .state , (if .isDraft then "◯" else "☓" end ) , (.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) ,(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S")) , .headRefName]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 8
$ current_branch: git branch -a --format='%(refname:short) %09 %(committername) %09 %(committerdate:format:%Y/%m/%d %H:%M) %09 %(objectname:short)' \
  | grep "$(git rev-parse --short HEAD)" \
  | grep -v "$(git symbolic-ref --short HEAD)" \
  | column -ts $'\t' \
  --- --column 1
$ contributor: git log --format="%cn:%ce" \
  | sort -fu \
  | column -ts ":" \
  --- --column 1
; $ grep_commit: git log <branch> \
;   --pretty=format:"%h; (%cd)%d %s" --date=format:"%Y/%m/%d %H:%M:%S" -- <ls-files> \
;   --- --column 1 --delimiter ; \
;   --preview "git show {1} --name-only --oneline | sed -e 1d -e '$ s/$/\n/' ; git show {1} | delta --no-gitconfig"
$ dir: git ls-tree <grep_commit> --name-only -dr
$ stash_num: git stash list \
  --- --column 1 --delimiter : \
  --preview "git stash show {1} -u ; git stash show {1} -up | delta --no-gitconfig"
$ stash_file: echo . && \
  git stash show --name-only -u <stash_num> \
  --- --multi --expand
$ modified_files: echo . && \
  git ls-files -m \
  --- --multi --expand
$ ls-files: git ls-files
$ ls-tree-files: git ls-tree --name-only --full-name -r <commit1> $(git rev-parse --show-toplevel)
$ extension: echo <ls-tree-files> | sed 's/^.*\.\([^\.]*\)$/\1/'
$ _pipe: echo -e " | bat -l <extension>\n > <ls-tree-files>"
$ base-head_diff_filename: git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ $(git merge-base <base_branch> HEAD)...HEAD \
  | xargs -I % echo "<base_branch>;%" \
  --- --delimiter ; --column 2 \
  --preview "git diff $(git merge-base {1} HEAD)...HEAD -- {2} | delta --no-gitconfig"
$ commit1-commit2_filename: echo . && \
  git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ <commit1>...<commit2> \
  --- --multi --expand
$ git_filename: git ls-tree -r --name-only <commit1>
$ conflict_files: echo . && \
  git diff --name-only --diff-filter=U \
  --- --multi --expand \
  --preview "git diff {1} | delta --no-gitconfig"
$ diff_filename: git diff --name-only <commit1> \
  | xargs -I % echo "<commit1>;%" \
  --- --delimiter ; --column 2 \
  --preview "git show {1}:{2} | delta --no-gitconfig"
$ working_filename: echo . && \
  git status --porcelain \
  | cut -c4- \
  | sed -e "s|^|$(pwd)/|g" \
  --- --multi --expand \
  --preview "git diff HEAD -- {1} | delta --no-gitconfig"
$ staging_filename: echo . && \
  git diff --cached --name-only --line-prefix=$(git rev-parse --show-toplevel)/ \
  --- --multi --expand \
  --preview "git diff --cached -- {1} | delta --no-gitconfig"
;$
