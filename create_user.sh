#!/bin/bash

# Prompt the user for PROFILE_NAME and PROFILE_EMAIL
read -p "Enter PROFILE_NAME: " PROFILE_NAME
read -p "Enter PROFILE_EMAIL: " PROFILE_EMAIL

source_yaml="profiles/boiler_plate.yaml"
output_yaml="profiles/$PROFILE_NAME.yaml"
configmap_yaml="common/dex/base/config-map.yaml"
hash=$(python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))')
regex='[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*'

# Ensure the configmap.yaml file exists
if [ ! -f "$configmap_yaml" ]; then
  echo "Error: ConfigMap YAML file '$configmap_yaml' not found."
  exit 1
fi

if [ ! -f "$source_yaml" ]; then
  echo "Error: Source YAML file '$source_yaml' not found."
  exit 1
fi

cp "$source_yaml" "$output_yaml"

# Replace placeholders with user input in the duplicated file using a different delimiter
sed -i "" "s|PROFILE_NAME|$PROFILE_NAME|g" "$output_yaml"
sed -i "" "s|PROFILE_EMAIL|$PROFILE_EMAIL|g" "$output_yaml"

# Apply the modified YAML to Kubeflow
kubectl apply -f "$output_yaml"

echo "Profile applied to Kubeflow with NAME: $PROFILE_NAME and EMAIL: $PROFILE_EMAIL"


sed -i '' '/staticPasswords:/a \
    - email: '"$PROFILE_EMAIL"'\
      hash: '"$hash"'\
' "$configmap_yaml"
echo "USER_PASSWORD appended to the ConfigMap."

kubectl apply -f "$configmap_yaml"
kustomize build common/dex/overlays/istio | kubectl apply -f -
kubectl rollout restart deployment dex -n auth
