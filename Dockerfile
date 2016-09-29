# File instantiated from Fiware repo
# Customized by waziup
####################################

FROM centos:6

MAINTAINER Waziup_agent

# Environment variables
ENV CYGNUS_USER "cygnus"
ENV CYGNUS_HOME "/opt/fiware-cygnus"
ENV CYGNUS_VERSION "1.3.0"
ENV CYGNUS_CONF_PATH "/opt/apache-flume/conf"
ENV CYGNUS_CONF_FILE "/opt/apache-flume/conf/agent.conf"
ENV CYGNUS_AGENT_NAME "cygnus-ngsi"
ENV CYGNUS_LOG_LEVEL "INFO"
ENV CYGNUS_LOG_APPENDER "console"
ENV CYGNUS_SERVICE_PORT "5050"
ENV CYGNUS_API_PORT "8081"
ENV CYGNUS_MYSQL_USER "mysql"
ENV CYGNUS_MYSQL_PASS "mysql"
ENV CYGNUS_MONGO_USER "mongo"
ENV CYGNUS_MONGO_PASS "mongo"

ENV GIT_URL_CYGNUS "https://github.com/telefonicaid/fiware-cygnus.git"
ENV GIT_REV_CYGNUS "release/1.3.0"

ENV MVN_VER "3.2.5"
ENV MVN_TGZ "apache-maven-${MVN_VER}-bin.tar.gz"
ENV MVN_URL "http://www.eu.apache.org/dist/maven/maven-3/${MVN_VER}/binaries/${MVN_TGZ}"
ENV MVN_HOME "/opt/apache-maven"

ENV FLUME_VER "1.4.0"
ENV FLUME_TGZ "apache-flume-${FLUME_VER}-bin.tar.gz"
ENV FLUME_URL "http://archive.apache.org/dist/flume/${FLUME_VER}/${FLUME_TGZ}"
ENV FLUME_HOME "/opt/apache-flume"

ENV JAVA_HOME /usr/lib/jvm/java-1.6.0

COPY . ${CYGNUS_HOME}/

