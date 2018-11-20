/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { SplitView, Orientation, ISplitViewStyles, IView as ISplitViewView } from 'vs/base/browser/ui/splitview/splitview';
import { $ } from 'vs/base/browser/dom';
import { Event, mapEvent } from 'vs/base/common/event';
import { IView } from 'vs/base/browser/ui/grid/gridview';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { Color } from 'vs/base/common/color';

export interface CenteredViewState {
	leftMarginRatio: number;
	rightMarginRatio: number;
}

const GOLDEN_RATIO = {
	leftMarginRatio: 0.1909,
	rightMarginRatio: 0.1909
};

function createEmptyView(background: Color): ISplitViewView {
	const element = $('.centered-layout-margin');
	element.style.height = '100%';
	element.style.backgroundColor = background.toString();

	return {
		element,
		layout: () => undefined,
		minimumSize: 60,
		maximumSize: Number.POSITIVE_INFINITY,
		onDidChange: Event.None
	};
}

function toSplitViewView(view: IView, getHeight: () => number): ISplitViewView {
	return {
		element: view.element,
		get maximumSize() { return view.maximumWidth; },
		get minimumSize() { return view.minimumWidth; },
		onDidChange: mapEvent(view.onDidChange, e => e && e.width),
		layout: size => view.layout(size, getHeight())
	};
}

export interface ICenteredViewStyles extends ISplitViewStyles {
	background: Color;
}

export class CenteredViewLayout {

	private splitView?: SplitView;
	private width: number = 0;
	private height: number = 0;
	private style: ICenteredViewStyles;
	private didLayout = false;
	private emptyViews: ISplitViewView[] | undefined;
	private splitViewDisposables: IDisposable[] = [];

	constructor(private container: HTMLElement, private view: IView, public readonly state: CenteredViewState = { leftMarginRatio: GOLDEN_RATIO.leftMarginRatio, rightMarginRatio: GOLDEN_RATIO.rightMarginRatio }) {
		this.container.appendChild(this.view.element);
		// Make sure to hide the split view overflow like sashes #52892
		this.container.style.overflow = 'hidden';
	}

	get minimumWidth(): number { return this.splitView ? this.splitView.minimumSize : this.view.minimumWidth; }
	get maximumWidth(): number { return this.splitView ? this.splitView.maximumSize : this.view.maximumWidth; }
	get minimumHeight(): number { return this.view.minimumHeight; }
	get maximumHeight(): number { return this.view.maximumHeight; }

	layout(width: number, height: number): void {
		this.width = width;
		this.height = height;
		if (this.splitView) {
			this.splitView.layout(width);
			if (!this.didLayout) {
				this.resizeMargins();
			}
		} else {
			this.view.layout(width, height);
		}
		this.didLayout = true;
	}

	private resizeMargins(): void {
		if (!this.splitView) {
			return;
		}
		this.splitView.resizeView(0, this.state.leftMarginRatio * this.width);
		this.splitView.resizeView(2, this.state.rightMarginRatio * this.width);
	}

	isActive(): boolean {
		return !!this.splitView;
	}

	styles(style: ICenteredViewStyles): void {
		this.style = style;
		if (this.splitView && this.emptyViews) {
			this.splitView.style(this.style);
			this.emptyViews[0].element.style.backgroundColor = this.style.background.toString();
			this.emptyViews[1].element.style.backgroundColor = this.style.background.toString();
		}
	}

	activate(active: boolean): void {
		if (active === this.isActive()) {
			return;
		}

		if (active) {
			this.container.removeChild(this.view.element);
			this.splitView = new SplitView(this.container, {
				inverseAltBehavior: true,
				orientation: Orientation.HORIZONTAL,
				styles: this.style
			});

			this.splitViewDisposables.push(this.splitView.onDidSashChange(() => {
				if (this.splitView) {
					this.state.leftMarginRatio = this.splitView.getViewSize(0) / this.width;
					this.state.rightMarginRatio = this.splitView.getViewSize(2) / this.width;
				}
			}));
			this.splitViewDisposables.push(this.splitView.onDidSashReset(() => {
				this.state.leftMarginRatio = GOLDEN_RATIO.leftMarginRatio;
				this.state.rightMarginRatio = GOLDEN_RATIO.rightMarginRatio;
				this.resizeMargins();
			}));

			this.splitView.layout(this.width);
			this.splitView.addView(toSplitViewView(this.view, () => this.height), 0);
			this.emptyViews = [createEmptyView(this.style.background), createEmptyView(this.style.background)];
			this.splitView.addView(this.emptyViews[0], this.state.leftMarginRatio * this.width, 0);
			this.splitView.addView(this.emptyViews[1], this.state.rightMarginRatio * this.width, 2);
		} else {
			if (this.splitView) {
				this.container.removeChild(this.splitView.el);
			}
			this.splitViewDisposables = dispose(this.splitViewDisposables);
			if (this.splitView) {
				this.splitView.dispose();
			}
			this.splitView = undefined;
			this.emptyViews = undefined;
			this.container.appendChild(this.view.element);
		}
	}

	isDefault(state: CenteredViewState): boolean {
		return state.leftMarginRatio === GOLDEN_RATIO.leftMarginRatio && state.rightMarginRatio === GOLDEN_RATIO.rightMarginRatio;
	}

	dispose(): void {
		this.splitViewDisposables = dispose(this.splitViewDisposables);

		if (this.splitView) {
			this.splitView.dispose();
			this.splitView = undefined;
		}
	}
}
