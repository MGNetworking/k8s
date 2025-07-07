# Notice d'utilisation du script `basic_setup.sh`

Ce document est une notice d'utilisation pour le script `basic_setup.sh`, qui automatise la configuration d'un cluster Kubernetes sur une machine Ubuntu (VM ou serveur physique) pour un environnement de préproduction. Le script couvre les étapes nécessaires à l'installation de Kubernetes avec `kubeadm`, en utilisant `containerd` comme runtime et Calico comme plugin réseau (CNI). Il est conçu pour être robuste, avec des vérifications d'erreurs et la génération d'un fichier de log (`kubernetes_setup.log`) qui distingue les messages d'information (`[INFO]`), les avertissements (`[WARNING]`), et les erreurs (`[ERROR]`).

Cette notice détaille :

- Les étapes réalisées par le script, leurs objectifs, et pourquoi elles sont nécessaires.
- Les commandes à exécuter par l'utilisateur pour vérifier que le cluster Kubernetes est correctement configuré.
- Les instructions pour exécuter le script et consulter les logs.

Le script est compatible avec une VM ou un serveur physique Ubuntu (par exemple, 20.04 ou 22.04), avec une configuration réseau adaptée (plage `--pod-network-cidr=10.244.0.0/16` par défaut, ajustée si nécessaire).

---

## Prérequis

Avant d'exécuter le script, assurez-vous que :

- La machine utilise **Ubuntu** (20.04, 22.04, ou version récente).
- Vous disposez des **droits root** (le script doit être exécuté avec `sudo`).
- La machine a des ressources minimales :
  - **CPU** : 2 cœurs.
  - **RAM** : 4 Go (8 Go recommandé pour la préproduction).
  - **Stockage** : 20-50 Go (SSD recommandé).
- Une connexion Internet est disponible pour télécharger les paquets et les manifestes.
- Le réseau local n'utilise pas la plage `10.244.0.0/16` (vérifiable avec `ip addr`).

Pour vérifier les ressources :

```bash
lscpu
free -h
df -h
ip addr
```

---

## Instructions pour exécuter le script

1. **Enregistrer le script** :

   - Copiez le contenu du script dans un fichier nommé `basic_setup.sh`.
   - Rendez-le exécutable :
     ```bash
     chmod +x basic_setup.sh
     ```

2. **Exécuter le script** :

   - Lancez le script avec `sudo` :
     ```bash
     sudo ./basic_setup.sh
     ```
   - Le script affiche les logs en temps réel dans la console et les enregistre dans `kubernetes_setup.log`.

3. **Consulter les logs** :

   - Vérifiez le fichier de log pour les détails :
     ```bash
     cat kubernetes_setup.log
     ```
   - Les logs sont horodatés et classés par type (`[INFO]`, `[WARNING]`, `[ERROR]`) pour chaque étape.

4. **En cas d'erreur** :
   - Si le script s'arrête sur une erreur (`[ERROR]`), consultez `kubernetes_setup.log` pour identifier la cause.
   - Exécutez la commande suggérée dans le log ou contactez l'administrateur avec la sortie.

---

## Étapes réalisées par le script

Le script automatise les étapes de configuration d'un cluster Kubernetes. Chaque étape est expliquée avec son **objectif**, son **rôle**, et **pourquoi** elle est nécessaire, en lien avec votre objectif de déployer Spring Cloud Gateway dans un environnement de préproduction évolutif.

### Étape 0 : Vérification et réinitialisation conditionnelle du cluster

- **Objectif** : Vérifier l'état du cluster existant et proposer une réinitialisation si nécessaire.
- **Commandes** :
  ```bash
  kubeadm reset -f
  rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
  systemctl restart containerd
  systemctl restart kubelet
  ```
- **Rôle** :
  - Détecte un cluster existant via `/etc/kubernetes/admin.conf`.
  - Permet de réinitialiser proprement un cluster pour repartir sur une base saine.
  - Nettoie les configurations et redémarre les services.
- **Pourquoi ?** :
  - Évite les conflits avec une installation précédente.
  - Assure un démarrage propre du processus d'installation.
  - Dans votre cas : Permet de relancer l'installation après un échec ou une modification.

### Étape 0 (suite) : Vérification des ports requis

- **Objectif** : S'assurer que les ports nécessaires à Kubernetes sont disponibles.
- **Commandes** :
  ```bash
  netstat -tulnp | grep -q ":6443\|:10250\|:10257\|:2379\|:2380"
  ```
- **Rôle** :
  - Vérifie que les ports 6443 (API server), 10250 (kubelet), 10257 (scheduler), 2379/2380 (etcd) sont libres.
