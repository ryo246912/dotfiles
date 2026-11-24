```sh
% WSL

# wsl : installable list
wsl --list --online

# wsl : install distro
wsl --install -d <distro>

# wsl : display installed distro
wsl -l -v

# wsl : export
wsl --export <distro> <distro>.tar

# wsl : import
wsl --import <new_distro> <old_distro> <old_distro>.tar

# wsl : launch wsl root directory[-e <command> or -- <command>:exec command ex)wsl -d <distro> -e cat /etc/os-release,wsl -- cat /etc/os-release]
wsl -e <command>

# wsl : delete distro
wsl --unregister <distro>
```

$ xxx: echo xxx
;$
