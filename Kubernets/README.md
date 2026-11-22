# Local Kubernetes practice

This lab uses **kind** to run Kubernetes inside Docker Desktop on your Mac.
It creates one node and deploys two Nginx pods. It does not use AWS.

Open the website: **http://localhost:8080**

## What the files do

- `cluster.yaml`: creates the node and maps Mac port 8080 to node port 30080.
- `app.yaml`: creates the `learning` namespace, a Deployment, and a Service.

## Basic concepts

- **Cluster:** the Kubernetes environment.
- **Node:** a machine that runs pods; here it is a Docker container.
- **Pod:** runs application containers; each website pod runs Nginx.
- **Deployment:** keeps two pods running and replaces failed/deleted pods.
- **Service:** gives pods one stable address and routes requests to ready pods.
- **Namespace:** groups resources for this practice lab.

Flow: **Browser → localhost:8080 → node:30080 → Service → Nginx pod:80**

The two pods run the same Nginx welcome page. Two pods do not mean two nodes.

## Create and deploy

Keep Docker Desktop running. Run these on your **Mac terminal**:

```bash
cd /Users/Ayush/Desktop/WEB_RESUME/Kubernets
~/.local/bin/kind create cluster --name learning --config cluster.yaml --wait 180s
kubectl --context kind-learning apply -f app.yaml
kubectl --context kind-learning -n learning rollout status deployment/website
```

Only run `kind create cluster` when the cluster does not already exist.
The kind binary is installed at `~/.local/bin/kind`.

## Inspect

```bash
# Show the node and whether it is Ready.
kubectl --context kind-learning get nodes

# Show the Deployment, pods, and Service.
kubectl --context kind-learning -n learning get deployments,pods,services

# Show application logs from both pods.
kubectl --context kind-learning -n learning logs -l app=website --prefix --tail=20

# Open a shell in one website pod. Type exit to leave.
kubectl --context kind-learning -n learning exec -it deployment/website -- sh
```

Inside the pod, run `ls /usr/share/nginx/html` to see the website files.
Use `kubectl` for application pods; `docker ps` shows the kind node container.

## Practise scaling

```bash
kubectl --context kind-learning -n learning scale deployment website --replicas=3
kubectl --context kind-learning -n learning get pods

# Return to the two replicas declared in app.yaml.
kubectl --context kind-learning apply -f app.yaml
```

## Practise automatic pod replacement

Copy one pod name from `get pods`, then replace POD_NAME below:

```bash
kubectl --context kind-learning -n learning delete pod POD_NAME
kubectl --context kind-learning -n learning get pods
```

The Deployment creates a replacement to keep two pods running.

## Remove the lab

```bash
# Remove the application only, keeping the cluster.
kubectl --context kind-learning delete -f app.yaml

# Remove the entire local cluster.
~/.local/bin/kind delete cluster --name learning
```

Reference: https://kind.sigs.k8s.io/docs/user/quick-start/
