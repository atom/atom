const { spawn } = require('child_process');
const path = require('path');

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

function updateLeadingContext(message, pendingLeadingContext, options) {
  if (message.type !== 'match' && message.type !== 'context') {
    return;
  }

  if (options.leadingContextLineCount) {
    pendingLeadingContext.push(cleanResultLine(message.data.lines));

    if (pendingLeadingContext.length > options.leadingContextLineCount) {
      pendingLeadingContext.shift();
    }
  }
}

function updateTrailingContexts(message, pendingTrailingContexts, options) {
  if (message.type !== 'match' && message.type !== 'context') {
    return;
  }

  if (options.trailingContextLineCount) {
    for (const trailingContextLines of pendingTrailingContexts) {
      trailingContextLines.push(cleanResultLine(message.data.lines));

      if (trailingContextLines.length === options.trailingContextLineCount) {
        pendingTrailingContexts.delete(trailingContextLines);
      }
    }
  }
}

function cleanResultLine(resultLine) {
  resultLine = getText(resultLine);

  return resultLine[resultLine.length - 1] === '\n'
    ? resultLine.slice(0, -1)
    : resultLine;
}

function getPositionFromColumn(lines, column) {
  let currentLength = 0;
  let currentLine = 0;
  let previousLength = 0;

  while (column >= currentLength) {
    previousLength = currentLength;
    currentLength += lines[currentLine].length + 1;
    currentLine++;
  }

  return [currentLine - 1, column - previousLength];
}

function processUnicodeMatch(match) {
  const text = getText(match.lines);

  if (text.length === Buffer.byteLength(text)) {
    // fast codepath for lines that only contain characters of 1 byte length.
    return;
  }

  let remainingBuffer = Buffer.from(text);
  let currentLength = 0;
  let previousPosition = 0;

  function convertPosition(position) {
    const currentBuffer = remainingBuffer.slice(0, position - previousPosition);
    currentLength = currentBuffer.toString().length + currentLength;
    remainingBuffer = remainingBuffer.slice(position);

    previousPosition = position;

    return currentLength;
  }

  // Iterate over all the submatches to find the convert the start and end values
  // (which come as bytes from ripgrep) to character positions.
  // We can do this because submatches come ordered by position.
  for (const submatch of match.submatches) {
    submatch.start = convertPosition(submatch.start);
    submatch.end = convertPosition(submatch.end);
  }
}

// This function processes a ripgrep submatch to create the correct
// range. This is mostly needed for multi-line results, since the range
// will have different start and end rows and we need to calculate these
// based on the lines that ripgrep returns.
function processSubmatch(submatch, lineText, offsetRow) {
  const lineParts = lineText.split('\n');

  const start = getPositionFromColumn(lineParts, submatch.start);
  const end = getPositionFromColumn(lineParts, submatch.end);

  // Make sure that the lineText string only contains lines that are
  // relevant to this submatch. This means getting rid of lines above
  // the start row and below the end row.
  for (let i = start[0]; i > 0; i--) {
    lineParts.shift();
  }
  while (end[0] < lineParts.length - 1) {
    lineParts.pop();
  }

  start[0] += offsetRow;
  end[0] += offsetRow;

  return {
    range: [start, end],
    lineText: cleanResultLine({ text: lineParts.join('\n') })
  };
}

function getText(input) {
  return 'text' in input
    ? input.text
    : Buffer.from(input.bytes, 'base64').toString();
}

