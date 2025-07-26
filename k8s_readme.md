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
- [Exemples d'usage](#exemples-dusage)
- [Fichiers générés](#fichiers-générés)
- [Maintenance](#maintenance)
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
├── install-k8s.sh                    # Script principal
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

### 1. Télécharger le script
```bash
git clone <votre-repo>
cd k8s-installer
chmod +x install-k8s.sh
```

### 2. Créer la structure des configurations
```bash
mkdir -p nodeConfig k8sConfig
```

### 3. Ajouter vos fichiers de configuration
Copiez les exemples fournis ou créez vos propres fichiers `.conf` dans les bons répertoires.

### 4. Lancer l'installation
```bash
./install-k8s.sh
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

| Plugin | Usage recommandé | Avantages |
|--------|------------------|-----------|
| **flannel** | Dev, test, homelab | Simple, léger, stable |
| **calico** | Production | Sécurité, politiques réseau |
| **cilium** | Production avancée | eBPF, haute performance |

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
./install-k8s.sh
# Choisir: 1 (Node complet)
# Choisir: dev-local.conf

# 3. Utiliser le cluster
/opt/k8s-dev/kubectl.sh get nodes
/opt/k8s-dev/kubectl.sh run nginx --image=nginx
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
./install-k8s.sh
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
./install-k8s.sh
# Choisir: 3 (Worker seul)
# Choisir: prod-worker-01.conf
```

### Scénario 3 : NAS/Homelab

```bash
# 1. Sur votre VM dans le NAS
./install-k8s.sh
# Choisir: 1 (Node complet)
# Choisir: nas-node.conf

# 2. Déployer des services
/volume1/k8s/kubectl.sh apply -f your-app.yaml
```

## 📄 Fichiers générés

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

### Scripts utiles
```bash
/opt/k8s/kubectl.sh               # Script kubectl personnalisé
/opt/k8s/join-worker.sh           # Script de jointure worker
/opt/k8s/join-master.sh           # Script de jointure master HA
/opt/k8s/backup-etcd.sh           # Script de backup etcd
```

### Fichiers de configuration
```bash
/opt/k8s/kubeconfig.yaml          # Configuration kubectl
```

## 🔧 Maintenance

### Utilisation quotidienne

```bash
# Vérifier le cluster
/opt/k8s/kubectl.sh get nodes
/opt/k8s/kubectl.sh get pods --all-namespaces

# Déployer une application
/opt/k8s/kubectl.sh create deployment nginx --image=nginx
/opt/k8s/kubectl.sh expose deployment nginx --port=80 --type=NodePort

# Voir les services
/opt/k8s/kubectl.sh get services
```

### Ajouter un worker

```bash
# 1. Sur le master, récupérer les infos actuelles
kubeadm token create --print-join-command

# 2. Mettre à jour la config du nouveau worker
# 3. Installer le worker
./install-k8s.sh
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
/opt/k8s/kubectl.sh top nodes
/opt/k8s/kubectl.sh top pods
```

## 🐛 Dépannage

### Problèmes courants

#### Cluster non disponible
```bash
# Vérifier les services
systemctl status kubelet containerd

# Redémarrer si nécessaire
systemctl restart kubelet

# Vérifier la configuration
/opt/k8s/kubectl.sh get nodes
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
```

#### Pods en état Pending
```bash
# Vérifier les nœuds
/opt/k8s/kubectl.sh get nodes

# Vérifier les ressources
/opt/k8s/kubectl.sh describe nodes

# Pour un cluster single-node, vérifier le taint
/opt/k8s/kubectl.sh describe nodes | grep -i taint
```

#### Réseau non fonctionnel
```bash
# Vérifier le plugin réseau
/opt/k8s/kubectl.sh get pods -n kube-system | grep -E "(flannel|calico|cilium)"

# Redémarrer les pods réseau
/opt/k8s/kubectl.sh delete pods -n kube-system -l app=flannel
```

### Logs de diagnostic

```bash
# Logs d'installation
tail -f install-*.log

# Logs système
journalctl -u kubelet --since "1 hour ago"
journalctl -u containerd --since "1 hour ago"

# Logs des pods
/opt/k8s/kubectl.sh logs -n kube-system [pod-name]
```

### Reset complet

```bash
# ⚠️ ATTENTION : Supprime tout le cluster !

# Arrêter les services
systemctl stop kubelet

# Reset kubeadm
kubeadm reset -f

# Nettoyer les fichiers
rm -rf /opt/k8s /var/lib/k8s /etc/k8s
rm -rf /etc/kubernetes
rm -rf ~/.kube

# Nettoyer iptables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Réinstaller
./install-k8s.sh
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
/opt/k8s/kubectl.sh version
/opt/k8s/kubectl.sh get nodes -o wide
```

### Logs à fournir en cas de problème

1. **Log d'installation** : `install-*.log`
2. **Configuration utilisée** : `[mode]-*.conf`
3. **Status système** : `systemctl status kubelet containerd`
4. **Informations cluster** : `/opt/k8s/kubectl.sh get nodes,pods --all-namespaces`

---

## 🎉 Conclusion

Ce script vous permet de déployer Kubernetes facilement dans tous vos environnements :

- **🏠 Développement** : Installation rapide single-node
- **🏢 Production** : Clusters HA avec sécurité renforcée  
- **⚙️ Expansion** : Ajout facile de workers

**Bon déploiement Kubernetes !** 🚀

---

*Documentation mise à jour : Janvier 2025*