#!/bin/bash
set -e

case "$1" in
  namenode)
    if [ ! -d /hadoop/dfs/name/current ]; then
      echo "Formatting new HDFS namenode"
      hdfs namenode -format -force -nonInteractive
    fi
    exec hdfs namenode
    ;;
  datanode)
    exec hdfs datanode
    ;;
  resourcemanager)
    exec yarn resourcemanager
    ;;
  nodemanager)
    exec yarn nodemanager
    ;;
  historyserver)
    # Serves aggregated container logs of finished applications to the browser.
    exec mapred historyserver
    ;;
  spark-client)
    echo "Waiting for HDFS..."
    until hdfs dfs -ls / >/dev/null 2>&1; do sleep 3; done
    hdfs dfsadmin -safemode wait
    hdfs dfs -mkdir -p /user/hive/warehouse /tmp/hive /data/aether/raw
    hdfs dfs -chmod -R 1777 /tmp /user/hive/warehouse
    echo "HDFS ready. Submit jobs with: spark-submit /opt/jobs/<job>.py"
    exec tail -f /dev/null
    ;;
  *)
    exec "$@"
    ;;
esac
