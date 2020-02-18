import {nullRemote} from './remote';
import {pushAtKey} from '../helpers';

export default class RemoteSet {
  constructor(iterable = []) {
    this.byName = new Map();
    this.byDotcomRepo = new Map();
    this.protocolCount = new Map();
    for (const remote of iterable) {
      this.add(remote);
    }
  }

  add(remote) {
    this.byName.set(remote.getName(), remote);
    if (remote.isGithubRepo()) {
      pushAtKey(this.byDotcomRepo, remote.getSlug(), remote);
    }
    if (remote.getProtocol()) {
      const count = this.protocolCount.get(remote.getProtocol()) || 0;
      this.protocolCount.set(remote.getProtocol(), count + 1);
    }
  }

  isEmpty() {
    return this.byName.size === 0;
  }

  size() {
    return this.byName.size;
  }

  withName(name) {
    return this.byName.get(name) || nullRemote;
  }

  [Symbol.iterator]() {
    return this.byName.values();
  }

  filter(predicate) {
    return new this.constructor(
      Array.from(this).filter(predicate),
    );
  }

  matchingGitHubRepository(owner, name) {
    return this.byDotcomRepo.get(`${owner}/${name}`) || [];
  }

  mostUsedProtocol(choices) {
    let best = choices[0];
    let bestCount = 0;
    for (const protocol of choices) {
      const count = this.protocolCount.get(protocol) || 0;
      if (count > bestCount) {
        bestCount = count;
        best = protocol;
      }
    }
    return best;
  }
}
