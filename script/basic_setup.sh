#!/bin/bash

# Script pour configurer un cluster Kubernetes sur Ubuntu
# Doit être exécuté avec sudo

# Fichier de log
LOG_FILE="kubernetes_setup.log"

# Fonction pour écrire dans le log
log() {
    local type="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$type] $message" | tee -a "$LOG_FILE"
}

# Vérifie si le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Ce script doit être exécuté avec sudo."
    exit 1
fi

# Identifier l'utilisateur non-root
if [ -n "$SUDO_USER" ]; then
    USER_HOME="/home/$SUDO_USER"
else
    USER_HOME="$HOME"
    log "WARNING" "SUDO_USER non défini, utilisation de $HOME."
fi

# Étape 0 : Vérification et réinitialisation conditionnelle du cluster
log "INFO" "Étape 0 : Vérification de l'état du cluster"
if [ -f "/etc/kubernetes/admin.conf" ] || kubeadm version >/dev/null 2>&1; then
    log "WARNING" "Un cluster Kubernetes semble déjà exister."
    read -p "Voulez-vous réinitialiser le cluster existant ? (y/N) : " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Réinitialisation du cluster existant"
        kubeadm reset -f >> "$LOG_FILE" 2>&1
        rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd >> "$LOG_FILE" 2>&1
        rm -rf "$USER_HOME/.kube" >> "$LOG_FILE" 2>&1
        systemctl restart containerd >> "$LOG_FILE" 2>&1
        systemctl restart kubelet >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            log "INFO" "Cluster réinitialisé avec succès."
        else
            log "ERROR" "Échec de la réinitialisation du cluster."
            exit 1
        fi
    else
        log "INFO" "Poursuite sans réinitialisation."
    fi
else
    log "INFO" "Aucun cluster détecté, installation initiale."
fi

# Vérification des ports
log "INFO" "Vérification des ports requis (6443, 10250, 10257, 2379, 2380)"
for port in 6443 10250 10257 2379 2380; do
    if netstat -tulnp | grep -q ":${port}"; then
        log "ERROR" "Le port ${port} est déjà utilisé."
        exit 1
    fi
done
log "INFO" "Tous les ports requis sont libres."

# Étape 1 : Mettre à jour le système (A voir : plutot avertir que exécuter !!!)
log "INFO" "Étape 1 : Mise à jour du système"
apt update >> "$LOG_FILE" 2>&1
apt upgrade -y >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log "INFO" "Système mis à jour avec succès."
else
    log "ERROR" "Échec de la mise à jour du système."
    exit 1
fi

# Étape 2 : Désactiver le swap (VERSION CORRIGÉE)
log "INFO" "Étape 2 : Désactivation du swap"
# Vérifier si du swap est réellement actif
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    log "INFO" "Swap détecté, désactivation en cours..."
    swapoff -a >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "INFO" "Swap désactivé avec succès."
    else
        log "ERROR" "Échec de la désactivation du swap."
        exit 1
    fi
    # Commenter les lignes swap dans fstab
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    log "INFO" "Lignes swap commentées dans /etc/fstab."
else
    log "INFO" "Aucun swap actif détecté, aucune action nécessaire."
fi
log "INFO" "Vérification finale du swap : $(free -h | grep Swap)"

# Étape 3 : Installer les dépendances
log "INFO" "Étape 3 : Installation des dépendances (curl, apt-transport-https, ca-certificates)"
apt install -y curl apt-transport-https ca-certificates >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log "INFO" "Dépendances installées avec succès."
else
    log "ERROR" "Échec de l'installation des dépendances."
    exit 1
fi

# Étape 4 : Installer containerd (VERSION CORRIGÉE)
log "INFO" "Étape 4 : Installation de containerd"
apt install -y containerd >> "$LOG_FILE" 2>&1
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >> "$LOG_FILE" 2>&1
# Activer SystemdCgroup pour la compatibilité avec kubeadm
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Garder la version par défaut de pause (suppression de la modification forcée)
log "INFO" "Configuration containerd avec SystemdCgroup activé."
systemctl restart containerd >> "$LOG_FILE" 2>&1
systemctl enable containerd >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log "INFO" "containerd installé et configuré avec succès."
else
    log "ERROR" "Échec de l'installation de containerd."
    exit 1
