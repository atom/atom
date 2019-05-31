// Extended: Wraps an {Array} of `String`s. The Array describes a path from the
// root of the syntax tree to a token including _all_ scope names for the entire
// path.
//
// Methods that take a `ScopeDescriptor` will also accept an {Array} of {String}
// scope names e.g. `['.source.js']`.
//
// You can use `ScopeDescriptor`s to get language-specific config settings via
// {Config::get}.
//
// You should not need to create a `ScopeDescriptor` directly.
//
// * {TextEditor::getRootScopeDescriptor} to get the language's descriptor.
// * {TextEditor::scopeDescriptorForBufferPosition} to get the descriptor at a
//   specific position in the buffer.
// * {Cursor::getScopeDescriptor} to get a cursor's descriptor based on position.
//
// See the [scopes and scope descriptor guide](http://flight-manual.atom.io/behind-atom/sections/scoped-settings-scopes-and-scope-descriptors/)
// for more information.
module.exports = class ScopeDescriptor {
  static fromObject(scopes) {
    if (scopes instanceof ScopeDescriptor) {
      return scopes;
    } else {
      return new ScopeDescriptor({ scopes });
    }
  }

  /*
  Section: Construction and Destruction
  */

  // Public: Create a {ScopeDescriptor} object.
  //
  // * `object` {Object}
  //   * `scopes` {Array} of {String}s
  constructor({ scopes }) {
    this.scopes = scopes;
  }

  // Public: Returns an {Array} of {String}s
  getScopesArray() {
    return this.scopes;
  }

  getScopeChain() {
    // For backward compatibility, prefix TextMate-style scope names with
    // leading dots (e.g. 'source.js' -> '.source.js').
    if (this.scopes[0] != null && this.scopes[0].includes('.')) {
      let result = '';
      for (let i = 0; i < this.scopes.length; i++) {
        const scope = this.scopes[i];
        if (i > 0) {
          result += ' ';
        }
        if (scope[0] !== '.') {
          result += '.';
        }
        result += scope;
      }
      return result;
    } else {
      return this.scopes.join(' ');
    }
  }

  toString() {
    return this.getScopeChain();
  }

  isEqual(other) {
    if (this.scopes.length !== other.scopes.length) {
      return false;
    }
    for (let i = 0; i < this.scopes.length; i++) {
      const scope = this.scopes[i];
      if (scope !== other.scopes[i]) {
        return false;
      }
    }
    return true;
  }
};
