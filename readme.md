# 🚀 Script d'installation Kubernetes interactif

Installation automatisée et configuration de clusters Kubernetes avec interface interactive. Supporte 3 modes d'installation : Node complet, Master seul, et Worker seul.

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Structure du projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Modes d'installation](#modes-dinstallation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Scripts utiles](#scripts-utiles)
- [Exemples d'usage](#exemples-dusage)
- [Fichiers générés](#fichiers-générés)
- [Vérification d'installation](#vérification-dinstallation)
- [Maintenance](#maintenance)
- [Reset et nettoyage](#reset-et-nettoyage)
- [Dépannage](#dépannage)

## 🎯 Vue d'ensemble

Ce script permet de déployer Kubernetes dans 3 configurations différentes selon vos besoins :

### 🏠 **Mode 1 : Node complet** (Master+Worker)

- **Usage** : Développement, tests, homelab, NAS
- **Avantages** : Simple, économique en ressources
- **Architecture** : Cluster single-node sur un seul serveur

### 🏢 **Mode 2 : Master seul** (Production)

- **Usage** : Production, staging avec HA
- **Avantages** : Haute disponibilité, scalabilité
- **Architecture** : Master dédié qui génère les infos pour workers

### ⚙️ **Mode 3 : Worker seul** (Production)

- **Usage** : Ajout de workers à un cluster existant
- **Avantages** : Expansion horizontale
- **Architecture** : Worker qui rejoint un master existant

## 📁 Structure du projet

```
k8s-installer/
├── install-k8s.sh                    # Script principal d'installation
├── reset-k8s.sh                      # Script de reset/nettoyage
├── README.md                         # Cette documentation
├── nodeConfig/                       # Configurations Mode 1
│   ├── dev-node.conf                # Dev/test single-node
│   ├── nas-node.conf                # NAS/homelab single-node
│   └── test-node.conf               # Tests temporaires
├── k8sConfig/                        # Configurations Mode 2&3
│   ├── prod-master.conf             # Master production
│   ├── prod-worker.conf             # Worker production
│   ├── staging-master.conf          # Master staging
│   ├── staging-worker.conf          # Worker staging
│   └── dev-master.conf              # Master développement
└── logs/ (généré automatiquement)
    ├── install-node-20250126-143022.log
    ├── install-master-20250126-144510.log
    ├── master-info-20250126-144510.txt
    └── install-worker-20250126-145032.log
```

## ⚙️ Prérequis

### Système

- **OS** : Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+
- **RAM** :
  - Node/Dev : 2GB minimum (4GB recommandé)
  - Production : 4GB minimum (8GB recommandé)
- **CPU** : 2 cores minimum
- **Disque** : 20GB+ (production), 10GB+ (dev/test)

### Réseau

- Connectivité internet pour téléchargements
- Ports requis ouverts :
  - `6443` : API Server Kubernetes
  - `2379-2380` : etcd
  - `10250` : kubelet
  - `10256` : kube-proxy

### Droits

- Accès **root** ou **sudo** sans mot de passe
- Utilisateur avec droits d'écriture dans le répertoire du script

## 🚀 Installation rapide

### 1. Télécharger les scripts

```bash
git clone <votre-repo>
cd k8s-installer
chmod +x install-k8s.sh reset-k8s.sh
```

### 2. Créer la structure des configurations

```bash
mkdir -p nodeConfig k8sConfig
```

### 3. Ajouter vos fichiers de configuration

Copiez les exemples fournis ou créez vos propres fichiers `.conf` dans les bons répertoires.

### 4. Lancer l'installation

```bash
sudo ./install-k8s.sh
```

Le script vous guidera interactivement ! 🎯

## 🎭 Modes d'installation

### Mode 1 : Node complet (Master+Worker)

```
┌─────────────────────────────┐
│         Serveur unique      │
│  ┌─────────┐ ┌─────────────┐│
│  │ Master  │ │   Worker    ││
│  │ (API)   │ │   (Pods)    ││
│  └─────────┘ └─────────────┘│
└─────────────────────────────┘
```

**Quand l'utiliser :**

- Développement et tests
- Homelab/NAS personnel
- Démonstrations
- Environnements avec ressources limitées

**Avantages :**

- Installation simple en une fois
- Économique en ressources
- Pas de configuration réseau complexe

### Mode 2 : Master seul (Production)

```
    ┌─────────────┐
    │   Master    │
    │   (API +    │
    │   Control   │
    │   Plane)    │
    └─────────────┘
           │
    Génère infos pour
       workers ↓
```

**Quand l'utiliser :**

- Production avec haute disponibilité
- Environnements staging
- Clusters multi-serveurs

**Avantages :**

- Haute disponibilité possible
- Séparation des responsabilités
- Scalabilité horizontale

### Mode 3 : Worker seul (Production)

```
┌─────────────┐      ┌─────────────┐
│   Master    │ ←──→ │   Worker    │
│  (existant) │      │   (Pods)    │
└─────────────┘      └─────────────┘
```

**Quand l'utiliser :**

- Ajouter de la capacité à un cluster existant
- Nœuds spécialisés (GPU, stockage, etc.)
- Expansion horizontale

**Avantages :**

- Ajout facile de ressources
- Spécialisation des nœuds
- Maintenance sans interruption

## 🔧 Configuration

### Variables communes

#### Obligatoires pour tous les modes

```bash
K8S_VERSION="1.28.0"              # Version Kubernetes
INSTALL_PATH="/opt/k8s"           # Répertoire d'installation
DATA_PATH="/var/lib/k8s"          # Données Kubernetes
CONFIG_PATH="/etc/k8s"            # Configurations
CONTAINER_RUNTIME="containerd"    # Runtime de conteneur
NETWORK_PLUGIN="flannel"          # Plugin réseau
```

#### Variables spécifiques Mode 1 (Node)

```bash
# Aucune variable spéciale requise
# Le script configure automatiquement Master+Worker
```

#### Variables spécifiques Mode 2 (Master)

```bash
# Haute disponibilité (optionnel)
HIGH_AVAILABILITY="true"
CONTROL_PLANE_ENDPOINT="k8s.domain.com:6443"

# Sécurité (production)
SECURITY_LEVEL="hardened"
ENABLE_AUDIT="true"
ENABLE_ENCRYPTION="true"
BACKUP_ETCD="true"
```

#### Variables spécifiques Mode 3 (Worker)

```bash
# Informations du master (OBLIGATOIRES)
MASTER_IP="192.168.1.100"
JOIN_TOKEN="abcdef.1234567890abcdef"
CA_CERT_HASH="sha256:abc123..."

# Ces valeurs sont générées par le master
# Consultez le fichier master-info-*.txt
```

### Plugins réseau disponibles

| Plugin      | Usage recommandé   | Avantages                   |
| ----------- | ------------------ | --------------------------- |
| **flannel** | Dev, test, homelab | Simple, léger, stable       |
| **calico**  | Production         | Sécurité, politiques réseau |
| **cilium**  | Production avancée | eBPF, haute performance     |

## 🎮 Utilisation

### Interface interactive

Le script vous guide étape par étape :

```bash
╔══════════════════════════════════════════════════════════════╗
║                    🚀 KUBERNETES INSTALLER                   ║
║                     Installation Automatisée                ║
╚══════════════════════════════════════════════════════════════╝

=== Installation Kubernetes ===

Choisissez votre mode d'installation :

1. Node complet (Master+Worker sur même serveur)
   → Cluster single-node, idéal pour dev/test/homelab

2. Master seul (génère infos pour workers)
   → Installation master avec HA, génère token pour workers

3. Worker seul (rejoint un master existant)
   → Rejoint un cluster existant avec les infos du master

Choisissez votre mode [1-3]: _
```

### Sélection de configuration

```bash
=== Fichiers de configuration disponibles ===

1. dev-node.conf
2. nas-node.conf

Choisissez votre configuration [1-2]: 1

→ Configuration sélectionnée : Node complet avec le fichier dev-node.conf
```

### Processus d'installation

Le script effectue automatiquement :

1. **Validation** de la configuration
2. **Vérification** des prérequis système
3. **Installation** des dépendances
4. **Configuration** du cluster
5. **Tests** de fonctionnement
6. **Génération** des fichiers utiles

## 🛠️ Scripts utiles

### Script d'installation principal

```bash
sudo ./install-k8s.sh
```

**Fonctionnalités :**

- ✅ Interface interactive
- ✅ Gestion d'erreurs robuste
- ✅ Retry automatique sur les échecs
- ✅ Diagnostic intégré
- ✅ Logs détaillés
- ✅ Génération de scripts kubectl personnalisés

### Script de reset/nettoyage

```bash
sudo ./reset-k8s.sh
```

**Fonctionnalités :**

- ✅ Nettoyage complet du cluster
- ✅ Suppression des configurations
- ✅ Nettoyage sélectif des règles iptables
- ✅ Préservation de la connectivité SSH
- ✅ Option de désinstallation des packages
- ✅ Réactivation optionnelle du swap

**⚠️ ATTENTION :** Le script de reset supprime **TOUTES** les données Kubernetes !

## 💡 Exemples d'usage

### Scénario 1 : Développement local

```bash
# 1. Créer la config
cat > nodeConfig/dev-local.conf << EOF
K8S_VERSION="1.28.0"
INSTALL_PATH="/opt/k8s-dev"
DATA_PATH="/var/lib/k8s-dev"
CONFIG_PATH="/etc/k8s-dev"
CONTAINER_RUNTIME="containerd"
NETWORK_PLUGIN="flannel"
EOF

# 2. Lancer l'installation
sudo ./install-k8s.sh
# Choisir: 1 (Node complet)
# Choisir: dev-local.conf

# 3. Utiliser le cluster (méthode 1)
/opt/k8s-dev/kubectl.sh get nodes

# 3. Ou utiliser le cluster (méthode 2 - standard)
/opt/k8s-dev/setup-kubectl.sh
kubectl get nodes
```

### Scénario 2 : Production avec HA

#### Étape 1 : Installer le premier master

```bash
# 1. Créer la config master
cat > k8sConfig/prod-master-01.conf << EOF
K8S_VERSION="1.28.0"
HIGH_AVAILABILITY="true"
CONTROL_PLANE_ENDPOINT="k8s-prod.domain.com:6443"
NETWORK_PLUGIN="calico"
ENABLE_AUDIT="true"
BACKUP_ETCD="true"
EOF

# 2. Installer
sudo ./install-k8s.sh
# Choisir: 2 (Master seul)
# Choisir: prod-master-01.conf

# 3. Récupérer les infos de jointure
cat master-info-*.txt
```

#### Étape 2 : Ajouter des workers

```bash
# 1. Créer la config worker avec les infos du master
cat > k8sConfig/prod-worker-01.conf << EOF
K8S_VERSION="1.28.0"
MASTER_IP="192.168.1.100"
JOIN_TOKEN="abcdef.1234567890abcdef"
CA_CERT_HASH="sha256:abc123..."
EOF

# 2. Installer sur chaque serveur worker
sudo ./install-k8s.sh
# Choisir: 3 (Worker seul)
# Choisir: prod-worker-01.conf
```

### Scénario 3 : Reset complet pour réinstallation

```bash
# 1. Reset complet et sécurisé
sudo ./reset-k8s.sh
# Répondre 'oui' pour confirmer
# Choisir si désinstaller les packages K8s

# 2. Réinstaller proprement
sudo ./install-k8s.sh
```

## 📄 Fichiers générés

### Scripts kubectl

```bash
/opt/k8s/kubectl.sh               # Script kubectl avec auto-diagnostic
/opt/k8s/setup-kubectl.sh         # Configuration kubectl standard
```

**Utilisation :**

```bash
# Méthode 1 : Script personnalisé (recommandé pour debug)
/opt/k8s/kubectl.sh get nodes
/opt/k8s/kubectl.sh get pods -A

# Méthode 2 : Configuration standard
/opt/k8s/setup-kubectl.sh
kubectl get nodes
kubectl get pods -A
```

### Logs d'installation

```bash
install-node-20250126-143022.log      # Log détaillé de l'installation
install-master-20250126-144510.log    # Log installation master
install-worker-20250126-145032.log    # Log installation worker
```

### Fichiers d'informations (Master)

```bash
master-info-20250126-144510.txt       # Infos condensées pour workers
```

Contenu exemple :

```bash
# Informations de jointure générées le 2025-01-26 14:45:10
MASTER_IP="192.168.1.100"
JOIN_TOKEN="abcdef.1234567890abcdef"
CA_CERT_HASH="sha256:abc123def456..."

# Commande de jointure complète pour worker :
# kubeadm join 192.168.1.100 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:abc123...
```

### Scripts de maintenance

```bash
/opt/k8s/join-worker.sh           # Script de jointure worker
/opt/k8s/join-master.sh           # Script de jointure master HA
/opt/k8s/backup-etcd.sh           # Script de backup etcd
```

### Fichiers de configuration

```bash
/opt/k8s/kubeconfig.yaml          # Configuration kubectl
```

## ✅ Vérification d'installation

### Commandes de vérification post-installation

#### Pour Mode 1 (Node complet) et Mode 2 (Master)

```bash
# === VÉRIFICATION CLUSTER ===

# 1. Vérifier l'état des nœuds
/opt/k8s/kubectl.sh get nodes
# Résultat attendu : STATUS = Ready

# 2. Vérifier les pods système
/opt/k8s/kubectl.sh get pods -A
# Résultat attendu : Tous les pods Running (sauf eventuellement quelques Pending au début)

# 3. Vérifier les services système
sudo systemctl status kubelet containerd
# Résultat attendu : active (running)

# 4. Test de déploiement simple
/opt/k8s/kubectl.sh run test-nginx --image=nginx
/opt/k8s/kubectl.sh get pods
# Résultat attendu : Pod test-nginx Running

# 5. Nettoyer le test
/opt/k8s/kubectl.sh delete pod test-nginx

# === VÉRIFICATION RÉSEAU ===

# 6. Vérifier le plugin réseau
/opt/k8s/kubectl.sh get pods -n kube-system | grep -E "(flannel|calico|cilium)"
# Résultat attendu : Pods réseau Running

# 7. Test connectivité entre pods (si cluster ready)
/opt/k8s/kubectl.sh run test1 --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
# Résultat attendu : Résolution DNS fonctionnelle

# === DIAGNOSTIC APPROFONDI ===

# 8. Informations détaillées du cluster
/opt/k8s/kubectl.sh cluster-info
/opt/k8s/kubectl.sh version

# 9. Vérifier les événements
/opt/k8s/kubectl.sh get events --sort-by=.metadata.creationTimestamp

# 10. Vérifier les ressources
/opt/k8s/kubectl.sh top nodes 2>/dev/null || echo "Metrics server non installé (normal)"
```

#### Pour Mode 3 (Worker)

```bash
# === VÉRIFICATION WORKER ===

# 1. Vérifier que le worker est visible depuis le master
# (à exécuter sur le master)
kubectl get nodes
# Résultat attendu : Nouveau worker visible avec STATUS = Ready

# 2. Vérifier les services sur le worker
sudo systemctl status kubelet containerd
# Résultat attendu : active (running)

# 3. Vérifier les pods sur le worker
# (depuis le master)
kubectl get pods -A -o wide --field-selector spec.nodeName=[WORKER-NAME]

# 4. Test de déploiement sur le worker
# (depuis le master)
kubectl run test-worker --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"[WORKER-NAME]"}}}'
kubectl get pods -o wide
# Résultat attendu : Pod déployé sur le worker spécifique
```

### Scripts de vérification automatique

#### Script de vérification complète (Mode 1 & 2)

```bash
cat > verify-cluster.sh << 'EOF'
#!/bin/bash
echo "=== VÉRIFICATION CLUSTER KUBERNETES ==="

echo "1. État des nœuds:"
/opt/k8s/kubectl.sh get nodes

echo -e "\n2. Pods système:"
/opt/k8s/kubectl.sh get pods -n kube-system

echo -e "\n3. Services système:"
systemctl is-active kubelet containerd

echo -e "\n4. Test déploiement:"
/opt/k8s/kubectl.sh run verify-test --image=nginx --timeout=60s
sleep 10
/opt/k8s/kubectl.sh get pod verify-test
/opt/k8s/kubectl.sh delete pod verify-test

echo -e "\n5. Informations cluster:"
/opt/k8s/kubectl.sh cluster-info

echo -e "\n=== VÉRIFICATION TERMINÉE ==="
EOF

chmod +x verify-cluster.sh
sudo ./verify-cluster.sh
```

#### Script de surveillance continue

```bash
cat > monitor-cluster.sh << 'EOF'
#!/bin/bash
echo "=== SURVEILLANCE CLUSTER (Ctrl+C pour arrêter) ==="

while true; do
    clear
    echo "=== $(date) ==="
    echo "Nœuds:"
    /opt/k8s/kubectl.sh get nodes

    echo -e "\nPods (non-système):"
    /opt/k8s/kubectl.sh get pods

    echo -e "\nServices:"
    /opt/k8s/kubectl.sh get services

    echo -e "\nÉvénements récents:"
    /opt/k8s/kubectl.sh get events --sort-by=.metadata.creationTimestamp | tail -5

    sleep 30
done
EOF

chmod +x monitor-cluster.sh
./monitor-cluster.sh
```

## 🔧 Maintenance

### Utilisation quotidienne

```bash
# Méthode 1 : Script personnalisé
/opt/k8s/kubectl.sh get nodes
/opt/k8s/kubectl.sh get pods --all-namespaces

# Méthode 2 : Kubectl standard (après setup)
/opt/k8s/setup-kubectl.sh
kubectl get nodes
kubectl get pods --all-namespaces

# Déployer une application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Voir les services
kubectl get services
```

### Ajouter un worker

```bash
# 1. Sur le master, récupérer les infos actuelles
kubeadm token create --print-join-command

# 2. Mettre à jour la config du nouveau worker
# 3. Installer le worker
sudo ./install-k8s.sh
# Choisir: 3 (Worker seul)
```

### Backup manuel (Master)

```bash
# Backup etcd
/opt/k8s/backup-etcd.sh

# Vérifier les backups
ls -la /opt/k8s/backups/
```

### Surveillance

```bash
# Status des services
systemctl status kubelet
systemctl status containerd

# Logs des services
journalctl -u kubelet -f
journalctl -u containerd -f

# Métriques du cluster
/opt/k8s/kubectl.sh top nodes 2>/dev/null
/opt/k8s/kubectl.sh top pods 2>/dev/null
```

## 🧹 Reset et nettoyage

### Reset complet avec le script sécurisé

```bash
# Lancer le script de reset
sudo ./reset-k8s.sh
```

**Le script effectue :**

- ✅ Arrêt des services Kubernetes
- ✅ Suppression des conteneurs et images
- ✅ Nettoyage des répertoires K8s
- ✅ Suppression des configurations utilisateur
- ✅ Nettoyage sélectif des interfaces réseau K8s
- ✅ Suppression sélective des règles iptables K8s
- ✅ Préservation de la connectivité SSH
- ✅ Option de désinstallation des packages
- ✅ Réactivation optionnelle du swap

### Reset manuel (si script non disponible)

```bash
# ⚠️ ATTENTION : Commandes manuelles - risque de coupure réseau

# Arrêter les services
sudo systemctl stop kubelet

# Reset kubeadm
sudo kubeadm reset -f

# Nettoyer les fichiers
sudo rm -rf /opt/k8s* /var/lib/k8s* /etc/k8s*
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
sudo rm -rf ~/.kube

# Nettoyer les interfaces K8s uniquement
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete cni0 2>/dev/null || true

# Redémarrer pour restaurer le réseau complètement
sudo reboot
```

### Après un reset

```bash
# 1. Vérifier que le système est propre
systemctl status kubelet 2>/dev/null || echo "Kubelet arrêté (normal)"
sudo find / -name "*kube*" -type d 2>/dev/null | grep -v proc | grep -v snap

# 2. Réinstaller
sudo ./install-k8s.sh
```

## 🐛 Dépannage

### Problèmes courants

#### Installation se bloque

```bash
# Vérifier les logs en temps réel
tail -f install-*.log

# Dans un autre terminal, surveiller les services
watch "systemctl is-active kubelet containerd"

# Si bloqué > 10 minutes, interrompre et voir les logs
Ctrl+C
tail -50 install-*.log
```

#### Cluster non disponible après installation

```bash
# Utiliser le script de diagnostic intégré
/opt/k8s/kubectl.sh get nodes
# Le script tentera une auto-réparation

# Ou vérifier manuellement
sudo systemctl status kubelet containerd
sudo systemctl restart kubelet

# Vérifier la configuration
ls -la /opt/k8s/
cat /opt/k8s/kubeconfig.yaml
```

#### Worker ne rejoint pas le cluster

```bash
# Sur le worker, vérifier la connectivité
ping [MASTER_IP]
telnet [MASTER_IP] 6443

# Vérifier le token (expire après 24h)
# Sur le master, générer un nouveau token :
kubeadm token create --print-join-command

# Mettre à jour la config du worker et réinstaller
sudo ./reset-k8s.sh
# Puis réinstaller avec les nouvelles infos
```

#### Pods en état Pending

```bash
# Vérifier les nœuds
/opt/k8s/kubectl.sh get nodes

# Vérifier les ressources
/opt/k8s/kubectl.sh describe nodes

# Pour un cluster single-node, vérifier le taint
/opt/k8s/kubectl.sh describe nodes | grep -i taint

# Si taint présent, le supprimer
/opt/k8s/kubectl.sh taint nodes --all node-role.kubernetes.io/control-plane-
```

#### Réseau non fonctionnel

```bash
# Vérifier le plugin réseau
/opt/k8s/kubectl.sh get pods -n kube-system | grep -E "(flannel|calico|cilium)"

# Redémarrer les pods réseau
/opt/k8s/kubectl.sh delete pods -n kube-system -l app=flannel

# Si problème persiste, réinstaller le plugin
/opt/k8s/kubectl.sh apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### Script reset a cassé le réseau

```bash
# Si connexion SSH coupée, accès physique au serveur :
sudo systemctl restart networking
sudo systemctl restart ssh
sudo dhclient -r && sudo dhclient

# Ou redémarrer le serveur pour restaurer la config réseau
sudo reboot
```

### Logs de diagnostic

```bash
# Logs d'installation
tail -f install-*.log

# Logs système détaillés
sudo journalctl -u kubelet --since "1 hour ago" --no-pager
sudo journalctl -u containerd --since "1 hour ago" --no-pager

# Logs des pods
/opt/k8s/kubectl.sh logs -n kube-system [pod-name]

# Événements du cluster
/opt/k8s/kubectl.sh get events --sort-by=.metadata.creationTimestamp
```

### Commandes de diagnostic système

```bash
# Processus K8s actifs
ps aux | grep -E "(kube|containerd)" | grep -v grep

# Ports en écoute
sudo netstat -tlnp | grep -E "(6443|2379|2380|10250)"

# Interfaces réseau
ip link show | grep -E "(flannel|cni)"

# Utilisation des ressources
free -h
df -h /var/lib/kubelet /opt/k8s
```

## 📞 Support et contribution

### Informations utiles pour le support

```bash
# Version du script
head -5 install-k8s.sh

# Configuration système
cat /etc/os-release
free -h
df -h

# Status Kubernetes
/opt/k8s/kubectl.sh version --short 2>/dev/null
/opt/k8s/kubectl.sh get nodes -o wide 2>/dev/null
```

### Logs à fournir en cas de problème

1. **Log d'installation** : `install-*.log`
2. **Configuration utilisée** : `[mode]-*.conf`
3. **Status système** : `systemctl status kubelet containerd`
4. **Informations cluster** : `/opt/k8s/kubectl.sh get nodes,pods --all-namespaces`
5. **Événements récents** : `/opt/k8s/kubectl.sh get events --sort-by=.metadata.creationTimestamp`

### Processus de contribution

```bash
# Avant de contribuer, tester sur un environnement propre
sudo ./reset-k8s.sh
sudo ./install-k8s.sh

# Vérifier que tout fonctionne
./verify-cluster.sh
```

---

## 🎉 Conclusion

Ce script vous permet de déployer Kubernetes facilement dans tous vos environnements :

- **🏠 Développement** : Installation rapide single-node avec reset facile
- **🏢 Production** : Clusters HA avec sécurité renforcée et backup automatique
- **⚙️ Expansion** : Ajout facile de workers avec gestion d'erreurs robuste
- **🧹 Maintenance** : Reset sécurisé sans casser votre connexion réseau

**Nouvelles fonctionnalités :**

- ✅ Script de reset sécurisé préservant SSH
- ✅ Gestion d'erreurs robuste avec retry automatique
- ✅ Deux méthodes d'utilisation kubectl (personnalisée + standard)
- ✅ Scripts de vérification automatique
- ✅ Diagnostic intégré et auto-réparation

**Bon déploiement Kubernetes !** 🚀

---

_Documentation mise à jour : Janvier 2025_
