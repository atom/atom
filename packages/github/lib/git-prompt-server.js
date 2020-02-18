import net from 'net';
import {Emitter} from 'event-kit';
import {normalizeGitHelperPath} from './helpers';

export default class GitPromptServer {
  constructor(gitTempDir) {
    this.emitter = new Emitter();
    this.gitTempDir = gitTempDir;
    this.address = null;
  }

  async start(promptForInput) {
    this.promptForInput = promptForInput;

    await this.gitTempDir.ensure();
    this.server = await this.startListening(this.gitTempDir.getSocketOptions());
  }

  getAddress() {
    /* istanbul ignore if */
    if (!this.address) {
      throw new Error('Server is not listening');
    } else if (this.address.port) {
      // TCP socket
      return `tcp:${this.address.port}`;
    } else {
      // Unix domain socket
      return `unix:${normalizeGitHelperPath(this.address)}`;
    }
  }

  startListening(socketOptions) {
    return new Promise(resolve => {
      const server = net.createServer({allowHalfOpen: true}, connection => {
        connection.setEncoding('utf8');

        let payload = '';
        connection.on('data', data => {
          payload += data;
        });

        connection.on('end', () => {
          this.handleData(connection, payload);
        });
      });

      server.listen(socketOptions, () => {
        this.address = server.address();
        resolve(server);
      });
    });
  }

  async handleData(connection, data) {
    let query;
    try {
      query = JSON.parse(data);
      const answer = await this.promptForInput(query);
      await new Promise(resolve => {
        connection.end(JSON.stringify(answer), 'utf8', resolve);
      });
    } catch (e) {
      this.emitter.emit('did-cancel', query.pid ? {handlerPid: query.pid} : undefined);
    }
  }

  onDidCancel(cb) {
    return this.emitter.on('did-cancel', cb);
  }

  async terminate() {
    await new Promise(resolve => this.server.close(resolve));
    this.emitter.dispose();
  }
}
