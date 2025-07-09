# Guide d'installation Kubernetes

## Script d'installation modulaire et sélectif

### Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Architectures supportées](#architectures-supportées)
4. [Modes d'installation](#modes-dinstallation)
5. [Composants disponibles](#composants-disponibles)
6. [Scénarios d'installation](#scénarios-dinstallation)
7. [Commandes de test](#commandes-de-test)
8. [Ajout de workers](#ajout-de-workers)
9. [Résolution de problèmes](#résolution-de-problèmes)
10. [Maintenance et mise à jour](#maintenance-et-mise-à-jour)

---

## Vue d'ensemble

Ce script d'installation `k8s_setup.sh` Kubernetes offre une approche modulaire et flexible pour déployer des clusters Kubernetes sur différentes architectures. Il supporte les installations automatisées et interactives avec une gestion complète des composants.

### Caractéristiques principales

- **Installation modulaire** : Choix sélectif des composants
- **Architectures multiples** : Single-node, multi-node, multi-master
- **Modes flexibles** : Control-plane, worker, components
- **Configuration persistante** : Sauvegarde automatique des paramètres
- **Logging complet** : Traçabilité de toutes les opérations
- **Mode dry-run** : Test sans installation

---

## Prérequis

### Système requis

- **OS** : Ubuntu 20.04+ / Debian 11+
- **RAM** : 2GB minimum (4GB recommandé)
- **CPU** : 2 vCPU minimum
- **Stockage** : 20GB minimum
- **Réseau** : Connexion internet stable

### Privilèges et ports

- **Sudo** : Exécution avec privilèges root
- **Ports control-plane** : 6443, 10250, 10257, 2379, 2380
- **Ports worker** : 10250, 30000-32767

### Vérification des prérequis

```bash
# Vérification des ressources
free -h
nproc
df -h

# Vérification des ports
sudo netstat -tulnp | grep -E ':(6443|10250|10257|2379|2380)'
```

---

## Architectures supportées

### 1. Single-node

**Description** : Un seul serveur faisant office de control-plane et worker
**Utilisation** : Développement, test, démonstration
**Avantages** : Simple, économique
**Inconvénients** : Pas de haute disponibilité

### 2. Multi-node

**Description** : Control-plane dédié + workers séparés
**Utilisation** : Production, environnements moyens
**Avantages** : Séparation des rôles, évolutif
**Inconvénients** : Plus complexe

### 3. Multi-master

**Description** : Plusieurs control-planes (HA)
**Utilisation** : Production critique, haute disponibilité
**Avantages** : Résilience maximale
**Inconvénients** : Complexité élevée

---

## Modes d'installation

### 1. Control-plane

Installation complète du nœud maître

- Base system + containerd
- Kubernetes tools
- Cluster initialization
- CNI + Ingress

### 2. Worker

Installation pour rejoindre un cluster existant

- Base system + containerd
- Kubernetes tools
- Join cluster configuration

### 3. Single-node

Installation complète sur un seul nœud

- Tous les composants
- Suppression des taints
- Configuration DNS locale

### 4. Components

Installation sélective par composants

- Choix manuel des éléments
- Installation granulaire
- Maximum de flexibilité

---

## Composants disponibles

| Composant      | Description                   | Requis pour   |
| -------------- | ----------------------------- | ------------- |
| `base`         | Système de base + dépendances | Tous          |
| `containerd`   | Runtime de conteneurs         | Tous          |
| `kubernetes`   | kubeadm, kubelet, kubectl     | Tous          |
| `network`      | Configuration réseau kernel   | Tous          |
| `cluster-init` | Initialisation cluster        | Control-plane |
| `cluster-join` | Rejoindre cluster             | Worker        |
| `cni`          | Plugin réseau Calico          | Control-plane |
| `ingress`      | Contrôleur Ingress NGINX      | Control-plane |
| `dns`          | Configuration DNS locale      | Single-node   |

---

## Scénarios d'installation

### Scénario 1 : Cluster single-node pour développement

**Objectif** : Environnement de développement complet sur une seule machine

```bash
# Installation complète automatique
sudo ./kubernetes_install.sh --architecture=single-node --mode=single-node

# Ou installation interactive
sudo ./kubernetes_install.sh --interactive
```

**Résultat attendu** :

- Cluster fonctionnel avec control-plane + worker
- Plugin réseau Calico installé
- Contrôleur Ingress configuré
- DNS local configuré

### Scénario 2 : Cluster multi-node production

**Étape 1 : Installation du control-plane**

```bash
# Sur le serveur maître
sudo ./kubernetes_install.sh --architecture=multi-node --mode=control-plane
```

**Étape 2 : Installation des workers**

```bash
# Récupération du token sur le control-plane
sudo kubeadm token create --print-join-command

# Sur chaque worker
sudo ./kubernetes_install.sh --mode=worker \
  --join-token=<token> \
  --endpoint=<control-plane-ip>:6443
```

### Scénario 3 : Installation personnalisée

**Objectif** : Installation granulaire avec composants spécifiques

```bash
# Installation de base seulement
sudo ./kubernetes_install.sh --mode=components \
  --components=base,containerd,kubernetes

# Ajout ultérieur du réseau
sudo ./kubernetes_install.sh --mode=components \
  --components=network,cluster-init,cni
```

### Scénario 4 : Migration et mise à jour

**Test avant installation** :

```bash
# Vérification de la configuration
sudo ./kubernetes_install.sh --architecture=single-node \
  --mode=single-node --dry-run
```

**Réinstallation forcée** :

```bash
sudo ./kubernetes_install.sh --architecture=single-node \
  --mode=single-node --force
```

---

## Commandes de test

### Vérification post-installation

#### 1. État du cluster

```bash
# Vérification des nœuds
kubectl get nodes -o wide

# Vérification des pods système
kubectl get pods -n kube-system

# Vérification des services
kubectl get svc -A
```

#### 2. Test des composants réseau

```bash
# Test de connectivité réseau
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
kubectl exec test-pod -- nslookup kubernetes.default.svc.cluster.local

# Nettoyage
kubectl delete pod test-pod
```

#### 3. Test du contrôleur Ingress

```bash
# Vérification du contrôleur Ingress
kubectl get pods -n ingress-nginx

# Test avec une application exemple
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --port=80
```

#### 4. Test de déploiement complet

```bash
# Déploiement d'une application de test
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
spec:
  selector:
    app: test-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Vérification du déploiement
kubectl get deployment,pods,svc
kubectl describe deployment test-app
```

### Tests de performances

#### 1. Test de charge basique

```bash
# Installation d'outils de test
kubectl run load-test --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://test-app-service; done"

# Surveillance des métriques
kubectl top nodes
kubectl top pods
```

#### 2. Test de montée en charge

```bash
# Augmentation du nombre de replicas
kubectl scale deployment test-app --replicas=5

# Vérification de la distribution
kubectl get pods -o wide
```

---

## Ajout de workers

### Processus standard

#### 1. Préparation du control-plane

```bash
# Sur le control-plane, génération du token
sudo kubeadm token create --print-join-command

# Exemple de sortie :
# kubeadm join 192.168.1.100:6443 --token abc123.xyz789 --discovery-token-ca-cert-hash sha256:...
```

#### 2. Installation du worker

```bash
# Sur le nouveau worker
sudo ./kubernetes_install.sh --mode=worker \
  --join-token=abc123.xyz789 \
  --endpoint=192.168.1.100:6443
```

#### 3. Vérification de l'ajout

```bash
# Sur le control-plane
kubectl get nodes
kubectl describe node <nouveau-worker>
```

### Ajout de workers avec étiquetage

```bash
# Après l'ajout, étiquetage du worker
kubectl label node <worker-name> node-role.kubernetes.io/worker=worker

# Ajout d'étiquettes personnalisées
kubectl label node <worker-name> environment=production
kubectl label node <worker-name> workload=compute-intensive
```

### Gestion des taints et tolerations

```bash
# Ajout de taints pour spécialiser les workers
kubectl taint nodes <worker-name> workload=database:NoSchedule

# Vérification des taints
kubectl describe node <worker-name> | grep -i taint
```

---

## Résolution de problèmes

### Problèmes courants

#### 1. Échec de l'initialisation du cluster

```bash
# Vérification des logs
sudo journalctl -u kubelet -f

# Reset du cluster
sudo kubeadm reset -f
sudo rm -rf ~/.kube/config
```

#### 2. Problèmes de réseau

```bash
# Vérification des modules kernel
lsmod | grep br_netfilter

# Rechargement de la configuration réseau
sudo sysctl --system
```

#### 3. Pods en erreur

```bash
# Diagnostic des pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Vérification des events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Logs et diagnostic

#### 1. Logs du script d'installation

```bash
# Consultation des logs
tail -f kubernetes_setup.log

# Recherche d'erreurs
grep -i error kubernetes_setup.log
```

#### 2. Logs des composants Kubernetes

```bash
# Logs du kubelet
sudo journalctl -u kubelet -n 50

# Logs du containerd
sudo journalctl -u containerd -n 50
```

---

## Maintenance et mise à jour

### Sauvegarde de la configuration

```bash
# Sauvegarde des certificats
sudo cp -r /etc/kubernetes /backup/kubernetes-$(date +%Y%m%d)

# Sauvegarde de la configuration kubectl
cp ~/.kube/config ~/.kube/config.backup
```

### Mise à jour du cluster

```bash
# Vérification des versions disponibles
apt list --upgradable | grep -E '(kubeadm|kubelet|kubectl)'

# Mise à jour planifiée
sudo apt update
sudo apt upgrade kubeadm

# Mise à jour du control-plane
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.28.x
```

### Nettoyage et maintenance

```bash
# Nettoyage des images inutilisées
sudo crictl rmi --prune

# Nettoyage des logs
sudo journalctl --vacuum-time=7d

# Vérification de l'espace disque
df -h
du -sh /var/lib/containerd/
```

### Surveillance continue

```bash
# Script de surveillance basique
cat << 'EOF' > monitor_cluster.sh
#!/bin/bash
echo "=== Cluster Status ==="
kubectl get nodes
echo "=== System Pods ==="
kubectl get pods -n kube-system | grep -v Running
echo "=== Resource Usage ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
EOF

chmod +x monitor_cluster.sh
./monitor_cluster.sh
```

---

## Fichiers de configuration

### Configuration du cluster (cluster.conf)

```bash
# Configuration automatiquement générée
CLUSTER_ARCHITECTURE="single-node"
INSTALL_MODE="single-node"
SELECTED_COMPONENTS=""
INSTALL_DATE="2024-01-15 10:30:00"
```

### Configuration kubectl personnalisée

```bash
# Contextes multiples
kubectl config get-contexts
kubectl config use-context <context-name>

# Configuration pour utilisateurs non-root
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Bonnes pratiques

### Sécurité

- Utiliser des tokens avec durée de vie limitée
- Configurer RBAC approprié
- Mettre à jour régulièrement les composants
- Sauvegarder les certificats

### Performance

- Dimensionner correctement les ressources
- Utiliser des labels et sélecteurs efficaces
- Monitorer l'utilisation des ressources
- Optimiser la configuration réseau

### Opérations

- Automatiser les sauvegardes
- Documenter les procédures
- Tester les procédures de récupération
- Maintenir un inventaire des composants

---

Cette documentation couvre tous les aspects de votre script d'installation Kubernetes. Elle peut être enrichie selon vos besoins spécifiques et l'évolution de votre environnement.
