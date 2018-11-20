/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { Action, IAction } from 'vs/base/common/actions';
import { illegalArgument } from 'vs/base/common/errors';
import * as arrays from 'vs/base/common/arrays';
import { IDisposable, toDisposable } from 'vs/base/common/lifecycle';
import { IBadge } from 'vs/workbench/services/activity/common/activity';
import { IStorageService, StorageScope } from 'vs/platform/storage/common/storage';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ActionBar, ActionsOrientation, Separator } from 'vs/base/browser/ui/actionbar/actionbar';
import { CompositeActionItem, CompositeOverflowActivityAction, ICompositeActivity, CompositeOverflowActivityActionItem, ActivityAction, ICompositeBar, ICompositeBarColors, DraggedCompositeIdentifier } from 'vs/workbench/browser/parts/compositeBarActions';
import { Dimension, $, addDisposableListener, EventType, EventHelper } from 'vs/base/browser/dom';
import { StandardMouseEvent } from 'vs/base/browser/mouseEvent';
import { IContextMenuService } from 'vs/platform/contextview/browser/contextView';
import { Widget } from 'vs/base/browser/ui/widget';
import { isUndefinedOrNull } from 'vs/base/common/types';
import { LocalSelectionTransfer } from 'vs/workbench/browser/dnd';
import { ITheme } from 'vs/platform/theme/common/themeService';

export interface ICompositeBarOptions {
	icon: boolean;
	storageId: string;
	orientation: ActionsOrientation;
	colors: (theme: ITheme) => ICompositeBarColors;
	compositeSize: number;
	overflowActionSize: number;
	getActivityAction: (compositeId: string) => ActivityAction;
	getCompositePinnedAction: (compositeId: string) => Action;
	getOnCompositeClickAction: (compositeId: string) => Action;
	getContextMenuActions: () => Action[];
	openComposite: (compositeId: string) => Thenable<any>;
	getDefaultCompositeId: () => string;
	hidePart: () => void;
}

export class CompositeBar extends Widget implements ICompositeBar {

	private dimension: Dimension;

	private compositeSwitcherBar: ActionBar;
	private compositeOverflowAction: CompositeOverflowActivityAction;
	private compositeOverflowActionItem: CompositeOverflowActivityActionItem;

	private model: CompositeBarModel;
	private visibleComposites: string[];
	private compositeSizeInBar: Map<string, number>;

	private compositeTransfer: LocalSelectionTransfer<DraggedCompositeIdentifier>;

	constructor(
		private options: ICompositeBarOptions,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IStorageService storageService: IStorageService,
		@IContextMenuService private contextMenuService: IContextMenuService
	) {
		super();

		this.model = new CompositeBarModel(options, storageService);
		this.visibleComposites = [];
		this.compositeSizeInBar = new Map<string, number>();
		this.compositeTransfer = LocalSelectionTransfer.getInstance<DraggedCompositeIdentifier>();
	}

	getComposites(): ICompositeBarItem[] {
		return [...this.model.items];
	}

	getPinnedComposites(): ICompositeBarItem[] {
		return this.model.pinnedItems;
	}

	create(parent: HTMLElement): HTMLElement {
		const actionBarDiv = parent.appendChild($('.composite-bar'));
		this.compositeSwitcherBar = this._register(new ActionBar(actionBarDiv, {
			actionItemProvider: (action: Action) => {
				if (action instanceof CompositeOverflowActivityAction) {
					return this.compositeOverflowActionItem;
				}
				const item = this.model.findItem(action.id);
				return item && this.instantiationService.createInstance(CompositeActionItem, action, item.pinnedAction, () => this.getContextMenuActions(), this.options.colors, this.options.icon, this);
			},
			orientation: this.options.orientation,
			ariaLabel: nls.localize('activityBarAriaLabel', "Active View Switcher"),
			animated: false,
		}));

		// Contextmenu for composites
		this._register(addDisposableListener(parent, EventType.CONTEXT_MENU, e => this.showContextMenu(e)));

		// Allow to drop at the end to move composites to the end
		this._register(addDisposableListener(parent, EventType.DROP, (e: DragEvent) => {
			if (this.compositeTransfer.hasData(DraggedCompositeIdentifier.prototype)) {
				EventHelper.stop(e, true);

				const draggedCompositeId = this.compositeTransfer.getData(DraggedCompositeIdentifier.prototype)[0].id;
				this.compositeTransfer.clearData(DraggedCompositeIdentifier.prototype);

				const targetItem = this.model.visibleItems[this.model.visibleItems.length - 1];
				if (targetItem && targetItem.id !== draggedCompositeId) {
					this.move(draggedCompositeId, targetItem.id);
				}
			}
		}));

		return actionBarDiv;
	}

