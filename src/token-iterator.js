module.exports = class TokenIterator {
  constructor(languageMode) {
    this.languageMode = languageMode;
  }

  reset(line) {
    this.line = line;
    this.index = null;
    this.startColumn = 0;
    this.endColumn = 0;
    this.scopes = this.line.openScopes.map(id =>
      this.languageMode.grammar.scopeForId(id)
    );
    this.scopeStarts = this.scopes.slice();
    this.scopeEnds = [];
    return this;
  }

  next() {
    const { tags } = this.line;

    if (this.index != null) {
      this.startColumn = this.endColumn;
      this.scopeEnds.length = 0;
      this.scopeStarts.length = 0;
      this.index++;
    } else {
      this.index = 0;
    }

    while (this.index < tags.length) {
      const tag = tags[this.index];
      if (tag < 0) {
        const scope = this.languageMode.grammar.scopeForId(tag);
        if (tag % 2 === 0) {
          if (this.scopeStarts[this.scopeStarts.length - 1] === scope) {
            this.scopeStarts.pop();
          } else {
            this.scopeEnds.push(scope);
          }
          this.scopes.pop();
        } else {
          this.scopeStarts.push(scope);
          this.scopes.push(scope);
        }
        this.index++;
      } else {
        this.endColumn += tag;
        this.text = this.line.text.substring(this.startColumn, this.endColumn);
        return true;
      }
    }

    return false;
  }

  getScopes() {
    return this.scopes;
  }

  getScopeStarts() {
    return this.scopeStarts;
  }

  getScopeEnds() {
    return this.scopeEnds;
  }

  getText() {
    return this.text;
  }

  getBufferStart() {
    return this.startColumn;
  }

  getBufferEnd() {
    return this.endColumn;
  }
};
