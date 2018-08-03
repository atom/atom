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
    if (params.injectionRegExp) this.injectionRegExp = new RegExp(params.injectionRegExp)

    this.folds = params.folds || []
    this.folds.forEach(normalizeFoldSpecification)

    this.commentStrings = {
      commentStartString: params.comments && params.comments.start,
      commentEndString: params.comments && params.comments.end
    }

    const scopeSelectors = {}
    for (const key in params.scopes || {}) {
      const classes = toSyntaxClasses(params.scopes[key])
      const selectors = key.split(/,\s+/)
      for (let selector of selectors) {
        selector = selector.trim()
        if (!selector) continue
        if (scopeSelectors[selector]) {
          scopeSelectors[selector] = [].concat(scopeSelectors[selector], classes)
        } else {
          scopeSelectors[selector] = classes
        }
      }
    }

    this.scopeMap = new SyntaxScopeMap(scopeSelectors)
    this.fileTypes = params.fileTypes
    this.injectionPoints = params.injectionPoints || []

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

const toSyntaxClasses = scopes =>
  typeof scopes === 'string'
    ? scopes
      .split('.')
      .map(s => `syntax--${s}`)
      .join(' ')
    : Array.isArray(scopes)
    ? scopes.map(toSyntaxClasses)
    : scopes.match
    ? {match: new RegExp(scopes.match), scopes: toSyntaxClasses(scopes.scopes)}
    : Object.assign({}, scopes, {scopes: toSyntaxClasses(scopes.scopes)})

const NODE_NAME_REGEX = /[\w_]+/

function matcherForSpec (spec) {
  if (typeof spec === 'string') {
    if (spec[0] === '"' && spec[spec.length - 1] === '"') {
      return {
        type: spec.substr(1, spec.length - 2),
        named: false
      }
    }

    if (!NODE_NAME_REGEX.test(spec)) {
      return {type: spec, named: false}
    }

    return {type: spec, named: true}
  }
  return spec
}

function normalizeFoldSpecification (spec) {
  if (spec.type) {
    if (Array.isArray(spec.type)) {
      spec.matchers = spec.type.map(matcherForSpec)
    } else {
      spec.matchers = [matcherForSpec(spec.type)]
    }
  }

  if (spec.start) normalizeFoldSpecification(spec.start)
  if (spec.end) normalizeFoldSpecification(spec.end)
}
