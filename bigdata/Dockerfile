# One image for every Hadoop + Spark role, so Java and Python match on the
# Spark driver and on the YARN NodeManager where the executors run.
FROM apache/spark:3.5.3-scala2.12-java11-python3-ubuntu

USER root
ARG HADOOP_VERSION=3.3.6

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl procps \
 && rm -rf /var/lib/apt/lists/*

# ~700 MB download from the Apache archive; the first build takes a while.
RUN curl -fSL "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    | tar -xz -C /opt \
 && mv "/opt/hadoop-${HADOOP_VERSION}" /opt/hadoop \
 && rm -rf /opt/hadoop/share/doc \
 # Default lets ApplicationMasters use only 10% of the queue; too small on a 4 GB node.
 && sed -i '/maximum-am-resource-percent/{n;s/0\.1/0.6/}' /opt/hadoop/etc/hadoop/capacity-scheduler.xml

# Apache Iceberg runtime for Spark 3.5 / Scala 2.12. In Spark's own jars folder so the
# driver and the YARN executors both get it (spark.yarn.jars points here).
ARG ICEBERG_VERSION=1.6.1
RUN curl -fSL -o "/opt/spark/jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar"

ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    YARN_CONF_DIR=/opt/hadoop/etc/hadoop \
    SPARK_HOME=/opt/spark \
    PATH=/opt/hadoop/bin:/opt/spark/bin:$PATH

COPY conf/hadoop/ /opt/hadoop/etc/hadoop/
COPY conf/spark/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
COPY --chmod=755 entrypoint.sh /entrypoint-bigdata.sh

WORKDIR /opt/jobs
ENTRYPOINT ["/entrypoint-bigdata.sh"]
