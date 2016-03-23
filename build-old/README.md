# Atom Build

This folder contains the grunt configuration and tasks to build Atom.

It was moved from the root of the repository so that any native modules used
would be compiled against node's v8 headers since anything stored in
`node_modules` at the root of the repo is compiled against atom's v8 headers.

New build dependencies should be added to the `package.json` file located in
this folder.
