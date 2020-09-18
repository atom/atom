const _ = require('underscore-plus')
const {Emitter, TextEditor, Range} = require('atom')
const escapeHelper = require('../escape-helper')

class Result {
  static create (result) {
    if (result && result.matches && result.matches.length) {
      const matches = []

      for (const m of result.matches) {
        const range = Range.fromObject(m.range)
        const matchSplit = m.matchText.split('\n')
        const linesSplit = m.lineText.split('\n')

        // If the result spans across multiple lines, process each of
        // them separately by creating separate `matches` objects for
        // each line on the match.
        for (let row = range.start.row; row <= range.end.row; row++) {
          const lineText = linesSplit[row - range.start.row]
          const matchText = matchSplit[row - range.start.row]

          // When receiving multiline results from opened buffers, only
          // the first result line is provided on the `lineText` property.
          // This makes it impossible to properly render the part of the result
          // that's part of other lines.
          // In order to prevent an error we just need to ignore these parts.
          if (lineText === undefined || matchText === undefined) {
            continue
          }

          // Adapt the range column number based on which line we're at:
          // - the first line of a multiline result will always start at the range start
          //   and will end at the end of the line.
          // - middle lines will start at 0 and end at the end of the line
          // - last line will start at 0 and end at the range end.
          const startColumn = row === range.start.row ? range.start.column : 0
          const endColumn = row === range.end.row ? range.end.column : lineText.length

          matches.push({
            matchText,
            lineText,
            lineTextOffset: m.lineTextOffset,
            range: {
              start: {
                row,
                column: startColumn
              },
              end: {
                row,
                column: endColumn
              }
            },
            leadingContextLines: m.leadingContextLines,
            trailingContextLines: m.trailingContextLines
          })
        }
      }

      return new Result({filePath: result.filePath, matches})
    } else {
      return null
    }
  }

  constructor (result) {
    _.extend(this, result)
  }
}

