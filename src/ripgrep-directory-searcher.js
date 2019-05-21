const { spawn } = require('child_process')
const path = require('path')

// `ripgrep` and `scandal` have a different way of handling the trailing and leading
// context lines:
//  * `scandal` returns all the context lines that are requested, even if they include
//    previous or future results.
//  * `ripgrep` is a bit smarter and only returns the context lines that do not correspond
//    to any result (in a similar way that is shown in the find and replace UI).
//
// For example, if we have the following file and we request to leading context lines:
//
//    line 1
//    line 2
//    result 1
//    result 2
//    line 3
//    line 4
//
// `scandal` will return two results:
//   * First result with `['line 1', line 2']` as leading context.
//   * Second result with `['line 2', result 1']` as leading context.
// `ripgrep` on the other hand will return a JS object that is more similar to the way that
// the results are shown:
//   [
//     {type: 'begin', ...},
//     {type: 'context', ...}, // context for line 1
//     {type: 'context', ...}, // context for line 2
//     {type: 'match', ...}, // result 1
//     {type: 'match', ...}, // result 2
//     {type: 'end', ...},
//   ]
//
// In order to keep backwards compatibility, and avoid doing changes to the find and replace logic,
// for `ripgrep` we need to keep some state with the context lines (and matches) to be able to build
// a data structure that has the same behaviour as the `scandal` one.
//
// We use the `pendingLeadingContext` array to generate the leading context. This array gets mutated
// to always contain the leading `n` lines and is cloned every time a match is found. It's currently
// implemented as a standard array but we can easily change it to use a linked list if we find that
// the shift operations are slow.
//
// We use the `pendingTrailingContexts` Set to generate the trailing context. Since the trailing
// context needs to be generated after receiving a match, we keep all trailing context arrays that
// haven't been fulfilled in this Set, and mutate them adding new lines until they are fulfilled.

function updateLeadingContext (message, pendingLeadingContext, options) {
  if (message.type !== 'match' && message.type !== 'context') {
    return
  }

  if (options.leadingContextLineCount) {
    pendingLeadingContext.push(cleanResultLine(message.data.lines.text))

    if (pendingLeadingContext.length > options.leadingContextLineCount) {
      pendingLeadingContext.shift()
    }
  }
}

function updateTrailingContexts (message, pendingTrailingContexts, options) {
  if (message.type !== 'match' && message.type !== 'context') {
    return
  }

  if (options.trailingContextLineCount) {
    for (const trailingContextLines of pendingTrailingContexts) {
      trailingContextLines.push(cleanResultLine(message.data.lines.text))

      if (trailingContextLines.length === options.trailingContextLineCount) {
        pendingTrailingContexts.delete(trailingContextLines)
      }
    }
  }
}

function cleanResultLine (resultLine) {
  return resultLine[resultLine.length - 1] === '\n' ? resultLine.slice(0, -1) : resultLine
}

module.exports = class RipgrepDirectorySearcher {
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
  //   * `didSearchPaths` {Function} periodically call with the number of paths searched that contain results thus far.
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
    const numPathsFound = { num: 0 }

    const allPromises = directories.map(
      directory => this.searchInDirectory(directory, regexp, options, numPathsFound)
    )

    const promise = Promise.all(allPromises)

    promise.cancel = () => {
      for (const promise of allPromises) {
        promise.cancel()
      }
    }

    return promise
  }

  searchInDirectory (directory, regexp, options, numPathsFound) {
    let regexpStr = regexp.source

    // ripgrep handles `--` as the arguments separator, so we need to escape it if the
    // user searches for that exact same string.
    if (regexpStr === '--') {
      regexpStr = '\\-\\-'
    }

    // Delay the require of vscode-ripgrep to not mess with the snapshot creation.
    if (!this.rgPath) {
      this.rgPath = require('vscode-ripgrep').rgPath.replace(/\bapp\.asar\b/, 'app.asar.unpacked')
    }

    const directoryPath = directory.getPath()

    const args = ['--hidden', '--json', '--regexp', regexpStr]
    if (options.leadingContextLineCount) {
      args.push('--before-context', options.leadingContextLineCount)
    }
    if (options.trailingContextLineCount) {
      args.push('--after-context', options.trailingContextLineCount)
    }
    if (regexp.ignoreCase) {
      args.push('--ignore-case')
    }
    for (const inclusion of this.prepareGlobs(options.inclusions, directoryPath)) {
      args.push('--glob', inclusion)
    }
    for (const exclusion of this.prepareGlobs(options.exclusions, directoryPath)) {
      args.push('--glob', '!' + exclusion)
    }

    args.push(directoryPath)

    const child = spawn(this.rgPath, args, {
      cwd: directory.getPath(),
      stdio: ['pipe', 'pipe', 'pipe']
    })

    const didMatch = options.didMatch || (() => {})
    let cancelled = false

    const returnedPromise = new Promise((resolve, reject) => {
      let buffer = ''
      let bufferError = ''
      let pendingEvent
      let pendingLeadingContext
      let pendingTrailingContexts

      child.on('close', (code, signal) => {
        // code 1 is used when no results are found.
        if (code !== null && code > 1) {
          reject(new Error(bufferError))
        } else {
          resolve()
        }
      })

      child.stderr.on('data', chunk => {
        bufferError += chunk
      })

      child.stdout.on('data', chunk => {
        if (cancelled) {
          return
        }

        buffer += chunk
        const lines = buffer.split('\n')
        buffer = lines.pop()
        for (const line of lines) {
          const message = JSON.parse(line)

          updateTrailingContexts(message, pendingTrailingContexts, options)

          if (message.type === 'begin') {
            pendingEvent = {
              filePath: message.data.path.text,
              matches: []
            }
            pendingLeadingContext = []
            pendingTrailingContexts = new Set()
          } else if (message.type === 'match') {
            const startRow = message.data.line_number - 1
            const trailingContextLines = []
            pendingTrailingContexts.add(trailingContextLines)

            for (const submatch of message.data.submatches) {
              pendingEvent.matches.push({
                matchText: submatch.match.text,
                lineText: cleanResultLine(message.data.lines.text),
                lineTextOffset: 0,
                range: [[startRow, submatch.start], [startRow, submatch.end]],
                leadingContextLines: [...pendingLeadingContext],
                trailingContextLines
              })
            }
          } else if (message.type === 'end') {
            options.didSearchPaths(++numPathsFound.num)
            didMatch(pendingEvent)
            pendingEvent = null
          }

          updateLeadingContext(message, pendingLeadingContext, options)
        }
      })
    })

    returnedPromise.cancel = () => {
      child.kill()
      cancelled = true
    }

    return returnedPromise
  }

  // We need to prepare the "globs" that we receive from the user to make their behaviour more
  // user-friendly (e.g when adding `src/` the user probably means `src/**/*`).
  // This helper function takes care of that.
  prepareGlobs (globs, projectRootPath) {
    const output = []

    for (let pattern of globs) {
      if (pattern.length === 0) {
        continue
      }

      const projectName = path.basename(projectRootPath)

      // The user can just search inside one of the opened projects. When we detect
      // this scenario we just consider the glob to include every file.
      if (pattern === projectName) {
        output.push('**/*')
        continue
      }

      if (pattern.startsWith(projectName + '/')) {
        pattern = pattern.slice(projectName.length + 1)
      }

      if (pattern.endsWith('/')) {
        pattern = pattern.slice(0, -1)
      }

      pattern = pattern.startsWith('**/') ? pattern : `**/${pattern}`

      output.push(pattern)
      output.push(pattern.endsWith('/**') ? pattern : `${pattern}/**`)
    }

    return output
  }
}
