```sh
% go

# go mod init
go mod init github.com/<name>/<project>

# go env
go env

# go install bin list
<cmd> $(go env GOPATH)/bin

# go source code
<cmd> $(go env GOROOT)
```

$ cmd: echo -n "ls -l\nyazi"
;$

```sh
% go(package)

# pkgsite
pkgsite --http "localhost:<port>"

# cloc
gocloc $(go env GOROOT)/src/<package>

# Go REPL [exit: :q][:import fmt]
gore

# hotreload [air init]
air
```

$ xxx: echo xxx
;$

```sh
% go(archive)

# godoc [-goroot /usr/share/go]
godoc -http :8000
```

$ xxx: echo xxx
;$
