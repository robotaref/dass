#!/bin/bash

validate_access:
	echo

install-prerequisites-mac:
	python -m pip install -r ./requirement.txt
	brew install kustomize

install-common:
	while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done
port-forward:
	kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
	$(info Use this link to conenct: "https://localhost:8080")

create-user:
	python3 ./common/dex/generate_password.py
