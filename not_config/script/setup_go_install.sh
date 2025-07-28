#!/bin/bash

set -e

go install github.com/x-motemen/gore/cmd/gore@latest
go install github.com/air-verse/air@latest
go install github.com/99designs/gqlgen
go install github.com/go-delve/delve/cmd/dlv@latest

