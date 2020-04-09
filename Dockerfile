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

# Add apt repository from neuro debian
# "http://neuro.debian.net/lists/bionic.us-tn.full"
# Install ppa key for 'neurodebian' so that we can install the
# latest 'git-annex' (Ubuntu 18.04 only has 6.20180227-1).
# http://neuro.debian.net/install_pkg.html?p=git-annex-standalone
# WARNING: Building this layer can fail sporadically.
RUN curl \
        -o "/etc/apt/sources.list.d/neurodebian.sources.list" \
            "http://neuro.debian.net/lists/bionic.us-tn.full" \
    && apt-key adv --recv-keys \
        --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9

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
        vim \
        zsh \
        # Install git-annex and datalad
        git-annex-standalone \
        datalad \
        #
        # Python packaging tools
        python3-pip \
        python3-setuptools \
        python3-wheel \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure bash with sensible defaults.
RUN curl -o '/usr/local/share/bash-sensible.bash' \
        "https://raw.githubusercontent.com/mrzool/bash-sensible/5a2269a6a12e2a1b10629bb223f2f3c27ac07050/sensible.bash" \
    && echo "source '/usr/local/share/bash-sensible.bash'" >> '/etc/skel/.bashrc'

# Configuration for default non-root user.
ARG USER_NAME='user'
ARG USER_UID='1000'
ARG USER_GID="$USER_UID"
ARG USER_SHELL='/bin/bash'
# Create non-root user and give them sudo with nopasswd.
RUN printf "### Building image for user %s (%s:%s) ###" \
        "${USER_NAME}" \
        "${USER_UID}" \
        "${USER_GID}" \
    #
    # Create a non-root user.
    && groupadd --gid "$USER_GID" \
        "$USER_NAME" \
    && useradd --create-home --shell "${USER_SHELL}" \
        --uid "${USER_UID}" --gid "${USER_GID}" \
        "${USER_NAME}" \
    #
    # Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo "$USER_NAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME" \
    && chmod 0440 "/etc/sudoers.d/$USER_NAME" \
    #
    # Special steps for vscode remote-container support
    && install -d --mode 0755 --owner "${USER_UID}" --group "${USER_GID}" \
        '/workspace/' \
        '/workspaces/' \
        \
        "/home/$USER_NAME/.vscode-server" \
        "/home/$USER_NAME/.vscode-server/bin" \
        "/home/$USER_NAME/.vscode-server/extensions"

USER root

# Archive the home directory in case user want's to mount over it.
RUN tar -vcap \
    -f "/usr/share/home-${USER_NAME}.tar.xz" \
    -C "/home/${USER_NAME}" \
    ./

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
# TODO: BUILD_DATE
ARG BUILD_DATE='unknown-date'

# Hardcoded Metadata
ARG META_VCS_URL='https://github.com/ngenetzky/dsind/'
ARG META_SUMMARY='DSIND for Nathan Genetzky'
ARG META_MAINTAINER='Nathan Genetzky <nathan@genetzky.us>'

####
# docker metadata
################################################################################

USER root

RUN apt-get --quiet --yes update \
    && apt-get -y install --no-install-recommends \
        uuid-runtime \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER "${USER_NAME}"
WORKDIR "/home/${USER_NAME}/"

ARG DSIND_USER_NAME='Nathan Genetzky'
ARG DSIND_USER_EMAIL='nathan@genetzky.us'
RUN cd "/home/${USER_NAME}/" \
    && mkdir ".dsind/" \
    && ( \
        printf 'T0="%s"\nUUID="%s"\nNAME="%s"\nEMAIL="%s"' \
            "$(date --iso-8601=d)" \
            "$(uuidgen -t)" \
            "${DSIND_USER_NAME}" \
            "${DSIND_USER_EMAIL}" \
    ) > ".dsind/user.toml" \
    && git config --global user.name "${DSIND_USER_NAME}" \
    && git config --global user.email "${DSIND_USER_EMAIL}" \
    && datalad create \
        --force --no-annex \
        './' \
    && datalad save --message "dataset: New dataset for ${DSIND_USER_NAME}" \
        './'

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
