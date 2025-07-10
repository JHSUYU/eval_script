#!/bin/bash
# topology.sh for Hadoop 2.7

TOPOLOGY_DATA="/opt/hadoop_scripts/topology.data"

while [ $# -gt 0 ] ; do
  nodeArg=$1
  result=""

  if [ -f "$TOPOLOGY_DATA" ]; then
    while IFS=' ' read -r node rack; do
      # 跳过空行
      if [[ -z "$node" ]]; then
        continue
      fi

      if [ "$node" = "$nodeArg" ]; then
        result="$rack"
        break
      fi
    done < "$TOPOLOGY_DATA"
  fi

  shift

  if [ -z "$result" ]; then
    echo -n "/default-rack "
  else
    echo -n "$result "
  fi
done