	layout(dimension: Dimension): void {
		this.dimension = dimension;
		if (dimension.height === 0 || dimension.width === 0) {
			// Do not layout if not visible. Otherwise the size measurment would be computed wrongly
			return;
		}

		if (this.compositeSizeInBar.size === 0) {
			// Compute size of each composite by getting the size from the css renderer
			// Size is later used for overflow computation
			this.computeSizes(this.model.visibleItems);
		}

		this.updateCompositeSwitcher();
	}

	addComposite({ id, name, order }: { id: string; name: string, order: number }): void {
		// Add to the model
		if (this.model.add(id, name, order)) {
			this.computeSizes([this.model.findItem(id)]);
			this.updateCompositeSwitcher();
		}
	}

	removeComposite(id: string): void {

		// If it pinned, unpin it first
		if (this.isPinned(id)) {
			this.unpin(id);
		}

		// Remove from the model
		if (this.model.remove(id)) {
			this.updateCompositeSwitcher();
		}
	}

	hideComposite(id: string): void {
		if (this.model.hide(id)) {
			this.resetActiveComposite(id);
			this.updateCompositeSwitcher();
		}
	}

	activateComposite(id: string): void {
		const previousActiveItem = this.model.activeItem;
		if (this.model.activate(id)) {
			// Update if current composite is neither visible nor pinned
			// or previous active composite is not pinned
			if (this.visibleComposites.indexOf(id) === - 1 || !this.model.activeItem.pinned || (previousActiveItem && !previousActiveItem.pinned)) {
				this.updateCompositeSwitcher();
			}
		}
	}

	deactivateComposite(id: string): void {
		const previousActiveItem = this.model.activeItem;
		if (this.model.deactivate()) {
			if (previousActiveItem && !previousActiveItem.pinned) {
				this.updateCompositeSwitcher();
			}
		}
	}

	showActivity(compositeId: string, badge: IBadge, clazz?: string, priority?: number): IDisposable {
		if (!badge) {
			throw illegalArgument('badge');
		}

		if (typeof priority !== 'number') {
			priority = 0;
		}

		const activity: ICompositeActivity = { badge, clazz, priority };
		this.model.addActivity(compositeId, activity);
		return toDisposable(() => this.model.removeActivity(compositeId, activity));
	}

	pin(compositeId: string, open?: boolean): void {
		if (this.model.setPinned(compositeId, true)) {
			this.updateCompositeSwitcher();

			if (open) {
				this.options.openComposite(compositeId).then(() => this.activateComposite(compositeId)); // Activate after opening
			}
		}
	}

	unpin(compositeId: string): void {
		if (this.model.setPinned(compositeId, false)) {

			this.updateCompositeSwitcher();

			this.resetActiveComposite(compositeId);
		}
	}

	private resetActiveComposite(compositeId: string) {
		const defaultCompositeId = this.options.getDefaultCompositeId();

		// Case: composite is not the active one or the active one is a different one
		// Solv: we do nothing
		if (!this.model.activeItem || this.model.activeItem.id !== compositeId) {
			return;
		}

		// Deactivate itself
		this.deactivateComposite(compositeId);

		// Case: composite is not the default composite and default composite is still showing
		// Solv: we open the default composite
		if (defaultCompositeId !== compositeId && this.isPinned(defaultCompositeId)) {
			this.options.openComposite(defaultCompositeId);
		}

		// Case: we closed the last visible composite
		// Solv: we hide the part
		else if (this.visibleComposites.length === 1) {
			this.options.hidePart();
		}

		// Case: we closed the default composite
		// Solv: we open the next visible composite from top
		else {
			this.options.openComposite(this.visibleComposites.filter(cid => cid !== compositeId)[0]);
		}
	}

	isPinned(compositeId: string): boolean {
		const item = this.model.findItem(compositeId);
		return item && item.pinned;
	}

	move(compositeId: string, toCompositeId: string): void {
		if (this.model.move(compositeId, toCompositeId)) {
			// timeout helps to prevent artifacts from showing up
			setTimeout(() => this.updateCompositeSwitcher(), 0);
		}
	}

