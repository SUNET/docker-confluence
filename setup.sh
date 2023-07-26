#!/bin/bash

set -e
set -x

export DEBIAN_FRONTEND noninteractive

# Update the image and install the needed tools
apt-get update && \
#    apt-get -y dist-upgrade && \
    apt-get install -y \
        ssl-cert\
    && apt-get -y autoremove \
    && apt-get autoclean

# Do some more cleanup to save space
rm -rf /var/lib/apt/lists/*

# Install Atlassian Confluence and helper tools and setup initial home
# directory structure.
mkdir -p                                  "${CONFLUENCE_HOME}" \
    && chmod -R 700                       "${CONFLUENCE_HOME}" \
    && chown ${RUN_USER}:${RUN_GROUP}     "${CONFLUENCE_HOME}" \
    && mkdir -p                           "${CONFLUENCE_INSTALL}/conf" \
    && curl -Ls                           "${CONFLUENCE_DOWNLOAD_URL}" \
            -o /opt/confluence.tar.gz
if [[ "${CONFLUENCE_SHA256_CHECKSUM}" != "$(sha256sum /opt/confluence.tar.gz | cut -d' ' -f1)" ]]; then
    echo "ERROR: SHA256 checksum of downloaded Confluence installation package does not match!"
    exit 1
fi
tar -xzf /opt/confluence.tar.gz --directory "${CONFLUENCE_INSTALL}" --strip-components=1 --no-same-owner \
    && rm -f /opt/confluence.tar.gz \
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
cat>/opt/atlassian/atlassian_app.sh<<'EOF'
#!/bin/bash
SERVER_XML="$CONFLUENCE_INSTALL/conf/server.xml"
CURRENT_PROXY_NAME=$(xmlstarlet sel -t -v "Server/Service/Connector[@port="8090"]/@proxyName" "${SERVER_XML}")
if [ -w "${SERVER_XML}" ]
then
  if [[ ! -z "${PROXY_NAME}" ]] && [[ ! -z "${CURRENT_PROXY_NAME}" ]]; then
    xmlstarlet ed --inplace -u "Server/Service/Connector[@port='8090']/@proxyName" -v "${PROXY_NAME}" -u "Server/Service/Connector[@port='8090']/@proxyPort" -v "${PROXY_PORT}" -u "Server/Service/Connector[@port='8090']/@scheme" -v "${PROXY_SCHEME}" "${SERVER_XML}"
  elif [ -z "${PROXY_NAME}" ]; then
    xmlstarlet ed --inplace -d "Server/Service/Connector[@port='8090']/@scheme" -d "Server/Service/Connector[@port='8090']/@proxyName" -d "Server/Service/Connector[@port='8090']/@proxyPort" "${SERVER_XML}"
  elif [ -z "${CURRENT_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace -a "Server/Service/Connector[@port='8090']" -t attr -n scheme -v "${PROXY_SCHEME}" -a "Server/Service/Connector[@port='8090']" -t attr -n proxyPort -v "${PROXY_PORT}" -a "Server/Service/Connector[@port='8090']" -t attr -n proxyName -v "${PROXY_NAME}" "${SERVER_XML}"
  fi
fi
"${CONFLUENCE_INSTALL}"/bin/catalina.sh run
EOF
chmod +x /opt/atlassian/atlassian_app.sh
