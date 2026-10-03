# Hive 3.1.3: the newest metastore line that Spark 3.5's built-in Hive client talks to.
FROM apache/hive:3.1.3

USER root
ADD --chmod=644 https://jdbc.postgresql.org/download/postgresql-42.7.4.jar /opt/hive/lib/postgresql-42.7.4.jar
COPY hive-site.xml /opt/hive/conf/hive-site.xml
COPY --chmod=755 entrypoint.sh /entrypoint-hive.sh
USER hive

ENTRYPOINT ["/entrypoint-hive.sh"]