# Install
RUN \
    # Add Cygnus user
    adduser ${CYGNUS_USER} && \
    yum -y install nc java-1.6.0-openjdk-devel git && \
    curl --remote-name --location --insecure --silent --show-error "${MVN_URL}" && \
    tar xzvf ${MVN_TGZ} && \
    mv apache-maven-${MVN_VER} ${MVN_HOME} && \
    export MAVEN_OPTS="-Xmx512m -XX:MaxPermSize=128m" && \
    curl --remote-name --location --insecure --silent --show-error "${FLUME_URL}" && \
    tar zxf ${FLUME_TGZ} && \
    mv apache-flume-${FLUME_VER}-bin ${FLUME_HOME} && \
    mkdir -p ${FLUME_HOME}/plugins.d/cygnus && \
    mkdir -p ${FLUME_HOME}/plugins.d/cygnus/lib && \
    mkdir -p ${FLUME_HOME}/plugins.d/cygnus/libext && \
    # mkdir -p ${CYGNUS_HOME}/cygnus-common && \
    chown -R cygnus:cygnus ${FLUME_HOME} && \
    # Build and install cygnus-common
    cd ${CYGNUS_HOME}/cygnus-common && \
    ${MVN_HOME}/bin/mvn clean compile exec:exec assembly:single && \
    cp target/cygnus-common-${CYGNUS_VERSION}-jar-with-dependencies.jar ${FLUME_HOME}/plugins.d/cygnus/libext/ && \
    ${MVN_HOME}/bin/mvn install:install-file -Dfile=${FLUME_HOME}/plugins.d/cygnus/libext/cygnus-common-${CYGNUS_VERSION}-jar-with-dependencies.jar -DgroupId=com.telefonica.iot -DartifactId=cygnus-common -Dversion=${CYGNUS_VERSION} -Dpackaging=jar -DgeneratePom=false && \
    # Build and install cygnus-ngsi
    cd ${CYGNUS_HOME}/cygnus-ngsi && \
    ${MVN_HOME}/bin/mvn clean compile exec:exec assembly:single && \
    cp target/cygnus-ngsi-${CYGNUS_VERSION}-jar-with-dependencies.jar ${FLUME_HOME}/plugins.d/cygnus/lib/ && \
    # Install Cygnus Application script
    cp ${CYGNUS_HOME}/cygnus-common/target/classes/cygnus-flume-ng ${FLUME_HOME}/bin/ && \
    chmod +x ${FLUME_HOME}/bin/cygnus-flume-ng && \
    # Instantiate some configuration files
    cp ${CYGNUS_HOME}/cygnus-common/conf/log4j.properties.template ${FLUME_HOME}/conf/log4j.properties && \
    cp ${CYGNUS_HOME}/cygnus-ngsi/conf/grouping_rules.conf.template ${FLUME_HOME}/conf/grouping_rules.conf && \
    # Create Cygnus log folder
    mkdir -p /var/log/cygnus && \
    # Cleanup to thin the final image
    cd ${CYGNUS_HOME}/cygnus-common && \
    ${MVN_HOME}/bin/mvn clean && \
    cd ${CYGNUS_HOME}/cygnus-ngsi && \
    ${MVN_HOME}/bin/mvn clean && \
    rm -rf /root/.m2 && rm -rf ${MVN_HOME} && rm -rf ${FLUME_HOME}/docs && rm -rf ${CYGNUS_HOME}/doc && rm -f /*.tar.gz && \
    yum erase -y git java-1.6.0-openjdk-devel && unset JAVA_HOME && \
    rpm -qa redhat-logos gtk2 pulseaudio-libs libvorbis jpackage* groff alsa* atk cairo libX* | xargs -r rpm -e --nodeps && yum -y erase libss && \
    yum clean all && rpm -vv --rebuilddb && rm -rf /var/lib/yum/yumdb && rm -rf /var/lib/yum/history && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en_US' ! -name 'locale.alias' | xargs -r rm -r && rm -f /var/log/*log && \
    bash -c 'localedef --list-archive | grep -v -e "en_US" | xargs localedef --delete-from-archive' && \
    /bin/cp -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl && \
    build-locale-archive && find ${CYGNUS_HOME} -name '.[^.]*' 2>/dev/null | xargs -r rm -rf && \
    # Reduce two big jar files...
    pack200 ${FLUME_HOME}/plugins.d/cygnus/libext/cygnus-common-${CYGNUS_VERSION}-jar-with-dependencies.jar.pack.gz ${FLUME_HOME}/plugins.d/cygnus/libext/cygnus-common-${CYGNUS_VERSION}-jar-with-dependencies.jar && \
    pack200 ${FLUME_HOME}/plugins.d/cygnus/lib/cygnus-ngsi-${CYGNUS_VERSION}-jar-with-dependencies.jar.pack.gz ${FLUME_HOME}/plugins.d/cygnus/lib/cygnus-ngsi-${CYGNUS_VERSION}-jar-with-dependencies.jar && \
    rm -f ${FLUME_HOME}/plugins.d/cygnus/libext/cygnus-common-${CYGNUS_VERSION}-jar-with-dependencies.jar && \
    rm -f ${FLUME_HOME}/plugins.d/cygnus/lib/cygnus-ngsi-${CYGNUS_VERSION}-jar-with-dependencies.jar

# Copy some files needed for starting cygnus-ngsi
COPY docker/cygnus-ngsi/cygnus-entrypoint.sh /
COPY docker/cygnus-ngsi/agent.conf ${FLUME_HOME}/conf/

# Define the entry point
ENTRYPOINT ["/cygnus-entrypoint.sh"]

# Ports used by cygnus-ngsi
EXPOSE ${CYGNUS_SERVICE_PORT} ${CYGNUS_API_PORT}

