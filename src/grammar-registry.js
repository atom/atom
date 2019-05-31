const _ = require('underscore-plus');
const Grim = require('grim');
const CSON = require('season');
const FirstMate = require('first-mate');
const { Disposable, CompositeDisposable } = require('event-kit');
const TextMateLanguageMode = require('./text-mate-language-mode');
const TreeSitterLanguageMode = require('./tree-sitter-language-mode');
const TreeSitterGrammar = require('./tree-sitter-grammar');
const ScopeDescriptor = require('./scope-descriptor');
const Token = require('./token');
const fs = require('fs-plus');
const { Point, Range } = require('text-buffer');

const PATH_SPLIT_REGEX = new RegExp('[/.]');

// Extended: This class holds the grammars used for tokenizing.
//
// An instance of this class is always available as the `atom.grammars` global.
module.exports = class GrammarRegistry {
  constructor({ config } = {}) {
    this.config = config;
    this.subscriptions = new CompositeDisposable();
    this.textmateRegistry = new FirstMate.GrammarRegistry({
      maxTokensPerLine: 100,
      maxLineLength: 1000
    });
    this.clear();
  }

  clear() {
    this.textmateRegistry.clear();
    this.treeSitterGrammarsById = {};
    if (this.subscriptions) this.subscriptions.dispose();
    this.subscriptions = new CompositeDisposable();
    this.languageOverridesByBufferId = new Map();
    this.grammarScoresByBuffer = new Map();
    this.textMateScopeNamesByTreeSitterLanguageId = new Map();
    this.treeSitterLanguageIdsByTextMateScopeName = new Map();

    const grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this);
    this.textmateRegistry.onDidAddGrammar(grammarAddedOrUpdated);
    this.textmateRegistry.onDidUpdateGrammar(grammarAddedOrUpdated);

    this.subscriptions.add(
      this.config.onDidChange('core.useTreeSitterParsers', () => {
        this.grammarScoresByBuffer.forEach((score, buffer) => {
          if (!this.languageOverridesByBufferId.has(buffer.id)) {
            this.autoAssignLanguageMode(buffer);
          }
        });
      })
    );
  }

  serialize() {
    const languageOverridesByBufferId = {};
    this.languageOverridesByBufferId.forEach((languageId, bufferId) => {
      languageOverridesByBufferId[bufferId] = languageId;
    });
    return { languageOverridesByBufferId };
  }

  deserialize(params) {
    for (const bufferId in params.languageOverridesByBufferId || {}) {
      this.languageOverridesByBufferId.set(
        bufferId,
        params.languageOverridesByBufferId[bufferId]
      );
    }
  }

  createToken(value, scopes) {
    return new Token({ value, scopes });
  }

  // Extended: set a {TextBuffer}'s language mode based on its path and content,
  // and continue to update its language mode as grammars are added or updated, or
  // the buffer's file path changes.
  //
  // * `buffer` The {TextBuffer} whose language mode will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the buffer's
  // language mode.
  maintainLanguageMode(buffer) {
    this.grammarScoresByBuffer.set(buffer, null);

    const languageOverride = this.languageOverridesByBufferId.get(buffer.id);
    if (languageOverride) {
      this.assignLanguageMode(buffer, languageOverride);
    } else {
      this.autoAssignLanguageMode(buffer);
    }

    const pathChangeSubscription = buffer.onDidChangePath(() => {
      this.grammarScoresByBuffer.delete(buffer);
      if (!this.languageOverridesByBufferId.has(buffer.id)) {
        this.autoAssignLanguageMode(buffer);
      }
    });

    const destroySubscription = buffer.onDidDestroy(() => {
      this.grammarScoresByBuffer.delete(buffer);
      this.languageOverridesByBufferId.delete(buffer.id);
      this.subscriptions.remove(destroySubscription);
      this.subscriptions.remove(pathChangeSubscription);
    });

    this.subscriptions.add(pathChangeSubscription, destroySubscription);

    return new Disposable(() => {
      destroySubscription.dispose();
      pathChangeSubscription.dispose();
      this.subscriptions.remove(pathChangeSubscription);
      this.subscriptions.remove(destroySubscription);
      this.grammarScoresByBuffer.delete(buffer);
      this.languageOverridesByBufferId.delete(buffer.id);
    });
  }

  // Extended: Force a {TextBuffer} to use a different grammar than the
  // one that would otherwise be selected for it.
  //
  // * `buffer` The {TextBuffer} whose grammar will be set.
  // * `languageId` The {String} id of the desired language.
  //
  // Returns a {Boolean} that indicates whether the language was successfully
  // found.
  assignLanguageMode(buffer, languageId) {
    if (buffer.getBuffer) buffer = buffer.getBuffer();

    let grammar = null;
    if (languageId != null) {
      grammar = this.grammarForId(languageId);
      if (!grammar) return false;
      this.languageOverridesByBufferId.set(buffer.id, languageId);
    } else {
      this.languageOverridesByBufferId.set(buffer.id, null);
      grammar = this.textmateRegistry.nullGrammar;
    }

    this.grammarScoresByBuffer.set(buffer, null);
    if (grammar !== buffer.getLanguageMode().grammar) {
      buffer.setLanguageMode(
        this.languageModeForGrammarAndBuffer(grammar, buffer)
      );
    }

    return true;
  }

  // Extended: Get the `languageId` that has been explicitly assigned to
  // to the given buffer, if any.
  //
  // Returns a {String} id of the language
  getAssignedLanguageId(buffer) {
    return this.languageOverridesByBufferId.get(buffer.id);
  }

  // Extended: Remove any language mode override that has been set for the
  // given {TextBuffer}. This will assign to the buffer the best language
  // mode available.
  //
  // * `buffer` The {TextBuffer}.
  autoAssignLanguageMode(buffer) {
    const result = this.selectGrammarWithScore(
      buffer.getPath(),
      getGrammarSelectionContent(buffer)
    );
    this.languageOverridesByBufferId.delete(buffer.id);
    this.grammarScoresByBuffer.set(buffer, result.score);
    if (result.grammar !== buffer.getLanguageMode().grammar) {
      buffer.setLanguageMode(
        this.languageModeForGrammarAndBuffer(result.grammar, buffer)
      );
    }
  }

  languageModeForGrammarAndBuffer(grammar, buffer) {
    if (grammar instanceof TreeSitterGrammar) {
      return new TreeSitterLanguageMode({
        grammar,
        buffer,
        config: this.config,
        grammars: this
      });
    } else {
      return new TextMateLanguageMode({ grammar, buffer, config: this.config });
    }
  }

  // Extended: Select a grammar for the given file path and file contents.
  //
  // This picks the best match by checking the file path and contents against
  // each grammar.
  //
  // * `filePath` A {String} file path.
  // * `fileContents` A {String} of text for the file path.
  //
  // Returns a {Grammar}, never null.
  selectGrammar(filePath, fileContents) {
    return this.selectGrammarWithScore(filePath, fileContents).grammar;
  }

  selectGrammarWithScore(filePath, fileContents) {
    let bestMatch = null;
    let highestScore = -Infinity;
    this.forEachGrammar(grammar => {
      const score = this.getGrammarScore(grammar, filePath, fileContents);
      if (score > highestScore || bestMatch == null) {
        bestMatch = grammar;
        highestScore = score;
      }
    });
    return { grammar: bestMatch, score: highestScore };
  }

  // Extended: Returns a {Number} representing how well the grammar matches the
  // `filePath` and `contents`.
  getGrammarScore(grammar, filePath, contents) {
    if (contents == null && fs.isFileSync(filePath)) {
      contents = fs.readFileSync(filePath, 'utf8');
    }

    // Initially identify matching grammars based on the filename and the first
    // line of the file.
    let score = this.getGrammarPathScore(grammar, filePath);
    if (this.grammarMatchesPrefix(grammar, contents)) score += 0.5;

    // If multiple grammars match by one of the above criteria, break ties.
    if (score > 0) {
      const isTreeSitter = grammar instanceof TreeSitterGrammar;

      // Prefer either TextMate or Tree-sitter grammars based on the user's settings.
      if (isTreeSitter) {
        if (this.shouldUseTreeSitterParser(grammar.scopeName)) {
          score += 0.1;
        } else {
          return -Infinity;
        }
      }

      // Prefer grammars with matching content regexes. Prefer a grammar with no content regex
      // over one with a non-matching content regex.
      if (grammar.contentRegex) {
        const contentMatch = isTreeSitter
          ? grammar.contentRegex.test(contents)
          : grammar.contentRegex.testSync(contents);
        if (contentMatch) {
          score += 0.05;
        } else {
          score -= 0.05;
        }
      }

      // Prefer grammars that the user has manually installed over bundled grammars.
      if (!grammar.bundledPackage) score += 0.01;
    }

    return score;
  }

  getGrammarPathScore(grammar, filePath) {
    if (!filePath) return -1;
    if (process.platform === 'win32') {
      filePath = filePath.replace(/\\/g, '/');
    }

    const pathComponents = filePath.toLowerCase().split(PATH_SPLIT_REGEX);
    let pathScore = 0;

    let customFileTypes;
    if (this.config.get('core.customFileTypes')) {
      customFileTypes = this.config.get('core.customFileTypes')[
        grammar.scopeName
      ];
    }

    let { fileTypes } = grammar;
    if (customFileTypes) {
      fileTypes = fileTypes.concat(customFileTypes);
    }

    for (let i = 0; i < fileTypes.length; i++) {
      const fileType = fileTypes[i];
      const fileTypeComponents = fileType.toLowerCase().split(PATH_SPLIT_REGEX);
      const pathSuffix = pathComponents.slice(-fileTypeComponents.length);
      if (_.isEqual(pathSuffix, fileTypeComponents)) {
        pathScore = Math.max(pathScore, fileType.length);
        if (i >= grammar.fileTypes.length) {
          pathScore += 0.5;
        }
      }
    }

    return pathScore;
  }

  grammarMatchesPrefix(grammar, contents) {
    if (contents && grammar.firstLineRegex) {
      let escaped = false;
      let numberOfNewlinesInRegex = 0;
      for (let character of grammar.firstLineRegex.source) {
        switch (character) {
          case '\\':
            escaped = !escaped;
            break;
          case 'n':
            if (escaped) {
              numberOfNewlinesInRegex++;
            }
            escaped = false;
            break;
          default:
            escaped = false;
        }
      }

      const prefix = contents
        .split('\n')
        .slice(0, numberOfNewlinesInRegex + 1)
        .join('\n');
      if (grammar.firstLineRegex.testSync) {
        return grammar.firstLineRegex.testSync(prefix);
      } else {
        return grammar.firstLineRegex.test(prefix);
      }
    } else {
      return false;
    }
  }

  forEachGrammar(callback) {
    this.textmateRegistry.grammars.forEach(callback);
    for (const grammarId in this.treeSitterGrammarsById) {
      const grammar = this.treeSitterGrammarsById[grammarId];
      if (grammar.scopeName) callback(grammar);
    }
  }

  grammarForId(languageId) {
    if (!languageId) return null;
    if (this.shouldUseTreeSitterParser(languageId)) {
      return (
        this.treeSitterGrammarsById[languageId] ||
        this.textmateRegistry.grammarForScopeName(languageId)
      );
    } else {
      return (
        this.textmateRegistry.grammarForScopeName(languageId) ||
        this.treeSitterGrammarsById[languageId]
      );
    }
  }

  // Deprecated: Get the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns a {String} such as `"source.js"`.
  grammarOverrideForPath(filePath) {
    Grim.deprecate('Use buffer.getLanguageMode().getLanguageId() instead');
    const buffer = atom.project.findBufferForPath(filePath);
    if (buffer) return this.getAssignedLanguageId(buffer);
  }

  // Deprecated: Set the grammar override for the given file path.
  //
  // * `filePath` A non-empty {String} file path.
  // * `languageId` A {String} such as `"source.js"`.
  //
  // Returns undefined.
  setGrammarOverrideForPath(filePath, languageId) {
    Grim.deprecate(
      'Use atom.grammars.assignLanguageMode(buffer, languageId) instead'
    );
    const buffer = atom.project.findBufferForPath(filePath);
    if (buffer) {
      const grammar = this.grammarForScopeName(languageId);
      if (grammar)
        this.languageOverridesByBufferId.set(buffer.id, grammar.name);
    }
  }

  // Remove the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns undefined.
  clearGrammarOverrideForPath(filePath) {
    Grim.deprecate('Use atom.grammars.autoAssignLanguageMode(buffer) instead');
    const buffer = atom.project.findBufferForPath(filePath);
    if (buffer) this.languageOverridesByBufferId.delete(buffer.id);
  }

  grammarAddedOrUpdated(grammar) {
    if (grammar.scopeName && !grammar.id) grammar.id = grammar.scopeName;

    this.grammarScoresByBuffer.forEach((score, buffer) => {
      const languageMode = buffer.getLanguageMode();
      const languageOverride = this.languageOverridesByBufferId.get(buffer.id);

      if (
        grammar === buffer.getLanguageMode().grammar ||
        grammar === this.grammarForId(languageOverride)
      ) {
        buffer.setLanguageMode(
          this.languageModeForGrammarAndBuffer(grammar, buffer)
        );
        return;
      } else if (!languageOverride) {
        const score = this.getGrammarScore(
          grammar,
          buffer.getPath(),
          getGrammarSelectionContent(buffer)
        );
        const currentScore = this.grammarScoresByBuffer.get(buffer);
        if (currentScore == null || score > currentScore) {
          buffer.setLanguageMode(
            this.languageModeForGrammarAndBuffer(grammar, buffer)
          );
          this.grammarScoresByBuffer.set(buffer, score);
          return;
        }
      }

      languageMode.updateForInjection(grammar);
    });
  }

  // Extended: Invoke the given callback when a grammar is added to the registry.
  //
  // * `callback` {Function} to call when a grammar is added.
  //   * `grammar` {Grammar} that was added.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddGrammar(callback) {
    return this.textmateRegistry.onDidAddGrammar(callback);
  }

  // Extended: Invoke the given callback when a grammar is updated due to a grammar
  // it depends on being added or removed from the registry.
  //
  // * `callback` {Function} to call when a grammar is updated.
  //   * `grammar` {Grammar} that was updated.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidUpdateGrammar(callback) {
    return this.textmateRegistry.onDidUpdateGrammar(callback);
  }

  // Experimental: Specify a type of syntax node that may embed other languages.
  //
  // * `grammarId` The {String} id of the parent language
  // * `injectionPoint` An {Object} with the following keys:
  //   * `type` The {String} type of syntax node that may embed other languages
  //   * `language` A {Function} that is called with syntax nodes of the specified `type` and
  //     returns a {String} that will be tested against other grammars' `injectionRegex` in
  //     order to determine what language should be embedded.
  //   * `content` A {Function} that is called with syntax nodes of the specified `type` and
  //     returns another syntax node or array of syntax nodes that contain the embedded source code.
  addInjectionPoint(grammarId, injectionPoint) {
    const grammar = this.treeSitterGrammarsById[grammarId];
    if (grammar) {
      if (grammar.addInjectionPoint) {
        grammar.addInjectionPoint(injectionPoint);
      } else {
        grammar.injectionPoints.push(injectionPoint);
      }
    } else {
      this.treeSitterGrammarsById[grammarId] = {
        injectionPoints: [injectionPoint]
      };
    }
    return new Disposable(() => {
      const grammar = this.treeSitterGrammarsById[grammarId];
      grammar.removeInjectionPoint(injectionPoint);
    });
  }

  get nullGrammar() {
    return this.textmateRegistry.nullGrammar;
  }

  get grammars() {
    return this.textmateRegistry.grammars;
  }

  decodeTokens() {
    return this.textmateRegistry.decodeTokens.apply(
      this.textmateRegistry,
      arguments
    );
  }

  grammarForScopeName(scopeName) {
    return this.grammarForId(scopeName);
  }

  addGrammar(grammar) {
    if (grammar instanceof TreeSitterGrammar) {
      const existingParams =
        this.treeSitterGrammarsById[grammar.scopeName] || {};
      if (grammar.scopeName)
        this.treeSitterGrammarsById[grammar.scopeName] = grammar;
      if (existingParams.injectionPoints) {
        for (const injectionPoint of existingParams.injectionPoints) {
          grammar.addInjectionPoint(injectionPoint);
        }
      }
      this.grammarAddedOrUpdated(grammar);
      return new Disposable(() => this.removeGrammar(grammar));
    } else {
      return this.textmateRegistry.addGrammar(grammar);
    }
  }

  removeGrammar(grammar) {
    if (grammar instanceof TreeSitterGrammar) {
      delete this.treeSitterGrammarsById[grammar.scopeName];
    } else {
      return this.textmateRegistry.removeGrammar(grammar);
    }
  }

  removeGrammarForScopeName(scopeName) {
    return this.textmateRegistry.removeGrammarForScopeName(scopeName);
  }

  // Extended: Read a grammar asynchronously and add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  // * `callback` A {Function} to call when loaded with the following arguments:
  //   * `error` An {Error}, may be null.
  //   * `grammar` A {Grammar} or null if an error occured.
  loadGrammar(grammarPath, callback) {
    this.readGrammar(grammarPath, (error, grammar) => {
      if (error) return callback(error);
      this.addGrammar(grammar);
      callback(null, grammar);
    });
  }

  // Extended: Read a grammar synchronously and add it to this registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  //
  // Returns a {Grammar}.
  loadGrammarSync(grammarPath) {
    const grammar = this.readGrammarSync(grammarPath);
    this.addGrammar(grammar);
    return grammar;
  }

  // Extended: Read a grammar asynchronously but don't add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  // * `callback` A {Function} to call when read with the following arguments:
  //   * `error` An {Error}, may be null.
  //   * `grammar` A {Grammar} or null if an error occured.
  //
  // Returns undefined.
  readGrammar(grammarPath, callback) {
    if (!callback) callback = () => {};
    CSON.readFile(grammarPath, (error, params = {}) => {
      if (error) return callback(error);
      try {
        callback(null, this.createGrammar(grammarPath, params));
      } catch (error) {
        callback(error);
      }
    });
  }

  // Extended: Read a grammar synchronously but don't add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  //
  // Returns a {Grammar}.
  readGrammarSync(grammarPath) {
    return this.createGrammar(
      grammarPath,
      CSON.readFileSync(grammarPath) || {}
    );
  }

  createGrammar(grammarPath, params) {
    if (params.type === 'tree-sitter') {
      return new TreeSitterGrammar(this, grammarPath, params);
    } else {
      if (
        typeof params.scopeName !== 'string' ||
        params.scopeName.length === 0
      ) {
        throw new Error(
          `Grammar missing required scopeName property: ${grammarPath}`
        );
      }
      return this.textmateRegistry.createGrammar(grammarPath, params);
    }
  }

  // Extended: Get all the grammars in this registry.
  //
  // Returns a non-empty {Array} of {Grammar} instances.
  getGrammars() {
    return this.textmateRegistry.getGrammars();
  }

  scopeForId(id) {
    return this.textmateRegistry.scopeForId(id);
  }

  treeSitterGrammarForLanguageString(languageString) {
    let longestMatchLength = 0;
    let grammarWithLongestMatch = null;
    for (const id in this.treeSitterGrammarsById) {
      const grammar = this.treeSitterGrammarsById[id];
      if (grammar.injectionRegex) {
        const match = languageString.match(grammar.injectionRegex);
        if (match) {
          const { length } = match[0];
          if (length > longestMatchLength) {
            grammarWithLongestMatch = grammar;
            longestMatchLength = length;
          }
        }
      }
    }
    return grammarWithLongestMatch;
  }

  shouldUseTreeSitterParser(languageId) {
    return this.config.get('core.useTreeSitterParsers', {
      scope: new ScopeDescriptor({ scopes: [languageId] })
    });
  }
};

function getGrammarSelectionContent(buffer) {
  return buffer.getTextInRange(
    Range(Point(0, 0), buffer.positionForCharacterIndex(1024))
  );
}
