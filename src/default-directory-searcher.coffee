Task = require './task'

# Searches local files for lines matching a specified regex. Implements `.then()`
# so that it can be used with `Promise.all()`.
class DirectorySearch
  constructor: (rootPaths, regex, options) ->
    scanHandlerOptions =
      ignoreCase: regex.ignoreCase
      inclusions: options.inclusions
      includeHidden: options.includeHidden
      excludeVcsIgnores: options.excludeVcsIgnores
      globalExclusions: options.exclusions
      follow: options.follow
    @task = new Task(require.resolve('./scan-handler'))
    @task.on 'scan:result-found', options.didMatch
    @task.on 'scan:file-error', options.didError
    @task.on 'scan:paths-searched', options.didSearchPaths
    @promise = new Promise (resolve, reject) =>
      @task.on('task:cancelled', reject)
      @task.start rootPaths, regex.source, scanHandlerOptions, =>
        @task.terminate()
        resolve()

  then: (args...) ->
    @promise.then.apply(@promise, args)

  cancel: ->
    # This will cause @promise to reject.
    @task.cancel()
    null

# Default provider for the `atom.directory-searcher` service.
module.exports =
class DefaultDirectorySearcher
  # Determines whether this object supports search for a `Directory`.
  #
  # * `directory` {Directory} whose search needs might be supported by this object.
  #
  # Returns a `boolean` indicating whether this object can search this `Directory`.
  canSearchDirectory: (directory) -> true

  # Performs a text search for files in the specified `Directory`, subject to the
  # specified parameters.
  #
  # Results are streamed back to the caller by invoking methods on the specified `options`,
  # such as `didMatch` and `didError`.
  #
  # * `directories` {Array} of {Directory} objects to search, all of which have been accepted by
  # this searcher's `canSearchDirectory()` predicate.
  # * `regex` {RegExp} to search with.
  # * `options` {Object} with the following properties:
  #   * `didMatch` {Function} call with a search result structured as follows:
  #     * `searchResult` {Object} with the following keys:
  #       * `filePath` {String} absolute path to the matching file.
  #       * `matches` {Array} with object elements with the following keys:
  #         * `lineText` {String} The full text of the matching line (without a line terminator character).
  #         * `lineTextOffset` {Number} (This always seems to be 0?)
  #         * `matchText` {String} The text that matched the `regex` used for the search.
  #         * `range` {Range} Identifies the matching region in the file. (Likely as an array of numeric arrays.)
  #   * `didError` {Function} call with an Error if there is a problem during the search.
  #   * `didSearchPaths` {Function} periodically call with the number of paths searched thus far.
  #   * `inclusions` {Array} of glob patterns (as strings) to search within. Note that this
  #   array may be empty, indicating that all files should be searched.
  #
  #   Each item in the array is a file/directory pattern, e.g., `src` to search in the "src"
  #   directory or `*.js` to search all JavaScript files. In practice, this often comes from the
  #   comma-delimited list of patterns in the bottom text input of the ProjectFindView dialog.
  #   * `ignoreHidden` {boolean} whether to ignore hidden files.
  #   * `excludeVcsIgnores` {boolean} whether to exclude VCS ignored paths.
  #   * `exclusions` {Array} similar to inclusions
  #   * `follow` {boolean} whether symlinks should be followed.
  #
  # Returns a *thenable* `DirectorySearch` that includes a `cancel()` method. If `cancel()` is
  # invoked before the `DirectorySearch` is determined, it will resolve the `DirectorySearch`.
  search: (directories, regex, options) ->
    rootPaths = directories.map (directory) -> directory.getPath()
    isCancelled = false
    directorySearch = new DirectorySearch(rootPaths, regex, options)
    promise = new Promise (resolve, reject) ->
      directorySearch.then resolve, ->
        if isCancelled
          resolve()
        else
          reject()
    return {
      then: promise.then.bind(promise)
      catch: promise.catch.bind(promise)
      cancel: ->
        isCancelled = true
        directorySearch.cancel()
    }
