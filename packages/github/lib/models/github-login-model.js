import crypto from 'crypto';
import {Emitter} from 'event-kit';

import {UNAUTHENTICATED, INSUFFICIENT, UNAUTHORIZED, createStrategy} from '../shared/keytar-strategy';

let instance = null;

export default class GithubLoginModel {
  // Be sure that we're requesting at least this many scopes on the token we grant through github.atom.io or we'll
  // give everyone a really frustrating experience ;-)
  static REQUIRED_SCOPES = ['repo', 'read:org', 'user:email']

  static get() {
    if (!instance) {
      instance = new GithubLoginModel();
    }
    return instance;
  }

  constructor(Strategy) {
    this._Strategy = Strategy;
    this._strategy = null;
    this.emitter = new Emitter();
    this.checked = new Map();
  }

  async getStrategy() {
    if (this._strategy) {
      return this._strategy;
    }

    if (this._Strategy) {
      this._strategy = new this._Strategy();
      return this._strategy;
    }

    this._strategy = await createStrategy();
    return this._strategy;
  }

  async getToken(account) {
    const strategy = await this.getStrategy();
    const password = await strategy.getPassword('atom-github', account);
    if (!password || password === UNAUTHENTICATED) {
      // User is not logged in
      return UNAUTHENTICATED;
    }

    if (/^https?:\/\//.test(account)) {
      // Avoid storing tokens in memory longer than necessary. Let's cache token scope checks by storing a set of
      // checksums instead.
      const hash = crypto.createHash('md5');
      hash.update(password);
      const fingerprint = hash.digest('base64');

      const outcome = this.checked.get(fingerprint);
      if (outcome === UNAUTHENTICATED || outcome === INSUFFICIENT) {
        // Cached failure
        return outcome;
      } else if (!outcome) {
        // No cached outcome. Query for scopes.
        try {
          const scopes = await this.getScopes(account, password);
          if (scopes === UNAUTHORIZED) {
            // Password is incorrect. Treat it as though you aren't authenticated at all.
            this.checked.set(fingerprint, UNAUTHENTICATED);
            return UNAUTHENTICATED;
          }
          const scopeSet = new Set(scopes);

          for (const scope of this.constructor.REQUIRED_SCOPES) {
            if (!scopeSet.has(scope)) {
              // Token doesn't have enough OAuth scopes, need to reauthenticate
              this.checked.set(fingerprint, INSUFFICIENT);
              return INSUFFICIENT;
            }
          }

          // Successfully authenticated and had all required scopes.
          this.checked.set(fingerprint, true);
        } catch (e) {
          // Most likely a network error. Do not cache the failure.
          return e;
        }
      }
    }

    return password;
  }

  async setToken(account, token) {
    const strategy = await this.getStrategy();
    await strategy.replacePassword('atom-github', account, token);
    this.didUpdate();
  }

  async removeToken(account) {
    const strategy = await this.getStrategy();
    await strategy.deletePassword('atom-github', account);
    this.didUpdate();
  }

  /* istanbul ignore next */
  async getScopes(host, token) {
    if (atom.inSpecMode()) {
      if (token === 'good-token') {
        return this.constructor.REQUIRED_SCOPES;
      }

      throw new Error('Attempt to check token scopes in specs');
    }

    let response;
    try {
      response = await fetch(host, {
        method: 'HEAD',
        headers: {Authorization: `bearer ${token}`},
      });
    } catch (e) {
      e.network = true;
      throw e;
    }

    if (response.status === 401) {
      return UNAUTHORIZED;
    }

    if (response.status !== 200) {
      const e = new Error(`Unable to check token for OAuth scopes against ${host}`);
      e.response = response;
      e.responseText = await response.text();
      throw e;
    }

    return response.headers.get('X-OAuth-Scopes').split(/\s*,\s*/);
  }

  didUpdate() {
    this.emitter.emit('did-update');
  }

  onDidUpdate(cb) {
    return this.emitter.on('did-update', cb);
  }

  destroy() {
    this.emitter.dispose();
  }
}
