/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Widget } from 'vs/base/browser/ui/widget';
import { IOverlayWidget, ICodeEditor, IOverlayWidgetPosition, OverlayWidgetPositionPreference } from 'vs/editor/browser/editorBrowser';
import { Event, Emitter } from 'vs/base/common/event';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { $, append } from 'vs/base/browser/dom';
import { attachStylerCallback } from 'vs/platform/theme/common/styler';
import { buttonBackground, buttonForeground, editorBackground, editorForeground, contrastBorder } from 'vs/platform/theme/common/colorRegistry';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IWindowService } from 'vs/platform/windows/common/windows';
import { IWorkspaceContextService, WorkbenchState } from 'vs/platform/workspace/common/workspace';
import { Schemas } from 'vs/base/common/network';
import { WORKSPACE_EXTENSION } from 'vs/platform/workspaces/common/workspaces';
import { extname } from 'vs/base/common/paths';
import { Disposable, dispose } from 'vs/base/common/lifecycle';
import { localize } from 'vs/nls';
import { IEditorContribution } from 'vs/editor/common/editorCommon';
import { isEqual } from 'vs/base/common/resources';

export class FloatingClickWidget extends Widget implements IOverlayWidget {

	private _onClick: Emitter<void> = this._register(new Emitter<void>());
	get onClick(): Event<void> { return this._onClick.event; }

	private _domNode: HTMLElement;

	constructor(
		private editor: ICodeEditor,
		private label: string,
		keyBindingAction: string,
		@IKeybindingService keybindingService: IKeybindingService,
		@IThemeService private themeService: IThemeService
	) {
		super();

		if (keyBindingAction) {
			const keybinding = keybindingService.lookupKeybinding(keyBindingAction);
			if (keybinding) {
				this.label += ` (${keybinding.getLabel()})`;
			}
		}
	}

	getId(): string {
		return 'editor.overlayWidget.floatingClickWidget';
	}

	getDomNode(): HTMLElement {
		return this._domNode;
	}

	getPosition(): IOverlayWidgetPosition {
		return {
			preference: OverlayWidgetPositionPreference.BOTTOM_RIGHT_CORNER
		};
	}

	render() {
		this._domNode = $('.floating-click-widget');

		this._register(attachStylerCallback(this.themeService, { buttonBackground, buttonForeground, editorBackground, editorForeground, contrastBorder }, colors => {
			const backgroundColor = colors.buttonBackground ? colors.buttonBackground : colors.editorBackground;
			if (backgroundColor) {
				this._domNode.style.backgroundColor = backgroundColor.toString();
			}

			const foregroundColor = colors.buttonForeground ? colors.buttonForeground : colors.editorForeground;
			if (foregroundColor) {
				this._domNode.style.color = foregroundColor.toString();
			}

			const borderColor = colors.contrastBorder ? colors.contrastBorder.toString() : null;
			this._domNode.style.borderWidth = borderColor ? '1px' : null;
			this._domNode.style.borderStyle = borderColor ? 'solid' : null;
			this._domNode.style.borderColor = borderColor;
		}));

		append(this._domNode, $('')).textContent = this.label;

		this.onclick(this._domNode, e => this._onClick.fire());

		this.editor.addOverlayWidget(this);
	}

	dispose(): void {
		this.editor.removeOverlayWidget(this);

		super.dispose();
	}
}

export class OpenWorkspaceButtonContribution extends Disposable implements IEditorContribution {

	static get(editor: ICodeEditor): OpenWorkspaceButtonContribution {
		return editor.getContribution<OpenWorkspaceButtonContribution>(OpenWorkspaceButtonContribution.ID);
	}

	private static readonly ID = 'editor.contrib.openWorkspaceButton';

	private openWorkspaceButton: FloatingClickWidget;

	constructor(
		private editor: ICodeEditor,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IWindowService private windowService: IWindowService,
		@IWorkspaceContextService private contextService: IWorkspaceContextService
	) {
		super();

		this.update();
		this.registerListeners();
	}

	private registerListeners(): void {
		this._register(this.editor.onDidChangeModel(e => this.update()));
	}

	getId(): string {
		return OpenWorkspaceButtonContribution.ID;
	}

	private update(): void {
		if (!this.shouldShowButton(this.editor)) {
			this.disposeOpenWorkspaceWidgetRenderer();
			return;
		}

		this.createOpenWorkspaceWidgetRenderer();
	}

	private shouldShowButton(editor: ICodeEditor): boolean {
		const model = editor.getModel();
		if (!model) {
			return false; // we need a model
		}

		if (model.uri.scheme !== Schemas.file || extname(model.uri.fsPath) !== `.${WORKSPACE_EXTENSION}`) {
			return false; // we need a local workspace file
		}

		if (this.contextService.getWorkbenchState() === WorkbenchState.WORKSPACE) {
			const workspaceConfiguration = this.contextService.getWorkspace().configuration;
			if (workspaceConfiguration && isEqual(workspaceConfiguration, model.uri)) {
				return false; // already inside workspace
			}
		}

		return true;
	}

	private createOpenWorkspaceWidgetRenderer(): void {
		if (!this.openWorkspaceButton) {
			this.openWorkspaceButton = this.instantiationService.createInstance(FloatingClickWidget, this.editor, localize('openWorkspace', "Open Workspace"), null);
			this._register(this.openWorkspaceButton.onClick(() => {
				const model = this.editor.getModel();
				if (model) {
					this.windowService.openWindow([model.uri]);
				}
			}));

			this.openWorkspaceButton.render();
		}
	}

	private disposeOpenWorkspaceWidgetRenderer(): void {
		this.openWorkspaceButton = dispose(this.openWorkspaceButton);
	}

	dispose(): void {
		this.disposeOpenWorkspaceWidgetRenderer();

		super.dispose();
	}
}