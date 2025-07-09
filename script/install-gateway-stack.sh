#!/bin/bash

set -e

echo "🧱 Création des ressources pour Spring Gateway..."

# 1. Ingress NGINX
echo "📦 Installation de ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# 2. Attente que le controller soit prêt
echo "⏳ Attente que le contrôleur Ingress soit disponible..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx

# 3. Cert-manager
echo "📦 Installation de cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# 4. Attente que cert-manager soit prêt
echo "⏳ Attente de cert-manager..."
kubectl rollout status deployment/cert-manager -n cert-manager
kubectl rollout status deployment/cert-manager-webhook -n cert-manager
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager

# 5. ClusterIssuer
echo "📄 Déploiement du ClusterIssuer (Let's Encrypt)..."
kubectl apply -f cluster-issuer.yaml

# 6. ServiceAccount + RBAC
echo "🔐 Déploiement du ServiceAccount et des rôles..."
kubectl apply -f gateway-service-account.yaml

# 7. Deployment + Service
echo "🚀 Déploiement de Spring Cloud Gateway..."
kubectl apply -f api-gateway-deployment.yaml
kubectl apply -f api-gateway-service.yaml

# 8. Ingress avec TLS
echo "🌐 Déploiement de l'Ingress avec certificat TLS automatique..."
kubectl apply -f api-gateway-ingress.yaml

echo "✅ Tout est déployé. Vérifie que l'Ingress a bien récupéré un certificat :"
echo "🔍 kubectl get certificate"
