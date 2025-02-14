# Podman Commands and Flags Documentation

This documentation provides a set of instructions and commonly used Podman commands with their flags. Use this as a reference for managing containers with Podman.

## Table of Contents
1. [Installation](#installation)
2. [Basic Commands](#basic-commands)
3. [Image Management](#image-management)
4. [Container Management](#container-management)
5. [Network Management](#network-management)
6. [Volume Management](#volume-management)
7. [Advanced Commands](#advanced-commands)

## Installation
To install Podman, follow the instructions on the [official Podman installation page](https://podman.io/getting-started/installation).

## Basic Commands

| Command             | Description                                 | Flags                                  | Meaning of Flags                       |
|---------------------|---------------------------------------------|----------------------------------------|----------------------------------------|
| `podman version`    | Display Podman version information          |                                        |                                        |
| `podman info`       | Display system information                  |                                        |                                        |
| `podman help`       | Display help information for Podman         |                                        |                                        |

## Image Management

| Command                     | Description                                 | Flags                                    | Meaning of Flags                       |
|-----------------------------|---------------------------------------------|------------------------------------------|----------------------------------------|
| `podman pull <image>`       | Pull an image from a registry               | `--quiet`, `--authfile`, `--tls-verify`  | `--quiet`: Suppress output<br>`--authfile`: Path to the authentication file<br>`--tls-verify`: Require HTTPS and verify certificates when pulling images |
| `podman images`             | List images                                 | `--all`, `--format`, `--filter`          | `--all`: Show all images (default hides intermediate images)<br>`--format`: Format the output using a Go template<br>`--filter`: Filter output based on conditions |
| `podman rmi <image>`        | Remove an image                             | `--force`, `--prune`                     | `--force`: Force removal of the image<br>`--prune`: Remove dangling images     |
| `podman build -t <tag> .`   | Build an image from a Dockerfile            | `--file`, `--build-arg`, `--no-cache`    | `--file`: Name of the Dockerfile (default is 'PATH/Dockerfile')<br>`--build-arg`: Set build-time variables<br>`--no-cache`: Do not use cache when building the image |
| `podman tag <image> <tag>`  | Add a new tag to an image                   |                                          |                                        |
| `podman inspect <image>`    | Display detailed information about an image | `--format`, `--type`                     | `--format`: Format the output using a Go template<br>`--type`: Return JSON for specified type (image or container) |

## Container Management

| Command                              | Description                                      | Flags                                     | Meaning of Flags                       |
|--------------------------------------|--------------------------------------------------|-------------------------------------------|----------------------------------------|
| `podman run <image>`                 | Run a container                                  | `-d`, `-it`, `--name`, `-p`, `--rm`       | `-d`: Run container in background and print container ID<br>`-it`: Allocate a pseudo-TTY and keep STDIN open<br>`--name`: Assign a name to the container<br>`-p`: Publish a container's port(s) to the host<br>`--rm`: Automatically remove the container when it exits |
| `podman ps`                          | List running containers                          | `--all`, `--filter`, `--format`, `--quiet`| `--all`: Show all containers (default shows just running)<br>`--filter`: Filter output based on conditions<br>`--format`: Format the output using a Go template<br>`--quiet`: Only display container IDs |
| `podman stop <container>`            | Stop a running container                         | `-t`, `--timeout`                         | `-t`: Seconds to wait for stop before killing it<br>`--timeout`: Specify a timeout (in seconds) |
| `podman rm <container>`              | Remove a container                               | `-f`, `--volumes`, `--link`               | `-f`: Force the removal of a running container (uses SIGKILL)<br>`--volumes`: Remove anonymous volumes associated with the container<br>`--link`: Remove the specified link |
| `podman logs <container>`            | Fetch the logs of a container                    | `-f`, `--since`, `--tail`, `--timestamps` | `-f`: Follow log output<br>`--since`: Show logs since timestamp<br>`--tail`: Number of lines to show from the end of the logs<br>`--timestamps`: Show timestamps |
| `podman exec -it <container> <cmd>`  | Run a command in a running container             | `-d`, `-e`, `--privileged`, `-w`          | `-d`: Detached mode: run command in the background<br>`-e`: Set environment variables<br>`--privileged`: Give extended privileges to the command<br>`-w`: Working directory inside the container |
| `podman inspect <container>`         | Display detailed information about a container   | `--format`, `--size`, `--type`            | `--format`: Format the output using a Go template<br>`--size`: Display total file sizes if the type is container<br>`--type`: Return JSON for specified type (image or container) |

## Network Management

| Command                      | Description                                     | Flags                     | Meaning of Flags                       |
|------------------------------|-------------------------------------------------|---------------------------|----------------------------------------|
| `podman network create`      | Create a new network                            | `--subnet`, `--driver`    | `--subnet`: Subnet in CIDR format<br>`--driver`: Driver to manage the network (default is 'bridge') |
| `podman network ls`          | List networks                                   | `--filter`, `--quiet`     | `--filter`: Filter output based on conditions<br>`--quiet`: Only display network IDs |
| `podman network rm <network>`| Remove a network                                |                           |                                        |
| `podman network inspect`     | Display detailed information about a network    | `--format`                | `--format`: Format the output using a Go template |
| `podman network connect`     | Connect a container to a network                |                           |                                        |
| `podman network disconnect`  | Disconnect a container from a network           |                           |                                        |

## Volume Management

| Command                     | Description                                     | Flags                     | Meaning of Flags                       |
|-----------------------------|-------------------------------------------------|---------------------------|----------------------------------------|
| `podman volume create`      | Create a new volume                             | `--label`, `--opt`, `--driver` | `--label`: Set metadata for the volume<br>`--opt`: Set driver-specific options<br>`--driver`: Specify volume driver (default is 'local') |
| `podman volume ls`          | List volumes                                    | `--filter`, `--format`, `--quiet`  | `--filter`: Filter output based on conditions<br>`--format`: Format the output using a Go template<br>`--quiet`: Only display volume names |
| `podman volume rm <volume>` | Remove a volume                                 | `--force`                 | `--force`: Force the removal of a volume that is in use         |
| `podman volume inspect`     | Display detailed information about a volume     | `--format`                | `--format`: Format the output using a Go template |

## Advanced Commands

| Command                                   | Description                                            | Flags                                          | Meaning of Flags                       |
|-------------------------------------------|--------------------------------------------------------|------------------------------------------------|----------------------------------------|
| `podman pod create`                       | Create a new pod                                       | `--name`, `--infra`, `--share`                 | `--name`: Assign a name to the pod<br>`--infra`: Create an infra container to share namespaces<br>`--share`: Comma-separated list of namespaces to share (default is 'cgroup,ipc,net,uts') |
| `podman pod ls`                           | List pods                                              | `--filter`, `--format`, `--quiet`              | `--filter`: Filter output based on conditions<br>`--format`: Format the output using a Go template<br>`--quiet`: Only display pod IDs |
| `podman pod rm <pod>`                     | Remove a pod                                           | `--force`                                      | `--force`: Force the removal of a running pod (uses SIGKILL) |
| `podman pod inspect <pod>`                | Display detailed information about a pod               | `--format`                                     | `--format`: Format the output using a Go template |
| `podman generate systemd <container>`     | Generate a systemd unit file for a container           | `--name`, `--files`, `--new`                   | `--name`: Assign a name to the systemd unit<br>`--files`: Generate a systemd unit file in the current directory<br>`--new`: Generate a new systemd unit file |
| `podman play kube <file>`                 | Play a Kubernetes YAML file to create pods and services| `--configmap`, `--quiet`                       | `--configmap`: Path to Kubernetes ConfigMap<br>`--quiet`: Suppress output |
| `podman machine init`                     | Initialize a Podman machine                            | `--cpus`, `--memory`, `--disk-size`            | `--cpus`: Number of CPUs for the machine<br>`--memory`: Amount of memory for the machine<br>`--disk-size`: Disk size for the machine |
| `podman machine start`                    | Start a Podman machine                                 |                                                |                                        |
| `podman machine stop`                     | Stop a Podman machine                                  |                                                |                                        |
| `podman machine rm`                       | Remove a Podman machine                                | `--force`                                      | `--force`: Force the removal of a running machine |

## Examples

### Run a Container:
```sh
# Run a container in interactive mode with a terminal
podman run -it --name mycontainer alpine sh
