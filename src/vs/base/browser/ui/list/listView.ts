/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { getOrDefault2 } from 'vs/base/common/objects';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { Gesture, EventType as TouchEventType, GestureEvent } from 'vs/base/browser/touch';
import * as DOM from 'vs/base/browser/dom';
import { Event, mapEvent, filterEvent } from 'vs/base/common/event';
import { domEvent } from 'vs/base/browser/event';
import { ScrollableElement } from 'vs/base/browser/ui/scrollbar/scrollableElement';
import { ScrollEvent, ScrollbarVisibility } from 'vs/base/common/scrollable';
import { RangeMap, shift } from './rangeMap';
import { IListVirtualDelegate, IListRenderer, IListMouseEvent, IListTouchEvent, IListGestureEvent } from './list';
import { RowCache, IRow } from './rowCache';
import { isWindows } from 'vs/base/common/platform';
import * as browser from 'vs/base/browser/browser';
import { ISpliceable } from 'vs/base/common/sequence';
import { memoize } from 'vs/base/common/decorators';
import { DragMouseEvent } from 'vs/base/browser/mouseEvent';
import { Range, IRange } from 'vs/base/common/range';

function canUseTranslate3d(): boolean {
	if (browser.isFirefox) {
		return false;
	}

	if (browser.getZoomLevel() !== 0) {
		return false;
	}

	return true;
}

interface IItem<T> {
	readonly id: string;
	readonly element: T;
	readonly templateId: string;
	row: IRow | null;
	size: number;
	hasDynamicHeight: boolean;
	renderWidth: number | undefined;
}

export interface IListViewOptions {
	readonly useShadows?: boolean;
	readonly verticalScrollMode?: ScrollbarVisibility;
	readonly setRowLineHeight?: boolean;
	readonly supportDynamicHeights?: boolean;
}

const DefaultOptions = {
	useShadows: true,
	verticalScrollMode: ScrollbarVisibility.Auto,
	setRowLineHeight: true,
	supportDynamicHeights: false
};

export class ListView<T> implements ISpliceable<T>, IDisposable {

	readonly domNode: HTMLElement;

	private items: IItem<T>[];
	private itemId: number;
	private rangeMap: RangeMap;
	private cache: RowCache<T>;
	private renderers = new Map<string, IListRenderer<T, any>>();
	private lastRenderTop: number;
	private lastRenderHeight: number;
	private renderWidth = 0;
	private gesture: Gesture;
	private rowsContainer: HTMLElement;
	private scrollableElement: ScrollableElement;
	private scrollHeight: number;
	private didRequestScrollableElementUpdate: boolean = false;
	private splicing = false;
	private dragAndDropScrollInterval: number;
	private dragAndDropScrollTimeout: number;
	private dragAndDropMouseY: number;
	private setRowLineHeight: boolean;
	private supportDynamicHeights: boolean;
	private disposables: IDisposable[];

	constructor(
		container: HTMLElement,
		private virtualDelegate: IListVirtualDelegate<T>,
		renderers: IListRenderer<T, any>[],
		options: IListViewOptions = DefaultOptions
	) {
		this.items = [];
		this.itemId = 0;
		this.rangeMap = new RangeMap();

		for (const renderer of renderers) {
			this.renderers.set(renderer.templateId, renderer);
		}

		this.cache = new RowCache(this.renderers);

		this.lastRenderTop = 0;
		this.lastRenderHeight = 0;

		this.domNode = document.createElement('div');
		this.domNode.className = 'monaco-list';

		this.rowsContainer = document.createElement('div');
		this.rowsContainer.className = 'monaco-list-rows';
		Gesture.addTarget(this.rowsContainer);

		this.scrollableElement = new ScrollableElement(this.rowsContainer, {
			alwaysConsumeMouseWheel: true,
			horizontal: ScrollbarVisibility.Hidden,
			vertical: getOrDefault2(options, o => o.verticalScrollMode, DefaultOptions.verticalScrollMode),
			useShadows: getOrDefault2(options, o => o.useShadows, DefaultOptions.useShadows)
		});

		this.domNode.appendChild(this.scrollableElement.getDomNode());
		container.appendChild(this.domNode);

		this.disposables = [this.rangeMap, this.gesture, this.scrollableElement, this.cache];

		this.scrollableElement.onScroll(this.onScroll, this, this.disposables);
		domEvent(this.rowsContainer, TouchEventType.Change)(this.onTouchChange, this, this.disposables);

		// Prevent the monaco-scrollable-element from scrolling
		// https://github.com/Microsoft/vscode/issues/44181
		domEvent(this.scrollableElement.getDomNode(), 'scroll')
			(e => (e.target as HTMLElement).scrollTop = 0, null, this.disposables);

		const onDragOver = mapEvent(domEvent(this.rowsContainer, 'dragover'), e => new DragMouseEvent(e));
		onDragOver(this.onDragOver, this, this.disposables);

		this.setRowLineHeight = getOrDefault2(options, o => o.setRowLineHeight, DefaultOptions.setRowLineHeight);
		this.supportDynamicHeights = getOrDefault2(options, o => o.supportDynamicHeights, DefaultOptions.supportDynamicHeights);

		this.layout();
	}

