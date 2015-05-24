# VERSION:        0.1
# DESCRIPTION:    Image to build Atom and create a .rpm file

# Base docker image
FROM fedora:21

# Install dependencies
RUN yum install -y \
    make \
    gcc \
    gcc-c++ \
    glibc-devel \
    git-core \
    libgnome-keyring-devel \
    rpmdevtools \
    nodejs \
    npm

RUN npm install -g npm@1.4.28 --loglevel error

ADD . /atom
WORKDIR /atom
