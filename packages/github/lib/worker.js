const qs = require('querystring');

const {remote, ipcRenderer: ipc} = require('electron');
const {GitProcess} = require('dugite');


class AverageTracker {
  constructor({limit} = {limit: 10}) {
    // for now this serves a dual purpose - # of values tracked AND # discarded prior to starting avg calculation
    this.limit = limit;
    this.sum = 0;
    this.values = [];
  }

  addValue(value) {
    if (this.values.length >= this.limit) {
      const discardedValue = this.values.shift();
      this.sum -= discardedValue;
    }
    this.values.push(value);
    this.sum += value;
  }

  getAverage() {
    if (this.enoughData()) {
      return this.sum / this.limit;
    } else {
      return null;
    }
  }

  getLimit() {
    return this.limit;
  }

  enoughData() {
    return this.values.length === this.limit;
  }
}

const query = qs.parse(window.location.search.substr(1));
const sourceWebContentsId = remote.getCurrentWindow().webContents.id;
const operationCountLimit = parseInt(query.operationCountLimit, 10);
const averageTracker = new AverageTracker({limit: operationCountLimit});
const childPidsById = new Map();

const destroyRenderer = () => {
  if (!managerWebContents.isDestroyed()) {
    managerWebContents.removeListener('crashed', destroyRenderer);
    managerWebContents.removeListener('destroyed', destroyRenderer);
  }
  const win = remote.BrowserWindow.fromWebContents(remote.getCurrentWebContents());
  if (win && !win.isDestroyed()) {
    win.destroy();
  }
};
const managerWebContentsId = parseInt(query.managerWebContentsId, 10);
const managerWebContents = remote.webContents.fromId(managerWebContentsId);
if (managerWebContents && !managerWebContents.isDestroyed()) {
  managerWebContents.on('crashed', destroyRenderer);
  managerWebContents.on('destroyed', destroyRenderer);
  window.onbeforeunload = () => {
    managerWebContents.removeListener('crashed', destroyRenderer);
    managerWebContents.removeListener('destroyed', destroyRenderer);
  };
}

const channelName = query.channelName;
ipc.on(channelName, (event, {type, data}) => {
  if (type === 'git-exec') {
    const {args, workingDir, options, id} = data;
    if (args) {
      document.getElementById('command').textContent = `git ${args.join(' ')}`;
    }

    options.processCallback = child => {
      childPidsById.set(id, child.pid);

      child.on('error', err => {
        event.sender.sendTo(managerWebContentsId, channelName, {
          sourceWebContentsId,
          type: 'git-spawn-error',
          data: {id, err},
        });
      });

      child.stdin.on('error', err => {
        event.sender.sendTo(managerWebContentsId, channelName, {
          sourceWebContentsId,
          type: 'git-stdin-error',
          data: {id, stdin: options.stdin, err},
        });
      });
    };

    const spawnStart = performance.now();
    GitProcess.exec(args, workingDir, options)
      .then(({stdout, stderr, exitCode}) => {
        const timing = {
          spawnTime: spawnEnd - spawnStart,
          execTime: performance.now() - spawnEnd,
        };
        childPidsById.delete(id);
        event.sender.sendTo(managerWebContentsId, channelName, {
          sourceWebContentsId,
          type: 'git-data',
          data: {
            id,
            average: averageTracker.getAverage(),
            results: {stdout, stderr, exitCode, timing},
          },
        });
      }, err => {
        const timing = {
          spawnTime: spawnEnd - spawnStart,
          execTime: performance.now() - spawnEnd,
        };
        childPidsById.delete(id);
        event.sender.sendTo(managerWebContentsId, channelName, {
          sourceWebContentsId,
          type: 'git-data',
          data: {
            id,
            average: averageTracker.getAverage(),
            results: {
              stdout: err.stdout,
              stderr: err.stderr,
              exitCode: err.code,
              signal: err.signal,
              timing,
            },
          },
        });
      });
    const spawnEnd = performance.now();
    averageTracker.addValue(spawnEnd - spawnStart);

    // TODO: consider using this to avoid duplicate write operations upon crashing.
    // For now we won't do this to avoid clogging up ipc channel
    // event.sender.sendTo(managerWebContentsId, channelName, {sourceWebContentsId, type: 'exec-started', data: {id}});

    if (averageTracker.enoughData() && averageTracker.getAverage() > 20) {
      event.sender.sendTo(managerWebContentsId, channelName, {type: 'slow-spawns'});
    }
  } else if (type === 'git-cancel') {
    const {id} = data;
    const childPid = childPidsById.get(id);
    if (childPid !== undefined) {
      require('tree-kill')(childPid, 'SIGINT', () => {
        event.sender.sendTo(managerWebContentsId, channelName, {
          sourceWebContentsId,
          type: 'git-cancelled',
          data: {id, childPid},
        });
      });
      childPidsById.delete(id);
    }
  } else {
    throw new Error(`Could not identify type ${type}`);
  }
});

ipc.sendTo(managerWebContentsId, channelName, {sourceWebContentsId, type: 'renderer-ready', data: {pid: process.pid}});
