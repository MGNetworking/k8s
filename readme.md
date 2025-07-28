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
├── verify.sh                         # Script de vérification générique
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
chmod +x install-k8s.sh reset-k8s.sh verify.sh
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

### 5. Vérifier l'installation

```bash
./verify.sh
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

### Script de vérification générique

```bash
./verify.sh
```

**Fonctionnalités :**

- ✅ Détection automatique des installations K8s
- ✅ Support de multiples installations simultanées
- ✅ Récupération automatique de la configuration d'origine
- ✅ Vérification rapide (2 min) ou complète (5 min)
- ✅ Tests adaptés selon le mode d'installation
- ✅ Diagnostic intégré et auto-réparation
- ✅ Interface interactive ou utilisation en ligne de commande

**Modes d'utilisation :**

```bash
# Mode interactif (recommandé)
./verify.sh

# Vérification rapide directe
./verify.sh quick

# Vérification complète directe
./verify.sh full

# Détection des installations seulement
./verify.sh detect

# Aide
./verify.sh help
```

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

# 3. Vérifier l'installation
./verify.sh quick
# Ou vérification complète
./verify.sh full

# 4. Utiliser le cluster (méthode 1)
/opt/k8s-dev/kubectl.sh get nodes

# 4. Ou utiliser le cluster (méthode 2 - standard)
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

# 3. Vérifier l'installation master
./verify.sh full

# 4. Récupérer les infos de jointure
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

# 3. Vérifier depuis le master que le worker a rejoint
# (sur le master)
kubectl get nodes
```

### Scénario 3 : Reset complet pour réinstallation

```bash
# 1. Reset complet et sécurisé
sudo ./reset-k8s.sh
# Répondre 'oui' pour confirmer
# Choisir si désinstaller les packages K8s

# 2. Réinstaller proprement
sudo ./install-k8s.sh

# 3. Vérifier la nouvelle installation
./verify.sh
```

### Scénario 4 : Gestion de multiples installations

```bash
# Si vous avez plusieurs installations (dev, test, prod)
./verify.sh

# Le script détectera automatiquement:
# [INFO] Plusieurs installations détectées :
#   1. k8s-dev (/opt/k8s-dev)
#   2. k8s-test (/opt/k8s-test)
#   3. k8s-prod (/opt/k8s-prod)
#
# Choisissez l'installation à vérifier [1-3]: 2

# Ou vérifier une installation spécifique en mode direct
./verify.sh full  # Suivre le menu pour choisir
```

## 📄 Fichiers générés

### Scripts kubectl

```bash
/opt/k8s*/kubectl.sh               # Script kubectl avec auto-diagnostic
/opt/k8s*/setup-kubectl.sh         # Configuration kubectl standard
```

**Utilisation :**

```bash
# Méthode 1 : Script personnalisé (recommandé pour debug)
/opt/k8s-dev/kubectl.sh get nodes
/opt/k8s-dev/kubectl.sh get pods -A

# Méthode 2 : Configuration standard
/opt/k8s-dev/setup-kubectl.sh
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
/opt/k8s*/join-worker.sh           # Script de jointure worker
/opt/k8s*/join-master.sh           # Script de jointure master HA
/opt/k8s*/backup-etcd.sh           # Script de backup etcd
```

### Fichiers de configuration

```bash
/opt/k8s*/kubeconfig.yaml          # Configuration kubectl
```

## ✅ Vérification d'installation

### Script de vérification générique - verify.sh

Le script `verify.sh` est l'outil principal pour vérifier vos installations Kubernetes. Il s'adapte automatiquement à votre configuration et détecte tous vos clusters installés.

#### Interface interactive

```bash
./verify.sh
```

```bash
╔══════════════════════════════════════════════════════════════╗
║                  🔍 VÉRIFICATION KUBERNETES                  ║
╚══════════════════════════════════════════════════════════════╝

Choisissez le type de vérification :

1. Vérification rapide (2 minutes)
   → Tests essentiels : nœuds, services, déploiement simple

2. Vérification complète (5 minutes)
   → Tests approfondis : réseau, DNS, déploiements avancés

3. Détection seulement
   → Affiche les installations trouvées sans tests

Votre choix [1-3]: _
```

