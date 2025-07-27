#!/bin/bash

# Script d'installation Kubernetes avec interface interactive - VERSION CORRIGÉE
# Supporte 3 modes : Node complet, Master seul, Worker seul

set -euo pipefail

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_CONFIG_DIR="$SCRIPT_DIR/nodeConfig"
K8S_CONFIG_DIR="$SCRIPT_DIR/k8sConfig"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
MODE=""
CONFIG_FILE=""
LOG_FILE=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Fonctions de logging
log() { echo -e "$1" | tee -a "$LOG_FILE"; }
print_status() { log "${BLUE}[INFO]${NC} $1"; }
print_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { log "${YELLOW}[WARNING]${NC} $1"; }
print_error() { log "${RED}[ERROR]${NC} $1"; }
print_header() { log "${CYAN}${BOLD}$1${NC}"; }

# Affichage du banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 KUBERNETES INSTALLER                   ║"
    echo "║                     Installation Automatisée                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Menu principal
show_main_menu() {
    print_header "=== Installation Kubernetes ==="
    echo
    echo -e "${BOLD}Choisissez votre mode d'installation :${NC}"
    echo
    echo -e "${GREEN}1.${NC} ${BOLD}Node complet${NC} (Master+Worker sur même serveur)"
    echo -e "   ${CYAN}→${NC} Cluster single-node, idéal pour dev/test/homelab"
    echo
    echo -e "${YELLOW}2.${NC} ${BOLD}Master seul${NC} (génère infos pour workers)"
    echo -e "   ${CYAN}→${NC} Installation master avec HA, génère token pour workers"
    echo
    echo -e "${BLUE}3.${NC} ${BOLD}Worker seul${NC} (rejoint un master existant)"
    echo -e "   ${CYAN}→${NC} Rejoint un cluster existant avec les infos du master"
    echo
    echo -n -e "${BOLD}Choisissez votre mode [1-3]: ${NC}"
}

# Sélection du mode
select_mode() {
    while true; do
        show_banner
        show_main_menu
        
        read -r choice
        echo
        
        case $choice in
            1)
                MODE="node"
                CONFIG_DIR="$NODE_CONFIG_DIR"
                LOG_FILE="$SCRIPT_DIR/install-node-$TIMESTAMP.log"
                print_success "Mode sélectionné : Node complet (Master+Worker)"
                break
                ;;
            2)
                MODE="master"
                CONFIG_DIR="$K8S_CONFIG_DIR"
                LOG_FILE="$SCRIPT_DIR/install-master-$TIMESTAMP.log"
                print_success "Mode sélectionné : Master seul"
                break
                ;;
            3)
                MODE="worker"
                CONFIG_DIR="$K8S_CONFIG_DIR"
                LOG_FILE="$SCRIPT_DIR/install-worker-$TIMESTAMP.log"
                print_success "Mode sélectionné : Worker seul"
                break
                ;;
            *)
                echo -e "${RED}Choix invalide. Veuillez entrer 1, 2 ou 3.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Affichage des fichiers de configuration
show_config_files() {
    print_header "=== Fichiers de configuration disponibles ==="
    echo
    
    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_error "Répertoire de configuration manquant : $CONFIG_DIR"
        print_status "Créez le répertoire et ajoutez vos fichiers .conf"
        exit 1
    fi
    
    # Lister les fichiers .conf
    local configs=()
    local counter=1
    
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        configs+=("$filename")
        echo -e "${GREEN}$counter.${NC} ${BOLD}$filename${NC}"
        ((counter++))
    done < <(find "$CONFIG_DIR" -name "*.conf" -type f -print0 | sort -z)
    
    if [[ ${#configs[@]} -eq 0 ]]; then
        print_error "Aucun fichier .conf trouvé dans $CONFIG_DIR"
        print_status "Créez au moins un fichier de configuration"
        exit 1
    fi
    
    echo
    echo -n -e "${BOLD}Choisissez votre configuration [1-${#configs[@]}]: ${NC}"
    
    while true; do
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#configs[@]} ]]; then
            CONFIG_FILE="$CONFIG_DIR/${configs[$((choice-1))]}"
            local selected_file="${configs[$((choice-1))]}"
            echo
            print_success "→ Configuration sélectionnée : $MODE avec le fichier $selected_file"
            break
        else
            echo -n -e "${RED}Choix invalide.${NC} Entrez un numéro entre 1 et ${#configs[@]}: "
        fi
    done
}

# Chargement et validation de la configuration
load_and_validate_config() {
    print_status "Chargement de la configuration : $(basename "$CONFIG_FILE")"
    
    # Charger le fichier de configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Fichier de configuration introuvable : $CONFIG_FILE"
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    # Validation selon le mode
    case $MODE in
        "node")
            validate_node_config
            ;;
        "master")
            validate_master_config
            ;;
        "worker")
            validate_worker_config
            ;;
    esac
    
    print_success "Configuration validée avec succès"
}

