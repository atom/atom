# VERSION:        0.1
# DESCRIPTION:    Image to build Atom and create a .rpm file

# Base docker image
FROM fedora:21

RUN curl --silent --location https://rpm.nodesource.com/setup_4.x | bash -

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

RUN npm install -g npm --loglevel error

ADD . /atom
WORKDIR /atom
