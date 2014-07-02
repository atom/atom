# Building Atom in Windows 8.1 using the msysgit shell

You can build atom on Windows 8.1 using a fully self-contained msysgit bash shell. That is, when installing msysgit, do not let it add commands to the system path, use the system cmd program, or anything that changes the default operation of the Windows system. Use all the default options to install msysgit.

## Install dependencies
Install the following programs that atom depends on:
* [msysgit][5] - Git for Windows
* [Python][2] 2.7.x (required by [node-gyp][3])
* [Node.js][1] v0.10.x
* [Visual Studio 2013 Express for Desktop][4]

## Temporarily add folders to the PATH environment variable
AFTER dependency installation, open up the msysgit shell (causing it to read the new PATH environment variable).
Temporarily add the following directories to the git shell's PATH variable:
*	/c/Program Files (x86)/Git/bin
*	/c/Program Files (x86)/Git/libexec/git-core
*	/c/Program Files/nodejs/node_modules/npm/bin/node-gyp-bin

To add them temporarily, type:
```
PATH=$PATH:/c/Program Files (x86)/Git/bin:/c/Program Files (x86)/Git/libexec/git-core:/c/Program Files/nodejs/node_modules/npm/bin/node-gyp-bin
export PATH
```

#### Notes:
* These paths may change depending on where you installed the packages on your own system.
* When combining the paths into a single string, ensure that you place a : between each path.
* If you close the git shell, the PATH will revert to the system's default PATH.

## Run the build script
After all the installs, move to the scripts directory and run build:
```
cd atom/scripts
./build
```

### !!!ATTENTION!!!
You might get syntax errors!
For some reason, the install script pulls a lot of libraries from npmjs.org as mentioned in the final few comments of https://github.com/atom/atom/issues/2580. If you get syntax errors, try rerunning the build script over and over until it magically works.

This seems to be an issue the team should solve by ensuring a proper download and caching of the necessary libraries, but it may currently cause problems.

[1]: http://nodejs.org/download/                "Node.js"
[2]: http://www.python.org/download/            "Python"
[3]: https://github.com/TooTallNate/node-gyp    "node-gyp"
[4]: http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_2 "Visual Studio Express 2013 for Desktop"
[5]: http://msysgit.github.io/                  "msysgit"