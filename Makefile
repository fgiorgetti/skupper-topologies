export KUBECONFIG = $(HOME)/.kube/config
export SKUPPER_CLI_IMAGE = quay.io/skupper/cli:2.2.0
ANSIBLE := ansible-playbook -i localhost,

#
# Install Ansible collections
#

install-collections:
	ansible-galaxy collection install -r requirements.yml

#
# Setup targets
#

setup-kube-1: install-collections
	$(ANSIBLE) ./playbooks/kube/setup-1.yml

setup-kube-2: install-collections
	$(ANSIBLE) ./playbooks/kube/setup-2.yml

setup-kube-3-linear: install-collections
	$(ANSIBLE) ./playbooks/kube/setup-3-linear.yml

setup-podman-1: install-collections
	$(ANSIBLE) ./playbooks/podman/setup-1.yml

setup-podman-2: install-collections
	$(ANSIBLE) ./playbooks/podman/setup-2.yml

setup-podman-3-linear: install-collections
	$(ANSIBLE) ./playbooks/podman/setup-3-linear.yml

#
# Teardonw Targets
#

teardown-kube: install-collections
	$(ANSIBLE) ./playbooks/kube/teardown.yml

teardown-podman: install-collections undeploy-podman-workloads
	$(ANSIBLE) ./playbooks/podman/teardown.yml

#
# Deploy workload targets
#

deploy-kube-fortio-server: install-collections
	@namespace=$$(kubectl get namespaces -o name | grep namespace\/topology- | sort -n | tail -1 | sed 's#namespace/##g'); \
	  $(ANSIBLE) ./playbooks/kube/deploy-workload.yml -e sourceFile=include/server-fortio.yml -e namespace=$${namespace}

deploy-kube-fortio-client: install-collections
	@namespace=$$(kubectl get namespaces -o name | grep namespace\/topology- | sort -n | head -1 | sed 's#namespace/##g'); \
	  $(ANSIBLE) ./playbooks/kube/deploy-workload.yml -e sourceFile=include/client-fortio.yml -e namespace=$${namespace}

deploy-kube-workloads: deploy-kube-fortio-client deploy-kube-fortio-server

deploy-podman-fortio-server: install-collections
	@namespace=$$(podman ps --format json | jq -r '.[].Names[0]' | grep ^topology- | sort -n | tail -1 | sed -re 's#(topology-[0-9]+)-.*#\1#g'); \
	  $(ANSIBLE) ./playbooks/podman/deploy-fortio-server.yml -e namespace=$${namespace}

deploy-podman-fortio-client: install-collections
	@namespace=$$(podman ps --format json | jq -r '.[].Names[0]' | grep ^topology- | sort -n | head -1 | sed -re 's#(topology-[0-9]+)-.*#\1#g'); \
	  $(ANSIBLE) ./playbooks/podman/deploy-fortio-client.yml -e namespace=$${namespace}

deploy-podman-workloads: deploy-podman-fortio-client deploy-podman-fortio-server

#
# Undeploy workloads targets
#

undeploy-podman-fortio-client:
	@podman rm -f fortio-client

undeploy-podman-fortio-server:
	@podman rm -f fortio-server

undeploy-podman-workloads: undeploy-podman-fortio-client undeploy-podman-fortio-server
