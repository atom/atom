const Task = require('./task');

// Searches local files for lines matching a specified regex. Implements `.then()`
// so that it can be used with `Promise.all()`.
class DirectorySearch {
  constructor(rootPaths, regex, options) {
    const scanHandlerOptions = {
      ignoreCase: regex.ignoreCase,
      inclusions: options.inclusions,
      includeHidden: options.includeHidden,
      excludeVcsIgnores: options.excludeVcsIgnores,
      globalExclusions: options.exclusions,
      follow: options.follow
    };
    const searchOptions = {
      leadingContextLineCount: options.leadingContextLineCount,
      trailingContextLineCount: options.trailingContextLineCount
    };
    this.task = new Task(require.resolve('./scan-handler'));
    this.task.on('scan:result-found', options.didMatch);
    this.task.on('scan:file-error', options.didError);
    this.task.on('scan:paths-searched', options.didSearchPaths);
    this.promise = new Promise((resolve, reject) => {
      this.task.on('task:cancelled', reject);
      this.task.start(
        rootPaths,
        regex.source,
        scanHandlerOptions,
        searchOptions,
        () => {
          this.task.terminate();
          resolve();
        }
      );
    });
  }

  then(...args) {
    return this.promise.then.apply(this.promise, args);
  }

  cancel() {
    // This will cause @promise to reject.
    this.task.cancel();
  }
}

// Default provider for the `atom.directory-searcher` service.
module.exports = class DefaultDirectorySearcher {
  // Determines whether this object supports search for a `Directory`.
  //
  // * `directory` {Directory} whose search needs might be supported by this object.
  //
  // Returns a `boolean` indicating whether this object can search this `Directory`.
  canSearchDirectory(directory) {
    return true;
  }

  // Performs a text search for files in the specified `Directory`, subject to the
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
  //         * `lineTextOffset` {Number} If > 0, the provided line text is truncated and starts at this offset
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
  //   * `includeHidden` {boolean} whether to ignore hidden files.
  //   * `excludeVcsIgnores` {boolean} whether to exclude VCS ignored paths.
  //   * `exclusions` {Array} similar to inclusions
  //   * `follow` {boolean} whether symlinks should be followed.
  //
  // Returns a *thenable* `DirectorySearch` that includes a `cancel()` method. If `cancel()` is
  // invoked before the `DirectorySearch` is determined, it will resolve the `DirectorySearch`.
  search(directories, regex, options) {
    const rootPaths = directories.map(directory => directory.getPath());
    let isCancelled = false;
    const directorySearch = new DirectorySearch(rootPaths, regex, options);
    const promise = new Promise(function(resolve, reject) {
      directorySearch.then(resolve, function() {
        if (isCancelled) {
          resolve();
        } else {
          reject(); // eslint-disable-line prefer-promise-reject-errors
        }
      });
    });
    return {
      then: promise.then.bind(promise),
      catch: promise.catch.bind(promise),
      cancel() {
        isCancelled = true;
        directorySearch.cancel();
      }
    };
  }
};
