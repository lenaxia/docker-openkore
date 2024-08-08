# Build stage
FROM ubuntu:24.04 as build

# Install build-time dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libperl-dev \
    perl-modules \
    zlib1g-dev \
    libreadline-dev \
    libncurses-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install CA certificates
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

# Clone the OpenKore repository
ARG OPENKORE_VERSION=master
RUN git clone --depth 1 --branch ${OPENKORE_VERSION} https://github.com/openkore/openkore.git /opt/openkore
WORKDIR /opt/openkore

# Build OpenKore
RUN make

# Runtime stage
FROM ubuntu:24.04

# Create a non-root user
RUN useradd -ms /bin/bash openkore

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    perl \
    perl-modules \
    zlib1g \
    libreadline-dev \
    libncurses6 \
    libcurl4-openssl-dev \
    curl \
    nano \
    dos2unix \
    default-mysql-client \
    dnsutils \
    make \
    python3 \
    redis-tools \
    build-essential \ 
    libncurses-dev \ 
    vim \
    && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from the build stage
COPY --from=build /opt/openkore /opt/openkore

# Change ownership of /opt/openkore to the openkore user
RUN chown -R openkore:openkore /opt/openkore

# Copy configuration files
COPY recvpackets.txt /opt/openkore/tables/
COPY servers.txt /opt/openkore/tables/
COPY docker-entrypoint.sh /usr/local/bin/
COPY config/ /opt/openkore/control/class/
COPY plugins/ /opt/openkore/plugins

# Set environment variables for configuration
ENV OK_IP="" \
    OK_SERVER="" \
    OK_USERNAME="" \
    OK_PWD="" \
    OK_CHAR="0" \
    OK_USERNAMEMAXSUFFIX="" \
    OK_FOLLOW_USERNAME1="" \
    OK_FOLLOW_USERNAME2="" \
    OK_KILLSTEAL="0" \
    MYSQL_HOST="" \
    MYSQL_DB="" \
    MYSQL_USER="" \
    MYSQL_PWD=""

# Set TERM env var to suppress an openkore error in docker
ENV TERM=xterm

# Create a symlink for python to point to python3
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set the working directory
WORKDIR /opt/openkore

COPY init-openkore.sh /opt/openkore/

RUN sed 's/^master.*/master localHost - rA\/Herc/' /opt/openkore/control/config.txt && \
    chmod +x /opt/openkore/init-openkore.sh && \
    /opt/openkore/init-openkore.sh

# Add a health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD perl -e 'exit 0'

# Set the entrypoint and command
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/opt/openkore/openkore.pl"]

# Switch to the non-root user
USER openkore
