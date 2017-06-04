/** @babel */

// Extended: Wraps an {Array} of `String`s. The Array describes a path from the
// root of the syntax tree to a token including _all_ scope names for the entire
// path.
//
// Methods that take a `ScopeDescriptor` will also accept an {Array} of {Strings}
// scope names e.g. `['.source.js']`.
//
// You can use `ScopeDescriptor`s to get language-specific config settings via
// {Config::get}.
//
// You should not need to create a `ScopeDescriptor` directly.
//
// * {Editor::getRootScopeDescriptor} to get the language's descriptor.
// * {Editor::scopeDescriptorForBufferPosition} to get the descriptor at a
//   specific position in the buffer.
// * {Cursor::getScopeDescriptor} to get a cursor's descriptor based on position.
//
// See the [scopes and scope descriptor guide](http://flight-manual.atom.io/behind-atom/sections/scoped-settings-scopes-and-scope-descriptors/)
// for more information.
export default class ScopeDescriptor {
  static fromObject (scopes) {
    if (scopes instanceof ScopeDescriptor) {
      return scopes
    } else {
      return new ScopeDescriptor({scopes})
    }
  }

  /*
  Section: Construction and Destruction
  */

  // Public: Create a {ScopeDescriptor} object.
  //
  // * `object` {Object}
  //   * `scopes` {Array} of {String}s
  constructor ({scopes}) {
    this.scopes = scopes
  }

  // Public: Returns an {Array} of {String}s
  getScopesArray () {
    return this.scopes
  }

  getScopeChain () {
    return this.scopes
      .map((scope) => {
        if (scope[0] !== '.') {
          scope = `.${scope}`
        }
        return scope
      })
      .join(' ')
  }

  toString () {
    return this.getScopeChain()
  }

  isEqual (other) {
    if (this.scopes.length !== other.scopes.length) {
      return false
    }

    for (let i = 0; i < this.scopes.length; i++) {
      let scope = this.scopes[i]
      if (scope !== other.scopes[i]) {
        return false
      }
    }
    return true
  }
}
