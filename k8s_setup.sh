#!/bin/bash

# Script d'installation Kubernetes modulaire et sélectif
# Version améliorée avec gestion des modes et architectures

set -euo pipefail

# Configuration par défaut
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="kubernetes_setup.log"
CONFIG_FILE="cluster.conf"

# Variables globales
CLUSTER_ARCHITECTURE=""
INSTALL_MODE=""
SELECTED_COMPONENTS=""
INTERACTIVE_MODE=false
FORCE_REINSTALL=false

# Composants disponibles
declare -A COMPONENTS=(
    ["base"]="Mise à jour système + dépendances de base"
    ["containerd"]="Installation et configuration containerd"
    ["kubernetes"]="Installation kubeadm, kubelet, kubectl"
    ["network"]="Configuration réseau + modules kernel"
    ["cluster-init"]="Initialisation du cluster (control-plane seulement)"
    ["cluster-join"]="Rejoindre un cluster existant (worker seulement)"
    ["cni"]="Installation du plugin réseau (Calico)"
    ["ingress"]="Installation du contrôleur Ingress"
    ["dns"]="Configuration DNS locale"
)

# Modes d'installation
declare -A INSTALL_MODES=(
    ["control-plane"]="Installation complète du control-plane"
    ["worker"]="Installation worker pour rejoindre un cluster"
    ["single-node"]="Installation complète single-node"
    ["components"]="Installation sélective par composants"
)

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Afficher cette aide
    -a, --architecture      Architecture du cluster (single-node|multi-node|multi-master)
    -m, --mode             Mode d'installation (control-plane|worker|single-node|components)
    -c, --components       Composants à installer (séparés par des virgules)
    -i, --interactive      Mode interactif
    -f, --force            Forcer la réinstallation
    -j, --join-token       Token pour rejoindre un cluster (mode worker)
    -e, --endpoint         Endpoint du control-plane (mode worker)
    --config-file          Fichier de configuration personnalisé
    --dry-run             Afficher les actions sans les exécuter

ARCHITECTURES:
    single-node     Un seul node (control-plane + workers)
    multi-node      Control-plane dédié + workers séparés
    multi-master    Plusieurs control-planes (HA)

MODES:
    control-plane   Installation du control-plane seulement
    worker         Installation worker pour rejoindre un cluster
    single-node    Installation complète sur un seul node
    components     Installation sélective par composants

COMPOSANTS:
    base           Mise à jour système + dépendances
    containerd     Runtime de conteneurs
    kubernetes     outils Kubernetes (kubeadm, kubelet, kubectl)
    network        Configuration réseau
    cluster-init   Initialisation du cluster
    cluster-join   Rejoindre un cluster
    cni            Plugin réseau (Calico)
    ingress        Contrôleur Ingress
    dns            Configuration DNS

EXEMPLES:
    # Installation interactive
    $0 --interactive

    # Installation single-node complète
    $0 --architecture=single-node --mode=single-node

    # Installation control-plane multi-node
    $0 --architecture=multi-node --mode=control-plane

    # Installation worker
    $0 --mode=worker --join-token=<token> --endpoint=<control-plane-ip>:6443

    # Installation sélective
    $0 --mode=components --components=base,containerd,kubernetes

    # Test sans installation
    $0 --architecture=single-node --mode=single-node --dry-run
EOF
}

# Fonction de logging
log() {
    local type="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$type] $message" | tee -a "$LOG_FILE"
}

# Fonction pour charger la configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log "INFO" "Chargement de la configuration depuis $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Fonction pour sauvegarder la configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Configuration du cluster Kubernetes
CLUSTER_ARCHITECTURE="$CLUSTER_ARCHITECTURE"
INSTALL_MODE="$INSTALL_MODE"
SELECTED_COMPONENTS="$SELECTED_COMPONENTS"
INSTALL_DATE="$(date)"
EOF
    log "INFO" "Configuration sauvegardée dans $CONFIG_FILE"
}

