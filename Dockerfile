
# References
# https://medium.com/@tonistiigi/advanced-multi-stage-build-patterns-6f741b852fae


##################################################################################
##################################################################################
# FROM phusion/baseimage:0.11 as phusion-datalad_0.11-r0.0
#
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
#########
#########

FROM phusion/baseimage:0.11 as phusion-datalad_0.11-r0.0

################################################################################
# System Setup for dsind
####

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
        # apt packages for base
        bash \
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

ARG PYTHON_REQUIREMENTS_TXT='datalad==0.12.5'
RUN cd '/root/' \
    # Install python dependencies
    && ( \
        printf '# date="%s"\n# uuid="%s"\n# path="%s"\n' \
            "$(date --iso-8601=d)" \
            "$(uuidgen -t)" \
            '/etc/python3/requirements.txt' \
        && echo "${PYTHON_REQUIREMENTS_TXT}"  \
    ) | tee '/etc/python3/requirements.txt' \
    && pip3 install \
        --no-cache-dir \
        --requirement '/etc/python3/requirements.txt'

# NOTE: We knowingly violate the convention of system GID being below 1000.
# NOTE: We use '37463' because it spells out 'dsind' on keypad.
RUN groupadd dsind --system --gid '37463' \
    && install --directory \
        --mode '775' \
        --group 'dsind' \
        '/var/lib/dsind/by-domain/' \
        '/var/lib/dsind/by-id/' \
        '/var/lib/dsind/by-uuid/' \
        '/var/lib/dsind/template/' \
    && ( \
        git init '/var/lib/dsind/by-id/0/' \
        && cd '/var/lib/dsind/by-id/0/' \
        && git remote add 'github.com/dsind/id-0' 'https://github.com/dsind/id-0.git' \
        && git fetch 'github.com/dsind/id-0' \
        && git reset --hard '692128780d4474abdcd1bdb7bde8370ba5e0c8d7' \
        && git branch 'by-id/0' \
    ) \
    && ( \
        git init --shared='world' '/var/lib/dsind/by-id/1/' \
        && cd '/var/lib/dsind/by-id/1/' \
        && git remote add 'origin' '/var/lib/dsind/by-id/0/' \
        && git remote add 'github.com/dsind/id-0' 'https://github.com/dsind/id-0.git' \
        && git fetch 'origin' \
        && git reset --hard '692128780d4474abdcd1bdb7bde8370ba5e0c8d7' \
        && git branch 'by-id/0' \
        && git branch 'by-id/1' \
    ) \
    && ( \
        cd '/var/lib/dsind/template/' \
        && git init \
        && git remote add 'github.com/dsind/id-0' 'https://github.com/dsind/id-0.git' \
        && git remote add 'local/dsind/id-0' '/var/lib/dsind/by-id/0/' \
        && git remote add 'local/dsind/id-1' '/var/lib/dsind/by-id/1/' \
        && git remote add 'origin' '/var/lib/dsind/by-id/1/' \
        && git fetch origin \
        && git merge 'origin/master' \
        \
        # We will use this template for the start of the user dsind.
        && cp -T -R '/var/lib/dsind/template/' '/etc/skel/.dsind/' \
    ) \
    # This is the quickest way to easily have all of these files owned by dsind group.
    && chgrp dsind -R '/var/lib/dsind/'


RUN cd '/etc/skel/' \
    && date --iso-8601=d > '.dsind/.date.txt' \
    && uuidgen -t > '.dsind/.uuid.txt' \
    && cat '.dsind/.uuid.txt' >> '.dsind/.uuid.log' \
    \
    # Create new dsind host
    && printf 'date="%s"\nuuid="%s"\nname="%s"\ninfo="%s"\n' \
        "$(cat .dsind/.date.txt)" \
        "$(cat .dsind/.uuid.txt)" \
        "$(hostname)" \
        "$(uname -a)" \
        > '.dsind/.host.toml' \
    \
    # Configure bash with sensible defaults.
    && curl -o '/usr/local/share/bash-sensible.bash' \
        "https://raw.githubusercontent.com/mrzool/bash-sensible/5a2269a6a12e2a1b10629bb223f2f3c27ac07050/sensible.bash" \
    && ( \
        printf 'f=%s && [[ -f $f ]] && source $f' \
            "'/usr/local/share/bash-sensible.bash'" \
    ) >> '/etc/skel/.bashrc'

