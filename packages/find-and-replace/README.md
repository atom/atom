# Find and Replace package
[![OS X Build Status](https://travis-ci.org/atom/find-and-replace.svg?branch=master)](https://travis-ci.org/atom/find-and-replace) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/6w4baiiq5mw4nxky/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/find-and-replace/branch/master) [![Dependency Status](https://david-dm.org/atom/find-and-replace.svg)](https://david-dm.org/atom/find-and-replace)

Find and replace in the current buffer or across the entire project in Atom.

## Find in buffer

Using the shortcut <kbd>cmd-f</kbd> (Mac) or <kbd>ctrl-f</kbd> (Windows and Linux).
![screen shot 2013-11-26 at 12 25 22 pm](https://f.cloud.github.com/assets/69169/1625938/a859fa70-56d9-11e3-8b2a-ac37c5033159.png)

## Find in project

Using the shortcut <kbd>cmd-shift-f</kbd> (Mac) or <kbd>ctrl-shift-f</kbd> (Windows and Linux).
![screen shot 2013-11-26 at 12 26 02 pm](https://f.cloud.github.com/assets/69169/1625945/b216d7b8-56d9-11e3-8b14-6afc33467be9.png)

## Provided Service

If you need access the marker layer containing result markers for a given editor, use the `find-and-replace@0.0.1` service. The service exposes one method, `resultsMarkerLayerForTextEditor`, which takes a `TextEditor` and returns a `TextEditorMarkerLayer` that you can interact with. Keep in mind that any work you do in synchronous event handlers on this layer will impact the performance of find and replace.