#### Utilisation en ligne de commande

```bash
# Vérification rapide (2 minutes)
./verify.sh quick

# Vérification complète (5 minutes)
./verify.sh full

# Détection des installations seulement
./verify.sh detect

# Aide
./verify.sh help
```

#### Détection automatique

Le script détecte automatiquement :

- **Toutes les installations** dans `/opt/k8s*`
- **Les fichiers requis** (`kubectl.sh`, `kubeconfig.yaml`)
- **La configuration d'origine** via les logs d'installation
- **Le mode d'installation** (Node/Master/Worker)
- **Les variables de configuration** (version K8s, plugin réseau, etc.)

#### Exemple de vérification rapide

```bash
$ ./verify.sh quick

🔍 VÉRIFICATION RAPIDE KUBERNETES
=================================

[INFO] Recherche des installations Kubernetes...
[SUCCESS] Installation détectée : /opt/k8s-dev
[SUCCESS] Configuration trouvée : Node avec dev-node.conf
[SUCCESS] Variables chargées depuis ./nodeConfig/dev-node.conf
[INFO]   - K8S_VERSION: 1.28.0
[INFO]   - NETWORK_PLUGIN: flannel
[INFO]   - CONTAINER_RUNTIME: containerd

[INFO] Utilisation de : /opt/k8s-dev/kubectl.sh

1️⃣ Nœuds du cluster:
NAME   STATUS   ROLES           AGE   VERSION
k8s    Ready    control-plane   45m   v1.28.0
[SUCCESS] Cluster accessible

2️⃣ Services système:
[SUCCESS] Services kubelet et containerd actifs

3️⃣ Test déploiement:
[INFO] Création d'un pod de test...
[SUCCESS] Pod de test démarré avec succès

🎉 CLUSTER OPÉRATIONNEL !

[INFO] Commandes utiles :
  /opt/k8s-dev/kubectl.sh get nodes
  /opt/k8s-dev/kubectl.sh get pods -A
  /opt/k8s-dev/kubectl.sh run mon-app --image=nginx
```

#### Exemple de vérification complète

```bash
$ ./verify.sh full

🔍 VÉRIFICATION COMPLÈTE KUBERNETES
===================================

[INFO] Tests en cours avec : /opt/k8s-dev/kubectl.sh

🧪 Cluster accessible... ✅
🧪 API Server santé... ✅
🧪 Kubelet actif... ✅
🧪 Containerd actif... ✅
🧪 Pods système présents... ✅
🧪 Pas de pods Pending... ✅
🧪 Plugin réseau (flannel)... ✅
🧪 DNS fonctionnel... ✅
🧪 Création deployment... ✅
🧪 Deployment ready... ✅
🧪 Service exposure... ✅
🧪 Service accessible... ✅

📊 RÉSULTATS:
🎉 TOUS LES TESTS RÉUSSIS ! Cluster prêt à l'emploi.

[INFO] Informations du cluster :
NAME   STATUS   ROLES           AGE   VERSION   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s    Ready    control-plane   47m   v1.28.0   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.6.12

[INFO] Configuration détectée :
  - Mode: Node
  - Version K8s: 1.28.0
  - Runtime: containerd
  - Réseau: flannel
  - Installation: /opt/k8s-dev
```

### Vérifications manuelles complémentaires

#### Pour Mode 1 (Node complet) et Mode 2 (Master)

```bash
# État détaillé des nœuds
[KUBECTL_SCRIPT] describe nodes

# Vérifier tous les pods système
[KUBECTL_SCRIPT] get pods -A -o wide

# Vérifier les événements récents
[KUBECTL_SCRIPT] get events --sort-by=.metadata.creationTimestamp | tail -10

# Test de connectivité réseau avancé
[KUBECTL_SCRIPT] run netshoot --rm -it --image=nicolaka/netshoot -- ping kubernetes.default
```

#### Pour Mode 3 (Worker)

```bash
# Depuis le master, vérifier le worker
kubectl get nodes -o wide
kubectl describe node [WORKER-NAME]

# Vérifier les pods déployés sur le worker
kubectl get pods -A -o wide --field-selector spec.nodeName=[WORKER-NAME]
```

