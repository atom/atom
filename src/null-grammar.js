const { Disposable } = require('event-kit');

module.exports = {
  name: 'Null Grammar',
  scopeName: 'text.plain.null-grammar',
  scopeForId(id) {
    if (id === -1 || id === -2) {
      return this.scopeName;
    } else {
      return null;
    }
  },
  startIdForScope(scopeName) {
    if (scopeName === this.scopeName) {
      return -1;
    } else {
      return null;
    }
  },
  endIdForScope(scopeName) {
    if (scopeName === this.scopeName) {
      return -2;
    } else {
      return null;
    }
  },
  tokenizeLine(text) {
    return {
      tags: [
        this.startIdForScope(this.scopeName),
        text.length,
        this.endIdForScope(this.scopeName)
      ],
      ruleStack: null
    };
  },
  onDidUpdate(callback) {
    return new Disposable(noop);
  }
};

function noop() {}
