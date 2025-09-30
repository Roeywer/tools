#!/bin/bash
# Step 1: Ask the user for the config file, from path, and dest registry.
config_file="${1:-}"
from_path="${2:-}"
dest_registry="${3:-}"
operator="${4:-}"

[ -z "$config_file" ] && read -r -p "Path to ImageSetConfiguration YAML: " config_file
[ -z "$from_path" ] && read -r -p "Path to folder for --from (file://thisFolder): " from_path
[ -z "$dest_registry" ] && read -r -p "Destination registry URL (e.g., quay.io/roeywer/openshift): " dest_registry
[ -z "$operator" ] && read -r -p "Operator name (e.g., crunchy-postgres-operator): " operator

[ ! -f "$config_file" ] && echo -e "Config file '$config_file' does not exist!" && exit 1
[ ! -e "$from_path" ] && echo -e "Source path '$from_path' does not exist!" && exit 1
[ -z "$dest_registry" ] && echo -e "Destination registry must be provided, e.g. quay.io/roeywer/openshift" && exit 1
[ -z "$operator" ] && echo -e "Operator name must be provided, e.g. crunchy-postgres-operator" && exit 1
# Step 2: Check if docker or podman is installed.
command -v docker > /dev/null 2>81 && export engine=docker
command -v podman > /dev/null 2>&1 && export engine=podman
[ -z "$engine" ] && echo "You must have 'podman' or 'docker' installed" && exit 1
# Step 3: Run oc mirror.
# rm -rf oc-mirror-workspace .oc-mirror.log
oc mirror -c "$config_file" --from "file://$from_path" "docker://$dest_registry" --v2
# Step 4: Get the catalogSource path and index image name.
cs_path=`find "$from_path/working-dir/cluster-resources/" -name 'cs-*' | head -n 1`
[ -z "$cs_path" ] && echo -e "Could not locate catalogSource file under '$from_path/working-dir/cluster-resources/'." && exit 1
indexImage=`grep -m1 '^  image:' "$cs_path" | awk '{print $2}'`
echo "$indexImage"
version=`echo "$indexImage" | rev | cut -d : -f 1 | rev`
pushTo="$dest_registry/catalogsource/$operator:$version"
# rm -rf $from_path/working-dir/
# Step 5: Pull, tag, push, and remove the index image.
"$engine" pull "$indexImage"
"$engine" tag "$indexImage" "$pushTo"
"$engine" push "$pushTo"
"$engine" rmi "$indexImage" "$pushTo"
# Step 6: Replace the catalogSource image and name.
catalogSource=`sed -e "/^metadata:/,/^spec:/{s|^  name: .*|  name: $operator|}" -e "/^spec:/,/^status:/{s|^  image: .*|  image: $pushTo|}" "$cs_path"`

echo "$catalogSource" > "$(dirname "$cs_path")/cs-new.yaml"
echo 
echo 
echo
echo
echo "catalogSource down below :)"
echo
echo
echo "$catalogSource"
echo 
echo 
echo
echo

[ -f .oc-mirror.log ] && cat .oc-mirror.log | grep -1 error || true