	splice(start: number, deleteCount: number, elements: T[] = []): T[] {
		if (this.splicing) {
			throw new Error('Can\'t run recursive splices.');
		}

		this.splicing = true;

		try {
			return this._splice(start, deleteCount, elements);
		} finally {
			this.splicing = false;
		}
	}

	private _splice(start: number, deleteCount: number, elements: T[] = []): T[] {
		const previousRenderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
		const deleteRange = { start, end: start + deleteCount };
		const removeRange = Range.intersect(previousRenderRange, deleteRange);

		for (let i = removeRange.start; i < removeRange.end; i++) {
			this.removeItemFromDOM(i);
		}

		const previousRestRange: IRange = { start: start + deleteCount, end: this.items.length };
		const previousRenderedRestRange = Range.intersect(previousRestRange, previousRenderRange);
		const previousUnrenderedRestRanges = Range.relativeComplement(previousRestRange, previousRenderRange);

		const inserted = elements.map<IItem<T>>(element => ({
			id: String(this.itemId++),
			element,
			templateId: this.virtualDelegate.getTemplateId(element),
			size: this.virtualDelegate.getHeight(element),
			hasDynamicHeight: !!this.virtualDelegate.hasDynamicHeight && this.virtualDelegate.hasDynamicHeight(element),
			renderWidth: undefined,
			row: null
		}));

		let deleted: IItem<T>[];

		// TODO@joao: improve this optimization to catch even more cases
		if (start === 0 && deleteCount >= this.items.length) {
			this.rangeMap = new RangeMap();
			this.rangeMap.splice(0, 0, inserted);
			this.items = inserted;
			deleted = [];
		} else {
			this.rangeMap.splice(start, deleteCount, inserted);
			deleted = this.items.splice(start, deleteCount, ...inserted);
		}

		const delta = elements.length - deleteCount;
		const renderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
		const renderedRestRange = shift(previousRenderedRestRange, delta);
		const updateRange = Range.intersect(renderRange, renderedRestRange);

		for (let i = updateRange.start; i < updateRange.end; i++) {
			this.updateItemInDOM(this.items[i], i);
		}

		const removeRanges = Range.relativeComplement(renderedRestRange, renderRange);

		for (const range of removeRanges) {
			for (let i = range.start; i < range.end; i++) {
				this.removeItemFromDOM(i);
			}
		}

		const unrenderedRestRanges = previousUnrenderedRestRanges.map(r => shift(r, delta));
		const elementsRange = { start, end: start + elements.length };
		const insertRanges = [elementsRange, ...unrenderedRestRanges].map(r => Range.intersect(renderRange, r));
		const beforeElement = this.getNextToLastElement(insertRanges);

		for (const range of insertRanges) {
			for (let i = range.start; i < range.end; i++) {
				this.insertItemInDOM(i, beforeElement);
			}
		}

		this.updateScrollHeight();

		if (this.supportDynamicHeights) {
			this.rerender(this.scrollTop, this.renderHeight);
		}

		return deleted.map(i => i.element);
	}

	private updateScrollHeight(): void {
		this.scrollHeight = this.getContentHeight();
		this.rowsContainer.style.height = `${this.scrollHeight}px`;

		if (!this.didRequestScrollableElementUpdate) {
			DOM.scheduleAtNextAnimationFrame(() => {
				this.scrollableElement.setScrollDimensions({ scrollHeight: this.scrollHeight });
				this.didRequestScrollableElementUpdate = false;
			});

			this.didRequestScrollableElementUpdate = true;
		}
	}

