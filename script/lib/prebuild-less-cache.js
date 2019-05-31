'use strict';

const fs = require('fs');
const klawSync = require('klaw-sync');
const glob = require('glob');
const path = require('path');
const LessCache = require('less-cache');

const CONFIG = require('../config');
const LESS_CACHE_VERSION = require('less-cache/package.json').version;
const FALLBACK_VARIABLE_IMPORTS =
  '@import "variables/ui-variables";\n@import "variables/syntax-variables";\n';

module.exports = function() {
  const cacheDirPath = path.join(
    CONFIG.intermediateAppPath,
    'less-compile-cache'
  );
  console.log(`Generating pre-built less cache in ${cacheDirPath}`);

  // Group bundled packages into UI themes, syntax themes, and non-theme packages
  const uiThemes = [];
  const syntaxThemes = [];
  const nonThemePackages = [];
  for (let packageName in CONFIG.appMetadata.packageDependencies) {
    const packageMetadata = require(path.join(
      CONFIG.intermediateAppPath,
      'node_modules',
      packageName,
      'package.json'
    ));
    if (packageMetadata.theme === 'ui') {
      uiThemes.push(packageName);
    } else if (packageMetadata.theme === 'syntax') {
      syntaxThemes.push(packageName);
    } else {
      nonThemePackages.push(packageName);
    }
  }

  CONFIG.snapshotAuxiliaryData.lessSourcesByRelativeFilePath = {};
  function saveIntoSnapshotAuxiliaryData(absoluteFilePath, content) {
    const relativeFilePath = path.relative(
      CONFIG.intermediateAppPath,
      absoluteFilePath
    );
    if (
      !CONFIG.snapshotAuxiliaryData.lessSourcesByRelativeFilePath.hasOwnProperty(
        relativeFilePath
      )
    ) {
      CONFIG.snapshotAuxiliaryData.lessSourcesByRelativeFilePath[
        relativeFilePath
      ] = {
        content: content,
        digest: LessCache.digestForContent(content)
      };
    }
  }

  CONFIG.snapshotAuxiliaryData.importedFilePathsByRelativeImportPath = {};
  // Warm cache for every combination of the default UI and syntax themes,
  // because themes assign variables which may be used in any style sheet.
  for (let uiTheme of uiThemes) {
    for (let syntaxTheme of syntaxThemes) {
      // Build a LessCache instance with import paths based on the current theme combination
      const lessCache = new LessCache({
        cacheDir: cacheDirPath,
        fallbackDir: path.join(
          CONFIG.atomHomeDirPath,
          'compile-cache',
          'prebuild-less',
          LESS_CACHE_VERSION
        ),
        syncCaches: true,
        resourcePath: CONFIG.intermediateAppPath,
        importPaths: [
          path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            syntaxTheme,
            'styles'
          ),
          path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            uiTheme,
            'styles'
          ),
          path.join(CONFIG.intermediateAppPath, 'static', 'variables'),
          path.join(CONFIG.intermediateAppPath, 'static')
        ]
      });

      // Store file paths located at the import paths so that we can avoid scanning them at runtime.
      for (const absoluteImportPath of lessCache.getImportPaths()) {
        const relativeImportPath = path.relative(
          CONFIG.intermediateAppPath,
          absoluteImportPath
        );
        if (
          !CONFIG.snapshotAuxiliaryData.importedFilePathsByRelativeImportPath.hasOwnProperty(
            relativeImportPath
          )
        ) {
          CONFIG.snapshotAuxiliaryData.importedFilePathsByRelativeImportPath[
            relativeImportPath
          ] = [];
          for (const importedFile of klawSync(absoluteImportPath, {
            nodir: true
          })) {
            CONFIG.snapshotAuxiliaryData.importedFilePathsByRelativeImportPath[
              relativeImportPath
            ].push(
              path.relative(CONFIG.intermediateAppPath, importedFile.path)
            );
          }
        }
      }

      // Cache all styles in static; don't append variable imports
      for (let lessFilePath of glob.sync(
        path.join(CONFIG.intermediateAppPath, 'static', '**', '*.less')
      )) {
        cacheCompiledCSS(lessCache, lessFilePath, false);
      }

      // Cache styles for all bundled non-theme packages
      for (let nonThemePackage of nonThemePackages) {
        for (let lessFilePath of glob.sync(
          path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            nonThemePackage,
            '**',
            '*.less'
          )
        )) {
          cacheCompiledCSS(lessCache, lessFilePath, true);
        }
      }

      // Cache styles for this UI theme
      const uiThemeMainPath = path.join(
        CONFIG.intermediateAppPath,
        'node_modules',
        uiTheme,
        'index.less'
      );
      cacheCompiledCSS(lessCache, uiThemeMainPath, true);
      for (let lessFilePath of glob.sync(
        path.join(
          CONFIG.intermediateAppPath,
          'node_modules',
          uiTheme,
          '**',
          '*.less'
        )
      )) {
        if (lessFilePath !== uiThemeMainPath) {
          saveIntoSnapshotAuxiliaryData(
            lessFilePath,
            fs.readFileSync(lessFilePath, 'utf8')
          );
        }
      }

      // Cache styles for this syntax theme
      const syntaxThemeMainPath = path.join(
        CONFIG.intermediateAppPath,
        'node_modules',
        syntaxTheme,
        'index.less'
      );
      cacheCompiledCSS(lessCache, syntaxThemeMainPath, true);
      for (let lessFilePath of glob.sync(
        path.join(
          CONFIG.intermediateAppPath,
          'node_modules',
          syntaxTheme,
          '**',
          '*.less'
        )
      )) {
        if (lessFilePath !== syntaxThemeMainPath) {
          saveIntoSnapshotAuxiliaryData(
            lessFilePath,
            fs.readFileSync(lessFilePath, 'utf8')
          );
        }
      }
    }
  }

  for (let lessFilePath of glob.sync(
    path.join(
      CONFIG.intermediateAppPath,
      'node_modules',
      'atom-ui',
      '**',
      '*.less'
    )
  )) {
    saveIntoSnapshotAuxiliaryData(
      lessFilePath,
      fs.readFileSync(lessFilePath, 'utf8')
    );
  }

  function cacheCompiledCSS(lessCache, lessFilePath, importFallbackVariables) {
    let lessSource = fs.readFileSync(lessFilePath, 'utf8');
    if (importFallbackVariables) {
      lessSource = FALLBACK_VARIABLE_IMPORTS + lessSource;
    }
    lessCache.cssForFile(lessFilePath, lessSource);
    saveIntoSnapshotAuxiliaryData(lessFilePath, lessSource);
  }
};
