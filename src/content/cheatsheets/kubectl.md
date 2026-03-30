---
title: "kubectl"
description: "Quick reference for Kubernetes cluster management, resource inspection, and debugging."
updatedDate: 2026-03-30
---

## Context and Config

```bash
# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context my-cluster

# Set default namespace
kubectl config set-context --current --namespace=prod

# View current context
kubectl config current-context

# View merged kubeconfig
kubectl config view --minify
```

## Getting Resources

```bash
# List pods (current namespace)
kubectl get pods

# All namespaces
kubectl get pods -A

# Wide output (node, IP)
kubectl get pods -o wide

# Specific labels
kubectl get pods -l app=web,env=prod

# Multiple resource types
kubectl get pods,svc,deploy

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Sort by field
kubectl get pods --sort-by=.status.startTime

# JSON path
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Watch for changes
kubectl get pods -w
```

## Describe and Inspect

```bash
# Full resource details + events
kubectl describe pod my-pod

# Raw YAML
kubectl get pod my-pod -o yaml

# Just the status
kubectl get pod my-pod -o jsonpath='{.status.phase}'

# Container image versions
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Events sorted by time
kubectl get events --sort-by=.lastTimestamp

# Resource usage
kubectl top pods
kubectl top nodes
```

## Create and Apply

```bash
# Apply from file
kubectl apply -f deployment.yaml

# Apply a directory
kubectl apply -f ./k8s/

# Apply from stdin
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  key: value
EOF

# Create deployment imperatively
kubectl create deployment web --image=nginx --replicas=3

# Expose as service
kubectl expose deployment web --port=80 --type=ClusterIP

# Dry run + output (generate YAML without applying)
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
```

## Edit and Patch

```bash
# Edit in $EDITOR
kubectl edit deployment web

# Patch (strategic merge)
kubectl patch deployment web -p '{"spec":{"replicas":5}}'

# JSON patch
kubectl patch deployment web --type=json -p='[{"op":"replace","path":"/spec/replicas","value":5}]'

# Set image
kubectl set image deployment/web web=nginx:1.25

# Scale
kubectl scale deployment web --replicas=3

# Rollout
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout undo deployment/web
kubectl rollout undo deployment/web --to-revision=2
kubectl rollout restart deployment/web
```

## Debugging Pods

```bash
# Logs
kubectl logs my-pod
kubectl logs my-pod -c sidecar        # specific container
kubectl logs my-pod --previous         # previous crash
kubectl logs -f my-pod                 # follow/stream
kubectl logs -l app=web --all-containers

# Exec into pod
kubectl exec -it my-pod -- /bin/sh
kubectl exec -it my-pod -c sidecar -- /bin/sh

# Run a debug pod
kubectl run debug --rm -it --image=busybox -- /bin/sh
kubectl run debug --rm -it --image=nicolaka/netshoot -- /bin/bash

# Ephemeral debug container (k8s 1.23+)
kubectl debug my-pod -it --image=busybox --target=my-container

# Port forward
kubectl port-forward pod/my-pod 8080:80
kubectl port-forward svc/my-svc 8080:80

# Copy files
kubectl cp my-pod:/var/log/app.log ./app.log
kubectl cp ./config.yaml my-pod:/etc/config/
```

## Namespaces

```bash
# List
kubectl get namespaces

# Create
kubectl create namespace staging

# Delete (and everything in it)
kubectl delete namespace staging

# Run command in namespace
kubectl -n kube-system get pods
```

## Labels and Annotations

```bash
# Add label
kubectl label pod my-pod env=prod

# Overwrite label
kubectl label pod my-pod env=staging --overwrite

# Remove label
kubectl label pod my-pod env-

# Add annotation
kubectl annotate pod my-pod description="web frontend"

# Select by label
kubectl get pods -l 'env in (prod,staging)'
kubectl get pods -l 'env notin (dev)'
kubectl get pods -l app=web,version!=v1
```

## Secrets and ConfigMaps

```bash
# Create secret
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Create from file
kubectl create secret generic tls-cert --from-file=cert.pem --from-file=key.pem

# View decoded secret
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d

# Create configmap
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-file=config.yaml

# View configmap
kubectl get configmap app-config -o yaml
```

## Jobs and CronJobs

```bash
# Create job
kubectl create job backup --image=alpine -- /bin/sh -c "echo done"

# Create from cronjob (run now)
kubectl create job --from=cronjob/nightly-backup manual-backup

# List jobs
kubectl get jobs

# Delete completed jobs
kubectl delete jobs --field-selector status.successful=1
```

## Cluster Info

```bash
# Cluster info
kubectl cluster-info

# Node details
kubectl describe node my-node

# API resources (what can I kubectl get?)
kubectl api-resources

# API versions
kubectl api-versions

# Explain a resource field
kubectl explain pod.spec.containers.livenessProbe
kubectl explain deployment.spec.strategy --recursive
```

## Delete

```bash
# Delete resource
kubectl delete pod my-pod

# Delete by label
kubectl delete pods -l env=test

# Delete from file
kubectl delete -f deployment.yaml

# Force delete stuck pod
kubectl delete pod my-pod --grace-period=0 --force

# Delete all pods in namespace
kubectl delete pods --all -n staging
```

## Useful Patterns

```bash
# Restart all pods in a deployment (rolling)
kubectl rollout restart deployment/web

# Get all images running in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Find pods not Running
kubectl get pods -A --field-selector status.phase!=Running

# Get pod resource requests/limits
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# Wait for rollout
kubectl rollout status deployment/web --timeout=120s

# Drain node for maintenance
kubectl drain my-node --ignore-daemonsets --delete-emptydir-data
kubectl uncordon my-node
```