fi
log "INFO" "Version de containerd : $(containerd --version)"

# Étape 5 : Installer kubeadm, kubelet, kubectl
log "INFO" "Étape 5 : Installation de kubeadm, kubelet, kubectl"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list >> "$LOG_FILE" 2>&1
apt update >> "$LOG_FILE" 2>&1
apt install -y kubeadm kubelet kubectl >> "$LOG_FILE" 2>&1
apt-mark hold kubeadm kubelet kubectl >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log "INFO" "kubeadm, kubelet, kubectl installés avec succès."
else
    log "ERROR" "Échec de l'installation de kubeadm, kubelet, kubectl."
    exit 1
fi
log "INFO" "Versions installées :"
log "INFO" "kubeadm : $(kubeadm version)"
log "INFO" "kubelet : $(kubelet --version)"
log "INFO" "kubectl : $(kubectl version --client)"

# Étape 6 : Vérifier l'adresse IP pour éviter les conflits
log "INFO" "Étape 6 : Vérification de l'adresse IP pour éviter les conflits"
ip addr show >> "$LOG_FILE" 2>&1
POD_CIDR="10.244.0.0/16"
log "INFO" "Plage d'IP pour les pods : $POD_CIDR"

# Étape 7 : Configurer les prérequis réseau
log "INFO" "Étape 7 : Configuration des prérequis réseau"
apt install -y linux-modules-extra-$(uname -r) >> "$LOG_FILE" 2>&1
modprobe br_netfilter >> "$LOG_FILE" 2>&1
echo "br_netfilter" | tee /etc/modules-load.d/kubernetes.conf >> "$LOG_FILE" 2>&1
echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-iptables >> "$LOG_FILE" 2>&1
sysctl -w net.ipv4.ip_forward=1 >> "$LOG_FILE" 2>&1
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-kubernetes.conf >> "$LOG_FILE" 2>&1
sysctl --system >> "$LOG_FILE" 2>&1
log "INFO" "Vérification réseau :"
log "INFO" "br_netfilter : $(lsmod | grep br_netfilter)"
log "INFO" "bridge-nf-call-iptables : $(cat /proc/sys/net/bridge/bridge-nf-call-iptables)"
log "INFO" "net.ipv4.ip_forward : $(sysctl net.ipv4.ip_forward)"

# Étape 8 : Initialiser le cluster avec kubeadm
log "INFO" "Étape 8 : Initialisation du cluster avec kubeadm"
kubeadm init --pod-network-cidr="$POD_CIDR" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log "INFO" "Cluster initialisé avec succès."
else
    log "ERROR" "Échec de l'initialisation du cluster. Consultez $LOG_FILE."
    exit 1
fi

# Configurer kubectl pour l'utilisateur non-root
log "INFO" "Configuration de kubectl pour l'utilisateur $SUDO_USER"
mkdir -p "$USER_HOME/.kube" >> "$LOG_FILE" 2>&1
cp -i /etc/kubernetes/admin.conf "$USER_HOME/.kube/config" >> "$LOG_FILE" 2>&1
chown $(id -u "$SUDO_USER"):$(id -g "$SUDO_USER") "$USER_HOME/.kube/config" >> "$LOG_FILE" 2>&1
if [ -f "$USER_HOME/.kube/config" ]; then
    log "INFO" "Fichier $USER_HOME/.kube/config créé avec succès."
else
    log "ERROR" "Échec de la création de $USER_HOME/.kube/config."
    exit 1
fi

# CORRECTION MAJEURE : Suppression des taints pour single-node IMMÉDIATEMENT après l'init
log "INFO" "Configuration single-node : suppression des taints du control-plane"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- --kubeconfig=/etc/kubernetes/admin.conf >> "$LOG_FILE" 2>&1 || true
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/etc/kubernetes/admin.conf >> "$LOG_FILE" 2>&1 || true
log "INFO" "Taints supprimés pour permettre le déploiement sur le control-plane."

