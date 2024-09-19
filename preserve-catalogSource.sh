#!/bin/bash

file="$1"

[ "$#" -ne 1 ] && echo "Please enter the operator's tar file" && exit 1
[ ! -f "$file" ] && echo -e "File '$1' does not exists!" && exit 1

command -v docker > /dev/null 2>81 && export engine=docker
command -v podman > /dev/null 2>&1 && export engine=podman
[ -z "$engine" ] && echo "You must have 'podman' or 'docker' installed" && exit 1

rm -rf oc-mirror-workspace .oc-mirror.log
oc-mirror --skip-cleanup --continue-on-error=false --from "$file" docker://quay.io/roeywer/openshift

indexImage=`cat $(find oc-mirror-workspace -name catalogSource-*) | grep image: | cut -d ' ' -f 4`
echo "$indexImage"
version=`echo "$indexImage" | rev | cut -d : -f 1 | rev`
operator=`cat $(find oc-mirror-workspace -name index.json | grep -v layout) | head -n 3 | tail -n 1 | tr -d ' ,"' | cut -d ':' -f 2`
pushTo="quay.io/roeywer/openshift/catalogsource/$operator:$version"
rm -rf oc-mirror-workspace/images*

"$engine" pull "$indexImage"
"$engine" tag "$indexImage" "$pushTo"
"$engine" push "$pushTo"
"$engine" rmi "$indexImage" "$pushTo"

catalogSource=`sed $(find oc-mirror-workspace -name catalogSource-*) -e "s~  image: .*~  image: $pushTo~g" -e "s~  name: .*~  name: $operator~g"`

echo "$catalogSource" > `find oc-mirror-workspace -name results-*`/cs-new.yaml
echo
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

cat .oc-mirror.log | grep -1 error