### Indicateurs de santé

#### ✅ Cluster sain

- Tous les nœuds avec STATUS "Ready"
- Pods système en état "Running"
- Services kubelet/containerd "active"
- Tests de déploiement réussis
- DNS fonctionnel

#### ⚠️ Problèmes détectés

- Nœuds "NotReady"
- Pods système "Pending" ou "CrashLoopBackOff"
- Échec des tests de déploiement
- Services inactifs

## 🔧 Maintenance

### Utilisation quotidienne

```bash
# Vérification rapide de l'état
./verify.sh quick

# État détaillé du cluster
[KUBECTL_SCRIPT] get nodes,pods,services -A

# Déployer une application
[KUBECTL_SCRIPT] create deployment nginx --image=nginx
[KUBECTL_SCRIPT] expose deployment nginx --port=80 --type=NodePort

# Voir les services
[KUBECTL_SCRIPT] get services
```

### Surveillance continue

```bash
# Créer un script de monitoring
cat > monitor-k8s.sh << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "=== $(date) ==="
    ./verify.sh quick
    echo -e "\nProchaine vérification dans 5 minutes..."
    sleep 300
done
EOF

chmod +x monitor-k8s.sh
./monitor-k8s.sh
```

### Ajouter un worker

```bash
# 1. Sur le master, récupérer les infos actuelles
kubeadm token create --print-join-command

# 2. Mettre à jour la config du nouveau worker
# 3. Installer le worker
sudo ./install-k8s.sh
# Choisir: 3 (Worker seul)

# 4. Vérifier depuis le master
kubectl get nodes
```

### Backup manuel (Master)

```bash
# Backup etcd
[INSTALL_PATH]/backup-etcd.sh

# Vérifier les backups
ls -la [INSTALL_PATH]/backups/
```

### Surveillance des logs

```bash
# Logs des services
journalctl -u kubelet -f
journalctl -u containerd -f

# Logs des pods
[KUBECTL_SCRIPT] logs -n kube-system [pod-name] -f
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

### Workflow complet : Reset → Réinstall → Vérify

```bash
# 1. Reset complet
sudo ./reset-k8s.sh

# 2. Réinstallation
sudo ./install-k8s.sh

# 3. Vérification de la nouvelle installation
./verify.sh full

# 4. Si problème détecté, diagnostic
./verify.sh detect  # Voir les installations trouvées
tail -f install-*.log  # Voir les logs d'installation
```

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

# 3. Vérifier la nouvelle installation
./verify.sh
```

## 🐛 Dépannage

### Diagnostic avec verify.sh

Le script `verify.sh` est votre premier outil de diagnostic :

```bash
# Diagnostic rapide
./verify.sh quick

# Si problème détecté, diagnostic complet
./verify.sh full

# Voir toutes les installations
./verify.sh detect
```

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
# Utiliser verify.sh pour diagnostic
./verify.sh full

# Le script affichera les erreurs spécifiques et proposera des solutions
# Exemple de sortie d'erreur:
# 🧪 Cluster accessible... ❌
# 🧪 Kubelet actif... ❌
#   Détails: inactive

# Puis corriger selon les indications
sudo systemctl restart kubelet
./verify.sh quick  # Re-tester
```

#### Worker ne rejoint pas le cluster

```bash
# Sur le worker, vérifier la connectivité
ping [MASTER_IP]
telnet [MASTER_IP] 6443

# Utiliser verify.sh sur le worker pour voir le problème
./verify.sh detect  # Voir si l'installation est détectée

# Vérifier le token (expire après 24h)
# Sur le master, générer un nouveau token :
kubeadm token create --print-join-command

# Mettre à jour la config du worker et réinstaller
sudo ./reset-k8s.sh
# Puis réinstaller avec les nouvelles infos
```

#### Pods en état Pending

```bash
# Diagnostic avec verify.sh
./verify.sh full
# Rechercher la ligne: 🧪 Pas de pods Pending... ❌

# Diagnostic manuel
[KUBECTL_SCRIPT] get nodes
[KUBECTL_SCRIPT] describe nodes

