FROM docker.sunet.se/eduix/eduix-base:latest
MAINTAINER Juha Leppälä "juha@eduix.fi"

# Setup useful environment variables
ENV CONFLUENCE_HOME     /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL  /opt/atlassian/confluence
ENV HEAP_START          2048
ENV HEAP_MAX            2048
ARG CONF_VERSION=6.7.2

LABEL Description="This image is used to start Atlassian Confluence" Vendor="Atlassian" Version="${CONF_VERSION}"

ENV CONFLUENCE_DOWNLOAD_URL http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONF_VERSION}.tar.gz

ENV MYSQL_VERSION 5.1.38
ENV MYSQL_DRIVER_DOWNLOAD_URL http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_VERSION}.tar.gz

ENV RUN_USER            atlassian
ENV RUN_GROUP           atlassian

# Install Atlassian Confluence and helper tools and setup initial home
# directory structure.
RUN set -x \
    && mkdir -p                           "${CONFLUENCE_HOME}" \
    && chmod -R 700                       "${CONFLUENCE_HOME}" \
    && mkdir -p                           "${CONFLUENCE_INSTALL}/conf" \
    && curl -Ls                           "${CONFLUENCE_DOWNLOAD_URL}" | tar -xz --directory "${CONFLUENCE_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                           "${MYSQL_DRIVER_DOWNLOAD_URL}" | tar -xz --directory "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib" --strip-components=1 --no-same-owner "mysql-connector-java-${MYSQL_VERSION}/mysql-connector-java-${MYSQL_VERSION}-bin.jar" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/conf" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/temp" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/logs" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/work" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/conf" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/temp" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/logs" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/work" \
    && echo -e                            "\nconfluence.home=${CONFLUENCE_HOME}" >> "${CONFLUENCE_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties" \
    && xmlstarlet                         ed --inplace \
        --delete                          "Server/@debug" \
        --delete                          "Server/Service/Connector/@debug" \
        --delete                          "Server/Service/Connector/@useURIValidationHack" \
        --delete                          "Server/Service/Connector/@minProcessors" \
        --delete                          "Server/Service/Connector/@maxProcessors" \
        --delete                          "Server/Service/Engine/@debug" \
        --delete                          "Server/Service/Engine/Host/@debug" \
        --delete                          "Server/Service/Engine/Host/Context/@debug" \
                                          "${CONFLUENCE_INSTALL}/conf/server.xml" \
    && touch -d "@0"                      "${CONFLUENCE_INSTALL}/conf/server.xml" \
    && sed -i "s/-Xms[0-9]*m/-Xms$\{HEAP_START\}m/" "${CONFLUENCE_INSTALL}/bin/setenv.sh" \
    && sed -i "s/-Xmx[0-9]*m/-Xmx$\{HEAP_MAX\}m/" "${CONFLUENCE_INSTALL}/bin/setenv.sh"

# Create the start up script for Confluence
RUN echo '#!/bin/bash\n\
SERVER_XML="$CONFLUENCE_INSTALL/conf/server.xml"\n\
CURRENT_PROXY_NAME=`xmlstarlet sel -t -v "Server/Service/Connector[@port="8090"]/@proxyName" $SERVER_XML`\n\
if [ -w $SERVER_XML ]\n\
then\n\
  if [[ ! -z "$PROXY_NAME" ]] && [[ ! -z "$CURRENT_PROXY_NAME" ]]; then\n\
    xmlstarlet ed --inplace -u "Server/Service/Connector[@port='8090']/@proxyName" -v "$PROXY_NAME" -u "Server/Service/Connector[@port='8090']/@proxyPort" -v "$PROXY_PORT" -u "Server/Service/Connector[@port='8090']/@scheme" -v "$PROXY_SCHEME" $SERVER_XML\n\
  elif [ -z "$CURRENT_PROXY_NAME" ]; then\n\
    xmlstarlet ed --inplace -a "Server/Service/Connector[@port='8090']" -t attr -n scheme -v "$PROXY_SCHEME" -a "Server/Service/Connector[@port='8090']" -t attr -n proxyPort -v "$PROXY_PORT" -a "Server/Service/Connector[@port='8090']" -t attr -n proxyName -v "$PROXY_NAME" $SERVER_XML\n\
  else\n\
    xmlstarlet ed --inplace -d "Server/Service/Connector[@port='8090']/@scheme" -d "Server/Service/Connector[@port='8090']/@proxyName" -d "Server/Service/Connector[@port='8090']/@proxyPort" $SERVER_XML\n\
  fi\n\
fi\n\
'"${CONFLUENCE_INSTALL}"'/bin/catalina.sh run' > atlassian_app.sh

# Expose default HTTP connector port.
EXPOSE 8090 8091

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${CONFLUENCE_INSTALL}", "${CONFLUENCE_HOME}"]

# Set the default working directory as the Confluence installation directory.
WORKDIR ${CONFLUENCE_INSTALL}

# Copying the Dockerfile to the image as documentation
COPY Dockerfile /

# Run Atlassian Confluence as a foreground process by default.
CMD ["/usr/bin/start_atlassian_app.sh"]