- **Pourquoi ?** :
  - Évite les conflits de ports qui empêcheraient le démarrage du cluster.
  - Dans votre cas : Garantit que l'API server et les composants essentiels pourront s'exécuter.

### Étape 1 : Mettre à jour le système

- **Objectif** : Assurer que le système Ubuntu est à jour avec les derniers paquets.
- **Commandes** :
  ```bash
  apt update
  apt upgrade -y
  ```
- **Rôle** :
  - `apt update` : Met à jour la liste des paquets disponibles.
  - `apt upgrade -y` : Installe les dernières versions des paquets installés.
- **Pourquoi ?** :
  - Garantit la compatibilité avec les outils Kubernetes (`kubeadm`, `containerd`).
  - Réduit les risques de failles de sécurité.
  - Dans votre cas : Prépare la machine pour l'installation de dépendances et de Kubernetes, évitant les problèmes liés à des versions obsolètes.

### Étape 2 : Désactiver le swap (VERSION CORRIGÉE)

- **Objectif** : Désactiver le swap pour répondre aux exigences de Kubernetes.
- **Commandes** :
  ```bash
  swapon --show
  swapoff -a
  sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  ```
- **Rôle** :
  - Vérifie d'abord si du swap est réellement actif avec `swapon --show`.
  - Désactive le swap uniquement s'il est présent.
  - Commente les lignes de swap dans `/etc/fstab` pour une désactivation permanente.
- **Pourquoi ?** :
  - Kubernetes exige l'absence de swap pour des performances prévisibles.
  - La version corrigée évite les erreurs si aucun swap n'est configuré.
  - Dans votre cas : Nécessaire pour que `kubeadm init` réussisse sans erreur.

### Étape 3 : Installer les dépendances

- **Objectif** : Installer les paquets nécessaires pour accéder au dépôt Kubernetes.
- **Commandes** :
  ```bash
  apt install -y curl apt-transport-https ca-certificates
  ```
- **Rôle** :
  - `curl` : Télécharge la clé GPG du dépôt Kubernetes.
  - `apt-transport-https` : Permet l'accès aux dépôts via HTTPS.
  - `ca-certificates` : Fournit les certificats SSL/TLS pour les connexions sécurisées.
- **Pourquoi ?** :
  - Ces outils sont requis pour ajouter et utiliser le dépôt Kubernetes officiel.
  - Dans votre cas : Permet l'installation de `kubeadm`, `kubelet`, et `kubectl`.

### Étape 4 : Installer containerd (VERSION CORRIGÉE)

- **Objectif** : Configurer `containerd` comme runtime pour exécuter les conteneurs des pods.
- **Commandes** :
  ```bash
  apt install -y containerd
  mkdir -p /etc/containerd
  containerd config default | tee /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
  systemctl enable containerd
  ```
- **Rôle** :
  - Installe `containerd` et génère sa configuration par défaut.
  - Active `SystemdCgroup` pour la compatibilité avec `kubeadm`.
  - Redémarre et active le service.
- **Pourquoi ?** :
  - Kubernetes a besoin d'un runtime pour gérer les conteneurs.
  - `SystemdCgroup = true` améliore la compatibilité avec `kubeadm`.
  - Dans votre cas : `containerd` est choisi pour sa légèreté et sa compatibilité avec Kubernetes.

### Étape 5 : Installer `kubeadm`, `kubelet`, `kubectl`

- **Objectif** : Installer les outils Kubernetes pour configurer et gérer le cluster.
- **Commandes** :
  ```bash
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
  apt update
  apt install -y kubeadm kubelet kubectl
  apt-mark hold kubeadm kubelet kubectl
  ```
- **Rôle** :
  - Ajoute le dépôt Kubernetes officiel avec la clé GPG.
  - Installe `kubeadm` (gestion du cluster), `kubelet` (agent des nœuds), `kubectl` (CLI).
  - Verrouille leurs versions pour éviter les mises à jour automatiques.
- **Pourquoi ?** :
  - Ces outils sont essentiels pour initialiser et interagir avec le cluster.
  - Dans votre cas : Nécessaire pour créer un cluster pour Spring Cloud Gateway.

### Étape 6 : Vérifier l'adresse IP pour éviter les conflits

- **Objectif** : Identifier la plage réseau pour éviter les conflits avec le réseau des pods.
- **Commandes** :
  ```bash
  ip addr show
  ```
- **Rôle** :
  - Vérifie les adresses IP utilisées par la machine.
  - Confirme que la plage `10.244.0.0/16` ne conflit pas avec le réseau existant.
