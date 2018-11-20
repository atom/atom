/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as browser from 'vs/base/browser/browser';
import { domEvent } from 'vs/base/browser/event';
import { IKeyboardEvent, StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { IMouseEvent, StandardMouseEvent } from 'vs/base/browser/mouseEvent';
import { TimeoutTimer } from 'vs/base/common/async';
import { CharCode } from 'vs/base/common/charCode';
import { onUnexpectedError } from 'vs/base/common/errors';
import { Emitter, Event } from 'vs/base/common/event';
import { Disposable, IDisposable, dispose } from 'vs/base/common/lifecycle';
import * as platform from 'vs/base/common/platform';

export function clearNode(node: HTMLElement): void {
	while (node.firstChild) {
		node.removeChild(node.firstChild);
	}
}

export function removeNode(node: HTMLElement): void {
	if (node.parentNode) {
		node.parentNode.removeChild(node);
	}
}

export function isInDOM(node: Node | null): boolean {
	while (node) {
		if (node === document.body) {
			return true;
		}
		node = node.parentNode;
	}
	return false;
}

interface IDomClassList {
	hasClass(node: HTMLElement, className: string): boolean;
	addClass(node: HTMLElement, className: string): void;
	addClasses(node: HTMLElement, ...classNames: string[]): void;
	removeClass(node: HTMLElement, className: string): void;
	removeClasses(node: HTMLElement, ...classNames: string[]): void;
	toggleClass(node: HTMLElement, className: string, shouldHaveIt?: boolean): void;
}

const _manualClassList = new class implements IDomClassList {

	private _lastStart: number;
	private _lastEnd: number;

	private _findClassName(node: HTMLElement, className: string): void {

		let classes = node.className;
		if (!classes) {
			this._lastStart = -1;
			return;
		}

		className = className.trim();

		let classesLen = classes.length,
			classLen = className.length;

		if (classLen === 0) {
			this._lastStart = -1;
			return;
		}

		if (classesLen < classLen) {
			this._lastStart = -1;
			return;
		}

		if (classes === className) {
			this._lastStart = 0;
			this._lastEnd = classesLen;
			return;
		}

		let idx = -1,
			idxEnd: number;

		while ((idx = classes.indexOf(className, idx + 1)) >= 0) {

			idxEnd = idx + classLen;

			// a class that is followed by another class
			if ((idx === 0 || classes.charCodeAt(idx - 1) === CharCode.Space) && classes.charCodeAt(idxEnd) === CharCode.Space) {
				this._lastStart = idx;
				this._lastEnd = idxEnd + 1;
				return;
			}

			// last class
			if (idx > 0 && classes.charCodeAt(idx - 1) === CharCode.Space && idxEnd === classesLen) {
				this._lastStart = idx - 1;
				this._lastEnd = idxEnd;
				return;
			}

			// equal - duplicate of cmp above
			if (idx === 0 && idxEnd === classesLen) {
				this._lastStart = 0;
				this._lastEnd = idxEnd;
				return;
			}
		}

		this._lastStart = -1;
	}

	hasClass(node: HTMLElement, className: string): boolean {
		this._findClassName(node, className);
		return this._lastStart !== -1;
	}

	addClasses(node: HTMLElement, ...classNames: string[]): void {
		classNames.forEach(nameValue => nameValue.split(' ').forEach(name => this.addClass(node, name)));
	}

	addClass(node: HTMLElement, className: string): void {
		if (!node.className) { // doesn't have it for sure
			node.className = className;
		} else {
			this._findClassName(node, className); // see if it's already there
			if (this._lastStart === -1) {
				node.className = node.className + ' ' + className;
			}
		}
	}

	removeClass(node: HTMLElement, className: string): void {
		this._findClassName(node, className);
		if (this._lastStart === -1) {
			return; // Prevent styles invalidation if not necessary
		} else {
			node.className = node.className.substring(0, this._lastStart) + node.className.substring(this._lastEnd);
		}
	}

	removeClasses(node: HTMLElement, ...classNames: string[]): void {
		classNames.forEach(nameValue => nameValue.split(' ').forEach(name => this.removeClass(node, name)));
	}

	toggleClass(node: HTMLElement, className: string, shouldHaveIt?: boolean): void {
		this._findClassName(node, className);
		if (this._lastStart !== -1 && (shouldHaveIt === void 0 || !shouldHaveIt)) {
			this.removeClass(node, className);
		}
		if (this._lastStart === -1 && (shouldHaveIt === void 0 || shouldHaveIt)) {
			this.addClass(node, className);
		}
	}
};

const _nativeClassList = new class implements IDomClassList {
	hasClass(node: HTMLElement, className: string): boolean {
		return Boolean(className) && node.classList && node.classList.contains(className);
	}

	addClasses(node: HTMLElement, ...classNames: string[]): void {
		classNames.forEach(nameValue => nameValue.split(' ').forEach(name => this.addClass(node, name)));
	}

	addClass(node: HTMLElement, className: string): void {
		if (className && node.classList) {
			node.classList.add(className);
		}
	}

	removeClass(node: HTMLElement, className: string): void {
		if (className && node.classList) {
			node.classList.remove(className);
		}
	}

	removeClasses(node: HTMLElement, ...classNames: string[]): void {
		classNames.forEach(nameValue => nameValue.split(' ').forEach(name => this.removeClass(node, name)));
	}

	toggleClass(node: HTMLElement, className: string, shouldHaveIt?: boolean): void {
		if (node.classList) {
			node.classList.toggle(className, shouldHaveIt);
		}
	}
};

// In IE11 there is only partial support for `classList` which makes us keep our
// custom implementation. Otherwise use the native implementation, see: http://caniuse.com/#search=classlist
const _classList: IDomClassList = browser.isIE ? _manualClassList : _nativeClassList;
export const hasClass: (node: HTMLElement, className: string) => boolean = _classList.hasClass.bind(_classList);
export const addClass: (node: HTMLElement, className: string) => void = _classList.addClass.bind(_classList);
export const addClasses: (node: HTMLElement, ...classNames: string[]) => void = _classList.addClasses.bind(_classList);
export const removeClass: (node: HTMLElement, className: string) => void = _classList.removeClass.bind(_classList);
export const removeClasses: (node: HTMLElement, ...classNames: string[]) => void = _classList.removeClasses.bind(_classList);
export const toggleClass: (node: HTMLElement, className: string, shouldHaveIt?: boolean) => void = _classList.toggleClass.bind(_classList);

class DomListener implements IDisposable {

	private _handler: (e: any) => void;
	private _node: Element | Window | Document;
	private readonly _type: string;
	private readonly _useCapture: boolean;

	constructor(node: Element | Window | Document, type: string, handler: (e: any) => void, useCapture?: boolean) {
		this._node = node;
		this._type = type;
		this._handler = handler;
		this._useCapture = (useCapture || false);
		this._node.addEventListener(this._type, this._handler, this._useCapture);
	}

	public dispose(): void {
		if (!this._handler) {
			// Already disposed
			return;
		}

		this._node.removeEventListener(this._type, this._handler, this._useCapture);

		// Prevent leakers from holding on to the dom or handler func
		this._node = null!;
		this._handler = null!;
	}
}

export function addDisposableListener(node: Element | Window | Document, type: string, handler: (event: any) => void, useCapture?: boolean): IDisposable {
	return new DomListener(node, type, handler, useCapture);
}

export interface IAddStandardDisposableListenerSignature {
	(node: HTMLElement, type: 'click', handler: (event: IMouseEvent) => void, useCapture?: boolean): IDisposable;
	(node: HTMLElement, type: 'mousedown', handler: (event: IMouseEvent) => void, useCapture?: boolean): IDisposable;
	(node: HTMLElement, type: 'keydown', handler: (event: IKeyboardEvent) => void, useCapture?: boolean): IDisposable;
	(node: HTMLElement, type: 'keypress', handler: (event: IKeyboardEvent) => void, useCapture?: boolean): IDisposable;
	(node: HTMLElement, type: 'keyup', handler: (event: IKeyboardEvent) => void, useCapture?: boolean): IDisposable;
	(node: HTMLElement, type: string, handler: (event: any) => void, useCapture?: boolean): IDisposable;
}
function _wrapAsStandardMouseEvent(handler: (e: IMouseEvent) => void): (e: MouseEvent) => void {
	return function (e: MouseEvent) {
		return handler(new StandardMouseEvent(e));
	};
}
function _wrapAsStandardKeyboardEvent(handler: (e: IKeyboardEvent) => void): (e: KeyboardEvent) => void {
	return function (e: KeyboardEvent) {
		return handler(new StandardKeyboardEvent(e));
	};
}
export let addStandardDisposableListener: IAddStandardDisposableListenerSignature = function addStandardDisposableListener(node: HTMLElement, type: string, handler: (event: any) => void, useCapture?: boolean): IDisposable {
	let wrapHandler = handler;

	if (type === 'click' || type === 'mousedown') {
		wrapHandler = _wrapAsStandardMouseEvent(handler);
	} else if (type === 'keydown' || type === 'keypress' || type === 'keyup') {
		wrapHandler = _wrapAsStandardKeyboardEvent(handler);
	}

	return addDisposableListener(node, type, wrapHandler, useCapture);
};

export function addDisposableNonBubblingMouseOutListener(node: Element, handler: (event: MouseEvent) => void): IDisposable {
	return addDisposableListener(node, 'mouseout', (e: MouseEvent) => {
		// Mouse out bubbles, so this is an attempt to ignore faux mouse outs coming from children elements
		let toElement: Node | null = <Node>(e.relatedTarget || e.toElement);
		while (toElement && toElement !== node) {
			toElement = toElement.parentNode;
		}
		if (toElement === node) {
			return;
		}

		handler(e);
	});
}

interface IRequestAnimationFrame {
	(callback: (time: number) => void): number;
}
let _animationFrame: IRequestAnimationFrame | null = null;
function doRequestAnimationFrame(callback: (time: number) => void): number {
	if (!_animationFrame) {
		const emulatedRequestAnimationFrame = (callback: (time: number) => void): any => {
			return setTimeout(() => callback(new Date().getTime()), 0);
		};
		_animationFrame = (
			self.requestAnimationFrame
			|| (<any>self).msRequestAnimationFrame
			|| (<any>self).webkitRequestAnimationFrame
			|| (<any>self).mozRequestAnimationFrame
			|| (<any>self).oRequestAnimationFrame
			|| emulatedRequestAnimationFrame
		);
	}
	return _animationFrame.call(self, callback);
}

/**
 * Schedule a callback to be run at the next animation frame.
 * This allows multiple parties to register callbacks that should run at the next animation frame.
 * If currently in an animation frame, `runner` will be executed immediately.
 * @return token that can be used to cancel the scheduled runner (only if `runner` was not executed immediately).
 */
export let runAtThisOrScheduleAtNextAnimationFrame: (runner: () => void, priority?: number) => IDisposable;
/**
 * Schedule a callback to be run at the next animation frame.
 * This allows multiple parties to register callbacks that should run at the next animation frame.
 * If currently in an animation frame, `runner` will be executed at the next animation frame.
 * @return token that can be used to cancel the scheduled runner.
 */
export let scheduleAtNextAnimationFrame: (runner: () => void, priority?: number) => IDisposable;

class AnimationFrameQueueItem implements IDisposable {

	private _runner: () => void;
	public priority: number;
	private _canceled: boolean;

	constructor(runner: () => void, priority: number = 0) {
		this._runner = runner;
		this.priority = priority;
		this._canceled = false;
	}

	public dispose(): void {
		this._canceled = true;
	}

	public execute(): void {
		if (this._canceled) {
			return;
		}

		try {
			this._runner();
		} catch (e) {
			onUnexpectedError(e);
		}
	}

	// Sort by priority (largest to lowest)
	public static sort(a: AnimationFrameQueueItem, b: AnimationFrameQueueItem): number {
		return b.priority - a.priority;
	}
}

(function () {
	/**
	 * The runners scheduled at the next animation frame
	 */
	let NEXT_QUEUE: AnimationFrameQueueItem[] = [];
	/**
	 * The runners scheduled at the current animation frame
	 */
	let CURRENT_QUEUE: AnimationFrameQueueItem[] | null = null;
	/**
	 * A flag to keep track if the native requestAnimationFrame was already called
	 */
	let animFrameRequested = false;
	/**
	 * A flag to indicate if currently handling a native requestAnimationFrame callback
	 */
	let inAnimationFrameRunner = false;

	let animationFrameRunner = () => {
		animFrameRequested = false;

		CURRENT_QUEUE = NEXT_QUEUE;
		NEXT_QUEUE = [];

		inAnimationFrameRunner = true;
		while (CURRENT_QUEUE.length > 0) {
			CURRENT_QUEUE.sort(AnimationFrameQueueItem.sort);
			let top = CURRENT_QUEUE.shift()!;
			top.execute();
		}
		inAnimationFrameRunner = false;
	};

	scheduleAtNextAnimationFrame = (runner: () => void, priority: number = 0) => {
		let item = new AnimationFrameQueueItem(runner, priority);
		NEXT_QUEUE.push(item);

		if (!animFrameRequested) {
			animFrameRequested = true;
			doRequestAnimationFrame(animationFrameRunner);
		}

		return item;
	};

	runAtThisOrScheduleAtNextAnimationFrame = (runner: () => void, priority?: number) => {
		if (inAnimationFrameRunner) {
			let item = new AnimationFrameQueueItem(runner, priority);
			CURRENT_QUEUE!.push(item);
			return item;
		} else {
			return scheduleAtNextAnimationFrame(runner, priority);
		}
	};
})();

export function measure(callback: () => void): IDisposable {
	return scheduleAtNextAnimationFrame(callback, 10000 /* must be early */);
}

export function modify(callback: () => void): IDisposable {
	return scheduleAtNextAnimationFrame(callback, -10000 /* must be late */);
}

/**
 * Add a throttled listener. `handler` is fired at most every 16ms or with the next animation frame (if browser supports it).
 */
export interface IEventMerger<R, E> {
	(lastEvent: R | null, currentEvent: E): R;
}

export interface DOMEvent {
	preventDefault(): void;
	stopPropagation(): void;
}

const MINIMUM_TIME_MS = 16;
const DEFAULT_EVENT_MERGER: IEventMerger<DOMEvent, DOMEvent> = function (lastEvent: DOMEvent, currentEvent: DOMEvent) {
	return currentEvent;
};

class TimeoutThrottledDomListener<R, E extends DOMEvent> extends Disposable {

	constructor(node: any, type: string, handler: (event: R) => void, eventMerger: IEventMerger<R, E> = <any>DEFAULT_EVENT_MERGER, minimumTimeMs: number = MINIMUM_TIME_MS) {
		super();

		let lastEvent: R | null = null;
		let lastHandlerTime = 0;
		let timeout = this._register(new TimeoutTimer());

		let invokeHandler = () => {
			lastHandlerTime = (new Date()).getTime();
			handler(<R>lastEvent);
			lastEvent = null;
		};

		this._register(addDisposableListener(node, type, (e) => {

			lastEvent = eventMerger(lastEvent, e);
			let elapsedTime = (new Date()).getTime() - lastHandlerTime;

			if (elapsedTime >= minimumTimeMs) {
				timeout.cancel();
				invokeHandler();
			} else {
				timeout.setIfNotSet(invokeHandler, minimumTimeMs - elapsedTime);
			}
		}));
	}
}

export function addDisposableThrottledListener<R, E extends DOMEvent = DOMEvent>(node: any, type: string, handler: (event: R) => void, eventMerger?: IEventMerger<R, E>, minimumTimeMs?: number): IDisposable {
	return new TimeoutThrottledDomListener<R, E>(node, type, handler, eventMerger, minimumTimeMs);
}

export function getComputedStyle(el: HTMLElement): CSSStyleDeclaration {
	return document.defaultView!.getComputedStyle(el, null);
}

// Adapted from WinJS
// Converts a CSS positioning string for the specified element to pixels.
const convertToPixels: (element: HTMLElement, value: string) => number = (function () {
	return function (element: HTMLElement, value: string): number {
		return parseFloat(value) || 0;
	};
})();

function getDimension(element: HTMLElement, cssPropertyName: string, jsPropertyName: string): number {
	let computedStyle: CSSStyleDeclaration = getComputedStyle(element);
	let value = '0';
	if (computedStyle) {
		if (computedStyle.getPropertyValue) {
			value = computedStyle.getPropertyValue(cssPropertyName);
		} else {
			// IE8
			value = (<any>computedStyle).getAttribute(jsPropertyName);
		}
	}
	return convertToPixels(element, value);
}

export function getClientArea(element: HTMLElement): Dimension {

	// Try with DOM clientWidth / clientHeight
	if (element !== document.body) {
		return new Dimension(element.clientWidth, element.clientHeight);
	}

	// Try innerWidth / innerHeight
	if (window.innerWidth && window.innerHeight) {
		return new Dimension(window.innerWidth, window.innerHeight);
	}

	// Try with document.body.clientWidth / document.body.clientHeight
	if (document.body && document.body.clientWidth && document.body.clientHeight) {
		return new Dimension(document.body.clientWidth, document.body.clientHeight);
	}

	// Try with document.documentElement.clientWidth / document.documentElement.clientHeight
	if (document.documentElement && document.documentElement.clientWidth && document.documentElement.clientHeight) {
		return new Dimension(document.documentElement.clientWidth, document.documentElement.clientHeight);
	}

	throw new Error('Unable to figure out browser width and height');
}

const sizeUtils = {

	getBorderLeftWidth: function (element: HTMLElement): number {
		return getDimension(element, 'border-left-width', 'borderLeftWidth');
	},
	getBorderRightWidth: function (element: HTMLElement): number {
		return getDimension(element, 'border-right-width', 'borderRightWidth');
	},
	getBorderTopWidth: function (element: HTMLElement): number {
		return getDimension(element, 'border-top-width', 'borderTopWidth');
	},
	getBorderBottomWidth: function (element: HTMLElement): number {
		return getDimension(element, 'border-bottom-width', 'borderBottomWidth');
	},

	getPaddingLeft: function (element: HTMLElement): number {
		return getDimension(element, 'padding-left', 'paddingLeft');
	},
	getPaddingRight: function (element: HTMLElement): number {
		return getDimension(element, 'padding-right', 'paddingRight');
	},
	getPaddingTop: function (element: HTMLElement): number {
		return getDimension(element, 'padding-top', 'paddingTop');
	},
	getPaddingBottom: function (element: HTMLElement): number {
		return getDimension(element, 'padding-bottom', 'paddingBottom');
	},

	getMarginLeft: function (element: HTMLElement): number {
		return getDimension(element, 'margin-left', 'marginLeft');
	},
	getMarginTop: function (element: HTMLElement): number {
		return getDimension(element, 'margin-top', 'marginTop');
	},
	getMarginRight: function (element: HTMLElement): number {
		return getDimension(element, 'margin-right', 'marginRight');
	},
	getMarginBottom: function (element: HTMLElement): number {
		return getDimension(element, 'margin-bottom', 'marginBottom');
	},
	__commaSentinel: false
};

// ----------------------------------------------------------------------------------------
// Position & Dimension

export class Dimension {
	public width: number;
	public height: number;

	constructor(width: number, height: number) {
		this.width = width;
		this.height = height;
	}

	static equals(a: Dimension | undefined, b: Dimension | undefined): boolean {
		if (a === b) {
			return true;
		}
		if (!a || !b) {
			return false;
		}
		return a.width === b.width && a.height === b.height;
	}
}

export function getTopLeftOffset(element: HTMLElement): { left: number; top: number; } {
	// Adapted from WinJS.Utilities.getPosition
	// and added borders to the mix

	let offsetParent = element.offsetParent, top = element.offsetTop, left = element.offsetLeft;

	while ((element = <HTMLElement>element.parentNode) !== null && element !== document.body && element !== document.documentElement) {
		top -= element.scrollTop;
		let c = getComputedStyle(element);
		if (c) {
			left -= c.direction !== 'rtl' ? element.scrollLeft : -element.scrollLeft;
		}

		if (element === offsetParent) {
			left += sizeUtils.getBorderLeftWidth(element);
			top += sizeUtils.getBorderTopWidth(element);
			top += element.offsetTop;
			left += element.offsetLeft;
			offsetParent = element.offsetParent;
		}
	}

	return {
		left: left,
		top: top
	};
}

export interface IDomNodePagePosition {
	left: number;
	top: number;
	width: number;
	height: number;
}

export function size(element: HTMLElement, width: number, height: number): void {
	if (typeof width === 'number') {
		element.style.width = `${width}px`;
	}

	if (typeof height === 'number') {
		element.style.height = `${height}px`;
	}
}

export function position(element: HTMLElement, top: number, right?: number, bottom?: number, left?: number, position: string = 'absolute'): void {
	if (typeof top === 'number') {
		element.style.top = `${top}px`;
	}

	if (typeof right === 'number') {
		element.style.right = `${right}px`;
	}

	if (typeof bottom === 'number') {
		element.style.bottom = `${bottom}px`;
	}

	if (typeof left === 'number') {
		element.style.left = `${left}px`;
	}

	element.style.position = position;
}

/**
 * Returns the position of a dom node relative to the entire page.
 */
export function getDomNodePagePosition(domNode: HTMLElement): IDomNodePagePosition {
	let bb = domNode.getBoundingClientRect();
	return {
		left: bb.left + StandardWindow.scrollX,
		top: bb.top + StandardWindow.scrollY,
		width: bb.width,
		height: bb.height
	};
}

export interface IStandardWindow {
	readonly scrollX: number;
	readonly scrollY: number;
}

export const StandardWindow: IStandardWindow = new class implements IStandardWindow {
	get scrollX(): number {
		if (typeof window.scrollX === 'number') {
			// modern browsers
			return window.scrollX;
		} else {
			return document.body.scrollLeft + document.documentElement!.scrollLeft;
		}
	}

	get scrollY(): number {
		if (typeof window.scrollY === 'number') {
			// modern browsers
			return window.scrollY;
		} else {
			return document.body.scrollTop + document.documentElement!.scrollTop;
		}
	}
};

// Adapted from WinJS
// Gets the width of the element, including margins.
export function getTotalWidth(element: HTMLElement): number {
	let margin = sizeUtils.getMarginLeft(element) + sizeUtils.getMarginRight(element);
	return element.offsetWidth + margin;
}

export function getContentWidth(element: HTMLElement): number {
	let border = sizeUtils.getBorderLeftWidth(element) + sizeUtils.getBorderRightWidth(element);
	let padding = sizeUtils.getPaddingLeft(element) + sizeUtils.getPaddingRight(element);
	return element.offsetWidth - border - padding;
}

export function getTotalScrollWidth(element: HTMLElement): number {
	let margin = sizeUtils.getMarginLeft(element) + sizeUtils.getMarginRight(element);
	return element.scrollWidth + margin;
}

// Adapted from WinJS
// Gets the height of the content of the specified element. The content height does not include borders or padding.
export function getContentHeight(element: HTMLElement): number {
	let border = sizeUtils.getBorderTopWidth(element) + sizeUtils.getBorderBottomWidth(element);
	let padding = sizeUtils.getPaddingTop(element) + sizeUtils.getPaddingBottom(element);
	return element.offsetHeight - border - padding;
}

// Adapted from WinJS
// Gets the height of the element, including its margins.
export function getTotalHeight(element: HTMLElement): number {
	let margin = sizeUtils.getMarginTop(element) + sizeUtils.getMarginBottom(element);
	return element.offsetHeight + margin;
}

// Gets the left coordinate of the specified element relative to the specified parent.
function getRelativeLeft(element: HTMLElement, parent: HTMLElement): number {
	if (element === null) {
		return 0;
	}

	let elementPosition = getTopLeftOffset(element);
	let parentPosition = getTopLeftOffset(parent);
	return elementPosition.left - parentPosition.left;
}

export function getLargestChildWidth(parent: HTMLElement, children: HTMLElement[]): number {
	let childWidths = children.map((child) => {
		return Math.max(getTotalScrollWidth(child), getTotalWidth(child)) + getRelativeLeft(child, parent) || 0;
	});
	let maxWidth = Math.max(...childWidths);
	return maxWidth;
}

// ----------------------------------------------------------------------------------------

export function isAncestor(testChild: Node | null, testAncestor: Node | null): boolean {
	while (testChild) {
		if (testChild === testAncestor) {
			return true;
		}
		testChild = testChild.parentNode;
	}

	return false;
}

export function findParentWithClass(node: HTMLElement, clazz: string, stopAtClazzOrNode?: string | HTMLElement): HTMLElement | null {
	while (node) {
		if (hasClass(node, clazz)) {
			return node;
		}

		if (stopAtClazzOrNode) {
			if (typeof stopAtClazzOrNode === 'string') {
				if (hasClass(node, stopAtClazzOrNode)) {
					return null;
				}
			} else {
				if (node === stopAtClazzOrNode) {
					return null;
				}
			}
		}

		node = <HTMLElement>node.parentNode;
	}

	return null;
}

export function createStyleSheet(container: HTMLElement = document.getElementsByTagName('head')[0]): HTMLStyleElement {
	let style = document.createElement('style');
	style.type = 'text/css';
	style.media = 'screen';
	container.appendChild(style);
	return style;
}

let _sharedStyleSheet: HTMLStyleElement | null = null;
function getSharedStyleSheet(): HTMLStyleElement {
	if (!_sharedStyleSheet) {
		_sharedStyleSheet = createStyleSheet();
	}
	return _sharedStyleSheet;
}

function getDynamicStyleSheetRules(style: any) {
	if (style && style.sheet && style.sheet.rules) {
		// Chrome, IE
		return style.sheet.rules;
	}
	if (style && style.sheet && style.sheet.cssRules) {
		// FF
		return style.sheet.cssRules;
	}
	return [];
}

export function createCSSRule(selector: string, cssText: string, style: HTMLStyleElement = getSharedStyleSheet()): void {
	if (!style || !cssText) {
		return;
	}

	(<CSSStyleSheet>style.sheet).insertRule(selector + '{' + cssText + '}', 0);
}

export function removeCSSRulesContainingSelector(ruleName: string, style: HTMLStyleElement = getSharedStyleSheet()): void {
	if (!style) {
		return;
	}

	let rules = getDynamicStyleSheetRules(style);
	let toDelete: number[] = [];
	for (let i = 0; i < rules.length; i++) {
		let rule = rules[i];
		if (rule.selectorText.indexOf(ruleName) !== -1) {
			toDelete.push(i);
		}
	}

	for (let i = toDelete.length - 1; i >= 0; i--) {
		(<any>style.sheet).deleteRule(toDelete[i]);
	}
}

export function isHTMLElement(o: any): o is HTMLElement {
	if (typeof HTMLElement === 'object') {
		return o instanceof HTMLElement;
	}
	return o && typeof o === 'object' && o.nodeType === 1 && typeof o.nodeName === 'string';
}

export const EventType = {
	// Mouse
	CLICK: 'click',
	DBLCLICK: 'dblclick',
	MOUSE_UP: 'mouseup',
	MOUSE_DOWN: 'mousedown',
	MOUSE_OVER: 'mouseover',
	MOUSE_MOVE: 'mousemove',
	MOUSE_OUT: 'mouseout',
	MOUSE_ENTER: 'mouseenter',
	MOUSE_LEAVE: 'mouseleave',
	CONTEXT_MENU: 'contextmenu',
	WHEEL: 'wheel',
	// Keyboard
	KEY_DOWN: 'keydown',
	KEY_PRESS: 'keypress',
	KEY_UP: 'keyup',
	// HTML Document
	LOAD: 'load',
	UNLOAD: 'unload',
	ABORT: 'abort',
	ERROR: 'error',
	RESIZE: 'resize',
	SCROLL: 'scroll',
	// Form
	SELECT: 'select',
	CHANGE: 'change',
	SUBMIT: 'submit',
	RESET: 'reset',
	FOCUS: 'focus',
	FOCUS_IN: 'focusin',
	FOCUS_OUT: 'focusout',
	BLUR: 'blur',
	INPUT: 'input',
	// Local Storage
	STORAGE: 'storage',
	// Drag
	DRAG_START: 'dragstart',
	DRAG: 'drag',
	DRAG_ENTER: 'dragenter',
	DRAG_LEAVE: 'dragleave',
	DRAG_OVER: 'dragover',
	DROP: 'drop',
	DRAG_END: 'dragend',
	// Animation
	ANIMATION_START: browser.isWebKit ? 'webkitAnimationStart' : 'animationstart',
	ANIMATION_END: browser.isWebKit ? 'webkitAnimationEnd' : 'animationend',
	ANIMATION_ITERATION: browser.isWebKit ? 'webkitAnimationIteration' : 'animationiteration'
};

export interface EventLike {
	preventDefault(): void;
	stopPropagation(): void;
}

export const EventHelper = {
	stop: function (e: EventLike, cancelBubble?: boolean) {
		if (e.preventDefault) {
			e.preventDefault();
		} else {
			// IE8
			(<any>e).returnValue = false;
		}

		if (cancelBubble) {
			if (e.stopPropagation) {
				e.stopPropagation();
			} else {
				// IE8
				(<any>e).cancelBubble = true;
			}
		}
	}
};

export interface IFocusTracker {
	onDidFocus: Event<void>;
	onDidBlur: Event<void>;
	dispose(): void;
}

export function saveParentsScrollTop(node: Element): number[] {
	let r: number[] = [];
	for (let i = 0; node && node.nodeType === node.ELEMENT_NODE; i++) {
		r[i] = node.scrollTop;
		node = <Element>node.parentNode;
	}
	return r;
}

export function restoreParentsScrollTop(node: Element, state: number[]): void {
	for (let i = 0; node && node.nodeType === node.ELEMENT_NODE; i++) {
		if (node.scrollTop !== state[i]) {
			node.scrollTop = state[i];
		}
		node = <Element>node.parentNode;
	}
}

class FocusTracker implements IFocusTracker {

	private _onDidFocus = new Emitter<void>();
	readonly onDidFocus: Event<void> = this._onDidFocus.event;

	private _onDidBlur = new Emitter<void>();
	readonly onDidBlur: Event<void> = this._onDidBlur.event;

	private disposables: IDisposable[] = [];

	constructor(element: HTMLElement | Window) {
		let hasFocus = isAncestor(document.activeElement, <HTMLElement>element);
		let loosingFocus = false;

		let onFocus = () => {
			loosingFocus = false;
			if (!hasFocus) {
				hasFocus = true;
				this._onDidFocus.fire();
			}
		};

		let onBlur = () => {
			if (hasFocus) {
				loosingFocus = true;
				window.setTimeout(() => {
					if (loosingFocus) {
						loosingFocus = false;
						hasFocus = false;
						this._onDidBlur.fire();
					}
				}, 0);
			}
		};

		domEvent(element, EventType.FOCUS, true)(onFocus, null, this.disposables);
		domEvent(element, EventType.BLUR, true)(onBlur, null, this.disposables);
	}

	dispose(): void {
		this.disposables = dispose(this.disposables);
		this._onDidFocus.dispose();
		this._onDidBlur.dispose();
	}
}

export function trackFocus(element: HTMLElement | Window): IFocusTracker {
	return new FocusTracker(element);
}

export function append<T extends Node>(parent: HTMLElement, ...children: T[]): T {
	children.forEach(child => parent.appendChild(child));
	return children[children.length - 1];
}

export function prepend<T extends Node>(parent: HTMLElement, child: T): T {
	parent.insertBefore(child, parent.firstChild);
	return child;
}

const SELECTOR_REGEX = /([\w\-]+)?(#([\w\-]+))?((.([\w\-]+))*)/;

export function $<T extends HTMLElement>(description: string, attrs?: { [key: string]: any; }, ...children: (Node | string)[]): T {
	let match = SELECTOR_REGEX.exec(description);

	if (!match) {
		throw new Error('Bad use of emmet');
	}

	let result = document.createElement(match[1] || 'div');

	if (match[3]) {
		result.id = match[3];
	}
	if (match[4]) {
		result.className = match[4].replace(/\./g, ' ').trim();
	}

	attrs = attrs || {};
	Object.keys(attrs).forEach(name => {
		const value = attrs![name];
		if (/^on\w+$/.test(name)) {
			(<any>result)[name] = value;
		} else if (name === 'selected') {
			if (value) {
				result.setAttribute(name, 'true');
			}

		} else {
			result.setAttribute(name, value);
		}
	});

	children
		.filter(child => !!child)
		.forEach(child => {
			if (child instanceof Node) {
				result.appendChild(child);
			} else {
				result.appendChild(document.createTextNode(child as string));
			}
		});

	return result as T;
}

export function join(nodes: Node[], separator: Node | string): Node[] {
	const result: Node[] = [];

	nodes.forEach((node, index) => {
		if (index > 0) {
			if (separator instanceof Node) {
				result.push(separator.cloneNode());
			} else {
				result.push(document.createTextNode(separator));
			}
		}

		result.push(node);
	});

	return result;
}

export function show(...elements: HTMLElement[]): void {
	for (let element of elements) {
		element.style.display = '';
		element.removeAttribute('aria-hidden');
	}
}

export function hide(...elements: HTMLElement[]): void {
	for (let element of elements) {
		element.style.display = 'none';
		element.setAttribute('aria-hidden', 'true');
	}
}

function findParentWithAttribute(node: Node | null, attribute: string): HTMLElement | null {
	while (node) {
		if (node instanceof HTMLElement && node.hasAttribute(attribute)) {
			return node;
		}

		node = node.parentNode;
	}

	return null;
}

export function removeTabIndexAndUpdateFocus(node: HTMLElement): void {
	if (!node || !node.hasAttribute('tabIndex')) {
		return;
	}

	// If we are the currently focused element and tabIndex is removed,
	// standard DOM behavior is to move focus to the <body> element. We
	// typically never want that, rather put focus to the closest element
	// in the hierarchy of the parent DOM nodes.
	if (document.activeElement === node) {
		let parentFocusable = findParentWithAttribute(node.parentElement, 'tabIndex');
		if (parentFocusable) {
			parentFocusable.focus();
		}
	}

	node.removeAttribute('tabindex');
}

export function getElementsByTagName(tag: string): HTMLElement[] {
	return Array.prototype.slice.call(document.getElementsByTagName(tag), 0);
}

export function finalHandler<T extends DOMEvent>(fn: (event: T) => any): (event: T) => any {
	return e => {
		e.preventDefault();
		e.stopPropagation();
		fn(e);
	};
}

export function domContentLoaded(): Promise<any> {
	return new Promise<any>(resolve => {
		const readyState = document.readyState;
		if (readyState === 'complete' || (document && document.body !== null)) {
			platform.setImmediate(resolve);
		} else {
			window.addEventListener('DOMContentLoaded', resolve, false);
		}
	});
}

/**
 * Find a value usable for a dom node size such that the likelihood that it would be
 * displayed with constant screen pixels size is as high as possible.
 *
 * e.g. We would desire for the cursors to be 2px (CSS px) wide. Under a devicePixelRatio
 * of 1.25, the cursor will be 2.5 screen pixels wide. Depending on how the dom node aligns/"snaps"
 * with the screen pixels, it will sometimes be rendered with 2 screen pixels, and sometimes with 3 screen pixels.
 */
export function computeScreenAwareSize(cssPx: number): number {
	const screenPx = window.devicePixelRatio * cssPx;
	return Math.max(1, Math.floor(screenPx)) / window.devicePixelRatio;
}

/**
 * See https://github.com/Microsoft/monaco-editor/issues/601
 * To protect against malicious code in the linked site, particularly phishing attempts,
 * the window.opener should be set to null to prevent the linked site from having access
 * to change the location of the current page.
 * See https://mathiasbynens.github.io/rel-noopener/
 */
export function windowOpenNoOpener(url: string): void {
	if (platform.isNative || browser.isEdgeWebView) {
		// In VSCode, window.open() always returns null...
		// The same is true for a WebView (see https://github.com/Microsoft/monaco-editor/issues/628)
		window.open(url);
	} else {
		let newTab = window.open();
		if (newTab) {
			(newTab as any).opener = null;
			newTab.location.href = url;
		}
	}
}
