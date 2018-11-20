/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from 'vs/base/browser/dom';
import { IMouseEvent } from 'vs/base/browser/mouseEvent';
import { DomScrollableElement } from 'vs/base/browser/ui/scrollbar/scrollableElement';
import { commonPrefixLength } from 'vs/base/common/arrays';
import { Color } from 'vs/base/common/color';
import { Emitter, Event } from 'vs/base/common/event';
import { dispose, IDisposable, combinedDisposable } from 'vs/base/common/lifecycle';
import { ScrollbarVisibility } from 'vs/base/common/scrollable';
import 'vs/css!./breadcrumbsWidget';

export abstract class BreadcrumbsItem {
	dispose(): void { }
	abstract equals(other: BreadcrumbsItem): boolean;
	abstract render(container: HTMLElement): void;
}

export class SimpleBreadcrumbsItem extends BreadcrumbsItem {

	constructor(
		readonly text: string,
		readonly title: string = text
	) {
		super();
	}

	equals(other: this) {
		return other === this || other instanceof SimpleBreadcrumbsItem && other.text === this.text && other.title === this.title;
	}

	render(container: HTMLElement): void {
		let node = document.createElement('div');
		node.title = this.title;
		node.innerText = this.text;
		container.appendChild(node);
	}
}

export interface IBreadcrumbsWidgetStyles {
	breadcrumbsBackground?: Color;
	breadcrumbsForeground?: Color;
	breadcrumbsHoverForeground?: Color;
	breadcrumbsFocusForeground?: Color;
	breadcrumbsFocusAndSelectionForeground?: Color;
}

export interface IBreadcrumbsItemEvent {
	type: 'select' | 'focus';
	item: BreadcrumbsItem;
	node: HTMLElement;
	payload: any;
}

export class BreadcrumbsWidget {

	private readonly _disposables = new Array<IDisposable>();
	private readonly _domNode: HTMLDivElement;
	private readonly _styleElement: HTMLStyleElement;
	private readonly _scrollable: DomScrollableElement;

	private readonly _onDidSelectItem = new Emitter<IBreadcrumbsItemEvent>();
	private readonly _onDidFocusItem = new Emitter<IBreadcrumbsItemEvent>();
	private readonly _onDidChangeFocus = new Emitter<boolean>();

	readonly onDidSelectItem: Event<IBreadcrumbsItemEvent> = this._onDidSelectItem.event;
	readonly onDidFocusItem: Event<IBreadcrumbsItemEvent> = this._onDidFocusItem.event;
	readonly onDidChangeFocus: Event<boolean> = this._onDidChangeFocus.event;

	private readonly _items = new Array<BreadcrumbsItem>();
	private readonly _nodes = new Array<HTMLDivElement>();
	private readonly _freeNodes = new Array<HTMLDivElement>();

	private _focusedItemIdx: number = -1;
	private _selectedItemIdx: number = -1;

	private _pendingLayout: IDisposable;
	private _dimension: dom.Dimension;

	constructor(
		container: HTMLElement
	) {
		this._domNode = document.createElement('div');
		this._domNode.className = 'monaco-breadcrumbs';
		this._domNode.tabIndex = 0;
		this._domNode.setAttribute('role', 'list');
		this._scrollable = new DomScrollableElement(this._domNode, {
			vertical: ScrollbarVisibility.Hidden,
			horizontal: ScrollbarVisibility.Auto,
			horizontalScrollbarSize: 3,
			useShadows: false,
			scrollYToX: true
		});
		this._disposables.push(this._scrollable);
		this._disposables.push(dom.addStandardDisposableListener(this._domNode, 'click', e => this._onClick(e)));
		container.appendChild(this._scrollable.getDomNode());

		this._styleElement = dom.createStyleSheet(this._domNode);

		let focusTracker = dom.trackFocus(this._domNode);
		this._disposables.push(focusTracker);
		this._disposables.push(focusTracker.onDidBlur(_ => this._onDidChangeFocus.fire(false)));
		this._disposables.push(focusTracker.onDidFocus(_ => this._onDidChangeFocus.fire(true)));
	}

