import url from 'url';

/**
 * Match and capture parts of a URI, like a specialized dialect of regular expression. This is used by PaneItem to
 * describe URIs that should launch specific panes.
 *
 * URI patterns used `{name}` placeholders to match any non-empty path segment or URI part (host, protocol) and capture
 * it as a parameter called "name". Any segment that is not recognized as a parameter will match exactly.
 *
 * Examples:
 *
 * `atom-github://hostname/exact/path?p0=value&p1=value` contains no parameters, so it will match _only_ that exact URL,
 * including query parameters and their values. Extra query parameters or a fragment (`#`) will cause the match to fail.
 *
 * `atom-github://hostname/path/{name}/fragment` will match and capture any second path segment.
 * * `atom-github://hostname/path/one/fragment` will match with `{name: 'one'}`
 * * `atom-github://hostname/path/two/fragment` will match with `{name: 'two'}`
 * * `atom-github://hostname/path/fragment` will not.
 *
 * `atom-github://hostname/root/{segments...}` will capture any number of path segments as an array. For example,
 * * `atom-github://hostname/root/foo/bar/baz/` will match with `{segments: ['foo', 'bar', 'baz']}`.
 * * `atom-github://hostname/root/single` will match with `{segments: ['single']}`; even a single segment will be
 *   matched as an array.
 * * `atom-github://hostname/root/` will match with `{segments: []}`.
 *
 * Query parameters and their values may be captured. Given: `atom-github://hostname?q={value}`
 * * `atom-github://hostname?q=foo` will match with `{value: 'foo'}`.
 * * `atom-github://hostname?q=one&q=two` will _not_ match.
 *
 * To match multiple query parameters, use a splat parameter. Given: `atom-github://hostname?q={value...}`
 * * `atom-github://hostname?q=one&q=two` will match with `{value: ['one', 'two']}`.
 * * `atom-github://hostname?q=single` will match with `{value: ['single']}`.
 * * `atom-github://hostname` will match with `{value: []}`.
 *
 * Protocol, username, password, or hostname may also contain capture expressions: `{p}://hostname`,
 * `foo://me:{password}@hostname`.
 */
export default class URIPattern {
  constructor(string) {
    this.original = string;

    const parsed = url.parse(dashEscape(string), true);
    this.parts = {
      protocol: asPart(parsed.protocol, '', ':'),
      auth: splitAuth(parsed.auth, asPart),
      hostname: asPart(parsed.hostname),
      port: asPart(parsed.port),
      pathname: (parsed.pathname || '').split('/').slice(1).map(segment => asPart(segment)),
      query: Object.keys(parsed.query).reduce(
        (acc, current) => {
          acc[current] = asPart(parsed.query[current]);
          return acc;
        },
        {},
      ),
      hash: asPart(parsed.hash, '#', ''),
    };
  }

  matches(string) {
    if (string === undefined || string === null) {
      return nonURIMatch;
    }

    const other = url.parse(string, true);
    const params = {};

    // direct matches
    for (const attr of ['protocol', 'hostname', 'port', 'hash']) {
      if (!this.parts[attr].matchesIn(params, other[attr])) {
        return nonURIMatch;
      }
    }

    // auth
    const auth = splitAuth(other.auth);
    if (!this.parts.auth.username.matchesIn(params, auth.username)) {
      return nonURIMatch;
    }
    if (!this.parts.auth.password.matchesIn(params, auth.password)) {
      return nonURIMatch;
    }

    // pathname
    const pathParts = (other.pathname || '').split('/').filter(p => p.length > 0);
    let mineInd = 0;
    let yoursInd = 0;
    while (mineInd < this.parts.pathname.length && yoursInd < pathParts.length) {
      const mine = this.parts.pathname[mineInd];
      const yours = pathParts[yoursInd];

      if (!mine.matchesIn(params, yours)) {
        return nonURIMatch;
      } else {
        if (!mine.isSplat()) {
          mineInd++;
        }
        yoursInd++;
      }
    }

    while (mineInd < this.parts.pathname.length) {
      const part = this.parts.pathname[mineInd];
      if (!part.matchesEmptyIn(params)) {
        return nonURIMatch;
      }
      mineInd++;
    }

    if (yoursInd !== pathParts.length) {
      return nonURIMatch;
    }

    // query string
    const remaining = new Set(Object.keys(this.parts.query));
    for (const k in other.query) {
      const yours = other.query[k];
      remaining.delete(k);

      const mine = this.parts.query[k];
      if (mine === undefined) {
        return nonURIMatch;
      }

      const allYours = yours instanceof Array ? yours : [yours];

      for (const each of allYours) {
        if (!mine.matchesIn(params, each)) {
          return nonURIMatch;
        }
      }
    }

    for (const k of remaining) {
      const part = this.parts.query[k];
      if (!part.matchesEmptyIn(params)) {
        return nonURIMatch;
      }
    }

    return new URIMatch(string, params);
  }

