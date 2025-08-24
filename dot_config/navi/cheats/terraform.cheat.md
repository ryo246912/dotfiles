```sh
% terraform

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
