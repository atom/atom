# VERSION:        0.1
# DESCRIPTION:    Create the atom editor in a container
# AUTHOR:         Jessica Frazelle <jessie@docker.com>
# COMMENTS:
#   This file describes how to build the atom editor
#   in a container with all dependencies installed.
#   Tested on Debian Jessie.
# USAGE:
#   # Download atom Dockerfile
#   wget https://raw.githubusercontent.com/atom/atom/master/Dockerfile
#
#   # Build atom image
#   docker build -t atom .
#
#   docker run -v /tmp/.X11-unix:/tmp/.X11-unix \
#     -e DISPLAY=unix$DISPLAY atom
#

DOCKER-VERSION 1.3

# Base docker image
FROM debian:jessie
MAINTAINER Jessica Frazelle <jessie@docker.com>

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    libasound2 \
    libgconf-2-4 \
    libgnome-keyring-dev \
    libgtk2.0-0 \
    libnss3 \
    libxtst6 \
    --no-install-recommends

# install node
RUN curl -sL https://deb.nodesource.com/setup | bash -
RUN apt-get install -y nodejs

# clone atom
RUN git clone https://github.com/atom/atom /src
WORKDIR /src
RUN git fetch && git checkout $(git describe --tags `git rev-list --tags --max-count=1`)
RUN script/build && script/grunt install

# Autorun atom
CMD /usr/local/bin/atom --foreground --log-file /var/log/atom.log && tail -f /var/log/atom.log
