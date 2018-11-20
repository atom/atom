/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as browser from 'vs/base/browser/browser';
import * as dom from 'vs/base/browser/dom';
import { StandardWheelEvent } from 'vs/base/browser/mouseEvent';
import { RunOnceScheduler, TimeoutTimer } from 'vs/base/common/async';
import { Disposable } from 'vs/base/common/lifecycle';
import * as platform from 'vs/base/common/platform';
import { HitTestContext, IViewZoneData, MouseTarget, MouseTargetFactory } from 'vs/editor/browser/controller/mouseTarget';
import * as editorBrowser from 'vs/editor/browser/editorBrowser';
import { ClientCoordinates, EditorMouseEvent, EditorMouseEventFactory, GlobalEditorMouseMoveMonitor, createEditorPagePosition } from 'vs/editor/browser/editorDom';
import { ViewController } from 'vs/editor/browser/view/viewController';
import { IViewCursorRenderData } from 'vs/editor/browser/viewParts/viewCursors/viewCursor';
import { EditorZoom } from 'vs/editor/common/config/editorZoom';
import { Position } from 'vs/editor/common/core/position';
import { Selection } from 'vs/editor/common/core/selection';
import { HorizontalRange } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { ViewEventHandler } from 'vs/editor/common/viewModel/viewEventHandler';

/**
 * Merges mouse events when mouse move events are throttled
 */
function createMouseMoveEventMerger(mouseTargetFactory: MouseTargetFactory | null) {
	return function (lastEvent: EditorMouseEvent, currentEvent: EditorMouseEvent): EditorMouseEvent {
		let targetIsWidget = false;
		if (mouseTargetFactory) {
			targetIsWidget = mouseTargetFactory.mouseTargetIsWidget(currentEvent);
		}
		if (!targetIsWidget) {
			currentEvent.preventDefault();
		}
		return currentEvent;
	};
}

export interface IPointerHandlerHelper {
	viewDomNode: HTMLElement;
	linesContentDomNode: HTMLElement;

	focusTextArea(): void;

	/**
	 * Get the last rendered information of the cursors.
	 */
	getLastViewCursorsRenderData(): IViewCursorRenderData[];

	shouldSuppressMouseDownOnViewZone(viewZoneId: number): boolean;
	shouldSuppressMouseDownOnWidget(widgetId: string): boolean;

	/**
	 * Decode a position from a rendered dom node
	 */
	getPositionFromDOMInfo(spanNode: HTMLElement, offset: number): Position | null;

	visibleRangeForPosition2(lineNumber: number, column: number): HorizontalRange | null;
	getLineWidth(lineNumber: number): number;
}

export class MouseHandler extends ViewEventHandler {

	static MOUSE_MOVE_MINIMUM_TIME = 100; // ms

	protected _context: ViewContext;
	protected viewController: ViewController;
	protected viewHelper: IPointerHandlerHelper;
	protected mouseTargetFactory: MouseTargetFactory;
	private _asyncFocus: RunOnceScheduler;

	private _mouseDownOperation: MouseDownOperation;
	private lastMouseLeaveTime: number;