# Fonction pour afficher les modes disponibles
show_modes() {
    log "INFO" "=== MODES D'INSTALLATION DISPONIBLES ==="
    for mode in "${!INSTALL_MODES[@]}"; do
        log "INFO" "[$mode] ${INSTALL_MODES[$mode]}"
    done
    echo
}

# Fonction pour afficher les composants disponibles
show_components() {
    log "INFO" "=== COMPOSANTS DISPONIBLES ==="
    for component in "${!COMPONENTS[@]}"; do
        log "INFO" "[$component] ${COMPONENTS[$component]}"
    done
    echo
}

# Fonction pour sélectionner le mode d'installation
select_install_mode() {
    local selected_mode=""
    
    show_modes
    
    while true; do
        read -p "Sélectionnez le mode d'installation [control-plane/worker/single-node/components]: " selected_mode
        
        if [[ -n "${INSTALL_MODES[$selected_mode]}" ]]; then
            log "INFO" "Mode sélectionné: ${INSTALL_MODES[$selected_mode]}"
            echo "$selected_mode"
            return 0
        else
            log "ERROR" "Mode invalide. Veuillez choisir parmi: ${!INSTALL_MODES[*]}"
        fi
    done
}

# Fonction pour sélectionner les composants
select_components() {
    local selected_components=""
    
    show_components
    
    log "INFO" "Sélectionnez les composants à installer (séparés par des virgules):"
    log "INFO" "Exemple: base,containerd,kubernetes"
    read -p "Composants: " selected_components
    
    # Validation des composants
    IFS=',' read -ra ADDR <<< "$selected_components"
    for component in "${ADDR[@]}"; do
        if [[ -z "${COMPONENTS[$component]}" ]]; then
            log "ERROR" "Composant invalide: $component"
            return 1
        fi
    done
    
    echo "$selected_components"
}

# Fonction pour installer un composant spécifique
install_component() {
    local component="$1"
    
    log "INFO" "Installation du composant: $component"
    
    case "$component" in
        "base")
            install_base_system
            ;;
        "containerd")
            install_containerd
            ;;
        "kubernetes")
            install_kubernetes_tools
            ;;
        "network")
            configure_network_prerequisites
            ;;
        "cluster-init")
            initialize_cluster
            ;;
        "cluster-join")
            join_cluster
            ;;
        "cni")
            install_cni_plugin
            ;;
        "ingress")
            install_ingress_controller
            ;;
        "dns")
            configure_dns
            ;;
        *)
            log "ERROR" "Composant inconnu: $component"
            return 1
            ;;
    esac
}

# Fonction pour installer le système de base
install_base_system() {
    log "INFO" "=== INSTALLATION DU SYSTÈME DE BASE ==="
    
    # Mise à jour du système
    apt update >> "$LOG_FILE" 2>&1
    apt upgrade -y >> "$LOG_FILE" 2>&1
    
    # Installation des dépendances
    apt install -y curl apt-transport-https ca-certificates gpg >> "$LOG_FILE" 2>&1
    
    # Désactivation du swap
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        swapoff -a >> "$LOG_FILE" 2>&1
        sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
        log "INFO" "Swap désactivé"
    fi
    
    log "INFO" "Système de base installé avec succès"
}

# Fonction pour installer containerd
install_containerd() {
    log "INFO" "=== INSTALLATION DE CONTAINERD ==="
    
    apt install -y containerd >> "$LOG_FILE" 2>&1
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml >> "$LOG_FILE" 2>&1
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl restart containerd >> "$LOG_FILE" 2>&1
    systemctl enable containerd >> "$LOG_FILE" 2>&1
    
    log "INFO" "containerd installé avec succès"
}

