# The tags that are recommended to be used for
# the base image are: latest, staging, stable
FROM docker.sunet.se/eduix/eduix-base:stable
MAINTAINER Jarkko Leponiemi "jarkko.leponiemi@eduix.fi"

# Setup useful environment variables
ENV CONFLUENCE_HOME     /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL  /opt/atlassian/confluence
ENV HEAP_START          2048
ENV HEAP_MAX            2048
ARG CONF_VERSION=6.13.4
ARG CONFLUENCE_SHA256_CHECKSUM=6af32eb3c616656f55f97f8063014a11183b8d6a9d049000275416524456ef9a

LABEL Description="This image is used to start Atlassian Confluence" Vendor="Atlassian" Version="${CONF_VERSION}"

ENV CONFLUENCE_DOWNLOAD_URL https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONF_VERSION}.tar.gz

ENV RUN_USER            atlassian
ENV RUN_GROUP           atlassian

# Copying the Dockerfile to the image as documentation
COPY Dockerfile /
COPY setup.sh /opt/sunet/setup.sh
RUN /opt/sunet/setup.sh

USER atlassian

# Expose default HTTP connector port.
EXPOSE 8090

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${CONFLUENCE_INSTALL}", "${CONFLUENCE_HOME}"]

# Set the default working directory as the Confluence installation directory.
WORKDIR ${CONFLUENCE_INSTALL}

# Run Atlassian Confluence as a foreground process by default.
CMD ["/opt/atlassian/atlassian_app.sh"]

