/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./media/notabstitlecontrol';
import { toResource, Verbosity, IEditorInput } from 'vs/workbench/common/editor';
import { TitleControl, IToolbarActions } from 'vs/workbench/browser/parts/editor/titleControl';
import { ResourceLabel } from 'vs/workbench/browser/labels';
import { TAB_ACTIVE_FOREGROUND, TAB_UNFOCUSED_ACTIVE_FOREGROUND } from 'vs/workbench/common/theme';
import { EventType as TouchEventType, GestureEvent, Gesture } from 'vs/base/browser/touch';
import { addDisposableListener, EventType, addClass, EventHelper, removeClass, toggleClass } from 'vs/base/browser/dom';
import { IEditorPartOptions, EDITOR_TITLE_HEIGHT } from 'vs/workbench/browser/parts/editor/editor';
import { IAction } from 'vs/base/common/actions';
import { CLOSE_EDITOR_COMMAND_ID } from 'vs/workbench/browser/parts/editor/editorCommands';
import { Color } from 'vs/base/common/color';

interface IRenderedEditorLabel {
	editor: IEditorInput;
	pinned: boolean;
}

export class NoTabsTitleControl extends TitleControl {
	private titleContainer: HTMLElement;
	private editorLabel: ResourceLabel;
	private activeLabel: IRenderedEditorLabel = Object.create(null);

	protected create(parent: HTMLElement): void {
		this.titleContainer = parent;
		this.titleContainer.draggable = true;

		//Container listeners
		this.registerContainerListeners();

		// Gesture Support
		Gesture.addTarget(this.titleContainer);

		const labelContainer = document.createElement('div');
		addClass(labelContainer, 'label-container');
		this.titleContainer.appendChild(labelContainer);

		// Editor Label
		this.editorLabel = this._register(this.instantiationService.createInstance(ResourceLabel, labelContainer, void 0));
		this._register(this.editorLabel.onClick(e => this.onTitleLabelClick(e)));

		// Breadcrumbs
		this.createBreadcrumbsControl(labelContainer, { showFileIcons: false, showSymbolIcons: true, showDecorationColors: false, breadcrumbsBackground: () => Color.transparent });
		toggleClass(this.titleContainer, 'breadcrumbs', Boolean(this.breadcrumbsControl));
		this.toDispose.push({ dispose: () => removeClass(this.titleContainer, 'breadcrumbs') }); // import to remove because the container is a shared dom node

		// Right Actions Container
		const actionsContainer = document.createElement('div');
		addClass(actionsContainer, 'title-actions');
		this.titleContainer.appendChild(actionsContainer);

		// Editor actions toolbar
		this.createEditorActionsToolBar(actionsContainer);
	}

	private registerContainerListeners(): void {

		// Group dragging
		this.enableGroupDragging(this.titleContainer);

		// Pin on double click
		this._register(addDisposableListener(this.titleContainer, EventType.DBLCLICK, (e: MouseEvent) => this.onTitleDoubleClick(e)));

		// Detect mouse click
		this._register(addDisposableListener(this.titleContainer, EventType.MOUSE_UP, (e: MouseEvent) => this.onTitleClick(e)));

		// Detect touch
		this._register(addDisposableListener(this.titleContainer, TouchEventType.Tap, (e: GestureEvent) => this.onTitleClick(e)));

		// Context Menu
		this._register(addDisposableListener(this.titleContainer, EventType.CONTEXT_MENU, (e: Event) => this.onContextMenu(this.group.activeEditor, e, this.titleContainer)));
		this._register(addDisposableListener(this.titleContainer, TouchEventType.Contextmenu, (e: Event) => this.onContextMenu(this.group.activeEditor, e, this.titleContainer)));
	}

	private onTitleLabelClick(e: MouseEvent): void {
		EventHelper.stop(e, false);

		// delayed to let the onTitleClick() come first which can cause a focus change which can close quick open
		setTimeout(() => this.quickOpenService.show());
	}

	private onTitleDoubleClick(e: MouseEvent): void {
		EventHelper.stop(e);

		this.group.pinEditor();
	}

	private onTitleClick(e: MouseEvent | GestureEvent): void {

		// Close editor on middle mouse click
		if (e instanceof MouseEvent && e.button === 1 /* Middle Button */) {
			EventHelper.stop(e, true /* for https://github.com/Microsoft/vscode/issues/56715 */);

			this.group.closeEditor(this.group.activeEditor);
		}
	}

	getPreferredHeight(): number {
		return EDITOR_TITLE_HEIGHT;
	}

	openEditor(editor: IEditorInput): void {
		const activeEditorChanged = this.ifActiveEditorChanged(() => this.redraw());
		if (!activeEditorChanged) {
			this.ifActiveEditorPropertiesChanged(() => this.redraw());
		}
	}

	closeEditor(editor: IEditorInput): void {
		this.ifActiveEditorChanged(() => this.redraw());
	}

	closeEditors(editors: IEditorInput[]): void {
		this.ifActiveEditorChanged(() => this.redraw());
	}

