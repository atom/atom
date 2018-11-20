/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as errors from 'vs/base/common/errors';
import { Disposable, IDisposable, toDisposable } from 'vs/base/common/lifecycle';
import { ScrollEvent } from 'vs/base/common/scrollable';
import { IConfigurationChangedEvent } from 'vs/editor/common/config/editorOptions';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { ScrollType } from 'vs/editor/common/editorCommon';

export const enum ViewEventType {
	ViewConfigurationChanged = 1,
	ViewCursorStateChanged = 2,
	ViewDecorationsChanged = 3,
	ViewFlushed = 4,
	ViewFocusChanged = 5,
	ViewLineMappingChanged = 6,
	ViewLinesChanged = 7,
	ViewLinesDeleted = 8,
	ViewLinesInserted = 9,
	ViewRevealRangeRequest = 10,
	ViewScrollChanged = 11,
	ViewTokensChanged = 12,
	ViewTokensColorsChanged = 13,
	ViewZonesChanged = 14,
	ViewThemeChanged = 15,
	ViewLanguageConfigurationChanged = 16
}

export class ViewConfigurationChangedEvent {

	public readonly type = ViewEventType.ViewConfigurationChanged;

	public readonly canUseLayerHinting: boolean;
	public readonly pixelRatio: boolean;
	public readonly editorClassName: boolean;
	public readonly lineHeight: boolean;
	public readonly readOnly: boolean;
	public readonly accessibilitySupport: boolean;
	public readonly emptySelectionClipboard: boolean;
	public readonly copyWithSyntaxHighlighting: boolean;
	public readonly layoutInfo: boolean;
	public readonly fontInfo: boolean;
	public readonly viewInfo: boolean;
	public readonly wrappingInfo: boolean;

	constructor(source: IConfigurationChangedEvent) {
		this.canUseLayerHinting = source.canUseLayerHinting;
		this.pixelRatio = source.pixelRatio;
		this.editorClassName = source.editorClassName;
		this.lineHeight = source.lineHeight;
		this.readOnly = source.readOnly;
		this.accessibilitySupport = source.accessibilitySupport;
		this.emptySelectionClipboard = source.emptySelectionClipboard;
		this.copyWithSyntaxHighlighting = source.copyWithSyntaxHighlighting;
		this.layoutInfo = source.layoutInfo;
		this.fontInfo = source.fontInfo;
		this.viewInfo = source.viewInfo;
		this.wrappingInfo = source.wrappingInfo;
	}
}

export class ViewCursorStateChangedEvent {

	public readonly type = ViewEventType.ViewCursorStateChanged;

	/**
	 * The primary selection is always at index 0.
	 */
	public readonly selections: Selection[];

	constructor(selections: Selection[]) {
		this.selections = selections;
	}
}

export class ViewDecorationsChangedEvent {

	public readonly type = ViewEventType.ViewDecorationsChanged;

	constructor() {
		// Nothing to do
	}
}

export class ViewFlushedEvent {

	public readonly type = ViewEventType.ViewFlushed;

	constructor() {
		// Nothing to do
	}
}

export class ViewFocusChangedEvent {

	public readonly type = ViewEventType.ViewFocusChanged;

	public readonly isFocused: boolean;

	constructor(isFocused: boolean) {
		this.isFocused = isFocused;
	}
}

export class ViewLineMappingChangedEvent {

	public readonly type = ViewEventType.ViewLineMappingChanged;

	constructor() {
		// Nothing to do
	}
}

export class ViewLinesChangedEvent {

	public readonly type = ViewEventType.ViewLinesChanged;

	/**
	 * The first line that has changed.
	 */
	public readonly fromLineNumber: number;
	/**
	 * The last line that has changed.
	 */
	public readonly toLineNumber: number;

	constructor(fromLineNumber: number, toLineNumber: number) {
		this.fromLineNumber = fromLineNumber;
		this.toLineNumber = toLineNumber;
	}
}

export class ViewLinesDeletedEvent {

	public readonly type = ViewEventType.ViewLinesDeleted;

	/**
	 * At what line the deletion began (inclusive).
	 */
	public readonly fromLineNumber: number;
	/**
	 * At what line the deletion stopped (inclusive).
	 */
	public readonly toLineNumber: number;

	constructor(fromLineNumber: number, toLineNumber: number) {
		this.fromLineNumber = fromLineNumber;
		this.toLineNumber = toLineNumber;
	}
}

export class ViewLinesInsertedEvent {

	public readonly type = ViewEventType.ViewLinesInserted;

	/**
	 * Before what line did the insertion begin
	 */
	public readonly fromLineNumber: number;
	/**
	 * `toLineNumber` - `fromLineNumber` + 1 denotes the number of lines that were inserted
	 */
	public readonly toLineNumber: number;

	constructor(fromLineNumber: number, toLineNumber: number) {
		this.fromLineNumber = fromLineNumber;
		this.toLineNumber = toLineNumber;
	}
}

export const enum VerticalRevealType {
	Simple = 0,
	Center = 1,
	CenterIfOutsideViewport = 2,
	Top = 3,
	Bottom = 4
}

export class ViewRevealRangeRequestEvent {

	public readonly type = ViewEventType.ViewRevealRangeRequest;

	/**
	 * Range to be reavealed.
	 */
	public readonly range: Range;

