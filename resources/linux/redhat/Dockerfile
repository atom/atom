# VERSION:        0.1
# DESCRIPTION:    Create a .rpm file for the atom editor

# Base docker image
FROM fedora:20

# Install dependencies
RUN yum install -y \
    make \
    gcc \
    gcc-c++ \
    glibc-devel \
    git-core \
    libgnome-keyring-devel \
    rpmdevtools

# Install node
RUN curl -sL https://rpm.nodesource.com/setup | bash -
RUN yum install -y nodejs

# Clone atom
RUN git clone https://github.com/atom/atom /src
WORKDIR /src
RUN git reset -q --hard $JANKY_SHA1

# Build the RPM
RUN script/build && script/grunt mkrpm