- **Pourquoi ?** :
  - Un conflit d'IP peut empêcher les pods de communiquer.
  - Dans votre cas : Assure que `10.244.0.0/16` est adapté pour Calico.

### Étape 7 : Configurer les prérequis réseau

- **Objectif** : Activer les paramètres réseau nécessaires pour Kubernetes.
- **Commandes** :
  ```bash
  apt install -y linux-modules-extra-$(uname -r)
  modprobe br_netfilter
  echo "br_netfilter" | tee /etc/modules-load.d/kubernetes.conf
  echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-iptables
  sysctl -w net.ipv4.ip_forward=1
  echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-kubernetes.conf
  sysctl --system
  ```
- **Rôle** :
  - Installe les modules noyau nécessaires.
  - Charge `br_netfilter` et le rend persistant.
  - Active le filtrage réseau et le transfert IP.
  - Applique les configurations de manière persistante.
- **Pourquoi ?** :
  - `br_netfilter` permet à Kubernetes de gérer le trafic réseau via iptables.
  - `net.ipv4.ip_forward` permet le routage entre interfaces.
  - Dans votre cas : Résout les erreurs de prérequis réseau lors de `kubeadm init`.

### Étape 8 : Initialiser le cluster avec kubeadm

- **Objectif** : Créer un cluster Kubernetes fonctionnel.
- **Commandes** :
  ```bash
  kubeadm init --pod-network-cidr=10.244.0.0/16
  mkdir -p $USER_HOME/.kube
  cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $(id -u $SUDO_USER):$(id -g $SUDO_USER) $USER_HOME/.kube/config
  ```
- **Rôle** :
  - Initialise le plan de contrôle (API server, etcd, scheduler, controller-manager).
  - Configure `kubectl` pour l'utilisateur non-root.
  - Définit la plage réseau pour les pods.
- **Pourquoi ?** :
  - Transforme la machine en un nœud maître Kubernetes.
  - Dans votre cas : Prépare le cluster pour déployer Spring Cloud Gateway.

### Étape 8 (suite) : Configuration single-node

- **Objectif** : Permettre le déploiement de pods sur le nœud master (configuration single-node).
- **Commandes** :
  ```bash
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  kubectl taint nodes --all node-role.kubernetes.io/master-
  ```
- **Rôle** :
  - Supprime les "taints" du nœud master qui empêchent normalement le déploiement de pods.
  - Permet au nœud master d'exécuter des pods d'application.
- **Pourquoi ?** :
  - Par défaut, les pods ne peuvent pas s'exécuter sur le nœud master.
  - Pour un cluster single-node, cette restriction doit être levée.
  - Dans votre cas : Essentiel pour que Spring Cloud Gateway puisse s'exécuter.

### Étape 9 : Installer le plugin réseau Calico

- **Objectif** : Configurer le réseau virtuel pour les pods.
- **Commandes** :
  ```bash
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  ```
- **Rôle** :
  - Installe Calico comme plugin CNI (Container Network Interface).
  - Configure le réseau pour permettre la communication entre pods.
  - Utilise la plage `10.244.0.0/16` définie lors de l'initialisation.
- **Pourquoi ?** :
  - Sans CNI, les pods ne peuvent pas communiquer entre eux.
  - Calico est choisi pour sa robustesse et sa compatibilité.
  - Dans votre cas : Nécessaire pour que Spring Cloud Gateway puisse communiquer avec les services.

### Étape 10 : Vérifier l'état du cluster

- **Objectif** : Confirmer que le cluster est opérationnel.
- **Commandes** :
  ```bash
  kubectl get nodes
  kubectl get pods -n kube-system
  ```
- **Rôle** :
  - Vérifie que le nœud est en état `Ready`.
  - Confirme que les pods système sont en cours d'exécution.
- **Pourquoi ?** :
  - Assure que le cluster est prêt pour déployer des applications.
  - Dans votre cas : Confirme que l'environnement est prêt pour Spring Cloud Gateway.

### Étape 11 : Configurer l'Ingress et la résolution DNS

