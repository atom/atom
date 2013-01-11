var $native = {};
(function() {

  native function exists(path);
  $native.exists = exists;

  native function read(path);
  $native.read = read;

  native function write(path, content);
  $native.write = write;

  native function absolute(path);
  $native.absolute = absolute;

  native function traverseTree(path, onFile, onDirectory);
  $native.traverseTree = traverseTree;

  native function getAllFilePathsAsync(path, callback);
  $native.getAllFilePathsAsync = getAllFilePathsAsync;

  native function isFile(path);
  $native.isFile = isFile;

  native function isDirectory(path);
  $native.isDirectory = isDirectory;

  native function remove(path);
  $native.remove = remove;

  native function open(path);
  $native.open = open;

  native function quit();
  $native.quit = quit;

  native function writeToPasteboard(text);
  $native.writeToPasteboard = writeToPasteboard;

  native function readFromPasteboard();
  $native.readFromPasteboard = readFromPasteboard;

  native function watchPath(path);
  $native.watchPath = watchPath;

  native function unwatchPath(path, callbackId);
  $native.unwatchPath = unwatchPath;

  native function getWatchedPaths();
  $native.getWatchedPaths = getWatchedPaths;

  native function unwatchAllPaths();
  $native.unwatchAllPaths = unwatchAllPaths;

  native function makeDirectory(path);
  $native.makeDirectory = makeDirectory;

  native function move(sourcePath, targetPath);
  $native.move = move;

  native function moveToTrash(path);
  $native.moveToTrash = moveToTrash;

  native function reload();
  $native.reload = reload;

  native function lastModified(path);
  $native.lastModified = lastModified;

  native function md5ForPath(path);
  $native.md5ForPath = md5ForPath;

  native function exec(command, options, callback);
  $native.exec = exec;

  native function getPlatform();
  $native.getPlatform = getPlatform;

  native function setWindowState(state);
  $native.setWindowState = setWindowState;

  native function getWindowState();
  $native.getWindowState = getWindowState;

})();
