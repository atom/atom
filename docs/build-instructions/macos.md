# macOS

## Requirements

  * macOS 10.8 or later
  * Node.js 4.4.x or later (we recommend installing it via [nvm](https://github.com/creationix/nvm))
  * npm 3.10.x or later (run `npm install -g npm`)
  * Command Line Tools for [Xcode](https://developer.apple.com/xcode/downloads/) (run `xcode-select --install` to install)

## Instructions

```sh
git clone https://github.com/atom/atom.git
cd atom
script/bootstrap
script/build
```

To also install the newly built application, use `script/build --install`.

### `script/build` Options

* `--code-sign`: signs the application with the GitHub certificate specified in `$ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL`.
* `--compress-artifacts`: zips the generated application as `out/atom-mac.zip`.
* `--install`: installs the application at `/Applications/Atom.app`.

## Troubleshooting

### macOS build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Aos-x&type=Issues) to get a list of reports about build errors on macOS.
