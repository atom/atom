const { Emitter, Disposable } = require('event-kit');
const crypto = require('crypto');
const fs = require('fs-plus');
const path = require('path');
const postcss = require('postcss');
const selectorParser = require('postcss-selector-parser');
const { createStylesElement } = require('./styles-element');
const DEPRECATED_SYNTAX_SELECTORS = require('./deprecated-syntax-selectors');

// Extended: A singleton instance of this class available via `atom.styles`,
// which you can use to globally query and observe the set of active style
// sheets. The `StyleManager` doesn't add any style elements to the DOM on its
// own, but is instead subscribed to by individual `<atom-styles>` elements,
// which clone and attach style elements in different contexts.
module.exports = class StyleManager {
  constructor() {
    this.emitter = new Emitter();
    this.styleElements = [];
    this.styleElementsBySourcePath = {};
    this.deprecationsBySourcePath = {};
  }

  initialize({ configDirPath }) {
    this.configDirPath = configDirPath;
    if (this.configDirPath != null) {
      this.cacheDirPath = path.join(
        this.configDirPath,
        'compile-cache',
        'style-manager'
      );
    }
  }

  /*
  Section: Event Subscription
  */

  // Extended: Invoke `callback` for all current and future style elements.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //     will be null because this element isn't attached to the DOM. If you want
  //     to attach this element to the DOM, be sure to clone it first by calling
  //     `.cloneNode(true)` on it. The style element will also have the following
  //     non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  observeStyleElements(callback) {
    for (let styleElement of this.getStyleElements()) {
      callback(styleElement);
    }

    return this.onDidAddStyleElement(callback);
  }

  // Extended: Invoke `callback` when a style element is added.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //     will be null because this element isn't attached to the DOM. If you want
  //     to attach this element to the DOM, be sure to clone it first by calling
  //     `.cloneNode(true)` on it. The style element will also have the following
  //     non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidAddStyleElement(callback) {
    return this.emitter.on('did-add-style-element', callback);
  }

  // Extended: Invoke `callback` when a style element is removed.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidRemoveStyleElement(callback) {
    return this.emitter.on('did-remove-style-element', callback);
  }

  // Extended: Invoke `callback` when an existing style element is updated.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //      will be null because this element isn't attached to the DOM. The style
  //      element will also have the following non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidUpdateStyleElement(callback) {
    return this.emitter.on('did-update-style-element', callback);
  }

  onDidUpdateDeprecations(callback) {
    return this.emitter.on('did-update-deprecations', callback);
  }

  /*
  Section: Reading Style Elements
  */

  // Extended: Get all loaded style elements.
  getStyleElements() {
    return this.styleElements.slice();
  }

  addStyleSheet(source, params = {}) {
    let styleElement;
    let updated;
    if (
      params.sourcePath != null &&
      this.styleElementsBySourcePath[params.sourcePath] != null
    ) {
      updated = true;
      styleElement = this.styleElementsBySourcePath[params.sourcePath];
    } else {
      updated = false;
      styleElement = document.createElement('style');
      if (params.sourcePath != null) {
        styleElement.sourcePath = params.sourcePath;
        styleElement.setAttribute('source-path', params.sourcePath);
      }
      if (params.context != null) {
        styleElement.context = params.context;
        styleElement.setAttribute('context', params.context);
      }
      if (params.priority != null) {
        styleElement.priority = params.priority;
        styleElement.setAttribute('priority', params.priority);
      }
    }

    if (params.skipDeprecatedSelectorsTransformation) {
      styleElement.textContent = source;
    } else {
      const transformed = this.upgradeDeprecatedSelectorsForStyleSheet(
        source,
        params.context
      );
      styleElement.textContent = transformed.source;
      if (transformed.deprecationMessage) {
        this.deprecationsBySourcePath[params.sourcePath] = {
          message: transformed.deprecationMessage
        };
        this.emitter.emit('did-update-deprecations');
      }
    }

    if (updated) {
      this.emitter.emit('did-update-style-element', styleElement);
    } else {
      this.addStyleElement(styleElement);
    }
    return new Disposable(() => {
      this.removeStyleElement(styleElement);
    });
  }

  addStyleElement(styleElement) {
    let insertIndex = this.styleElements.length;
    if (styleElement.priority != null) {
      for (let i = 0; i < this.styleElements.length; i++) {
        const existingElement = this.styleElements[i];
        if (existingElement.priority > styleElement.priority) {
          insertIndex = i;
          break;
        }
      }
    }

    this.styleElements.splice(insertIndex, 0, styleElement);
    if (
      styleElement.sourcePath != null &&
      this.styleElementsBySourcePath[styleElement.sourcePath] == null
    ) {
      this.styleElementsBySourcePath[styleElement.sourcePath] = styleElement;
    }
    this.emitter.emit('did-add-style-element', styleElement);
  }

  removeStyleElement(styleElement) {
    const index = this.styleElements.indexOf(styleElement);
    if (index !== -1) {
      this.styleElements.splice(index, 1);
      if (styleElement.sourcePath != null) {
        delete this.styleElementsBySourcePath[styleElement.sourcePath];
      }
      this.emitter.emit('did-remove-style-element', styleElement);
    }
  }

  upgradeDeprecatedSelectorsForStyleSheet(styleSheet, context) {
    if (this.cacheDirPath != null) {
      const hash = crypto.createHash('sha1');
      if (context != null) {
        hash.update(context);
      }
      hash.update(styleSheet);
      const cacheFilePath = path.join(this.cacheDirPath, hash.digest('hex'));
      try {
        return JSON.parse(fs.readFileSync(cacheFilePath));
      } catch (e) {
        const transformed = transformDeprecatedShadowDOMSelectors(
          styleSheet,
          context
        );
        fs.writeFileSync(cacheFilePath, JSON.stringify(transformed));
        return transformed;
      }
    } else {
      return transformDeprecatedShadowDOMSelectors(styleSheet, context);
    }
  }

  getDeprecations() {
    return this.deprecationsBySourcePath;
  }

  clearDeprecations() {
    this.deprecationsBySourcePath = {};
  }

  getSnapshot() {
    return this.styleElements.slice();
  }

  restoreSnapshot(styleElementsToRestore) {
    for (let styleElement of this.getStyleElements()) {
      if (!styleElementsToRestore.includes(styleElement)) {
        this.removeStyleElement(styleElement);
      }
    }

    const existingStyleElements = this.getStyleElements();
    for (let styleElement of styleElementsToRestore) {
      if (!existingStyleElements.includes(styleElement)) {
        this.addStyleElement(styleElement);
      }
    }
  }

  buildStylesElement() {
    const stylesElement = createStylesElement();
    stylesElement.initialize(this);
    return stylesElement;
  }

  /*
  Section: Paths
  */

  // Extended: Get the path of the user style sheet in `~/.atom`.
  //
  // Returns a {String}.
  getUserStyleSheetPath() {
    if (this.configDirPath == null) {
      return '';
    } else {
      const stylesheetPath = fs.resolve(
        path.join(this.configDirPath, 'styles'),
        ['css', 'less']
      );
      if (fs.isFileSync(stylesheetPath)) {
        return stylesheetPath;
      } else {
        return path.join(this.configDirPath, 'styles.less');
      }
    }
  }
};

