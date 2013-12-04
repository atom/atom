## Building Atom

These guide is meant only for users who wish to help develop atom core,
if you're just interested in using atom you should just [download
atom][download].

## OSX

* Use OS X 10.8 or later
* Install the latest node 0.10.x release (32bit preferable)
* Clone [atom][atom-git] to `~/github/atom`
* Run `~/github/atom/script/build`

## Windows

* Install [Visual C++ 2010 Express][win-vs2010]
* Install the [latest 32bit Node 0.10.x][win-node]
* Install the [latest Python 2.7.x][win-python]
* Install [GitHub for Windows][win-github]
* Clone [atom/atom][atom-git] to `C:\Users\<user>\github\atom\`
* Add `C:\Python27;C:\Program Files\nodejs;C:\Users\<user>\github\atom\node_modules\`
  to your PATH
* Set ATOM_ACCESS_TOKEN to your oauth2 credentials (run `security -q
  find-generic-password -ws 'GitHub API Token'` on OSX to get your
  credentials).
* Use the Windows GitHub shell and cd into `C:\Users\<user>\github\atom`
* Run `script\bootstrap`

[download]: https://github.com/atom/atom/releases/latest
[win-node]: http://nodejs.org/download/
[win-python]: http://www.python.org/download/
[win-github]: http://windows.github.com/
[win-vs2010]: http://www.microsoft.com/visualstudio/eng/products/visual-studio-2010-express
[atom-git]: https://github.com/atom/atom/
