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
    rpmdevtools

RUN git clone https://github.com/creationix/nvm.git /tmp/.nvm
RUN source /tmp/.nvm/nvm.sh
RUN nvm install 4.4.7
RUN nvm use 4.4.7
RUN npm install -g npm --loglevel error

ADD . /atom
WORKDIR /atom
