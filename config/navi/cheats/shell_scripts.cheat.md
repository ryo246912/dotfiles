```sh
% shellscript

# find : find path and exec command
find . -maxdepth 1 | while read -r FILE; do
  echo "ファイル：$FILE"
done

# while ~ read
echo "a:b:c" | while IFS=':' read -r a b c; do
  echo $a
  echo $b
  echo $c
done

# array [${array[@]}:array][${array[*]}:string][${#array[@]}:items]
() {local array ; array=(0 1 2 3 4 5) && for i in "${array[@]}"; do echo "item:$i" ; done && for i in "${array[*]}"; do echo "string:$i" ; done && echo "item_no:${#array[@]}" }

# if
if <condition> ; then <true_command> ; else <false_command> ;fi

# if : [a != b:not equal(int,str)][-n "$var":not zero][-z "$var":zero][-e path:exist file][1 -le 10,10 -ge 1:{less,greter} equal]
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

$ xxx: echo xxx
;$
