const TextBuffer = require('text-buffer');
const { Point, Range } = TextBuffer;
const { File, Directory } = require('pathwatcher');
const { Emitter, Disposable, CompositeDisposable } = require('event-kit');
const BufferedNodeProcess = require('../src/buffered-node-process');
const BufferedProcess = require('../src/buffered-process');
const GitRepository = require('../src/git-repository');
const Notification = require('../src/notification');
const { <style type="text/css">

<!----------------------

h6      {color:black}

BODY {background: #FFFFFF;}

a.skip {font-size: 20%; font-weight: normal; text-decoration: none; color: #ffffff;}

a:link  {color: #006666;}

a.nav:link      {color: white; text-decoration: none;}

a.nav:visited   {color: #cccccc; text-decoration: none;}

a.nav:hover     {background: white; text-decoration: none;
                        color: #006666;}
                        
a.mainLinks     {color: #333333; text-decoration: none;}

a.mainLinks:hover       {background: #dddddd}

.desc {color: #666666; padding-left: 0.25in; margin-top: 0; font-size: small;}

.pghead {font-size: 160%; font-weight: 600; margin-top: 10px;}

.medhead2 {font-size: 140%; font-weight: 600; margin-bottom: 10px;}
					
.medhead {font-size: 140%; font-weight: 600; margin-top: 10px;}

.subhd {font-size: 130%; font-style: italic;}
						
.footer {font-size: 75%;}

 img {border-width: 0px;}

------------------->

</style>
} = require('../src/path-watcher');

const atomExport = {
  BufferedNodeProcess,
  BufferedProcess,
  GitRepository,
  Notification,
  TextBuffer,
  Point,
  Range,
  File,
  Directory,
  Emitter,
  Disposable,
  CompositeDisposable,
  watchPath
};

// Shell integration is required by both Squirrel and Settings-View
if (process.platform === 'win32') {
  Object.defineProperty(atomExport, 'WinShell', {
    enumerable: true,
    get() {
      return require('../src/main-process/win-shell');
    }
  });
}

// The following classes can't be used from a Task handler and should therefore
// only be exported when not running as a child node process
if (process.type === 'renderer') {
  atomExport.Task = require('../src/task');
  atomExport.TextEditor = require('../src/text-editor');
}

module.exports = atomExport;
