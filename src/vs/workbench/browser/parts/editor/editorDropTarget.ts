/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./media/editordroptarget';
import { LocalSelectionTransfer, DraggedEditorIdentifier, ResourcesDropHandler, DraggedEditorGroupIdentifier, DragAndDropObserver } from 'vs/workbench/browser/dnd';
import { addDisposableListener, EventType, EventHelper, isAncestor, toggleClass, addClass, removeClass } from 'vs/base/browser/dom';
import { IEditorGroupsAccessor, EDITOR_TITLE_HEIGHT, IEditorGroupView, getActiveTextEditorOptions } from 'vs/workbench/browser/parts/editor/editor';
import { EDITOR_DRAG_AND_DROP_BACKGROUND, Themable } from 'vs/workbench/common/theme';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { activeContrastBorder } from 'vs/platform/theme/common/colorRegistry';
import { IEditorIdentifier, EditorInput, EditorOptions } from 'vs/workbench/common/editor';
import { isMacintosh } from 'vs/base/common/platform';
import { GroupDirection, MergeGroupMode } from 'vs/workbench/services/group/common/editorGroupsService';
import { toDisposable } from 'vs/base/common/lifecycle';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { RunOnceScheduler } from 'vs/base/common/async';

interface IDropOperation {
	splitDirection?: GroupDirection;
}

class DropOverlay extends Themable {

	private static OVERLAY_ID = 'monaco-workbench-editor-drop-overlay';

	private container: HTMLElement;
	private overlay: HTMLElement;

	private currentDropOperation: IDropOperation;
	private _disposed: boolean;

	private cleanupOverlayScheduler: RunOnceScheduler;

	private readonly editorTransfer = LocalSelectionTransfer.getInstance<DraggedEditorIdentifier>();
	private readonly groupTransfer = LocalSelectionTransfer.getInstance<DraggedEditorGroupIdentifier>();

	constructor(
		private accessor: IEditorGroupsAccessor,
		private groupView: IEditorGroupView,
		themeService: IThemeService,
		private instantiationService: IInstantiationService
	) {
		super(themeService);

		this.cleanupOverlayScheduler = this._register(new RunOnceScheduler(() => this.dispose(), 300));

		this.create();
	}

	get disposed(): boolean {
		return this._disposed;
	}

	private create(): void {
		const overlayOffsetHeight = this.getOverlayOffsetHeight();

		// Container
		this.container = document.createElement('div');
		this.container.id = DropOverlay.OVERLAY_ID;
		this.container.style.top = `${overlayOffsetHeight}px`;

		// Parent
		this.groupView.element.appendChild(this.container);
		addClass(this.groupView.element, 'dragged-over');
		this._register(toDisposable(() => {
			this.groupView.element.removeChild(this.container);
			removeClass(this.groupView.element, 'dragged-over');
		}));

		// Overlay
		this.overlay = document.createElement('div');
		addClass(this.overlay, 'editor-group-overlay-indicator');
		this.container.appendChild(this.overlay);

		// Overlay Event Handling
		this.registerListeners();

		// Styles
		this.updateStyles();
	}

	protected updateStyles(): void {

		// Overlay drop background
		this.overlay.style.backgroundColor = this.getColor(EDITOR_DRAG_AND_DROP_BACKGROUND);

		// Overlay contrast border (if any)
		const activeContrastBorderColor = this.getColor(activeContrastBorder);
		this.overlay.style.outlineColor = activeContrastBorderColor;
		this.overlay.style.outlineOffset = activeContrastBorderColor ? '-2px' : null;
		this.overlay.style.outlineStyle = activeContrastBorderColor ? 'dashed' : null;
		this.overlay.style.outlineWidth = activeContrastBorderColor ? '2px' : null;
	}

