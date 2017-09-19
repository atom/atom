const url = require('url')
const {Disposable} = require('event-kit')

// Private: Associates listener functions with URLs from outside the application.
//
// The global URL handler registry maps URLs to listener functions. URLs are mapped
// based on the hostname of the URL; the format is atom://package/command?args.
// The "core" package name is reserved for URLs handled by Atom core (it is not possible
// to register a package with the name "core").
//
// Because URL handling can be triggered from outside the application (e.g. from
// the user's browser), package authors should take great care to ensure that malicious
// activities cannot be performed by an attacker. A good rule to follow is that
// **URL handlers should not take action on behalf of the user**. For example, clicking
// a link to open a pane item that prompts the user to install a package is okay;
// automatically installing the package right away is not.
//
// Packages can register their desire to handle URLs via a special key in their
// `package.json` called "urlHandlers". The value of this key should be an object
// that contains, at minimum, a key named "method". This is the name of the method
// on your package object that Atom will call when it receives a URL your package
// is responsible for handling. It will pass the full URL as the only argument, and you
// are free to do your own URL parsing to handle it.
//
// If your package can defer activation until a URL it needs to handle is triggered,
// you can additionally specify the `"defer": true` option in your "urlHandlers" object.
// When Atom receives a request for a URL in your package's namespace, it will activate your
// pacakge and then call `methodName` on it as before.
//
// If your package specifies a deprecated `urlMain` property, you cannot register URL handlers
// via the `urlHandlers` key.
//
// ## Example
//
// Here is a message that could open a specific panel in a package's view:
//
// `package.json`:
//
// ```javascript
// {
//   "name": "my-package",
//   "main": "./lib/my-package.js",
//   "urlHandlers": {
//     "method": "handleUrl",
//     "deferActivation": true,
//   }
// }
// ```
//
// `lib/my-package.json`
//
// ```javascript
// module.exports = {
//   activate: function() {
//     // code to activate your package
//   }
//
//   handleUrl(url) {
//     // parse and handle url
//   }
// }
// ```
//
// In this example, when Atom handles `atom://my-package/something`, it will activate your
// package and then call `handleUrl` passing in the string `"atom://my-package/something"`
module.exports =
class UrlHandlerRegistry {
  constructor () {
    this.registrations = new Map()
  }

  registerHostHandler (host, callback) {
    if (typeof callback !== 'function') {
      throw new Error('Cannot register a URL host handler with a non-function callback')
    }

    if (this.registrations.has(host)) {
      throw new Error(`There is already a URL host handler for the host ${host}`)
    } else {
      this.registrations.set(host, callback)
    }

    return new Disposable(() => {
      this.registrations.delete(host)
    })
  }

  handleUrl (uri) {
    const {protocol, slashes, auth, port, host} = url.parse(uri)
    if (protocol !== 'atom:' || slashes !== true || auth || port) {
      throw new Error(`UrlHandlerRegistry#handleUrl asked to handle an invalid URL: ${uri}`)
    }

    const registration = this.registrations.get(host)
    if (registration) {
      registration(uri)
    }
  }
}
