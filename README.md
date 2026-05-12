# Router Topologies with Skupper

This project uses Ansible playbooks wrapped by a `Makefile` to create and tear down Skupper topologies for two execution environments:

- Kubernetes
- Podman

It also provides workload deployment helpers for running [Fortio](https://fortio.org/) as a client/server pair so you can exercise the topology and run performance tests across the Skupper network.

## What this project does

The repository automates the setup of these Skupper topologies:

- **1 router**
- **2 routers**
- **3 routers in a linear topology**

For each topology, you can:

1. Create the Skupper sites/routers
2. Link the sites together
3. Deploy a Fortio server on one end of the topology
4. Deploy a Fortio client on the other end
5. Use the Fortio UI or endpoints to run HTTP and gRPC performance tests

## Repository structure

- `Makefile` - entry point for setup, teardown, and workload deployment
- `requirements.yml` - required Ansible collections
- `playbooks/kube/` - Kubernetes topology and workload playbooks
- `playbooks/podman/` - Podman topology and workload playbooks

## Prerequisites

## Common requirements

Make sure the following tools are installed:

- `make`
- `ansible`
- `ansible-galaxy`

Install the required Ansible collections with:

```bash
make install-collections
```

This installs the collections declared in `requirements.yml`, including:

- `kubernetes.core`
- `skupper.v2`

## Kubernetes requirements

You need:

- Access to a Kubernetes cluster
- `kubectl` configured and pointing to the target cluster
- A valid kubeconfig at `~/.kube/config` or exported via `KUBECONFIG`

The `Makefile` exports:

```bash
KUBECONFIG=$(HOME)/.kube/config
```

So by default it will use `~/.kube/config`.

## Podman requirements

You need:

- `podman`
- `jq`

The Podman playbooks use host networking and local Skupper resources.

Optional environment variable:

```bash
export SKUPPER_CLI_IMAGE=quay.io/skupper/cli:v2-dev
```

If not set, the Podman playbooks default to that image automatically.

---

## Available Make targets

### Install dependencies

```bash
make install-collections
```

### Kubernetes topology setup

```bash
make setup-kube-1
make setup-kube-2
make setup-kube-3-linear
```

### Kubernetes teardown

```bash
make teardown-kube
```

### Podman topology setup

```bash
make setup-podman-1
make setup-podman-2
make setup-podman-3-linear
```

### Podman teardown

```bash
make teardown-podman
```

### Deploy Kubernetes workloads

```bash
make deploy-kube-fortio-server
make deploy-kube-fortio-client
```

### Deploy Podman workloads

```bash
make deploy-podman-fortio-server
make deploy-podman-fortio-client
```

### Remove Podman workloads

```bash
make undeploy-podman-fortio-client
make undeploy-podman-fortio-server
make undeploy-podman-workloads
```

---

## How to set up a topology

Choose either Kubernetes or Podman, then choose the desired topology.

## Kubernetes

### Single router

```bash
make setup-kube-1
```

Creates:

- Namespace `topology-1`
- Skupper site `router-1`

### Two routers

```bash
make setup-kube-2
```

Creates:

- Namespaces `topology-1`, `topology-2`
- Skupper sites `router-1`, `router-2`
- A link from `topology-2` to `topology-1`

### Three routers in a line

```bash
make setup-kube-3-linear
```

Creates:

- Namespaces `topology-1`, `topology-2`, `topology-3`
- Skupper sites `router-1`, `router-2`, `router-3`
- Links:
  - `topology-2` -> `topology-1`
  - `topology-3` -> `topology-2`

## Podman

### Single router

```bash
make setup-podman-1
```

Creates and starts:

- Namespace `topology-1`
- Skupper site `router-1`

### Two routers

```bash
make setup-podman-2
```

Creates and starts:

- Namespaces `topology-1`, `topology-2`
- Skupper sites `router-1`, `router-2`
- Router access on `topology-1`
- A link from `topology-2` to `topology-1`

### Three routers in a line

```bash
make setup-podman-3-linear
```

Creates and starts:

- Namespaces `topology-1`, `topology-2`, `topology-3`
- Skupper sites `router-1`, `router-2`, `router-3`
- Router access on `topology-1` and `topology-2`
- Links:
  - `topology-2` -> `topology-1`
  - `topology-3` -> `topology-2`

---

## How to deploy workloads

The project uses Fortio as:

- **server** on the last topology namespace/router
- **client** on the first topology namespace/router

This lets you measure traffic crossing the full topology.

## Kubernetes workloads

### Deploy the Fortio server

```bash
make deploy-kube-fortio-server
```

This deploys the Fortio server to the **highest-numbered** `topology-*` namespace.

Examples:

- `setup-kube-1` -> deploys to `topology-1`
- `setup-kube-2` -> deploys to `topology-2`
- `setup-kube-3-linear` -> deploys to `topology-3`

### Deploy the Fortio client

```bash
make deploy-kube-fortio-client
```

This deploys the Fortio client to the **lowest-numbered** `topology-*` namespace, typically `topology-1`.

After deployment, the playbook prints usage hints. For the Fortio client, the intended access points are:

- Fortio UI: `http://&lt;fortio-client-ip&gt;:8080/fortio`
- HTTP target: `http://fortio-http:8080/echo`
- gRPC target: `http://fortio-grpc:8079`

Notes:

- The client is exposed as a Kubernetes `LoadBalancer` service.
- If the external IP is not immediately available, the playbook may print a placeholder until the service gets an address.

## Podman workloads

### Deploy the Fortio server

```bash
make deploy-podman-fortio-server
```

This deploys the Fortio server to the **highest-numbered** topology namespace.

### Deploy the Fortio client

```bash
make deploy-podman-fortio-client
```

This deploys the Fortio client to the **lowest-numbered** topology namespace.

After deployment, the playbook prints the local URLs to use:

- Fortio UI: `http://localhost:7080/fortio`
- HTTP target: `http://127.0.0.1:8080/echo`
- gRPC target: `http://127.0.0.1:8079`

---

## How to run performance tests

Performance testing is done through the Fortio client against the Fortio server exposed through Skupper listeners/connectors.

## Kubernetes performance test flow

1. Set up a topology, for example:

   ```bash
   make setup-kube-3-linear
   ```

2. Deploy the server:

   ```bash
   make deploy-kube-fortio-server
   ```

3. Deploy the client:

   ```bash
   make deploy-kube-fortio-client
   ```

4. Open the Fortio client UI using the printed LoadBalancer IP:

   ```text
   http://<fortio-client-ip>:8080/fortio
   ```

5. Run tests from the UI using one of these targets:

   - HTTP: `http://fortio-http:8080/echo`
   - gRPC: `http://fortio-grpc:8079`

## Podman performance test flow

1. Set up a topology, for example:

   ```bash
   make setup-podman-3-linear
   ```

2. Deploy the server:

   ```bash
   make deploy-podman-fortio-server
   ```

3. Deploy the client:

   ```bash
   make deploy-podman-fortio-client
   ```

4. Open the Fortio client UI:

   ```text
   http://localhost:7080/fortio
   ```

5. Run tests from the UI using one of these targets:

   - HTTP: `http://127.0.0.1:8080/echo`
   - gRPC: `http://127.0.0.1:8079`

---

## Example end-to-end workflows

## Kubernetes example

```bash
make setup-kube-2
make deploy-kube-fortio-server
make deploy-kube-fortio-client
```

Then open the Fortio UI and test traffic through the two-router topology.

When finished:

```bash
make teardown-kube
```

## Podman example

```bash
make setup-podman-2
make deploy-podman-fortio-server
make deploy-podman-fortio-client
```

Then open:

```text
http://localhost:7080/fortio
```

When finished:

```bash
make teardown-podman
```

---

## Teardown and cleanup

## Kubernetes

Remove the Kubernetes-based topology:

```bash
make teardown-kube
```

## Podman

Remove the Podman workloads and topology:

```bash
make teardown-podman
```

Note: the Podman undeploy tasks are called automatically by `make teardown-podman`, so you normally do not need to run them manually.

If needed, workloads can also be removed independently:

```bash
make undeploy-podman-workloads
```

---

## Notes

- All setup and deployment commands run Ansible locally using `ansible-playbook -i localhost,`.
- Kubernetes workload deployment automatically selects:
  - the first `topology-*` namespace for the client
  - the last `topology-*` namespace for the server
- Podman workload deployment follows the same first/last topology selection logic.
- The project is intended for experimenting with Skupper topology layouts and measuring the impact on HTTP/gRPC request paths using Fortio.
