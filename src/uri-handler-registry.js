const url = require('url');
const { Emitter, Disposable } = require('event-kit');

// Private: Associates listener functions with URIs from outside the application.
//
// The global URI handler registry maps URIs to listener functions. URIs are mapped
// based on the hostname of the URI; the format is atom://package/command?args.
// The "core" package name is reserved for URIs handled by Atom core (it is not possible
// to register a package with the name "core").
//
// Because URI handling can be triggered from outside the application (e.g. from
// the user's browser), package authors should take great care to ensure that malicious
// activities cannot be performed by an attacker. A good rule to follow is that
// **URI handlers should not take action on behalf of the user**. For example, clicking
// a link to open a pane item that prompts the user to install a package is okay;
// automatically installing the package right away is not.
//
// Packages can register their desire to handle URIs via a special key in their
// `package.json` called "uriHandler". The value of this key should be an object
// that contains, at minimum, a key named "method". This is the name of the method
// on your package object that Atom will call when it receives a URI your package
// is responsible for handling. It will pass the parsed URI as the first argument (by using
// [Node's `url.parse(uri, true)`](https://nodejs.org/docs/latest/api/url.html#url_url_parse_urlstring_parsequerystring_slashesdenotehost))
// and the raw URI string as the second argument.
//
// By default, Atom will defer activation of your package until a URI it needs to handle
// is triggered. If you need your package to activate right away, you can add
// `"deferActivation": false` to your "uriHandler" configuration object. When activation
// is deferred, once Atom receives a request for a URI in your package's namespace, it will
// activate your pacakge and then call `methodName` on it as before.
//
// If your package specifies a deprecated `urlMain` property, you cannot register URI handlers
// via the `uriHandler` key.
//
// ## Example
//
// Here is a sample package that will be activated and have its `handleURI` method called
// when a URI beginning with `atom://my-package` is triggered:
//
// `package.json`:
//
// ```javascript
// {
//   "name": "my-package",
//   "main": "./lib/my-package.js",
//   "uriHandler": {
//     "method": "handleURI"
//   }
// }
// ```
//
// `lib/my-package.js`
//
// ```javascript
// module.exports = {
//   activate: function() {
//     // code to activate your package
//   }
//
//   handleURI(parsedUri, rawUri) {
//     // parse and handle uri
//   }
// }
// ```
module.exports = class URIHandlerRegistry {
  constructor(maxHistoryLength = 50) {
    this.registrations = new Map();
    this.history = [];
    this.maxHistoryLength = maxHistoryLength;
    this._id = 0;

    this.emitter = new Emitter();
  }

  registerHostHandler(host, callback) {
    if (typeof callback !== 'function') {
      throw new Error(
        'Cannot register a URI host handler with a non-function callback'
      );
    }

    if (this.registrations.has(host)) {
      throw new Error(
        `There is already a URI host handler for the host ${host}`
      );
    } else {
      this.registrations.set(host, callback);
    }

    return new Disposable(() => {
      this.registrations.delete(host);
    });
  }

  async handleURI(uri) {
    const parsed = url.parse(uri, true);
    const { protocol, slashes, auth, port, host } = parsed;
    if (protocol !== 'atom:' || slashes !== true || auth || port) {
      throw new Error(
        `URIHandlerRegistry#handleURI asked to handle an invalid URI: ${uri}`
      );
    }

    const registration = this.registrations.get(host);
    const historyEntry = { id: ++this._id, uri: uri, handled: false, host };
    try {
      if (registration) {
        historyEntry.handled = true;
        await registration(parsed, uri);
      }
    } finally {
      this.history.unshift(historyEntry);
      if (this.history.length > this.maxHistoryLength) {
        this.history.length = this.maxHistoryLength;
      }
      this.emitter.emit('history-change');
    }
  }

  getRecentlyHandledURIs() {
    return this.history;
  }

  onHistoryChange(cb) {
    return this.emitter.on('history-change', cb);
  }

  destroy() {
    this.emitter.dispose();
    this.registrations = new Map();
    this.history = [];
    this._id = 0;
  }
};
