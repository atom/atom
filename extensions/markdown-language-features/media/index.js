/******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, {
/******/ 				configurable: false,
/******/ 				enumerable: true,
/******/ 				get: getter
/******/ 			});
/******/ 		}
/******/ 	};
/******/
/******/ 	// define __esModule on exports
/******/ 	__webpack_require__.r = function(exports) {
/******/ 		Object.defineProperty(exports, '__esModule', { value: true });
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = "./preview-src/index.ts");
/******/ })
/************************************************************************/
/******/ ({

/***/ "./node_modules/lodash.throttle/index.js":
/*!***********************************************!*\
  !*** ./node_modules/lodash.throttle/index.js ***!
  \***********************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

/* WEBPACK VAR INJECTION */(function(global) {/**
 * lodash (Custom Build) <https://lodash.com/>
 * Build: `lodash modularize exports="npm" -o ./`
 * Copyright jQuery Foundation and other contributors <https://jquery.org/>
 * Released under MIT license <https://lodash.com/license>
 * Based on Underscore.js 1.8.3 <http://underscorejs.org/LICENSE>
 * Copyright Jeremy Ashkenas, DocumentCloud and Investigative Reporters & Editors
 */

/** Used as the `TypeError` message for "Functions" methods. */
var FUNC_ERROR_TEXT = 'Expected a function';

/** Used as references for various `Number` constants. */
var NAN = 0 / 0;

/** `Object#toString` result references. */
var symbolTag = '[object Symbol]';

/** Used to match leading and trailing whitespace. */
var reTrim = /^\s+|\s+$/g;

/** Used to detect bad signed hexadecimal string values. */
var reIsBadHex = /^[-+]0x[0-9a-f]+$/i;

/** Used to detect binary string values. */
var reIsBinary = /^0b[01]+$/i;

/** Used to detect octal string values. */
var reIsOctal = /^0o[0-7]+$/i;

/** Built-in method references without a dependency on `root`. */
var freeParseInt = parseInt;

/** Detect free variable `global` from Node.js. */
var freeGlobal = typeof global == 'object' && global && global.Object === Object && global;

/** Detect free variable `self`. */
var freeSelf = typeof self == 'object' && self && self.Object === Object && self;

/** Used as a reference to the global object. */
var root = freeGlobal || freeSelf || Function('return this')();

/** Used for built-in method references. */
var objectProto = Object.prototype;

/**
 * Used to resolve the
 * [`toStringTag`](http://ecma-international.org/ecma-262/7.0/#sec-object.prototype.tostring)
 * of values.
 */
var objectToString = objectProto.toString;

/* Built-in method references for those with the same name as other `lodash` methods. */
var nativeMax = Math.max,
    nativeMin = Math.min;

/**
 * Gets the timestamp of the number of milliseconds that have elapsed since
 * the Unix epoch (1 January 1970 00:00:00 UTC).
 *
 * @static
 * @memberOf _
 * @since 2.4.0
 * @category Date
 * @returns {number} Returns the timestamp.
 * @example
 *
 * _.defer(function(stamp) {
 *   console.log(_.now() - stamp);
 * }, _.now());
 * // => Logs the number of milliseconds it took for the deferred invocation.
 */
var now = function() {
  return root.Date.now();
};

/**
 * Creates a debounced function that delays invoking `func` until after `wait`
 * milliseconds have elapsed since the last time the debounced function was
 * invoked. The debounced function comes with a `cancel` method to cancel
 * delayed `func` invocations and a `flush` method to immediately invoke them.
 * Provide `options` to indicate whether `func` should be invoked on the
 * leading and/or trailing edge of the `wait` timeout. The `func` is invoked
 * with the last arguments provided to the debounced function. Subsequent
 * calls to the debounced function return the result of the last `func`
 * invocation.
 *
 * **Note:** If `leading` and `trailing` options are `true`, `func` is
 * invoked on the trailing edge of the timeout only if the debounced function
 * is invoked more than once during the `wait` timeout.
 *
 * If `wait` is `0` and `leading` is `false`, `func` invocation is deferred
 * until to the next tick, similar to `setTimeout` with a timeout of `0`.
 *
 * See [David Corbacho's article](https://css-tricks.com/debouncing-throttling-explained-examples/)
 * for details over the differences between `_.debounce` and `_.throttle`.
 *
 * @static
 * @memberOf _
 * @since 0.1.0
 * @category Function
 * @param {Function} func The function to debounce.
 * @param {number} [wait=0] The number of milliseconds to delay.
 * @param {Object} [options={}] The options object.
 * @param {boolean} [options.leading=false]
 *  Specify invoking on the leading edge of the timeout.
 * @param {number} [options.maxWait]
 *  The maximum time `func` is allowed to be delayed before it's invoked.
 * @param {boolean} [options.trailing=true]
 *  Specify invoking on the trailing edge of the timeout.
 * @returns {Function} Returns the new debounced function.
 * @example
 *
 * // Avoid costly calculations while the window size is in flux.
 * jQuery(window).on('resize', _.debounce(calculateLayout, 150));
 *
 * // Invoke `sendMail` when clicked, debouncing subsequent calls.
 * jQuery(element).on('click', _.debounce(sendMail, 300, {
 *   'leading': true,
 *   'trailing': false
 * }));
 *
 * // Ensure `batchLog` is invoked once after 1 second of debounced calls.
 * var debounced = _.debounce(batchLog, 250, { 'maxWait': 1000 });
 * var source = new EventSource('/stream');
 * jQuery(source).on('message', debounced);
 *
 * // Cancel the trailing debounced invocation.
 * jQuery(window).on('popstate', debounced.cancel);
 */
function debounce(func, wait, options) {
  var lastArgs,
      lastThis,
      maxWait,
      result,
      timerId,
      lastCallTime,
      lastInvokeTime = 0,
      leading = false,
      maxing = false,
      trailing = true;

  if (typeof func != 'function') {
    throw new TypeError(FUNC_ERROR_TEXT);
  }
  wait = toNumber(wait) || 0;
  if (isObject(options)) {
    leading = !!options.leading;
    maxing = 'maxWait' in options;
    maxWait = maxing ? nativeMax(toNumber(options.maxWait) || 0, wait) : maxWait;
    trailing = 'trailing' in options ? !!options.trailing : trailing;
  }

  function invokeFunc(time) {
    var args = lastArgs,
        thisArg = lastThis;

    lastArgs = lastThis = undefined;
    lastInvokeTime = time;
    result = func.apply(thisArg, args);
    return result;
  }

  function leadingEdge(time) {
    // Reset any `maxWait` timer.
    lastInvokeTime = time;
    // Start the timer for the trailing edge.
    timerId = setTimeout(timerExpired, wait);
    // Invoke the leading edge.
    return leading ? invokeFunc(time) : result;
  }

  function remainingWait(time) {
    var timeSinceLastCall = time - lastCallTime,
        timeSinceLastInvoke = time - lastInvokeTime,
        result = wait - timeSinceLastCall;

    return maxing ? nativeMin(result, maxWait - timeSinceLastInvoke) : result;
  }

  function shouldInvoke(time) {
    var timeSinceLastCall = time - lastCallTime,
        timeSinceLastInvoke = time - lastInvokeTime;

    // Either this is the first call, activity has stopped and we're at the
    // trailing edge, the system time has gone backwards and we're treating
    // it as the trailing edge, or we've hit the `maxWait` limit.
    return (lastCallTime === undefined || (timeSinceLastCall >= wait) ||
      (timeSinceLastCall < 0) || (maxing && timeSinceLastInvoke >= maxWait));
  }

  function timerExpired() {
    var time = now();
    if (shouldInvoke(time)) {
      return trailingEdge(time);
    }
    // Restart the timer.
    timerId = setTimeout(timerExpired, remainingWait(time));
  }

  function trailingEdge(time) {
    timerId = undefined;

    // Only invoke if we have `lastArgs` which means `func` has been
    // debounced at least once.
    if (trailing && lastArgs) {
      return invokeFunc(time);
    }
    lastArgs = lastThis = undefined;
    return result;
  }

  function cancel() {
    if (timerId !== undefined) {
      clearTimeout(timerId);
    }
    lastInvokeTime = 0;
    lastArgs = lastCallTime = lastThis = timerId = undefined;
  }

  function flush() {
    return timerId === undefined ? result : trailingEdge(now());
  }

  function debounced() {
    var time = now(),
        isInvoking = shouldInvoke(time);

    lastArgs = arguments;
    lastThis = this;
    lastCallTime = time;

    if (isInvoking) {
      if (timerId === undefined) {
        return leadingEdge(lastCallTime);
      }
      if (maxing) {
        // Handle invocations in a tight loop.
        timerId = setTimeout(timerExpired, wait);
        return invokeFunc(lastCallTime);
      }
    }
    if (timerId === undefined) {
      timerId = setTimeout(timerExpired, wait);
    }
    return result;
  }
  debounced.cancel = cancel;
  debounced.flush = flush;
  return debounced;
}

/**
 * Creates a throttled function that only invokes `func` at most once per
 * every `wait` milliseconds. The throttled function comes with a `cancel`
 * method to cancel delayed `func` invocations and a `flush` method to
 * immediately invoke them. Provide `options` to indicate whether `func`
 * should be invoked on the leading and/or trailing edge of the `wait`
 * timeout. The `func` is invoked with the last arguments provided to the
 * throttled function. Subsequent calls to the throttled function return the
 * result of the last `func` invocation.
 *
 * **Note:** If `leading` and `trailing` options are `true`, `func` is
 * invoked on the trailing edge of the timeout only if the throttled function
 * is invoked more than once during the `wait` timeout.
 *
 * If `wait` is `0` and `leading` is `false`, `func` invocation is deferred
 * until to the next tick, similar to `setTimeout` with a timeout of `0`.
 *
 * See [David Corbacho's article](https://css-tricks.com/debouncing-throttling-explained-examples/)
 * for details over the differences between `_.throttle` and `_.debounce`.
 *
 * @static
 * @memberOf _
 * @since 0.1.0
 * @category Function
 * @param {Function} func The function to throttle.
 * @param {number} [wait=0] The number of milliseconds to throttle invocations to.
 * @param {Object} [options={}] The options object.
 * @param {boolean} [options.leading=true]
 *  Specify invoking on the leading edge of the timeout.
 * @param {boolean} [options.trailing=true]
 *  Specify invoking on the trailing edge of the timeout.
 * @returns {Function} Returns the new throttled function.
 * @example
 *
 * // Avoid excessively updating the position while scrolling.
 * jQuery(window).on('scroll', _.throttle(updatePosition, 100));
 *
 * // Invoke `renewToken` when the click event is fired, but not more than once every 5 minutes.
 * var throttled = _.throttle(renewToken, 300000, { 'trailing': false });
 * jQuery(element).on('click', throttled);
 *
 * // Cancel the trailing throttled invocation.
 * jQuery(window).on('popstate', throttled.cancel);
 */
function throttle(func, wait, options) {
  var leading = true,
      trailing = true;

  if (typeof func != 'function') {
    throw new TypeError(FUNC_ERROR_TEXT);
  }
  if (isObject(options)) {
    leading = 'leading' in options ? !!options.leading : leading;
    trailing = 'trailing' in options ? !!options.trailing : trailing;
  }
  return debounce(func, wait, {
    'leading': leading,
    'maxWait': wait,
    'trailing': trailing
  });
}

/**
 * Checks if `value` is the
 * [language type](http://www.ecma-international.org/ecma-262/7.0/#sec-ecmascript-language-types)
 * of `Object`. (e.g. arrays, functions, objects, regexes, `new Number(0)`, and `new String('')`)
 *
 * @static
 * @memberOf _
 * @since 0.1.0
 * @category Lang
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if `value` is an object, else `false`.
 * @example
 *
 * _.isObject({});
 * // => true
 *
 * _.isObject([1, 2, 3]);
 * // => true
 *
 * _.isObject(_.noop);
 * // => true
 *
 * _.isObject(null);
 * // => false
 */
function isObject(value) {
  var type = typeof value;
  return !!value && (type == 'object' || type == 'function');
}

/**
 * Checks if `value` is object-like. A value is object-like if it's not `null`
 * and has a `typeof` result of "object".
 *
 * @static
 * @memberOf _
 * @since 4.0.0
 * @category Lang
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if `value` is object-like, else `false`.
 * @example
 *
 * _.isObjectLike({});
 * // => true
 *
 * _.isObjectLike([1, 2, 3]);
 * // => true
 *
 * _.isObjectLike(_.noop);
 * // => false
 *
 * _.isObjectLike(null);
 * // => false
 */
function isObjectLike(value) {
  return !!value && typeof value == 'object';
}

/**
 * Checks if `value` is classified as a `Symbol` primitive or object.
 *
 * @static
 * @memberOf _
 * @since 4.0.0
 * @category Lang
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if `value` is a symbol, else `false`.
 * @example
 *
 * _.isSymbol(Symbol.iterator);
 * // => true
 *
 * _.isSymbol('abc');
 * // => false
 */
function isSymbol(value) {
  return typeof value == 'symbol' ||
    (isObjectLike(value) && objectToString.call(value) == symbolTag);
}

/**
 * Converts `value` to a number.
 *
 * @static
 * @memberOf _
 * @since 4.0.0
 * @category Lang
 * @param {*} value The value to process.
 * @returns {number} Returns the number.
 * @example
 *
 * _.toNumber(3.2);
 * // => 3.2
 *
 * _.toNumber(Number.MIN_VALUE);
 * // => 5e-324
 *
 * _.toNumber(Infinity);
 * // => Infinity
 *
 * _.toNumber('3.2');
 * // => 3.2
 */
function toNumber(value) {
  if (typeof value == 'number') {
    return value;
  }
  if (isSymbol(value)) {
    return NAN;
  }
  if (isObject(value)) {
    var other = typeof value.valueOf == 'function' ? value.valueOf() : value;
    value = isObject(other) ? (other + '') : other;
  }
  if (typeof value != 'string') {
    return value === 0 ? value : +value;
  }
  value = value.replace(reTrim, '');
  var isBinary = reIsBinary.test(value);
  return (isBinary || reIsOctal.test(value))
    ? freeParseInt(value.slice(2), isBinary ? 2 : 8)
    : (reIsBadHex.test(value) ? NAN : +value);
}

module.exports = throttle;

/* WEBPACK VAR INJECTION */}.call(this, __webpack_require__(/*! ./../webpack/buildin/global.js */ "./node_modules/webpack/buildin/global.js")))

/***/ }),

/***/ "./node_modules/webpack/buildin/global.js":
/*!***********************************!*\
  !*** (webpack)/buildin/global.js ***!
  \***********************************/
