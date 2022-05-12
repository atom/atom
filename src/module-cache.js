const Module = require('module');
const path = require('path');
const semver = require('semver');

// Extend semver.Range to memoize matched versions for speed
class Range extends semver.Range {
  constructor() {
    super(...arguments);
    this.matchedVersions = new Set();
    this.unmatchedVersions = new Set();
  }

  test(version) {
    if (this.matchedVersions.has(version)) return true;
    if (this.unmatchedVersions.has(version)) return false;

    const matches = super.test(...arguments);
    if (matches) {
      this.matchedVersions.add(version);
    } else {
      this.unmatchedVersions.add(version);
    }
    return matches;
  }
}

let nativeModules = null;

const cache = {
  builtins: {},
  debug: false,
  dependencies: {},
  extensions: {},
  folders: {},
  ranges: {},
  registered: false,
  resourcePath: null,
  resourcePathWithTrailingSlash: null
};

// isAbsolute is inlined from fs-plus so that fs-plus itself can be required
// from this cache.
let isAbsolute;
if (process.platform === 'win32') {
  isAbsolute = pathToCheck =>
    pathToCheck &&
    (pathToCheck[1] === ':' ||
      (pathToCheck[0] === '\\' && pathToCheck[1] === '\\'));
} else {
  isAbsolute = pathToCheck => pathToCheck && pathToCheck[0] === '/';
}

const isCorePath = pathToCheck =>
  pathToCheck.startsWith(cache.resourcePathWithTrailingSlash);

function loadDependencies(modulePath, rootPath, rootMetadata, moduleCache) {
  const fs = require('fs-plus');

  for (let childPath of fs.listSync(path.join(modulePath, 'node_modules'))) {
    if (path.basename(childPath) === '.bin') continue;
    if (
      rootPath === modulePath &&
      (rootMetadata.packageDependencies &&
        rootMetadata.packageDependencies.hasOwnProperty(
          path.basename(childPath)
        ))
    ) {
      continue;
    }

    const childMetadataPath = path.join(childPath, 'package.json');
    if (!fs.isFileSync(childMetadataPath)) continue;

    const childMetadata = JSON.parse(fs.readFileSync(childMetadataPath));
    if (childMetadata && childMetadata.version) {
      let mainPath;
      try {
        mainPath = require.resolve(childPath);
      } catch (error) {
        mainPath = null;
      }

      if (mainPath) {
        moduleCache.dependencies.push({
          name: childMetadata.name,
          version: childMetadata.version,
          path: path.relative(rootPath, mainPath)
        });
      }

      loadDependencies(childPath, rootPath, rootMetadata, moduleCache);
    }
  }
}

function loadFolderCompatibility(
  modulePath,
  rootPath,
  rootMetadata,
  moduleCache
) {
  const fs = require('fs-plus');

  const metadataPath = path.join(modulePath, 'package.json');
  if (!fs.isFileSync(metadataPath)) return;

  const metadata = JSON.parse(fs.readFileSync(metadataPath));
  const dependencies = metadata.dependencies || {};

  for (let name in dependencies) {
    if (!semver.validRange(dependencies[name])) {
      delete dependencies[name];
    }
  }

  const onDirectory = childPath => path.basename(childPath) !== 'node_modules';

  const extensions = ['.js', '.coffee', '.json', '.node'];
  let paths = {};
  function onFile(childPath) {
    const needle = path.extname(childPath);
    if (extensions.includes(needle)) {
      const relativePath = path.relative(rootPath, path.dirname(childPath));
      paths[relativePath] = true;
    }
  }
  fs.traverseTreeSync(modulePath, onFile, onDirectory);

  paths = Object.keys(paths);
  if (paths.length > 0 && Object.keys(dependencies).length > 0) {
    moduleCache.folders.push({ paths, dependencies });
  }

  for (let childPath of fs.listSync(path.join(modulePath, 'node_modules'))) {
    if (path.basename(childPath) === '.bin') continue;
    if (
      rootPath === modulePath &&
      (rootMetadata.packageDependencies &&
        rootMetadata.packageDependencies.hasOwnProperty(
          path.basename(childPath)
        ))
    ) {
      continue;
    }
    loadFolderCompatibility(childPath, rootPath, rootMetadata, moduleCache);
  }
}

function loadExtensions(modulePath, rootPath, rootMetadata, moduleCache) {
  const fs = require('fs-plus');
  const extensions = ['.js', '.coffee', '.json', '.node'];
  const nodeModulesPath = path.join(rootPath, 'node_modules');

  function onFile(filePath) {
    filePath = path.relative(rootPath, filePath);
    const segments = filePath.split(path.sep);
    if (segments.includes('test')) return;
    if (segments.includes('tests')) return;
    if (segments.includes('spec')) return;
    if (segments.includes('specs')) return;
    if (
      segments.length > 1 &&
      !['exports', 'lib', 'node_modules', 'src', 'static', 'vendor'].includes(
        segments[0]
      )
    )
      return;

    const extension = path.extname(filePath);
    if (extensions.includes(extension)) {
      if (moduleCache.extensions[extension] == null) {
        moduleCache.extensions[extension] = [];
      }
      moduleCache.extensions[extension].push(filePath);
    }
  }

  function onDirectory(childPath) {
    // Don't include extensions from bundled packages
    // These are generated and stored in the package's own metadata cache
    if (rootMetadata.name === 'atom') {
      const parentPath = path.dirname(childPath);
      if (parentPath === nodeModulesPath) {
        const packageName = path.basename(childPath);
        if (
          rootMetadata.packageDependencies &&
          rootMetadata.packageDependencies.hasOwnProperty(packageName)
        )
          return false;
      }
    }

    return true;
  }

  fs.traverseTreeSync(rootPath, onFile, onDirectory);
}