# Validation configuration Node (Master+Worker)
validate_node_config() {
    print_status "Validation de la configuration Node (Master+Worker)..."
    
    local required_vars=(
        "K8S_VERSION"
        "INSTALL_PATH"
        "DATA_PATH"
        "CONFIG_PATH"
        "CONTAINER_RUNTIME"
        "NETWORK_PLUGIN"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Variable obligatoire manquante : $var"
            print_status "Ajoutez cette variable dans $CONFIG_FILE"
            exit 1
        fi
    done
    
    # Variables dérivées pour Node
    export NODE_TYPE="node"
    export ALLOW_MASTER_WORKLOAD="true"
    export HIGH_AVAILABILITY="false"
    export NODE_IP=$(hostname -I | awk '{print $1}')
    export KUBECONFIG_FILE="$INSTALL_PATH/kubeconfig.yaml"
    export KUBECTL_SCRIPT="$INSTALL_PATH/kubectl.sh"
    
    print_success "✅ Configuration Node validée"
    print_status "  - Version K8s : $K8S_VERSION"
    print_status "  - Runtime : $CONTAINER_RUNTIME"
    print_status "  - Réseau : $NETWORK_PLUGIN"
    print_status "  - IP Node : $NODE_IP"
}

# Validation configuration Master
validate_master_config() {
    print_status "Validation de la configuration Master..."
    
    local required_vars=(
        "K8S_VERSION"
        "INSTALL_PATH"
        "DATA_PATH"
        "CONFIG_PATH"
        "CONTAINER_RUNTIME"
        "NETWORK_PLUGIN"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Variable obligatoire manquante : $var"
            print_status "Ajoutez cette variable dans $CONFIG_FILE"
            exit 1
        fi
    done
    
    # Validation HA si activée
    if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
        if [[ -z "${CONTROL_PLANE_ENDPOINT:-}" ]]; then
            print_error "CONTROL_PLANE_ENDPOINT requis pour la haute disponibilité"
            print_status "Exemple: CONTROL_PLANE_ENDPOINT=\"k8s-cluster.domain.com:6443\""
            exit 1
        fi
    fi
    
    # Variables dérivées pour Master
    export NODE_TYPE="master"
    export ALLOW_MASTER_WORKLOAD="false"
    export NODE_IP=$(hostname -I | awk '{print $1}')
    export KUBECONFIG_FILE="$INSTALL_PATH/kubeconfig.yaml"
    export KUBECTL_SCRIPT="$INSTALL_PATH/kubectl.sh"
    export MASTER_INFO_FILE="$SCRIPT_DIR/master-info-$TIMESTAMP.txt"
    
    print_success "✅ Configuration Master validée"
    print_status "  - Version K8s : $K8S_VERSION"
    print_status "  - Runtime : $CONTAINER_RUNTIME"
    print_status "  - Réseau : $NETWORK_PLUGIN"
    print_status "  - IP Master : $NODE_IP"
    print_status "  - HA : ${HIGH_AVAILABILITY:-false}"
    if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
        print_status "  - Control Plane : ${CONTROL_PLANE_ENDPOINT}"
    fi
}

# Validation configuration Worker
validate_worker_config() {
    print_status "Validation de la configuration Worker..."
    
    local required_vars=(
        "K8S_VERSION"
        "INSTALL_PATH"
        "DATA_PATH"
        "CONFIG_PATH"
        "CONTAINER_RUNTIME"
        "MASTER_IP"
        "JOIN_TOKEN"
        "CA_CERT_HASH"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Variable obligatoire manquante : $var"
            if [[ "$var" == "MASTER_IP" ]] || [[ "$var" == "JOIN_TOKEN" ]] || [[ "$var" == "CA_CERT_HASH" ]]; then
                print_status "Ces informations sont générées lors de l'installation du Master"
                print_status "Consultez le fichier master-info-*.txt du Master"
            fi
            exit 1
        fi
    done
    
    # Variables dérivées pour Worker
    export NODE_TYPE="worker"
    export NODE_IP=$(hostname -I | awk '{print $1}')
    
    print_success "✅ Configuration Worker validée"
    print_status "  - Version K8s : $K8S_VERSION"
    print_status "  - Runtime : $CONTAINER_RUNTIME"
    print_status "  - IP Worker : $NODE_IP"
    print_status "  - Master IP : $MASTER_IP"
}

# Fonction de gestion d'erreur améliorée
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Erreur ligne $line_number (code: $exit_code)"
    print_error "Consultez les logs : $LOG_FILE"
    
    # Proposer des solutions selon l'étape
    case $line_number in
        *) 
            print_status "Pour nettoyer et recommencer :"
            print_status "1. Exécutez le script de reset : sudo ./reset-k8s.sh"
            print_status "2. Relancez l'installation"
            ;;
    esac
    
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Vérifications système
check_prerequisites() {
    print_status "Vérification des prérequis système..."
    
    # Vérifier les droits administrateur
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        print_error "Exécutez avec sudo ou en tant que root"
        exit 1
    fi
    
    # Vérifier la connectivité internet
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        print_warning "Connectivité internet limitée - certaines étapes peuvent échouer"
    fi
    
    # Vérifier les outils requis
    local tools=("curl" "wget" "systemctl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Outil requis manquant : $tool"
            exit 1
        fi
    done
    
    # Vérifier les ressources système
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 2000 ]]; then
        print_warning "RAM faible détectée: ${total_ram}MB (recommandé: >2GB)"
    fi
    
    # Vérifier l'espace disque
    local disk_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $disk_space -lt 10000000 ]]; then  # 10GB
        print_warning "Espace disque faible (recommandé: 10GB+)"
    fi
    
    # Vérifier si Kubernetes est déjà installé
    if systemctl is-active --quiet kubelet 2>/dev/null; then
        print_warning "Kubelet déjà actif - installation existante détectée"
        read -p "Continuer quand même ? (oui/non): " continue_install
        if [[ "$continue_install" != "oui" ]] && [[ "$continue_install" != "o" ]]; then
            print_error "Installation annulée"
            exit 1
        fi
    fi
    
    print_success "Prérequis validés"
}