module.exports = class RipgrepDirectorySearcher {
  canSearchDirectory() {
    return true;
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
  //   * `includeHidden` {boolean} whether to ignore hidden files.
  //   * `excludeVcsIgnores` {boolean} whether to exclude VCS ignored paths.
  //   * `exclusions` {Array} similar to inclusions
  //   * `follow` {boolean} whether symlinks should be followed.
  //
  // Returns a *thenable* `DirectorySearch` that includes a `cancel()` method. If `cancel()` is
  // invoked before the `DirectorySearch` is determined, it will resolve the `DirectorySearch`.
  search(directories, regexp, options) {
    const numPathsFound = { num: 0 };

    const allPromises = directories.map(directory =>
      this.searchInDirectory(directory, regexp, options, numPathsFound)
    );

    const promise = Promise.all(allPromises);

    promise.cancel = () => {
      for (const promise of allPromises) {
        promise.cancel();
      }
    };

    return promise;
  }

  searchInDirectory(directory, regexp, options, numPathsFound) {
    // Delay the require of vscode-ripgrep to not mess with the snapshot creation.
    if (!this.rgPath) {
      this.rgPath = require('vscode-ripgrep').rgPath.replace(
        /\bapp\.asar\b/,
        'app.asar.unpacked'
      );
    }

    const directoryPath = directory.getPath();
    const regexpStr = this.prepareRegexp(regexp.source);

    const args = ['--json', '--regexp', regexpStr];
    if (options.leadingContextLineCount) {
      args.push('--before-context', options.leadingContextLineCount);
    }
    if (options.trailingContextLineCount) {
      args.push('--after-context', options.trailingContextLineCount);
    }
    if (regexp.ignoreCase) {
      args.push('--ignore-case');
    }
    for (const inclusion of this.prepareGlobs(
      options.inclusions,
      directoryPath
    )) {
      args.push('--glob', inclusion);
    }
    for (const exclusion of this.prepareGlobs(
      options.exclusions,
      directoryPath
    )) {
      args.push('--glob', '!' + exclusion);
    }

    if (this.isMultilineRegexp(regexpStr)) {
      args.push('--multiline');
    }

    if (options.includeHidden) {
      args.push('--hidden');
    }

    if (options.follow) {
      args.push('--follow');
    }

    if (!options.excludeVcsIgnores) {
      args.push('--no-ignore-vcs');
    }

    if (options.PCRE2) {
      args.push('--pcre2');
    }

    args.push('.');

    const child = spawn(this.rgPath, args, {
      cwd: directoryPath,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    const didMatch = options.didMatch || (() => {});
    let cancelled = false;

    const returnedPromise = new Promise((resolve, reject) => {
      let buffer = '';
      let bufferError = '';
      let pendingEvent;
      let pendingLeadingContext;
      let pendingTrailingContexts;

      child.on('close', (code, signal) => {
        // code 1 is used when no results are found.
        if (code !== null && code > 1) {
          reject(new Error(bufferError));
        } else {
          resolve();
        }
      });

      child.stderr.on('data', chunk => {
        bufferError += chunk;
      });

      child.stdout.on('data', chunk => {
        if (cancelled) {
          return;
        }

        buffer += chunk;
        const lines = buffer.split('\n');
        buffer = lines.pop();
        for (const line of lines) {
          const message = JSON.parse(line);
          updateTrailingContexts(message, pendingTrailingContexts, options);

          if (message.type === 'begin') {
            pendingEvent = {
              filePath: path.join(directoryPath, getText(message.data.path)),
              matches: []
            };
            pendingLeadingContext = [];
            pendingTrailingContexts = new Set();
          } else if (message.type === 'match') {
            const trailingContextLines = [];
            pendingTrailingContexts.add(trailingContextLines);

            processUnicodeMatch(message.data);

            for (const submatch of message.data.submatches) {
              const { lineText, range } = processSubmatch(
                submatch,
                getText(message.data.lines),
                message.data.line_number - 1
              );

              pendingEvent.matches.push({
                matchText: getText(submatch.match),
                lineText,
                lineTextOffset: 0,
                range,
                leadingContextLines: [...pendingLeadingContext],
                trailingContextLines
              });
            }
          } else if (message.type === 'end') {
            options.didSearchPaths(++numPathsFound.num);
            didMatch(pendingEvent);
            pendingEvent = null;
          }

          updateLeadingContext(message, pendingLeadingContext, options);
        }
      });
    });

    returnedPromise.cancel = () => {
      child.kill();
      cancelled = true;
    };

    return returnedPromise;
  }

  // We need to prepare the "globs" that we receive from the user to make their behaviour more
  // user-friendly (e.g when adding `src/` the user probably means `src/**/*`).
  // This helper function takes care of that.
  prepareGlobs(globs, projectRootPath) {
    const output = [];

    for (let pattern of globs) {
      // we need to replace path separators by slashes since globs should
      // always use always slashes as path separators.
      pattern = pattern.replace(new RegExp(`\\${path.sep}`, 'g'), '/');

      if (pattern.length === 0) {
        continue;
      }

      const projectName = path.basename(projectRootPath);

      // The user can just search inside one of the opened projects. When we detect
      // this scenario we just consider the glob to include every file.
      if (pattern === projectName) {
        output.push('**/*');
        continue;
      }

      if (pattern.startsWith(projectName + '/')) {
        pattern = pattern.slice(projectName.length + 1);
      }

      if (pattern.endsWith('/')) {
        pattern = pattern.slice(0, -1);
      }

      output.push(pattern);
      output.push(pattern.endsWith('/**') ? pattern : `${pattern}/**`);
    }

    return output;
  }

  prepareRegexp(regexpStr) {
    // ripgrep handles `--` as the arguments separator, so we need to escape it if the
    // user searches for that exact same string.
    if (regexpStr === '--') {
      return '\\-\\-';
    }

    // ripgrep is quite picky about unnecessarily escaped sequences, so we need to unescape
    // them: https://github.com/BurntSushi/ripgrep/issues/434.
    regexpStr = regexpStr.replace(/\\\//g, '/');

    return regexpStr;
  }

  isMultilineRegexp(regexpStr) {
    if (regexpStr.includes('\\n')) {
      return true;
    }

    return false;
  }
};
