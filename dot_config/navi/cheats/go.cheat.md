```sh
% go

# go mod init
go mod init github.com/<name>/<project>

# go env
go env

# test : [-count=1:no-cache]
go test -shuffle=on -count=1

# test : display test log
go test -json ./... | jq -r 'select(.Action=="run" or .Action=="pass" or .Action=="fail") | [.Time, .Action, .Test] | join("\t")'

# go install bin list
<cmd> $(go env GOPATH)/bin

# go source code
<cmd> $(go env GOROOT)

# list : display go module version
go list -m -f '{{.GoVersion}}'

# list : display build entrypoint
go list -f '{{if eq .Name "main"}}{{.Dir}}/{{join .GoFiles " "}}{{end}}' ./...

# list : display deps
go list -f '{{join .Deps "\n"}}' <module> | xargs go list -f '{{if not .Standard}}{{.ImportPath}}{{end}}'
```

$ cmd: echo -n "ls -l\nyazi"
$ module: go list -f '{{if eq .Name "main"}}{{.Dir}}{{end}}' ./...
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