	private registerListeners(): void {
		this._register(new DragAndDropObserver(this.container, {
			onDragEnter: e => void 0,
			onDragOver: e => {
				const isDraggingGroup = this.groupTransfer.hasData(DraggedEditorGroupIdentifier.prototype);
				const isDraggingEditor = this.editorTransfer.hasData(DraggedEditorIdentifier.prototype);

				// Update the dropEffect to "copy" if there is no local data to be dragged because
				// in that case we can only copy the data into and not move it from its source
				if (!isDraggingEditor && !isDraggingGroup) {
					e.dataTransfer.dropEffect = 'copy';
				}

				// Find out if operation is valid
				const isCopy = isDraggingGroup ? this.isCopyOperation(e) : isDraggingEditor ? this.isCopyOperation(e, this.editorTransfer.getData(DraggedEditorIdentifier.prototype)[0].identifier) : true;
				if (!isCopy) {
					const sourceGroupView = this.findSourceGroupView();
					if (sourceGroupView === this.groupView) {
						if (isDraggingGroup || (isDraggingEditor && sourceGroupView.count < 2)) {
							this.hideOverlay();
							return; // do not allow to drop group/editor on itself if this results in an empty group
						}
					}
				}

				// Position overlay
				this.positionOverlay(e.offsetX, e.offsetY, isDraggingGroup);

				// Make sure to stop any running cleanup scheduler to remove the overlay
				if (this.cleanupOverlayScheduler.isScheduled()) {
					this.cleanupOverlayScheduler.cancel();
				}
			},

			onDragLeave: e => this.dispose(),
			onDragEnd: e => this.dispose(),

			onDrop: e => {
				EventHelper.stop(e, true);

				// Dispose overlay
				this.dispose();

				// Handle drop if we have a valid operation
				if (this.currentDropOperation) {
					this.handleDrop(e, this.currentDropOperation.splitDirection);
				}
			}
		}));

		this._register(addDisposableListener(this.container, EventType.MOUSE_OVER, () => {
			// Under some circumstances we have seen reports where the drop overlay is not being
			// cleaned up and as such the editor area remains under the overlay so that you cannot
			// type into the editor anymore. This seems related to using VMs and DND via host and
			// guest OS, though some users also saw it without VMs.
			// To protect against this issue we always destroy the overlay as soon as we detect a
			// mouse event over it. The delay is used to guarantee we are not interfering with the
			// actual DROP event that can also trigger a mouse over event.
			if (!this.cleanupOverlayScheduler.isScheduled()) {
				this.cleanupOverlayScheduler.schedule();
			}
		}));
	}

	private findSourceGroupView(): IEditorGroupView {

		// Check for group transfer
		if (this.groupTransfer.hasData(DraggedEditorGroupIdentifier.prototype)) {
			return this.accessor.getGroup(this.groupTransfer.getData(DraggedEditorGroupIdentifier.prototype)[0].identifier);
		}

		// Check for editor transfer
		else if (this.editorTransfer.hasData(DraggedEditorIdentifier.prototype)) {
			return this.accessor.getGroup(this.editorTransfer.getData(DraggedEditorIdentifier.prototype)[0].identifier.groupId);
		}

		return void 0;
	}

