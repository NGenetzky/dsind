# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
#
# https://github.com/phusion/baseimage-docker/releases
# ___________________________________________________________
# | Ubuntu LTS | Phusion | Notes from Phusion       |
# |------------|---------|--------------------------|
# |   18.04    |  0.11   | released on Aug 16, 2018 |
# |   16.04    | 0.9.22  | released on May 17, 2017 |
#
FROM phusion/baseimage:0.11

# Using "ARG" influences the behavior of apt only while building container.
# No Debian that's a bad Debian! We don't have an interactive prompt don't fail
ARG DEBIAN_FRONTEND=noninteractive

# We don't use phusion's "install_clean" because we want portability.
RUN apt-get --quiet --yes update \
    # We first install these packages, to avoid skipping package configuration
    && apt-get -y install --no-install-recommends \
        apt-utils \
        dialog \
    # Then we can proceed with our packages
    && apt-get -y install --no-install-recommends \
        # Basic tools
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        lsb-release \
        sudo \
        tmux \
        uuid-runtime \
        vim \
        zsh \
        #
        # Python packaging tools
        python3-pip \
        python3-setuptools \
        python3-wheel \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add apt repository from neuro debian
# "http://neuro.debian.net/lists/bionic.us-tn.full"
# Install ppa key for 'neurodebian' so that we can install the
# latest 'git-annex' (Ubuntu 18.04 only has 6.20180227-1).
# http://neuro.debian.net/install_pkg.html?p=git-annex-standalone
COPY .local/share/keyring/neuro.debian.net.asc /tmp/
RUN cat '/tmp/neuro.debian.net.asc' | apt-key add - \
    && curl \
        -o "/etc/apt/sources.list.d/neurodebian.sources.list" \
            "http://neuro.debian.net/lists/bionic.us-tn.full" \
    && apt-get --quiet --yes update \
    # Then we can proceed with our packages
    && apt-get -y install --no-install-recommends \
        # Basic tools
        # Install git-annex and datalad
        git-annex-standalone \
        datalad \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

################################################################################
# docker metadata
####

# docker-hub environment-variables
# https://docs.docker.com/docker-hub/builds/advanced/#environment-variables-for-building-and-testing
#
# SOURCE_BRANCH: the name of the branch or the tag that is currently being tested.
# SOURCE_COMMIT: the SHA1 hash of the commit being tested.
# COMMIT_MSG: the message from the commit being tested and built.
# DOCKER_REPO: the name of the Docker repository being built.
# DOCKERFILE_PATH: the dockerfile currently being built.
# DOCKER_TAG: the Docker repository tag being built.
# IMAGE_NAME: the name and tag of the Docker repository being built. (This variable is a combination of DOCKER_REPO:DOCKER_TAG.)
ARG SOURCE_BRANCH='unknown-branch'
ARG SOURCE_COMMIT='unknown-commit'
ARG DOCKER_REPO='ngenetzky/dsind'
ARG DOCKERFILE_PATH='Dockerfile'
ARG DOCKER_TAG='latest'
ARG IMAGE_NAME="${DOCKER_REPO}:${DOCKER_TAG}"

# Programatic Metadata
ARG BUILD_DATE='unknown-date'

# Hardcoded Metadata
ARG META_VCS_URL='https://github.com/ngenetzky/dsind/'
ARG META_SUMMARY='DSIND for Nathan Genetzky'
ARG META_MAINTAINER='Nathan Genetzky <nathan@genetzky.us>'

####
# docker metadata
################################################################################

RUN install -d '/etc/skel/.dsind' \
    && ( \
        printf 'T0="%s"\nUUID="%s"\nNAME="%s"\nINFO="%s"\n' \
            "$(date --iso-8601=d)" \
            "$(uuidgen -t)" \
            "$(hostname)" \
            "$(uname -a)" \
    ) > "/etc/skel/.dsind/host.toml" \
    && ( \
        printf 'T0="%s"\nUUID="%s"\nNAME="%s"\nVCS_URL="%s"\nVCS_REF="%s"\n' \
            "$(date --iso-8601=d)" \
            "$(uuidgen -t)" \
            "${IMAGE_NAME}" \
            "${META_VCS_URL}" \
            "${SOURCE_COMMIT}" \
    ) > "/etc/skel/.dsind/image.toml" \
    # Configure bash with sensible defaults.
    && curl -o '/usr/local/share/bash-sensible.bash' \
        "https://raw.githubusercontent.com/mrzool/bash-sensible/5a2269a6a12e2a1b10629bb223f2f3c27ac07050/sensible.bash" \
    && ( \
        printf 'f=%s && [[ -f $f ]] && source $f' \
            "'/usr/local/share/bash-sensible.bash'" \
    ) >> '/etc/skel/.bashrc'

# Build-time metadata as defined at http://label-schema.org
LABEL \
    maintainer="${META_MAINTAINER}" \
    summary="${META_SUMMARY}" \
    description="${META_SUMMARY}" \
    authors="${META_MAINTAINER}" \
    url="$META_VCS_URL" \
    \
    org.label-schema.build-date="$BUILD_DATE" \
    org.label-schema.name="$IMAGE_NAME" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.vcs-ref="$SOURCE_COMMIT" \
    org.label-schema.vcs-url="$META_VCS_URL" \
    org.label-schema.version="$SOURCE_COMMIT"
