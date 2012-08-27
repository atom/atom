var $native = {};
(function() {

  native function exists(path);
  $native.exists = exists;

  native function alert(message, detailedMessage, buttonNamesAndCallbacks);
  $native.alert = alert;

  native function read(path);
  $native.read = read;

  native function write(path, content);
  $native.write = write;

  native function absolute(path);
  $native.absolute = absolute;

  native function list(path, recursive);
  $native.list = list;

  native function isFile(path);
  $native.isFile = isFile;

  native function isDirectory(path);
  $native.isDirectory = isDirectory;

  native function remove(path);
  $native.remove = remove;

  native function asyncList(path, recursive, callback);
  $native.asyncList = asyncList;

  native function open(path);
  $native.open = open;

  native function openDialog();
  $native.openDialog = openDialog;

  native function quit();
  $native.quit = quit;

  native function writeToPasteboard(text);
  $native.writeToPasteboard = writeToPasteboard;

  native function readFromPasteboard();
  $native.readFromPasteboard = readFromPasteboard;

  native function showDevTools();
  $native.showDevTools = showDevTools;

  native function toggleDevTools();
  $native.toggleDevTools = toggleDevTools;

  native function newWindow();
  $native.newWindow = newWindow;

  native function saveDialog();
  $native.saveDialog = saveDialog;

  native function exit(status);
  $native.exit = exit;

  native function watchPath(path);
  $native.watchPath = watchPath;

  native function unwatchPath(path, callbackId);
  $native.unwatchPath = unwatchPath;

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

})();