	dispose(): void {
		dispose(this._disposables);
		dispose(this._pendingLayout);
		this._onDidSelectItem.dispose();
		this._onDidFocusItem.dispose();
		this._onDidChangeFocus.dispose();
		this._domNode.remove();
		this._disposables.length = 0;
		this._nodes.length = 0;
		this._freeNodes.length = 0;
	}

	layout(dim: dom.Dimension | undefined): void {
		if (dim && dom.Dimension.equals(dim, this._dimension)) {
			return;
		}
		if (this._pendingLayout) {
			this._pendingLayout.dispose();
		}
		if (dim) {
			// only meaure
			this._pendingLayout = this._updateDimensions(dim);
		} else {
			this._pendingLayout = this._updateScrollbar();
		}
	}

	private _updateDimensions(dim: dom.Dimension): IDisposable {
		let disposables: IDisposable[] = [];
		disposables.push(dom.modify(() => {
			this._dimension = dim;
			this._domNode.style.width = `${dim.width}px`;
			this._domNode.style.height = `${dim.height}px`;
			disposables.push(this._updateScrollbar());
		}));
		return combinedDisposable(disposables);
	}

	private _updateScrollbar(): IDisposable {
		return dom.measure(() => {
			dom.measure(() => { // double RAF
				this._scrollable.setRevealOnScroll(false);
				this._scrollable.scanDomNode();
				this._scrollable.setRevealOnScroll(true);
			});
		});
	}

	style(style: IBreadcrumbsWidgetStyles): void {
		let content = '';
		if (style.breadcrumbsBackground) {
			content += `.monaco-breadcrumbs { background-color: ${style.breadcrumbsBackground}}`;
		}
		if (style.breadcrumbsForeground) {
			content += `.monaco-breadcrumbs .monaco-breadcrumb-item { color: ${style.breadcrumbsForeground}}\n`;
		}
		if (style.breadcrumbsFocusForeground) {
			content += `.monaco-breadcrumbs .monaco-breadcrumb-item.focused { color: ${style.breadcrumbsFocusForeground}}\n`;
		}
		if (style.breadcrumbsFocusAndSelectionForeground) {
			content += `.monaco-breadcrumbs .monaco-breadcrumb-item.focused.selected { color: ${style.breadcrumbsFocusAndSelectionForeground}}\n`;
		}
		if (style.breadcrumbsHoverForeground) {
			content += `.monaco-breadcrumbs .monaco-breadcrumb-item:hover:not(.focused):not(.selected) { color: ${style.breadcrumbsHoverForeground}}\n`;
		}
		if (this._styleElement.innerHTML !== content) {
			this._styleElement.innerHTML = content;
		}
	}

	domFocus(): void {
		let idx = this._focusedItemIdx >= 0 ? this._focusedItemIdx : this._items.length - 1;
		if (idx >= 0 && idx < this._items.length) {
			this._focus(idx, undefined);
		} else {
			this._domNode.focus();
		}
	}

	isDOMFocused(): boolean {
		let candidate = document.activeElement;
		while (candidate) {
			if (this._domNode === candidate) {
				return true;
			}
			candidate = candidate.parentElement;
		}
		return false;
	}

	getFocused(): BreadcrumbsItem {
		return this._items[this._focusedItemIdx];
	}

	setFocused(item: BreadcrumbsItem, payload?: any): void {
		this._focus(this._items.indexOf(item), payload);
	}

	focusPrev(payload?: any): any {
		if (this._focusedItemIdx > 0) {
			this._focus(this._focusedItemIdx - 1, payload);
		}
	}

	focusNext(payload?: any): any {
		if (this._focusedItemIdx + 1 < this._nodes.length) {
			this._focus(this._focusedItemIdx + 1, payload);
		}
	}