	constructor(context: ViewContext, viewController: ViewController, viewHelper: IPointerHandlerHelper) {
		super();

		this._context = context;
		this.viewController = viewController;
		this.viewHelper = viewHelper;
		this.mouseTargetFactory = new MouseTargetFactory(this._context, viewHelper);

		this._mouseDownOperation = this._register(new MouseDownOperation(
			this._context,
			this.viewController,
			this.viewHelper,
			(e, testEventTarget) => this._createMouseTarget(e, testEventTarget),
			(e) => this._getMouseColumn(e)
		));

		this._asyncFocus = this._register(new RunOnceScheduler(() => this.viewHelper.focusTextArea(), 0));

		this.lastMouseLeaveTime = -1;

		let mouseEvents = new EditorMouseEventFactory(this.viewHelper.viewDomNode);

		this._register(mouseEvents.onContextMenu(this.viewHelper.viewDomNode, (e) => this._onContextMenu(e, true)));

		this._register(mouseEvents.onMouseMoveThrottled(this.viewHelper.viewDomNode,
			(e) => this._onMouseMove(e),
			createMouseMoveEventMerger(this.mouseTargetFactory), MouseHandler.MOUSE_MOVE_MINIMUM_TIME));

		this._register(mouseEvents.onMouseUp(this.viewHelper.viewDomNode, (e) => this._onMouseUp(e)));

		this._register(mouseEvents.onMouseLeave(this.viewHelper.viewDomNode, (e) => this._onMouseLeave(e)));

		this._register(mouseEvents.onMouseDown(this.viewHelper.viewDomNode, (e) => this._onMouseDown(e)));

		let onMouseWheel = (browserEvent: WheelEvent) => {
			if (!this._context.configuration.editor.viewInfo.mouseWheelZoom) {
				return;
			}
			let e = new StandardWheelEvent(browserEvent);
			if (e.browserEvent!.ctrlKey || e.browserEvent!.metaKey) {
				let zoomLevel: number = EditorZoom.getZoomLevel();
				let delta = e.deltaY > 0 ? 1 : -1;
				EditorZoom.setZoomLevel(zoomLevel + delta);
				e.preventDefault();
				e.stopPropagation();
			}
		};
		this._register(dom.addDisposableListener(this.viewHelper.viewDomNode, 'wheel', onMouseWheel, true));

		this._context.addEventHandler(this);
	}

	public dispose(): void {
		this._context.removeEventHandler(this);
		super.dispose();
	}