- **Objectif** : Installer le contrôleur NGINX Ingress pour gérer l'accès externe aux services.
- **Commandes** :
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.2/deploy/static/provider/baremetal/deploy.yaml
  echo "127.0.0.1 nutrition.local" >> /etc/hosts
  echo "127.0.0.1 gateway.local" >> /etc/hosts
  ```
- **Rôle** :
  - Installe NGINX Ingress Controller adapté pour bare-metal.
  - Configure la résolution DNS locale pour les domaines de test.
  - Attend que les pods NGINX Ingress soient prêts.
- **Pourquoi ?** :
  - Permet d'accéder aux services Kubernetes depuis l'extérieur du cluster.
  - La version bare-metal utilise NodePort pour exposer les services.
  - Dans votre cas : Essentiel pour accéder à Spring Cloud Gateway via HTTP/HTTPS.

### Étape 12 : Récapitulatif final

- **Objectif** : Fournir un résumé de l'installation et les informations utiles.
- **Rôle** :
  - Affiche les composants installés.
  - Indique les commandes utiles pour la gestion du cluster.
  - Précise l'emplacement des logs et de la configuration.
- **Pourquoi ?** :
  - Facilite la prise en main du cluster nouvellement installé.
  - Dans votre cas : Prépare la suite avec les informations nécessaires pour déployer Spring Cloud Gateway.

---

## Vérification de l'installation de Kubernetes

Après l'exécution du script, utilisez les commandes suivantes pour vérifier que le cluster Kubernetes est correctement configuré. Ces commandes permettent de s'assurer que chaque composant fonctionne comme prévu.

1. **Vérifier l'état du nœud** :

   ```bash
   kubectl get nodes
   ```

   - **Objectif** : Vérifie que le nœud maître est en état `Ready`.
   - **Sortie attendue** :
     ```
     NAME    STATUS   ROLES           AGE    VERSION
     <nom>   Ready    control-plane   Xm     v1.28.15
     ```
   - **Pourquoi ?** : Confirme que le nœud est opérationnel et que le plan de contrôle fonctionne.
   - **Action si erreur** : Si le nœud est en `NotReady`, vérifiez les pods Calico (étape suivante) ou consultez `kubernetes_setup.log`.

2. **Vérifier les pods système** :

   ```bash
   kubectl get pods -n kube-system
   ```

   - **Objectif** : Vérifie que les pods système (par exemple, `coredns`, `calico-node`, `kube-apiserver`) sont en état `Running`.
   - **Sortie attendue** :
     ```
     NAME                             READY   STATUS    RESTARTS   AGE
     calico-node-...                  1/1     Running   0          Xm
     coredns-...                      1/1     Running   0          Xm
     kube-apiserver-...               1/1     Running   0          Xm
     ...
     ```
   - **Pourquoi ?** : Assure que les composants essentiels du cluster (DNS, réseau, API) fonctionnent.
   - **Action si erreur** : Si un pod est en `Pending` ou `CrashLoopBackOff`, exécutez `kubectl describe pod <nom-du-pod> -n kube-system` pour diagnostiquer.

3. **Vérifier le réseau des pods** :

   ```bash
   kubectl get pods -n kube-system -l k8s-app=calico-node
   ```

   - **Objectif** : Confirme que les pods Calico sont en cours d'exécution.
   - **Sortie attendue** : Les pods `calico-node` doivent être en `Running`.
   - **Pourquoi ?** : Calico gère le réseau des pods, essentiel pour la communication.
   - **Action si erreur** : Consultez `kubernetes_setup.log` ou exécutez `kubectl logs <nom-du-pod> -n kube-system`.

4. **Vérifier le contrôleur NGINX Ingress** :

   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get svc -n ingress-nginx
   ```

   - **Objectif** : Confirme que le contrôleur NGINX Ingress est en cours d'exécution.
   - **Sortie attendue** : Les pods ingress-nginx doivent être en `Running` et les services exposés via NodePort.
   - **Pourquoi ?** : Nécessaire pour accéder aux applications depuis l'extérieur du cluster.
   - **Action si erreur** : Consultez `kubernetes_setup.log` ou exécutez `kubectl describe pods -n ingress-nginx`.

5. **Vérifier la configuration réseau** :

   ```bash
   lsmod | grep br_netfilter
   cat /proc/sys/net/bridge/bridge-nf-call-iptables
   sysctl net.ipv4.ip_forward
   ```

   - **Objectif** : Vérifie que `br_netfilter` est chargé et que les paramètres réseau sont corrects.
   - **Sortie attendue** :
     - `lsmod | grep br_netfilter` : Affiche `br_netfilter`.
     - `cat /proc/sys/net/bridge/bridge-nf-call-iptables` : Affiche `1`.
     - `sysctl net.ipv4.ip_forward` : Affiche `net.ipv4.ip_forward = 1`.
   - **Pourquoi ?** : Assure que les prérequis réseau sont en place.
   - **Action si erreur** : Répétez l'étape 7 du script (voir `kubernetes_setup.log`).