# Création des répertoires
setup_directories() {
    print_status "Création des répertoires..."
    
    mkdir -p "$INSTALL_PATH" "$DATA_PATH" "$CONFIG_PATH"
    chmod 755 "$INSTALL_PATH" "$DATA_PATH" "$CONFIG_PATH"
    
    # Répertoire pour les backups (si activé)
    if [[ "${BACKUP_ETCD:-false}" == "true" ]]; then
        mkdir -p "$INSTALL_PATH/backups"
        chmod 700 "$INSTALL_PATH/backups"
    fi
    
    print_success "Répertoires créés"
}

# Installation des dépendances Linux
install_linux_dependencies() {
    print_status "Installation des dépendances système..."
    
    # Désactiver le swap
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    
    # Modules kernel
    cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    # Paramètres sysctl
    cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system
    
    print_success "Dépendances système configurées"
}

# Installation containerd avec gestion d'erreurs
install_containerd() {
    print_status "Installation de containerd..."
    
    # Détecter la distribution
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y containerd
        
        # Configuration containerd
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
        
        # Activer systemd cgroup driver
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y containerd.io
        
        # Configuration containerd
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    else
        print_error "Distribution non supportée"
        exit 1
    fi
    
    # Démarrer et activer containerd
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd
    
    # Vérifier que containerd fonctionne
    if ! systemctl is-active --quiet containerd; then
        print_error "Échec du démarrage de containerd"
        systemctl status containerd
        exit 1
    fi
    
    print_success "Containerd installé et configuré"
}

# Installation des outils K8s (complets pour master/node)
install_k8s_tools() {
    print_status "Installation kubeadm, kubelet, kubectl..."
    
    # Utiliser la version majeure.mineure du K8S_VERSION
    local k8s_repo_version
    k8s_repo_version=$(echo "$K8S_VERSION" | cut -d. -f1,2)
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gpg
        
        # Ajouter la clé GPG
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        
        # Ajouter le dépôt
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
        
        apt-get update
        apt-get install -y kubelet="$K8S_VERSION-*" kubeadm="$K8S_VERSION-*" kubectl="$K8S_VERSION-*"
        apt-mark hold kubelet kubeadm kubectl
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/rpm/repodata/repomd.xml.key
EOF
        
        yum install -y kubelet-"$K8S_VERSION" kubeadm-"$K8S_VERSION" kubectl-"$K8S_VERSION" --disableexcludes=kubernetes
    fi
    
    # Activer kubelet
    systemctl enable kubelet
    
    print_success "Outils K8s installés"
}

# Installation outils worker (kubelet + kubeadm seulement)
install_worker_tools() {
    print_status "Installation kubelet et kubeadm pour worker..."
    
    # Utiliser la version majeure.mineure du K8S_VERSION
    local k8s_repo_version
    k8s_repo_version=$(echo "$K8S_VERSION" | cut -d. -f1,2)
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gpg
        
        # Ajouter la clé GPG
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        
        # Ajouter le dépôt
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
        
        apt-get update
        apt-get install -y kubelet="$K8S_VERSION-*" kubeadm="$K8S_VERSION-*"
        apt-mark hold kubelet kubeadm
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/rpm/repodata/repomd.xml.key
EOF
        
        yum install -y kubelet-"$K8S_VERSION" kubeadm-"$K8S_VERSION" --disableexcludes=kubernetes
    fi
    
    # Activer kubelet
    systemctl enable kubelet
    
    print_success "Outils worker installés"
}