	// --- begin event handlers
	public onCursorStateChanged(e: viewEvents.ViewCursorStateChangedEvent): boolean {
		this._mouseDownOperation.onCursorStateChanged(e);
		return false;
	}
	private _isFocused = false;
	public onFocusChanged(e: viewEvents.ViewFocusChangedEvent): boolean {
		this._isFocused = e.isFocused;
		return false;
	}
	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		this._mouseDownOperation.onScrollChanged();
		return false;
	}
	// --- end event handlers

	public getTargetAtClientPoint(clientX: number, clientY: number): editorBrowser.IMouseTarget | null {
		let clientPos = new ClientCoordinates(clientX, clientY);
		let pos = clientPos.toPageCoordinates();
		let editorPos = createEditorPagePosition(this.viewHelper.viewDomNode);

		if (pos.y < editorPos.y || pos.y > editorPos.y + editorPos.height || pos.x < editorPos.x || pos.x > editorPos.x + editorPos.width) {
			return null;
		}

		let lastViewCursorsRenderData = this.viewHelper.getLastViewCursorsRenderData();
		return this.mouseTargetFactory.createMouseTarget(lastViewCursorsRenderData, editorPos, pos, null);
	}

	protected _createMouseTarget(e: EditorMouseEvent, testEventTarget: boolean): editorBrowser.IMouseTarget {
		let lastViewCursorsRenderData = this.viewHelper.getLastViewCursorsRenderData();
		return this.mouseTargetFactory.createMouseTarget(lastViewCursorsRenderData, e.editorPos, e.pos, testEventTarget ? e.target : null);
	}

	private _getMouseColumn(e: EditorMouseEvent): number {
		return this.mouseTargetFactory.getMouseColumn(e.editorPos, e.pos);
	}

	protected _onContextMenu(e: EditorMouseEvent, testEventTarget: boolean): void {
		this.viewController.emitContextMenu({
			event: e,
			target: this._createMouseTarget(e, testEventTarget)
		});
	}

	private _onMouseMove(e: EditorMouseEvent): void {
		if (this._mouseDownOperation.isActive()) {
			// In selection/drag operation
			return;
		}
		let actualMouseMoveTime = e.timestamp;
		if (actualMouseMoveTime < this.lastMouseLeaveTime) {
			// Due to throttling, this event occurred before the mouse left the editor, therefore ignore it.
			return;
		}

		this.viewController.emitMouseMove({
			event: e,
			target: this._createMouseTarget(e, true)
		});
	}

	private _onMouseLeave(e: EditorMouseEvent): void {
		this.lastMouseLeaveTime = (new Date()).getTime();
		this.viewController.emitMouseLeave({
			event: e,
			target: null
		});
	}

	public _onMouseUp(e: EditorMouseEvent): void {
		this.viewController.emitMouseUp({
			event: e,
			target: this._createMouseTarget(e, true)
		});
	}

	public _onMouseDown(e: EditorMouseEvent): void {
		let t = this._createMouseTarget(e, true);

		let targetIsContent = (t.type === editorBrowser.MouseTargetType.CONTENT_TEXT || t.type === editorBrowser.MouseTargetType.CONTENT_EMPTY);
		let targetIsGutter = (t.type === editorBrowser.MouseTargetType.GUTTER_GLYPH_MARGIN || t.type === editorBrowser.MouseTargetType.GUTTER_LINE_NUMBERS || t.type === editorBrowser.MouseTargetType.GUTTER_LINE_DECORATIONS);
		let targetIsLineNumbers = (t.type === editorBrowser.MouseTargetType.GUTTER_LINE_NUMBERS);
		let selectOnLineNumbers = this._context.configuration.editor.viewInfo.selectOnLineNumbers;
		let targetIsViewZone = (t.type === editorBrowser.MouseTargetType.CONTENT_VIEW_ZONE || t.type === editorBrowser.MouseTargetType.GUTTER_VIEW_ZONE);
		let targetIsWidget = (t.type === editorBrowser.MouseTargetType.CONTENT_WIDGET);

		let shouldHandle = e.leftButton || e.middleButton;
		if (platform.isMacintosh && e.leftButton && e.ctrlKey) {
			shouldHandle = false;
		}

		let focus = () => {
			// In IE11, if the focus is in the browser's address bar and
			// then you click in the editor, calling preventDefault()
			// will not move focus properly (focus remains the address bar)
			if (browser.isIE && !this._isFocused) {
				this._asyncFocus.schedule();
			} else {
				e.preventDefault();
				this.viewHelper.focusTextArea();
			}
		};

		if (shouldHandle && (targetIsContent || (targetIsLineNumbers && selectOnLineNumbers))) {
			focus();
			this._mouseDownOperation.start(t.type, e);

		} else if (targetIsGutter) {
			// Do not steal focus
			e.preventDefault();
		} else if (targetIsViewZone) {
			let viewZoneData = <IViewZoneData>t.detail;
			if (this.viewHelper.shouldSuppressMouseDownOnViewZone(viewZoneData.viewZoneId)) {
				focus();
				this._mouseDownOperation.start(t.type, e);
				e.preventDefault();
			}
		} else if (targetIsWidget && this.viewHelper.shouldSuppressMouseDownOnWidget(<string>t.detail)) {
			focus();
			e.preventDefault();
		}

		this.viewController.emitMouseDown({
			event: e,
			target: t
		});
	}
}

class MouseDownOperation extends Disposable {

	private readonly _context: ViewContext;
	private readonly _viewController: ViewController;
	private readonly _viewHelper: IPointerHandlerHelper;
	private readonly _createMouseTarget: (e: EditorMouseEvent, testEventTarget: boolean) => editorBrowser.IMouseTarget;
	private readonly _getMouseColumn: (e: EditorMouseEvent) => number;

	private readonly _mouseMoveMonitor: GlobalEditorMouseMoveMonitor;
	private readonly _onScrollTimeout: TimeoutTimer;
	private readonly _mouseState: MouseDownState;

	private _currentSelection: Selection;
	private _isActive: boolean;
	private _lastMouseEvent: EditorMouseEvent | null;