	closeAllEditors(): void {
		this.redraw();
	}

	moveEditor(editor: IEditorInput, fromIndex: number, targetIndex: number): void {
		this.ifActiveEditorChanged(() => this.redraw());
	}

	pinEditor(editor: IEditorInput): void {
		this.ifEditorIsActive(editor, () => this.redraw());
	}

	setActive(isActive: boolean): void {
		this.redraw();
	}

	updateEditorLabel(editor: IEditorInput): void {
		this.ifEditorIsActive(editor, () => this.redraw());
	}

	updateEditorDirty(editor: IEditorInput): void {
		this.ifEditorIsActive(editor, () => {
			if (editor.isDirty()) {
				addClass(this.titleContainer, 'dirty');
			} else {
				removeClass(this.titleContainer, 'dirty');
			}
		});
	}

	updateOptions(oldOptions: IEditorPartOptions, newOptions: IEditorPartOptions): void {
		if (oldOptions.labelFormat !== newOptions.labelFormat) {
			this.redraw();
		}
	}

	updateStyles(): void {
		this.redraw();
	}

	protected handleBreadcrumbsEnablementChange(): void {
		toggleClass(this.titleContainer, 'breadcrumbs', Boolean(this.breadcrumbsControl));
		this.redraw();
	}

	private ifActiveEditorChanged(fn: () => void): boolean {
		if (
			!this.activeLabel.editor && this.group.activeEditor || 	// active editor changed from null => editor
			this.activeLabel.editor && !this.group.activeEditor || 	// active editor changed from editor => null
			!this.group.isActive(this.activeLabel.editor)			// active editor changed from editorA => editorB
		) {
			fn();

			return true;
		}

		return false;
	}

	private ifActiveEditorPropertiesChanged(fn: () => void): void {
		if (!this.activeLabel.editor || !this.group.activeEditor) {
			return; // need an active editor to check for properties changed
		}

		if (this.activeLabel.pinned !== this.group.isPinned(this.group.activeEditor)) {
			fn(); // only run if pinned state has changed
		}
	}


	private ifEditorIsActive(editor: IEditorInput, fn: () => void): void {
		if (this.group.isActive(editor)) {
			fn();  // only run if editor is current active
		}
	}

	private redraw(): void {
		const editor = this.group.activeEditor;

		const isEditorPinned = this.group.isPinned(this.group.activeEditor);
		const isGroupActive = this.accessor.activeGroup === this.group;

		this.activeLabel = { editor, pinned: isEditorPinned };

		// Update Breadcrumbs
		if (this.breadcrumbsControl) {
			if (isGroupActive) {
				this.breadcrumbsControl.update();
				toggleClass(this.breadcrumbsControl.domNode, 'preview', !isEditorPinned);
			} else {
				this.breadcrumbsControl.hide();
			}
		}

		// Clear if there is no editor
		if (!editor) {
			removeClass(this.titleContainer, 'dirty');
			this.editorLabel.clear();
			this.clearEditorActionsToolbar();
		}

		// Otherwise render it
		else {

			// Dirty state
			this.updateEditorDirty(editor);

			// Editor Label
			const resource = toResource(editor, { supportSideBySide: true });
			const name = editor.getName() || '';

			const { labelFormat } = this.accessor.partOptions;
			let description: string;
			if (this.breadcrumbsControl && !this.breadcrumbsControl.isHidden()) {
				description = ''; // hide description when showing breadcrumbs
			} else if (labelFormat === 'default' && !isGroupActive) {
				description = ''; // hide description when group is not active and style is 'default'
			} else {
				description = editor.getDescription(this.getVerbosity(labelFormat)) || '';
			}

			let title = editor.getTitle(Verbosity.LONG);
			if (description === title) {
				title = ''; // dont repeat what is already shown
			}

			this.editorLabel.setLabel({ name, description, resource }, { title, italic: !isEditorPinned, extraClasses: ['no-tabs', 'title-label'] });
			if (isGroupActive) {
				this.editorLabel.element.style.color = this.getColor(TAB_ACTIVE_FOREGROUND);
			} else {
				this.editorLabel.element.style.color = this.getColor(TAB_UNFOCUSED_ACTIVE_FOREGROUND);
			}

			// Update Editor Actions Toolbar
			this.updateEditorActionsToolbar();
		}
	}

	private getVerbosity(style: string): Verbosity {
		switch (style) {
			case 'short': return Verbosity.SHORT;
			case 'long': return Verbosity.LONG;
			default: return Verbosity.MEDIUM;
		}
	}

	protected prepareEditorActions(editorActions: IToolbarActions): { primaryEditorActions: IAction[], secondaryEditorActions: IAction[] } {
		const isGroupActive = this.accessor.activeGroup === this.group;

		// Group active: show all actions
		if (isGroupActive) {
			return super.prepareEditorActions(editorActions);
		}

		// Group inactive: only show close action
		return { primaryEditorActions: editorActions.primary.filter(action => action.id === CLOSE_EDITOR_COMMAND_ID), secondaryEditorActions: [] };
	}
}