/*! no static exports found */
/***/ (function(module, exports) {

var g;

// This works in non-strict mode
g = (function() {
	return this;
})();

try {
	// This works if eval is allowed (see CSP)
	g = g || Function("return this")() || (1, eval)("this");
} catch (e) {
	// This works if the window reference is available
	if (typeof window === "object") g = window;
}

// g can still be undefined, but nothing to do about it...
// We return undefined, instead of nothing here, so it's
// easier to handle this case. if(!global) { ...}

module.exports = g;


/***/ }),

/***/ "./preview-src/activeLineMarker.ts":
/*!*****************************************!*\
  !*** ./preview-src/activeLineMarker.ts ***!
  \*****************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

Object.defineProperty(exports, "__esModule", { value: true });
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
const scroll_sync_1 = __webpack_require__(/*! ./scroll-sync */ "./preview-src/scroll-sync.ts");
class ActiveLineMarker {
    onDidChangeTextEditorSelection(line) {
        const { previous } = scroll_sync_1.getElementsForSourceLine(line);
        this._update(previous && previous.element);
    }
    _update(before) {
        this._unmarkActiveElement(this._current);
        this._markActiveElement(before);
        this._current = before;
    }
    _unmarkActiveElement(element) {
        if (!element) {
            return;
        }
        element.className = element.className.replace(/\bcode-active-line\b/g, '');
    }
    _markActiveElement(element) {
        if (!element) {
            return;
        }
        element.className += ' code-active-line';
    }
}
exports.ActiveLineMarker = ActiveLineMarker;


/***/ }),

/***/ "./preview-src/events.ts":
/*!*******************************!*\
  !*** ./preview-src/events.ts ***!
  \*******************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
function onceDocumentLoaded(f) {
    if (document.readyState === 'loading' || document.readyState === 'uninitialized') {
        document.addEventListener('DOMContentLoaded', f);
    }
    else {
        f();
    }
}
exports.onceDocumentLoaded = onceDocumentLoaded;


/***/ }),

/***/ "./preview-src/index.ts":
/*!******************************!*\
  !*** ./preview-src/index.ts ***!
  \******************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
const activeLineMarker_1 = __webpack_require__(/*! ./activeLineMarker */ "./preview-src/activeLineMarker.ts");
const events_1 = __webpack_require__(/*! ./events */ "./preview-src/events.ts");
const messaging_1 = __webpack_require__(/*! ./messaging */ "./preview-src/messaging.ts");
const scroll_sync_1 = __webpack_require__(/*! ./scroll-sync */ "./preview-src/scroll-sync.ts");
const settings_1 = __webpack_require__(/*! ./settings */ "./preview-src/settings.ts");
const throttle = __webpack_require__(/*! lodash.throttle */ "./node_modules/lodash.throttle/index.js");
var scrollDisabled = true;
const marker = new activeLineMarker_1.ActiveLineMarker();
const settings = settings_1.getSettings();
const vscode = acquireVsCodeApi();
// Set VS Code state
const state = settings_1.getData('data-state');
vscode.setState(state);
const messaging = messaging_1.createPosterForVsCode(vscode);
window.cspAlerter.setPoster(messaging);
window.styleLoadingMonitor.setPoster(messaging);
window.onload = () => {
    updateImageSizes();
};
events_1.onceDocumentLoaded(() => {
    if (settings.scrollPreviewWithEditor) {
        setTimeout(() => {
            const initialLine = +settings.line;
            if (!isNaN(initialLine)) {
                scrollDisabled = true;
                scroll_sync_1.scrollToRevealSourceLine(initialLine);
            }
        }, 0);
    }
});
const onUpdateView = (() => {
    const doScroll = throttle((line) => {
        scrollDisabled = true;
        scroll_sync_1.scrollToRevealSourceLine(line);
    }, 50);
    return (line, settings) => {
        if (!isNaN(line)) {
            settings.line = line;
            doScroll(line);
        }
    };
})();
let updateImageSizes = throttle(() => {
    const imageInfo = [];
    let images = document.getElementsByTagName('img');
    if (images) {
        let i;
        for (i = 0; i < images.length; i++) {
            const img = images[i];
            if (img.classList.contains('loading')) {
                img.classList.remove('loading');
            }
            imageInfo.push({
                id: img.id,
                height: img.height,
                width: img.width
            });
        }
        messaging.postMessage('cacheImageSizes', imageInfo);
    }
}, 50);
window.addEventListener('resize', () => {
    scrollDisabled = true;
    updateImageSizes();
}, true);
window.addEventListener('message', event => {
    if (event.data.source !== settings.source) {
        return;
    }
    switch (event.data.type) {
        case 'onDidChangeTextEditorSelection':
            marker.onDidChangeTextEditorSelection(event.data.line);
            break;
        case 'updateView':
            onUpdateView(event.data.line, settings);
            break;
    }
}, false);
document.addEventListener('dblclick', event => {
    if (!settings.doubleClickToSwitchToEditor) {
        return;
    }
    // Ignore clicks on links
    for (let node = event.target; node; node = node.parentNode) {
        if (node.tagName === 'A') {
            return;
        }
    }
    const offset = event.pageY;
    const line = scroll_sync_1.getEditorLineNumberForPageOffset(offset);
    if (typeof line === 'number' && !isNaN(line)) {
        messaging.postMessage('didClick', { line: Math.floor(line) });
    }
});
document.addEventListener('click', event => {
    if (!event) {
        return;
    }
    let node = event.target;
    while (node) {
        if (node.tagName && node.tagName === 'A' && node.href) {
            if (node.getAttribute('href').startsWith('#')) {
                break;
            }
            if (node.href.startsWith('file://') || node.href.startsWith('vscode-resource:')) {
                const [path, fragment] = node.href.replace(/^(file:\/\/|vscode-resource:)/i, '').split('#');
                messaging.postMessage('clickLink', { path, fragment });
                event.preventDefault();
                event.stopPropagation();
                break;
            }
            break;
        }
        node = node.parentNode;
    }
}, true);
if (settings.scrollEditorWithPreview) {
    window.addEventListener('scroll', throttle(() => {
        if (scrollDisabled) {
            scrollDisabled = false;
        }
        else {
            const line = scroll_sync_1.getEditorLineNumberForPageOffset(window.scrollY);
            if (typeof line === 'number' && !isNaN(line)) {
                messaging.postMessage('revealLine', { line });
            }
        }
    }, 50));
}


/***/ }),

/***/ "./preview-src/messaging.ts":
/*!**********************************!*\
  !*** ./preview-src/messaging.ts ***!
  \**********************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
const settings_1 = __webpack_require__(/*! ./settings */ "./preview-src/settings.ts");
exports.createPosterForVsCode = (vscode) => {
    return new class {
        postMessage(type, body) {
            vscode.postMessage({
                type,
                source: settings_1.getSettings().source,
                body
            });
        }
    };
};


/***/ }),

/***/ "./preview-src/scroll-sync.ts":
/*!************************************!*\
  !*** ./preview-src/scroll-sync.ts ***!
  \************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
const settings_1 = __webpack_require__(/*! ./settings */ "./preview-src/settings.ts");
function clamp(min, max, value) {
    return Math.min(max, Math.max(min, value));
}
function clampLine(line) {
    return clamp(0, settings_1.getSettings().lineCount - 1, line);
}
const getCodeLineElements = (() => {
    let elements;
    return () => {
        if (!elements) {
            elements = ([{ element: document.body, line: 0 }]).concat(Array.prototype.map.call(document.getElementsByClassName('code-line'), (element) => {
                const line = +element.getAttribute('data-line');
                return { element, line };
            })
                .filter((x) => !isNaN(x.line)));
        }
        return elements;
    };
})();
/**
 * Find the html elements that map to a specific target line in the editor.
 *
 * If an exact match, returns a single element. If the line is between elements,
 * returns the element prior to and the element after the given line.
 */
function getElementsForSourceLine(targetLine) {
    const lineNumber = Math.floor(targetLine);
    const lines = getCodeLineElements();
    let previous = lines[0] || null;
    for (const entry of lines) {
        if (entry.line === lineNumber) {
            return { previous: entry, next: undefined };
        }
        else if (entry.line > lineNumber) {
            return { previous, next: entry };
        }
        previous = entry;
    }
    return { previous };
}
exports.getElementsForSourceLine = getElementsForSourceLine;
/**
 * Find the html elements that are at a specific pixel offset on the page.
 */
function getLineElementsAtPageOffset(offset) {
    const lines = getCodeLineElements();
    const position = offset - window.scrollY;
    let lo = -1;
    let hi = lines.length - 1;
    while (lo + 1 < hi) {
        const mid = Math.floor((lo + hi) / 2);
        const bounds = lines[mid].element.getBoundingClientRect();
        if (bounds.top + bounds.height >= position) {
            hi = mid;
        }
        else {
            lo = mid;
        }
    }
    const hiElement = lines[hi];
    const hiBounds = hiElement.element.getBoundingClientRect();
    if (hi >= 1 && hiBounds.top > position) {
        const loElement = lines[lo];
        return { previous: loElement, next: hiElement };
    }
    return { previous: hiElement };
}
exports.getLineElementsAtPageOffset = getLineElementsAtPageOffset;
/**
 * Attempt to reveal the element for a source line in the editor.
 */
function scrollToRevealSourceLine(line) {
    if (!settings_1.getSettings().scrollPreviewWithEditor) {
        return;
    }
    if (line <= 0) {
        window.scroll(window.scrollX, 0);
        return;
    }
    const { previous, next } = getElementsForSourceLine(line);
    if (!previous) {
        return;
    }
    let scrollTo = 0;
    const rect = previous.element.getBoundingClientRect();
    const previousTop = rect.top;
    if (next && next.line !== previous.line) {
        // Between two elements. Go to percentage offset between them.
        const betweenProgress = (line - previous.line) / (next.line - previous.line);
        const elementOffset = next.element.getBoundingClientRect().top - previousTop;
        scrollTo = previousTop + betweenProgress * elementOffset;
    }
    else {
        scrollTo = previousTop;
    }
    window.scroll(window.scrollX, Math.max(1, window.scrollY + scrollTo));
}
exports.scrollToRevealSourceLine = scrollToRevealSourceLine;
function getEditorLineNumberForPageOffset(offset) {
    const { previous, next } = getLineElementsAtPageOffset(offset);
    if (previous) {
        const previousBounds = previous.element.getBoundingClientRect();
        const offsetFromPrevious = (offset - window.scrollY - previousBounds.top);
        if (next) {
            const progressBetweenElements = offsetFromPrevious / (next.element.getBoundingClientRect().top - previousBounds.top);
            const line = previous.line + progressBetweenElements * (next.line - previous.line);
            return clampLine(line);
        }
        else {
            const progressWithinElement = offsetFromPrevious / (previousBounds.height);
            const line = previous.line + progressWithinElement;
            return clampLine(line);
        }
    }
    return null;
}
exports.getEditorLineNumberForPageOffset = getEditorLineNumberForPageOffset;


/***/ }),

/***/ "./preview-src/settings.ts":
/*!*********************************!*\
  !*** ./preview-src/settings.ts ***!
  \*********************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";

/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
let cachedSettings = undefined;
function getData(key) {
    const element = document.getElementById('vscode-markdown-preview-data');
    if (element) {
        const data = element.getAttribute(key);
        if (data) {
            return JSON.parse(data);
        }
    }
    throw new Error(`Could not load data for ${key}`);
}
exports.getData = getData;
function getSettings() {
    if (cachedSettings) {
        return cachedSettings;
    }
    cachedSettings = getData('data-settings');
    if (cachedSettings) {
        return cachedSettings;
    }
    throw new Error('Could not load settings');
}
exports.getSettings = getSettings;


/***/ })

