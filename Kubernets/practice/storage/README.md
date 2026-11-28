# Mounted storage practice

This exercise uses your running `kind-learning` cluster and Flask application.
No AWS resources are created.

```text
Browser → website pod → /data/note.txt → website-files PVC → local node storage
```

The website's database messages still go to PostgreSQL. The new practice note
goes to a text file on a separate volume.

## Open the exercise

From the repository root, build and deploy changes with:

```bash
bash Kubernets/deploy.sh
kubectl --context kind-learning -n krishna port-forward service/website 8081:80
```

Leave port-forward running and visit http://localhost:8081/storage.
If port 8081 is already occupied by an earlier forward, stop that forward or use
`8082:80` and open http://localhost:8082/storage.

## 1. Save a file

Save a note such as `My file lives outside the pod` on the storage page.
In another terminal:

```bash
kubectl --context kind-learning -n krishna get pvc website-files
kubectl --context kind-learning -n krishna exec deployment/website -- cat /data/note.txt
kubectl --context kind-learning -n krishna get pods -l app=website -o wide
```

`website-files` should be Bound. The file content should match your note.
Remember the pod name shown on the page.

## 2. Replace the pod

```bash
kubectl --context kind-learning -n krishna rollout restart deployment/website
kubectl --context kind-learning -n krishna rollout status deployment/website --timeout=180s
kubectl --context kind-learning -n krishna exec deployment/website -- cat /data/note.txt
```

The pod changes; the file stays. The new pod mounts the same PVC at `/data`.
Port-forward may stop when its selected pod is replaced. Restart the
port-forward command and reopen the page.

## 3. Read the same file from two pods

```bash
kubectl --context kind-learning -n krishna scale deployment website --replicas=2
kubectl --context kind-learning -n krishna rollout status deployment/website --timeout=180s
kubectl --context kind-learning -n krishna get pods -l app=website -o wide
```

Copy each pod name into these commands, replacing `POD_A` and `POD_B`:

```bash
kubectl --context kind-learning -n krishna exec POD_A -- cat /data/note.txt
kubectl --context kind-learning -n krishna exec POD_B -- cat /data/note.txt
```

Both see the same file. Save a different note on the page and run both commands
again. A port-forward connects to one chosen pod, so refreshing the page does
not necessarily switch pods. Reading both pods directly proves the sharing.
Concurrent saves replace the whole note; the last completed save wins.

Return to one website pod when finished:

```bash
kubectl --context kind-learning -n krishna scale deployment website --replicas=1
```

## What the YAML means

| Setting | Meaning |
| --- | --- |
| `website-files-pvc.yaml` | Requests a separate persistent volume for files. |
| `volumes` | Connects the website pod to that PVC. |
| `volumeMounts.mountPath: /data` | Makes the volume accessible at `/data` in the container. |
| `fsGroup: 10001` | Gives the app's non-root user group access to supported mounted volumes. |
| `STORAGE_DIR: /data` | Tells Flask where to save `note.txt`. |

## How this relates to EBS and EFS

Your kind cluster has one node. This PVC uses local node storage and
`ReadWriteOnce` (RWO): read/write access from one node. Multiple pods on that
same node can use it. This does **not** demonstrate sharing across nodes.

On AWS, EBS normally provides storage attached to one node at a time. EFS
provides a shared network filesystem usable from multiple nodes, typically
through a `ReadWriteMany` (RWX) claim and the EFS CSI driver. Changing RWO to RWX
in this lab would not turn local storage into EFS.

The note survives pod replacement, but deleting the kind cluster removes the
local storage. Do not delete the PVC to reset the page: its reclaim policy may
delete the underlying data. This exercise does not modify PostgreSQL's PVC.

References: [Kubernetes persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
and [volume permissions](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).