6. **Vérifier la version de Kubernetes** :

   ```bash
   kubeadm version
   kubelet --version
   kubectl version --client
   ```

   - **Objectif** : Confirme que les outils Kubernetes sont installés et utilisent la version correcte (1.28).
   - **Sortie attendue** :
     ```
     kubeadm version: v1.28.15
     Kubernetes v1.28.15
     Client Version: v1.28.15
     ```
   - **Pourquoi ?** : Vérifie la compatibilité des outils.
   - **Action si erreur** : Consultez `kubernetes_setup.log` pour les erreurs d'installation.

7. **Tester la création d'un pod** :

   ```bash
   kubectl run test-pod --image=nginx --restart=Never
   kubectl get pods
   ```

   - **Objectif** : Déploie un pod de test (NGINX) pour vérifier que le cluster peut exécuter des conteneurs.
   - **Sortie attendue** :
     ```
     NAME       READY   STATUS    RESTARTS   AGE
     test-pod   1/1     Running   0          Xs
     ```
   - **Pourquoi ?** : Confirme que le runtime (`containerd`) et le réseau fonctionnent.
   - **Action si erreur** : Exécutez `kubectl describe pod test-pod` pour diagnostiquer.

8. **Vérifier l'accès aux domaines locaux** :
   ```bash
   nslookup nutrition.local
   nslookup gateway.local
   ```
   - **Objectif** : Confirme que la résolution DNS locale fonctionne.
   - **Sortie attendue** : Les domaines doivent résoudre vers `127.0.0.1`.
   - **Pourquoi ?** : Nécessaire pour accéder aux applications via les noms de domaine.
   - **Action si erreur** : Vérifiez `/etc/hosts` et ajoutez manuellement les entrées si nécessaire.

---

## Informations post-installation

Après l'installation réussie, le script fournit les informations suivantes :

### Ports d'accès NGINX Ingress

- **HTTP** : Le port NodePort pour HTTP (généralement 30000-32767)
- **HTTPS** : Le port NodePort pour HTTPS (généralement 30000-32767)

### URLs d'accès

- `http://nutrition.local:<port_http>`
- `http://gateway.local:<port_http>`
- `https://nutrition.local:<port_https>`
- `https://gateway.local:<port_https>`

### Configuration kubectl

- Fichier de configuration : `~/.kube/config`
- Utilisateur configuré : utilisateur non-root (défini par `$SUDO_USER`)

---

## Dépannage

- **Consultez les logs** :

  - Si une erreur ou un avertissement apparaît, vérifiez `kubernetes_setup.log` :
    ```bash
    cat kubernetes_setup.log
    ```
  - Cherchez les lignes `[ERROR]` ou `[WARNING]` pour identifier la cause.

- **Erreurs courantes** :

  - **Échec de `kubeadm init`** : Vérifiez `br_netfilter` et `net.ipv4.ip_forward` (étape 5 ci-dessus).
  - **Pods Calico en `Pending`** : Vérifiez les logs avec `kubectl logs <nom-du-pod> -n kube-system`.
  - **Pods NGINX Ingress en `Pending`** : Vérifiez les ressources disponibles et les taints du nœud.
  - **Conflit d'IP** : Si `10.244.0.0/16` est utilisé, modifiez le script pour utiliser `172.16.0.0/16`.

- **Réinitialisation du cluster** :

  - Si vous devez recommencer, le script propose une réinitialisation automatique au début.
  - Vous pouvez également réinitialiser manuellement :
    ```bash
    sudo kubeadm reset -f
    sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube
    ```

- **Ressources insuffisantes** :

  - Vérifiez CPU, RAM, et stockage :
    ```bash
    lscpu
    free -h
    df -h
    ```

- **Problèmes de réseau** :
  - Vérifiez la connectivité Internet :
    ```bash
    ping 8.8.8.8
    curl -I https://docs.projectcalico.org
    ```

---

## Notes

- **Compatibilité** : Le script est conçu pour Ubuntu (VM ou serveur physique). Vérifiez la version d'Ubuntu et du noyau :
  ```bash
  lsb_release -a
  uname -r
  ```
- **Évolutivité** : Pour ajouter des nœuds, utilisez la commande `kubeadm join` affichée après `kubeadm init` (voir `kubernetes_setup.log`).
- **Spring Cloud Gateway** : Après vérification, le cluster est prêt pour le déploiement de Spring Cloud Gateway.
- **Sauvegarde** : Avant d'exécuter le script sur un serveur physique, sauvegardez les configurations importantes :
  ```bash
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo cp /etc/hosts /etc/hosts.bak
  ```
- **Sécurité** : Ce script configure un cluster de développement/préproduction. Pour la production, considérez :
  - La configuration de certificats TLS personnalisés
  - La restriction d'accès à l'API server
  - La configuration de politiques réseau
  - La mise en place de monitoring et logging