	get length(): number {
		return this.items.length;
	}

	get renderHeight(): number {
		const scrollDimensions = this.scrollableElement.getScrollDimensions();
		return scrollDimensions.height;
	}

	element(index: number): T {
		return this.items[index].element;
	}

	domElement(index: number): HTMLElement | null {
		const row = this.items[index].row;
		return row && row.domNode;
	}

	elementHeight(index: number): number {
		return this.items[index].size;
	}

	elementTop(index: number): number {
		return this.rangeMap.positionAt(index);
	}

	indexAt(position: number): number {
		return this.rangeMap.indexAt(position);
	}

	indexAfter(position: number): number {
		return this.rangeMap.indexAfter(position);
	}

	layout(height?: number): void {
		this.scrollableElement.setScrollDimensions({
			height: height || DOM.getContentHeight(this.domNode)
		});
	}

	layoutWidth(width: number): void {
		this.renderWidth = width;

		if (this.supportDynamicHeights) {
			this.rerender(this.scrollTop, this.renderHeight);
		}
	}

	// Render

	private render(renderTop: number, renderHeight: number): void {
		const previousRenderRange = this.getRenderRange(this.lastRenderTop, this.lastRenderHeight);
		const renderRange = this.getRenderRange(renderTop, renderHeight);

		const rangesToInsert = Range.relativeComplement(renderRange, previousRenderRange);
		const rangesToRemove = Range.relativeComplement(previousRenderRange, renderRange);
		const beforeElement = this.getNextToLastElement(rangesToInsert);

		for (const range of rangesToInsert) {
			for (let i = range.start; i < range.end; i++) {
				this.insertItemInDOM(i, beforeElement);
			}
		}

		for (const range of rangesToRemove) {
			for (let i = range.start; i < range.end; i++) {
				this.removeItemFromDOM(i);
			}
		}

		if (canUseTranslate3d() && !isWindows /* Windows: translate3d breaks subpixel-antialias (ClearType) unless a background is defined */) {
			const transform = `translate3d(0px, -${renderTop}px, 0px)`;
			this.rowsContainer.style.transform = transform;
			this.rowsContainer.style.webkitTransform = transform;
		} else {
			this.rowsContainer.style.top = `-${renderTop}px`;
		}

		this.lastRenderTop = renderTop;
		this.lastRenderHeight = renderHeight;
	}

	// DOM operations

	private insertItemInDOM(index: number, beforeElement: HTMLElement | null): void {
		const item = this.items[index];

		if (!item.row) {
			item.row = this.cache.alloc(item.templateId);
		}

		if (!item.row.domNode!.parentElement) {
			if (beforeElement) {
				this.rowsContainer.insertBefore(item.row.domNode!, beforeElement);
			} else {
				this.rowsContainer.appendChild(item.row.domNode!);
			}
		}

		this.updateItemInDOM(item, index);

		const renderer = this.renderers.get(item.templateId);
		renderer.renderElement(item.element, index, item.row.templateData);
	}

	private updateItemInDOM(item: IItem<T>, index: number): void {
		item.row!.domNode!.style.top = `${this.elementTop(index)}px`;
		item.row!.domNode!.style.height = `${item.size}px`;

		if (this.setRowLineHeight) {
			item.row!.domNode!.style.lineHeight = `${item.size}px`;
		}

		item.row!.domNode!.setAttribute('data-index', `${index}`);
		item.row!.domNode!.setAttribute('data-last-element', index === this.length - 1 ? 'true' : 'false');
		item.row!.domNode!.setAttribute('aria-setsize', `${this.length}`);
		item.row!.domNode!.setAttribute('aria-posinset', `${index + 1}`);
	}

	private removeItemFromDOM(index: number): void {
		const item = this.items[index];
		const renderer = this.renderers.get(item.templateId);

		if (renderer.disposeElement) {
			renderer.disposeElement(item.element, index, item.row!.templateData);
		}

		this.cache.release(item.row!);
		item.row = null;
	}

	getContentHeight(): number {
		return this.rangeMap.size;
	}