/******/ });
//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIndlYnBhY2s6Ly8vd2VicGFjay9ib290c3RyYXAiLCJ3ZWJwYWNrOi8vLy4vbm9kZV9tb2R1bGVzL2xvZGFzaC50aHJvdHRsZS9pbmRleC5qcyIsIndlYnBhY2s6Ly8vKHdlYnBhY2spL2J1aWxkaW4vZ2xvYmFsLmpzIiwid2VicGFjazovLy8uL3ByZXZpZXctc3JjL2FjdGl2ZUxpbmVNYXJrZXIudHMiLCJ3ZWJwYWNrOi8vLy4vcHJldmlldy1zcmMvZXZlbnRzLnRzIiwid2VicGFjazovLy8uL3ByZXZpZXctc3JjL2luZGV4LnRzIiwid2VicGFjazovLy8uL3ByZXZpZXctc3JjL21lc3NhZ2luZy50cyIsIndlYnBhY2s6Ly8vLi9wcmV2aWV3LXNyYy9zY3JvbGwtc3luYy50cyIsIndlYnBhY2s6Ly8vLi9wcmV2aWV3LXNyYy9zZXR0aW5ncy50cyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiO0FBQUE7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7OztBQUdBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLGFBQUs7QUFDTDtBQUNBOztBQUVBO0FBQ0E7QUFDQSx5REFBaUQsY0FBYztBQUMvRDs7QUFFQTtBQUNBO0FBQ0E7QUFDQSxtQ0FBMkIsMEJBQTBCLEVBQUU7QUFDdkQseUNBQWlDLGVBQWU7QUFDaEQ7QUFDQTtBQUNBOztBQUVBO0FBQ0EsOERBQXNELCtEQUErRDs7QUFFckg7QUFDQTs7O0FBR0E7QUFDQTs7Ozs7Ozs7Ozs7O0FDbkVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNBOztBQUVBO0FBQ0E7O0FBRUE7QUFDQTs7QUFFQTtBQUNB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Q0FBQztBQWpCRCw0RUFpQkM7Ozs7Ozs7Ozs7Ozs7O0FDdElEOzs7Z0dBR2dHOztBQVloRyxJQUFJLGNBQWMsR0FBZ0MsU0FBUyxDQUFDO0FBRTVELGlCQUF3QixHQUFXO0lBQ2xDLE1BQU0sT0FBTyxHQUFHLFFBQVEsQ0FBQyxjQUFjLENBQUMsOEJBQThCLENBQUMsQ0FBQztJQUN4RSxFQUFFLENBQUMsQ0FBQyxPQUFPLENBQUMsQ0FBQyxDQUFDO1FBQ2IsTUFBTSxJQUFJLEdBQUcsT0FBTyxDQUFDLFlBQVksQ0FBQyxHQUFHLENBQUMsQ0FBQztRQUN2QyxFQUFFLENBQUMsQ0FBQyxJQUFJLENBQUMsQ0FBQyxDQUFDO1lBQ1YsTUFBTSxDQUFDLElBQUksQ0FBQyxLQUFLLENBQUMsSUFBSSxDQUFDLENBQUM7UUFDekIsQ0FBQztJQUNGLENBQUM7SUFFRCxNQUFNLElBQUksS0FBSyxDQUFDLDJCQUEyQixHQUFHLEVBQUUsQ0FBQyxDQUFDO0FBQ25ELENBQUM7QUFWRCwwQkFVQztBQUVEO0lBQ0MsRUFBRSxDQUFDLENBQUMsY0FBYyxDQUFDLENBQUMsQ0FBQztRQUNwQixNQUFNLENBQUMsY0FBYyxDQUFDO0lBQ3ZCLENBQUM7SUFFRCxjQUFjLEdBQUcsT0FBTyxDQUFDLGVBQWUsQ0FBQyxDQUFDO0lBQzFDLEVBQUUsQ0FBQyxDQUFDLGNBQWMsQ0FBQyxDQUFDLENBQUM7UUFDcEIsTUFBTSxDQUFDLGNBQWMsQ0FBQztJQUN2QixDQUFDO0lBRUQsTUFBTSxJQUFJLEtBQUssQ0FBQyx5QkFBeUIsQ0FBQyxDQUFDO0FBQzVDLENBQUM7QUFYRCxrQ0FXQyIsImZpbGUiOiJpbmRleC5qcyIsInNvdXJjZXNDb250ZW50IjpbIiBcdC8vIFRoZSBtb2R1bGUgY2FjaGVcbiBcdHZhciBpbnN0YWxsZWRNb2R1bGVzID0ge307XG5cbiBcdC8vIFRoZSByZXF1aXJlIGZ1bmN0aW9uXG4gXHRmdW5jdGlvbiBfX3dlYnBhY2tfcmVxdWlyZV9fKG1vZHVsZUlkKSB7XG5cbiBcdFx0Ly8gQ2hlY2sgaWYgbW9kdWxlIGlzIGluIGNhY2hlXG4gXHRcdGlmKGluc3RhbGxlZE1vZHVsZXNbbW9kdWxlSWRdKSB7XG4gXHRcdFx0cmV0dXJuIGluc3RhbGxlZE1vZHVsZXNbbW9kdWxlSWRdLmV4cG9ydHM7XG4gXHRcdH1cbiBcdFx0Ly8gQ3JlYXRlIGEgbmV3IG1vZHVsZSAoYW5kIHB1dCBpdCBpbnRvIHRoZSBjYWNoZSlcbiBcdFx0dmFyIG1vZHVsZSA9IGluc3RhbGxlZE1vZHVsZXNbbW9kdWxlSWRdID0ge1xuIFx0XHRcdGk6IG1vZHVsZUlkLFxuIFx0XHRcdGw6IGZhbHNlLFxuIFx0XHRcdGV4cG9ydHM6IHt9XG4gXHRcdH07XG5cbiBcdFx0Ly8gRXhlY3V0ZSB0aGUgbW9kdWxlIGZ1bmN0aW9uXG4gXHRcdG1vZHVsZXNbbW9kdWxlSWRdLmNhbGwobW9kdWxlLmV4cG9ydHMsIG1vZHVsZSwgbW9kdWxlLmV4cG9ydHMsIF9fd2VicGFja19yZXF1aXJlX18pO1xuXG4gXHRcdC8vIEZsYWcgdGhlIG1vZHVsZSBhcyBsb2FkZWRcbiBcdFx0bW9kdWxlLmwgPSB0cnVlO1xuXG4gXHRcdC8vIFJldHVybiB0aGUgZXhwb3J0cyBvZiB0aGUgbW9kdWxlXG4gXHRcdHJldHVybiBtb2R1bGUuZXhwb3J0cztcbiBcdH1cblxuXG4gXHQvLyBleHBvc2UgdGhlIG1vZHVsZXMgb2JqZWN0IChfX3dlYnBhY2tfbW9kdWxlc19fKVxuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5tID0gbW9kdWxlcztcblxuIFx0Ly8gZXhwb3NlIHRoZSBtb2R1bGUgY2FjaGVcbiBcdF9fd2VicGFja19yZXF1aXJlX18uYyA9IGluc3RhbGxlZE1vZHVsZXM7XG5cbiBcdC8vIGRlZmluZSBnZXR0ZXIgZnVuY3Rpb24gZm9yIGhhcm1vbnkgZXhwb3J0c1xuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5kID0gZnVuY3Rpb24oZXhwb3J0cywgbmFtZSwgZ2V0dGVyKSB7XG4gXHRcdGlmKCFfX3dlYnBhY2tfcmVxdWlyZV9fLm8oZXhwb3J0cywgbmFtZSkpIHtcbiBcdFx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgbmFtZSwge1xuIFx0XHRcdFx0Y29uZmlndXJhYmxlOiBmYWxzZSxcbiBcdFx0XHRcdGVudW1lcmFibGU6IHRydWUsXG4gXHRcdFx0XHRnZXQ6IGdldHRlclxuIFx0XHRcdH0pO1xuIFx0XHR9XG4gXHR9O1xuXG4gXHQvLyBkZWZpbmUgX19lc01vZHVsZSBvbiBleHBvcnRzXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLnIgPSBmdW5jdGlvbihleHBvcnRzKSB7XG4gXHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHsgdmFsdWU6IHRydWUgfSk7XG4gXHR9O1xuXG4gXHQvLyBnZXREZWZhdWx0RXhwb3J0IGZ1bmN0aW9uIGZvciBjb21wYXRpYmlsaXR5IHdpdGggbm9uLWhhcm1vbnkgbW9kdWxlc1xuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5uID0gZnVuY3Rpb24obW9kdWxlKSB7XG4gXHRcdHZhciBnZXR0ZXIgPSBtb2R1bGUgJiYgbW9kdWxlLl9fZXNNb2R1bGUgP1xuIFx0XHRcdGZ1bmN0aW9uIGdldERlZmF1bHQoKSB7IHJldHVybiBtb2R1bGVbJ2RlZmF1bHQnXTsgfSA6XG4gXHRcdFx0ZnVuY3Rpb24gZ2V0TW9kdWxlRXhwb3J0cygpIHsgcmV0dXJuIG1vZHVsZTsgfTtcbiBcdFx0X193ZWJwYWNrX3JlcXVpcmVfXy5kKGdldHRlciwgJ2EnLCBnZXR0ZXIpO1xuIFx0XHRyZXR1cm4gZ2V0dGVyO1xuIFx0fTtcblxuIFx0Ly8gT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLm8gPSBmdW5jdGlvbihvYmplY3QsIHByb3BlcnR5KSB7IHJldHVybiBPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5LmNhbGwob2JqZWN0LCBwcm9wZXJ0eSk7IH07XG5cbiBcdC8vIF9fd2VicGFja19wdWJsaWNfcGF0aF9fXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLnAgPSBcIlwiO1xuXG5cbiBcdC8vIExvYWQgZW50cnkgbW9kdWxlIGFuZCByZXR1cm4gZXhwb3J0c1xuIFx0cmV0dXJuIF9fd2VicGFja19yZXF1aXJlX18oX193ZWJwYWNrX3JlcXVpcmVfXy5zID0gXCIuL3ByZXZpZXctc3JjL2luZGV4LnRzXCIpO1xuIiwiLyoqXG4gKiBsb2Rhc2ggKEN1c3RvbSBCdWlsZCkgPGh0dHBzOi8vbG9kYXNoLmNvbS8+XG4gKiBCdWlsZDogYGxvZGFzaCBtb2R1bGFyaXplIGV4cG9ydHM9XCJucG1cIiAtbyAuL2BcbiAqIENvcHlyaWdodCBqUXVlcnkgRm91bmRhdGlvbiBhbmQgb3RoZXIgY29udHJpYnV0b3JzIDxodHRwczovL2pxdWVyeS5vcmcvPlxuICogUmVsZWFzZWQgdW5kZXIgTUlUIGxpY2Vuc2UgPGh0dHBzOi8vbG9kYXNoLmNvbS9saWNlbnNlPlxuICogQmFzZWQgb24gVW5kZXJzY29yZS5qcyAxLjguMyA8aHR0cDovL3VuZGVyc2NvcmVqcy5vcmcvTElDRU5TRT5cbiAqIENvcHlyaWdodCBKZXJlbXkgQXNoa2VuYXMsIERvY3VtZW50Q2xvdWQgYW5kIEludmVzdGlnYXRpdmUgUmVwb3J0ZXJzICYgRWRpdG9yc1xuICovXG5cbi8qKiBVc2VkIGFzIHRoZSBgVHlwZUVycm9yYCBtZXNzYWdlIGZvciBcIkZ1bmN0aW9uc1wiIG1ldGhvZHMuICovXG52YXIgRlVOQ19FUlJPUl9URVhUID0gJ0V4cGVjdGVkIGEgZnVuY3Rpb24nO1xuXG4vKiogVXNlZCBhcyByZWZlcmVuY2VzIGZvciB2YXJpb3VzIGBOdW1iZXJgIGNvbnN0YW50cy4gKi9cbnZhciBOQU4gPSAwIC8gMDtcblxuLyoqIGBPYmplY3QjdG9TdHJpbmdgIHJlc3VsdCByZWZlcmVuY2VzLiAqL1xudmFyIHN5bWJvbFRhZyA9ICdbb2JqZWN0IFN5bWJvbF0nO1xuXG4vKiogVXNlZCB0byBtYXRjaCBsZWFkaW5nIGFuZCB0cmFpbGluZyB3aGl0ZXNwYWNlLiAqL1xudmFyIHJlVHJpbSA9IC9eXFxzK3xcXHMrJC9nO1xuXG4vKiogVXNlZCB0byBkZXRlY3QgYmFkIHNpZ25lZCBoZXhhZGVjaW1hbCBzdHJpbmcgdmFsdWVzLiAqL1xudmFyIHJlSXNCYWRIZXggPSAvXlstK10weFswLTlhLWZdKyQvaTtcblxuLyoqIFVzZWQgdG8gZGV0ZWN0IGJpbmFyeSBzdHJpbmcgdmFsdWVzLiAqL1xudmFyIHJlSXNCaW5hcnkgPSAvXjBiWzAxXSskL2k7XG5cbi8qKiBVc2VkIHRvIGRldGVjdCBvY3RhbCBzdHJpbmcgdmFsdWVzLiAqL1xudmFyIHJlSXNPY3RhbCA9IC9eMG9bMC03XSskL2k7XG5cbi8qKiBCdWlsdC1pbiBtZXRob2QgcmVmZXJlbmNlcyB3aXRob3V0IGEgZGVwZW5kZW5jeSBvbiBgcm9vdGAuICovXG52YXIgZnJlZVBhcnNlSW50ID0gcGFyc2VJbnQ7XG5cbi8qKiBEZXRlY3QgZnJlZSB2YXJpYWJsZSBgZ2xvYmFsYCBmcm9tIE5vZGUuanMuICovXG52YXIgZnJlZUdsb2JhbCA9IHR5cGVvZiBnbG9iYWwgPT0gJ29iamVjdCcgJiYgZ2xvYmFsICYmIGdsb2JhbC5PYmplY3QgPT09IE9iamVjdCAmJiBnbG9iYWw7XG5cbi8qKiBEZXRlY3QgZnJlZSB2YXJpYWJsZSBgc2VsZmAuICovXG52YXIgZnJlZVNlbGYgPSB0eXBlb2Ygc2VsZiA9PSAnb2JqZWN0JyAmJiBzZWxmICYmIHNlbGYuT2JqZWN0ID09PSBPYmplY3QgJiYgc2VsZjtcblxuLyoqIFVzZWQgYXMgYSByZWZlcmVuY2UgdG8gdGhlIGdsb2JhbCBvYmplY3QuICovXG52YXIgcm9vdCA9IGZyZWVHbG9iYWwgfHwgZnJlZVNlbGYgfHwgRnVuY3Rpb24oJ3JldHVybiB0aGlzJykoKTtcblxuLyoqIFVzZWQgZm9yIGJ1aWx0LWluIG1ldGhvZCByZWZlcmVuY2VzLiAqL1xudmFyIG9iamVjdFByb3RvID0gT2JqZWN0LnByb3RvdHlwZTtcblxuLyoqXG4gKiBVc2VkIHRvIHJlc29sdmUgdGhlXG4gKiBbYHRvU3RyaW5nVGFnYF0oaHR0cDovL2VjbWEtaW50ZXJuYXRpb25hbC5vcmcvZWNtYS0yNjIvNy4wLyNzZWMtb2JqZWN0LnByb3RvdHlwZS50b3N0cmluZylcbiAqIG9mIHZhbHVlcy5cbiAqL1xudmFyIG9iamVjdFRvU3RyaW5nID0gb2JqZWN0UHJvdG8udG9TdHJpbmc7XG5cbi8qIEJ1aWx0LWluIG1ldGhvZCByZWZlcmVuY2VzIGZvciB0aG9zZSB3aXRoIHRoZSBzYW1lIG5hbWUgYXMgb3RoZXIgYGxvZGFzaGAgbWV0aG9kcy4gKi9cbnZhciBuYXRpdmVNYXggPSBNYXRoLm1heCxcbiAgICBuYXRpdmVNaW4gPSBNYXRoLm1pbjtcblxuLyoqXG4gKiBHZXRzIHRoZSB0aW1lc3RhbXAgb2YgdGhlIG51bWJlciBvZiBtaWxsaXNlY29uZHMgdGhhdCBoYXZlIGVsYXBzZWQgc2luY2VcbiAqIHRoZSBVbml4IGVwb2NoICgxIEphbnVhcnkgMTk3MCAwMDowMDowMCBVVEMpLlxuICpcbiAqIEBzdGF0aWNcbiAqIEBtZW1iZXJPZiBfXG4gKiBAc2luY2UgMi40LjBcbiAqIEBjYXRlZ29yeSBEYXRlXG4gKiBAcmV0dXJucyB7bnVtYmVyfSBSZXR1cm5zIHRoZSB0aW1lc3RhbXAuXG4gKiBAZXhhbXBsZVxuICpcbiAqIF8uZGVmZXIoZnVuY3Rpb24oc3RhbXApIHtcbiAqICAgY29uc29sZS5sb2coXy5ub3coKSAtIHN0YW1wKTtcbiAqIH0sIF8ubm93KCkpO1xuICogLy8gPT4gTG9ncyB0aGUgbnVtYmVyIG9mIG1pbGxpc2Vjb25kcyBpdCB0b29rIGZvciB0aGUgZGVmZXJyZWQgaW52b2NhdGlvbi5cbiAqL1xudmFyIG5vdyA9IGZ1bmN0aW9uKCkge1xuICByZXR1cm4gcm9vdC5EYXRlLm5vdygpO1xufTtcblxuLyoqXG4gKiBDcmVhdGVzIGEgZGVib3VuY2VkIGZ1bmN0aW9uIHRoYXQgZGVsYXlzIGludm9raW5nIGBmdW5jYCB1bnRpbCBhZnRlciBgd2FpdGBcbiAqIG1pbGxpc2Vjb25kcyBoYXZlIGVsYXBzZWQgc2luY2UgdGhlIGxhc3QgdGltZSB0aGUgZGVib3VuY2VkIGZ1bmN0aW9uIHdhc1xuICogaW52b2tlZC4gVGhlIGRlYm91bmNlZCBmdW5jdGlvbiBjb21lcyB3aXRoIGEgYGNhbmNlbGAgbWV0aG9kIHRvIGNhbmNlbFxuICogZGVsYXllZCBgZnVuY2AgaW52b2NhdGlvbnMgYW5kIGEgYGZsdXNoYCBtZXRob2QgdG8gaW1tZWRpYXRlbHkgaW52b2tlIHRoZW0uXG4gKiBQcm92aWRlIGBvcHRpb25zYCB0byBpbmRpY2F0ZSB3aGV0aGVyIGBmdW5jYCBzaG91bGQgYmUgaW52b2tlZCBvbiB0aGVcbiAqIGxlYWRpbmcgYW5kL29yIHRyYWlsaW5nIGVkZ2Ugb2YgdGhlIGB3YWl0YCB0aW1lb3V0LiBUaGUgYGZ1bmNgIGlzIGludm9rZWRcbiAqIHdpdGggdGhlIGxhc3QgYXJndW1lbnRzIHByb3ZpZGVkIHRvIHRoZSBkZWJvdW5jZWQgZnVuY3Rpb24uIFN1YnNlcXVlbnRcbiAqIGNhbGxzIHRvIHRoZSBkZWJvdW5jZWQgZnVuY3Rpb24gcmV0dXJuIHRoZSByZXN1bHQgb2YgdGhlIGxhc3QgYGZ1bmNgXG4gKiBpbnZvY2F0aW9uLlxuICpcbiAqICoqTm90ZToqKiBJZiBgbGVhZGluZ2AgYW5kIGB0cmFpbGluZ2Agb3B0aW9ucyBhcmUgYHRydWVgLCBgZnVuY2AgaXNcbiAqIGludm9rZWQgb24gdGhlIHRyYWlsaW5nIGVkZ2Ugb2YgdGhlIHRpbWVvdXQgb25seSBpZiB0aGUgZGVib3VuY2VkIGZ1bmN0aW9uXG4gKiBpcyBpbnZva2VkIG1vcmUgdGhhbiBvbmNlIGR1cmluZyB0aGUgYHdhaXRgIHRpbWVvdXQuXG4gKlxuICogSWYgYHdhaXRgIGlzIGAwYCBhbmQgYGxlYWRpbmdgIGlzIGBmYWxzZWAsIGBmdW5jYCBpbnZvY2F0aW9uIGlzIGRlZmVycmVkXG4gKiB1bnRpbCB0byB0aGUgbmV4dCB0aWNrLCBzaW1pbGFyIHRvIGBzZXRUaW1lb3V0YCB3aXRoIGEgdGltZW91dCBvZiBgMGAuXG4gKlxuICogU2VlIFtEYXZpZCBDb3JiYWNobydzIGFydGljbGVdKGh0dHBzOi8vY3NzLXRyaWNrcy5jb20vZGVib3VuY2luZy10aHJvdHRsaW5nLWV4cGxhaW5lZC1leGFtcGxlcy8pXG4gKiBmb3IgZGV0YWlscyBvdmVyIHRoZSBkaWZmZXJlbmNlcyBiZXR3ZWVuIGBfLmRlYm91bmNlYCBhbmQgYF8udGhyb3R0bGVgLlxuICpcbiAqIEBzdGF0aWNcbiAqIEBtZW1iZXJPZiBfXG4gKiBAc2luY2UgMC4xLjBcbiAqIEBjYXRlZ29yeSBGdW5jdGlvblxuICogQHBhcmFtIHtGdW5jdGlvbn0gZnVuYyBUaGUgZnVuY3Rpb24gdG8gZGVib3VuY2UuXG4gKiBAcGFyYW0ge251bWJlcn0gW3dhaXQ9MF0gVGhlIG51bWJlciBvZiBtaWxsaXNlY29uZHMgdG8gZGVsYXkuXG4gKiBAcGFyYW0ge09iamVjdH0gW29wdGlvbnM9e31dIFRoZSBvcHRpb25zIG9iamVjdC5cbiAqIEBwYXJhbSB7Ym9vbGVhbn0gW29wdGlvbnMubGVhZGluZz1mYWxzZV1cbiAqICBTcGVjaWZ5IGludm9raW5nIG9uIHRoZSBsZWFkaW5nIGVkZ2Ugb2YgdGhlIHRpbWVvdXQuXG4gKiBAcGFyYW0ge251bWJlcn0gW29wdGlvbnMubWF4V2FpdF1cbiAqICBUaGUgbWF4aW11bSB0aW1lIGBmdW5jYCBpcyBhbGxvd2VkIHRvIGJlIGRlbGF5ZWQgYmVmb3JlIGl0J3MgaW52b2tlZC5cbiAqIEBwYXJhbSB7Ym9vbGVhbn0gW29wdGlvbnMudHJhaWxpbmc9dHJ1ZV1cbiAqICBTcGVjaWZ5IGludm9raW5nIG9uIHRoZSB0cmFpbGluZyBlZGdlIG9mIHRoZSB0aW1lb3V0LlxuICogQHJldHVybnMge0Z1bmN0aW9ufSBSZXR1cm5zIHRoZSBuZXcgZGVib3VuY2VkIGZ1bmN0aW9uLlxuICogQGV4YW1wbGVcbiAqXG4gKiAvLyBBdm9pZCBjb3N0bHkgY2FsY3VsYXRpb25zIHdoaWxlIHRoZSB3aW5kb3cgc2l6ZSBpcyBpbiBmbHV4LlxuICogalF1ZXJ5KHdpbmRvdykub24oJ3Jlc2l6ZScsIF8uZGVib3VuY2UoY2FsY3VsYXRlTGF5b3V0LCAxNTApKTtcbiAqXG4gKiAvLyBJbnZva2UgYHNlbmRNYWlsYCB3aGVuIGNsaWNrZWQsIGRlYm91bmNpbmcgc3Vic2VxdWVudCBjYWxscy5cbiAqIGpRdWVyeShlbGVtZW50KS5vbignY2xpY2snLCBfLmRlYm91bmNlKHNlbmRNYWlsLCAzMDAsIHtcbiAqICAgJ2xlYWRpbmcnOiB0cnVlLFxuICogICAndHJhaWxpbmcnOiBmYWxzZVxuICogfSkpO1xuICpcbiAqIC8vIEVuc3VyZSBgYmF0Y2hMb2dgIGlzIGludm9rZWQgb25jZSBhZnRlciAxIHNlY29uZCBvZiBkZWJvdW5jZWQgY2FsbHMuXG4gKiB2YXIgZGVib3VuY2VkID0gXy5kZWJvdW5jZShiYXRjaExvZywgMjUwLCB7ICdtYXhXYWl0JzogMTAwMCB9KTtcbiAqIHZhciBzb3VyY2UgPSBuZXcgRXZlbnRTb3VyY2UoJy9zdHJlYW0nKTtcbiAqIGpRdWVyeShzb3VyY2UpLm9uKCdtZXNzYWdlJywgZGVib3VuY2VkKTtcbiAqXG4gKiAvLyBDYW5jZWwgdGhlIHRyYWlsaW5nIGRlYm91bmNlZCBpbnZvY2F0aW9uLlxuICogalF1ZXJ5KHdpbmRvdykub24oJ3BvcHN0YXRlJywgZGVib3VuY2VkLmNhbmNlbCk7XG4gKi9cbmZ1bmN0aW9uIGRlYm91bmNlKGZ1bmMsIHdhaXQsIG9wdGlvbnMpIHtcbiAgdmFyIGxhc3RBcmdzLFxuICAgICAgbGFzdFRoaXMsXG4gICAgICBtYXhXYWl0LFxuICAgICAgcmVzdWx0LFxuICAgICAgdGltZXJJZCxcbiAgICAgIGxhc3RDYWxsVGltZSxcbiAgICAgIGxhc3RJbnZva2VUaW1lID0gMCxcbiAgICAgIGxlYWRpbmcgPSBmYWxzZSxcbiAgICAgIG1heGluZyA9IGZhbHNlLFxuICAgICAgdHJhaWxpbmcgPSB0cnVlO1xuXG4gIGlmICh0eXBlb2YgZnVuYyAhPSAnZnVuY3Rpb24nKSB7XG4gICAgdGhyb3cgbmV3IFR5cGVFcnJvcihGVU5DX0VSUk9SX1RFWFQpO1xuICB9XG4gIHdhaXQgPSB0b051bWJlcih3YWl0KSB8fCAwO1xuICBpZiAoaXNPYmplY3Qob3B0aW9ucykpIHtcbiAgICBsZWFkaW5nID0gISFvcHRpb25zLmxlYWRpbmc7XG4gICAgbWF4aW5nID0gJ21heFdhaXQnIGluIG9wdGlvbnM7XG4gICAgbWF4V2FpdCA9IG1heGluZyA/IG5hdGl2ZU1heCh0b051bWJlcihvcHRpb25zLm1heFdhaXQpIHx8IDAsIHdhaXQpIDogbWF4V2FpdDtcbiAgICB0cmFpbGluZyA9ICd0cmFpbGluZycgaW4gb3B0aW9ucyA/ICEhb3B0aW9ucy50cmFpbGluZyA6IHRyYWlsaW5nO1xuICB9XG5cbiAgZnVuY3Rpb24gaW52b2tlRnVuYyh0aW1lKSB7XG4gICAgdmFyIGFyZ3MgPSBsYXN0QXJncyxcbiAgICAgICAgdGhpc0FyZyA9IGxhc3RUaGlzO1xuXG4gICAgbGFzdEFyZ3MgPSBsYXN0VGhpcyA9IHVuZGVmaW5lZDtcbiAgICBsYXN0SW52b2tlVGltZSA9IHRpbWU7XG4gICAgcmVzdWx0ID0gZnVuYy5hcHBseSh0aGlzQXJnLCBhcmdzKTtcbiAgICByZXR1cm4gcmVzdWx0O1xuICB9XG5cbiAgZnVuY3Rpb24gbGVhZGluZ0VkZ2UodGltZSkge1xuICAgIC8vIFJlc2V0IGFueSBgbWF4V2FpdGAgdGltZXIuXG4gICAgbGFzdEludm9rZVRpbWUgPSB0aW1lO1xuICAgIC8vIFN0YXJ0IHRoZSB0aW1lciBmb3IgdGhlIHRyYWlsaW5nIGVkZ2UuXG4gICAgdGltZXJJZCA9IHNldFRpbWVvdXQodGltZXJFeHBpcmVkLCB3YWl0KTtcbiAgICAvLyBJbnZva2UgdGhlIGxlYWRpbmcgZWRnZS5cbiAgICByZXR1cm4gbGVhZGluZyA/IGludm9rZUZ1bmModGltZSkgOiByZXN1bHQ7XG4gIH1cblxuICBmdW5jdGlvbiByZW1haW5pbmdXYWl0KHRpbWUpIHtcbiAgICB2YXIgdGltZVNpbmNlTGFzdENhbGwgPSB0aW1lIC0gbGFzdENhbGxUaW1lLFxuICAgICAgICB0aW1lU2luY2VMYXN0SW52b2tlID0gdGltZSAtIGxhc3RJbnZva2VUaW1lLFxuICAgICAgICByZXN1bHQgPSB3YWl0IC0gdGltZVNpbmNlTGFzdENhbGw7XG5cbiAgICByZXR1cm4gbWF4aW5nID8gbmF0aXZlTWluKHJlc3VsdCwgbWF4V2FpdCAtIHRpbWVTaW5jZUxhc3RJbnZva2UpIDogcmVzdWx0O1xuICB9XG5cbiAgZnVuY3Rpb24gc2hvdWxkSW52b2tlKHRpbWUpIHtcbiAgICB2YXIgdGltZVNpbmNlTGFzdENhbGwgPSB0aW1lIC0gbGFzdENhbGxUaW1lLFxuICAgICAgICB0aW1lU2luY2VMYXN0SW52b2tlID0gdGltZSAtIGxhc3RJbnZva2VUaW1lO1xuXG4gICAgLy8gRWl0aGVyIHRoaXMgaXMgdGhlIGZpcnN0IGNhbGwsIGFjdGl2aXR5IGhhcyBzdG9wcGVkIGFuZCB3ZSdyZSBhdCB0aGVcbiAgICAvLyB0cmFpbGluZyBlZGdlLCB0aGUgc3lzdGVtIHRpbWUgaGFzIGdvbmUgYmFja3dhcmRzIGFuZCB3ZSdyZSB0cmVhdGluZ1xuICAgIC8vIGl0IGFzIHRoZSB0cmFpbGluZyBlZGdlLCBvciB3ZSd2ZSBoaXQgdGhlIGBtYXhXYWl0YCBsaW1pdC5cbiAgICByZXR1cm4gKGxhc3RDYWxsVGltZSA9PT0gdW5kZWZpbmVkIHx8ICh0aW1lU2luY2VMYXN0Q2FsbCA+PSB3YWl0KSB8fFxuICAgICAgKHRpbWVTaW5jZUxhc3RDYWxsIDwgMCkgfHwgKG1heGluZyAmJiB0aW1lU2luY2VMYXN0SW52b2tlID49IG1heFdhaXQpKTtcbiAgfVxuXG4gIGZ1bmN0aW9uIHRpbWVyRXhwaXJlZCgpIHtcbiAgICB2YXIgdGltZSA9IG5vdygpO1xuICAgIGlmIChzaG91bGRJbnZva2UodGltZSkpIHtcbiAgICAgIHJldHVybiB0cmFpbGluZ0VkZ2UodGltZSk7XG4gICAgfVxuICAgIC8vIFJlc3RhcnQgdGhlIHRpbWVyLlxuICAgIHRpbWVySWQgPSBzZXRUaW1lb3V0KHRpbWVyRXhwaXJlZCwgcmVtYWluaW5nV2FpdCh0aW1lKSk7XG4gIH1cblxuICBmdW5jdGlvbiB0cmFpbGluZ0VkZ2UodGltZSkge1xuICAgIHRpbWVySWQgPSB1bmRlZmluZWQ7XG5cbiAgICAvLyBPbmx5IGludm9rZSBpZiB3ZSBoYXZlIGBsYXN0QXJnc2Agd2hpY2ggbWVhbnMgYGZ1bmNgIGhhcyBiZWVuXG4gICAgLy8gZGVib3VuY2VkIGF0IGxlYXN0IG9uY2UuXG4gICAgaWYgKHRyYWlsaW5nICYmIGxhc3RBcmdzKSB7XG4gICAgICByZXR1cm4gaW52b2tlRnVuYyh0aW1lKTtcbiAgICB9XG4gICAgbGFzdEFyZ3MgPSBsYXN0VGhpcyA9IHVuZGVmaW5lZDtcbiAgICByZXR1cm4gcmVzdWx0O1xuICB9XG5cbiAgZnVuY3Rpb24gY2FuY2VsKCkge1xuICAgIGlmICh0aW1lcklkICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIGNsZWFyVGltZW91dCh0aW1lcklkKTtcbiAgICB9XG4gICAgbGFzdEludm9rZVRpbWUgPSAwO1xuICAgIGxhc3RBcmdzID0gbGFzdENhbGxUaW1lID0gbGFzdFRoaXMgPSB0aW1lcklkID0gdW5kZWZpbmVkO1xuICB9XG5cbiAgZnVuY3Rpb24gZmx1c2goKSB7XG4gICAgcmV0dXJuIHRpbWVySWQgPT09IHVuZGVmaW5lZCA/IHJlc3VsdCA6IHRyYWlsaW5nRWRnZShub3coKSk7XG4gIH1cblxuICBmdW5jdGlvbiBkZWJvdW5jZWQoKSB7XG4gICAgdmFyIHRpbWUgPSBub3coKSxcbiAgICAgICAgaXNJbnZva2luZyA9IHNob3VsZEludm9rZSh0aW1lKTtcblxuICAgIGxhc3RBcmdzID0gYXJndW1lbnRzO1xuICAgIGxhc3RUaGlzID0gdGhpcztcbiAgICBsYXN0Q2FsbFRpbWUgPSB0aW1lO1xuXG4gICAgaWYgKGlzSW52b2tpbmcpIHtcbiAgICAgIGlmICh0aW1lcklkID09PSB1bmRlZmluZWQpIHtcbiAgICAgICAgcmV0dXJuIGxlYWRpbmdFZGdlKGxhc3RDYWxsVGltZSk7XG4gICAgICB9XG4gICAgICBpZiAobWF4aW5nKSB7XG4gICAgICAgIC8vIEhhbmRsZSBpbnZvY2F0aW9ucyBpbiBhIHRpZ2h0IGxvb3AuXG4gICAgICAgIHRpbWVySWQgPSBzZXRUaW1lb3V0KHRpbWVyRXhwaXJlZCwgd2FpdCk7XG4gICAgICAgIHJldHVybiBpbnZva2VGdW5jKGxhc3RDYWxsVGltZSk7XG4gICAgICB9XG4gICAgfVxuICAgIGlmICh0aW1lcklkID09PSB1bmRlZmluZWQpIHtcbiAgICAgIHRpbWVySWQgPSBzZXRUaW1lb3V0KHRpbWVyRXhwaXJlZCwgd2FpdCk7XG4gICAgfVxuICAgIHJldHVybiByZXN1bHQ7XG4gIH1cbiAgZGVib3VuY2VkLmNhbmNlbCA9IGNhbmNlbDtcbiAgZGVib3VuY2VkLmZsdXNoID0gZmx1c2g7XG4gIHJldHVybiBkZWJvdW5jZWQ7XG59XG5cbi8qKlxuICogQ3JlYXRlcyBhIHRocm90dGxlZCBmdW5jdGlvbiB0aGF0IG9ubHkgaW52b2tlcyBgZnVuY2AgYXQgbW9zdCBvbmNlIHBlclxuICogZXZlcnkgYHdhaXRgIG1pbGxpc2Vjb25kcy4gVGhlIHRocm90dGxlZCBmdW5jdGlvbiBjb21lcyB3aXRoIGEgYGNhbmNlbGBcbiAqIG1ldGhvZCB0byBjYW5jZWwgZGVsYXllZCBgZnVuY2AgaW52b2NhdGlvbnMgYW5kIGEgYGZsdXNoYCBtZXRob2QgdG9cbiAqIGltbWVkaWF0ZWx5IGludm9rZSB0aGVtLiBQcm92aWRlIGBvcHRpb25zYCB0byBpbmRpY2F0ZSB3aGV0aGVyIGBmdW5jYFxuICogc2hvdWxkIGJlIGludm9rZWQgb24gdGhlIGxlYWRpbmcgYW5kL29yIHRyYWlsaW5nIGVkZ2Ugb2YgdGhlIGB3YWl0YFxuICogdGltZW91dC4gVGhlIGBmdW5jYCBpcyBpbnZva2VkIHdpdGggdGhlIGxhc3QgYXJndW1lbnRzIHByb3ZpZGVkIHRvIHRoZVxuICogdGhyb3R0bGVkIGZ1bmN0aW9uLiBTdWJzZXF1ZW50IGNhbGxzIHRvIHRoZSB0aHJvdHRsZWQgZnVuY3Rpb24gcmV0dXJuIHRoZVxuICogcmVzdWx0IG9mIHRoZSBsYXN0IGBmdW5jYCBpbnZvY2F0aW9uLlxuICpcbiAqICoqTm90ZToqKiBJZiBgbGVhZGluZ2AgYW5kIGB0cmFpbGluZ2Agb3B0aW9ucyBhcmUgYHRydWVgLCBgZnVuY2AgaXNcbiAqIGludm9rZWQgb24gdGhlIHRyYWlsaW5nIGVkZ2Ugb2YgdGhlIHRpbWVvdXQgb25seSBpZiB0aGUgdGhyb3R0bGVkIGZ1bmN0aW9uXG4gKiBpcyBpbnZva2VkIG1vcmUgdGhhbiBvbmNlIGR1cmluZyB0aGUgYHdhaXRgIHRpbWVvdXQuXG4gKlxuICogSWYgYHdhaXRgIGlzIGAwYCBhbmQgYGxlYWRpbmdgIGlzIGBmYWxzZWAsIGBmdW5jYCBpbnZvY2F0aW9uIGlzIGRlZmVycmVkXG4gKiB1bnRpbCB0byB0aGUgbmV4dCB0aWNrLCBzaW1pbGFyIHRvIGBzZXRUaW1lb3V0YCB3aXRoIGEgdGltZW91dCBvZiBgMGAuXG4gKlxuICogU2VlIFtEYXZpZCBDb3JiYWNobydzIGFydGljbGVdKGh0dHBzOi8vY3NzLXRyaWNrcy5jb20vZGVib3VuY2luZy10aHJvdHRsaW5nLWV4cGxhaW5lZC1leGFtcGxlcy8pXG4gKiBmb3IgZGV0YWlscyBvdmVyIHRoZSBkaWZmZXJlbmNlcyBiZXR3ZWVuIGBfLnRocm90dGxlYCBhbmQgYF8uZGVib3VuY2VgLlxuICpcbiAqIEBzdGF0aWNcbiAqIEBtZW1iZXJPZiBfXG4gKiBAc2luY2UgMC4xLjBcbiAqIEBjYXRlZ29yeSBGdW5jdGlvblxuICogQHBhcmFtIHtGdW5jdGlvbn0gZnVuYyBUaGUgZnVuY3Rpb24gdG8gdGhyb3R0bGUuXG4gKiBAcGFyYW0ge251bWJlcn0gW3dhaXQ9MF0gVGhlIG51bWJlciBvZiBtaWxsaXNlY29uZHMgdG8gdGhyb3R0bGUgaW52b2NhdGlvbnMgdG8uXG4gKiBAcGFyYW0ge09iamVjdH0gW29wdGlvbnM9e31dIFRoZSBvcHRpb25zIG9iamVjdC5cbiAqIEBwYXJhbSB7Ym9vbGVhbn0gW29wdGlvbnMubGVhZGluZz10cnVlXVxuICogIFNwZWNpZnkgaW52b2tpbmcgb24gdGhlIGxlYWRpbmcgZWRnZSBvZiB0aGUgdGltZW91dC5cbiAqIEBwYXJhbSB7Ym9vbGVhbn0gW29wdGlvbnMudHJhaWxpbmc9dHJ1ZV1cbiAqICBTcGVjaWZ5IGludm9raW5nIG9uIHRoZSB0cmFpbGluZyBlZGdlIG9mIHRoZSB0aW1lb3V0LlxuICogQHJldHVybnMge0Z1bmN0aW9ufSBSZXR1cm5zIHRoZSBuZXcgdGhyb3R0bGVkIGZ1bmN0aW9uLlxuICogQGV4YW1wbGVcbiAqXG4gKiAvLyBBdm9pZCBleGNlc3NpdmVseSB1cGRhdGluZyB0aGUgcG9zaXRpb24gd2hpbGUgc2Nyb2xsaW5nLlxuICogalF1ZXJ5KHdpbmRvdykub24oJ3Njcm9sbCcsIF8udGhyb3R0bGUodXBkYXRlUG9zaXRpb24sIDEwMCkpO1xuICpcbiAqIC8vIEludm9rZSBgcmVuZXdUb2tlbmAgd2hlbiB0aGUgY2xpY2sgZXZlbnQgaXMgZmlyZWQsIGJ1dCBub3QgbW9yZSB0aGFuIG9uY2UgZXZlcnkgNSBtaW51dGVzLlxuICogdmFyIHRocm90dGxlZCA9IF8udGhyb3R0bGUocmVuZXdUb2tlbiwgMzAwMDAwLCB7ICd0cmFpbGluZyc6IGZhbHNlIH0pO1xuICogalF1ZXJ5KGVsZW1lbnQpLm9uKCdjbGljaycsIHRocm90dGxlZCk7XG4gKlxuICogLy8gQ2FuY2VsIHRoZSB0cmFpbGluZyB0aHJvdHRsZWQgaW52b2NhdGlvbi5cbiAqIGpRdWVyeSh3aW5kb3cpLm9uKCdwb3BzdGF0ZScsIHRocm90dGxlZC5jYW5jZWwpO1xuICovXG5mdW5jdGlvbiB0aHJvdHRsZShmdW5jLCB3YWl0LCBvcHRpb25zKSB7XG4gIHZhciBsZWFkaW5nID0gdHJ1ZSxcbiAgICAgIHRyYWlsaW5nID0gdHJ1ZTtcblxuICBpZiAodHlwZW9mIGZ1bmMgIT0gJ2Z1bmN0aW9uJykge1xuICAgIHRocm93IG5ldyBUeXBlRXJyb3IoRlVOQ19FUlJPUl9URVhUKTtcbiAgfVxuICBpZiAoaXNPYmplY3Qob3B0aW9ucykpIHtcbiAgICBsZWFkaW5nID0gJ2xlYWRpbmcnIGluIG9wdGlvbnMgPyAhIW9wdGlvbnMubGVhZGluZyA6IGxlYWRpbmc7XG4gICAgdHJhaWxpbmcgPSAndHJhaWxpbmcnIGluIG9wdGlvbnMgPyAhIW9wdGlvbnMudHJhaWxpbmcgOiB0cmFpbGluZztcbiAgfVxuICByZXR1cm4gZGVib3VuY2UoZnVuYywgd2FpdCwge1xuICAgICdsZWFkaW5nJzogbGVhZGluZyxcbiAgICAnbWF4V2FpdCc6IHdhaXQsXG4gICAgJ3RyYWlsaW5nJzogdHJhaWxpbmdcbiAgfSk7XG59XG5cbi8qKlxuICogQ2hlY2tzIGlmIGB2YWx1ZWAgaXMgdGhlXG4gKiBbbGFuZ3VhZ2UgdHlwZV0oaHR0cDovL3d3dy5lY21hLWludGVybmF0aW9uYWwub3JnL2VjbWEtMjYyLzcuMC8jc2VjLWVjbWFzY3JpcHQtbGFuZ3VhZ2UtdHlwZXMpXG4gKiBvZiBgT2JqZWN0YC4gKGUuZy4gYXJyYXlzLCBmdW5jdGlvbnMsIG9iamVjdHMsIHJlZ2V4ZXMsIGBuZXcgTnVtYmVyKDApYCwgYW5kIGBuZXcgU3RyaW5nKCcnKWApXG4gKlxuICogQHN0YXRpY1xuICogQG1lbWJlck9mIF9cbiAqIEBzaW5jZSAwLjEuMFxuICogQGNhdGVnb3J5IExhbmdcbiAqIEBwYXJhbSB7Kn0gdmFsdWUgVGhlIHZhbHVlIHRvIGNoZWNrLlxuICogQHJldHVybnMge2Jvb2xlYW59IFJldHVybnMgYHRydWVgIGlmIGB2YWx1ZWAgaXMgYW4gb2JqZWN0LCBlbHNlIGBmYWxzZWAuXG4gKiBAZXhhbXBsZVxuICpcbiAqIF8uaXNPYmplY3Qoe30pO1xuICogLy8gPT4gdHJ1ZVxuICpcbiAqIF8uaXNPYmplY3QoWzEsIDIsIDNdKTtcbiAqIC8vID0+IHRydWVcbiAqXG4gKiBfLmlzT2JqZWN0KF8ubm9vcCk7XG4gKiAvLyA9PiB0cnVlXG4gKlxuICogXy5pc09iamVjdChudWxsKTtcbiAqIC8vID0+IGZhbHNlXG4gKi9cbmZ1bmN0aW9uIGlzT2JqZWN0KHZhbHVlKSB7XG4gIHZhciB0eXBlID0gdHlwZW9mIHZhbHVlO1xuICByZXR1cm4gISF2YWx1ZSAmJiAodHlwZSA9PSAnb2JqZWN0JyB8fCB0eXBlID09ICdmdW5jdGlvbicpO1xufVxuXG4vKipcbiAqIENoZWNrcyBpZiBgdmFsdWVgIGlzIG9iamVjdC1saWtlLiBBIHZhbHVlIGlzIG9iamVjdC1saWtlIGlmIGl0J3Mgbm90IGBudWxsYFxuICogYW5kIGhhcyBhIGB0eXBlb2ZgIHJlc3VsdCBvZiBcIm9iamVjdFwiLlxuICpcbiAqIEBzdGF0aWNcbiAqIEBtZW1iZXJPZiBfXG4gKiBAc2luY2UgNC4wLjBcbiAqIEBjYXRlZ29yeSBMYW5nXG4gKiBAcGFyYW0geyp9IHZhbHVlIFRoZSB2YWx1ZSB0byBjaGVjay5cbiAqIEByZXR1cm5zIHtib29sZWFufSBSZXR1cm5zIGB0cnVlYCBpZiBgdmFsdWVgIGlzIG9iamVjdC1saWtlLCBlbHNlIGBmYWxzZWAuXG4gKiBAZXhhbXBsZVxuICpcbiAqIF8uaXNPYmplY3RMaWtlKHt9KTtcbiAqIC8vID0+IHRydWVcbiAqXG4gKiBfLmlzT2JqZWN0TGlrZShbMSwgMiwgM10pO1xuICogLy8gPT4gdHJ1ZVxuICpcbiAqIF8uaXNPYmplY3RMaWtlKF8ubm9vcCk7XG4gKiAvLyA9PiBmYWxzZVxuICpcbiAqIF8uaXNPYmplY3RMaWtlKG51bGwpO1xuICogLy8gPT4gZmFsc2VcbiAqL1xuZnVuY3Rpb24gaXNPYmplY3RMaWtlKHZhbHVlKSB7XG4gIHJldHVybiAhIXZhbHVlICYmIHR5cGVvZiB2YWx1ZSA9PSAnb2JqZWN0Jztcbn1cblxuLyoqXG4gKiBDaGVja3MgaWYgYHZhbHVlYCBpcyBjbGFzc2lmaWVkIGFzIGEgYFN5bWJvbGAgcHJpbWl0aXZlIG9yIG9iamVjdC5cbiAqXG4gKiBAc3RhdGljXG4gKiBAbWVtYmVyT2YgX1xuICogQHNpbmNlIDQuMC4wXG4gKiBAY2F0ZWdvcnkgTGFuZ1xuICogQHBhcmFtIHsqfSB2YWx1ZSBUaGUgdmFsdWUgdG8gY2hlY2suXG4gKiBAcmV0dXJucyB7Ym9vbGVhbn0gUmV0dXJucyBgdHJ1ZWAgaWYgYHZhbHVlYCBpcyBhIHN5bWJvbCwgZWxzZSBgZmFsc2VgLlxuICogQGV4YW1wbGVcbiAqXG4gKiBfLmlzU3ltYm9sKFN5bWJvbC5pdGVyYXRvcik7XG4gKiAvLyA9PiB0cnVlXG4gKlxuICogXy5pc1N5bWJvbCgnYWJjJyk7XG4gKiAvLyA9PiBmYWxzZVxuICovXG5mdW5jdGlvbiBpc1N5bWJvbCh2YWx1ZSkge1xuICByZXR1cm4gdHlwZW9mIHZhbHVlID09ICdzeW1ib2wnIHx8XG4gICAgKGlzT2JqZWN0TGlrZSh2YWx1ZSkgJiYgb2JqZWN0VG9TdHJpbmcuY2FsbCh2YWx1ZSkgPT0gc3ltYm9sVGFnKTtcbn1cblxuLyoqXG4gKiBDb252ZXJ0cyBgdmFsdWVgIHRvIGEgbnVtYmVyLlxuICpcbiAqIEBzdGF0aWNcbiAqIEBtZW1iZXJPZiBfXG4gKiBAc2luY2UgNC4wLjBcbiAqIEBjYXRlZ29yeSBMYW5nXG4gKiBAcGFyYW0geyp9IHZhbHVlIFRoZSB2YWx1ZSB0byBwcm9jZXNzLlxuICogQHJldHVybnMge251bWJlcn0gUmV0dXJucyB0aGUgbnVtYmVyLlxuICogQGV4YW1wbGVcbiAqXG4gKiBfLnRvTnVtYmVyKDMuMik7XG4gKiAvLyA9PiAzLjJcbiAqXG4gKiBfLnRvTnVtYmVyKE51bWJlci5NSU5fVkFMVUUpO1xuICogLy8gPT4gNWUtMzI0XG4gKlxuICogXy50b051bWJlcihJbmZpbml0eSk7XG4gKiAvLyA9PiBJbmZpbml0eVxuICpcbiAqIF8udG9OdW1iZXIoJzMuMicpO1xuICogLy8gPT4gMy4yXG4gKi9cbmZ1bmN0aW9uIHRvTnVtYmVyKHZhbHVlKSB7XG4gIGlmICh0eXBlb2YgdmFsdWUgPT0gJ251bWJlcicpIHtcbiAgICByZXR1cm4gdmFsdWU7XG4gIH1cbiAgaWYgKGlzU3ltYm9sKHZhbHVlKSkge1xuICAgIHJldHVybiBOQU47XG4gIH1cbiAgaWYgKGlzT2JqZWN0KHZhbHVlKSkge1xuICAgIHZhciBvdGhlciA9IHR5cGVvZiB2YWx1ZS52YWx1ZU9mID09ICdmdW5jdGlvbicgPyB2YWx1ZS52YWx1ZU9mKCkgOiB2YWx1ZTtcbiAgICB2YWx1ZSA9IGlzT2JqZWN0KG90aGVyKSA/IChvdGhlciArICcnKSA6IG90aGVyO1xuICB9XG4gIGlmICh0eXBlb2YgdmFsdWUgIT0gJ3N0cmluZycpIHtcbiAgICByZXR1cm4gdmFsdWUgPT09IDAgPyB2YWx1ZSA6ICt2YWx1ZTtcbiAgfVxuICB2YWx1ZSA9IHZhbHVlLnJlcGxhY2UocmVUcmltLCAnJyk7XG4gIHZhciBpc0JpbmFyeSA9IHJlSXNCaW5hcnkudGVzdCh2YWx1ZSk7XG4gIHJldHVybiAoaXNCaW5hcnkgfHwgcmVJc09jdGFsLnRlc3QodmFsdWUpKVxuICAgID8gZnJlZVBhcnNlSW50KHZhbHVlLnNsaWNlKDIpLCBpc0JpbmFyeSA/IDIgOiA4KVxuICAgIDogKHJlSXNCYWRIZXgudGVzdCh2YWx1ZSkgPyBOQU4gOiArdmFsdWUpO1xufVxuXG5tb2R1bGUuZXhwb3J0cyA9IHRocm90dGxlO1xuIiwidmFyIGc7XHJcblxyXG4vLyBUaGlzIHdvcmtzIGluIG5vbi1zdHJpY3QgbW9kZVxyXG5nID0gKGZ1bmN0aW9uKCkge1xyXG5cdHJldHVybiB0aGlzO1xyXG59KSgpO1xyXG5cclxudHJ5IHtcclxuXHQvLyBUaGlzIHdvcmtzIGlmIGV2YWwgaXMgYWxsb3dlZCAoc2VlIENTUClcclxuXHRnID0gZyB8fCBGdW5jdGlvbihcInJldHVybiB0aGlzXCIpKCkgfHwgKDEsIGV2YWwpKFwidGhpc1wiKTtcclxufSBjYXRjaCAoZSkge1xyXG5cdC8vIFRoaXMgd29ya3MgaWYgdGhlIHdpbmRvdyByZWZlcmVuY2UgaXMgYXZhaWxhYmxlXHJcblx0aWYgKHR5cGVvZiB3aW5kb3cgPT09IFwib2JqZWN0XCIpIGcgPSB3aW5kb3c7XHJcbn1cclxuXHJcbi8vIGcgY2FuIHN0aWxsIGJlIHVuZGVmaW5lZCwgYnV0IG5vdGhpbmcgdG8gZG8gYWJvdXQgaXQuLi5cclxuLy8gV2UgcmV0dXJuIHVuZGVmaW5lZCwgaW5zdGVhZCBvZiBub3RoaW5nIGhlcmUsIHNvIGl0J3NcclxuLy8gZWFzaWVyIHRvIGhhbmRsZSB0aGlzIGNhc2UuIGlmKCFnbG9iYWwpIHsgLi4ufVxyXG5cclxubW9kdWxlLmV4cG9ydHMgPSBnO1xyXG4iLCIvKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVxuICogIENvcHlyaWdodCAoYykgTWljcm9zb2Z0IENvcnBvcmF0aW9uLiBBbGwgcmlnaHRzIHJlc2VydmVkLlxuICogIExpY2Vuc2VkIHVuZGVyIHRoZSBNSVQgTGljZW5zZS4gU2VlIExpY2Vuc2UudHh0IGluIHRoZSBwcm9qZWN0IHJvb3QgZm9yIGxpY2Vuc2UgaW5mb3JtYXRpb24uXG4gKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKi9cbmltcG9ydCB7IGdldEVsZW1lbnRzRm9yU291cmNlTGluZSB9IGZyb20gJy4vc2Nyb2xsLXN5bmMnO1xuXG5leHBvcnQgY2xhc3MgQWN0aXZlTGluZU1hcmtlciB7XG5cdHByaXZhdGUgX2N1cnJlbnQ6IGFueTtcblxuXHRvbkRpZENoYW5nZVRleHRFZGl0b3JTZWxlY3Rpb24obGluZTogbnVtYmVyKSB7XG5cdFx0Y29uc3QgeyBwcmV2aW91cyB9ID0gZ2V0RWxlbWVudHNGb3JTb3VyY2VMaW5lKGxpbmUpO1xuXHRcdHRoaXMuX3VwZGF0ZShwcmV2aW91cyAmJiBwcmV2aW91cy5lbGVtZW50KTtcblx0fVxuXG5cdF91cGRhdGUoYmVmb3JlOiBIVE1MRWxlbWVudCB8IHVuZGVmaW5lZCkge1xuXHRcdHRoaXMuX3VubWFya0FjdGl2ZUVsZW1lbnQodGhpcy5fY3VycmVudCk7XG5cdFx0dGhpcy5fbWFya0FjdGl2ZUVsZW1lbnQoYmVmb3JlKTtcblx0XHR0aGlzLl9jdXJyZW50ID0gYmVmb3JlO1xuXHR9XG5cblx0X3VubWFya0FjdGl2ZUVsZW1lbnQoZWxlbWVudDogSFRNTEVsZW1lbnQgfCB1bmRlZmluZWQpIHtcblx0XHRpZiAoIWVsZW1lbnQpIHtcblx0XHRcdHJldHVybjtcblx0XHR9XG5cdFx0ZWxlbWVudC5jbGFzc05hbWUgPSBlbGVtZW50LmNsYXNzTmFtZS5yZXBsYWNlKC9cXGJjb2RlLWFjdGl2ZS1saW5lXFxiL2csICcnKTtcblx0fVxuXG5cdF9tYXJrQWN0aXZlRWxlbWVudChlbGVtZW50OiBIVE1MRWxlbWVudCB8IHVuZGVmaW5lZCkge1xuXHRcdGlmICghZWxlbWVudCkge1xuXHRcdFx0cmV0dXJuO1xuXHRcdH1cblx0XHRlbGVtZW50LmNsYXNzTmFtZSArPSAnIGNvZGUtYWN0aXZlLWxpbmUnO1xuXHR9XG59IiwiLyotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS1cbiAqICBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4gQWxsIHJpZ2h0cyByZXNlcnZlZC5cbiAqICBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuIFNlZSBMaWNlbnNlLnR4dCBpbiB0aGUgcHJvamVjdCByb290IGZvciBsaWNlbnNlIGluZm9ybWF0aW9uLlxuICotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSovXG5cbmV4cG9ydCBmdW5jdGlvbiBvbmNlRG9jdW1lbnRMb2FkZWQoZjogKCkgPT4gdm9pZCkge1xuXHRpZiAoZG9jdW1lbnQucmVhZHlTdGF0ZSA9PT0gJ2xvYWRpbmcnIHx8IGRvY3VtZW50LnJlYWR5U3RhdGUgPT09ICd1bmluaXRpYWxpemVkJykge1xuXHRcdGRvY3VtZW50LmFkZEV2ZW50TGlzdGVuZXIoJ0RPTUNvbnRlbnRMb2FkZWQnLCBmKTtcblx0fSBlbHNlIHtcblx0XHRmKCk7XG5cdH1cbn0iLCIvKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVxuICogIENvcHlyaWdodCAoYykgTWljcm9zb2Z0IENvcnBvcmF0aW9uLiBBbGwgcmlnaHRzIHJlc2VydmVkLlxuICogIExpY2Vuc2VkIHVuZGVyIHRoZSBNSVQgTGljZW5zZS4gU2VlIExpY2Vuc2UudHh0IGluIHRoZSBwcm9qZWN0IHJvb3QgZm9yIGxpY2Vuc2UgaW5mb3JtYXRpb24uXG4gKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKi9cblxuaW1wb3J0IHsgQWN0aXZlTGluZU1hcmtlciB9IGZyb20gJy4vYWN0aXZlTGluZU1hcmtlcic7XG5pbXBvcnQgeyBvbmNlRG9jdW1lbnRMb2FkZWQgfSBmcm9tICcuL2V2ZW50cyc7XG5pbXBvcnQgeyBjcmVhdGVQb3N0ZXJGb3JWc0NvZGUgfSBmcm9tICcuL21lc3NhZ2luZyc7XG5pbXBvcnQgeyBnZXRFZGl0b3JMaW5lTnVtYmVyRm9yUGFnZU9mZnNldCwgc2Nyb2xsVG9SZXZlYWxTb3VyY2VMaW5lIH0gZnJvbSAnLi9zY3JvbGwtc3luYyc7XG5pbXBvcnQgeyBnZXRTZXR0aW5ncywgZ2V0RGF0YSB9IGZyb20gJy4vc2V0dGluZ3MnO1xuaW1wb3J0IHRocm90dGxlID0gcmVxdWlyZSgnbG9kYXNoLnRocm90dGxlJyk7XG5cbmRlY2xhcmUgdmFyIGFjcXVpcmVWc0NvZGVBcGk6IGFueTtcblxudmFyIHNjcm9sbERpc2FibGVkID0gdHJ1ZTtcbmNvbnN0IG1hcmtlciA9IG5ldyBBY3RpdmVMaW5lTWFya2VyKCk7XG5jb25zdCBzZXR0aW5ncyA9IGdldFNldHRpbmdzKCk7XG5cbmNvbnN0IHZzY29kZSA9IGFjcXVpcmVWc0NvZGVBcGkoKTtcblxuLy8gU2V0IFZTIENvZGUgc3RhdGVcbmNvbnN0IHN0YXRlID0gZ2V0RGF0YSgnZGF0YS1zdGF0ZScpO1xudnNjb2RlLnNldFN0YXRlKHN0YXRlKTtcblxuY29uc3QgbWVzc2FnaW5nID0gY3JlYXRlUG9zdGVyRm9yVnNDb2RlKHZzY29kZSk7XG5cbndpbmRvdy5jc3BBbGVydGVyLnNldFBvc3RlcihtZXNzYWdpbmcpO1xud2luZG93LnN0eWxlTG9hZGluZ01vbml0b3Iuc2V0UG9zdGVyKG1lc3NhZ2luZyk7XG5cbndpbmRvdy5vbmxvYWQgPSAoKSA9PiB7XG5cdHVwZGF0ZUltYWdlU2l6ZXMoKTtcbn07XG5cbm9uY2VEb2N1bWVudExvYWRlZCgoKSA9PiB7XG5cdGlmIChzZXR0aW5ncy5zY3JvbGxQcmV2aWV3V2l0aEVkaXRvcikge1xuXHRcdHNldFRpbWVvdXQoKCkgPT4ge1xuXHRcdFx0Y29uc3QgaW5pdGlhbExpbmUgPSArc2V0dGluZ3MubGluZTtcblx0XHRcdGlmICghaXNOYU4oaW5pdGlhbExpbmUpKSB7XG5cdFx0XHRcdHNjcm9sbERpc2FibGVkID0gdHJ1ZTtcblx0XHRcdFx0c2Nyb2xsVG9SZXZlYWxTb3VyY2VMaW5lKGluaXRpYWxMaW5lKTtcblx0XHRcdH1cblx0XHR9LCAwKTtcblx0fVxufSk7XG5cbmNvbnN0IG9uVXBkYXRlVmlldyA9ICgoKSA9PiB7XG5cdGNvbnN0IGRvU2Nyb2xsID0gdGhyb3R0bGUoKGxpbmU6IG51bWJlcikgPT4ge1xuXHRcdHNjcm9sbERpc2FibGVkID0gdHJ1ZTtcblx0XHRzY3JvbGxUb1JldmVhbFNvdXJjZUxpbmUobGluZSk7XG5cdH0sIDUwKTtcblxuXHRyZXR1cm4gKGxpbmU6IG51bWJlciwgc2V0dGluZ3M6IGFueSkgPT4ge1xuXHRcdGlmICghaXNOYU4obGluZSkpIHtcblx0XHRcdHNldHRpbmdzLmxpbmUgPSBsaW5lO1xuXHRcdFx0ZG9TY3JvbGwobGluZSk7XG5cdFx0fVxuXHR9O1xufSkoKTtcblxubGV0IHVwZGF0ZUltYWdlU2l6ZXMgPSB0aHJvdHRsZSgoKSA9PiB7XG5cdGNvbnN0IGltYWdlSW5mbzogeyBpZDogc3RyaW5nLCBoZWlnaHQ6IG51bWJlciwgd2lkdGg6IG51bWJlciB9W10gPSBbXTtcblx0bGV0IGltYWdlcyA9IGRvY3VtZW50LmdldEVsZW1lbnRzQnlUYWdOYW1lKCdpbWcnKTtcblx0aWYgKGltYWdlcykge1xuXHRcdGxldCBpO1xuXHRcdGZvciAoaSA9IDA7IGkgPCBpbWFnZXMubGVuZ3RoOyBpKyspIHtcblx0XHRcdGNvbnN0IGltZyA9IGltYWdlc1tpXTtcblxuXHRcdFx0aWYgKGltZy5jbGFzc0xpc3QuY29udGFpbnMoJ2xvYWRpbmcnKSkge1xuXHRcdFx0XHRpbWcuY2xhc3NMaXN0LnJlbW92ZSgnbG9hZGluZycpO1xuXHRcdFx0fVxuXG5cdFx0XHRpbWFnZUluZm8ucHVzaCh7XG5cdFx0XHRcdGlkOiBpbWcuaWQsXG5cdFx0XHRcdGhlaWdodDogaW1nLmhlaWdodCxcblx0XHRcdFx0d2lkdGg6IGltZy53aWR0aFxuXHRcdFx0fSk7XG5cdFx0fVxuXG5cdFx0bWVzc2FnaW5nLnBvc3RNZXNzYWdlKCdjYWNoZUltYWdlU2l6ZXMnLCBpbWFnZUluZm8pO1xuXHR9XG59LCA1MCk7XG5cbndpbmRvdy5hZGRFdmVudExpc3RlbmVyKCdyZXNpemUnLCAoKSA9PiB7XG5cdHNjcm9sbERpc2FibGVkID0gdHJ1ZTtcblx0dXBkYXRlSW1hZ2VTaXplcygpO1xufSwgdHJ1ZSk7XG5cbndpbmRvdy5hZGRFdmVudExpc3RlbmVyKCdtZXNzYWdlJywgZXZlbnQgPT4ge1xuXHRpZiAoZXZlbnQuZGF0YS5zb3VyY2UgIT09IHNldHRpbmdzLnNvdXJjZSkge1xuXHRcdHJldHVybjtcblx0fVxuXG5cdHN3aXRjaCAoZXZlbnQuZGF0YS50eXBlKSB7XG5cdFx0Y2FzZSAnb25EaWRDaGFuZ2VUZXh0RWRpdG9yU2VsZWN0aW9uJzpcblx0XHRcdG1hcmtlci5vbkRpZENoYW5nZVRleHRFZGl0b3JTZWxlY3Rpb24oZXZlbnQuZGF0YS5saW5lKTtcblx0XHRcdGJyZWFrO1xuXG5cdFx0Y2FzZSAndXBkYXRlVmlldyc6XG5cdFx0XHRvblVwZGF0ZVZpZXcoZXZlbnQuZGF0YS5saW5lLCBzZXR0aW5ncyk7XG5cdFx0XHRicmVhaztcblx0fVxufSwgZmFsc2UpO1xuXG5kb2N1bWVudC5hZGRFdmVudExpc3RlbmVyKCdkYmxjbGljaycsIGV2ZW50ID0+IHtcblx0aWYgKCFzZXR0aW5ncy5kb3VibGVDbGlja1RvU3dpdGNoVG9FZGl0b3IpIHtcblx0XHRyZXR1cm47XG5cdH1cblxuXHQvLyBJZ25vcmUgY2xpY2tzIG9uIGxpbmtzXG5cdGZvciAobGV0IG5vZGUgPSBldmVudC50YXJnZXQgYXMgSFRNTEVsZW1lbnQ7IG5vZGU7IG5vZGUgPSBub2RlLnBhcmVudE5vZGUgYXMgSFRNTEVsZW1lbnQpIHtcblx0XHRpZiAobm9kZS50YWdOYW1lID09PSAnQScpIHtcblx0XHRcdHJldHVybjtcblx0XHR9XG5cdH1cblxuXHRjb25zdCBvZmZzZXQgPSBldmVudC5wYWdlWTtcblx0Y29uc3QgbGluZSA9IGdldEVkaXRvckxpbmVOdW1iZXJGb3JQYWdlT2Zmc2V0KG9mZnNldCk7XG5cdGlmICh0eXBlb2YgbGluZSA9PT0gJ251bWJlcicgJiYgIWlzTmFOKGxpbmUpKSB7XG5cdFx0bWVzc2FnaW5nLnBvc3RNZXNzYWdlKCdkaWRDbGljaycsIHsgbGluZTogTWF0aC5mbG9vcihsaW5lKSB9KTtcblx0fVxufSk7XG5cbmRvY3VtZW50LmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgZXZlbnQgPT4ge1xuXHRpZiAoIWV2ZW50KSB7XG5cdFx0cmV0dXJuO1xuXHR9XG5cblx0bGV0IG5vZGU6IGFueSA9IGV2ZW50LnRhcmdldDtcblx0d2hpbGUgKG5vZGUpIHtcblx0XHRpZiAobm9kZS50YWdOYW1lICYmIG5vZGUudGFnTmFtZSA9PT0gJ0EnICYmIG5vZGUuaHJlZikge1xuXHRcdFx0aWYgKG5vZGUuZ2V0QXR0cmlidXRlKCdocmVmJykuc3RhcnRzV2l0aCgnIycpKSB7XG5cdFx0XHRcdGJyZWFrO1xuXHRcdFx0fVxuXHRcdFx0aWYgKG5vZGUuaHJlZi5zdGFydHNXaXRoKCdmaWxlOi8vJykgfHwgbm9kZS5ocmVmLnN0YXJ0c1dpdGgoJ3ZzY29kZS1yZXNvdXJjZTonKSkge1xuXHRcdFx0XHRjb25zdCBbcGF0aCwgZnJhZ21lbnRdID0gbm9kZS5ocmVmLnJlcGxhY2UoL14oZmlsZTpcXC9cXC98dnNjb2RlLXJlc291cmNlOikvaSwgJycpLnNwbGl0KCcjJyk7XG5cdFx0XHRcdG1lc3NhZ2luZy5wb3N0TWVzc2FnZSgnY2xpY2tMaW5rJywgeyBwYXRoLCBmcmFnbWVudCB9KTtcblx0XHRcdFx0ZXZlbnQucHJldmVudERlZmF1bHQoKTtcblx0XHRcdFx0ZXZlbnQuc3RvcFByb3BhZ2F0aW9uKCk7XG5cdFx0XHRcdGJyZWFrO1xuXHRcdFx0fVxuXHRcdFx0YnJlYWs7XG5cdFx0fVxuXHRcdG5vZGUgPSBub2RlLnBhcmVudE5vZGU7XG5cdH1cbn0sIHRydWUpO1xuXG5pZiAoc2V0dGluZ3Muc2Nyb2xsRWRpdG9yV2l0aFByZXZpZXcpIHtcblx0d2luZG93LmFkZEV2ZW50TGlzdGVuZXIoJ3Njcm9sbCcsIHRocm90dGxlKCgpID0+IHtcblx0XHRpZiAoc2Nyb2xsRGlzYWJsZWQpIHtcblx0XHRcdHNjcm9sbERpc2FibGVkID0gZmFsc2U7XG5cdFx0fSBlbHNlIHtcblx0XHRcdGNvbnN0IGxpbmUgPSBnZXRFZGl0b3JMaW5lTnVtYmVyRm9yUGFnZU9mZnNldCh3aW5kb3cuc2Nyb2xsWSk7XG5cdFx0XHRpZiAodHlwZW9mIGxpbmUgPT09ICdudW1iZXInICYmICFpc05hTihsaW5lKSkge1xuXHRcdFx0XHRtZXNzYWdpbmcucG9zdE1lc3NhZ2UoJ3JldmVhbExpbmUnLCB7IGxpbmUgfSk7XG5cdFx0XHR9XG5cdFx0fVxuXHR9LCA1MCkpO1xufSIsIi8qLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tXG4gKiAgQ29weXJpZ2h0IChjKSBNaWNyb3NvZnQgQ29ycG9yYXRpb24uIEFsbCByaWdodHMgcmVzZXJ2ZWQuXG4gKiAgTGljZW5zZWQgdW5kZXIgdGhlIE1JVCBMaWNlbnNlLiBTZWUgTGljZW5zZS50eHQgaW4gdGhlIHByb2plY3Qgcm9vdCBmb3IgbGljZW5zZSBpbmZvcm1hdGlvbi5cbiAqLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0qL1xuXG5pbXBvcnQgeyBnZXRTZXR0aW5ncyB9IGZyb20gJy4vc2V0dGluZ3MnO1xuXG5leHBvcnQgaW50ZXJmYWNlIE1lc3NhZ2VQb3N0ZXIge1xuXHQvKipcblx0ICogUG9zdCBhIG1lc3NhZ2UgdG8gdGhlIG1hcmtkb3duIGV4dGVuc2lvblxuXHQgKi9cblx0cG9zdE1lc3NhZ2UodHlwZTogc3RyaW5nLCBib2R5OiBvYmplY3QpOiB2b2lkO1xufVxuXG5leHBvcnQgY29uc3QgY3JlYXRlUG9zdGVyRm9yVnNDb2RlID0gKHZzY29kZTogYW55KSA9PiB7XG5cdHJldHVybiBuZXcgY2xhc3MgaW1wbGVtZW50cyBNZXNzYWdlUG9zdGVyIHtcblx0XHRwb3N0TWVzc2FnZSh0eXBlOiBzdHJpbmcsIGJvZHk6IG9iamVjdCk6IHZvaWQge1xuXHRcdFx0dnNjb2RlLnBvc3RNZXNzYWdlKHtcblx0XHRcdFx0dHlwZSxcblx0XHRcdFx0c291cmNlOiBnZXRTZXR0aW5ncygpLnNvdXJjZSxcblx0XHRcdFx0Ym9keVxuXHRcdFx0fSk7XG5cdFx0fVxuXHR9O1xufTtcblxuIiwiLyotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS1cbiAqICBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4gQWxsIHJpZ2h0cyByZXNlcnZlZC5cbiAqICBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuIFNlZSBMaWNlbnNlLnR4dCBpbiB0aGUgcHJvamVjdCByb290IGZvciBsaWNlbnNlIGluZm9ybWF0aW9uLlxuICotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSovXG5cbmltcG9ydCB7IGdldFNldHRpbmdzIH0gZnJvbSAnLi9zZXR0aW5ncyc7XG5cblxuZnVuY3Rpb24gY2xhbXAobWluOiBudW1iZXIsIG1heDogbnVtYmVyLCB2YWx1ZTogbnVtYmVyKSB7XG5cdHJldHVybiBNYXRoLm1pbihtYXgsIE1hdGgubWF4KG1pbiwgdmFsdWUpKTtcbn1cblxuZnVuY3Rpb24gY2xhbXBMaW5lKGxpbmU6IG51bWJlcikge1xuXHRyZXR1cm4gY2xhbXAoMCwgZ2V0U2V0dGluZ3MoKS5saW5lQ291bnQgLSAxLCBsaW5lKTtcbn1cblxuXG5leHBvcnQgaW50ZXJmYWNlIENvZGVMaW5lRWxlbWVudCB7XG5cdGVsZW1lbnQ6IEhUTUxFbGVtZW50O1xuXHRsaW5lOiBudW1iZXI7XG59XG5cbmNvbnN0IGdldENvZGVMaW5lRWxlbWVudHMgPSAoKCkgPT4ge1xuXHRsZXQgZWxlbWVudHM6IENvZGVMaW5lRWxlbWVudFtdO1xuXHRyZXR1cm4gKCkgPT4ge1xuXHRcdGlmICghZWxlbWVudHMpIHtcblx0XHRcdGVsZW1lbnRzID0gKFt7IGVsZW1lbnQ6IGRvY3VtZW50LmJvZHksIGxpbmU6IDAgfV0pLmNvbmNhdChBcnJheS5wcm90b3R5cGUubWFwLmNhbGwoXG5cdFx0XHRcdGRvY3VtZW50LmdldEVsZW1lbnRzQnlDbGFzc05hbWUoJ2NvZGUtbGluZScpLFxuXHRcdFx0XHQoZWxlbWVudDogYW55KSA9PiB7XG5cdFx0XHRcdFx0Y29uc3QgbGluZSA9ICtlbGVtZW50LmdldEF0dHJpYnV0ZSgnZGF0YS1saW5lJyk7XG5cdFx0XHRcdFx0cmV0dXJuIHsgZWxlbWVudCwgbGluZSB9O1xuXHRcdFx0XHR9KVxuXHRcdFx0XHQuZmlsdGVyKCh4OiBhbnkpID0+ICFpc05hTih4LmxpbmUpKSk7XG5cdFx0fVxuXHRcdHJldHVybiBlbGVtZW50cztcblx0fTtcbn0pKCk7XG5cbi8qKlxuICogRmluZCB0aGUgaHRtbCBlbGVtZW50cyB0aGF0IG1hcCB0byBhIHNwZWNpZmljIHRhcmdldCBsaW5lIGluIHRoZSBlZGl0b3IuXG4gKlxuICogSWYgYW4gZXhhY3QgbWF0Y2gsIHJldHVybnMgYSBzaW5nbGUgZWxlbWVudC4gSWYgdGhlIGxpbmUgaXMgYmV0d2VlbiBlbGVtZW50cyxcbiAqIHJldHVybnMgdGhlIGVsZW1lbnQgcHJpb3IgdG8gYW5kIHRoZSBlbGVtZW50IGFmdGVyIHRoZSBnaXZlbiBsaW5lLlxuICovXG5leHBvcnQgZnVuY3Rpb24gZ2V0RWxlbWVudHNGb3JTb3VyY2VMaW5lKHRhcmdldExpbmU6IG51bWJlcik6IHsgcHJldmlvdXM6IENvZGVMaW5lRWxlbWVudDsgbmV4dD86IENvZGVMaW5lRWxlbWVudDsgfSB7XG5cdGNvbnN0IGxpbmVOdW1iZXIgPSBNYXRoLmZsb29yKHRhcmdldExpbmUpO1xuXHRjb25zdCBsaW5lcyA9IGdldENvZGVMaW5lRWxlbWVudHMoKTtcblx0bGV0IHByZXZpb3VzID0gbGluZXNbMF0gfHwgbnVsbDtcblx0Zm9yIChjb25zdCBlbnRyeSBvZiBsaW5lcykge1xuXHRcdGlmIChlbnRyeS5saW5lID09PSBsaW5lTnVtYmVyKSB7XG5cdFx0XHRyZXR1cm4geyBwcmV2aW91czogZW50cnksIG5leHQ6IHVuZGVmaW5lZCB9O1xuXHRcdH0gZWxzZSBpZiAoZW50cnkubGluZSA+IGxpbmVOdW1iZXIpIHtcblx0XHRcdHJldHVybiB7IHByZXZpb3VzLCBuZXh0OiBlbnRyeSB9O1xuXHRcdH1cblx0XHRwcmV2aW91cyA9IGVudHJ5O1xuXHR9XG5cdHJldHVybiB7IHByZXZpb3VzIH07XG59XG5cbi8qKlxuICogRmluZCB0aGUgaHRtbCBlbGVtZW50cyB0aGF0IGFyZSBhdCBhIHNwZWNpZmljIHBpeGVsIG9mZnNldCBvbiB0aGUgcGFnZS5cbiAqL1xuZXhwb3J0IGZ1bmN0aW9uIGdldExpbmVFbGVtZW50c0F0UGFnZU9mZnNldChvZmZzZXQ6IG51bWJlcik6IHsgcHJldmlvdXM6IENvZGVMaW5lRWxlbWVudDsgbmV4dD86IENvZGVMaW5lRWxlbWVudDsgfSB7XG5cdGNvbnN0IGxpbmVzID0gZ2V0Q29kZUxpbmVFbGVtZW50cygpO1xuXHRjb25zdCBwb3NpdGlvbiA9IG9mZnNldCAtIHdpbmRvdy5zY3JvbGxZO1xuXHRsZXQgbG8gPSAtMTtcblx0bGV0IGhpID0gbGluZXMubGVuZ3RoIC0gMTtcblx0d2hpbGUgKGxvICsgMSA8IGhpKSB7XG5cdFx0Y29uc3QgbWlkID0gTWF0aC5mbG9vcigobG8gKyBoaSkgLyAyKTtcblx0XHRjb25zdCBib3VuZHMgPSBsaW5lc1ttaWRdLmVsZW1lbnQuZ2V0Qm91bmRpbmdDbGllbnRSZWN0KCk7XG5cdFx0aWYgKGJvdW5kcy50b3AgKyBib3VuZHMuaGVpZ2h0ID49IHBvc2l0aW9uKSB7XG5cdFx0XHRoaSA9IG1pZDtcblx0XHR9XG5cdFx0ZWxzZSB7XG5cdFx0XHRsbyA9IG1pZDtcblx0XHR9XG5cdH1cblx0Y29uc3QgaGlFbGVtZW50ID0gbGluZXNbaGldO1xuXHRjb25zdCBoaUJvdW5kcyA9IGhpRWxlbWVudC5lbGVtZW50LmdldEJvdW5kaW5nQ2xpZW50UmVjdCgpO1xuXHRpZiAoaGkgPj0gMSAmJiBoaUJvdW5kcy50b3AgPiBwb3NpdGlvbikge1xuXHRcdGNvbnN0IGxvRWxlbWVudCA9IGxpbmVzW2xvXTtcblx0XHRyZXR1cm4geyBwcmV2aW91czogbG9FbGVtZW50LCBuZXh0OiBoaUVsZW1lbnQgfTtcblx0fVxuXHRyZXR1cm4geyBwcmV2aW91czogaGlFbGVtZW50IH07XG59XG5cbi8qKlxuICogQXR0ZW1wdCB0byByZXZlYWwgdGhlIGVsZW1lbnQgZm9yIGEgc291cmNlIGxpbmUgaW4gdGhlIGVkaXRvci5cbiAqL1xuZXhwb3J0IGZ1bmN0aW9uIHNjcm9sbFRvUmV2ZWFsU291cmNlTGluZShsaW5lOiBudW1iZXIpIHtcblx0aWYgKCFnZXRTZXR0aW5ncygpLnNjcm9sbFByZXZpZXdXaXRoRWRpdG9yKSB7XG5cdFx0cmV0dXJuO1xuXHR9XG5cblx0aWYgKGxpbmUgPD0gMCkge1xuXHRcdHdpbmRvdy5zY3JvbGwod2luZG93LnNjcm9sbFgsIDApO1xuXHRcdHJldHVybjtcblx0fVxuXG5cdGNvbnN0IHsgcHJldmlvdXMsIG5leHQgfSA9IGdldEVsZW1lbnRzRm9yU291cmNlTGluZShsaW5lKTtcblx0aWYgKCFwcmV2aW91cykge1xuXHRcdHJldHVybjtcblx0fVxuXHRsZXQgc2Nyb2xsVG8gPSAwO1xuXHRjb25zdCByZWN0ID0gcHJldmlvdXMuZWxlbWVudC5nZXRCb3VuZGluZ0NsaWVudFJlY3QoKTtcblx0Y29uc3QgcHJldmlvdXNUb3AgPSByZWN0LnRvcDtcblx0aWYgKG5leHQgJiYgbmV4dC5saW5lICE9PSBwcmV2aW91cy5saW5lKSB7XG5cdFx0Ly8gQmV0d2VlbiB0d28gZWxlbWVudHMuIEdvIHRvIHBlcmNlbnRhZ2Ugb2Zmc2V0IGJldHdlZW4gdGhlbS5cblx0XHRjb25zdCBiZXR3ZWVuUHJvZ3Jlc3MgPSAobGluZSAtIHByZXZpb3VzLmxpbmUpIC8gKG5leHQubGluZSAtIHByZXZpb3VzLmxpbmUpO1xuXHRcdGNvbnN0IGVsZW1lbnRPZmZzZXQgPSBuZXh0LmVsZW1lbnQuZ2V0Qm91bmRpbmdDbGllbnRSZWN0KCkudG9wIC0gcHJldmlvdXNUb3A7XG5cdFx0c2Nyb2xsVG8gPSBwcmV2aW91c1RvcCArIGJldHdlZW5Qcm9ncmVzcyAqIGVsZW1lbnRPZmZzZXQ7XG5cdH0gZWxzZSB7XG5cdFx0c2Nyb2xsVG8gPSBwcmV2aW91c1RvcDtcblx0fVxuXHR3aW5kb3cuc2Nyb2xsKHdpbmRvdy5zY3JvbGxYLCBNYXRoLm1heCgxLCB3aW5kb3cuc2Nyb2xsWSArIHNjcm9sbFRvKSk7XG59XG5cbmV4cG9ydCBmdW5jdGlvbiBnZXRFZGl0b3JMaW5lTnVtYmVyRm9yUGFnZU9mZnNldChvZmZzZXQ6IG51bWJlcikge1xuXHRjb25zdCB7IHByZXZpb3VzLCBuZXh0IH0gPSBnZXRMaW5lRWxlbWVudHNBdFBhZ2VPZmZzZXQob2Zmc2V0KTtcblx0aWYgKHByZXZpb3VzKSB7XG5cdFx0Y29uc3QgcHJldmlvdXNCb3VuZHMgPSBwcmV2aW91cy5lbGVtZW50LmdldEJvdW5kaW5nQ2xpZW50UmVjdCgpO1xuXHRcdGNvbnN0IG9mZnNldEZyb21QcmV2aW91cyA9IChvZmZzZXQgLSB3aW5kb3cuc2Nyb2xsWSAtIHByZXZpb3VzQm91bmRzLnRvcCk7XG5cdFx0aWYgKG5leHQpIHtcblx0XHRcdGNvbnN0IHByb2dyZXNzQmV0d2VlbkVsZW1lbnRzID0gb2Zmc2V0RnJvbVByZXZpb3VzIC8gKG5leHQuZWxlbWVudC5nZXRCb3VuZGluZ0NsaWVudFJlY3QoKS50b3AgLSBwcmV2aW91c0JvdW5kcy50b3ApO1xuXHRcdFx0Y29uc3QgbGluZSA9IHByZXZpb3VzLmxpbmUgKyBwcm9ncmVzc0JldHdlZW5FbGVtZW50cyAqIChuZXh0LmxpbmUgLSBwcmV2aW91cy5saW5lKTtcblx0XHRcdHJldHVybiBjbGFtcExpbmUobGluZSk7XG5cdFx0fVxuXHRcdGVsc2Uge1xuXHRcdFx0Y29uc3QgcHJvZ3Jlc3NXaXRoaW5FbGVtZW50ID0gb2Zmc2V0RnJvbVByZXZpb3VzIC8gKHByZXZpb3VzQm91bmRzLmhlaWdodCk7XG5cdFx0XHRjb25zdCBsaW5lID0gcHJldmlvdXMubGluZSArIHByb2dyZXNzV2l0aGluRWxlbWVudDtcblx0XHRcdHJldHVybiBjbGFtcExpbmUobGluZSk7XG5cdFx0fVxuXHR9XG5cdHJldHVybiBudWxsO1xufVxuIiwiLyotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS1cbiAqICBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4gQWxsIHJpZ2h0cyByZXNlcnZlZC5cbiAqICBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuIFNlZSBMaWNlbnNlLnR4dCBpbiB0aGUgcHJvamVjdCByb290IGZvciBsaWNlbnNlIGluZm9ybWF0aW9uLlxuICotLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSovXG5cbmV4cG9ydCBpbnRlcmZhY2UgUHJldmlld1NldHRpbmdzIHtcblx0c291cmNlOiBzdHJpbmc7XG5cdGxpbmU6IG51bWJlcjtcblx0bGluZUNvdW50OiBudW1iZXI7XG5cdHNjcm9sbFByZXZpZXdXaXRoRWRpdG9yPzogYm9vbGVhbjtcblx0c2Nyb2xsRWRpdG9yV2l0aFByZXZpZXc6IGJvb2xlYW47XG5cdGRpc2FibGVTZWN1cml0eVdhcm5pbmdzOiBib29sZWFuO1xuXHRkb3VibGVDbGlja1RvU3dpdGNoVG9FZGl0b3I6IGJvb2xlYW47XG59XG5cbmxldCBjYWNoZWRTZXR0aW5nczogUHJldmlld1NldHRpbmdzIHwgdW5kZWZpbmVkID0gdW5kZWZpbmVkO1xuXG5leHBvcnQgZnVuY3Rpb24gZ2V0RGF0YShrZXk6IHN0cmluZyk6IFByZXZpZXdTZXR0aW5ncyB7XG5cdGNvbnN0IGVsZW1lbnQgPSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgndnNjb2RlLW1hcmtkb3duLXByZXZpZXctZGF0YScpO1xuXHRpZiAoZWxlbWVudCkge1xuXHRcdGNvbnN0IGRhdGEgPSBlbGVtZW50LmdldEF0dHJpYnV0ZShrZXkpO1xuXHRcdGlmIChkYXRhKSB7XG5cdFx0XHRyZXR1cm4gSlNPTi5wYXJzZShkYXRhKTtcblx0XHR9XG5cdH1cblxuXHR0aHJvdyBuZXcgRXJyb3IoYENvdWxkIG5vdCBsb2FkIGRhdGEgZm9yICR7a2V5fWApO1xufVxuXG5leHBvcnQgZnVuY3Rpb24gZ2V0U2V0dGluZ3MoKTogUHJldmlld1NldHRpbmdzIHtcblx0aWYgKGNhY2hlZFNldHRpbmdzKSB7XG5cdFx0cmV0dXJuIGNhY2hlZFNldHRpbmdzO1xuXHR9XG5cblx0Y2FjaGVkU2V0dGluZ3MgPSBnZXREYXRhKCdkYXRhLXNldHRpbmdzJyk7XG5cdGlmIChjYWNoZWRTZXR0aW5ncykge1xuXHRcdHJldHVybiBjYWNoZWRTZXR0aW5ncztcblx0fVxuXG5cdHRocm93IG5ldyBFcnJvcignQ291bGQgbm90IGxvYWQgc2V0dGluZ3MnKTtcbn1cbiJdLCJzb3VyY2VSb290IjoiIn0=