# Fonction pour installer les outils Kubernetes
install_kubernetes_tools() {
    log "INFO" "=== INSTALLATION DES OUTILS KUBERNETES ==="
    
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list >> "$LOG_FILE" 2>&1
    
    apt update >> "$LOG_FILE" 2>&1
    apt install -y kubeadm kubelet kubectl >> "$LOG_FILE" 2>&1
    apt-mark hold kubeadm kubelet kubectl >> "$LOG_FILE" 2>&1
    
    log "INFO" "Outils Kubernetes installés avec succès"
}

# Fonction pour configurer les prérequis réseau
configure_network_prerequisites() {
    log "INFO" "=== CONFIGURATION DES PRÉREQUIS RÉSEAU ==="
    
    apt install -y linux-modules-extra-$(uname -r) >> "$LOG_FILE" 2>&1
    modprobe br_netfilter >> "$LOG_FILE" 2>&1
    echo "br_netfilter" | tee /etc/modules-load.d/kubernetes.conf >> "$LOG_FILE" 2>&1
    
    cat > /etc/sysctl.d/99-kubernetes.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    
    sysctl --system >> "$LOG_FILE" 2>&1
    
    log "INFO" "Prérequis réseau configurés avec succès"
}

# Fonction pour initialiser le cluster
initialize_cluster() {
    log "INFO" "=== INITIALISATION DU CLUSTER ==="
    
    local pod_cidr="10.244.0.0/16"
    
    kubeadm init --pod-network-cidr="$pod_cidr" >> "$LOG_FILE" 2>&1
    
    # Configuration kubectl
    local user_home="/home/${SUDO_USER:-$USER}"
    mkdir -p "$user_home/.kube"
    cp -i /etc/kubernetes/admin.conf "$user_home/.kube/config"
    chown $(id -u ${SUDO_USER:-$USER}):$(id -g ${SUDO_USER:-$USER}) "$user_home/.kube/config"
    
    # Gestion des taints selon l'architecture
    if [[ "$CLUSTER_ARCHITECTURE" == "single-node" ]]; then
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- --kubeconfig=/etc/kubernetes/admin.conf >> "$LOG_FILE" 2>&1 || true
        kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/etc/kubernetes/admin.conf >> "$LOG_FILE" 2>&1 || true
        log "INFO" "Taints supprimés pour configuration single-node"
    fi
    
    log "INFO" "Cluster initialisé avec succès"
}

# Fonction pour rejoindre un cluster
join_cluster() {
    log "INFO" "=== REJOINDRE UN CLUSTER ==="
    
    if [[ -z "${JOIN_TOKEN:-}" ]] || [[ -z "${CONTROL_PLANE_ENDPOINT:-}" ]]; then
        log "ERROR" "Token et endpoint du control-plane requis pour rejoindre un cluster"
        log "ERROR" "Utilisez: --join-token=<token> --endpoint=<ip>:6443"
        return 1
    fi
    
    kubeadm join "$CONTROL_PLANE_ENDPOINT" --token "$JOIN_TOKEN" --discovery-token-unsafe-skip-ca-verification >> "$LOG_FILE" 2>&1
    
    log "INFO" "Node ajouté au cluster avec succès"
}

# Fonction pour installer le plugin CNI
install_cni_plugin() {
    log "INFO" "=== INSTALLATION DU PLUGIN CNI (CALICO) ==="
    
    local user_home="/home/${SUDO_USER:-$USER}"
    local kubeconfig="$user_home/.kube/config"
    
    if [[ ! -f "$kubeconfig" ]]; then
        log "ERROR" "Configuration kubectl non trouvée. Initialisez d'abord le cluster."
        return 1
    fi
    
    sudo -u "${SUDO_USER:-$USER}" KUBECONFIG="$kubeconfig" kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml >> "$LOG_FILE" 2>&1
    
    log "INFO" "Plugin CNI Calico installé avec succès"
}