module.exports = class ResultsModel {
  constructor (findOptions, metricsReporter) {
    this.metricsReporter = metricsReporter
    this.onContentsModified = this.onContentsModified.bind(this)
    this.findOptions = findOptions
    this.emitter = new Emitter()

    atom.workspace.getCenter().observeActivePaneItem(item => {
      if (item instanceof TextEditor && atom.project.contains(item.getPath())) {
        item.onDidStopChanging(() => this.onContentsModified(item))
      }
    })

    this.clear()
  }

  onDidClear (callback) {
    return this.emitter.on('did-clear', callback)
  }

  onDidClearSearchState (callback) {
    return this.emitter.on('did-clear-search-state', callback)
  }

  onDidClearReplacementState (callback) {
    return this.emitter.on('did-clear-replacement-state', callback)
  }

  onDidSearchPaths (callback) {
    return this.emitter.on('did-search-paths', callback)
  }

  onDidErrorForPath (callback) {
    return this.emitter.on('did-error-for-path', callback)
  }

  onDidNoopSearch (callback) {
    return this.emitter.on('did-noop-search', callback)
  }

  onDidStartSearching (callback) {
    return this.emitter.on('did-start-searching', callback)
  }

  onDidCancelSearching (callback) {
    return this.emitter.on('did-cancel-searching', callback)
  }

  onDidFinishSearching (callback) {
    return this.emitter.on('did-finish-searching', callback)
  }

  onDidStartReplacing (callback) {
    return this.emitter.on('did-start-replacing', callback)
  }

  onDidFinishReplacing (callback) {
    return this.emitter.on('did-finish-replacing', callback)
  }

  onDidSearchPath (callback) {
    return this.emitter.on('did-search-path', callback)
  }

  onDidReplacePath (callback) {
    return this.emitter.on('did-replace-path', callback)
  }

  onDidAddResult (callback) {
    return this.emitter.on('did-add-result', callback)
  }

  onDidSetResult (callback) {
    return this.emitter.on('did-set-result', callback)
  }

  onDidRemoveResult (callback) {
    return this.emitter.on('did-remove-result', callback)
  }

  clear () {
    this.clearSearchState()
    this.clearReplacementState()
    this.emitter.emit('did-clear', this.getResultsSummary())
  }

  clearSearchState () {
    this.pathCount = 0
    this.matchCount = 0
    this.regex = null
    this.results = {}
    this.active = false
    this.searchErrors = null

    if (this.inProgressSearchPromise != null) {
      this.inProgressSearchPromise.cancel()
      this.inProgressSearchPromise = null
    }

    this.emitter.emit('did-clear-search-state', this.getResultsSummary())
  }

  clearReplacementState () {
    this.replacePattern = null
    this.replacedPathCount = null
    this.replacementCount = null
    this.replacementErrors = null
    this.emitter.emit('did-clear-replacement-state', this.getResultsSummary())
  }

  shouldRerunSearch (findPattern, pathsPattern, options = {}) {
    return (
      !options.onlyRunIfChanged ||
      findPattern == null ||
      findPattern !== this.lastFindPattern ||
      pathsPattern == null ||
      pathsPattern !== this.lastPathsPattern
    )
  }

  async search (findPattern, pathsPattern, replacePattern, options = {}) {
    if (!this.shouldRerunSearch(findPattern, pathsPattern, options)) {
      this.emitter.emit('did-noop-search')
      return Promise.resolve()
    }

    const {keepReplacementState} = options
    if (keepReplacementState) {
      this.clearSearchState()
    } else {
      this.clear()
    }

    this.lastFindPattern = findPattern
    this.lastPathsPattern = pathsPattern
    this.findOptions.set(_.extend({findPattern, replacePattern, pathsPattern}, options))
    this.regex = this.findOptions.getFindPatternRegex()

    this.active = true
    const searchPaths = this.pathsArrayFromPathsPattern(pathsPattern)

    const onPathsSearched = numberOfPathsSearched => {
      this.emitter.emit('did-search-paths', numberOfPathsSearched)
    }

    const leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
    const trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')

    const startTime = Date.now()
    const useRipgrep = atom.config.get('find-and-replace.useRipgrep')
    const enablePCRE2 = atom.config.get('find-and-replace.enablePCRE2')

    this.inProgressSearchPromise = atom.workspace.scan(
      this.regex,
      {
        paths: searchPaths,
        onPathsSearched,
        leadingContextLineCount,
        ripgrep: useRipgrep,
        PCRE2: enablePCRE2,
        trailingContextLineCount
      },
      (result, error) => {
        if (result) {
          this.setResult(result.filePath, Result.create(result))
        } else {
          if (this.searchErrors == null) { this.searchErrors = [] }
          this.searchErrors.push(error)
          this.emitter.emit('did-error-for-path', error)
        }
      })

    this.emitter.emit('did-start-searching', this.inProgressSearchPromise)

    const message = await this.inProgressSearchPromise

    if (message === 'cancelled') {
      this.emitter.emit('did-cancel-searching')
    } else {
      const resultsSummary = this.getResultsSummary()

      this.metricsReporter.sendSearchEvent(
        Date.now() - startTime,
        resultsSummary.matchCount,
        useRipgrep ? 'ripgrep' : 'standard'
      )
      this.inProgressSearchPromise = null
      this.emitter.emit('did-finish-searching', resultsSummary)
    }
  }

  replace (pathsPattern, replacePattern, replacementPaths) {
    if (!this.findOptions.findPattern || (this.regex == null)) { return }

    this.findOptions.set({replacePattern, pathsPattern})

    if (this.findOptions.useRegex) { replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern) }

    this.active = false // not active until the search is finished
    this.replacedPathCount = 0
    this.replacementCount = 0

    const promise = atom.workspace.replace(this.regex, replacePattern, replacementPaths, (result, error) => {
      if (result) {
        if (result.replacements) {
          this.replacedPathCount++
          this.replacementCount += result.replacements
        }
        this.emitter.emit('did-replace-path', result)
      } else {
        if (this.replacementErrors == null) { this.replacementErrors = [] }
        this.replacementErrors.push(error)
        this.emitter.emit('did-error-for-path', error)
      }
    })

    this.emitter.emit('did-start-replacing', promise)
    return promise.then(() => {
      this.emitter.emit('did-finish-replacing', this.getResultsSummary())
      return this.search(this.findOptions.findPattern, this.findOptions.pathsPattern,
        this.findOptions.replacePattern, {keepReplacementState: true})
    }).catch(e => console.error(e.stack))
  }

  setActive (isActive) {
    if ((isActive && this.findOptions.findPattern) || !isActive) {
      this.active = isActive
    }
  }

  getActive () { return this.active }

  getFindOptions () { return this.findOptions }

  getLastFindPattern () { return this.lastFindPattern }

  getResultsSummary () {
    const findPattern = this.lastFindPattern != null ? this.lastFindPattern : this.findOptions.findPattern
    const { replacePattern } = this.findOptions
    return {
      findPattern,
      replacePattern,
      pathCount: this.pathCount,
      matchCount: this.matchCount,
      searchErrors: this.searchErrors,
      replacedPathCount: this.replacedPathCount,
      replacementCount: this.replacementCount,
      replacementErrors: this.replacementErrors
    }
  }

  getPathCount () {
    return this.pathCount
  }

  getMatchCount () {
    return this.matchCount
  }

  getPaths () {
    return Object.keys(this.results)
  }

  getResult (filePath) {
    return this.results[filePath]
  }

  setResult (filePath, result) {
    if (result == null) {
      return this.removeResult(filePath)
    }
    if (!this.results[filePath]) {
      return this.addResult(filePath, result)
    }

    this.matchCount += result.matches.length - this.results[filePath].matches.length

    this.results[filePath] = result
    this.emitter.emit('did-set-result', {filePath, result})
  }

  addResult (filePath, result) {
    this.pathCount++
    this.matchCount += result.matches.length

    this.results[filePath] = result
    this.emitter.emit('did-add-result', {filePath, result})
  }

  removeResult (filePath) {
    if (!this.results[filePath]) {
      return
    }

    this.pathCount--
    this.matchCount -= this.results[filePath].matches.length

    const result = this.results[filePath]
    delete this.results[filePath]
    this.emitter.emit('did-remove-result', {filePath, result})
  }

  onContentsModified (editor) {
    if (!this.active || !this.regex || !editor.getPath()) { return }

    const matches = []
    const leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
    const trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')
    editor.scan(this.regex,
      {leadingContextLineCount, trailingContextLineCount},
      (match) => matches.push(match)
    )

    const result = Result.create({filePath: editor.getPath(), matches})
    this.setResult(editor.getPath(), result)
    this.emitter.emit('did-finish-searching', this.getResultsSummary())
  }

  pathsArrayFromPathsPattern (pathsPattern) {
    return pathsPattern.trim().split(',').map((inputPath) => inputPath.trim())
  }
}

// Exported for tests
module.exports.Result = Result