# Initialisation du cluster K8s avec gestion d'erreurs améliorée
initialize_k8s_cluster() {
    print_status "Initialisation du cluster K8s..."
    
    # Définir le control plane endpoint
    local control_plane_endpoint
    if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
        control_plane_endpoint="${CONTROL_PLANE_ENDPOINT}"
    else
        control_plane_endpoint="$NODE_IP:6443"
    fi
    
    # Créer le fichier de configuration kubeadm
    cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $NODE_IP
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $K8S_VERSION
controlPlaneEndpoint: "$control_plane_endpoint"
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "10.244.0.0/16"
apiServer:
  advertiseAddress: $NODE_IP
  certSANs:
  - "$NODE_IP"
  - "localhost"
  - "127.0.0.1"
$(if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
    echo "  - \"$(echo $CONTROL_PLANE_ENDPOINT | cut -d: -f1)\""
fi)
$(if [[ "${ENABLE_AUDIT:-false}" == "true" ]]; then
    cat <<EOL
  auditPolicy:
    path: /etc/kubernetes/audit-policy.yaml
  auditLogPath: /var/log/kubernetes/audit.log
EOL
fi)
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
    
    # Créer la politique d'audit si nécessaire
    if [[ "${ENABLE_AUDIT:-false}" == "true" ]]; then
        setup_audit_policy
    fi
    
    # Initialiser le cluster avec retry
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        print_status "Tentative d'initialisation $((retry_count + 1))/$max_retries..."
        
        if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
            if kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs; then
                break
            fi
        else
            if kubeadm init --config=/tmp/kubeadm-config.yaml; then
                break
            fi
        fi
        
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            print_warning "Initialisation échouée, nouvelle tentative dans 10 secondes..."
            sleep 10
        else
            print_error "Échec de l'initialisation après $max_retries tentatives"
            print_status "Vérifiez les logs : journalctl -xeu kubelet"
            exit 1
        fi
    done
    
    # Configurer kubectl
    mkdir -p "$INSTALL_PATH"
    cp /etc/kubernetes/admin.conf "$KUBECONFIG_FILE"
    chmod 644 "$KUBECONFIG_FILE"
    
    # Configurer kubectl pour root
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    print_success "Cluster K8s initialisé"
}

# Rejoindre le cluster (worker)
join_k8s_cluster() {
    print_status "Jointure au cluster K8s..."
    
    # Construire et exécuter la commande de jointure
    local join_cmd="kubeadm join $MASTER_IP --token $JOIN_TOKEN --discovery-token-ca-cert-hash $CA_CERT_HASH"
    
    print_status "Exécution de: $join_cmd"
    
    # Retry logic pour la jointure
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if $join_cmd; then
            print_success "Worker rejoint le cluster avec succès"
            return 0
        fi
        
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            print_warning "Jointure échouée, nouvelle tentative dans 10 secondes..."
            sleep 10
        else
            print_error "Échec de la jointure après $max_retries tentatives"
            exit 1
        fi
    done
}

# Autoriser les workloads sur le master (pour mode node)
allow_master_workload() {
    print_status "Configuration du mode single-node (Master+Worker)..."
    
    # Attendre que le cluster soit prêt
    local max_wait=60
    local wait_count=0
    
    while [[ $wait_count -lt $max_wait ]]; do
        if kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes &>/dev/null; then
            break
        fi
        ((wait_count++))
        sleep 2
    done
    
    # Supprimer le taint qui empêche les pods sur le master
    kubectl --kubeconfig="$KUBECONFIG_FILE" taint nodes --all node-role.kubernetes.io/control-plane- || true
    
    print_success "Master configuré pour accepter les workloads"
}

# Installation du plugin réseau avec retry
install_network_plugin() {
    print_status "Installation du plugin réseau : $NETWORK_PLUGIN..."
    
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        case "$NETWORK_PLUGIN" in
            "flannel")
                if kubectl --kubeconfig="$KUBECONFIG_FILE" apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml; then
                    break
                fi
                ;;
            "calico")
                if kubectl --kubeconfig="$KUBECONFIG_FILE" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml; then
                    break
                fi
                ;;
            "cilium")
                # Installation Cilium CLI
                if ! command -v cilium &> /dev/null; then
                    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
                    sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
                    tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
                fi
                if cilium install; then
                    break
                fi
                ;;
            *)
                print_error "Plugin réseau non supporté : $NETWORK_PLUGIN"
                exit 1
                ;;
        esac
        
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            print_warning "Installation du plugin réseau échouée, nouvelle tentative..."
            sleep 10
        else
            print_error "Échec de l'installation du plugin réseau après $max_retries tentatives"
            exit 1
        fi
    done
    
    print_success "Plugin réseau $NETWORK_PLUGIN installé"
}

