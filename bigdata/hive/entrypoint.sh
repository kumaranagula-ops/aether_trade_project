#!/bin/bash
set -e
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS $SERVICE_OPTS"

if [ "$SERVICE_NAME" = "metastore" ]; then
  # Create the metastore schema on first start only, so restarts are safe.
  if ! /opt/hive/bin/schematool -dbType postgres -info >/dev/null 2>&1; then
    /opt/hive/bin/schematool -dbType postgres -initSchema
  fi
  exec /opt/hive/bin/hive --skiphadoopversion --skiphbasecp --service metastore
else
  exec /opt/hive/bin/hive --skiphadoopversion --skiphbasecp --service hiveserver2
fi