	private handleDrop(event: DragEvent, splitDirection?: GroupDirection): void {

		// Determine target group
		const ensureTargetGroup = () => {
			let targetGroup: IEditorGroupView;
			if (typeof splitDirection === 'number') {
				targetGroup = this.accessor.addGroup(this.groupView, splitDirection);
			} else {
				targetGroup = this.groupView;
			}

			return targetGroup;
		};

		// Check for group transfer
		if (this.groupTransfer.hasData(DraggedEditorGroupIdentifier.prototype)) {
			const draggedEditorGroup = this.groupTransfer.getData(DraggedEditorGroupIdentifier.prototype)[0].identifier;

			// Return if the drop is a no-op
			const sourceGroup = this.accessor.getGroup(draggedEditorGroup);
			if (typeof splitDirection !== 'number' && sourceGroup === this.groupView) {
				return;
			}

			// Split to new group
			let targetGroup: IEditorGroupView;
			if (typeof splitDirection === 'number') {
				if (this.isCopyOperation(event)) {
					targetGroup = this.accessor.copyGroup(sourceGroup, this.groupView, splitDirection);
				} else {
					targetGroup = this.accessor.moveGroup(sourceGroup, this.groupView, splitDirection);
				}
			}

			// Merge into existing group
			else {
				if (this.isCopyOperation(event)) {
					targetGroup = this.accessor.mergeGroup(sourceGroup, this.groupView, { mode: MergeGroupMode.COPY_EDITORS });
				} else {
					targetGroup = this.accessor.mergeGroup(sourceGroup, this.groupView);
				}
			}

			this.accessor.activateGroup(targetGroup);
			this.groupTransfer.clearData(DraggedEditorGroupIdentifier.prototype);
		}

		// Check for editor transfer
		else if (this.editorTransfer.hasData(DraggedEditorIdentifier.prototype)) {
			const draggedEditor = this.editorTransfer.getData(DraggedEditorIdentifier.prototype)[0].identifier;
			const targetGroup = ensureTargetGroup();

			// Return if the drop is a no-op
			const sourceGroup = this.accessor.getGroup(draggedEditor.groupId);
			if (sourceGroup === targetGroup) {
				return;
			}

			// Open in target group
			const options = getActiveTextEditorOptions(sourceGroup, draggedEditor.editor, EditorOptions.create({ pinned: true }));
			targetGroup.openEditor(draggedEditor.editor, options);

			// Ensure target has focus
			targetGroup.focus();

			// Close in source group unless we copy
			const copyEditor = this.isCopyOperation(event, draggedEditor);
			if (!copyEditor) {
				sourceGroup.closeEditor(draggedEditor.editor);
			}

			this.editorTransfer.clearData(DraggedEditorIdentifier.prototype);
		}

		// Check for URI transfer
		else {
			const dropHandler = this.instantiationService.createInstance(ResourcesDropHandler, { allowWorkspaceOpen: true /* open workspace instead of file if dropped */ });
			dropHandler.handleDrop(event, () => ensureTargetGroup(), targetGroup => targetGroup.focus());
		}
	}

	private isCopyOperation(e: DragEvent, draggedEditor?: IEditorIdentifier): boolean {
		if (draggedEditor && !(draggedEditor.editor as EditorInput).supportsSplitEditor()) {
			return false;
		}

		return (e.ctrlKey && !isMacintosh) || (e.altKey && isMacintosh);
	}

