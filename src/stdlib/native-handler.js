var $native = {};
(function() {

  native function exists();
  $native.exists = exists;

  native function alert();
  $native.alert = alert;

  native function read();
  $native.read = read;

  native function write();
  $native.write = write;

  native function absolute();
  $native.absolute = absolute;

  native function list();
  $native.list = list;

  native function isFile();
  $native.isFile = isFile;

  native function isDirectory();
  $native.isDirectory = isDirectory;

  native function remove();
  $native.remove = remove;

  native function asyncList();
  $native.asyncList = asyncList;

  native function open();
  $native.open = open;

  native function openDialog();
  $native.openDialog = openDialog;

  native function quit();
  $native.quit = quit;

  native function writeToPasteboard();
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

  native function exit();
  $native.exit = exit;

  native function watchPath();
  $native.watchPath = watchPath;

  native function unwatchPath();
  $native.unwatchPath = unwatchPath;

  native function makeDirectory();
  $native.makeDirectory = makeDirectory;

  native function move();
  $native.move = move;

  native function moveToTrash();
  $native.moveToTrash = moveToTrash;

  native function reload();
  $native.reload = reload;

  native function lastModified();
  $native.lastModified = lastModified;

  native function md5ForPath();
  $native.md5ForPath = md5ForPath;

  native function exec();
  $native.exec = exec;

  native function getPlatform();
  $native.getPlatform = getPlatform;

})();