	constructor(
		context: ViewContext,
		viewController: ViewController,
		viewHelper: IPointerHandlerHelper,
		createMouseTarget: (e: EditorMouseEvent, testEventTarget: boolean) => editorBrowser.IMouseTarget,
		getMouseColumn: (e: EditorMouseEvent) => number
	) {
		super();
		this._context = context;
		this._viewController = viewController;
		this._viewHelper = viewHelper;
		this._createMouseTarget = createMouseTarget;
		this._getMouseColumn = getMouseColumn;

		this._mouseMoveMonitor = this._register(new GlobalEditorMouseMoveMonitor(this._viewHelper.viewDomNode));
		this._onScrollTimeout = this._register(new TimeoutTimer());
		this._mouseState = new MouseDownState();

		this._currentSelection = new Selection(1, 1, 1, 1);
		this._isActive = false;
		this._lastMouseEvent = null;
	}

	public dispose(): void {
		super.dispose();
	}

	public isActive(): boolean {
		return this._isActive;
	}

	private _onMouseDownThenMove(e: EditorMouseEvent): void {
		this._lastMouseEvent = e;
		this._mouseState.setModifiers(e);

		let position = this._findMousePosition(e, true);
		if (!position) {
			// Ignoring because position is unknown
			return;
		}

		if (this._mouseState.isDragAndDrop) {
			this._viewController.emitMouseDrag({
				event: e,
				target: position
			});
		} else {
			this._dispatchMouse(position, true);
		}
	}

	public start(targetType: editorBrowser.MouseTargetType, e: EditorMouseEvent): void {
		this._lastMouseEvent = e;

		this._mouseState.setStartedOnLineNumbers(targetType === editorBrowser.MouseTargetType.GUTTER_LINE_NUMBERS);
		this._mouseState.setStartButtons(e);
		this._mouseState.setModifiers(e);
		let position = this._findMousePosition(e, true);
		if (!position || !position.position) {
			// Ignoring because position is unknown
			return;
		}

		this._mouseState.trySetCount(e.detail, position.position);

		// Overwrite the detail of the MouseEvent, as it will be sent out in an event and contributions might rely on it.
		e.detail = this._mouseState.count;

		if (!this._context.configuration.editor.readOnly
			&& this._context.configuration.editor.dragAndDrop
			&& !this._mouseState.altKey // we don't support multiple mouse
			&& e.detail < 2 // only single click on a selection can work
			&& !this._isActive // the mouse is not down yet
			&& !this._currentSelection.isEmpty() // we don't drag single cursor
			&& (position.type === editorBrowser.MouseTargetType.CONTENT_TEXT) // single click on text
			&& position.position && this._currentSelection.containsPosition(position.position) // single click on a selection
		) {
			this._mouseState.isDragAndDrop = true;
			this._isActive = true;

			this._mouseMoveMonitor.startMonitoring(
				createMouseMoveEventMerger(null),
				(e) => this._onMouseDownThenMove(e),
				() => {
					let position = this._findMousePosition(this._lastMouseEvent!, true);

					this._viewController.emitMouseDrop({
						event: this._lastMouseEvent!,
						target: (position ? this._createMouseTarget(this._lastMouseEvent!, true) : null) // Ignoring because position is unknown, e.g., Content View Zone
					});

					this._stop();
				}
			);

			return;
		}

		this._mouseState.isDragAndDrop = false;
		this._dispatchMouse(position, e.shiftKey);

		if (!this._isActive) {
			this._isActive = true;
			this._mouseMoveMonitor.startMonitoring(
				createMouseMoveEventMerger(null),
				(e) => this._onMouseDownThenMove(e),
				() => this._stop()
			);
		}
	}

	private _stop(): void {
		this._isActive = false;
		this._onScrollTimeout.cancel();
	}

	public onScrollChanged(): void {
		if (!this._isActive) {
			return;
		}
		this._onScrollTimeout.setIfNotSet(() => {
			if (!this._lastMouseEvent) {
				return;
			}
			let position = this._findMousePosition(this._lastMouseEvent, false);
			if (!position) {
				// Ignoring because position is unknown
				return;
			}
			if (this._mouseState.isDragAndDrop) {
				// Ignoring because users are dragging the text
				return;
			}
			this._dispatchMouse(position, true);
		}, 10);
	}

