/* global snapshotAuxiliaryData */

const path = require('path');
const _ = require('underscore-plus');
const { Emitter, CompositeDisposable } = require('event-kit');
const { File } = require('pathwatcher');
const fs = require('fs-plus');
const LessCompileCache = require('./less-compile-cache');

// Extended: Handles loading and activating available themes.
//
// An instance of this class is always available as the `atom.themes` global.
module.exports = class ThemeManager {
  constructor({
    packageManager,
    config,
    styleManager,
    notificationManager,
    viewRegistry
  }) {
    this.packageManager = packageManager;
    this.config = config;
    this.styleManager = styleManager;
    this.notificationManager = notificationManager;
    this.viewRegistry = viewRegistry;
    this.emitter = new Emitter();
    this.styleSheetDisposablesBySourcePath = {};
    this.lessCache = null;
    this.initialLoadComplete = false;
    this.packageManager.registerPackageActivator(this, ['theme']);
    this.packageManager.onDidActivateInitialPackages(() => {
      this.onDidChangeActiveThemes(() =>
        this.packageManager.reloadActivePackageStyleSheets()
      );
    });
  }

  initialize({ resourcePath, configDirPath, safeMode, devMode }) {
    this.resourcePath = resourcePath;
    this.configDirPath = configDirPath;
    this.safeMode = safeMode;
    this.lessSourcesByRelativeFilePath = null;
    if (devMode || typeof snapshotAuxiliaryData === 'undefined') {
      this.lessSourcesByRelativeFilePath = {};
      this.importedFilePathsByRelativeImportPath = {};
    } else {
      this.lessSourcesByRelativeFilePath =
        snapshotAuxiliaryData.lessSourcesByRelativeFilePath;
      this.importedFilePathsByRelativeImportPath =
        snapshotAuxiliaryData.importedFilePathsByRelativeImportPath;
    }
  }

  /*
  Section: Event Subscription
  */

  // Essential: Invoke `callback` when style sheet changes associated with
  // updating the list of active themes have completed.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveThemes(callback) {
    return this.emitter.on('did-change-active-themes', callback);
  }

  /*
  Section: Accessing Available Themes
  */

  getAvailableNames() {
    // TODO: Maybe should change to list all the available themes out there?
    return this.getLoadedNames();
  }

  /*
  Section: Accessing Loaded Themes
  */

  // Public: Returns an {Array} of {String}s of all the loaded theme names.
  getLoadedThemeNames() {
    return this.getLoadedThemes().map(theme => theme.name);
  }

  // Public: Returns an {Array} of all the loaded themes.
  getLoadedThemes() {
    return this.packageManager
      .getLoadedPackages()
      .filter(pack => pack.isTheme());
  }

  /*
  Section: Accessing Active Themes
  */

  // Public: Returns an {Array} of {String}s of all the active theme names.
  getActiveThemeNames() {
    return this.getActiveThemes().map(theme => theme.name);
  }

  // Public: Returns an {Array} of all the active themes.
  getActiveThemes() {
    return this.packageManager
      .getActivePackages()
      .filter(pack => pack.isTheme());
  }

  activatePackages() {
    return this.activateThemes();
  }

  /*
  Section: Managing Enabled Themes
  */

  warnForNonExistentThemes() {
    let themeNames = this.config.get('core.themes') || [];
    if (!Array.isArray(themeNames)) {
      themeNames = [themeNames];
    }
    for (let themeName of themeNames) {
      if (
        !themeName ||
        typeof themeName !== 'string' ||
        !this.packageManager.resolvePackagePath(themeName)
      ) {
        console.warn(`Enabled theme '${themeName}' is not installed.`);
      }
    }
  }

  // Public: Get the enabled theme names from the config.
  //
  // Returns an array of theme names in the order that they should be activated.
  getEnabledThemeNames() {
    let themeNames = this.config.get('core.themes') || [];
    if (!Array.isArray(themeNames)) {
      themeNames = [themeNames];
    }
    themeNames = themeNames.filter(
      themeName =>
        typeof themeName === 'string' &&
        this.packageManager.resolvePackagePath(themeName)
    );

    // Use a built-in syntax and UI theme any time the configured themes are not
    // available.
    if (themeNames.length < 2) {
      const builtInThemeNames = [
        'atom-dark-syntax',
        'atom-dark-ui',
        'atom-light-syntax',
        'atom-light-ui',
        'base16-tomorrow-dark-theme',
        'base16-tomorrow-light-theme',
        'solarized-dark-syntax',
        'solarized-light-syntax'
      ];
      themeNames = _.intersection(themeNames, builtInThemeNames);
      if (themeNames.length === 0) {
        themeNames = ['one-dark-syntax', 'one-dark-ui'];
      } else if (themeNames.length === 1) {
        if (themeNames[0].endsWith('-ui')) {
          themeNames.unshift('one-dark-syntax');
        } else {
          themeNames.push('one-dark-ui');
        }
      }
    }

    // Reverse so the first (top) theme is loaded after the others. We want
    // the first/top theme to override later themes in the stack.
    return themeNames.reverse();
  }

  /*
  Section: Private
  */

  // Resolve and apply the stylesheet specified by the path.
  //
  // This supports both CSS and Less stylesheets.
  //
  // * `stylesheetPath` A {String} path to the stylesheet that can be an absolute
  //   path or a relative path that will be resolved against the load path.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // required stylesheet.
  requireStylesheet(
    stylesheetPath,
    priority,
    skipDeprecatedSelectorsTransformation
  ) {
    let fullPath = this.resolveStylesheet(stylesheetPath);
    if (fullPath) {
      const content = this.loadStylesheet(fullPath);
      return this.applyStylesheet(
        fullPath,
        content,
        priority,
        skipDeprecatedSelectorsTransformation
      );
    } else {
      throw new Error(`Could not find a file at path '${stylesheetPath}'`);
    }
  }

  unwatchUserStylesheet() {
    if (this.userStylesheetSubscriptions != null)
      this.userStylesheetSubscriptions.dispose();
    this.userStylesheetSubscriptions = null;
    this.userStylesheetFile = null;
    if (this.userStyleSheetDisposable != null)
      this.userStyleSheetDisposable.dispose();
    this.userStyleSheetDisposable = null;
  }

  loadUserStylesheet() {
    this.unwatchUserStylesheet();

    const userStylesheetPath = this.styleManager.getUserStyleSheetPath();
    if (!fs.isFileSync(userStylesheetPath)) {
      return;
    }

    try {
      this.userStylesheetFile = new File(userStylesheetPath);
      this.userStylesheetSubscriptions = new CompositeDisposable();
      const reloadStylesheet = () => this.loadUserStylesheet();
      this.userStylesheetSubscriptions.add(
        this.userStylesheetFile.onDidChange(reloadStylesheet)
      );
      this.userStylesheetSubscriptions.add(
        this.userStylesheetFile.onDidRename(reloadStylesheet)
      );
      this.userStylesheetSubscriptions.add(
        this.userStylesheetFile.onDidDelete(reloadStylesheet)
      );
    } catch (error) {
      const message = `\
Unable to watch path: \`${path.basename(userStylesheetPath)}\`. Make sure
you have permissions to \`${userStylesheetPath}\`.

On linux there are currently problems with watch sizes. See
[this document][watches] for more info.
[watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path\
`;
      this.notificationManager.addError(message, { dismissable: true });
    }

    let userStylesheetContents;
    try {
      userStylesheetContents = this.loadStylesheet(userStylesheetPath, true);
    } catch (error) {
      return;
    }

    this.userStyleSheetDisposable = this.styleManager.addStyleSheet(
      userStylesheetContents,
      { sourcePath: userStylesheetPath, priority: 2 }
    );
  }

  loadBaseStylesheets() {
    this.reloadBaseStylesheets();
  }

  reloadBaseStylesheets() {
    this.requireStylesheet('../static/atom', -2, true);
  }

  stylesheetElementForId(id) {
    const escapedId = id.replace(/\\/g, '\\\\');
    return document.head.querySelector(
      `atom-styles style[source-path="${escapedId}"]`
    );
  }

  resolveStylesheet(stylesheetPath) {
    if (path.extname(stylesheetPath).length > 0) {
      return fs.resolveOnLoadPath(stylesheetPath);
    } else {
      return fs.resolveOnLoadPath(stylesheetPath, ['css', 'less']);
    }
  }

  loadStylesheet(stylesheetPath, importFallbackVariables) {
    if (path.extname(stylesheetPath) === '.less') {
      return this.loadLessStylesheet(stylesheetPath, importFallbackVariables);
    } else {
      return fs.readFileSync(stylesheetPath, 'utf8');
    }
  }

  loadLessStylesheet(lessStylesheetPath, importFallbackVariables = false) {
    if (this.lessCache == null) {
      this.lessCache = new LessCompileCache({
        resourcePath: this.resourcePath,
        lessSourcesByRelativeFilePath: this.lessSourcesByRelativeFilePath,
        importedFilePathsByRelativeImportPath: this
          .importedFilePathsByRelativeImportPath,
        importPaths: this.getImportPaths()
      });
    }

    try {
      if (importFallbackVariables) {
        const baseVarImports = `\
@import "variables/ui-variables";
@import "variables/syntax-variables";\
`;
        const relativeFilePath = path.relative(
          this.resourcePath,
          lessStylesheetPath
        );
        const lessSource = this.lessSourcesByRelativeFilePath[relativeFilePath];

        let content, digest;
        if (lessSource != null) {
          ({ content } = lessSource);
          ({ digest } = lessSource);
        } else {
          content =
            baseVarImports + '\n' + fs.readFileSync(lessStylesheetPath, 'utf8');
          digest = null;
        }

        return this.lessCache.cssForFile(lessStylesheetPath, content, digest);
      } else {
        return this.lessCache.read(lessStylesheetPath);
      }
    } catch (error) {
      let detail, message;
      error.less = true;
      if (error.line != null) {
        // Adjust line numbers for import fallbacks
        if (importFallbackVariables) {
          error.line -= 2;
        }

        message = `Error compiling Less stylesheet: \`${lessStylesheetPath}\``;
        detail = `Line number: ${error.line}\n${error.message}`;
      } else {
        message = `Error loading Less stylesheet: \`${lessStylesheetPath}\``;
        detail = error.message;
      }

      this.notificationManager.addError(message, { detail, dismissable: true });
      throw error;
    }
  }

  removeStylesheet(stylesheetPath) {
    if (this.styleSheetDisposablesBySourcePath[stylesheetPath] != null) {
      this.styleSheetDisposablesBySourcePath[stylesheetPath].dispose();
    }
  }

  applyStylesheet(path, text, priority, skipDeprecatedSelectorsTransformation) {
    this.styleSheetDisposablesBySourcePath[
      path
    ] = this.styleManager.addStyleSheet(text, {
      priority,
      skipDeprecatedSelectorsTransformation,
      sourcePath: path
    });

    return this.styleSheetDisposablesBySourcePath[path];
  }

  activateThemes() {
    return new Promise(resolve => {
      // @config.observe runs the callback once, then on subsequent changes.
      this.config.observe('core.themes', () => {
        this.deactivateThemes().then(() => {
          this.warnForNonExistentThemes();
          this.refreshLessCache(); // Update cache for packages in core.themes config

          const promises = [];
          for (const themeName of this.getEnabledThemeNames()) {
            if (this.packageManager.resolvePackagePath(themeName)) {
              promises.push(this.packageManager.activatePackage(themeName));
            } else {
              console.warn(
                `Failed to activate theme '${themeName}' because it isn't installed.`
              );
            }
          }

          return Promise.all(promises).then(() => {
            this.addActiveThemeClasses();
            this.refreshLessCache(); // Update cache again now that @getActiveThemes() is populated
            this.loadUserStylesheet();
            this.reloadBaseStylesheets();
            this.initialLoadComplete = true;
            this.emitter.emit('did-change-active-themes');
            resolve();
          });
        });
      });
    });
  }

  deactivateThemes() {
    this.removeActiveThemeClasses();
    this.unwatchUserStylesheet();
    const results = this.getActiveThemes().map(pack =>
      this.packageManager.deactivatePackage(pack.name)
    );
    return Promise.all(
      results.filter(r => r != null && typeof r.then === 'function')
    );
  }

  isInitialLoadComplete() {
    return this.initialLoadComplete;
  }

  addActiveThemeClasses() {
    const workspaceElement = this.viewRegistry.getView(this.workspace);
    if (workspaceElement) {
      for (const pack of this.getActiveThemes()) {
        workspaceElement.classList.add(`theme-${pack.name}`);
      }
    }
  }

  removeActiveThemeClasses() {
    const workspaceElement = this.viewRegistry.getView(this.workspace);
    for (const pack of this.getActiveThemes()) {
      workspaceElement.classList.remove(`theme-${pack.name}`);
    }
  }

  refreshLessCache() {
    if (this.lessCache) this.lessCache.setImportPaths(this.getImportPaths());
  }

  getImportPaths() {
    let themePaths;
    const activeThemes = this.getActiveThemes();
    if (activeThemes.length > 0) {
      themePaths = activeThemes
        .filter(theme => theme)
        .map(theme => theme.getStylesheetsPath());
    } else {
      themePaths = [];
      for (const themeName of this.getEnabledThemeNames()) {
        const themePath = this.packageManager.resolvePackagePath(themeName);
        if (themePath) {
          const deprecatedPath = path.join(themePath, 'stylesheets');
          if (fs.isDirectorySync(deprecatedPath)) {
            themePaths.push(deprecatedPath);
          } else {
            themePaths.push(path.join(themePath, 'styles'));
          }
        }
      }
    }

    return themePaths.filter(themePath => fs.isDirectorySync(themePath));
  }
};
