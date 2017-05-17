# VERSION:        0.2
# DESCRIPTION:    Image to build Atom

# Base docker image
FROM node:6

# Install dependencies
RUN apt-get update && \ 
	apt-get install -y build-essential \
		git \
		libsecret-1-dev \
		fakeroot \
		rpm \
		libx11-dev \
		libxkbfile-dev
