const NULL = Symbol('null');
const CREATE_ON_EMPTY = Symbol('create on empty');

export default class Search {
  constructor(name, query, attrs = {}) {
    this.name = name;
    this.query = query;
    this.attrs = attrs;
  }

  getName() {
    return this.name;
  }

  createQuery() {
    return this.query;
  }

  // A null search has insufficient information to construct a canned query, so it should always return no results.
  isNull() {
    return this.attrs[NULL] || false;
  }

  showCreateOnEmpty() {
    return this.attrs[CREATE_ON_EMPTY] || false;
  }

  getWebURL(remote) {
    if (!remote.isGithubRepo()) {
      throw new Error(`Attempt to generate web URL for non-GitHub remote ${remote.getName()}`);
    }

    return `https://${remote.getDomain()}/search?q=${encodeURIComponent(this.createQuery())}`;
  }

  static inRemote(remote, name, query, attrs = {}) {
    if (!remote.isGithubRepo()) {
      return new this(name, '', {...attrs, [NULL]: true});
    }

    return new this(name, `repo:${remote.getOwner()}/${remote.getRepo()} ${query.trim()}`, attrs);
  }
}

export const nullSearch = new Search('', '', {[NULL]: true});
