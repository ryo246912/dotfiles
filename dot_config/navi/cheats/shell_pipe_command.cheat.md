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

# command : exec not user-defined command(not alias&function)[-v:display command path]
command <command>

# command : exec not alias command(not alias)[ex:"ls"]
"<command>"

# cut : separate input by bytes [-c:char,-b:byte][cut_list:start-end,start-,-end]
cut -<cb> <cut_list>

# cut : separate input by field [-d:separater,default='\t'][-f:cut by field:no1,no2][ex:cut -f 1,7]
cut -d "<separater>" -f <cut_no>

# date : ["+":format]
date "+%y/%m/%d %H:%M:%S"

# dirname : [ex:dirname $(which dirname)]
dirname <path>

# fx
fx

# fzf [-m:multi select]
fzf

# less [-i:ignore-case][-M:prompt more verbosely][-W:highlight first unread line after scrolling][-R:ANSI "color" escape sequences to be displayed in their raw][--use-color:enables colored]
less -iRMW --use-color

# lnav [-c:command]
lnav -c ':set-text-view-mode raw'

# grep : normal [-r:recursive][-i:ignore upper&lower][-n:output rows number][-e:multi condition][-E:extend regex,*/+/{n}/(X|Y)][-P:perl regex] [ex: grep -r 'navi' ./**/*dot* , grep -E '(X|Y)' apps/**/*.py]
grep -Pinr '<regex>' ./**/*

# grep : [-l:only filename] [ex:grep -il '' apps/**/*.py]
grep -Plnr '<regex>' ./**/*

# grep : [-B/A/C n:(before/after/both)output {n} lines] [ex:grep -C 1 -in '' apps/**/*.py]
grep -<line_output_option> <n> -Pnr '<regex>' ./**/*

# grep : [-v:output not match][ex:grep -v -e <word1> -e <word2>]
grep -vPr '<regex>' ./**/*

# grep : [-o:only matching][ex:grep -Po "v[0-9]*\.[0-9]*.[0-9]*"]
grep -oP '<regex>'

# gron : json to flat and filter to json [-u:ungron]['del(.[] | nulls)':remove null]
gron | grep -p '<regex>' | gron -u | jq 'del(.[] | nulls)'

# head : [-n:output number]
head -n <num>

# ijq
ijq

# jq : [-r:raw output]['.[]':expand array]['.[i:j]':expand array]['.key1,.key2':expand value]
jq -r '.'

# sed : replace [-e:multi command][ex:sed -e 1d -e '$ s/$/\n/'][regex:.|[a-z]|[^0-9]|.*][ex:sed 's| |!|']
sed -e 's/<regex>/<after>/g'

# sed : add [-e:multi command][symbol:^=head,$=tail]
sed -e 's/<symbol>/<after>/g'

# sed : delete [-e:multi command][regex:^$=line,]
sed -e 's/<regex>/<after>/g'

# sed : extract word [-r:regex \(\) -> ()][¥1:first()][&:word] [ex:sed -r 's/.*github.com.(.*).git/\1/']
sed -r 's/<regex>/\1/'

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

# spacer
spacer --after 5

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

# redirect : redirect std output(1>) to null & error output(2>) to std output
> /dev/null 2>&1

# redirect : redirect std output(1>) to null & error output(2>) to pipe
(<command> > /dev/null) 2>&1 |

# redirect : merge error output(2>) to std output(&1) [ex:ls > file 2>&1]
2>&1

# redirect : here string (echo string pipe)
<<< "<string>"

```

$ no: echo -e "1\n(NF-1)\nNF"
$ no2: echo -e "1\n(NF-1)\nNF"
$ cb: echo -e "c\nb"
$ cut_list: echo -e "<start_no>\n<start_no>-<end_no>\n<start_no>-\n-<end_no>"
$ line_output_option: echo -e "A\nB\nC"
$ symbol: echo -e "^\n$"
;$