	private positionOverlay(mousePosX: number, mousePosY: number, isDraggingGroup: boolean): void {
		const preferSplitVertically = this.accessor.partOptions.openSideBySideDirection === 'right';

		const editorControlWidth = this.groupView.element.clientWidth;
		const editorControlHeight = this.groupView.element.clientHeight - this.getOverlayOffsetHeight();

		let edgeWidthThresholdFactor: number;
		if (isDraggingGroup) {
			edgeWidthThresholdFactor = preferSplitVertically ? 0.3 : 0.1; // give larger threshold when dragging group depending on preferred split direction
		} else {
			edgeWidthThresholdFactor = 0.1; // 10% threshold to split if dragging editors
		}

		let edgeHeightThresholdFactor: number;
		if (isDraggingGroup) {
			edgeHeightThresholdFactor = preferSplitVertically ? 0.1 : 0.3; // give larger threshold when dragging group depending on preferred split direction
		} else {
			edgeHeightThresholdFactor = 0.1; // 10% threshold to split if dragging editors
		}

		const edgeWidthThreshold = editorControlWidth * edgeWidthThresholdFactor;
		const edgeHeightThreshold = editorControlHeight * edgeHeightThresholdFactor;

		const splitWidthThreshold = editorControlWidth / 3;		// offer to split left/right at 33%
		const splitHeightThreshold = editorControlHeight / 3;	// offer to split up/down at 33%

		// Enable to debug the drop threshold square
		// let child = this.overlay.children.item(0) as HTMLElement || this.overlay.appendChild(document.createElement('div'));
		// child.style.backgroundColor = 'red';
		// child.style.position = 'absolute';
		// child.style.width = (groupViewWidth - (2 * edgeWidthThreshold)) + 'px';
		// child.style.height = (groupViewHeight - (2 * edgeHeightThreshold)) + 'px';
		// child.style.left = edgeWidthThreshold + 'px';
		// child.style.top = edgeHeightThreshold + 'px';

		// No split if mouse is above certain threshold in the center of the view
		let splitDirection: GroupDirection;
		if (
			mousePosX > edgeWidthThreshold && mousePosX < editorControlWidth - edgeWidthThreshold &&
			mousePosY > edgeHeightThreshold && mousePosY < editorControlHeight - edgeHeightThreshold
		) {
			splitDirection = void 0;
		}

		// Offer to split otherwise
		else {

			// User prefers to split vertically: offer a larger hitzone
			// for this direction like so:
			// ----------------------------------------------
			// |		|		SPLIT UP		|			|
			// | SPLIT 	|-----------------------|	SPLIT	|
			// |		|		  MERGE			|			|
			// | LEFT	|-----------------------|	RIGHT	|
			// |		|		SPLIT DOWN		|			|
			// ----------------------------------------------
			if (preferSplitVertically) {
				if (mousePosX < splitWidthThreshold) {
					splitDirection = GroupDirection.LEFT;
				} else if (mousePosX > splitWidthThreshold * 2) {
					splitDirection = GroupDirection.RIGHT;
				} else if (mousePosY < editorControlHeight / 2) {
					splitDirection = GroupDirection.UP;
				} else {
					splitDirection = GroupDirection.DOWN;
				}
			}

			// User prefers to split horizontally: offer a larger hitzone
			// for this direction like so:
			// ----------------------------------------------
			// |				SPLIT UP					|
			// |--------------------------------------------|
			// |  SPLIT LEFT  |	   MERGE	|  SPLIT RIGHT  |
			// |--------------------------------------------|
			// |				SPLIT DOWN					|
			// ----------------------------------------------
			else {
				if (mousePosY < splitHeightThreshold) {
					splitDirection = GroupDirection.UP;
				} else if (mousePosY > splitHeightThreshold * 2) {
					splitDirection = GroupDirection.DOWN;
				} else if (mousePosX < editorControlWidth / 2) {
					splitDirection = GroupDirection.LEFT;
				} else {
					splitDirection = GroupDirection.RIGHT;
				}
			}
		}

		// Draw overlay based on split direction
		switch (splitDirection) {
			case GroupDirection.UP:
				this.doPositionOverlay({ top: '0', left: '0', width: '100%', height: '50%' });
				break;
			case GroupDirection.DOWN:
				this.doPositionOverlay({ top: '50%', left: '0', width: '100%', height: '50%' });
				break;
			case GroupDirection.LEFT:
				this.doPositionOverlay({ top: '0', left: '0', width: '50%', height: '100%' });
				break;
			case GroupDirection.RIGHT:
				this.doPositionOverlay({ top: '0', left: '50%', width: '50%', height: '100%' });
				break;
			default:
				this.doPositionOverlay({ top: '0', left: '0', width: '100%', height: '100%' });
		}

		// Make sure the overlay is visible now
		this.overlay.style.opacity = '1';

		// Enable transition after a timeout to prevent initial animation
		setTimeout(() => addClass(this.overlay, 'overlay-move-transition'), 0);

		// Remember as current split direction
		this.currentDropOperation = { splitDirection };
	}

	private doPositionOverlay(options: { top: string, left: string, width: string, height: string }): void {

		// Container
		const offsetHeight = this.getOverlayOffsetHeight();
		if (offsetHeight) {
			this.container.style.height = `calc(100% - ${offsetHeight}px)`;
		} else {
			this.container.style.height = '100%';
		}

		// Overlay
		this.overlay.style.top = options.top;
		this.overlay.style.left = options.left;
		this.overlay.style.width = options.width;
		this.overlay.style.height = options.height;
	}