function transformDeprecatedShadowDOMSelectors(css, context) {
  const transformedSelectors = [];
  let transformedSource;
  try {
    transformedSource = postcss.parse(css);
  } catch (e) {
    transformedSource = null;
  }

  if (transformedSource) {
    transformedSource.walkRules(rule => {
      const transformedSelector = selectorParser(selectors => {
        selectors.each(selector => {
          const firstNode = selector.nodes[0];
          if (
            context === 'atom-text-editor' &&
            firstNode.type === 'pseudo' &&
            firstNode.value === ':host'
          ) {
            const atomTextEditorElementNode = selectorParser.tag({
              value: 'atom-text-editor'
            });
            firstNode.replaceWith(atomTextEditorElementNode);
          }

          let previousNodeIsAtomTextEditor = false;
          let targetsAtomTextEditorShadow = context === 'atom-text-editor';
          let previousNode;
          selector.each(node => {
            if (targetsAtomTextEditorShadow && node.type === 'class') {
              if (DEPRECATED_SYNTAX_SELECTORS.has(node.value)) {
                node.value = `syntax--${node.value}`;
              }
            } else {
              if (
                previousNodeIsAtomTextEditor &&
                node.type === 'pseudo' &&
                node.value === '::shadow'
              ) {
                node.type = 'className';
                node.value = '.editor';
                targetsAtomTextEditorShadow = true;
              }
            }
            previousNode = node;
            if (node.type === 'combinator') {
              previousNodeIsAtomTextEditor = false;
            } else if (
              previousNode.type === 'tag' &&
              previousNode.value === 'atom-text-editor'
            ) {
              previousNodeIsAtomTextEditor = true;
            }
          });
        });
      }).processSync(rule.selector, { lossless: true });
      if (transformedSelector !== rule.selector) {
        transformedSelectors.push({
          before: rule.selector,
          after: transformedSelector
        });
        rule.selector = transformedSelector;
      }
    });

    let deprecationMessage;
    if (transformedSelectors.length > 0) {
      deprecationMessage =
        'Starting from Atom v1.13.0, the contents of `atom-text-editor` elements ';
      deprecationMessage +=
        'are no longer encapsulated within a shadow DOM boundary. ';
      deprecationMessage +=
        'This means you should stop using `:host` and `::shadow` ';
      deprecationMessage +=
        'pseudo-selectors, and prepend all your syntax selectors with `syntax--`. ';
      deprecationMessage +=
        'To prevent breakage with existing style sheets, Atom will automatically ';
      deprecationMessage += 'upgrade the following selectors:\n\n';
      deprecationMessage +=
        transformedSelectors
          .map(selector => `* \`${selector.before}\` => \`${selector.after}\``)
          .join('\n\n') + '\n\n';
      deprecationMessage +=
        'Automatic translation of selectors will be removed in a few release cycles to minimize startup time. ';
      deprecationMessage +=
        'Please, make sure to upgrade the above selectors as soon as possible.';
    }
    return { source: transformedSource.toString(), deprecationMessage };
  } else {
    // CSS was malformed so we don't transform it.
    return { source: css };
  }
}