	public onCursorStateChanged(e: viewEvents.ViewCursorStateChangedEvent): void {
		this._currentSelection = e.selections[0];
	}

	private _getPositionOutsideEditor(e: EditorMouseEvent): MouseTarget | null {
		const editorContent = e.editorPos;
		const model = this._context.model;
		const viewLayout = this._context.viewLayout;

		const mouseColumn = this._getMouseColumn(e);

		if (e.posy < editorContent.y) {
			const verticalOffset = Math.max(viewLayout.getCurrentScrollTop() - (editorContent.y - e.posy), 0);
			const viewZoneData = HitTestContext.getZoneAtCoord(this._context, verticalOffset);
			if (viewZoneData) {
				const newPosition = this._helpPositionJumpOverViewZone(viewZoneData);
				if (newPosition) {
					return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, newPosition);
				}
			}

			let aboveLineNumber = viewLayout.getLineNumberAtVerticalOffset(verticalOffset);
			return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, new Position(aboveLineNumber, 1));
		}

		if (e.posy > editorContent.y + editorContent.height) {
			const verticalOffset = viewLayout.getCurrentScrollTop() + (e.posy - editorContent.y);
			const viewZoneData = HitTestContext.getZoneAtCoord(this._context, verticalOffset);
			if (viewZoneData) {
				const newPosition = this._helpPositionJumpOverViewZone(viewZoneData);
				if (newPosition) {
					return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, newPosition);
				}
			}

			let belowLineNumber = viewLayout.getLineNumberAtVerticalOffset(verticalOffset);
			return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, new Position(belowLineNumber, model.getLineMaxColumn(belowLineNumber)));
		}

		let possibleLineNumber = viewLayout.getLineNumberAtVerticalOffset(viewLayout.getCurrentScrollTop() + (e.posy - editorContent.y));

		if (e.posx < editorContent.x) {
			return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, new Position(possibleLineNumber, 1));
		}

		if (e.posx > editorContent.x + editorContent.width) {
			return new MouseTarget(null, editorBrowser.MouseTargetType.OUTSIDE_EDITOR, mouseColumn, new Position(possibleLineNumber, model.getLineMaxColumn(possibleLineNumber)));
		}

		return null;
	}

	private _findMousePosition(e: EditorMouseEvent, testEventTarget: boolean): MouseTarget | null {
		let positionOutsideEditor = this._getPositionOutsideEditor(e);
		if (positionOutsideEditor) {
			return positionOutsideEditor;
		}

		let t = this._createMouseTarget(e, testEventTarget);
		let hintedPosition = t.position;
		if (!hintedPosition) {
			return null;
		}

		if (t.type === editorBrowser.MouseTargetType.CONTENT_VIEW_ZONE || t.type === editorBrowser.MouseTargetType.GUTTER_VIEW_ZONE) {
			const newPosition = this._helpPositionJumpOverViewZone(<IViewZoneData>t.detail);
			if (newPosition) {
				return new MouseTarget(t.element, t.type, t.mouseColumn, newPosition, null, t.detail);
			}
		}

		return t;
	}

	private _helpPositionJumpOverViewZone(viewZoneData: IViewZoneData): Position | null {
		// Force position on view zones to go above or below depending on where selection started from
		let selectionStart = new Position(this._currentSelection.selectionStartLineNumber, this._currentSelection.selectionStartColumn);
		let positionBefore = viewZoneData.positionBefore;
		let positionAfter = viewZoneData.positionAfter;

		if (positionBefore && positionAfter) {
			if (positionBefore.isBefore(selectionStart)) {
				return positionBefore;
			} else {
				return positionAfter;
			}
		}
		return null;
	}

	private _dispatchMouse(position: MouseTarget, inSelectionMode: boolean): void {
		if (!position.position) {
			return;
		}
		this._viewController.dispatchMouse({
			position: position.position,
			mouseColumn: position.mouseColumn,
			startedOnLineNumbers: this._mouseState.startedOnLineNumbers,

			inSelectionMode: inSelectionMode,
			mouseDownCount: this._mouseState.count,
			altKey: this._mouseState.altKey,
			ctrlKey: this._mouseState.ctrlKey,
			metaKey: this._mouseState.metaKey,
			shiftKey: this._mouseState.shiftKey,

			leftButton: this._mouseState.leftButton,
			middleButton: this._mouseState.middleButton,
		});
	}
}

