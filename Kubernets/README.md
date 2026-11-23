# Local Kubernetes database practice

One kind node runs a small Flask website and a PostgreSQL database. This lab uses Docker Desktop on your Mac and does not use AWS.

**Browser → website Service → Flask pod → postgres Service → PostgreSQL → persistent volume**

You can add messages, see them after refreshing the page, and delete them.

## Files and concepts

- `cluster.yaml`: defines the local Kubernetes node.
- `manifests/namespace.yaml`: creates the `krishna` namespace.
- `manifests/database-configmap.yaml`: stores the shared database connection settings.
- `manifests/database-secret.yaml`: stores the password and session key locally; excluded from Git.
- `manifests/database-secret.yaml.example`: safe template for a fresh checkout.
- `manifests/postgres-pvc.yaml`: requests persistent storage for PostgreSQL.
- `manifests/postgres-deployment.yaml`: runs one PostgreSQL pod.
- `manifests/postgres-service.yaml`: gives PostgreSQL an internal address.
- `manifests/website-deployment.yaml`: runs the Flask website pod.
- `manifests/website-service.yaml`: gives the website an internal address.
- `web/app.py`: the page and Python backend, which runs SQL queries.
- `web/Dockerfile`: packages the app with Python and its dependencies.
- `web/requirements.txt`: Python packages installed inside the image.
- `deploy.sh`: builds the image, loads it into kind, applies the Secret YAML, and deploys the app.

A **ConfigMap** holds DB_HOST, DB_PORT, DB_NAME, and DB_USER. A **Secret** holds the generated database password and app session key. The real Secret YAML is excluded from Git; only the example template is committed. A Secret is not automatically encrypted at rest in this basic kind lab.

A **Deployment** maintains pods. A **Service** gives pods a stable internal address. A **PersistentVolumeClaim (PVC)** requests storage that survives pod deletion.

This is a local learning app without sign-in. Its database is internal to the cluster.

## Deploy

Keep Docker Desktop running. Run on your Mac:

```bash
cd /Users/Ayush/Desktop/WEB_RESUME/Kubernets
# Only create the cluster if it does not already exist.
~/.local/bin/kind create cluster --name learning --config cluster.yaml
./deploy.sh
```

To reapply the YAML files after editing them (with your local Secret YAML present):

```bash
kubectl --context kind-learning apply -f manifests/
```

For a fresh checkout, copy `manifests/database-secret.yaml.example` to `manifests/database-secret.yaml` and replace both placeholder values before running `deploy.sh`. Keep the database password unchanged while reusing an initialized database volume: editing a Secret does not change the password already stored in PostgreSQL. `cluster.yaml` stays outside `manifests/` because it is a kind configuration, not an application resource.

## Open the website

```bash
kubectl --context kind-learning -n krishna port-forward service/website 8081:80
```

Keep that terminal running and open **http://localhost:8081**. This uses port 8081 so an old Nginx port-forward on 8080 does not conflict. If the selected website pod is replaced, restart port-forward.

## Inspect the lab

```bash
kubectl --context kind-learning get nodes
kubectl --context kind-learning -n krishna get pods,services,configmaps,pvc
kubectl --context kind-learning -n krishna logs deployment/website
kubectl --context kind-learning -n krishna logs deployment/postgres
```

## Query the database

Open PostgreSQL's SQL terminal inside its pod:

```bash
kubectl --context kind-learning -n krishna exec -it deployment/postgres -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Inside `psql`, try:

```sql
-- List tables.
\dt

-- Read all saved messages.
SELECT * FROM messages ORDER BY id;

-- Count messages.
SELECT COUNT(*) FROM messages;

-- Add a row; refresh the website to see it.
INSERT INTO messages (name, message) VALUES ('Krishna', 'My first SQL insert');

-- Update that practice row.
UPDATE messages SET message = 'Updated using SQL' WHERE name = 'Krishna' AND message = 'My first SQL insert';

-- Delete that practice row.
DELETE FROM messages WHERE name = 'Krishna' AND message = 'Updated using SQL';

-- Leave the SQL terminal.
\q
```

## Test data persistence

Save a message on the website, then delete the database pod:

```bash
kubectl --context kind-learning -n krishna delete pod -l app=postgres
kubectl --context kind-learning -n krishna rollout status deployment/postgres --timeout=180s
```

Refresh the page after the database is ready. The PVC retains the messages. A brief connection error during database restart is expected: this lab has only one database pod.

The local volume does **not** survive deleting the kind cluster. It is not a backup.

## Scale the website

```bash
kubectl --context kind-learning -n krishna scale deployment website --replicas=2
kubectl --context kind-learning -n krishna get pods -o wide
```

Both website pods use the same database. Keep the PostgreSQL Deployment at one replica for this lab. Applying the manifests returns the website to its declared one replica.

## Cleanup

```bash
# WARNING: deletes this namespace, including the database PVC and messages.
kubectl --context kind-learning delete namespace krishna

# Or remove the entire cluster and all its local data.
~/.local/bin/kind delete cluster --name learning
```

References:
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
- https://www.psycopg.org/psycopg3/docs/basic/params.html