	getAction(compositeId): ActivityAction {
		const item = this.model.findItem(compositeId);
		return item && item.activityAction;
	}

	private computeSizes(items: ICompositeBarItem[]): void {
		const size = this.options.compositeSize;
		if (size) {
			items.forEach(composite => this.compositeSizeInBar.set(composite.id, size));
		} else {
			if (this.dimension && this.dimension.height !== 0 && this.dimension.width !== 0) {
				// Compute sizes only if visible. Otherwise the size measurment would be computed wrongly.
				const currentItemsLength = this.compositeSwitcherBar.items.length;
				this.compositeSwitcherBar.push(items.map(composite => composite.activityAction));
				items.map((composite, index) => this.compositeSizeInBar.set(composite.id, this.options.orientation === ActionsOrientation.VERTICAL
					? this.compositeSwitcherBar.getHeight(currentItemsLength + index)
					: this.compositeSwitcherBar.getWidth(currentItemsLength + index)
				));
				items.forEach(() => this.compositeSwitcherBar.pull(this.compositeSwitcherBar.items.length - 1));
			}
		}
	}

	private updateCompositeSwitcher(): void {
		if (!this.compositeSwitcherBar || !this.dimension) {
			return; // We have not been rendered yet so there is nothing to update.
		}

		let compositesToShow = this.model.visibleItems.filter(item =>
			item.pinned
			|| (this.model.activeItem && this.model.activeItem.id === item.id) /* Show the active composite even if it is not pinned */
		).map(item => item.id);

		// Ensure we are not showing more composites than we have height for
		let overflows = false;
		let maxVisible = compositesToShow.length;
		let size = 0;
		const limit = this.options.orientation === ActionsOrientation.VERTICAL ? this.dimension.height : this.dimension.width;
		for (let i = 0; i < compositesToShow.length && size <= limit; i++) {
			size += this.compositeSizeInBar.get(compositesToShow[i]);
			if (size > limit) {
				maxVisible = i;
			}
		}
		overflows = compositesToShow.length > maxVisible;

		if (overflows) {
			size -= this.compositeSizeInBar.get(compositesToShow[maxVisible]);
			compositesToShow = compositesToShow.slice(0, maxVisible);
			size += this.options.overflowActionSize;
		}
		// Check if we need to make extra room for the overflow action
		if (size > limit) {
			size -= this.compositeSizeInBar.get(compositesToShow.pop());
		}

		// We always try show the active composite
		if (this.model.activeItem && compositesToShow.every(compositeId => compositeId !== this.model.activeItem.id)) {
			const removedComposite = compositesToShow.pop();
			size = size - this.compositeSizeInBar.get(removedComposite) + this.compositeSizeInBar.get(this.model.activeItem.id);
			compositesToShow.push(this.model.activeItem.id);
		}

		// The active composite might have bigger size than the removed composite, check for overflow again
		if (size > limit) {
			compositesToShow.length ? compositesToShow.splice(compositesToShow.length - 2, 1) : compositesToShow.pop();
		}

		const visibleCompositesChange = !arrays.equals(compositesToShow, this.visibleComposites);

		// Pull out overflow action if there is a composite change so that we can add it to the end later
		if (this.compositeOverflowAction && visibleCompositesChange) {
			this.compositeSwitcherBar.pull(this.compositeSwitcherBar.length() - 1);

			this.compositeOverflowAction.dispose();
			this.compositeOverflowAction = null;

			this.compositeOverflowActionItem.dispose();
			this.compositeOverflowActionItem = null;
		}

		// Pull out composites that overflow or got hidden
		const compositesToRemove: number[] = [];
		this.visibleComposites.forEach((compositeId, index) => {
			if (compositesToShow.indexOf(compositeId) === -1) {
				compositesToRemove.push(index);
			}
		});
		compositesToRemove.reverse().forEach(index => {
			const actionItem = this.compositeSwitcherBar.items[index];
			this.compositeSwitcherBar.pull(index);
			actionItem.dispose();
			this.visibleComposites.splice(index, 1);
		});

		// Update the positions of the composites
		compositesToShow.forEach((compositeId, newIndex) => {
			const currentIndex = this.visibleComposites.indexOf(compositeId);
			if (newIndex !== currentIndex) {
				if (currentIndex !== -1) {
					const actionItem = this.compositeSwitcherBar.items[currentIndex];
					this.compositeSwitcherBar.pull(currentIndex);
					actionItem.dispose();
					this.visibleComposites.splice(currentIndex, 1);
				}

				this.compositeSwitcherBar.push(this.model.findItem(compositeId).activityAction, { label: true, icon: this.options.icon, index: newIndex });
				this.visibleComposites.splice(newIndex, 0, compositeId);
			}
		});

		// Add overflow action as needed
		if ((visibleCompositesChange && overflows) || this.compositeSwitcherBar.length() === 0) {
			this.compositeOverflowAction = this.instantiationService.createInstance(CompositeOverflowActivityAction, () => this.compositeOverflowActionItem.showMenu());
			this.compositeOverflowActionItem = this.instantiationService.createInstance(
				CompositeOverflowActivityActionItem,
				this.compositeOverflowAction,
				() => this.getOverflowingComposites(),
				() => this.model.activeItem ? this.model.activeItem.id : void 0,
				(compositeId: string) => {
					const item = this.model.findItem(compositeId);
					return item && item.activity[0] && item.activity[0].badge;
				},
				this.options.getOnCompositeClickAction,
				this.options.colors
			);

			this.compositeSwitcherBar.push(this.compositeOverflowAction, { label: false, icon: true });
		}

		// Persist
		this.model.saveState();
	}