####
# System Setup for dsind
################################################################################


################################################################################
# USER root # dsind.github.io+dsind_root@gmail.com
####

RUN cd '/root/' \
    # Start with the same '/etc/skel' as other user.
    && cp -T -R '/etc/skel/' './' \
    && date --iso-8601=d > '.dsind/.date.txt' \
    \
    # Create new dsind root
    ## UUID: new dsind root
    && uuidgen -t > '.dsind/.uuid.txt' \
    && cat '.dsind/.uuid.txt' >> '.dsind/.uuid.log' \
    && printf 'date="%s"\nuuid="%s"\nname="%s"\nemail="%s"\n' \
        "$(cat .dsind/.date.txt)" \
        "$(cat .dsind/.uuid.txt)" \
        "root dsind.github.io" \
        "dsind.github.io+dsind_root_$(cat .dsind/.date.txt)_$(cat .dsind/.uuid.txt)@gmail.com" \
        > '.dsind/.user.toml' \
    # Configure git user from dsind user
    && ( \
        . '.dsind/.user.toml' \
        && git config --global user.name "${name}" \
        && git config --global user.email "${email}" \
    ) \
    # Create the base dataset for this host.
    && ( \
        cd '.dsind/' \
        # UUID: from 'new dsind root' above
        && git checkout -b "by-uuid/$(cat .uuid.txt)" \
        && datalad create --force --no-annex './' \
        && datalad save ./ \
        \
        # UUID: new dsind host (may be duplicate of UUID from '/etc/skel/')
        # NOTE: Redo 'new dsind host' in case cache was used for previous layer.
        && datalad run "uuidgen -t > .uuid.txt ; cat .uuid.txt >> .uuid.log" \
        # Create new dsind host
        && printf 'date="%s"\nuuid="%s"\nname="%s"\ninfo="%s"\n' \
            "$(cat .date.txt)" \
            "$(cat .uuid.txt)" \
            "$(hostname)" \
            "$(uname -a)" \
            > '.host.toml' \
        && datalad save ./ \
        # UUID: 'logout dsind session'
        && datalad run "uuidgen -t > .uuid.txt ; cat .uuid.txt >> .uuid.log" \
        && git push 'local/dsind/id-1' \
    )

####
# USER root # dsind.github.io+dsind_root@gmail.com
################################################################################


################################################################################
# docker args for metadata
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
# docker args for metadata
################################################################################


################################################################################
# docker metadata

USER root
WORKDIR /root/

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

####
# docker metadata
################################################################################


#########
#########
# FROM phusion/baseimage:0.11 as phusion-datalad_0.11-r0.0
##################################################################################
##################################################################################


##################################################################################
##################################################################################
# FROM phusion-datalad_0.11-r0.0 as phusion-datalad_0.11-r0.1
#########
#########

# FROM locally build image:
FROM phusion-datalad_0.11-r0.0 as phusion-datalad_0.11-r0.1

# FROM cached image:
# FROM ngenetzky/dsind-host-phusion:latest as phusion-datalad_0.11-r0.1
# FROM ngenetzky/dsind-host-phusion:build as phusion-datalad_0.11-r0.1

################################################################################
# git-annex
####

# TODO: Provide git-annex without depending on 'neuro.debian.net'
# # Add apt repository from neuro debian
# # "http://neuro.debian.net/lists/bionic.us-tn.full"
# # Install ppa key for 'neurodebian' so that we can install the
# # latest 'git-annex' (Ubuntu 18.04 only has 6.20180227-1).
# # http://neuro.debian.net/install_pkg.html?p=git-annex-standalone
COPY .local/share/keyring/neuro.debian.net.asc /tmp/
RUN cat '/tmp/neuro.debian.net.asc' | apt-key add - \
    && curl \
        -o "/etc/apt/sources.list.d/neurodebian.sources.list" \
            "http://neuro.debian.net/lists/bionic.us-tn.full" \
    && apt-get --quiet --yes update \
    # Then we can proceed with our packages
    && apt-get -y install --no-install-recommends \
        # Install git-annex (install datalad from pip)
        git-annex-standalone \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

