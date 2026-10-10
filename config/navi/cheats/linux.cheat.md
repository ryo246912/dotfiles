```sh
% linux

# apt(Debian) : update package
sudo apt update

# apt(Debian) : upgrade specified package
sudo apt install --only-upgrade <package>

# apt(Debian) : install package [-y:yes]
sudo apt update && sudo apt install -y <package>

# apt(Debian) : uninstall package and unnecessary package
sudo apt remove -y <package> && sudo apt autoremove -y

# apt(Debian) : display install list
apt-mark showmanual | less -iRMW --use-color

# apt(Debian) : display install list
cat /var/log/apt/history.log | grep 'install ' | less -iRMW --use-color

# apt(Debian) : apt command history
cat /var/log/apt/history.log<_grep> | less -iRMW --use-color

# apt(Debian) : display source list
cat /etc/apt/sources.list | sed -e "/^#/d" -e "/^$/d" | less -iRMW --use-color

# apt(Debian) : add third-party package [ex.sudo add-apt-repository ppa:git-core/ppa]
sudo add-apt-repository ppa:git-core/ppa && sudo apt update

# free : [-h:human][-c:count][-s:interval seconds]
free -h -c 12 -s 300

# ldd(list dynamic dependency) :
ldd $(which <command>)

# sar : [-P:processor][ex:sar <option> <interval> <count>]
sar -P ALL 1 10

# sar : [-r:memory]
sar -r 1 10

# sar : [-B:paging]
sar -B 1 10
```
$ _grep : echo -e "\n | grep 'Commandline'"
;$
