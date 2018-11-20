/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./panelview';
import { IDisposable, dispose, combinedDisposable, Disposable } from 'vs/base/common/lifecycle';
import { Event, Emitter, chain, filterEvent } from 'vs/base/common/event';
import { domEvent } from 'vs/base/browser/event';
import { StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { KeyCode } from 'vs/base/common/keyCodes';
import { $, append, addClass, removeClass, toggleClass, trackFocus, scheduleAtNextAnimationFrame } from 'vs/base/browser/dom';
import { firstIndex } from 'vs/base/common/arrays';
import { Color, RGBA } from 'vs/base/common/color';
import { SplitView, IView } from './splitview';

export interface IPanelOptions {
	ariaHeaderLabel?: string;
	minimumBodySize?: number;
	maximumBodySize?: number;
	expanded?: boolean;
}

export interface IPanelStyles {
	dropBackground?: Color;
	headerForeground?: Color;
	headerBackground?: Color;
	headerBorder?: Color;
}

/**
 * A Panel is a structured SplitView view.
 *
 * WARNING: You must call `render()` after you contruct it.
 * It can't be done automatically at the end of the ctor
 * because of the order of property initialization in TypeScript.
 * Subclasses wouldn't be able to set own properties
 * before the `render()` call, thus forbiding their use.
 */
export abstract class Panel implements IView {

	private static readonly HEADER_SIZE = 22;

	readonly element: HTMLElement;

	protected _expanded: boolean;
	protected disposables: IDisposable[] = [];

	private expandedSize: number | undefined = undefined;
	private _headerVisible = true;
	private _minimumBodySize: number;
	private _maximumBodySize: number;
	private ariaHeaderLabel: string;
	private styles: IPanelStyles = {};

	private header: HTMLElement;

	private _onDidChange = new Emitter<number | undefined>();
	readonly onDidChange: Event<number | undefined> = this._onDidChange.event;

	get draggableElement(): HTMLElement {
		return this.header;
	}

	get dropTargetElement(): HTMLElement {
		return this.element;
	}

	private _dropBackground: Color | undefined;
	get dropBackground(): Color | undefined {
		return this._dropBackground;
	}

	get minimumBodySize(): number {
		return this._minimumBodySize;
	}

	set minimumBodySize(size: number) {
		this._minimumBodySize = size;
		this._onDidChange.fire();
	}

	get maximumBodySize(): number {
		return this._maximumBodySize;
	}

	set maximumBodySize(size: number) {
		this._maximumBodySize = size;
		this._onDidChange.fire();
	}

	private get headerSize(): number {
		return this.headerVisible ? Panel.HEADER_SIZE : 0;
	}

	get minimumSize(): number {
		const headerSize = this.headerSize;
		const expanded = !this.headerVisible || this.isExpanded();
		const minimumBodySize = expanded ? this._minimumBodySize : 0;

		return headerSize + minimumBodySize;
	}

	get maximumSize(): number {
		const headerSize = this.headerSize;
		const expanded = !this.headerVisible || this.isExpanded();
		const maximumBodySize = expanded ? this._maximumBodySize : 0;

		return headerSize + maximumBodySize;
	}

	constructor(options: IPanelOptions = {}) {
		this._expanded = typeof options.expanded === 'undefined' ? true : !!options.expanded;
		this.ariaHeaderLabel = options.ariaHeaderLabel || '';
		this._minimumBodySize = typeof options.minimumBodySize === 'number' ? options.minimumBodySize : 120;
		this._maximumBodySize = typeof options.maximumBodySize === 'number' ? options.maximumBodySize : Number.POSITIVE_INFINITY;

		this.element = $('.panel');
	}

	isExpanded(): boolean {
		return this._expanded;
	}

	setExpanded(expanded: boolean): void {
		if (this._expanded === !!expanded) {
			return;
		}

		this._expanded = !!expanded;
		this.updateHeader();
		this._onDidChange.fire(expanded ? this.expandedSize : undefined);
	}

	get headerVisible(): boolean {
		return this._headerVisible;
	}

	set headerVisible(visible: boolean) {
		if (this._headerVisible === !!visible) {
			return;
		}

		this._headerVisible = !!visible;
		this.updateHeader();
		this._onDidChange.fire();
	}

	render(): void {
		this.header = $('.panel-header');
		append(this.element, this.header);
		this.header.setAttribute('tabindex', '0');
		this.header.setAttribute('role', 'toolbar');
		this.header.setAttribute('aria-label', this.ariaHeaderLabel);
		this.renderHeader(this.header);

		const focusTracker = trackFocus(this.header);
		focusTracker.onDidFocus(() => addClass(this.header, 'focused'));
		focusTracker.onDidBlur(() => removeClass(this.header, 'focused'));

		this.updateHeader();

		const onHeaderKeyDown = chain(domEvent(this.header, 'keydown'))
			.map(e => new StandardKeyboardEvent(e));

		onHeaderKeyDown.filter(e => e.keyCode === KeyCode.Enter || e.keyCode === KeyCode.Space)
			.event(() => this.setExpanded(!this.isExpanded()), null, this.disposables);

		onHeaderKeyDown.filter(e => e.keyCode === KeyCode.LeftArrow)
			.event(() => this.setExpanded(false), null, this.disposables);

		onHeaderKeyDown.filter(e => e.keyCode === KeyCode.RightArrow)
			.event(() => this.setExpanded(true), null, this.disposables);

		domEvent(this.header, 'click')
			(() => this.setExpanded(!this.isExpanded()), null, this.disposables);

		// TODO@Joao move this down to panelview
		// onHeaderKeyDown.filter(e => e.keyCode === KeyCode.UpArrow)
		// 	.event(focusPrevious, this, this.disposables);

		// onHeaderKeyDown.filter(e => e.keyCode === KeyCode.DownArrow)
		// 	.event(focusNext, this, this.disposables);

		const body = append(this.element, $('.panel-body'));
		this.renderBody(body);
	}

	layout(size: number): void {
		const headerSize = this.headerVisible ? Panel.HEADER_SIZE : 0;

		if (this.isExpanded()) {
			this.layoutBody(size - headerSize);
			this.expandedSize = size;
		}
	}

	style(styles: IPanelStyles): void {
		this.styles = styles;

		if (!this.header) {
			return;
		}

		this.updateHeader();
	}

	protected updateHeader(): void {
		const expanded = !this.headerVisible || this.isExpanded();

		this.header.style.height = `${this.headerSize}px`;
		this.header.style.lineHeight = `${this.headerSize}px`;
		toggleClass(this.header, 'hidden', !this.headerVisible);
		toggleClass(this.header, 'expanded', expanded);
		this.header.setAttribute('aria-expanded', String(expanded));

		this.header.style.color = this.styles.headerForeground ? this.styles.headerForeground.toString() : null;
		this.header.style.backgroundColor = this.styles.headerBackground ? this.styles.headerBackground.toString() : null;
		this.header.style.borderTop = this.styles.headerBorder ? `1px solid ${this.styles.headerBorder}` : null;
		this._dropBackground = this.styles.dropBackground;
	}

	protected abstract renderHeader(container: HTMLElement): void;
	protected abstract renderBody(container: HTMLElement): void;
	protected abstract layoutBody(size: number): void;

	dispose(): void {
		this.disposables = dispose(this.disposables);

		this._onDidChange.dispose();
	}
}

interface IDndContext {
	draggable: PanelDraggable | null;
}

class PanelDraggable extends Disposable {

	private static readonly DefaultDragOverBackgroundColor = new Color(new RGBA(128, 128, 128, 0.5));

	private dragOverCounter = 0; // see https://github.com/Microsoft/vscode/issues/14470

	private _onDidDrop = this._register(new Emitter<{ from: Panel, to: Panel }>());
	readonly onDidDrop = this._onDidDrop.event;

	constructor(private panel: Panel, private dnd: IPanelDndController, private context: IDndContext) {
		super();

		panel.draggableElement.draggable = true;
		this._register(domEvent(panel.draggableElement, 'dragstart')(this.onDragStart, this));
		this._register(domEvent(panel.dropTargetElement, 'dragenter')(this.onDragEnter, this));
		this._register(domEvent(panel.dropTargetElement, 'dragleave')(this.onDragLeave, this));
		this._register(domEvent(panel.dropTargetElement, 'dragend')(this.onDragEnd, this));
		this._register(domEvent(panel.dropTargetElement, 'drop')(this.onDrop, this));
	}

	private onDragStart(e: DragEvent): void {
		if (!this.dnd.canDrag(this.panel) || !e.dataTransfer) {
			e.preventDefault();
			e.stopPropagation();
			return;
		}

		e.dataTransfer.effectAllowed = 'move';

		const dragImage = append(document.body, $('.monaco-panel-drag-image', {}, this.panel.draggableElement.textContent || ''));
		e.dataTransfer.setDragImage(dragImage, -10, -10);
		setTimeout(() => document.body.removeChild(dragImage), 0);

		this.context.draggable = this;
	}

	private onDragEnter(e: DragEvent): void {
		if (!this.context.draggable || this.context.draggable === this) {
			return;
		}

		if (!this.dnd.canDrop(this.context.draggable.panel, this.panel)) {
			return;
		}

		this.dragOverCounter++;
		this.render();
	}

	private onDragLeave(e: DragEvent): void {
		if (!this.context.draggable || this.context.draggable === this) {
			return;
		}

		if (!this.dnd.canDrop(this.context.draggable.panel, this.panel)) {
			return;
		}

		this.dragOverCounter--;

		if (this.dragOverCounter === 0) {
			this.render();
		}
	}

	private onDragEnd(e: DragEvent): void {
		if (!this.context.draggable) {
			return;
		}

		this.dragOverCounter = 0;
		this.render();
		this.context.draggable = null;
	}

	private onDrop(e: DragEvent): void {
		if (!this.context.draggable) {
			return;
		}

		this.dragOverCounter = 0;
		this.render();

		if (this.dnd.canDrop(this.context.draggable.panel, this.panel) && this.context.draggable !== this) {
			this._onDidDrop.fire({ from: this.context.draggable.panel, to: this.panel });
		}

		this.context.draggable = null;
	}

	private render(): void {
		let backgroundColor: string | null = null;

		if (this.dragOverCounter > 0) {
			backgroundColor = (this.panel.dropBackground || PanelDraggable.DefaultDragOverBackgroundColor).toString();
		}

		this.panel.dropTargetElement.style.backgroundColor = backgroundColor;
	}
}

export interface IPanelDndController {
	canDrag(panel: Panel): boolean;
	canDrop(panel: Panel, overPanel: Panel): boolean;
}

export class DefaultPanelDndController implements IPanelDndController {

	canDrag(panel: Panel): boolean {
		return true;
	}

	canDrop(panel: Panel, overPanel: Panel): boolean {
		return true;
	}
}

export interface IPanelViewOptions {
	dnd?: IPanelDndController;
}

interface IPanelItem {
	panel: Panel;
	disposable: IDisposable;
}

export class PanelView extends Disposable {

	private dnd: IPanelDndController | undefined;
	private dndContext: IDndContext = { draggable: null };
	private el: HTMLElement;
	private panelItems: IPanelItem[] = [];
	private splitview: SplitView;
	private animationTimer: number | null = null;

	private _onDidDrop = this._register(new Emitter<{ from: Panel, to: Panel }>());
	readonly onDidDrop: Event<{ from: Panel, to: Panel }> = this._onDidDrop.event;

	readonly onDidSashChange: Event<number>;

	constructor(container: HTMLElement, options: IPanelViewOptions = {}) {
		super();

		this.dnd = options.dnd;
		this.el = append(container, $('.monaco-panel-view'));
		this.splitview = this._register(new SplitView(this.el));
		this.onDidSashChange = this.splitview.onDidSashChange;
	}

	addPanel(panel: Panel, size: number, index = this.splitview.length): void {
		const disposables: IDisposable[] = [];

		// https://github.com/Microsoft/vscode/issues/59950
		let shouldAnimate = false;
		disposables.push(scheduleAtNextAnimationFrame(() => shouldAnimate = true));

		filterEvent(panel.onDidChange, () => shouldAnimate)
			(this.setupAnimation, this, disposables);

		const panelItem = { panel, disposable: combinedDisposable(disposables) };
		this.panelItems.splice(index, 0, panelItem);
		this.splitview.addView(panel, size, index);

		if (this.dnd) {
			const draggable = new PanelDraggable(panel, this.dnd, this.dndContext);
			disposables.push(draggable);
			draggable.onDidDrop(this._onDidDrop.fire, this._onDidDrop, disposables);
		}
	}

	removePanel(panel: Panel): void {
		const index = firstIndex(this.panelItems, item => item.panel === panel);

		if (index === -1) {
			return;
		}

		this.splitview.removeView(index);
		const panelItem = this.panelItems.splice(index, 1)[0];
		panelItem.disposable.dispose();
	}

	movePanel(from: Panel, to: Panel): void {
		const fromIndex = firstIndex(this.panelItems, item => item.panel === from);
		const toIndex = firstIndex(this.panelItems, item => item.panel === to);

		if (fromIndex === -1 || toIndex === -1) {
			return;
		}

		const [panelItem] = this.panelItems.splice(fromIndex, 1);
		this.panelItems.splice(toIndex, 0, panelItem);

		this.splitview.moveView(fromIndex, toIndex);
	}

	resizePanel(panel: Panel, size: number): void {
		const index = firstIndex(this.panelItems, item => item.panel === panel);

		if (index === -1) {
			return;
		}

		this.splitview.resizeView(index, size);
	}

	getPanelSize(panel: Panel): number {
		const index = firstIndex(this.panelItems, item => item.panel === panel);

		if (index === -1) {
			return -1;
		}

		return this.splitview.getViewSize(index);
	}

	layout(size: number): void {
		this.splitview.layout(size);
	}

	private setupAnimation(): void {
		if (typeof this.animationTimer === 'number') {
			window.clearTimeout(this.animationTimer);
		}

		addClass(this.el, 'animated');

		this.animationTimer = window.setTimeout(() => {
			this.animationTimer = null;
			removeClass(this.el, 'animated');
		}, 200);
	}

	dispose(): void {
		super.dispose();

		this.panelItems.forEach(i => i.disposable.dispose());
	}
}
