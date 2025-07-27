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

# 9. Nettoyer SEULEMENT les règles iptables Kubernetes (SÉCURISÉ)
print_status "Nettoyage sélectif des règles iptables..."
# NE PAS faire de flush complet pour préserver SSH !

# Supprimer seulement les chaînes Kubernetes spécifiques
iptables -t nat -F KUBE-SERVICES 2>/dev/null || true
iptables -t nat -X KUBE-SERVICES 2>/dev/null || true
iptables -t nat -F KUBE-NODEPORTS 2>/dev/null || true
iptables -t nat -X KUBE-NODEPORTS 2>/dev/null || true
iptables -t nat -F KUBE-POSTROUTING 2>/dev/null || true
iptables -t nat -X KUBE-POSTROUTING 2>/dev/null || true

iptables -F KUBE-FORWARD 2>/dev/null || true
iptables -X KUBE-FORWARD 2>/dev/null || true

# 10. Nettoyer SEULEMENT les routes Kubernetes (SÉCURISÉ)
print_status "Nettoyage sélectif des routes..."
# Supprimer seulement les routes vers les subnets Kubernetes
ip route del 10.244.0.0/16 2>/dev/null || true
ip route del 10.96.0.0/16 2>/dev/null || true
# NE PAS faire de flush complet !

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
read -p "Voulez-vous aussi désinstaller les packages K8s ? (oui/non): " remove_packages

if [[ "$remove_packages" == "oui" ]] || [[ "$remove_packages" == "o" ]] || [[ "$remove_packages" == "yes" ]] || [[ "$remove_packages" == "y" ]]; then
    print_status "Désinstallation des packages Kubernetes..."
    
    # Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
        apt-get remove -y kubelet kubeadm kubectl 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
    fi
    
    # RHEL/CentOS
    if command -v yum &> /dev/null; then
        yum remove -y kubelet kubeadm kubectl 2>/dev/null || true
    fi
    
    print_success "Packages Kubernetes désinstallés"
fi

# 14. Redémarrer les services
print_status "Redémarrage des services..."
systemctl start containerd 2>/dev/null || true
systemctl enable containerd 2>/dev/null || true

# 15. Nettoyer les répertoires de logs spécifiques
print_status "Nettoyage final..."
rm -rf /var/log/kubernetes/ 2>/dev/null || true
rm -rf /var/log/pods/ 2>/dev/null || true

# 16. Remettre le swap (si il était activé)
print_status "Vérification du swap..."
if [[ -f /swapfile ]] || [[ -f /swap.img ]] || swapon --show | grep -q "/"; then
    read -p "Voulez-vous réactiver le swap ? (oui/non): " enable_swap
    if [[ "$enable_swap" == "oui" ]] || [[ "$enable_swap" == "o" ]]; then
        swapon -a 2>/dev/null || true
        print_success "Swap réactivé"
    fi
fi

echo
print_success "================================"
print_success "   RESET TERMINÉ AVEC SUCCÈS"
print_success "================================"
echo
print_status "Système nettoyé et prêt pour une nouvelle installation"
print_status "Vous pouvez maintenant relancer votre script d'installation"
echo
print_warning "REDÉMARRAGE RECOMMANDÉ pour s'assurer que tout est propre"
echo
read -p "Voulez-vous redémarrer maintenant ? (oui/non): " reboot_now

if [[ "$reboot_now" == "oui" ]] || [[ "$reboot_now" == "o" ]] || [[ "$reboot_now" == "yes" ]] || [[ "$reboot_now" == "y" ]]; then
    print_status "Redémarrage dans 5 secondes..."
    sleep 5
    reboot
else
    print_warning "N'oubliez pas de redémarrer manuellement !"
fi