	private getOverlayOffsetHeight(): number {
		if (!this.groupView.isEmpty() && this.accessor.partOptions.showTabs) {
			return EDITOR_TITLE_HEIGHT; // show overlay below title if group shows tabs
		}

		return 0;
	}

	private hideOverlay(): void {

		// Reset overlay
		this.doPositionOverlay({ top: '0', left: '0', width: '100%', height: '100%' });
		this.overlay.style.opacity = '0';
		removeClass(this.overlay, 'overlay-move-transition');

		// Reset current operation
		this.currentDropOperation = void 0;
	}

	contains(element: HTMLElement): boolean {
		return element === this.container || element === this.overlay;
	}

	dispose(): void {
		super.dispose();

		this._disposed = true;
	}
}

export class EditorDropTarget extends Themable {

	private _overlay: DropOverlay;

	private counter = 0;

	private readonly editorTransfer = LocalSelectionTransfer.getInstance<DraggedEditorIdentifier>();
	private readonly groupTransfer = LocalSelectionTransfer.getInstance<DraggedEditorGroupIdentifier>();

	constructor(
		private accessor: IEditorGroupsAccessor,
		private container: HTMLElement,
		@IThemeService themeService: IThemeService,
		@IInstantiationService private instantiationService: IInstantiationService
	) {
		super(themeService);

		this.registerListeners();
	}

	private get overlay(): DropOverlay {
		if (this._overlay && !this._overlay.disposed) {
			return this._overlay;
		}

		return void 0;
	}

	private registerListeners(): void {
		this._register(addDisposableListener(this.container, EventType.DRAG_ENTER, e => this.onDragEnter(e)));
		this._register(addDisposableListener(this.container, EventType.DRAG_LEAVE, () => this.onDragLeave()));
		[this.container, window].forEach(node => this._register(addDisposableListener(node as HTMLElement, EventType.DRAG_END, () => this.onDragEnd())));
	}

	private onDragEnter(event: DragEvent): void {
		this.counter++;

		// Validate transfer
		if (
			!this.editorTransfer.hasData(DraggedEditorIdentifier.prototype) &&
			!this.groupTransfer.hasData(DraggedEditorGroupIdentifier.prototype) &&
			!event.dataTransfer.types.length // see https://github.com/Microsoft/vscode/issues/25789
		) {
			event.dataTransfer.dropEffect = 'none';
			return; // unsupported transfer
		}

		// Signal DND start
		this.updateContainer(true);

		const target = event.target as HTMLElement;
		if (target) {

			// Somehow we managed to move the mouse quickly out of the current overlay, so destroy it
			if (this.overlay && !this.overlay.contains(target)) {
				this.disposeOverlay();
			}

			// Create overlay over target
			if (!this.overlay) {
				const targetGroupView = this.findTargetGroupView(target);
				if (targetGroupView) {
					this._overlay = new DropOverlay(this.accessor, targetGroupView, this.themeService, this.instantiationService);
				}
			}
		}
	}

	private onDragLeave(): void {
		this.counter--;

		if (this.counter === 0) {
			this.updateContainer(false);
		}
	}

	private onDragEnd(): void {
		this.counter = 0;

		this.updateContainer(false);
		this.disposeOverlay();
	}

	private findTargetGroupView(child: HTMLElement): IEditorGroupView {
		const groups = this.accessor.groups;
		for (let i = 0; i < groups.length; i++) {
			const groupView = groups[i];

			if (isAncestor(child, groupView.element)) {
				return groupView;
			}
		}

		return void 0;
	}

	private updateContainer(isDraggedOver: boolean): void {
		toggleClass(this.container, 'dragged-over', isDraggedOver);
	}

	dispose(): void {
		super.dispose();

		this.disposeOverlay();
	}

	private disposeOverlay(): void {
		if (this.overlay) {
			this.overlay.dispose();
			this._overlay = void 0;
		}
	}
}
