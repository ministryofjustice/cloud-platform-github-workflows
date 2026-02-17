#!/bin/bash
# Gather cluster names if accountClusters is in that list remove it from the list as these cluster do not need to be deleted 
# and we want to send a reminder about the clusters that do need to be deleted. 
# These are not account clusters and should be deleted after use.


accountClusters=("cloud-platform-development" "cloud-platform-preproduction" "cloud-platform-nonlive" "cloud-platform-live")

clusterList=$(aws eks list-clusters --region eu-west-2)
accountAliases=$(aws iam list-account-aliases --region eu-west-2 | jq -r '.AccountAliases[]')

for accountCluster in "${accountClusters[@]}"
do
  if [[ $clusterList == *"$accountCluster"* ]]; then
    clusterList=$(echo "$clusterList" | jq --arg accountCluster "$accountCluster" 'del(.clusters[] | select(. == $accountCluster))')
  fi
done

# build a message to send to slack 
clustersToDelete=$(echo "$clusterList" | jq -r '.clusters[]')

title=":donut_spin: :donut_spin: :friday_yayday: *Friday test cluster cleanup reminder!* :friday_yayday: :donut_spin: :donut_spin:"

if [[ -n "$clustersToDelete" ]]; then
  clusters_msg="Clusters that need to be deleted:"
else
  clusters_msg="*Yay, there are no development clusters to cleanup!*"
fi

echo -e "$title\nAccount: $accountAliases\n$clusters_msg\n$clustersToDelete"