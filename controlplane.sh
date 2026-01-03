#!/bin/bash
set -euo pipefail


sudo swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sysctl net.ipv4.ip_forward

sudo apt-get update
sudo apt-get -y install containerd

sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml


sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml


sudo systemctl restart containerd
sudo systemctl enable containerd



sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y kubelet=1.34.0-1.1 kubeadm=1.34.0-1.1 kubectl=1.34.0-1.1
sudo apt-mark hold kubelet kubeadm kubectl

kubeadm init --pod-network-cidr=192.168.0.0/16

##### AFTER THIS FOLLOW STEPS MENTIONED IN README.md file:#####
#==============================================================

mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf


############Below code should be executed manually on controlplane if cilium not present###########
# ------------------------------------------------
# WAIT LOGIC (THIS IS THE KEY)
# ------------------------------------------------
echo "=== Waiting for API server ==="
until kubectl version --short; do
  sleep 5
done

echo "=== Waiting for node to register ==="
until kubectl get nodes | grep -q Ready; do
  sleep 5
done

echo "=== Waiting for kube-system to stabilize ==="
kubectl wait --for=condition=Available deployment/coredns \
  -n kube-system --timeout=5m || true

#################Cilium download##########################
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}


#################Cilium download##########################

cilium install --set ipam.operator.clusterPoolIPv4PodCIDRList="192.168.0.0/16"

echo "=== Waiting for Cilium to become ready ==="
cilium status --wait

echo "=== Bootstrap COMPLETE ==="