# Fonction pour installer le contrôleur Ingress
install_ingress_controller() {
    log "INFO" "=== INSTALLATION DU CONTRÔLEUR INGRESS ==="
    
    local user_home="/home/${SUDO_USER:-$USER}"
    local kubeconfig="$user_home/.kube/config"
    
    sudo -u "${SUDO_USER:-$USER}" KUBECONFIG="$kubeconfig" kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.2/deploy/static/provider/baremetal/deploy.yaml >> "$LOG_FILE" 2>&1
    
    log "INFO" "Contrôleur Ingress installé avec succès"
}

# Fonction pour configurer le DNS
configure_dns() {
    log "INFO" "=== CONFIGURATION DNS ==="
    
    if ! grep -q "nutrition.local" /etc/hosts; then
        echo "127.0.0.1 nutrition.local" >> /etc/hosts
    fi
    if ! grep -q "gateway.local" /etc/hosts; then
        echo "127.0.0.1 gateway.local" >> /etc/hosts
    fi
    
    log "INFO" "Configuration DNS terminée"
}

# Fonction pour valider les prérequis
validate_prerequisites() {
    log "INFO" "=== VALIDATION DES PRÉREQUIS ==="
    
    # Vérification des privilèges
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "Ce script doit être exécuté avec sudo"
        return 1
    fi
    
    # Vérification des ports (pour control-plane)
    if [[ "$INSTALL_MODE" == "control-plane" ]] || [[ "$INSTALL_MODE" == "single-node" ]]; then
        for port in 6443 10250 10257 2379 2380; do
            if netstat -tulnp 2>/dev/null | grep -q ":${port}"; then
                log "ERROR" "Le port ${port} est déjà utilisé"
                return 1
            fi
        done
    fi
    
    log "INFO" "Prérequis validés avec succès"
}

# Fonction pour afficher l'état du cluster
show_cluster_status() {
    log "INFO" "=== ÉTAT DU CLUSTER ==="
    
    local user_home="/home/${SUDO_USER:-$USER}"
    local kubeconfig="$user_home/.kube/config"
    
    if [[ -f "$kubeconfig" ]]; then
        sudo -u "${SUDO_USER:-$USER}" KUBECONFIG="$kubeconfig" kubectl get nodes >> "$LOG_FILE" 2>&1
        sudo -u "${SUDO_USER:-$USER}" KUBECONFIG="$kubeconfig" kubectl get pods -A >> "$LOG_FILE" 2>&1
    else
        log "WARNING" "Configuration kubectl non trouvée"
    fi
}

# Fonction pour générer les instructions de jointure
generate_join_instructions() {
    log "INFO" "=== INSTRUCTIONS DE JOINTURE ==="
    
    if [[ "$INSTALL_MODE" == "control-plane" ]] || [[ "$INSTALL_MODE" == "single-node" ]]; then
        log "INFO" "Pour ajouter des worker nodes, utilisez:"
        kubeadm token create --print-join-command 2>/dev/null || log "WARNING" "Impossible de générer la commande de jointure"
    fi
}

# Fonction principale d'orchestration
orchestrate_installation() {
    log "INFO" "=== DÉBUT DE L'INSTALLATION ==="
    log "INFO" "Architecture: $CLUSTER_ARCHITECTURE"
    log "INFO" "Mode: $INSTALL_MODE"
    
    # Validation des prérequis
    validate_prerequisites
    
    case "$INSTALL_MODE" in
        "single-node")
            install_component "base"
            install_component "containerd"
            install_component "kubernetes"
            install_component "network"
            install_component "cluster-init"
            install_component "cni"
            install_component "ingress"
            install_component "dns"
            ;;
            
        "control-plane")
            install_component "base"
            install_component "containerd"
            install_component "kubernetes"
            install_component "network"
            install_component "cluster-init"
            install_component "cni"
            install_component "ingress"
            ;;
            
        "worker")
            install_component "base"
            install_component "containerd"
            install_component "kubernetes"
            install_component "network"
            install_component "cluster-join"
            ;;
            
        "components")
            IFS=',' read -ra ADDR <<< "$SELECTED_COMPONENTS"
            for component in "${ADDR[@]}"; do
                install_component "$component"
            done
            ;;
    esac
    
    # Sauvegarde de la configuration
    save_config
    
    # Affichage de l'état final
    show_cluster_status
    
    # Instructions de jointure si applicable
    generate_join_instructions
    
    log "INFO" "=== INSTALLATION TERMINÉE ==="
}