####
# git-annex
################################################################################

#########
#########
# FROM phusion-datalad_0.11-r0.0 as phusion-datalad_0.11-r0.1
##################################################################################
##################################################################################

##################################################################################
##################################################################################
# FROM PN_PV-PR as dsind
#
# Default stage. Use this to easily change the stage built by docker build.
# Any "WIP" sort of work should be done under this.
#########
#########

## FROM locally build image:
# FROM phusion-datalad_0.11-r0.0 as dsind
FROM phusion-datalad_0.11-r0.1 as dsind

## FROM cached image:
# FROM ngenetzky/dsind-host-phusion:latest as dsind
# FROM ngenetzky/dsind-host-phusion:build as dsind

################################################################################
# USER user # dsind.github.io+dsind_user@gmail.com
####

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
        # NOTE: Added to special group for 'dsind'
        --groups 'dsind' \
        "${USER_NAME}" \
    #
    # Add sudo support for the non-root user
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

USER "${USER_NAME}"
WORKDIR "/home/${USER_NAME}"

RUN cd "/home/${USER_NAME}" \
    # Start with the same '/etc/skel' as other user.
    && date --iso-8601=d > '.dsind/.date.txt' \
    \
    # Create new dsind user
    ## UUID: new dsind user
    && uuidgen -t > '.dsind/.uuid.txt' \
    && cat '.dsind/.uuid.txt' >> '.dsind/.uuid.log' \
    && printf 'date="%s"\nuuid="%s"\nname="%s"\nemail="%s"\n' \
        "$(cat .dsind/.date.txt)" \
        "$(cat .dsind/.uuid.txt)" \
        "user dsind.github.io" \
        "dsind.github.io+dsind_user_$(cat .dsind/.date.txt)_$(cat .dsind/.uuid.txt)@gmail.com" \
        > '.dsind/.user.toml' \
    # Configure git user from dsind user
    && ( \
        . '.dsind/.user.toml' \
        && git config --global user.name "${name}" \
        && git config --global user.email "${email}" \
    ) \
    # Create the base dataset for this host.
    && ( \
        cd '.dsind/' \
        # UUID: from 'new dsind user' above
        && git checkout -b "by-uuid/$(cat .uuid.txt)" \
        && datalad create --force --no-annex './' \
        && datalad save ./ \
        \
        # UUID: new dsind host (may be duplicate of UUID from '/etc/skel/')
        # NOTE: Redo 'new dsind host' in case cache was used for previous layer.
        && datalad run "uuidgen -t > .uuid.txt ; cat .uuid.txt >> .uuid.log" \
        # Create new dsind host
        && printf 'date="%s"\nuuid="%s"\nname="%s"\ninfo="%s"\n' \
            "$(cat .date.txt)" \
            "$(cat .uuid.txt)" \
            "$(hostname)" \
            "$(uname -a)" \
            > '.host.toml' \
        && datalad save ./ \
        # UUID: 'logout dsind session'
        && datalad run "uuidgen -t > .uuid.txt ; cat .uuid.txt >> .uuid.log" \
        && git push 'local/dsind/id-1' \
    )

####
# USER user # dsind.github.io+dsind_user@gmail.com
################################################################################

################################################################################
# WIP
####

COPY .config/datalad/procedures /home/user/.dsind/.config/datalad/procedures
RUN cd '/home/user/.dsind/' \
    && datalad save ./ \
    && printf "%80s\n" ' ' | tr ' ' '-' \
    && ( \
        install -d '/home/user/.config/datalad/procedures/' \
        && install -m 600 -t '/home/user/.config/datalad/procedures/' \
            '.config/datalad/procedures/cfg_dsind.py' \
        && datalad run-procedure --discover \
        && datalad run-procedure cfg_dsind \
    ) && printf "%80s\n" ' ' | tr ' ' '-'


####
# WIP
################################################################################

# NOTE: Phusion expects to run as root for it's entrypoint.
USER root
WORKDIR /root/

#########
#########
# FROM PN_PV-PR as dsind
##################################################################################
##################################################################################