	private getOverflowingComposites(): { id: string, name: string }[] {
		let overflowingIds = this.model.visibleItems.filter(item => item.pinned).map(item => item.id);

		// Show the active composite even if it is not pinned
		if (this.model.activeItem && !this.model.activeItem.pinned) {
			overflowingIds.push(this.model.activeItem.id);
		}

		overflowingIds = overflowingIds.filter(compositeId => this.visibleComposites.indexOf(compositeId) === -1);
		return this.model.visibleItems.filter(c => overflowingIds.indexOf(c.id) !== -1);
	}

	private showContextMenu(e: MouseEvent): void {
		EventHelper.stop(e, true);
		const event = new StandardMouseEvent(e);
		this.contextMenuService.showContextMenu({
			getAnchor: () => { return { x: event.posx, y: event.posy }; },
			getActions: () => this.getContextMenuActions()
		});
	}

	private getContextMenuActions(): IAction[] {
		const actions: IAction[] = this.model.visibleItems
			.map(({ id, name, activityAction }) => (<IAction>{
				id,
				label: name || id,
				checked: this.isPinned(id),
				enabled: activityAction.enabled,
				run: () => {
					if (this.isPinned(id)) {
						this.unpin(id);
					} else {
						this.pin(id, true);
					}
				}
			}));
		const otherActions = this.options.getContextMenuActions();
		if (otherActions.length) {
			actions.push(new Separator());
			actions.push(...otherActions);
		}
		return actions;
	}
}

interface ISerializedCompositeBarItem {
	id: string;
	pinned: boolean;
	order: number;
	visible: boolean;
}

interface ICompositeBarItem extends ISerializedCompositeBarItem {
	name: string;
	activityAction: ActivityAction;
	pinnedAction: Action;
	activity: ICompositeActivity[];
}

class CompositeBarModel {

	private readonly options: ICompositeBarOptions;
	readonly items: ICompositeBarItem[];

	activeItem: ICompositeBarItem;

	constructor(
		options: ICompositeBarOptions,
		private storageService: IStorageService,
	) {
		this.options = options;
		this.items = this.loadItemStates();
	}

	get visibleItems(): ICompositeBarItem[] {
		return this.items.filter(item => item.visible);
	}

	get pinnedItems(): ICompositeBarItem[] {
		return this.items.filter(item => item.visible && item.pinned);
	}

	private createCompositeBarItem(id: string, name: string, order: number, pinned: boolean, visible: boolean): ICompositeBarItem {
		const options = this.options;
		return {
			id, name, pinned, order, visible,
			activity: [],
			get activityAction() {
				return options.getActivityAction(id);
			},
			get pinnedAction() {
				return options.getCompositePinnedAction(id);
			}
		};
	}

	add(id: string, name: string, order: number): boolean {
		const item = this.findItem(id);
		if (item) {
			let changed = false;
			item.name = name;
			if (!isUndefinedOrNull(order)) {
				changed = item.order !== order;
				item.order = order;
			}
			if (!item.visible) {
				item.visible = true;
				changed = true;
			}
			return changed;
		} else {
			const item = this.createCompositeBarItem(id, name, order, true, true);
			if (isUndefinedOrNull(order)) {
				this.items.push(item);
			} else {
				let index = 0;
				while (index < this.items.length && this.items[index].order < order) {
					index++;
				}
				this.items.splice(index, 0, item);
			}
			return true;
		}
	}

