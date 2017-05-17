# Docker build instructions

You can build atom using the Dockerfile provided in the repository.

## Requirements

* Docker installed

## Building the docker image

Before building, the docker image must be built. The image is based on node:6 and installs the dependencies required for atom.

```
$ ~/atom: docker build -t atom:latest ./
```

This will build the image. It will be available later as `atom:latest`

## Building atom

Run the following command to run the atom build container with the image we just built. Note that you can provide arguments to `script/build` at the and as you wish.

```
$ ~/atom: docker run --rm --name atom-build --volume $(pwd):/atom --workdir /atom atom:latest script/build
```
