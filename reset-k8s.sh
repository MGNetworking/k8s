#!/bin/bash

# Script de reset Kubernetes complet
# Usage: sudo ./reset-k8s.sh

set -e

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

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  RESET KUBERNETES COMPLET${NC}"
echo -e "${GREEN}================================${NC}"
echo

# Vérifier les droits root
if [[ $EUID -ne 0 ]]; then
    print_error "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

print_warning "ATTENTION: Ce script va supprimer complètement Kubernetes"
print_warning "Toutes les données du cluster seront perdues !"
echo
read -p "Voulez-vous continuer ? (oui/non): " confirm

if [[ "$confirm" != "oui" ]] && [[ "$confirm" != "o" ]] && [[ "$confirm" != "yes" ]] && [[ "$confirm" != "y" ]]; then
    print_error "Reset annulé"
    exit 1
fi

echo
print_status "Début du reset Kubernetes..."

# 1. Arrêter kubelet
print_status "Arrêt de kubelet..."
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

# 2. Nettoyer les conteneurs avec crictl
print_status "Nettoyage des conteneurs..."
crictl stopp $(crictl pods -q) 2>/dev/null || true
crictl rmp $(crictl pods -q) 2>/dev/null || true
crictl rm $(crictl ps -aq) 2>/dev/null || true
crictl rmi $(crictl images -q) 2>/dev/null || true

# 3. Nettoyer avec kubeadm si disponible
print_status "Reset kubeadm..."
kubeadm reset --force 2>/dev/null || print_warning "kubeadm reset échoué (normal si pas installé)"

# 4. Arrêter containerd temporairement
print_status "Arrêt temporaire de containerd..."
systemctl stop containerd 2>/dev/null || true

# 5. Nettoyer les répertoires Kubernetes
print_status "Suppression des répertoires Kubernetes..."
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/
rm -rf /var/lib/dockershim/
rm -rf /var/run/kubernetes/
rm -rf /var/lib/cni/
rm -rf /etc/cni/

# 6. Nettoyer les répertoires du script personnalisé
print_status "Suppression des répertoires personnalisés..."
rm -rf /opt/k8s*
rm -rf /var/lib/k8s*
rm -rf /etc/k8s*

# 7. Nettoyer les configurations utilisateur
print_status "Nettoyage des configurations utilisateur..."
rm -rf /root/.kube/
find /home -name ".kube" -type d -exec rm -rf {} + 2>/dev/null || true

# 8. Nettoyer les interfaces réseau Kubernetes
print_status "Nettoyage des interfaces réseau..."
ip link delete flannel.1 2>/dev/null || true
ip link delete cni0 2>/dev/null || true
ip link delete docker0 2>/dev/null || true

# 9. Nettoyer les règles iptables
print_status "Nettoyage des règles iptables..."
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true

# 10. Nettoyer les routes
print_status "Nettoyage des routes..."
ip route flush table main 2>/dev/null || true

# 11. Nettoyer les namespaces réseau
print_status "Nettoyage des namespaces réseau..."
for ns in $(ip netns list | awk '{print $1}' 2>/dev/null); do
    ip netns delete "$ns" 2>/dev/null || true
done

# 12. Nettoyer les logs
print_status "Nettoyage des logs..."
journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true

# 13. Nettoyer les packages si demandé
echo
read -p "Voulez-vous aussi d