# Pour un cluster single-node, vérifier le taint
[KUBECTL_SCRIPT] describe nodes | grep -i taint

# Si taint présent, le supprimer
[KUBECTL_SCRIPT] taint nodes --all node-role.kubernetes.io/control-plane-
```

#### Réseau non fonctionnel

```bash
# verify.sh détectera automatiquement les problèmes réseau
./verify.sh full
# Rechercher les lignes:
# 🧪 Plugin réseau (flannel)... ❌
# 🧪 DNS fonctionnel... ❌

# Diagnostic manuel du réseau
[KUBECTL_SCRIPT] get pods -n kube-system | grep -E "(flannel|calico|cilium)"

# Redémarrer les pods réseau
[KUBECTL_SCRIPT] delete pods -n kube-system -l app=flannel

# Si problème persiste, réinstaller le plugin
[KUBECTL_SCRIPT] apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Re-tester
./verify.sh quick
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

#### Multiple installations détectées

```bash
# verify.sh gère automatiquement les installations multiples
./verify.sh

# Si confusion entre les installations
./verify.sh detect  # Voir toutes les installations
ls -la /opt/k8s*    # Vérifier physiquement

# Nettoyer les installations inutiles
sudo rm -rf /opt/k8s-old
sudo ./reset-k8s.sh  # Pour un nettoyage complet
```

### Logs de diagnostic

```bash
# Logs d'installation
tail -f install-*.log

# Logs système détaillés
sudo journalctl -u kubelet --since "1 hour ago" --no-pager
sudo journalctl -u containerd --since "1 hour ago" --no-pager

# Logs des pods
[KUBECTL_SCRIPT] logs -n kube-system [pod-name]

# Événements du cluster
[KUBECTL_SCRIPT] get events --sort-by=.metadata.creationTimestamp
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
df -h /var/lib/kubelet /opt/k8s*
```

### Workflow de dépannage recommandé

```bash
# 1. Diagnostic initial avec verify.sh
./verify.sh full

# 2. Si échecs détectés, voir les détails
./verify.sh detect  # Vérifier les installations
tail -20 install-*.log  # Voir les logs récents

# 3. Corriger les problèmes identifiés
sudo systemctl restart kubelet containerd
[KUBECTL_SCRIPT] get pods -A  # Vérifier l'état

# 4. Re-tester
./verify.sh quick

# 5. Si problème persiste, reset complet
sudo ./reset-k8s.sh
sudo ./install-k8s.sh
./verify.sh full
```

## 📞 Support et contribution

### Informations utiles pour le support

```bash
# Version des scripts
head -5 install-k8s.sh
head -5 verify.sh

# Configuration système
cat /etc/os-release
free -h
df -h

# Status Kubernetes avec verify.sh
./verify.sh detect
./verify.sh full > cluster-diagnostic.txt
```

### Logs à fournir en cas de problème

1. **Sortie de verify.sh** : `./verify.sh full > diagnostic.txt`
2. **Log d'installation** : `install-*.log`
3. **Configuration utilisée** : `[mode]-*.conf`
4. **Status système** : `systemctl status kubelet containerd`
5. **Informations cluster** : Output de verify.sh
6. **Événements récents** : `[KUBECTL_SCRIPT] get events --sort-by=.metadata.creationTimestamp`

### Processus de contribution

```bash
# Avant de contribuer, tester le workflow complet
sudo ./reset-k8s.sh
sudo ./install-k8s.sh
./verify.sh full

# Vérifier que tous les scripts fonctionnent
./verify.sh quick
./verify.sh detect
./verify.sh help
```

### Template de rapport de bug

```bash
# Générer un rapport complet automatiquement
cat > bug-report.sh << 'EOF'
#!/bin/bash
echo "=== BUG REPORT KUBERNETES INSTALLER ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo

echo "=== SYSTEM INFO ==="
cat /etc/os-release
echo "RAM: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo

echo "=== VERIFY.SH OUTPUT ==="
./verify.sh detect
echo
./verify.sh full

echo -e "\n=== RECENT LOGS ==="
tail -20 install-*.log 2>/dev/null || echo "No install logs found"

echo -e "\n=== SYSTEM SERVICES ==="
systemctl status kubelet containerd --no-pager

echo -e "\n=== NETWORK INTERFACES ==="
ip link show | grep -E "(flannel|cni|docker)" || echo "No k8s network interfaces"
EOF

chmod +x bug-report.sh
./bug-report.sh > my-bug-report.txt
```