# Fonction pour le mode interactif
interactive_mode() {
    log "INFO" "=== MODE INTERACTIF ==="
    
    # Chargement de la configuration existante
    load_config
    
    # Sélection de l'architecture
    if [[ -z "$CLUSTER_ARCHITECTURE" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/k8s_architecture_module.sh"
        CLUSTER_ARCHITECTURE=$(select_architecture)
    fi
    
    # Sélection du mode d'installation
    if [[ -z "$INSTALL_MODE" ]]; then
        INSTALL_MODE=$(select_install_mode)
    fi
    
    # Sélection des composants si nécessaire
    if [[ "$INSTALL_MODE" == "components" ]] && [[ -z "$SELECTED_COMPONENTS" ]]; then
        SELECTED_COMPONENTS=$(select_components)
    fi
    
    # Demande des paramètres supplémentaires si nécessaire
    if [[ "$INSTALL_MODE" == "worker" ]]; then
        if [[ -z "${JOIN_TOKEN:-}" ]]; then
            read -p "Token de jointure: " JOIN_TOKEN
        fi
        if [[ -z "${CONTROL_PLANE_ENDPOINT:-}" ]]; then
            read -p "Endpoint du control-plane (IP:6443): " CONTROL_PLANE_ENDPOINT
        fi
    fi
    
    # Confirmation avant installation
    log "INFO" "=== RÉCAPITULATIF ==="
    log "INFO" "Architecture: $CLUSTER_ARCHITECTURE"
    log "INFO" "Mode: $INSTALL_MODE"
    [[ -n "$SELECTED_COMPONENTS" ]] && log "INFO" "Composants: $SELECTED_COMPONENTS"
    
    read -p "Continuer avec cette configuration ? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Installation annulée"
        exit 0
    fi
}

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--architecture)
            CLUSTER_ARCHITECTURE="$2"
            shift 2
            ;;
        -m|--mode)
            INSTALL_MODE="$2"
            shift 2
            ;;
        -c|--components)
            SELECTED_COMPONENTS="$2"
            shift 2
            ;;
        -i|--interactive)
            INTERACTIVE_MODE=true
            shift
            ;;
        -f|--force)
            FORCE_REINSTALL=true
            shift
            ;;
        -j|--join-token)
            JOIN_TOKEN="$2"
            shift 2
            ;;
        -e|--endpoint)
            CONTROL_PLANE_ENDPOINT="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log "ERROR" "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Point d'entrée principal
main() {
    log "INFO" "Démarrage du script d'installation Kubernetes"
    
    # Mode interactif
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        interactive_mode
    fi
    
    # Validation des paramètres
    if [[ -z "$CLUSTER_ARCHITECTURE" ]] || [[ -z "$INSTALL_MODE" ]]; then
        log "ERROR" "Architecture et mode d'installation requis"
        log "ERROR" "Utilisez --help pour plus d'informations"
        exit 1
    fi
    
    # Mode dry-run
    if [[ "${DRY_RUN:-false}" == true ]]; then
        log "INFO" "MODE DRY-RUN - Aucune installation ne sera effectuée"
        log "INFO" "Architecture: $CLUSTER_ARCHITECTURE"
        log "INFO" "Mode: $INSTALL_MODE"
        [[ -n "$SELECTED_COMPONENTS" ]] && log "INFO" "Composants: $SELECTED_COMPONENTS"
        exit 0
    fi
    
    # Lancement de l'installation
    orchestrate_installation
}

# Lancement du script
main "$@"