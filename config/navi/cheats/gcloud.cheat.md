```sh
% gcloud

# display current config
gcloud config list

# display configs list
gcloud config configurations list

# display config
gcloud config configurations describe <name>

# switch config
gcloud config configurations activate <name>

# create config [ex:gcloud config configurations create staging]
gcloud config configurations create <name>

# set config [ex:gcloud config set compute/zone asia-northeast1-a]
gcloud config set <section>/<property> <value>
```

$ name: gcloud config configurations list \
  | awk '{print $1}' \
  --- --headers 1
;$
