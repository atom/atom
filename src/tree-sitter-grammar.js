const path = require('path');
const SyntaxScopeMap = require('./syntax-scope-map');
const Module = require('module');

module.exports = class TreeSitterGrammar {
  constructor(registry, filePath, params) {
    this.registry = registry;
    this.name = params.name;
    this.scopeName = params.scopeName;

    // TODO - Remove the `RegExp` spelling and only support `Regex`, once all of the existing
    // Tree-sitter grammars are updated to spell it `Regex`.
    this.contentRegex = buildRegex(params.contentRegex || params.contentRegExp);
    this.injectionRegex = buildRegex(
      params.injectionRegex || params.injectionRegExp
    );
    this.firstLineRegex = buildRegex(params.firstLineRegex);

    this.folds = params.folds || [];
    this.folds.forEach(normalizeFoldSpecification);

    this.commentStrings = {
      commentStartString: params.comments && params.comments.start,
      commentEndString: params.comments && params.comments.end
    };

    const scopeSelectors = {};
    for (const key in params.scopes || {}) {
      const classes = preprocessScopes(params.scopes[key]);
      const selectors = key.split(/,\s+/);
      for (let selector of selectors) {
        selector = selector.trim();
        if (!selector) continue;
        if (scopeSelectors[selector]) {
          scopeSelectors[selector] = [].concat(
            scopeSelectors[selector],
            classes
          );
        } else {
          scopeSelectors[selector] = classes;
        }
      }
    }

    this.scopeMap = new SyntaxScopeMap(scopeSelectors);
    this.fileTypes = params.fileTypes || [];
    this.injectionPointsByType = {};

    for (const injectionPoint of params.injectionPoints || []) {
      this.addInjectionPoint(injectionPoint);
    }

    // TODO - When we upgrade to a new enough version of node, use `require.resolve`
    // with the new `paths` option instead of this private API.
    const languageModulePath = Module._resolveFilename(params.parser, {
      id: filePath,
      filename: filePath,
      paths: Module._nodeModulePaths(path.dirname(filePath))
    });

    this.languageModule = require(languageModulePath);
    this.classNamesById = new Map();
    this.scopeNamesById = new Map();
    this.idsByScope = Object.create(null);
    this.nextScopeId = 256 + 1;
    this.registration = null;
  }

  inspect() {
    return `TreeSitterGrammar {scopeName: ${this.scopeName}}`;
  }

  idForScope(scopeName) {
    let id = this.idsByScope[scopeName];
    if (!id) {
      id = this.nextScopeId += 2;
      const className = scopeName
        .split('.')
        .map(s => `syntax--${s}`)
        .join(' ');
      this.idsByScope[scopeName] = id;
      this.classNamesById.set(id, className);
      this.scopeNamesById.set(id, scopeName);
    }
    return id;
  }

  classNameForScopeId(id) {
    return this.classNamesById.get(id);
  }

  scopeNameForScopeId(id) {
    return this.scopeNamesById.get(id);
  }

  activate() {
    this.registration = this.registry.addGrammar(this);
  }

  deactivate() {
    if (this.registration) this.registration.dispose();
  }

  addInjectionPoint(injectionPoint) {
    let injectionPoints = this.injectionPointsByType[injectionPoint.type];
    if (!injectionPoints) {
      injectionPoints = this.injectionPointsByType[injectionPoint.type] = [];
    }
    injectionPoints.push(injectionPoint);
  }

  removeInjectionPoint(injectionPoint) {
    const injectionPoints = this.injectionPointsByType[injectionPoint.type];
    if (injectionPoints) {
      const index = injectionPoints.indexOf(injectionPoint);
      if (index !== -1) injectionPoints.splice(index, 1);
      if (injectionPoints.length === 0) {
        delete this.injectionPointsByType[injectionPoint.type];
      }
    }
  }
};

const preprocessScopes = value =>
  typeof value === 'string'
    ? value
    : Array.isArray(value)
    ? value.map(preprocessScopes)
    : value.match
    ? { match: new RegExp(value.match), scopes: preprocessScopes(value.scopes) }
    : Object.assign({}, value, { scopes: preprocessScopes(value.scopes) });

const NODE_NAME_REGEX = /[\w_]+/;

function matcherForSpec(spec) {
  if (typeof spec === 'string') {
    if (spec[0] === '"' && spec[spec.length - 1] === '"') {
      return {
        type: spec.substr(1, spec.length - 2),
        named: false
      };
    }

    if (!NODE_NAME_REGEX.test(spec)) {
      return { type: spec, named: false };
    }

    return { type: spec, named: true };
  }
  return spec;
}

function normalizeFoldSpecification(spec) {
  if (spec.type) {
    if (Array.isArray(spec.type)) {
      spec.matchers = spec.type.map(matcherForSpec);
    } else {
      spec.matchers = [matcherForSpec(spec.type)];
    }
  }

  if (spec.start) normalizeFoldSpecification(spec.start);
  if (spec.end) normalizeFoldSpecification(spec.end);
}

function buildRegex(value) {
  // Allow multiple alternatives to be specified via an array, for
  // readability of the grammar file
  if (Array.isArray(value)) value = value.map(_ => `(${_})`).join('|');
  if (typeof value === 'string') return new RegExp(value);
  return null;
}
