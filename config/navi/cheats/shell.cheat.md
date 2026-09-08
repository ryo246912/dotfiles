```sh
% bash

# bash : show bindkey
bind | less -iRMW --use-color

# bash: var : shell current process
echo $$

# bash : var : shell parent process
echo $PPID

# bash : var : pipestatus
echo ${PIPESTATUS[@]}

# bash : show shell option[i:interactive]
echo $-

# bash : exec command [-c:exec commnad][-i:interactive shell=bashrc][-l=login shell=bashprofile]
sh -i -l -c '<command>'

# zsh : show bindkey[-M : selected keymap]
bindkey -M <keymap> | less -iRMW --use-color

# zsh : manual zshbuiltins
man zshbuiltins

# zsh : show/set shell option
setopt

# shell : display shells
cat /etc/shells

# shell : display linux os version
cat /etc/os-release

# shell : display kernel version [architecture:arm64=M series,x86_64:AMD64 compatible]
uname -a

```
$ keymap: bindkey -l
;$
