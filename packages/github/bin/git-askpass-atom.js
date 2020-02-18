const net = require('net');
const {execFile} = require('child_process');

const sockAddr = process.argv[2];
const prompt = process.argv[3];

const diagnosticsEnabled = process.env.GIT_TRACE && process.env.GIT_TRACE.length !== 0;
const userAskPass = process.env.ATOM_GITHUB_ORIGINAL_SSH_ASKPASS || '';
const workdirPath = process.env.ATOM_GITHUB_WORKDIR_PATH;

function log(message) {
  if (!diagnosticsEnabled) {
    return;
  }

  process.stderr.write(`git-askpass-atom: ${message}\n`);
}

function getSockOptions() {
  const common = {
    allowHalfOpen: true,
  };

  const tcp = /tcp:(\d+)/.exec(sockAddr);
  if (tcp) {
    const port = parseInt(tcp[1], 10);
    if (Number.isNaN(port)) {
      throw new Error(`Non-integer TCP port: ${tcp[1]}`);
    }
    return {port, host: 'localhost', ...common};
  }

  const unix = /unix:(.+)/.exec(sockAddr);
  if (unix) {
    return {path: unix[1], ...common};
  }

  throw new Error(`Malformed $ATOM_GITHUB_SOCK_ADDR: ${sockAddr}`);
}

function userHelper() {
  return new Promise((resolve, reject) => {
    if (userAskPass.length === 0) {
      log('no user askpass specified');

      reject(new Error('No user SSH_ASKPASS'));
      return;
    }

    log(`attempting user askpass: ${userAskPass}`);

    // Present on ${PATH} even in Windows from dugite!
    execFile('sh', ['-c', `'${userAskPass}' '${prompt}'`], {cwd: workdirPath}, (err, stdout, stderr) => {
      if (err) {
        log(`user askpass failed. this is ok\n${err.stack}`);

        reject(err);
        return;
      }

      log('collected password from user askpass');
      resolve(stdout);
    });
  });
}

function dialog() {
  const sockOptions = getSockOptions();
  const query = {prompt, includeUsername: false, pid: process.pid};
  log('requesting dialog through Atom socket');
  log(`prompt = "${prompt}"`);

  return new Promise((resolve, reject) => {
    const socket = net.connect(sockOptions, () => {
      log('connection established');
      let payload = '';

      socket.on('data', data => {
        payload += data;
      });
      socket.on('end', () => {
        log('Atom socket stream terminated');

        try {
          const reply = JSON.parse(payload);
          log('Atom reply parsed');
          resolve(reply.password);
        } catch (err) {
          log('Unable to parse reply from Atom');
          reject(err);
        }
      });

      log('writing query');
      socket.end(JSON.stringify(query), 'utf8', () => log('query written'));
    });
    socket.setEncoding('utf8');
  });
}

userHelper()
  .catch(() => dialog())
  .then(password => {
    process.stdout.write(password);
    log('success');
    process.exit(0);
  }, err => {
    process.stderr.write(`Unable to prompt through Atom:\n${err.stack}`);
    log('failure');
    process.exit(1);
  });