	public readonly verticalType: VerticalRevealType;
	/**
	 * If true: there should be a horizontal & vertical revealing
	 * If false: there should be just a vertical revealing
	 */
	public readonly revealHorizontal: boolean;

	public readonly scrollType: ScrollType;

	constructor(range: Range, verticalType: VerticalRevealType, revealHorizontal: boolean, scrollType: ScrollType) {
		this.range = range;
		this.verticalType = verticalType;
		this.revealHorizontal = revealHorizontal;
		this.scrollType = scrollType;
	}
}

export class ViewScrollChangedEvent {

	public readonly type = ViewEventType.ViewScrollChanged;

	public readonly scrollWidth: number;
	public readonly scrollLeft: number;
	public readonly scrollHeight: number;
	public readonly scrollTop: number;

	public readonly scrollWidthChanged: boolean;
	public readonly scrollLeftChanged: boolean;
	public readonly scrollHeightChanged: boolean;
	public readonly scrollTopChanged: boolean;

	constructor(source: ScrollEvent) {
		this.scrollWidth = source.scrollWidth;
		this.scrollLeft = source.scrollLeft;
		this.scrollHeight = source.scrollHeight;
		this.scrollTop = source.scrollTop;

		this.scrollWidthChanged = source.scrollWidthChanged;
		this.scrollLeftChanged = source.scrollLeftChanged;
		this.scrollHeightChanged = source.scrollHeightChanged;
		this.scrollTopChanged = source.scrollTopChanged;
	}
}

export class ViewTokensChangedEvent {

	public readonly type = ViewEventType.ViewTokensChanged;

	public readonly ranges: {
		/**
		 * Start line number of range
		 */
		readonly fromLineNumber: number;
		/**
		 * End line number of range
		 */
		readonly toLineNumber: number;
	}[];

	constructor(ranges: { fromLineNumber: number; toLineNumber: number; }[]) {
		this.ranges = ranges;
	}
}

export class ViewThemeChangedEvent {

	public readonly type = ViewEventType.ViewThemeChanged;

	constructor() {
	}
}

export class ViewTokensColorsChangedEvent {

	public readonly type = ViewEventType.ViewTokensColorsChanged;

	constructor() {
		// Nothing to do
	}
}

export class ViewZonesChangedEvent {

	public readonly type = ViewEventType.ViewZonesChanged;

	constructor() {
		// Nothing to do
	}
}

export class ViewLanguageConfigurationEvent {

	public readonly type = ViewEventType.ViewLanguageConfigurationChanged;

	constructor() {
	}
}

export type ViewEvent = (
	ViewConfigurationChangedEvent
	| ViewCursorStateChangedEvent
	| ViewDecorationsChangedEvent
	| ViewFlushedEvent
	| ViewFocusChangedEvent
	| ViewLinesChangedEvent
	| ViewLineMappingChangedEvent
	| ViewLinesDeletedEvent
	| ViewLinesInsertedEvent
	| ViewRevealRangeRequestEvent
	| ViewScrollChangedEvent
	| ViewTokensChangedEvent
	| ViewTokensColorsChangedEvent
	| ViewZonesChangedEvent
	| ViewThemeChangedEvent
	| ViewLanguageConfigurationEvent
);

export interface IViewEventListener {
	(events: ViewEvent[]): void;
}

export class ViewEventEmitter extends Disposable {
	private _listeners: IViewEventListener[];
	private _collector: ViewEventsCollector | null;
	private _collectorCnt: number;

	constructor() {
		super();
		this._listeners = [];
		this._collector = null;
		this._collectorCnt = 0;
	}

	public dispose(): void {
		this._listeners = [];
		super.dispose();
	}

	protected _beginEmit(): ViewEventsCollector {
		this._collectorCnt++;
		if (this._collectorCnt === 1) {
			this._collector = new ViewEventsCollector();
		}
		return this._collector!;
	}

	protected _endEmit(): void {
		this._collectorCnt--;
		if (this._collectorCnt === 0) {
			const events = this._collector!.finalize();
			this._collector = null;
			if (events.length > 0) {
				this._emit(events);
			}
		}
	}

	private _emit(events: ViewEvent[]): void {
		const listeners = this._listeners.slice(0);
		for (let i = 0, len = listeners.length; i < len; i++) {
			safeInvokeListener(listeners[i], events);
		}
	}

	public addEventListener(listener: (events: ViewEvent[]) => void): IDisposable {
		this._listeners.push(listener);
		return toDisposable(() => {
			let listeners = this._listeners;
			for (let i = 0, len = listeners.length; i < len; i++) {
				if (listeners[i] === listener) {
					listeners.splice(i, 1);
					break;
				}
			}
		});
	}
}

export class ViewEventsCollector {

	private _events: ViewEvent[];
	private _eventsLen = 0;

	constructor() {
		this._events = [];
		this._eventsLen = 0;
	}

	public emit(event: ViewEvent) {
		this._events[this._eventsLen++] = event;
	}

	public finalize(): ViewEvent[] {
		let result = this._events;
		this._events = [];
		return result;
	}

}

function safeInvokeListener(listener: IViewEventListener, events: ViewEvent[]): void {
	try {
		listener(events);
	} catch (e) {
		errors.onUnexpectedError(e);
	}
}