# Vérification que l'API server fonctionne
log "INFO" "Vérification de l'API server..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if kubectl get nodes --kubeconfig=/etc/kubernetes/admin.conf >/dev/null 2>&1; then
        log "INFO" "API server accessible."
        break
    fi
    log "INFO" "Attente de l'API server... ($elapsed/$timeout secondes)"
    sleep 10
    elapsed=$((elapsed + 10))
    if [ $elapsed -ge $timeout ]; then
        log "ERROR" "API server non accessible après $timeout secondes."
        log "ERROR" "Vérifiez les logs : sudo journalctl -u kubelet -f"
        exit 1
    fi
done

# Vérifier l'accès à kubectl
log "INFO" "Vérification de l'accès à kubectl pour $SUDO_USER"
export KUBECONFIG="$USER_HOME/.kube/config"
if ! sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get nodes >/dev/null 2>&1; then
    log "ERROR" "Échec de la vérification de kubectl. Vérifiez $USER_HOME/.kube/config."
    exit 1
fi

# Étape 9 : Installer le plugin réseau Calico
log "INFO" "Étape 9 : Installation du plugin réseau Calico"
retries=5
for i in $(seq 1 $retries); do
    log "INFO" "Tentative $i/$retries d'installation de Calico..."
    if sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml >> "$LOG_FILE" 2>&1; then
        log "INFO" "Calico installé avec succès."
        break
    else
        log "WARNING" "Échec de l'installation de Calico, tentative $i/$retries."
        sleep 30
        if [ $i -eq $retries ]; then
            log "ERROR" "Échec de l'installation de Calico après $retries tentatives."
            exit 1
        fi
    fi
done

# Attente de la disponibilité des pods Calico (timeout unifié)
log "INFO" "Attente de la disponibilité des pods Calico..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n kube-system -l k8s-app=calico-node | grep -q "Running"; then
        log "INFO" "Pods Calico sont prêts."
        break
    fi
    log "INFO" "Attente des pods Calico... ($elapsed/$timeout secondes)"
    sleep 10
    elapsed=$((elapsed + 10))
    if [ $elapsed -ge $timeout ]; then
        log "ERROR" "Les pods Calico ne sont pas prêts après $timeout secondes."
        exit 1
    fi
done

# Étape 10 : Vérifier l'état du cluster
log "INFO" "Étape 10 : Vérification de l'état du cluster"
sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get nodes >> "$LOG_FILE" 2>&1
sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n kube-system >> "$LOG_FILE" 2>&1

# Étape 11 : Configurer l'Ingress et la résolution DNS (VERSION CORRIGÉE)
log "INFO" "Étape 11 : Configuration du contrôleur NGINX Ingress"

# Installer le contrôleur NGINX Ingress avec la version pour bare-metal
log "INFO" "Installation du contrôleur NGINX Ingress pour bare-metal..."
retries=3
for i in $(seq 1 $retries); do
    log "INFO" "Tentative $i/$retries d'installation du contrôleur NGINX Ingress..."
    if sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.2/deploy/static/provider/baremetal/deploy.yaml >> "$LOG_FILE" 2>&1; then
        log "INFO" "Contrôleur NGINX Ingress installé avec succès."
        break
    else
        log "WARNING" "Échec de l'installation du contrôleur NGINX Ingress, tentative $i/$retries."
        sleep 30
        if [ $i -eq $retries ]; then
            log "ERROR" "Échec de l'installation du contrôleur NGINX Ingress après $retries tentatives."
            # Afficher les logs pour diagnostiquer
            log "INFO" "Diagnostic des pods ingress-nginx..."
            sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx >> "$LOG_FILE" 2>&1
            sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl describe pods -n ingress-nginx >> "$LOG_FILE" 2>&1
            exit 1
        fi
    fi
done