	remove(id: string): boolean {
		for (let index = 0; index < this.items.length; index++) {
			if (this.items[index].id === id) {
				this.items.splice(index, 1);
				return true;
			}
		}
		return false;
	}

	hide(id: string): boolean {
		for (const item of this.items) {
			if (item.id === id) {
				if (item.visible) {
					item.visible = false;
					return true;
				}
				return false;
			}
		}
		return false;
	}

	move(compositeId: string, toCompositeId: string): boolean {

		const fromIndex = this.findIndex(compositeId);
		const toIndex = this.findIndex(toCompositeId);

		// Make sure both items are known to the model
		if (fromIndex === -1 || toIndex === -1) {
			return false;
		}

		const sourceItem = this.items.splice(fromIndex, 1)[0];
		this.items.splice(toIndex, 0, sourceItem);

		// Make sure a moved composite gets pinned
		sourceItem.pinned = true;

		return true;
	}

	setPinned(id: string, pinned: boolean): boolean {
		for (let index = 0; index < this.items.length; index++) {
			const item = this.items[index];
			if (item.id === id) {
				if (item.pinned !== pinned) {
					item.pinned = pinned;
					return true;
				}
				return false;
			}
		}
		return false;
	}

	addActivity(id: string, activity: ICompositeActivity): boolean {
		const item = this.findItem(id);
		if (item) {
			const stack = item.activity;
			for (let i = 0; i <= stack.length; i++) {
				if (i === stack.length) {
					stack.push(activity);
					break;
				} else if (stack[i].priority <= activity.priority) {
					stack.splice(i, 0, activity);
					break;
				}
			}
			this.updateActivity(id);
			return true;
		}
		return false;
	}

	removeActivity(id: string, activity: ICompositeActivity): boolean {
		const item = this.findItem(id);
		if (item) {
			const index = item.activity.indexOf(activity);
			if (index !== -1) {
				item.activity.splice(index, 1);
				this.updateActivity(id);
				return true;
			}
		}
		return false;
	}

	updateActivity(id: string): void {
		const item = this.findItem(id);
		if (item) {
			if (item.activity.length) {
				const [{ badge, clazz }] = item.activity;
				item.activityAction.setBadge(badge, clazz);
			}
			else {
				item.activityAction.setBadge(undefined);
			}
		}
	}

	activate(id: string): boolean {
		if (!this.activeItem || this.activeItem.id !== id) {
			if (this.activeItem) {
				this.deactivate();
			}
			for (let index = 0; index < this.items.length; index++) {
				const item = this.items[index];
				if (item.id === id) {
					this.activeItem = item;
					this.activeItem.activityAction.activate();
					return true;
				}
			}
		}
		return false;
	}

	deactivate(): boolean {
		if (this.activeItem) {
			this.activeItem.activityAction.deactivate();
			this.activeItem = void 0;
			return true;
		}
		return false;
	}

	findItem(id: string): ICompositeBarItem {
		return this.items.filter(item => item.id === id)[0];
	}

	private findIndex(id: string): number {
		for (let index = 0; index < this.items.length; index++) {
			if (this.items[index].id === id) {
				return index;
			}
		}
		return -1;
	}

	private loadItemStates(): ICompositeBarItem[] {
		const storedStates = <Array<string | ISerializedCompositeBarItem>>JSON.parse(this.storageService.get(this.options.storageId, StorageScope.GLOBAL, '[]'));
		return <ICompositeBarItem[]>storedStates.map(c => {
			const serialized: ISerializedCompositeBarItem = typeof c === 'string' /* migration from pinned states to composites states */ ? { id: c, pinned: true, order: void 0, visible: true } : c;
			return this.createCompositeBarItem(serialized.id, void 0, serialized.order, serialized.pinned, isUndefinedOrNull(serialized.visible) ? true : serialized.visible);
		});
	}

	saveState(): void {
		const serialized = this.items.map(({ id, pinned, order, visible }) => ({ id, pinned, order, visible }));
		this.storageService.store(this.options.storageId, JSON.stringify(serialized), StorageScope.GLOBAL);
	}
}
