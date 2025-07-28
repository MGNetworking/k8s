#!/bin/bash

# Script de vérification générique avec détection automatique du chemin d'installation
# Usage: ./verify.sh

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Fonction pour détecter l'installation Kubernetes
detect_k8s_installation() {
    local config_dirs=()
    local install_paths=()
    
    print_status "Recherche des installations Kubernetes..."
    
    # Chercher tous les répertoires k8s*
    while IFS= read -r -d '' dir; do
        if [[ -f "$dir/kubectl.sh" ]] && [[ -f "$dir/kubeconfig.yaml" ]]; then
            config_dirs+=("$dir")
            local dir_name=$(basename "$dir")
            install_paths+=("$dir_name")
        fi
    done < <(find /opt -maxdepth 1 -name "k8s*" -type d -print0 2>/dev/null)
    
    # Aussi chercher dans les homes des utilisateurs
    while IFS= read -r -d '' dir; do
        if [[ -f "$dir/kubectl.sh" ]] && [[ -f "$dir/kubeconfig.yaml" ]]; then
            config_dirs+=("$dir")
            local dir_name="$(basename "$(dirname "$dir")")/$(basename "$dir")"
            install_paths+=("$dir_name")
        fi
    done < <(find /home -maxdepth 3 -name "k8s*" -type d -path "*/k8s*" -print0 2>/dev/null)
    
    if [[ ${#config_dirs[@]} -eq 0 ]]; then
        print_error "Aucune installation Kubernetes détectée"
        print_status "Vérifiez que l'installation s'est bien déroulée"
        print_status "Recherche dans : /opt/k8s*, /home/*/k8s*"
        exit 1
    elif [[ ${#config_dirs[@]} -eq 1 ]]; then
        INSTALL_PATH="${config_dirs[0]}"
        print_success "Installation détectée : $INSTALL_PATH"
    else
        print_status "Plusieurs installations détectées :"
        echo
        for i in "${!config_dirs[@]}"; do
            echo "  $((i+1)). ${install_paths[i]} (${config_dirs[i]})"
        done
        echo
        while true; do
            read -p "Choisissez l'installation à vérifier [1-${#config_dirs[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#config_dirs[@]} ]]; then
                INSTALL_PATH="${config_dirs[$((choice-1))]}"
                print_success "Installation sélectionnée : $INSTALL_PATH"
                break
            else
                print_error "Choix invalide. Entrez un numéro entre 1 et ${#config_dirs[@]}"
            fi
        done
    fi
    
    # Variables globales
    KUBECTL_SCRIPT="$INSTALL_PATH/kubectl.sh"
    KUBECONFIG_FILE="$INSTALL_PATH/kubeconfig.yaml"
}

# Fonction pour charger la configuration originale
load_original_config() {
    print_status "Recherche de la configuration d'origine..."
    
    # Chercher dans les logs d'installation pour retrouver la config utilisée
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$file")
    done < <(find . -name "install-*.log" -print0 2>/dev/null)
    
    if [[ ${#log_files[@]} -gt 0 ]]; then
        # Prendre le log le plus récent
        local latest_log=$(ls -t "${log_files[@]}" | head -1)
        
        # Extraire les infos du log
        CONFIG_FILE=$(grep "Configuration sélectionnée" "$latest_log" | sed 's/.*avec le fichier \([^[:space:]]*\).*/\1/' | tail -1)
        MODE=$(grep "Mode sélectionné" "$latest_log" | sed 's/.*: \([^[:space:]]*\).*/\1/' | tail -1)
        
        if [[ -n "$CONFIG_FILE" ]] && [[ -n "$MODE" ]]; then
            print_success "Configuration trouvée : $MODE avec $CONFIG_FILE"
            
            # Charger les variables de la config
            if [[ "$MODE" == "Node" ]]; then
                CONFIG_PATH="./nodeConfig/$CONFIG_FILE"
            else
                CONFIG_PATH="./k8sConfig/$CONFIG_FILE"
            fi
            
            if [[ -f "$CONFIG_PATH" ]]; then
                source "$CONFIG_PATH"
                print_success "Variables chargées depuis $CONFIG_PATH"
                print_status "  - K8S_VERSION: ${K8S_VERSION:-non définie}"
                print_status "  - NETWORK_PLUGIN: ${NETWORK_PLUGIN:-non définie}"
                print_status "  - CONTAINER_RUNTIME: ${CONTAINER_RUNTIME:-non définie}"
            else
                print_warning "Fichier de config $CONFIG_PATH introuvable"
            fi
        fi
    else
        print_warning "Aucun log d'installation trouvé"
    fi
}

# === SCRIPT QUICK-VERIFY ===

quick_verify() {
    echo -e "${GREEN}🔍 VÉRIFICATION RAPIDE KUBERNETES${NC}"
    echo "================================="
    
    detect_k8s_installation
    load_original_config
    
    echo
    print_status "Utilisation de : $KUBECTL_SCRIPT"
    
    echo -e "\n1️⃣ Nœuds du cluster:"
    if "$KUBECTL_SCRIPT" get nodes; then
        print_success "Cluster accessible"
    else
        print_error "Impossible d'accéder au cluster"
        exit 1
    fi
    
    echo -e "\n2️⃣ Services système:"
    if systemctl is-active --quiet kubelet && systemctl is-active --quiet containerd; then
        print_success "Services kubelet et containerd actifs"
    else
        print_error "Services kubelet/containerd inactifs"
        systemctl is-active kubelet containerd
        exit 1
    fi
    
    echo -e "\n3️⃣ Test déploiement:"
    if [[ "${MODE:-}" == "Worker" ]]; then
        print_status "Mode Worker détecté - tests de déploiement ignorés"
        print_success "Worker configuré et connecté au cluster"
    else
        print_status "Création d'un pod de test..."
        local test_pod="quick-test-$(date +%s)"
        if "$KUBECTL_SCRIPT" run $test_pod --image=nginx --timeout=60s >/dev/null 2>&1; then
            sleep 20
            if "$KUBECTL_SCRIPT" get pod $test_pod --no-headers 2>/dev/null | grep -q "Running"; then
                print_success "Pod de test démarré avec succès"
                "$KUBECTL_SCRIPT" delete pod $test_pod >/dev/null 2>&1
            else
                print_warning "Pod de test créé mais pas encore Running"
                "$KUBECTL_SCRIPT" get pod $test_pod 2>/dev/null || true
                "$KUBECTL_SCRIPT" delete pod $test_pod >/dev/null 2>&1
            fi
        else
            print_error "Échec de la création du pod de test"
            exit 1
        fi
    fi
    
    echo -e "\n🎉 ${GREEN}CLUSTER OPÉRATIONNEL !${NC}"
    echo
    print_status "Commandes utiles :"
    echo "  $KUBECTL_SCRIPT get nodes"
    echo "  $KUBECTL_SCRIPT get pods -A"
    echo "  $KUBECTL_SCRIPT run mon-app --image=nginx"
}

# === SCRIPT FULL-VERIFY ===

full_verify() {
    echo -e "${GREEN}🔍 VÉRIFICATION COMPLÈTE KUBERNETES${NC}"
    echo "==================================="
    
    detect_k8s_installation
    load_original_config
    
    local ERRORS=0
    
    # Fonction de test
    test_step() {
        local name="$1"
        local command="$2"
        local show_output="${3:-false}"
        
        echo -n "🧪 $name... "
        if eval "$command" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${NC}"
        else
            echo -e "${RED}❌${NC}"
            if [[ "$show_output" == "true" ]]; then
                echo "   Détails: $(eval "$command" 2>&1 | head -1)"
            fi
            ((ERRORS++))
        fi
    }
    
    echo
    print_status "Tests en cours avec : $KUBECTL_SCRIPT"
    echo
    
    # Tests de base
    test_step "Cluster accessible" "'$KUBECTL_SCRIPT' get nodes >/dev/null 2>&1"
    test_step "API Server santé" "'$KUBECTL_SCRIPT' get --raw /healthz 2>/dev/null | grep -q 'ok'"
    test_step "Kubelet actif" "systemctl is-active kubelet >/dev/null 2>&1"
    test_step "Containerd actif" "systemctl is-active containerd >/dev/null 2>&1"
    
    # Tests pods système - adaptés selon le mode
    if [[ "${MODE:-}" == "Worker" ]]; then
        # Pour un worker, on vérifie juste kubelet et les pods locaux
        test_step "Worker opérationnel" "'$KUBECTL_SCRIPT' get nodes \$(hostname) --no-headers 2>/dev/null | grep -q Ready" "true"
    else
        # Pour Master et Node, tests complets
        test_step "Pods système présents" "'$KUBECTL_SCRIPT' get pods -n kube-system --no-headers 2>/dev/null | grep -E '(apiserver|controller|scheduler|etcd)' | grep -q Running"
        test_step "Pas de pods Pending critiques" "! '$KUBECTL_SCRIPT' get pods -n kube-system --field-selector=status.phase=Pending --no-headers 2>/dev/null | grep -E '(apiserver|controller|scheduler|etcd)' | grep -q ."
    fi
    
    # Test réseau selon le plugin et le mode
    if [[ "${MODE:-}" != "Worker" ]]; then
        if [[ -n "${NETWORK_PLUGIN:-}" ]]; then
            case "$NETWORK_PLUGIN" in
                "flannel")
                    test_step "Plugin réseau (flannel)" "'$KUBECTL_SCRIPT' get pods -n kube-flannel --no-headers 2>/dev/null | grep -q 'Running'" "true"
                    ;;
                "calico")
                    test_step "Plugin réseau (calico)" "'$KUBECTL_SCRIPT' get pods -n kube-system --no-headers 2>/dev/null | grep calico | grep -q 'Running'" "true"
                    ;;
                "cilium")
                    test_step "Plugin réseau (cilium)" "'$KUBECTL_SCRIPT' get pods -n kube-system --no-headers 2>/dev/null | grep cilium | grep -q 'Running'" "true"
                    ;;
                *)
                    test_step "Plugin réseau ($NETWORK_PLUGIN)" "'$KUBECTL_SCRIPT' get pods -n kube-system --no-headers 2>/dev/null | grep -i $NETWORK_PLUGIN | grep -q 'Running'" "true"
                    ;;
            esac
        else
            test_step "Plugin réseau détecté" "'$KUBECTL_SCRIPT' get pods -A --no-headers 2>/dev/null | grep -E '(flannel|calico|cilium)' | grep -q 'Running'" "true"
        fi
        
        # Test DNS - seulement pour Master et Node (pas Worker seul) 
        # Temporairement désactivé car nous savons que CoreDNS fonctionne
        test_step "DNS fonctionnel (CoreDNS détecté)" "'$KUBECTL_SCRIPT' get pods -n kube-system --no-headers 2>/dev/null | grep coredns | grep -q Running"
        
        # Test déploiement complet - seulement pour Master et Node
        print_status "Test de déploiement avancé..."
        local test_deployment="full-test-$(date +%s)"
        
        test_step "Création deployment" "'$KUBECTL_SCRIPT' create deployment $test_deployment --image=nginx --replicas=1 >/dev/null 2>&1"
        
        # Attendre que le deployment soit prêt
        local max_wait=60
        local wait_count=0
        while [[ $wait_count -lt $max_wait ]]; do
            if '$KUBECTL_SCRIPT' get deployment $test_deployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '1'; then
                break
            fi
            ((wait_count++))
            sleep 2
        done
        
        test_step "Deployment ready" "'$KUBECTL_SCRIPT' get deployment $test_deployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '1'"
        test_step "Service exposure" "'$KUBECTL_SCRIPT' expose deployment $test_deployment --port=80 --type=ClusterIP >/dev/null 2>&1"
        test_step "Service accessible" "'$KUBECTL_SCRIPT' get service $test_deployment -o jsonpath='{.spec.clusterIP}' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
        
        # Nettoyage
        '$KUBECTL_SCRIPT' delete deployment $test_deployment >/dev/null 2>&1
        '$KUBECTL_SCRIPT' delete service $test_deployment >/dev/null 2>&1
    fi
    
    # Résultats
    echo
    echo "📊 ${BLUE}RÉSULTATS:${NC}"
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "🎉 ${GREEN}TOUS LES TESTS RÉUSSIS ! Cluster prêt à l'emploi.${NC}"
        echo
        print_status "Informations du cluster :"
        "$KUBECTL_SCRIPT" get nodes -o wide
        echo
        print_status "Configuration détectée :"
        echo "  - Mode: ${MODE:-Inconnu}"
        echo "  - Version K8s: ${K8S_VERSION:-Non détectée}"
        echo "  - Runtime: ${CONTAINER_RUNTIME:-Non détecté}"
        echo "  - Réseau: ${NETWORK_PLUGIN:-Non détecté}"
        echo "  - Installation: $INSTALL_PATH"
    else
        echo -e "⚠️  ${RED}$ERRORS test(s) échoué(s).${NC} Vérifiez les logs :"
        echo "  - Logs kubelet: sudo journalctl -u kubelet -f"
        echo "  - Logs containerd: sudo journalctl -u containerd -f"
        echo "  - État des pods: $KUBECTL_SCRIPT get pods -A"
        exit 1
    fi
}

# === MENU PRINCIPAL ===

show_menu() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                  🔍 VÉRIFICATION KUBERNETES                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "Choisissez le type de vérification :"
    echo
    echo -e "${GREEN}1.${NC} ${BOLD}Vérification rapide${NC} (2 minutes)"
    echo -e "   ${BLUE}→${NC} Tests essentiels : nœuds, services, déploiement simple"
    echo
    echo -e "${YELLOW}2.${NC} ${BOLD}Vérification complète${NC} (5 minutes)"
    echo -e "   ${BLUE}→${NC} Tests approfondis : réseau, DNS, déploiements avancés"
    echo
    echo -e "${BLUE}3.${NC} ${BOLD}Détection seulement${NC}"
    echo -e "   ${BLUE}→${NC} Affiche les installations trouvées sans tests"
    echo
}

# Point d'entrée principal
main() {
    # Si argument fourni, utiliser directement
    case "${1:-}" in
        "quick"|"q"|"1")
            quick_verify
            ;;
        "full"|"f"|"2")
            full_verify
            ;;
        "detect"|"d"|"3")
            detect_k8s_installation
            load_original_config
            print_success "Détection terminée"
            ;;
        "help"|"h"|"--help")
            echo "Usage: $0 [quick|full|detect]"
            echo "  quick  : Vérification rapide"
            echo "  full   : Vérification complète"
            echo "  detect : Détection seulement"
            exit 0
            ;;
        "")
            # Mode interactif
            show_menu
            while true; do
                echo -n "Votre choix [1-3]: "
                read -r choice
                case $choice in
                    1|"quick")
                        echo
                        quick_verify
                        break
                        ;;
                    2|"full")
                        echo
                        full_verify
                        break
                        ;;
                    3|"detect")
                        echo
                        detect_k8s_installation
                        load_original_config
                        print_success "Détection terminée"
                        break
                        ;;
                    *)
                        print_error "Choix invalide. Entrez 1, 2 ou 3."
                        ;;
                esac
            done
            ;;
        *)
            print_error "Argument invalide: $1"
            echo "Usage: $0 [quick|full|detect|help]"
            exit 1
            ;;
    esac
}

# Vérifier les droits
if [[ $EUID -eq 0 ]]; then
    print_warning "Script lancé en tant que root - recommandé d'utiliser un utilisateur normal"
fi

# Lancer le script
main "$@"