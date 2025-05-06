```sh
% shell:command

# cal : calendar[-y:year]
cal -3

# cal : calendar
cal <month_year>

# cat : concatenate command output(process substitution)
cat <(<command1>) <(<command2>)

# cat : output file(here document)
cat << EOF > <filename>
```
```sh
# curl : download file[-O:remote-name][-o:output filename][-s:silence][-S:show error when -s]
curl -sS -O '<url>'

# curl : curl http header[-I:display only header][-H:header ex: -H 'Content-Type: application/json']
curl -sI '<url>' -H '<header>'

# curl : POST [-i:include headers][-X:request method][-d:post data ex: -d '{"key1":"value1", "key2":"'"$value2"'"}']
curl -isS -X 'POST' '<url>' -H '<header>' -d '{"<key1>":"<value1>","<key2>":"'"$<value2>"'"}'

# chown : change file owner [-c:display change details] [chown <owner>:<group> .]
sudo chown -Rc <username>:<username> <file>

# chmod : change file permission [4=read(r),2=write(w),1=exec(x)/7=rwx,6=rw-,4=r--][764=owner:7,group:6,other=4]
sudo chmod -R 764 <file>

# chmod : change file permission [ugo+-=rwx : u=user,g=group,o=other : +=add,-=remove,=set][ex: chmod u+x file, chmod g-w file]
sudo chmod -R u+wrx <file>

# chsh : change shell [ex:chsh -s $(which zsh)]
chsh -s <shells>

# echo args[$@:args(array)][$*:args(string)]
echo $* $@

# echo exit status
echo $?

# echo $path
echo $PATH | sed -e 's/:/\n/g'

# df : disk free [--total:linux only][-h:human-readable]
df -h<_--total>

# du : disk usage [-c:display total][-s:display only depth0 directory][-h:human-readable]
du -csh

# find : find path (option) [ex:find . -name '*.app'][-depth,-maxdepth,-mindepth:directory depth][-printf:print format]
find . --depth 1

# find : output directory [-type:d,f,l=link][-path:pathname ex:./app/src/models/users][-not:not operator]
find . -type d -path '*' -not -path '.*'

# find : output file [-type:d,f,l=link][-path:pathname ex:./app/src/models/users][-name:filename ex:user.py][-not:not operator]
find . -type f -path '*' -name '*' -not -name '.*'

# find : output file [-regex:filename regex]
find . -type f -path '*' -regex '.*'

# find : and condition [-a:and]
find . -regex '.*' -a -not -regex '.*'

# find : prune or print [-prune:not search recursively,"condition1 -prune" -o "condition2 -print"][-o:or][-print:default action][-exec:command(ex:-exec sha1sum {} \;)]
find $PWD -type d -path "$PWD/.*" -prune -o -type <file_or_directory> -name '*' -print

# find : delete file [ex:find . -type f -path "*:Zone.Identifier" -delete]
find . -type f -path "<file>" -delete

# find : exclude '.*' directory&file
find $PWD -type d -path "$PWD/.*" -prune -o -not -name '.*' -type <file_or_directory> -name '*' -print

# groups : display group
groups

# id : display uid gid groups
id

# kill : [-s:signal,9=KILL,15=TERM(default)]
kill -s KILL <pid>

# killall : [-s:signal,9=KILL,15=TERM(default)][ex:killall mysqld]
killall <command_name>

# ln : link [-s:symbolic][-f:force(overwrite)][-b:create backup][ex:ln -sf ~/.private/.zprofile.secret ~]
ln -s <file> <dir>

# lsof(=list open files) : display file,pid,user[-i:port]
lsof -i:<port>

# make help
grep "^[a-zA-Z\-]*:" Makefile | sed -e 's/^/make /' -e 's/://'

# make print
make -n <make_command>

# ping : [-c <num>:ping count][-w:ping while][ex:ping www.google.co.jp]
ping <address>

# ps : [a:other tty process][x:no tty process][u:user-friendly=USER,PID,%CPU,%MEM,VSZ,RSS,TT,STAT,STARTED,TIME,COMMAND]
ps axu | less -iRMW --use-color

# ps : [o:format][pgid:process group id][sess:session id]
ps axo pid,ppid,pgid,sess,tty,user,start,command | less -iRMW --use-color

# sudo : sudo cd & exec command
sudo sh -c "cd <directory>; <command>"

# set : set shell option [-o:set option][+o:unset option][ex:set -o noclobber]
set -o <option>

# set : display shell option command
set +o

# tar : display contents [-t(--list):display content][-v:verbose][-f:archive file][ex:tar -tvf libs.tar.gz]
tar -tvf <file>

# tar : create archive [-c:create archive][-z(--gzip):extract or compress gzip][ex:tar -czvf libs.tgz *]
tar -czvf <name>.<extension> *

# tar : extract archive [-x:extract archive][ex:tar -xzvf libs.tgz '*.txt']
tar -xzvf <file>

# type : [a:all][ex:type -a python]
type -a <command>

# unset : unset shell variable
unset <var>

# watch : [-e:exit if error][-d:emphasis diff][-t:no title][-n:exec timespan(s)]
watch -n <second> -edt '<command>'

# watch :
watch -edt '<command> ; ! echo $?'
```
$ _--total: echo -e "\n --total"
$ header: echo -e "\naccept: application/json\nCookie: X-CSRF-Token="
$ username: whoami
$ file_or_directory: echo -e "f\nd"
$ shells: cat /etc/shells | sed 1,4d
;$ file: find $PWD -type d -path "$PWD/.*" -prune -o -not -name '.*' -type f -name '*' -print
;$ dir: find $PWD -type d -path "$PWD/.*" -prune -o -not -name '.*' -type d -name '*' -print
$ extension: echo -e "tar.gz\ntgz"
$ make_command: grep "^[a-zA-Z\-]*:" Makefile | sed -e 's/://' \
  --- --map "cut -d' ' -f1"
;$
