```sh
% shell:ssh

# ssh : login by .ssh/config [-T:config HOST][-l:login user][-A:Forward Agent][ex:ssh -A user@example.com]
ssh -AT <HOST>

# ssh : locale [SendEnv LANG LC_*:take over local locale]
vim /etc/ssh/ssh_config

# ssh : copy ssh key(Mac)
pbcopy < ~/.ssh/id_rsa.pub

# ssh : copy ssh key(Win)
clip.exe < ~/.ssh/id_rsa.pub

# ssh-add : add secret key [--apple-use-keychain(ex:-K):add OS keychain store][default=add {id_rsa,id_dsa,identify}]
ssh-add

# ssh-add : display secret key
ssh-add -l

# ssh-keygen : create secret key (default:id_rsa{,.pub}) [-t:algorithm]
ssh-keygen -t rsa

# ssh-keyscan : get public ssh key [ex:ssh-keyscan github.com >> ~/.ssh/known_hosts]
ssh-keyscan <HOST> >> ~/.ssh/known_hosts

# ssh-agent : ssh-add [eval $(ssh-agent):terminate ssh-agent=ssh-agent -k][exec ssh-agent $SHELL:terminate ssh-agent=exit]
eval $(ssh-agent) && ssh-add ~/.ssh/{id_rsa,id_ed25519}

# ssh-agent : terminate ssh-agent [-k:kill]
ssh-agent -k
```

$ xxx: echo xxx
;$
