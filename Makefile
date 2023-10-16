#!/bin/bash

validate_access:
	echo

install-prerequisites-mac:
	python -m pip install -r ./requirement.txt
	brew install kustomize@3.2.0

install-common:
	while ! kustomize build example  | kubectl apply --validate=false -f -; do echo "Retrying to apply resources"; sleep 10; done
	kubectl patch svc/istio-ingressgateway -n istio-system  --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
	kubectl patch svc/minio-service -n kubeflow  --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'

port-forward:
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
	$(info Use this link to conenct: "http://localhost:8080")

create-user:
	python3 ./common/dex/generate_password.py

install-istio-system:
	kustomize build common/istio-1-16/istio-crds/base | kubectl apply -f -
	kustomize build common/istio-1-16/istio-namespace/base | kubectl apply -f -
	kustomize build common/istio-1-16/istio-install/base | kubectl apply -f -

install-cert-manager:
	kustomize build common/cert-manager/cert-manager/base | kubectl apply -f -
	kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
	kustomize build common/cert-manager/kubeflow-issuer/base | kubectl apply -f -

install-istio:
	kustomize build common/istio-1-16/istio-crds/base | kubectl apply -f -
	kustomize build common/istio-1-16/istio-namespace/base | kubectl apply -f -
	kustomize build common/istio-1-16/istio-install/base | kubectl apply -f -

install-dex:
	kustomize build common/dex/overlays/istio | kubectl apply -f -

install-oidc-auth-service:
	kustomize build common/oidc-authservice/base | kubectl apply -f -

install-knative:
	kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
	kustomize build common/istio-1-16/cluster-local-gateway/base | kubectl apply -f -
	kustomize build common/knative/knative-eventing/base | kubectl apply -f -

install-kubeflow-namespace:
	kustomize build common/kubeflow-namespace/base | kubectl apply -f -

install-kubeflow-roles:
	kustomize build common/kubeflow-roles/base | kubectl apply -f -

install-kubeflow-istio-resources:
	kustomize build common/istio-1-16/kubeflow-istio-resources/base | kubectl apply -f -

install-kubeflow-pipelines:
	kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user  | kubectl apply --validate=false -f -

install-kserve:
	kustomize build contrib/kserve/kserve | kubectl apply -f -
	kustomize build contrib/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -

install-katib:
	kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -

install-central-dashboard:
	kustomize build apps/centraldashboard/upstream/overlays/kserve | kubectl apply -f -

install-admission-webhook:
	kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -

install-note-books:
	kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
	kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -

install-profiles-KFAM:
	kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -

install-volumes-web-app:
	kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -

install-tensor-board:
	kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
	kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -

install-training-operator:
	kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -

install-user-namespace:
	kustomize build common/user-namespace/base | kubectl apply -f -

health-check:
	kubectl get pods -n cert-manager
	kubectl get pods -n istio-system
	kubectl get pods -n auth
	kubectl get pods -n knative-eventing
	kubectl get pods -n knative-serving
	kubectl get pods -n kubeflow
	kubectl get pods -n kubeflow-user-example-com

install-all:
	make install-istio-system
	make install-cert-manager
	make install-istio
	make install-dex
	make install-oidc-auth-service
	make install-knative
	make install-kubeflow-namespace
	make install-kubeflow-roles
	make install-kubeflow-istio-resources
	make install-kubeflow-pipelines
	make install-kserve
	make install-katib
	make install-central-dashboard
	make install-admission-webhook
	make install-note-books
	make install-profiles-KFAM
	make install-volumes-web-app
	make install-tensor-board
	make install-training-operator
	make install-user-namespace

delete-namespace:
	kubectl delete namespaces kubeflow --force

make_sure_deleted:
	kubectl get ns cert-manager -o json
	jq '.spec.finalizers=[]'
	curl -X PUT http://localhost:8001/api/v1/namespaces/cert-manager/finalize -H "Content-Type: application/json" --data @-


dns:
	kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"LoadBalancer"}}'
	iptables -t nat -A PREROUTING -d 185.74.221.163 -p tcp --dport 80 -j DNAT --to-destination 192.168.10.2:30171