# Configuration audit (pour production)
setup_audit_policy() {
    print_status "Configuration de l'audit..."
    
    mkdir -p /etc/kubernetes /var/log/kubernetes
    
    cat <<EOF > /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["default", "kube-system"]
  verbs: ["create", "update", "delete"]
- level: Request
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
EOF
    
    chmod 600 /etc/kubernetes/audit-policy.yaml
    print_success "Politique d'audit configurée"
}

# Sauvegarde des informations de jointure (Master)
save_master_info() {
    print_status "Génération des informations de jointure..."
    
    # Attendre que le cluster soit prêt
    local max_wait=60
    local wait_count=0
    
    while [[ $wait_count -lt $max_wait ]]; do
        if kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes &>/dev/null; then
            break
        fi
        ((wait_count++))
        sleep 2
    done
    
    # Générer un nouveau token (valable 24h)
    local join_token
    join_token=$(kubeadm token create --ttl=24h0m0s)
    
    local ca_cert_hash
    ca_cert_hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
    
    # Sauvegarder dans le fichier d'infos condensées
    cat <<EOF > "$MASTER_INFO_FILE"
# Informations de jointure générées le $(date)
# À utiliser dans la configuration des workers

MASTER_IP="$NODE_IP"
JOIN_TOKEN="$join_token"
CA_CERT_HASH="sha256:$ca_cert_hash"

# Commande de jointure complète pour worker :
# kubeadm join $NODE_IP --token $join_token --discovery-token-ca-cert-hash sha256:$ca_cert_hash

# Pour ajouter un master en HA, utilisez aussi :
$(if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
    local certificate_key
    certificate_key=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -n 1)
    echo "CERTIFICATE_KEY=\"$certificate_key\""
    echo "# Commande jointure master HA :"
    echo "# kubeadm join $NODE_IP --token $join_token --discovery-token-ca-cert-hash sha256:$ca_cert_hash --control-plane --certificate-key $certificate_key"
fi)
EOF
    
    # Sauvegarder les commandes dans des scripts exécutables
    echo "kubeadm join $NODE_IP --token $join_token --discovery-token-ca-cert-hash sha256:$ca_cert_hash" > "$INSTALL_PATH/join-worker.sh"
    chmod +x "$INSTALL_PATH/join-worker.sh"
    
    if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
        local certificate_key
        certificate_key=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -n 1)
        echo "kubeadm join $NODE_IP --token $join_token --discovery-token-ca-cert-hash sha256:$ca_cert_hash --control-plane --certificate-key $certificate_key" > "$INSTALL_PATH/join-master.sh"
        chmod +x "$INSTALL_PATH/join-master.sh"
    fi
    
    print_success "Informations de jointure sauvegardées"
    print_status "  - Fichier condensé : $MASTER_INFO_FILE"
    print_status "  - Script worker : $INSTALL_PATH/join-worker.sh"
    if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
        print_status "  - Script master HA : $INSTALL_PATH/join-master.sh"
    fi
}

