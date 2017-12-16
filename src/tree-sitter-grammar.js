const path = require('path')
const SyntaxScopeMap = require('./syntax-scope-map')
const Module = require('module')

module.exports =
class TreeSitterGrammar {
  constructor (registry, filePath, params) {
    this.registry = registry
    this.id = params.id
    this.name = params.name
    this.legacyScopeName = params.legacyScopeName
    if (params.contentRegExp) this.contentRegExp = new RegExp(params.contentRegExp)

    this.folds = params.folds || []

    this.commentStrings = {
      commentStartString: params.comments && params.comments.start,
      commentEndString: params.comments && params.comments.end
    }

    const scopeSelectors = {}
    for (const key in params.scopes || {}) {
      scopeSelectors[key] = params.scopes[key]
        .split('.')
        .map(s => `syntax--${s}`)
        .join(' ')
    }

    this.scopeMap = new SyntaxScopeMap(scopeSelectors)
    this.fileTypes = params.fileTypes

    // TODO - When we upgrade to a new enough version of node, use `require.resolve`
    // with the new `paths` option instead of this private API.
    const languageModulePath = Module._resolveFilename(params.parser, {
      id: filePath,
      filename: filePath,
      paths: Module._nodeModulePaths(path.dirname(filePath))
    })

    this.languageModule = require(languageModulePath)
    this.scopesById = new Map()
    this.idsByScope = {}
    this.nextScopeId = 256 + 1
    this.registration = null
  }

  idForScope (scope) {
    let id = this.idsByScope[scope]
    if (!id) {
      id = this.nextScopeId += 2
      this.idsByScope[scope] = id
      this.scopesById.set(id, scope)
    }
    return id
  }

  classNameForScopeId (id) {
    return this.scopesById.get(id)
  }

  get scopeName () {
    return this.id
  }

  activate () {
    this.registration = this.registry.addGrammar(this)
  }

  deactivate () {
    if (this.registration) this.registration.dispose()
  }
}