## 📚 Guide de référence rapide

### Commandes essentielles

```bash
# Installation
sudo ./install-k8s.sh

# Vérification rapide
./verify.sh quick

# Vérification complète
./verify.sh full

# Reset complet
sudo ./reset-k8s.sh

# Utilisation du cluster (adapté automatiquement)
[KUBECTL_SCRIPT] get nodes
[KUBECTL_SCRIPT] get pods -A
[KUBECTL_SCRIPT] run test --image=nginx
```

### Résolution de problèmes rapide

| Problème                 | Solution rapide                                                             |
| ------------------------ | --------------------------------------------------------------------------- |
| Cluster non accessible   | `./verify.sh full` puis suivre les indications                              |
| Pods Pending             | `[KUBECTL_SCRIPT] taint nodes --all node-role.kubernetes.io/control-plane-` |
| Réseau ne fonctionne pas | `[KUBECTL_SCRIPT] delete pods -n kube-system -l app=flannel`                |
| Services inactifs        | `sudo systemctl restart kubelet containerd`                                 |
| Installation multiple    | `./verify.sh detect` puis choisir                                           |
| Reset cassé le réseau    | `sudo reboot` (accès physique requis)                                       |

### Fichiers importants par installation

```bash
# Scripts générés automatiquement
/opt/k8s*/kubectl.sh               # Script kubectl personnalisé
/opt/k8s*/setup-kubectl.sh         # Configuration kubectl standard
/opt/k8s*/kubeconfig.yaml          # Configuration cluster

# Logs et infos
install-*.log                      # Logs d'installation
master-info-*.txt                  # Infos de jointure (master)

# Maintenance
/opt/k8s*/backup-etcd.sh          # Backup etcd (si activé)
/opt/k8s*/join-worker.sh          # Script jointure worker
```

### Ports et services clés

| Service    | Port      | Description              |
| ---------- | --------- | ------------------------ |
| API Server | 6443      | Interface principale K8s |
| etcd       | 2379-2380 | Base de données cluster  |
| kubelet    | 10250     | Agent sur chaque nœud    |
| kube-proxy | 10256     | Proxy réseau             |

---

## 🎉 Conclusion

Ce script vous permet de déployer Kubernetes facilement dans tous vos environnements :

- **🏠 Développement** : Installation rapide single-node avec reset facile
- **🏢 Production** : Clusters HA avec sécurité renforcée et backup automatique
- **⚙️ Expansion** : Ajout facile de workers avec gestion d'erreurs robuste
- **🧹 Maintenance** : Reset sécurisé sans casser votre connexion réseau
- **🔍 Vérification** : Script générique qui s'adapte à toutes vos installations

**Nouvelles fonctionnalités :**

- ✅ Script de reset sécurisé préservant SSH
- ✅ Gestion d'erreurs robuste avec retry automatique
- ✅ Deux méthodes d'utilisation kubectl (personnalisée + standard)
- ✅ **Script de vérification générique verify.sh**
- ✅ **Détection automatique des installations multiples**
- ✅ **Récupération automatique de la configuration d'origine**
- ✅ Diagnostic intégré et auto-réparation
- ✅ **Interface interactive et utilisation en ligne de commande**

**Workflow recommandé :**

1. **Installation** : `sudo ./install-k8s.sh`
2. **Vérification** : `./verify.sh`
3. **Utilisation** : Scripts kubectl générés automatiquement
4. **Maintenance** : `./verify.sh quick` régulièrement
5. **Reset si besoin** : `sudo ./reset-k8s.sh`

**Le script verify.sh est votre outil principal** pour :

- ✅ Vérifier l'état de vos clusters
- ✅ Diagnostiquer les problèmes
- ✅ Gérer plusieurs installations
- ✅ Adapter automatiquement les tests à votre configuration

**Bon déploiement Kubernetes !** 🚀
