ONCE THE TERRAFORM APPLY IS DONE SUCCESSFULLY , PLEASE FOLLOW BELOW STEPS IN CONTROLPLAN:

mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config


******************below not required***************
export KUBECONFIG=/etc/kubernetes/admin.conf

# Wait for kubelet + apiserver + controller
#until kubectl get pods -n kube-system \
# | grep kube-controller-manager | grep -q Running; do
#  sleep 10
#done

#sleep 59
*************************************************************




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

cilium status