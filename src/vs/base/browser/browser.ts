/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Emitter, Event } from 'vs/base/common/event';
import { IDisposable } from 'vs/base/common/lifecycle';
import * as platform from 'vs/base/common/platform';

class WindowManager {

	public static readonly INSTANCE = new WindowManager();

	// --- Zoom Level
	private _zoomLevel: number = 0;
	private _lastZoomLevelChangeTime: number = 0;
	private readonly _onDidChangeZoomLevel: Emitter<number> = new Emitter<number>();

	public readonly onDidChangeZoomLevel: Event<number> = this._onDidChangeZoomLevel.event;
	public getZoomLevel(): number {
		return this._zoomLevel;
	}
	public getTimeSinceLastZoomLevelChanged(): number {
		return Date.now() - this._lastZoomLevelChangeTime;
	}
	public setZoomLevel(zoomLevel: number, isTrusted: boolean): void {
		if (this._zoomLevel === zoomLevel) {
			return;
		}

		this._zoomLevel = zoomLevel;
		// See https://github.com/Microsoft/vscode/issues/26151
		this._lastZoomLevelChangeTime = isTrusted ? 0 : Date.now();
		this._onDidChangeZoomLevel.fire(this._zoomLevel);
	}

	// --- Zoom Factor
	private _zoomFactor: number = 0;

	public getZoomFactor(): number {
		return this._zoomFactor;
	}
	public setZoomFactor(zoomFactor: number): void {
		this._zoomFactor = zoomFactor;
	}

	// --- Pixel Ratio
	public getPixelRatio(): number {
		let ctx = document.createElement('canvas').getContext('2d');
		let dpr = window.devicePixelRatio || 1;
		let bsr = (<any>ctx).webkitBackingStorePixelRatio ||
			(<any>ctx).mozBackingStorePixelRatio ||
			(<any>ctx).msBackingStorePixelRatio ||
			(<any>ctx).oBackingStorePixelRatio ||
			(<any>ctx).backingStorePixelRatio || 1;
		return dpr / bsr;
	}

	// --- Fullscreen
	private _fullscreen: boolean;
	private readonly _onDidChangeFullscreen: Emitter<void> = new Emitter<void>();

	public readonly onDidChangeFullscreen: Event<void> = this._onDidChangeFullscreen.event;
	public setFullscreen(fullscreen: boolean): void {
		if (this._fullscreen === fullscreen) {
			return;
		}

		this._fullscreen = fullscreen;
		this._onDidChangeFullscreen.fire();
	}
	public isFullscreen(): boolean {
		return this._fullscreen;
	}

	// --- Accessibility
	private _accessibilitySupport = platform.AccessibilitySupport.Unknown;
	private readonly _onDidChangeAccessibilitySupport: Emitter<void> = new Emitter<void>();

	public readonly onDidChangeAccessibilitySupport: Event<void> = this._onDidChangeAccessibilitySupport.event;
	public setAccessibilitySupport(accessibilitySupport: platform.AccessibilitySupport): void {
		if (this._accessibilitySupport === accessibilitySupport) {
			return;
		}

		this._accessibilitySupport = accessibilitySupport;
		this._onDidChangeAccessibilitySupport.fire();
	}
	public getAccessibilitySupport(): platform.AccessibilitySupport {
		return this._accessibilitySupport;
	}
}

/** A zoom index, e.g. 1, 2, 3 */
export function setZoomLevel(zoomLevel: number, isTrusted: boolean): void {
	WindowManager.INSTANCE.setZoomLevel(zoomLevel, isTrusted);
}
export function getZoomLevel(): number {
	return WindowManager.INSTANCE.getZoomLevel();
}
/** Returns the time (in ms) since the zoom level was changed */
export function getTimeSinceLastZoomLevelChanged(): number {
	return WindowManager.INSTANCE.getTimeSinceLastZoomLevelChanged();
}
export function onDidChangeZoomLevel(callback: (zoomLevel: number) => void): IDisposable {
	return WindowManager.INSTANCE.onDidChangeZoomLevel(callback);
}

/** The zoom scale for an index, e.g. 1, 1.2, 1.4 */
export function getZoomFactor(): number {
	return WindowManager.INSTANCE.getZoomFactor();
}
export function setZoomFactor(zoomFactor: number): void {
	WindowManager.INSTANCE.setZoomFactor(zoomFactor);
}

export function getPixelRatio(): number {
	return WindowManager.INSTANCE.getPixelRatio();
}

export function setFullscreen(fullscreen: boolean): void {
	WindowManager.INSTANCE.setFullscreen(fullscreen);
}
export function isFullscreen(): boolean {
	return WindowManager.INSTANCE.isFullscreen();
}
export const onDidChangeFullscreen = WindowManager.INSTANCE.onDidChangeFullscreen;

export function setAccessibilitySupport(accessibilitySupport: platform.AccessibilitySupport): void {
	WindowManager.INSTANCE.setAccessibilitySupport(accessibilitySupport);
}
export function getAccessibilitySupport(): platform.AccessibilitySupport {
	return WindowManager.INSTANCE.getAccessibilitySupport();
}
export function onDidChangeAccessibilitySupport(callback: () => void): IDisposable {
	return WindowManager.INSTANCE.onDidChangeAccessibilitySupport(callback);
}

const userAgent = navigator.userAgent;

export const isIE = (userAgent.indexOf('Trident') >= 0);
export const isEdge = (userAgent.indexOf('Edge/') >= 0);
export const isEdgeOrIE = isIE || isEdge;

export const isOpera = (userAgent.indexOf('Opera') >= 0);
export const isFirefox = (userAgent.indexOf('Firefox') >= 0);
export const isWebKit = (userAgent.indexOf('AppleWebKit') >= 0);
export const isChrome = (userAgent.indexOf('Chrome') >= 0);
export const isSafari = (userAgent.indexOf('Chrome') === -1) && (userAgent.indexOf('Safari') >= 0);
export const isIPad = (userAgent.indexOf('iPad') >= 0);
export const isEdgeWebView = isEdge && (userAgent.indexOf('WebView/') >= 0);

export function hasClipboardSupport() {
	if (isIE) {
		return false;
	}

	if (isEdge) {
		let index = userAgent.indexOf('Edge/');
		let version = parseInt(userAgent.substring(index + 5, userAgent.indexOf('.', index)), 10);

		if (!version || (version >= 12 && version <= 16)) {
			return false;
		}
	}

	return true;
}