# Attente de la disponibilité des pods NGINX Ingress (timeout unifié)
log "INFO" "Attente de la disponibilité des pods NGINX Ingress..."
timeout=300  # Timeout unifié avec les autres composants
elapsed=0
while [ $elapsed -lt $timeout ]; do
    # Vérifier différents états possibles
    pod_status=$(sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    
    if echo "$pod_status" | grep -q "Running"; then
        log "INFO" "Au moins un pod NGINX Ingress est en cours d'exécution."
        # Vérifier que le contrôleur principal est prêt
        if sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -q "Running"; then
            log "INFO" "Pods NGINX Ingress sont prêts."
            break
        fi
    fi
    
    # Afficher l'état actuel pour debugging
    if [ $((elapsed % 60)) -eq 0 ]; then
        log "INFO" "État actuel des pods NGINX Ingress:"
        sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx >> "$LOG_FILE" 2>&1
    fi
    
    log "INFO" "Attente des pods NGINX Ingress... ($elapsed/$timeout secondes)"
    sleep 15
    elapsed=$((elapsed + 15))
    
    if [ $elapsed -ge $timeout ]; then
        log "ERROR" "Les pods NGINX Ingress ne sont pas prêts après $timeout secondes."
        log "ERROR" "Diagnostic final:"
        sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx >> "$LOG_FILE" 2>&1
        sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl describe pods -n ingress-nginx >> "$LOG_FILE" 2>&1
        sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get events -n ingress-nginx >> "$LOG_FILE" 2>&1
        exit 1
    fi
done

# Vérifier les pods NGINX Ingress avec plus de détails
log "INFO" "Vérification détaillée des pods NGINX Ingress..."
sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get pods -n ingress-nginx -o wide >> "$LOG_FILE" 2>&1
sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get svc -n ingress-nginx >> "$LOG_FILE" 2>&1

# CORRECTION : Configuration correcte de /etc/hosts (sans ports)
log "INFO" "Configuration de la résolution DNS locale..."
if ! grep -q "nutrition.local" /etc/hosts; then
    echo "127.0.0.1 nutrition.local" >> /etc/hosts
    log "INFO" "nutrition.local ajouté à /etc/hosts."
fi
if ! grep -q "gateway.local" /etc/hosts; then
    echo "127.0.0.1 gateway.local" >> /etc/hosts
    log "INFO" "gateway.local ajouté à /etc/hosts."
fi

# Afficher les informations de connexion
log "INFO" "Informations de connexion :"
ingress_http_port=$(sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
ingress_https_port=$(sudo -u "$SUDO_USER" KUBECONFIG="$USER_HOME/.kube/config" kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null)

if [ -n "$ingress_http_port" ]; then
    log "INFO" "Service NGINX Ingress HTTP accessible sur le port NodePort: $ingress_http_port"
    log "INFO" "Accès applications via: http://nutrition.local:$ingress_http_port"
    log "INFO" "Accès applications via: http://gateway.local:$ingress_http_port"
fi

if [ -n "$ingress_https_port" ]; then
    log "INFO" "Service NGINX Ingress HTTPS accessible sur le port NodePort: $ingress_https_port"
    log "INFO" "Accès applications via: https://nutrition.local:$ingress_https_port"
    log "INFO" "Accès applications via: https://gateway.local:$ingress_https_port"
fi

log "INFO" "Configuration NGINX Ingress terminée avec succès."

# Étape 12 : Récapitulatif final
log "INFO" "=== INSTALLATION TERMINÉE AVEC SUCCÈS ==="
log "INFO" "Cluster Kubernetes configuré en mode single-node"
log "INFO" "Composants installés :"
log "INFO" "- containerd (runtime)"
log "INFO" "- kubeadm, kubelet, kubectl"
log "INFO" "- Calico (réseau)"
log "INFO" "- NGINX Ingress Controller"
log "INFO" ""
log "INFO" "Commandes utiles :"
log "INFO" "- Voir les nodes : kubectl get nodes"
log "INFO" "- Voir les pods : kubectl get pods -A"
log "INFO" "- Voir les services : kubectl get svc -A"
log "INFO" ""
log "INFO" "Logs disponibles dans : $LOG_FILE"
log "INFO" "Configuration kubectl : $USER_HOME/.kube/config"

exit 0