	getScrollTop(): number {
		const scrollPosition = this.scrollableElement.getScrollPosition();
		return scrollPosition.scrollTop;
	}

	setScrollTop(scrollTop: number): void {
		this.scrollableElement.setScrollPosition({ scrollTop });
	}

	get scrollTop(): number {
		return this.getScrollTop();
	}

	set scrollTop(scrollTop: number) {
		this.setScrollTop(scrollTop);
	}

	// Events

	@memoize get onMouseClick(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'click'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseDblClick(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'dblclick'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseMiddleClick(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'auxclick'), e => this.toMouseEvent(e as MouseEvent)), e => e.index >= 0 && e.browserEvent.button === 1); }
	@memoize get onMouseUp(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'mouseup'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseDown(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'mousedown'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseOver(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'mouseover'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseMove(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'mousemove'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onMouseOut(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'mouseout'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onContextMenu(): Event<IListMouseEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'contextmenu'), e => this.toMouseEvent(e)), e => e.index >= 0); }
	@memoize get onTouchStart(): Event<IListTouchEvent<T>> { return filterEvent(mapEvent(domEvent(this.domNode, 'touchstart'), e => this.toTouchEvent(e)), e => e.index >= 0); }
	@memoize get onTap(): Event<IListGestureEvent<T>> { return filterEvent(mapEvent(domEvent(this.rowsContainer, TouchEventType.Tap), e => this.toGestureEvent(e)), e => e.index >= 0); }

	private toMouseEvent(browserEvent: MouseEvent): IListMouseEvent<T> {
		const index = this.getItemIndexFromEventTarget(browserEvent.target || null);
		const item = index < 0 ? undefined : this.items[index];
		const element = item && item.element;
		return { browserEvent, index, element };
	}

	private toTouchEvent(browserEvent: TouchEvent): IListTouchEvent<T> {
		const index = this.getItemIndexFromEventTarget(browserEvent.target || null);
		const item = index < 0 ? undefined : this.items[index];
		const element = item && item.element;
		return { browserEvent, index, element };
	}

	private toGestureEvent(browserEvent: GestureEvent): IListGestureEvent<T> {
		const index = this.getItemIndexFromEventTarget(browserEvent.initialTarget || null);
		const item = index < 0 ? undefined : this.items[index];
		const element = item && item.element;
		return { browserEvent, index, element };
	}

	private onScroll(e: ScrollEvent): void {
		try {
			this.render(e.scrollTop, e.height);

			if (this.supportDynamicHeights) {
				this.rerender(e.scrollTop, e.height);
			}
		} catch (err) {
			console.log('Got bad scroll event:', e);
			throw err;
		}
	}

	private onTouchChange(event: GestureEvent): void {
		event.preventDefault();
		event.stopPropagation();

		this.scrollTop -= event.translationY;
	}

	private onDragOver(event: DragMouseEvent): void {
		this.setupDragAndDropScrollInterval();
		this.dragAndDropMouseY = event.posy;
	}

	private setupDragAndDropScrollInterval(): void {
		const viewTop = DOM.getTopLeftOffset(this.domNode).top;

		if (!this.dragAndDropScrollInterval) {
			this.dragAndDropScrollInterval = window.setInterval(() => {
				if (this.dragAndDropMouseY === undefined) {
					return;
				}

				var diff = this.dragAndDropMouseY - viewTop;
				var scrollDiff = 0;
				var upperLimit = this.renderHeight - 35;

				if (diff < 35) {
					scrollDiff = Math.max(-14, 0.2 * (diff - 35));
				} else if (diff > upperLimit) {
					scrollDiff = Math.min(14, 0.2 * (diff - upperLimit));
				}

				this.scrollTop += scrollDiff;
			}, 10);

			this.cancelDragAndDropScrollTimeout();

			this.dragAndDropScrollTimeout = window.setTimeout(() => {
				this.cancelDragAndDropScrollInterval();
				this.dragAndDropScrollTimeout = -1;
			}, 1000);
		}
	}

	private cancelDragAndDropScrollInterval(): void {
		if (this.dragAndDropScrollInterval) {
			window.clearInterval(this.dragAndDropScrollInterval);
			this.dragAndDropScrollInterval = -1;
		}

		this.cancelDragAndDropScrollTimeout();
	}

	private cancelDragAndDropScrollTimeout(): void {
		if (this.dragAndDropScrollTimeout) {
			window.clearTimeout(this.dragAndDropScrollTimeout);
			this.dragAndDropScrollTimeout = -1;
		}
	}

	// Util

	private getItemIndexFromEventTarget(target: EventTarget | null): number {
		let element: HTMLElement | null = target as (HTMLElement | null);

		while (element instanceof HTMLElement && element !== this.rowsContainer) {
			const rawIndex = element.getAttribute('data-index');

			if (rawIndex) {
				const index = Number(rawIndex);

				if (!isNaN(index)) {
					return index;
				}
			}

			element = element.parentElement;
		}

		return -1;
	}

	private getRenderRange(renderTop: number, renderHeight: number): IRange {
		return {
			start: this.rangeMap.indexAt(renderTop),
			end: this.rangeMap.indexAfter(renderTop + renderHeight - 1)
		};
	}

	/**
	 * Given a stable rendered state, checks every rendered element whether it needs
	 * to be probed for dynamic height. Adjusts scroll height and top if necessary.
	 */
	private rerender(renderTop: number, renderHeight: number): void {
		const previousRenderRange = this.getRenderRange(renderTop, renderHeight);

		// Let's remember the second element's position, this helps in scrolling up
		// and preserving a linear upwards scroll movement
		let secondElementIndex: number | undefined;
		let secondElementTopDelta: number | undefined;

		if (previousRenderRange.end - previousRenderRange.start > 1) {
			secondElementIndex = previousRenderRange.start + 1;
			secondElementTopDelta = this.elementTop(secondElementIndex) - renderTop;
		}

		let heightDiff = 0;

		while (true) {
			const renderRange = this.getRenderRange(renderTop, renderHeight);

			let didChange = false;

			for (let i = renderRange.start; i < renderRange.end; i++) {
				const diff = this.probeDynamicHeight(i);

				if (diff !== 0) {
					this.rangeMap.splice(i, 1, [this.items[i]]);
				}

				heightDiff += diff;
				didChange = didChange || diff !== 0;
			}

			if (!didChange) {
				if (heightDiff !== 0) {
					this.updateScrollHeight();
				}

				const unrenderRanges = Range.relativeComplement(previousRenderRange, renderRange);

				for (const range of unrenderRanges) {
					for (let i = range.start; i < range.end; i++) {
						if (this.items[i].row) {
							this.removeItemFromDOM(i);
						}
					}
				}

				for (let i = renderRange.start; i < renderRange.end; i++) {
					if (this.items[i].row) {
						this.updateItemInDOM(this.items[i], i);
					}
				}

				if (typeof secondElementIndex === 'number') {
					this.scrollTop = this.elementTop(secondElementIndex) - secondElementTopDelta!;
				}

				return;
			}
		}

	}

	private probeDynamicHeight(index: number): number {
		const item = this.items[index];

		if (!item.hasDynamicHeight || item.renderWidth === this.renderWidth) {
			return 0;
		}

		const size = item.size;
		const renderer = this.renderers.get(item.templateId);
		const row = this.cache.alloc(item.templateId);

		row.domNode!.style.height = '';
		this.rowsContainer.appendChild(row.domNode!);
		renderer.renderElement(item.element, index, row.templateData);
		item.size = row.domNode!.offsetHeight;
		item.renderWidth = this.renderWidth;
		this.rowsContainer.removeChild(row.domNode!);
		this.cache.release(row);

		return item.size - size;
	}

	private getNextToLastElement(ranges: IRange[]): HTMLElement | null {
		const lastRange = ranges[ranges.length - 1];

		if (!lastRange) {
			return null;
		}

		const nextToLastItem = this.items[lastRange.end];

		if (!nextToLastItem) {
			return null;
		}

		if (!nextToLastItem.row) {
			return null;
		}

		return nextToLastItem.row.domNode;
	}

	// Dispose

	dispose() {
		if (this.items) {
			for (const item of this.items) {
				if (item.row) {
					const renderer = this.renderers.get(item.row.templateId);
					renderer.disposeTemplate(item.row.templateData);
				}
			}

			this.items = [];
		}

		if (this.domNode && this.domNode.parentNode) {
			this.domNode.parentNode.removeChild(this.domNode);
		}

		this.disposables = dispose(this.disposables);
	}
}