# Configuration de backup automatique etcd
setup_etcd_backup() {
    if [[ "${BACKUP_ETCD:-false}" != "true" ]]; then
        return 0
    fi
    
    print_status "Configuration backup etcd automatique..."
    
    # Créer le script de backup
    cat <<EOF > "$INSTALL_PATH/backup-etcd.sh"
#!/bin/bash
# Script de backup etcd automatique

BACKUP_DIR="$INSTALL_PATH/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/etcd-backup-\$DATE.db"

# Créer le backup
ETCDCTL_API=3 etcdctl snapshot save "\$BACKUP_FILE" \\
    --endpoints=https://127.0.0.1:2379 \\
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
    --cert=/etc/kubernetes/pki/etcd/server.crt \\
    --key=/etc/kubernetes/pki/etcd/server.key

if [[ \$? -eq 0 ]]; then
    echo "Backup etcd créé: \$BACKUP_FILE"
    
    # Nettoyer les anciens backups (garder 7 jours)
    find "\$BACKUP_DIR" -name "etcd-backup-*.db" -mtime +7 -delete
else
    echo "Erreur lors du backup etcd"
    exit 1
fi
EOF
    
    chmod +x "$INSTALL_PATH/backup-etcd.sh"
    
    # Créer la tâche cron
    (crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_PATH/backup-etcd.sh >> $LOG_FILE 2>&1") | crontab -
    
    print_success "Backup etcd automatique configuré (quotidien à 2h)"
}

# Attente du cluster avec timeout et retry
wait_for_cluster() {
    print_status "Attente de la disponibilité du cluster..."
    
    local max_attempts=120  # Augmenté à 10 minutes
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes &>/dev/null; then
            # Vérifier que le node est Ready
            if kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes | grep -q "Ready"; then
                print_success "Cluster opérationnel !"
                kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes
                return 0
            fi
        fi
        
        ((attempt++))
        if [[ $((attempt % 10)) -eq 0 ]]; then
            print_status "Tentative $attempt/$max_attempts... (patientez, initialisation en cours)"
        fi
        sleep 5
    done
    
    print_error "Timeout : cluster non disponible après $((max_attempts * 5)) secondes"
    print_status "Diagnostic :"
    kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes 2>&1 || true
    kubectl --kubeconfig="$KUBECONFIG_FILE" get pods -A 2>&1 || true
    return 1
}

# Création du script kubectl avec diagnostic intégré
create_kubectl_script() {
    print_status "Création du script kubectl personnalisé..."
    
    cat <<EOF > "$KUBECTL_SCRIPT"
#!/bin/bash
# Script kubectl personnalisé pour $MODE

export KUBECONFIG="$KUBECONFIG_FILE"

# Fonction pour vérifier la disponibilité du cluster
check_cluster() {
    if ! kubectl get nodes &>/dev/null; then
        echo "Erreur : Cluster K8s non disponible"
        echo "Tentative de diagnostic..."
        
        # Vérifier les services
        systemctl is-active kubelet containerd || true
        
        # Vérifier les processus
        if ! pgrep -f kube-apiserver >/dev/null; then
            echo "API Server non démarré"
        fi
        
        return 1
    fi
    return 0
}

# Fonction d'auto-réparation
auto_repair() {
    echo "Tentative de réparation automatique..."
    
    # Redémarrer les services
    systemctl restart kubelet 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || true
    
    # Attendre un peu
    sleep 10
    
    # Revérifier
    if check_cluster; then
        echo "Réparation réussie !"
        return 0
    else
        echo "Réparation échouée. Consultez les logs :"
        echo "  sudo journalctl -xeu kubelet"
        echo "  sudo journalctl -xeu containerd"
        return 1
    fi
}

# Vérifier le cluster avant d'exécuter la commande
if ! check_cluster; then
    auto_repair || exit 1
fi

# Exécuter kubectl avec les arguments passés
kubectl "\$@"
EOF
    
    chmod +x "$KUBECTL_SCRIPT"
    
    # Créer aussi un alias plus simple (optionnel)
    cat <<EOF > "$INSTALL_PATH/setup-kubectl.sh"
#!/bin/bash
# Script pour configurer kubectl en mode standard

mkdir -p ~/.kube
cp "$KUBECONFIG_FILE" ~/.kube/config
chown \$(id -u):\$(id -g) ~/.kube/config

echo "Kubectl configuré en mode standard"
echo "Vous pouvez maintenant utiliser : kubectl get nodes"
EOF
    
    chmod +x "$INSTALL_PATH/setup-kubectl.sh"
    
    print_success "Scripts kubectl créés :"
    print_status "  - Script personnalisé : $KUBECTL_SCRIPT"
    print_status "  - Setup standard : $INSTALL_PATH/setup-kubectl.sh"
}

# Tests du cluster avec diagnostics détaillés
test_cluster() {
    print_status "Tests du cluster K8s..."
    
    # Test des nœuds
    if "$KUBECTL_SCRIPT" get nodes | grep -q "Ready"; then
        print_success "✅ Nœuds opérationnels"
    else
        print_warning "⚠️ Problème détecté avec les nœuds"
        "$KUBECTL_SCRIPT" get nodes || true
    fi
    
    # Test des pods système
    local system_pods_ready=0
    local total_system_pods=0
    
    if "$KUBECTL_SCRIPT" get pods -n kube-system &>/dev/null; then
        system_pods_ready=$("$KUBECTL_SCRIPT" get pods -n kube-system --no-headers | grep -c "Running" || echo "0")
        total_system_pods=$("$KUBECTL_SCRIPT" get pods -n kube-system --no-headers | wc -l || echo "0")
        
        if [[ $system_pods_ready -gt 0 ]]; then
            print_success "✅ Pods système fonctionnels ($system_pods_ready/$total_system_pods)"
        else
            print_warning "⚠️ Aucun pod système en fonctionnement"
        fi
    else
        print_warning "⚠️ Impossible d'accéder aux pods système"
    fi
    
    # Test de déploiement (seulement pour master et node)
    if [[ "$MODE" == "master" ]] || [[ "$MODE" == "node" ]]; then
        print_status "Test de déploiement simple..."
        if "$KUBECTL_SCRIPT" run test-nginx --image=nginx --rm -it --restart=Never --timeout=30s -- echo "Test OK" 2>/dev/null; then
            print_success "✅ Test de déploiement réussi"
        else
            print_warning "⚠️ Test de déploiement échoué (normal si pas encore prêt)"
        fi
    fi
    
    # Afficher l'état global
    echo
    print_status "État du cluster :"
    "$KUBECTL_SCRIPT" get nodes -o wide 2>/dev/null || true
    echo
    print_status "Pods système :"
    "$KUBECTL_SCRIPT" get pods -n kube-system 2>/dev/null || true
    
    print_success "Tests terminés"
}

# Installation selon le mode Node (Master+Worker)
install_node_mode() {
    print_header "🚀 Installation Node complet (Master+Worker)"
    
    # Installation des composants
    install_linux_dependencies
    install_containerd
    install_k8s_tools
    
    # Initialisation du cluster
    initialize_k8s_cluster
    
    # Installation du réseau (avant de permettre les workloads)
    install_network_plugin
    
    # Configuration single-node
    allow_master_workload
    
    print_success "Installation Node terminée"
}

# Installation selon le mode Master
install_master_mode() {
    print_header "🚀 Installation Master avec haute disponibilité"
    
    # Installation des composants
    install_linux_dependencies
    install_containerd
    install_k8s_tools
    
    # Initialisation du cluster
    initialize_k8s_cluster
    
    # Installation du réseau
    install_network_plugin
    
    # Génération des informations pour les workers
    save_master_info
    
    # Configuration backup si activé
    setup_etcd_backup
    
    print_success "Installation Master terminée"
}

# Installation selon le mode Worker
install_worker_mode() {
    print_header "🚀 Installation Worker"
    
    # Installation des composants
    install_linux_dependencies
    install_containerd
    install_worker_tools
    
    # Rejoindre le cluster
    join_k8s_cluster
    
    print_success "Installation Worker terminée"
}

# Affichage des informations finales avec diagnostics
show_final_info() {
    echo
    print_header "=============================================="
    print_header "    Installation terminée avec succès ! 🎉"
    print_header "=============================================="
    echo
    
    case $MODE in
        "node")
            log "🏠 ${BOLD}Mode : Node complet (Master+Worker)${NC}"
            log "🌍 IP du node : $NODE_IP"
            log "🐳 Runtime : $CONTAINER_RUNTIME"
            log "🌐 Plugin réseau : $NETWORK_PLUGIN"
            echo
            log "📁 ${BOLD}Fichiers importants :${NC}"
            log "   - Kubeconfig : $KUBECONFIG_FILE"
            log "   - Script kubectl : $KUBECTL_SCRIPT"
            log "   - Setup standard : $INSTALL_PATH/setup-kubectl.sh"
            log "   - Logs : $LOG_FILE"
            echo
            log "🚀 ${BOLD}Utilisation :${NC}"
            log "   # Méthode 1 : Script personnalisé"
            log "   $KUBECTL_SCRIPT get nodes"
            log "   $KUBECTL_SCRIPT get pods --all-namespaces"
            echo
            log "   # Méthode 2 : Setup standard"
            log "   $INSTALL_PATH/setup-kubectl.sh"
            log "   kubectl get nodes"
            echo
            log "🧪 ${BOLD}Tests rapides :${NC}"
            log "   $KUBECTL_SCRIPT run nginx --image=nginx"
            log "   $KUBECTL_SCRIPT get pods"
            log "   $KUBECTL_SCRIPT delete pod nginx"
            echo
            log "✨ ${GREEN}Cluster single-node prêt ! Vous pouvez déployer vos applications.${NC}"
            ;;
            
        "master")
            log "🏢 ${BOLD}Mode : Master seul${NC}"
            log "🌍 IP du master : $NODE_IP"
            log "🐳 Runtime : $CONTAINER_RUNTIME"
            log "🌐 Plugin réseau : $NETWORK_PLUGIN"
            log "🔧 HA : ${HIGH_AVAILABILITY:-false}"
            echo
            log "📁 ${BOLD}Fichiers importants :${NC}"
            log "   - Kubeconfig : $KUBECONFIG_FILE"
            log "   - Script kubectl : $KUBECTL_SCRIPT"
            log "   - Setup standard : $INSTALL_PATH/setup-kubectl.sh"
            log "   - Infos jointure : $MASTER_INFO_FILE"
            log "   - Script worker : $INSTALL_PATH/join-worker.sh"
            if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
                log "   - Script master HA : $INSTALL_PATH/join-master.sh"
            fi
            log "   - Logs : $LOG_FILE"
            echo
            log "🚀 ${BOLD}Utilisation :${NC}"
            log "   $KUBECTL_SCRIPT get nodes"
            log "   $KUBECTL_SCRIPT get pods --all-namespaces"
            echo
            log "🔗 ${BOLD}Pour ajouter des workers :${NC}"
            log "   1. Consultez le fichier : $MASTER_INFO_FILE"
            log "   2. Copiez les variables MASTER_IP, JOIN_TOKEN, CA_CERT_HASH"
            log "   3. Ajoutez-les dans la config du worker"
            log "   4. Lancez : ./install-k8s.sh puis choisissez mode 3 (Worker)"
            if [[ "${HIGH_AVAILABILITY:-false}" == "true" ]]; then
                echo
                log "🔗 ${BOLD}Pour ajouter des masters HA :${NC}"
                log "   1. Utilisez le script : $INSTALL_PATH/join-master.sh"
                log "   2. Ou consultez les infos dans : $MASTER_INFO_FILE"
            fi
            ;;
            
        "worker")
            log "⚙️ ${BOLD}Mode : Worker${NC}"
            log "🌍 IP du worker : $NODE_IP"
            log "🐳 Runtime : $CONTAINER_RUNTIME"
            log "🔗 Master : $MASTER_IP"
            echo
            log "📁 ${BOLD}Fichiers importants :${NC}"
            log "   - Logs : $LOG_FILE"
            echo
            log "✅ ${GREEN}Worker ajouté au cluster avec succès !${NC}"
            log "Vous pouvez vérifier depuis le master avec :"
            log "   kubectl get nodes"
            ;;
    esac
    
    echo
    # Afficher un résumé de l'état du cluster
    if [[ "$MODE" != "worker" ]]; then
        log "📊 ${BOLD}État actuel du cluster :${NC}"
        "$KUBECTL_SCRIPT" get nodes 2>/dev/null || echo "   Cluster non accessible"
        echo
        log "🔍 ${BOLD}Pour surveiller l'état en temps réel :${NC}"
        log "   watch '$KUBECTL_SCRIPT get pods -A'"
    fi
    
    print_header "=============================================="
}

