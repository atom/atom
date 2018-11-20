/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./accessibility';
import * as nls from 'vs/nls';
import * as dom from 'vs/base/browser/dom';
import { FastDomNode, createFastDomNode } from 'vs/base/browser/fastDomNode';
import { renderFormattedText } from 'vs/base/browser/htmlContentRenderer';
import { alert } from 'vs/base/browser/ui/aria/aria';
import { Widget } from 'vs/base/browser/ui/widget';
import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { Disposable } from 'vs/base/common/lifecycle';
import * as platform from 'vs/base/common/platform';
import * as strings from 'vs/base/common/strings';
import { URI } from 'vs/base/common/uri';
import { ICodeEditor, IOverlayWidget, IOverlayWidgetPosition } from 'vs/editor/browser/editorBrowser';
import { EditorAction, EditorCommand, registerEditorAction, registerEditorCommand, registerEditorContribution } from 'vs/editor/browser/editorExtensions';
import * as editorOptions from 'vs/editor/common/config/editorOptions';
import { IEditorContribution } from 'vs/editor/common/editorCommon';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { ToggleTabFocusModeAction } from 'vs/editor/contrib/toggleTabFocusMode/toggleTabFocusMode';
import { ConfigurationTarget, IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { IContextKey, IContextKeyService, RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { IInstantiationService, ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { IOpenerService } from 'vs/platform/opener/common/opener';
import { contrastBorder, editorWidgetBackground, widgetShadow } from 'vs/platform/theme/common/colorRegistry';
import { registerThemingParticipant } from 'vs/platform/theme/common/themeService';

const CONTEXT_ACCESSIBILITY_WIDGET_VISIBLE = new RawContextKey<boolean>('accessibilityHelpWidgetVisible', false);

class AccessibilityHelpController extends Disposable implements IEditorContribution {

	private static readonly ID = 'editor.contrib.accessibilityHelpController';

	public static get(editor: ICodeEditor): AccessibilityHelpController {
		return editor.getContribution<AccessibilityHelpController>(AccessibilityHelpController.ID);
	}

	private _editor: ICodeEditor;
	private _widget: AccessibilityHelpWidget;

	constructor(
		editor: ICodeEditor,
		@IInstantiationService instantiationService: IInstantiationService
	) {
		super();

		this._editor = editor;
		this._widget = this._register(instantiationService.createInstance(AccessibilityHelpWidget, this._editor));
	}

	public getId(): string {
		return AccessibilityHelpController.ID;
	}

	public show(): void {
		this._widget.show();
	}

	public hide(): void {
		this._widget.hide();
	}
}

class AccessibilityHelpWidget extends Widget implements IOverlayWidget {

	private static readonly ID = 'editor.contrib.accessibilityHelpWidget';
	private static readonly WIDTH = 500;
	private static readonly HEIGHT = 300;

	private _editor: ICodeEditor;
	private _domNode: FastDomNode<HTMLElement>;
	private _contentDomNode: FastDomNode<HTMLElement>;
	private _isVisible: boolean;
	private _isVisibleKey: IContextKey<boolean>;

	constructor(
		editor: ICodeEditor,
		@IContextKeyService private readonly _contextKeyService: IContextKeyService,
		@IKeybindingService private readonly _keybindingService: IKeybindingService,
		@IConfigurationService private readonly _configurationService: IConfigurationService,
		@IOpenerService private readonly _openerService: IOpenerService
	) {
		super();

		this._editor = editor;
		this._isVisibleKey = CONTEXT_ACCESSIBILITY_WIDGET_VISIBLE.bindTo(this._contextKeyService);

		this._domNode = createFastDomNode(document.createElement('div'));
		this._domNode.setClassName('accessibilityHelpWidget');
		this._domNode.setWidth(AccessibilityHelpWidget.WIDTH);
		this._domNode.setHeight(AccessibilityHelpWidget.HEIGHT);
		this._domNode.setDisplay('none');
		this._domNode.setAttribute('role', 'dialog');
		this._domNode.setAttribute('aria-hidden', 'true');

		this._contentDomNode = createFastDomNode(document.createElement('div'));
		this._contentDomNode.setAttribute('role', 'document');
		this._domNode.appendChild(this._contentDomNode);

		this._isVisible = false;

		this._register(this._editor.onDidLayoutChange(() => {
			if (this._isVisible) {
				this._layout();
			}
		}));

		// Intentionally not configurable!
		this._register(dom.addStandardDisposableListener(this._contentDomNode.domNode, 'keydown', (e) => {
			if (!this._isVisible) {
				return;
			}

			if (e.equals(KeyMod.CtrlCmd | KeyCode.KEY_E)) {
				alert(nls.localize('emergencyConfOn', "Now changing the setting `editor.accessibilitySupport` to 'on'."));

				this._configurationService.updateValue('editor.accessibilitySupport', 'on', ConfigurationTarget.USER);

				e.preventDefault();
				e.stopPropagation();
			}

			if (e.equals(KeyMod.CtrlCmd | KeyCode.KEY_H)) {
				alert(nls.localize('openingDocs', "Now opening the VS Code Accessibility documentation page."));

				this._openerService.open(URI.parse('https://go.microsoft.com/fwlink/?linkid=851010'));

				e.preventDefault();
				e.stopPropagation();
			}
		}));

		this.onblur(this._contentDomNode.domNode, () => {
			this.hide();
		});

		this._editor.addOverlayWidget(this);
	}

	public dispose(): void {
		this._editor.removeOverlayWidget(this);
		super.dispose();
	}

	public getId(): string {
		return AccessibilityHelpWidget.ID;
	}

	public getDomNode(): HTMLElement {
		return this._domNode.domNode;
	}

	public getPosition(): IOverlayWidgetPosition {
		return {
			preference: null
		};
	}

	public show(): void {
		if (this._isVisible) {
			return;
		}
		this._isVisible = true;
		this._isVisibleKey.set(true);
		this._layout();
		this._domNode.setDisplay('block');
		this._domNode.setAttribute('aria-hidden', 'false');
		this._contentDomNode.domNode.tabIndex = 0;
		this._buildContent();
		this._contentDomNode.domNode.focus();
	}

	private _descriptionForCommand(commandId: string, msg: string, noKbMsg: string): string {
		let kb = this._keybindingService.lookupKeybinding(commandId);
		if (kb) {
			return strings.format(msg, kb.getAriaLabel());
		}
		return strings.format(noKbMsg, commandId);
	}

	private _buildContent() {
		let opts = this._editor.getConfiguration();
		let text = nls.localize('introMsg', "Thank you for trying out VS Code's accessibility options.");

		text += '\n\n' + nls.localize('status', "Status:");

		const configuredValue = this._configurationService.getValue<editorOptions.IEditorOptions>('editor').accessibilitySupport;
		const actualValue = opts.accessibilitySupport;

		const emergencyTurnOnMessage = (
			platform.isMacintosh
				? nls.localize('changeConfigToOnMac', "To configure the editor to be permanently optimized for usage with a Screen Reader press Command+E now.")
				: nls.localize('changeConfigToOnWinLinux', "To configure the editor to be permanently optimized for usage with a Screen Reader press Control+E now.")
		);

		switch (configuredValue) {
			case 'auto':
				switch (actualValue) {
					case platform.AccessibilitySupport.Unknown:
						// Should never happen in VS Code
						text += '\n\n - ' + nls.localize('auto_unknown', "The editor is configured to use platform APIs to detect when a Screen Reader is attached, but the current runtime does not support this.");
						break;
					case platform.AccessibilitySupport.Enabled:
						text += '\n\n - ' + nls.localize('auto_on', "The editor has automatically detected a Screen Reader is attached.");
						break;
					case platform.AccessibilitySupport.Disabled:
						text += '\n\n - ' + nls.localize('auto_off', "The editor is configured to automatically detect when a Screen Reader is attached, which is not the case at this time.");
						text += ' ' + emergencyTurnOnMessage;
						break;
				}
				break;
			case 'on':
				text += '\n\n - ' + nls.localize('configuredOn', "The editor is configured to be permanently optimized for usage with a Screen Reader - you can change this by editing the setting `editor.accessibilitySupport`.");
				break;
			case 'off':
				text += '\n\n - ' + nls.localize('configuredOff', "The editor is configured to never be optimized for usage with a Screen Reader.");
				text += ' ' + emergencyTurnOnMessage;
				break;
		}

		const NLS_TAB_FOCUS_MODE_ON = nls.localize('tabFocusModeOnMsg', "Pressing Tab in the current editor will move focus to the next focusable element. Toggle this behavior by pressing {0}.");
		const NLS_TAB_FOCUS_MODE_ON_NO_KB = nls.localize('tabFocusModeOnMsgNoKb', "Pressing Tab in the current editor will move focus to the next focusable element. The command {0} is currently not triggerable by a keybinding.");
		const NLS_TAB_FOCUS_MODE_OFF = nls.localize('tabFocusModeOffMsg', "Pressing Tab in the current editor will insert the tab character. Toggle this behavior by pressing {0}.");
		const NLS_TAB_FOCUS_MODE_OFF_NO_KB = nls.localize('tabFocusModeOffMsgNoKb', "Pressing Tab in the current editor will insert the tab character. The command {0} is currently not triggerable by a keybinding.");

		if (opts.tabFocusMode) {
			text += '\n\n - ' + this._descriptionForCommand(ToggleTabFocusModeAction.ID, NLS_TAB_FOCUS_MODE_ON, NLS_TAB_FOCUS_MODE_ON_NO_KB);
		} else {
			text += '\n\n - ' + this._descriptionForCommand(ToggleTabFocusModeAction.ID, NLS_TAB_FOCUS_MODE_OFF, NLS_TAB_FOCUS_MODE_OFF_NO_KB);
		}

		const openDocMessage = (
			platform.isMacintosh
				? nls.localize('openDocMac', "Press Command+H now to open a browser window with more VS Code information related to Accessibility.")
				: nls.localize('openDocWinLinux', "Press Control+H now to open a browser window with more VS Code information related to Accessibility.")
		);

		text += '\n\n' + openDocMessage;

		text += '\n\n' + nls.localize('outroMsg', "You can dismiss this tooltip and return to the editor by pressing Escape or Shift+Escape.");

		this._contentDomNode.domNode.appendChild(renderFormattedText(text));
		// Per https://www.w3.org/TR/wai-aria/roles#document, Authors SHOULD provide a title or label for documents
		this._contentDomNode.domNode.setAttribute('aria-label', text);
	}

	public hide(): void {
		if (!this._isVisible) {
			return;
		}
		this._isVisible = false;
		this._isVisibleKey.reset();
		this._domNode.setDisplay('none');
		this._domNode.setAttribute('aria-hidden', 'true');
		this._contentDomNode.domNode.tabIndex = -1;
		dom.clearNode(this._contentDomNode.domNode);

		this._editor.focus();
	}

	private _layout(): void {
		let editorLayout = this._editor.getLayoutInfo();

		let top = Math.round((editorLayout.height - AccessibilityHelpWidget.HEIGHT) / 2);
		this._domNode.setTop(top);

		let left = Math.round((editorLayout.width - AccessibilityHelpWidget.WIDTH) / 2);
		this._domNode.setLeft(left);
	}
}

class ShowAccessibilityHelpAction extends EditorAction {

	constructor() {
		super({
			id: 'editor.action.showAccessibilityHelp',
			label: nls.localize('ShowAccessibilityHelpAction', "Show Accessibility Help"),
			alias: 'Show Accessibility Help',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.focus,
				primary: KeyMod.Alt | KeyCode.F1,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let controller = AccessibilityHelpController.get(editor);
		if (controller) {
			controller.show();
		}
	}
}

registerEditorContribution(AccessibilityHelpController);
registerEditorAction(ShowAccessibilityHelpAction);

const AccessibilityHelpCommand = EditorCommand.bindToContribution<AccessibilityHelpController>(AccessibilityHelpController.get);

registerEditorCommand(new AccessibilityHelpCommand({
	id: 'closeAccessibilityHelp',
	precondition: CONTEXT_ACCESSIBILITY_WIDGET_VISIBLE,
	handler: x => x.hide(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 100,
		kbExpr: EditorContextKeys.focus,
		primary: KeyCode.Escape, secondary: [KeyMod.Shift | KeyCode.Escape]
	}
}));

registerThemingParticipant((theme, collector) => {
	const widgetBackground = theme.getColor(editorWidgetBackground);
	if (widgetBackground) {
		collector.addRule(`.monaco-editor .accessibilityHelpWidget { background-color: ${widgetBackground}; }`);
	}

	const widgetShadowColor = theme.getColor(widgetShadow);
	if (widgetShadowColor) {
		collector.addRule(`.monaco-editor .accessibilityHelpWidget { box-shadow: 0 2px 8px ${widgetShadowColor}; }`);
	}

	const hcBorder = theme.getColor(contrastBorder);
	if (hcBorder) {
		collector.addRule(`.monaco-editor .accessibilityHelpWidget { border: 2px solid ${hcBorder}; }`);
	}
});
