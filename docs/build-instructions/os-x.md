# OS X

## Requirements

  * OS X 10.8 or later
  * [node.js](http://nodejs.org/download/) (0.10.x or 0.12.x) or [io.js](https://iojs.org) (1.x)
  * Command Line Tools for [Xcode](https://developer.apple.com/xcode/downloads/) (run `xcode-select --install` to install)

## Instructions

  If you have problems with permissions don't forget to prefix with `sudo`

  1. Clone the Atom repository:

    ```sh
    git clone https://github.com/atom/atom
    cd atom
    ```

  2. Build Atom:

    ```sh
    script/build
    ```

    Creates application at /Applications/Atom.app.

### `script/build` Options
  * `--install-dir` - The full path to the final built application (must include `.app` in the path), e.g. `script/build --install-dir /Users/username/full/path/to/Atom.app`
  * `--build-dir` - Build the application in this directory.
  * `--verbose` - Verbose mode. A lot more information output.

## Troubleshooting

### OSX build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Aos-x&type=Issues) to get a list of reports about build errors on OSX.
