# Deploy K3s cluster on RPi 4 board

This doc is about how to deploy a K3s cluster on stacked RPi 4 board.

## Install K3s server and Agent on the RPi cluster

After all the RPi boards are booted successfully, we are about to install K3s on them in order to compose a cluster compatible with K8s. Since the RPi boards are stacked, I'll name them as `piattop`, `piat2nd` and `piat3rd` to represent them from top to bottom.

### Preparation

Since all the RPi boards are connected to my local home router, we need to do some configuration on the router to support the cluster's installation/running and accessibility over Internet. I am using a Mikrotik RB4011 router at home, here is the basic configuration.
![RB4011](https://i.mt.lv/cdn/rb_images/1633_l.jpg)

- Here I reserve the IP addresses according to the LAN MAC addrs on RPi boards.
```
/ip dhcp-server lease add mac-address=<MAC_ADDR>  address=192.168.11.<FIXED_VAL> server=192.168.11.0
```

- To Allow hostname ping inside the LAN, extra config needs to be applied. #TODO

- 443 and 80 Port mapping

- To allow accessing the DNS host via both WAN and LAN. Firewall needs to be adjusted.

### Deploy K3s server and agent

We are about to install K3s on the cluster. We use `piattop` as the K3s server and the other 2 as K3s agent.

- Install K3s server

```bash
export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC=" --no-deploy servicelb --no-deploy traefik"
curl -sfL https://get.k3s.io | sh -

# Get token of the k3s svc
sudo cat /var/lib/rancher/k3s/server/node-token
```

- Install K3s agent, TOKEN can be fetched at server machine 

```bash
export K3S_KUBECONFIG_MODE="644"
export K3S_URL="https://piattop:6443"
export K3S_TOKEN="<TOKEN>"
curl -sfL https://get.k3s.io | sh -
```

## Deploy loadbalancer and ingress controller

Here we deploy the loadbalancer and ingress controller onto the cluster.

- Use Helm(v3) to install Loadbalancer

```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm install metallb stable/metallb --namespace kube-system \
  --set configInline.address-pools[0].name=default \
  --set configInline.address-pools[0].protocol=layer2 \
  --set configInline.address-pools[0].addresses[0]=192.168.11.50-192.168.11.60
```

- Use Helm(v3) to install ingress controller

```bash
kubectl create namespace ingress-controller
helm install nginx-ingress stable/nginx-ingress \
  --namespace ingress-controller \
  --set controller.image.repository=quay.io/kubernetes-ingress-controller/nginx-ingress-controller-arm64 \
  --set controller.image.tag=0.25.1 \
  --set controller.image.runAsUser=33 \
  --set defaultBackend.enabled=false
```

### Install Cert-manager

Cert manager will help you to grant TLS keys from Letsencrypt. I created a separate namespace to install it. I refer to Rancher's [cert-manager install doc](https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/helm-rancher/#5-install-cert-manager)

```bash
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml

# **Important:**
# If you are running Kubernetes v1.15 or below, you
# will need to add the `--validate=false` flag to your
# kubectl apply command, or else you will receive a
# validation error relating to the
# x-kubernetes-preserve-unknown-fields field in
# cert-manager’s CustomResourceDefinition resources.
# This is a benign error and occurs due to the way kubectl
# performs resource validation.

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v0.12.0
```

### Install Rancher

In order to manage the cluster properly. I installed Rancher 2 onto the cluster. The reference doc is [Install Rancher on Kubernetes Cluster](https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/helm-rancher/)

```bash
kubectl create namespace cattle-system
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=<HOST_NAME> \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=<EMAIL_ADDR>
```

N.B. There is some "race-condition" during rancher deployment. The certificate granting might ends up failure or pending. Here you need to do following checks:

- Is the dst-nat and masqurading properly set on home router
- Is the certificate created successfully.

```bash
kubectl -n cattle-system get certificate
kubectl -n cattle-system get issuer
kubectl -n cattle-system get certificaterequest
kubectl -n cattle-system describe certificaterequest rancher
```

- If the certificaterequest got stuck. Try to delete the ingress and re-create it.

```bash
helm -n cattle-system get values rancher > rancher-values.yaml
kubectl -n cattle-system delete ingress rancher
helm -n cattle-system upgrade -i rancher \
  rancher-latest/rancher -f rancher-values.yaml
```

After Rancher is installed, we could check if Rancher is accessible from WAN and LAN.

![rancher-login](https://user-images.githubusercontent.com/944672/81685208-2f4f9900-9458-11ea-8e03-6aab82e399b9.png)

The cluster is shown in below pic.

![K3s Local Cluster](https://user-images.githubusercontent.com/944672/82371075-e0869e00-9a19-11ea-8ecd-0c8516faaa56.png)

### Prepare cluster-issuer for further deployment

In order to make use of cert-managet to other services, create cluster-issuer.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: <EMAIL>
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <EMAIL>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```
