const { spawn } = require("child_process")

module.exports = class RipgrepDirectorySearcher {
  constructor() {
    this.rgPath = require('vscode-ripgrep').rgPath
  }

  canSearchDirectory () {
    return true
  }

  // Performs a text search for files in the specified `Directory`s, subject to the
  // specified parameters.
  //
  // Results are streamed back to the caller by invoking methods on the specified `options`,
  // such as `didMatch` and `didError`.
  //
  // * `directories` {Array} of {Directory} objects to search, all of which have been accepted by
  // this searcher's `canSearchDirectory()` predicate.
  // * `regex` {RegExp} to search with.
  // * `options` {Object} with the following properties:
  //   * `didMatch` {Function} call with a search result structured as follows:
  //     * `searchResult` {Object} with the following keys:
  //       * `filePath` {String} absolute path to the matching file.
  //       * `matches` {Array} with object elements with the following keys:
  //         * `lineText` {String} The full text of the matching line (without a line terminator character).
  //         * `lineTextOffset` {Number} Always 0, present for backwards compatibility
  //         * `matchText` {String} The text that matched the `regex` used for the search.
  //         * `range` {Range} Identifies the matching region in the file. (Likely as an array of numeric arrays.)
  //   * `didError` {Function} call with an Error if there is a problem during the search.
  //   * `didSearchPaths` {Function} periodically call with the number of paths searched thus far.
  //   * `inclusions` {Array} of glob patterns (as strings) to search within. Note that this
  //   array may be empty, indicating that all files should be searched.
  //
  //   Each item in the array is a file/directory pattern, e.g., `src` to search in the "src"
  //   directory or `*.js` to search all JavaScript files. In practice, this often comes from the
  //   comma-delimited list of patterns in the bottom text input of the ProjectFindView dialog.
  //   * `ignoreHidden` {boolean} whether to ignore hidden files.
  //   * `excludeVcsIgnores` {boolean} whether to exclude VCS ignored paths.
  //   * `exclusions` {Array} similar to inclusions
  //   * `follow` {boolean} whether symlinks should be followed.
  //
  // Returns a *thenable* `DirectorySearch` that includes a `cancel()` method. If `cancel()` is
  // invoked before the `DirectorySearch` is determined, it will resolve the `DirectorySearch`.
  search (directories, regexp, options) {
    const paths = directories.map(d => d.getPath())

    const args = ["--json", "--regexp", regexp.source]
    if (options.leadingContextLineCount) {
      args.push("--before-context", options.leadingContextLineCount)
    }
    if (options.trailingContextLineCount) {
      args.push("--after-context", options.trailingContextLineCount)
    }
    args.push(...paths)

    console.log(args)

    const child = spawn(this.rgPath, args, {
      stdio: ['pipe', 'pipe', 'inherit']
    })

    const didMatch = options.didMatch || (() => {})

    return new Promise(resolve => {
      let buffer = ''
      let pendingEvent
      child.stdout.on('data', chunk => {
        buffer += chunk;
        const lines = buffer.split('\n')
        buffer = lines.pop()
        for (const line of lines) {
          const message = JSON.parse(line)
          console.log(message);

          if (message.type === 'begin') {
            pendingEvent = {
              filePath: message.data.path.text,
              matches: []
            }
          } else if (message.type === 'match') {
            const startRow = message.data.line_number - 1
            for (const submatch of message.data.submatches) {
              pendingEvent.matches.push({
                matchText: submatch.match.text,
                lineText: message.data.lines.text,
                lineTextOffset: 0,
                range: [[startRow, submatch.start], [startRow, submatch.end]],
                leadingContextLines: [],
                trailingContextLines: []
              })
            }
          } else if (message.type === 'end') {
            console.log('yielding', pendingEvent)
            didMatch(pendingEvent)
            pendingEvent = null
          } else if (message.type === 'summary') {
            resolve()
          }
        }
      })

    })
  }

}
