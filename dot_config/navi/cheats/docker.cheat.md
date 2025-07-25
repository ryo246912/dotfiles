```sh
% docker

# container ls(ps) [-a:all]
docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.RunningFor}}"

# image list(images) [-a:all]
docker image ls -a --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}"

# network list
docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.CreatedAt}}"

# inspect container
docker container inspect <container> | less -iRMW --use-color

# inspect image
docker image inspect <image_id> | less -iRMW --use-color

# inspect network
docker network inspect <network> | less -iRMW --use-color

# disk free
docker system df

# disk image [-s:file block size][-k:KB][file:Docker.raw or Docker.qcow2]
ls -sk ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw

# display no referenced images [-f:filter (dangling=not referenced by any containers)]
docker image ls -f dangling=true

# display no referenced volume [-f:filter (dangling=not referenced by any containers)]
docker volume ls -f dangling=true

# remove no referenced images(rmi) [-q:only display volume names] [ex:docker rmi <image_id>]
docker image rm $(docker images -q -f dangling=true)

# remove container
docker container rm <container>

# remove no referenced volume [-q:only display volume names]
docker volume rm $(docker volume ls -q -f dangling=true)

# remove(container/image/build cache)
docker system prune

# remove network
docker network prune

# remove unused build cache
docker builder prune

# build(create image from dockerfile)[-t: name:tag][-f DockerfileName:(default:Dockerfile)][--no-cache][ex:docker build -t image_name .(dockerfile directory)]
docker image build -t <image_name> .

# run (create temporary container & execute a command) [-d:run background][-i:wait stdin][-t:tty][-p:port][-e:env][--privileged:sudo][ex:docker run -it --rm mysql:tag --verbose --help]
docker container run -it --rm <image_id> <command>

# run (create remain container & execute a command) [-d:run background][-i:wait stdin][-t:tty][-p:port][-v:volume][-w:exec command in WD][-e:env][--privileged:sudo][ex:docker run -it -d -p 80:8080 -v ~/xxx:/var/xxx -w /app -e var=xxx ubuntu:22.04 bash]
docker container run -it -d --name <container_name> <image_id> <command>

# exec in existed container [-d:run background][-i:wait stdin][-t:tty][ex:docker run -it -d ubuntu:22.04 bash]
docker container exec -it <container> <command>

# volume mount and exec
docker run --rm -v <volume_name>:/from alpine sh -c "<command>"

# volume mount (copy)
docker run --rm -v <volume_name_from>:/from -v <volume_name_to>:/to alpine sh -c "cd /from && cp -av . /to"
```

$ container: docker container ls -a \
  --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.RunningFor}}" \
  --- --headers 1 --column 2
$ network: docker network ls \
  --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.CreatedAt}}" \
  --- --headers 1 --column 2
$ image_id: docker image ls -a \
  --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}" \
  --- --headers 1 --column 1
;$


```sh
% docker compose

# ls [--all]
docker compose ls --all

# ps [--all]
docker compose -p <project> ps --all

# start (starts existing containers)
docker compose -p <project> start <service>

# restart
docker compose -p <project> restart <service>

# stop
docker compose -p <project> stop <service>

# down
docker compose -p <project> down <service>

# exec (execute a command in a running container)[--project-directory:specify compose file][--env KEY=VALUE][--env-file:specify env file]
docker compose -p <project> exec <service> <command>

# run (create container & execute a command)
docker compose -p <project> run <service> <command>

# up (build image & create container & execute a command from compose file)[-d:detach mode=run background][-f compose.yml]
docker compose -p <project> up -d
```
$ project: docker compose ls --all \
  --- --headers 1 --column 1
$ service: docker compose -p <project> ps --all --format json \
  | jq -r ' ["Name","Service","State","Command"], (if type == "array" then .[] else . end | [.Name,.Service,.State,.Command]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 2

```sh
% docker-tool(dive)

# dive image
dive <image>

# dive build [-f:file path][--target <target>:target image]
dive build -f <dockerfile><_--target_target_> .

# dive workaround
export DOCKER_HOST=$(docker context inspect -f '{{ .Endpoints.docker.Host }}')
```

$ image: docker image ls -a \
  --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}" \
  --- --headers 1 --column 2
$ dockerfile: find . -type f -name '*Dockerfile' -not -name '.*'
$ _--target_target_: echo -e "\n --target_target "
;$
