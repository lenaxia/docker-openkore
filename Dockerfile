# Build stage
FROM ubuntu:24.04 as build

# Install build-time dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libperl-dev \
    libtime-perl \
    zlib1g-dev \
    libreadline-dev \
    libncurses-dev \
    python2 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone the OpenKore repository and get the version
ARG OPENKORE_VERSION=master
RUN git clone --depth 1 --branch ${OPENKORE_VERSION} https://github.com/openkore/openkore.git /opt/openkore
WORKDIR /opt/openkore
RUN OPENKORE_VERSION=$(git describe --tags --always) && echo "OPENKORE_VERSION=$OPENKORE_VERSION" >> $GITHUB_ENV

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
    libtime-perl \
    zlib1g \
    libreadline8 \
    libncurses6 \
    python2 \
    curl \
    nano \
    dos2unix \
    default-mysql-client \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from the build stage
COPY --from=build /opt/openkore /opt/openkore

# Copy configuration files
COPY recvpackets.txt /opt/openkore/tables/
COPY servers.txt /opt/openkore/tables/
COPY docker-entrypoint.sh /usr/local/bin/
COPY config/acolyte.txt /opt/openkore/control/class/acolyte.txt
COPY config/archer.txt /opt/openkore/control/class/archer.txt
COPY config/knight.txt /opt/openkore/control/class/knight.txt
COPY config/mage.txt /opt/openkore/control/class/mage.txt
COPY config/monk.txt /opt/openkore/control/class/monk.txt
COPY config/priest.txt /opt/openkore/control/class/priest.txt
COPY config/sage.txt /opt/openkore/control/class/sage.txt
COPY config/swordman.txt /opt/openkore/control/class/swordman.txt
COPY config/wizard.txt /opt/openkore/control/class/wizard.txt

# Set environment variables for configuration
ENV OK_IP="" \
    OK_USERNAME="" \
    OK_PWD="" \
    OK_CHAR="1" \
    OK_USERNAMEMAXSUFFIX="" \
    OK_FOLLOW_USERNAME1="" \
    OK_FOLLOW_USERNAME2="" \
    OK_KILLSTEAL="0" \
    MYSQL_HOST="" \
    MYSQL_DB="" \
    MYSQL_USER="" \
    MYSQL_PWD=""

# Set the working directory
WORKDIR /opt/openkore

# Add a health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD perl -e 'exit 0'

# Set the entrypoint and command
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/opt/openkore/openkore.pl"]

# Switch to the non-root user
USER openkore
