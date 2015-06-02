Task = require './task'

# Public:
# Implements thenable so it can be used with `Promise.all()`.
class DirectorySearch
  # Public:
  constructor: (directory, options) ->
    @task = new Task(require.resolve('./scan-handler'))
    rootPaths = [directory.getPath()]
    @promise = new Promise (resolve, reject) =>
      @task.start(rootPaths, options.regexSource, options, resolve)
      @task.on('task:cancelled', reject)

  # Public:
  # Returns `Promise`.
  then: (args...) ->
    @promise.then.apply(@promise, args)

  # Public:
  # Returns `Disposable`.
  onDidMatch: (callback) ->
    @task.on 'scan:result-found', callback

  # Public:
  # Returns `Disposable`.
  onDidError: (callback) ->
    @task.on 'scan:file-error', callback

  # Public:
  #
  # * `callback` {Function} called with the number of paths searched thus far.
  #
  # Returns `Disposable`.
  onDidSearchPaths: (callback) ->
    @task.on 'scan:paths-searched', callback

  # Public:
  cancel: ->
    # This will cause @promise to reject.
    @task.cancel()


# Default provider for the `atom.directory-searcher` service.
module.exports =
class DefaultDirectorySearcher
  # Public: Determines whether this object supports search for a `Directory`.
  #
  # * `directory` {Directory} whose search needs might be supported by this object.
  #
  # Returns a `boolean` indicating whether this object can search this `Directory`.
  canSearchDirectory: (directory) -> true

  # Public: Performs a text search for files in the specified `Directory`, subject to the
  # specified parameters.
  #
  # Results are streamed back to the caller via `recordSearchResult()` and `recordSearchError()`.
  #
  # * `directory` {Directory} that has been accepted by this provider's `canSearchDirectory()`
  # predicate.
  # (Note this reflects the "Use Regex" option exposed via the ProjectFindView UI.)
  # * `onSearchResult` {Function} Should be called with each matching search result.
  #   * `searchResult` {Object} with the following keys:
  #     * `filePath` {String} absolute path to the matching file.
  #     * `matches` {Array} with object elements with the following keys:
  #       * `lineText` {String} The full text of the matching line (without a line terminator character).
  #       * `lineTextOffset` {Number} (This always seems to be 0?)
  #       * `matchText` {String} The text that matched the `regex` used for the search.
  #       * `range` {Range} Identifies the matching region in the file. (Likely as an array of numeric arrays.)
  # * `onSearchError` {Function} Should be called to report a search error.
  # * `onPathsSearched` {Function} callback that should be invoked periodically with the number of
  # paths searched.
  # * `options` {Object} with the following properties:
  #   * `regexSource` {String} regex to search with. Produced via `RegExp::source`.
  #   * `ignoreCase` {boolean}
  #   * `inclusions` {Array} of glob patterns (as strings) to search within. Note that this
  #   array may be empty, indicating that all files should be searched.
  #
  #   Each item in the array is a file/directory pattern, e.g., `src` to search in the "src"
  #   directory or `*.js` to search all JavaScript files. In practice, this often comes from the
  #   comma-delimited list of patterns in the bottom text input of the ProjectFindView dialog.
  #   * `ignoreHidden` {boolean}
  #   * `excludeVcsIgnores` {boolean}
  #   * `exclusions` {Array} similar to inclusions
  #   * `follow` {boolean} whether symlinks should be followed
  #
  # Returns a `DirectorySearch` that includes a `cancel()` method. If invoked before the `Proimse` is
  # determined, it will reject the `Promise`.
  search: (directory, options) ->
    new DirectorySearch(directory, options)