function satisfies(version, rawRange) {
  let parsedRange;
  if (!(parsedRange = cache.ranges[rawRange])) {
    parsedRange = new Range(rawRange);
    cache.ranges[rawRange] = parsedRange;
  }
  return parsedRange.test(version);
}

function resolveFilePath(relativePath, parentModule) {
  if (!relativePath) return;
  if (!(parentModule && parentModule.filename)) return;
  if (relativePath[0] !== '.' && !isAbsolute(relativePath)) return;

  const resolvedPath = path.resolve(
    path.dirname(parentModule.filename),
    relativePath
  );
  if (!isCorePath(resolvedPath)) return;

  let extension = path.extname(resolvedPath);
  if (extension) {
    if (
      cache.extensions[extension] &&
      cache.extensions[extension].has(resolvedPath)
    )
      return resolvedPath;
  } else {
    for (extension in cache.extensions) {
      const paths = cache.extensions[extension];
      const resolvedPathWithExtension = `${resolvedPath}${extension}`;
      if (paths.has(resolvedPathWithExtension)) {
        return resolvedPathWithExtension;
      }
    }
  }
}

function resolveModulePath(relativePath, parentModule) {
  if (!relativePath) return;
  if (!(parentModule && parentModule.filename)) return;

  if (!nativeModules) nativeModules = process.binding('natives');
  if (nativeModules.hasOwnProperty(relativePath)) return;
  if (relativePath[0] === '.') return;
  if (isAbsolute(relativePath)) return;

  const folderPath = path.dirname(parentModule.filename);

  const range =
    cache.folders[folderPath] && cache.folders[folderPath][relativePath];
  if (!range) {
    const builtinPath = cache.builtins[relativePath];
    if (builtinPath) {
      return builtinPath;
    } else {
      return;
    }
  }

  const candidates = cache.dependencies[relativePath];
  if (candidates == null) return;

  for (let version in candidates) {
    const resolvedPath = candidates[version];
    if (Module._cache[resolvedPath] || isCorePath(resolvedPath)) {
      if (satisfies(version, range)) return resolvedPath;
    }
  }
}

function registerBuiltins(devMode) {
  if (
    devMode ||
    !cache.resourcePath.startsWith(`${process.resourcesPath}${path.sep}`)
  ) {
    const fs = require('fs-plus');
    const atomJsPath = path.join(cache.resourcePath, 'exports', 'atom.js');
    if (fs.isFileSync(atomJsPath)) {
      cache.builtins.atom = atomJsPath;
    }
  }
  if (cache.builtins.atom == null) {
    cache.builtins.atom = path.join(cache.resourcePath, 'exports', 'atom.js');
  }
}

exports.create = function(modulePath) {
  const fs = require('fs-plus');

  modulePath = fs.realpathSync(modulePath);
  const metadataPath = path.join(modulePath, 'package.json');
  const metadata = JSON.parse(fs.readFileSync(metadataPath));

  const moduleCache = {
    version: 1,
    dependencies: [],
    extensions: {},
    folders: []
  };

  loadDependencies(modulePath, modulePath, metadata, moduleCache);
  loadFolderCompatibility(modulePath, modulePath, metadata, moduleCache);
  loadExtensions(modulePath, modulePath, metadata, moduleCache);

  metadata._atomModuleCache = moduleCache;
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
};

exports.register = function({ resourcePath, devMode } = {}) {
  if (cache.registered) return;

  const originalResolveFilename = Module._resolveFilename;
  Module._resolveFilename = function(relativePath, parentModule) {
    let resolvedPath = resolveModulePath(relativePath, parentModule);
    if (!resolvedPath) {
      resolvedPath = resolveFilePath(relativePath, parentModule);
    }
    return resolvedPath || originalResolveFilename(relativePath, parentModule);
  };

  cache.registered = true;
  cache.resourcePath = resourcePath;
  cache.resourcePathWithTrailingSlash = `${resourcePath}${path.sep}`;
  registerBuiltins(devMode);
};

exports.add = function(directoryPath, metadata) {
  // path.join isn't used in this function for speed since path.join calls
  // path.normalize and all the paths are already normalized here.

  if (metadata == null) {
    try {
      metadata = require(`${directoryPath}${path.sep}package.json`);
    } catch (error) {
      return;
    }
  }

  const cacheToAdd = metadata && metadata._atomModuleCache;
  if (!cacheToAdd) return;

  for (const dependency of cacheToAdd.dependencies || []) {
    if (!cache.dependencies[dependency.name]) {
      cache.dependencies[dependency.name] = {};
    }
    if (!cache.dependencies[dependency.name][dependency.version]) {
      cache.dependencies[dependency.name][
        dependency.version
      ] = `${directoryPath}${path.sep}${dependency.path}`;
    }
  }

  for (const entry of cacheToAdd.folders || []) {
    for (const folderPath of entry.paths) {
      if (folderPath) {
        cache.folders[`${directoryPath}${path.sep}${folderPath}`] =
          entry.dependencies;
      } else {
        cache.folders[directoryPath] = entry.dependencies;
      }
    }
  }

  for (const extension in cacheToAdd.extensions) {
    const paths = cacheToAdd.extensions[extension];
    if (!cache.extensions[extension]) {
      cache.extensions[extension] = new Set();
    }
    for (let filePath of paths) {
      cache.extensions[extension].add(`${directoryPath}${path.sep}${filePath}`);
    }
  }
};

exports.cache = cache;

exports.Range = Range;
