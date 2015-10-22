// We won't have access to es_natives.js here, so this means we have to provide
// them ourselves. The best way we can overcome this is to avoid using such
// functions wherever possible.

// TODO: can we load a v8 context that has all these primitives and compile the
// snapshot using that environment instead?
Object.prototype.toString = function() {
  return "[object " + typeof this + "]";
};

var cachedFunctions = {
};

function SnapshotModule(id, parent) {
  this.id = id;
  this.exports = {};
  this.parent = parent;
  if (parent && parent.children) {
    parent.children.push(this);
  }

  this.filename = null;
  this.loaded = false;
  this.children = [];
}

SnapshotModule._resolveFilename = function (request, parent) {
  // this should expand the filename into a full path, so that we can directly
  // fetch it from the cache.
  return request;
}

SnapshotModule._load = function(request, parent) {
  var filename = SnapshotModule._resolveFilename(request, parent);
  var snapshotModule = new SnapshotModule(filename, parent);
  snapshotModule.load(filename);
  return snapshotModule.exports;
};

// Given a file name, pass it to the proper extension handler.
SnapshotModule.prototype.load = function(filename) {
  this.filename = filename;
  this._compile(filename);
  this.loaded = true;
};

// Loads a module at the given file path. Returns that module's
// `exports` property.
SnapshotModule.prototype.require = function(path) {
  return SnapshotModule._load(path, this);
};

SnapshotModule.prototype._compile = function(filename) {
  var self = this;

  function require(path) {
    return self.require(path);
  }

  require.resolve = function(request) {
    return SnapshotModule._resolveFilename(request, self);
  };
  // var dirname = cachedFunctions[filename].dirname;
  var dirname = "";
  // we need to make sure to not use process/global inside the code we run on the snapshot.
  // here we may probably shim it and re-assign it later, when node has loaded.
  var args = [self.exports, require, self, filename, dirname];
  return cachedFunctions[filename].apply(self.exports, args);
};

var snapshot = new SnapshotModule("snapshot", null);
var AtomEnvironment = snapshot.require("underscore-plus");