  // Access the original string used to create this pattern.
  getOriginal() {
    return this.original;
  }

  toString() {
    return `<URIPattern ${this.original}>`;
  }
}

/**
 * Pattern component that matches its corresponding segment exactly.
 */
class ExactPart {
  constructor(string) {
    this.string = string;
  }

  matchesIn(params, other) {
    return other === this.string;
  }

  matchesEmptyIn(params) {
    return false;
  }

  isSplat() {
    return false;
  }
}

/**
 * Pattern component that matches and captures any non-empty corresponding segment within a URI.
 */
class CapturePart {
  constructor(name, splat, prefix, suffix) {
    this.name = name;
    this.splat = splat;
    this.prefix = prefix;
    this.suffix = suffix;
  }

  matchesIn(params, other) {
    if (this.prefix.length > 0 && other.startsWith(this.prefix)) {
      other = other.slice(this.prefix.length);
    }
    if (this.suffix.length > 0 && other.endsWith(this.suffix)) {
      other = other.slice(0, -this.suffix.length);
    }

    other = decodeURIComponent(other);

    if (this.name.length > 0) {
      if (this.splat) {
        if (params[this.name] === undefined) {
          params[this.name] = [other];
        } else {
          params[this.name].push(other);
        }
      } else {
        if (params[this.name] !== undefined) {
          return false;
        }
        params[this.name] = other;
      }
    }
    return true;
  }

  matchesEmptyIn(params) {
    if (this.splat) {
      if (params[this.name] === undefined) {
        params[this.name] = [];
      }
      return true;
    }

    return false;
  }

  isSplat() {
    return this.splat;
  }
}

/**
 * Including `{}` characters in certain URI components (hostname, protocol) cause `url.parse()` to lump everything into
 * the `pathname`. Escape brackets from a pattern with `-a` and `-z`, and literal dashes with `--`.
 */
function dashEscape(raw) {
  return raw.replace(/[{}-]/g, ch => {
    if (ch === '{') {
      return '-a';
    } else if (ch === '}') {
      return '-z';
    } else {
      return '--';
    }
  });
}

/**
 * Reverse the escaping performed by `dashEscape` by un-doubling `-` characters.
 */
function dashUnescape(escaped) {
  return escaped.replace(/--/g, '-');
}

/**
 * Parse a URI pattern component as either an `ExactPart` or a `CapturePart`. Recognize captures ending with `...` as
 * splat captures that can consume zero to many components.
 */
function asPart(patternSegment, prefix = '', suffix = '') {
  if (patternSegment === null) {
    return new ExactPart(null);
  }

  let subPattern = patternSegment;
  if (prefix.length > 0 && subPattern.startsWith(prefix)) {
    subPattern = subPattern.slice(prefix.length);
  }
  if (suffix.length > 0 && subPattern.endsWith(suffix)) {
    subPattern = subPattern.slice(0, -suffix.length);
  }

  if (subPattern.startsWith('-a') && subPattern.endsWith('-z')) {
    const splat = subPattern.endsWith('...-z');
    if (splat) {
      subPattern = subPattern.slice(2, -5);
    } else {
      subPattern = subPattern.slice(2, -2);
    }

    return new CapturePart(dashUnescape(subPattern), splat, prefix, suffix);
  } else {
    return new ExactPart(dashUnescape(patternSegment));
  }
}

/**
 * Split the `.auth` field into username and password subcomponent.
 */
function splitAuth(auth, fn = x => x) {
  if (auth === null) {
    return {username: fn(null), password: fn(null)};
  }

  const ind = auth.indexOf(':');
  return ind !== -1
    ? {username: fn(auth.slice(0, ind)), password: fn(auth.slice(ind + 1))}
    : {username: fn(auth), password: fn(null)};
}

/**
 * Memorialize a successful match between a URI and a URIPattern, including any parameters that have been captured.
 */
class URIMatch {
  constructor(uri, params) {
    this.uri = uri;
    this.params = params;
  }

  ok() {
    return true;
  }

  getURI() {
    return this.uri;
  }

  getParams() {
    return this.params;
  }

  toString() {
    let s = '<URIMatch ok';
    for (const k in this.params) {
      s += ` ${k}="${this.params[k]}"`;
    }
    s += '>';
    return s;
  }
}

/**
 * Singleton object that memorializes an unsuccessful match between a URIPattern and an URI. Matches the API of a
 * URIMatch, but returns false for ok() and so on.
 */
export const nonURIMatch = {
  ok() {
    return false;
  },

  getURI() {
    return undefined;
  },

  getParams() {
    return {};
  },

  toString() {
    return '<nonURIMatch>';
  },
};