# Fonction de diagnostic post-installation
post_install_diagnostics() {
    if [[ "$MODE" == "worker" ]]; then
        return 0
    fi
    
    print_status "Diagnostic post-installation..."
    
    # Vérifier les pods système
    local pending_pods
    pending_pods=$("$KUBECTL_SCRIPT" get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ $pending_pods -gt 0 ]]; then
        print_warning "Il y a $pending_pods pod(s) en attente"
        print_status "Ceci est normal pendant les premières minutes après l'installation"
    fi
    
    # Conseils selon l'état
    local ready_nodes
    ready_nodes=$("$KUBECTL_SCRIPT" get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    
    if [[ $ready_nodes -eq 0 ]]; then
        print_warning "Aucun nœud Ready détecté"
        print_status "Patientez quelques minutes puis vérifiez avec :"
        print_status "  $KUBECTL_SCRIPT get nodes"
        print_status "  $KUBECTL_SCRIPT get pods -A"
    fi
}

# Fonction principale avec gestion d'erreurs complète
main() {
    # Initialiser le log
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="$SCRIPT_DIR/install-$TIMESTAMP.log"
    
    # Rediriger toutes les erreurs vers le log
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    print_status "Démarrage de l'installation Kubernetes"
    print_status "Log : $LOG_FILE"
    
    # Banner et sélection du mode
    show_banner
    select_mode
    
    # Sélection de la configuration
    show_config_files
    
    # Validation et démarrage
    echo
    print_header "🔍 Validation de la configuration..."
    load_and_validate_config
    
    echo
    print_header "⚙️ Vérification des prérequis..."
    check_prerequisites
    setup_directories
    
    # Installation selon le mode choisi
    echo
    case $MODE in
        "node")
            install_node_mode
            if wait_for_cluster; then
                create_kubectl_script
                test_cluster
                post_install_diagnostics
                show_final_info
            else
                print_error "Échec de l'installation Node"
                print_status "Consultez les logs pour plus de détails : $LOG_FILE"
                exit 1
            fi
            ;;
        "master")
            install_master_mode
            if wait_for_cluster; then
                create_kubectl_script
                test_cluster
                post_install_diagnostics
                show_final_info
            else
                print_error "Échec de l'installation Master"
                print_status "Consultez les logs pour plus de détails : $LOG_FILE"
                exit 1
            fi
            ;;
        "worker")
            install_worker_mode
            # Pas besoin d'attendre le cluster pour un worker
            show_final_info
            ;;
    esac
    
    echo
    print_success "🎉 Installation $MODE terminée avec succès !"
    print_status "📋 Consultez les logs détaillés : $LOG_FILE"
    
    # Message final selon le mode
    case $MODE in
        "node"|"master")
            echo
            print_status "🚀 Pour utiliser votre cluster :"
            print_status "   Option 1 (Recommandée) : $INSTALL_PATH/setup-kubectl.sh && kubectl get nodes"
            print_status "   Option 2 (Avancée) : $KUBECTL_SCRIPT get nodes"
            ;;
    esac
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi