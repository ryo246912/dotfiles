```sh
% go

# go mod init
go mod init github.com/<name>/<project>

# go env
go env

# go install bin list
yazi $(go env GOPATH)/bin

# go source code
yazi $(go env GOROOT)
```

$ xxx: echo xxx
;$

```sh
% go(package)

# pkgsite
pkgsite

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
