```sh
% terraform

# init : init and upgrade [-backend:false:not initialize backend]
terraform init -upgrade -backend=false

# upgrade : update lock file (linux_amd64: Intel/AMD 64bit, linux_arm64:ARM 64bit, darwin_arm64:macOS (Apple Silicon),darwin_amd64:macOS (Intel))
terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64

# plan : [-out:output file][-var:set variable ex)-var="environment=production"][-var-file:load file]
terraform plan

# plan : display summary of changes
terraform plan -no-color | grep --line-buffered -E '^\S+|^\s{,2}(\+|-|~|-/\+) |^\s<=|^Plan'

# state : local state
cat .terraform/terraform.tfstate | less

# state : display state
terraform show -json | fx

# state : display show remote state
terraform state pull | fx
```

$ xxx: echo xxx
;$