	private _focus(nth: number, payload: any): void {
		this._focusedItemIdx = -1;
		for (let i = 0; i < this._nodes.length; i++) {
			const node = this._nodes[i];
			if (i !== nth) {
				dom.removeClass(node, 'focused');
			} else {
				this._focusedItemIdx = i;
				dom.addClass(node, 'focused');
				node.focus();
			}
		}
		this._reveal(this._focusedItemIdx, true);
		this._onDidFocusItem.fire({ type: 'focus', item: this._items[this._focusedItemIdx], node: this._nodes[this._focusedItemIdx], payload });
	}

	reveal(item: BreadcrumbsItem): void {
		let idx = this._items.indexOf(item);
		if (idx >= 0) {
			this._reveal(idx, false);
		}
	}

	private _reveal(nth: number, minimal: boolean): void {
		const node = this._nodes[nth];
		if (node) {
			const { width } = this._scrollable.getScrollDimensions();
			const { scrollLeft } = this._scrollable.getScrollPosition();
			if (!minimal || node.offsetLeft > scrollLeft + width || node.offsetLeft < scrollLeft) {
				this._scrollable.setRevealOnScroll(false);
				this._scrollable.setScrollPosition({ scrollLeft: node.offsetLeft });
				this._scrollable.setRevealOnScroll(true);
			}
		}
	}

	getSelection(): BreadcrumbsItem {
		return this._items[this._selectedItemIdx];
	}

	setSelection(item: BreadcrumbsItem, payload?: any): void {
		this._select(this._items.indexOf(item), payload);
	}

	private _select(nth: number, payload: any): void {
		this._selectedItemIdx = -1;
		for (let i = 0; i < this._nodes.length; i++) {
			const node = this._nodes[i];
			if (i !== nth) {
				dom.removeClass(node, 'selected');
			} else {
				this._selectedItemIdx = i;
				dom.addClass(node, 'selected');
			}
		}
		this._onDidSelectItem.fire({ type: 'select', item: this._items[this._selectedItemIdx], node: this._nodes[this._selectedItemIdx], payload });
	}

	getItems(): ReadonlyArray<BreadcrumbsItem> {
		return this._items;
	}

	setItems(items: BreadcrumbsItem[]): void {
		let prefix: number | undefined;
		let removed: BreadcrumbsItem[] = [];
		try {
			prefix = commonPrefixLength(this._items, items, (a, b) => a.equals(b));
			removed = this._items.splice(prefix, this._items.length - prefix, ...items.slice(prefix));
			this._render(prefix);
			dispose(removed);
			this._focus(-1, undefined);
		} catch (e) {
			let newError = new Error(`BreadcrumbsItem#setItems: newItems: ${items.length}, prefix: ${prefix}, removed: ${removed.length}`);
			newError.name = e.name;
			newError.stack = e.stack;
			throw newError;
		}
	}

	private _render(start: number): void {
		for (; start < this._items.length && start < this._nodes.length; start++) {
			let item = this._items[start];
			let node = this._nodes[start];
			this._renderItem(item, node);
		}
		// case a: more nodes -> remove them
		while (start < this._nodes.length) {
			const free = this._nodes.pop();
			if (free) {
				this._freeNodes.push(free);
				free.remove();
			}
		}

		// case b: more items -> render them
		for (; start < this._items.length; start++) {
			let item = this._items[start];
			let node = this._freeNodes.length > 0 ? this._freeNodes.pop() : document.createElement('div');
			if (node) {
				this._renderItem(item, node);
				this._domNode.appendChild(node);
				this._nodes.push(node);
			}
		}
		this.layout(undefined);
	}

	private _renderItem(item: BreadcrumbsItem, container: HTMLDivElement): void {
		dom.clearNode(container);
		container.className = '';
		item.render(container);
		container.tabIndex = -1;
		container.setAttribute('role', 'listitem');
		dom.addClass(container, 'monaco-breadcrumb-item');
	}

	private _onClick(event: IMouseEvent): void {
		for (let el: HTMLElement | null = event.target; el; el = el.parentElement) {
			let idx = this._nodes.indexOf(el as any);
			if (idx >= 0) {
				this._focus(idx, event);
				this._select(idx, event);
				break;
			}
		}
	}
}