class MouseDownState {

	private static readonly CLEAR_MOUSE_DOWN_COUNT_TIME = 400; // ms

	private _altKey: boolean;
	public get altKey(): boolean { return this._altKey; }

	private _ctrlKey: boolean;
	public get ctrlKey(): boolean { return this._ctrlKey; }

	private _metaKey: boolean;
	public get metaKey(): boolean { return this._metaKey; }

	private _shiftKey: boolean;
	public get shiftKey(): boolean { return this._shiftKey; }

	private _leftButton: boolean;
	public get leftButton(): boolean { return this._leftButton; }

	private _middleButton: boolean;
	public get middleButton(): boolean { return this._middleButton; }

	private _startedOnLineNumbers: boolean;
	public get startedOnLineNumbers(): boolean { return this._startedOnLineNumbers; }

	private _lastMouseDownPosition: Position | null;
	private _lastMouseDownPositionEqualCount: number;
	private _lastMouseDownCount: number;
	private _lastSetMouseDownCountTime: number;
	public isDragAndDrop: boolean;

	constructor() {
		this._altKey = false;
		this._ctrlKey = false;
		this._metaKey = false;
		this._shiftKey = false;
		this._leftButton = false;
		this._middleButton = false;
		this._startedOnLineNumbers = false;
		this._lastMouseDownPosition = null;
		this._lastMouseDownPositionEqualCount = 0;
		this._lastMouseDownCount = 0;
		this._lastSetMouseDownCountTime = 0;
		this.isDragAndDrop = false;
	}

	public get count(): number {
		return this._lastMouseDownCount;
	}

	public setModifiers(source: EditorMouseEvent) {
		this._altKey = source.altKey;
		this._ctrlKey = source.ctrlKey;
		this._metaKey = source.metaKey;
		this._shiftKey = source.shiftKey;
	}

	public setStartButtons(source: EditorMouseEvent) {
		this._leftButton = source.leftButton;
		this._middleButton = source.middleButton;
	}

	public setStartedOnLineNumbers(startedOnLineNumbers: boolean): void {
		this._startedOnLineNumbers = startedOnLineNumbers;
	}

	public trySetCount(setMouseDownCount: number, newMouseDownPosition: Position): void {
		// a. Invalidate multiple clicking if too much time has passed (will be hit by IE because the detail field of mouse events contains garbage in IE10)
		let currentTime = (new Date()).getTime();
		if (currentTime - this._lastSetMouseDownCountTime > MouseDownState.CLEAR_MOUSE_DOWN_COUNT_TIME) {
			setMouseDownCount = 1;
		}
		this._lastSetMouseDownCountTime = currentTime;

		// b. Ensure that we don't jump from single click to triple click in one go (will be hit by IE because the detail field of mouse events contains garbage in IE10)
		if (setMouseDownCount > this._lastMouseDownCount + 1) {
			setMouseDownCount = this._lastMouseDownCount + 1;
		}

		// c. Invalidate multiple clicking if the logical position is different
		if (this._lastMouseDownPosition && this._lastMouseDownPosition.equals(newMouseDownPosition)) {
			this._lastMouseDownPositionEqualCount++;
		} else {
			this._lastMouseDownPositionEqualCount = 1;
		}
		this._lastMouseDownPosition = newMouseDownPosition;

		// Finally set the lastMouseDownCount
		this._lastMouseDownCount = Math.min(setMouseDownCount, this._lastMouseDownPositionEqualCount);
	}

}
