# Atom Build

This folder contains the grunt configuration and tasks to build Atom.

It was moved from the root of the repository so that native modules would be
compiled against node's v8 headers instead of Atom's v8 headers.

New build dependencies should be added to the `package.json` file located in
this folder.
