/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { onUnexpectedError } from 'vs/base/common/errors';
import * as marked from 'vs/base/common/marked/marked';
import { OS } from 'vs/base/common/platform';
import { URI } from 'vs/base/common/uri';
import { TPromise } from 'vs/base/common/winjs.base';
import { asText } from 'vs/base/node/request';
import { TokenizationRegistry, ITokenizationSupport } from 'vs/editor/common/modes';
import { generateTokensCSSForColorMap } from 'vs/editor/common/modes/supports/tokenization';
import { tokenizeToString } from 'vs/editor/common/modes/textToHtmlTokenizer';
import { IModeService } from 'vs/editor/common/services/modeService';
import * as nls from 'vs/nls';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { IOpenerService } from 'vs/platform/opener/common/opener';
import { IRequestService } from 'vs/platform/request/node/request';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { addGAParameters } from 'vs/platform/telemetry/node/telemetryNodeUtils';
import { IWebviewEditorService } from 'vs/workbench/parts/webview/electron-browser/webviewEditorService';
import { IEditorService, ACTIVE_GROUP } from 'vs/workbench/services/editor/common/editorService';
import { WebviewEditorInput } from 'vs/workbench/parts/webview/electron-browser/webviewEditorInput';
import { KeybindingParser } from 'vs/base/common/keybindingParser';
import { CancellationToken } from 'vs/base/common/cancellation';
import { IExtensionService } from 'vs/workbench/services/extensions/common/extensions';

function renderBody(
	body: string,
	css: string
): string {
	const styleSheetPath = require.toUrl('./media/markdown.css').replace('file://', 'vscode-core-resource://');
	return `<!DOCTYPE html>
		<html>
			<head>
				<base href="https://code.visualstudio.com/raw/">
				<meta http-equiv="Content-type" content="text/html;charset=UTF-8">
				<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; media-src https:; script-src 'none'; style-src vscode-core-resource: https: 'unsafe-inline'; child-src 'none'; frame-src 'none';">
				<link rel="stylesheet" type="text/css" href="${styleSheetPath}">
				<style>${css}</style>
			</head>
			<body>${body}</body>
		</html>`;
}

export class ReleaseNotesManager {

	private _releaseNotesCache: { [version: string]: TPromise<string>; } = Object.create(null);

	private _currentReleaseNotes: WebviewEditorInput | undefined = undefined;
	private _lastText: string;

	public constructor(
		@IEnvironmentService private readonly _environmentService: IEnvironmentService,
		@IKeybindingService private readonly _keybindingService: IKeybindingService,
		@IModeService private readonly _modeService: IModeService,
		@IOpenerService private readonly _openerService: IOpenerService,
		@IRequestService private readonly _requestService: IRequestService,
		@ITelemetryService private readonly _telemetryService: ITelemetryService,
		@IEditorService private readonly _editorService: IEditorService,
		@IWebviewEditorService private readonly _webviewEditorService: IWebviewEditorService,
		@IExtensionService private readonly _extensionService: IExtensionService
	) {
		TokenizationRegistry.onDidChange(async () => {
			if (!this._currentReleaseNotes || !this._lastText) {
				return;
			}
			const html = await this.renderBody(this._lastText);
			if (this._currentReleaseNotes) {
				this._currentReleaseNotes.html = html;
			}
		});
	}

	public async show(
		accessor: ServicesAccessor,
		version: string
	): Promise<boolean> {
		const releaseNoteText = await this.loadReleaseNotes(version);
		this._lastText = releaseNoteText;
		const html = await this.renderBody(releaseNoteText);
		const title = nls.localize('releaseNotesInputName', "Release Notes: {0}", version);

		const activeControl = this._editorService.activeControl;
		if (this._currentReleaseNotes) {
			this._currentReleaseNotes.setName(title);
			this._currentReleaseNotes.html = html;
			this._webviewEditorService.revealWebview(this._currentReleaseNotes, activeControl ? activeControl.group : undefined, false);
		} else {
			this._currentReleaseNotes = this._webviewEditorService.createWebview(
				'releaseNotes',
				title,
				{ group: ACTIVE_GROUP, preserveFocus: false },
				{ tryRestoreScrollPosition: true, enableFindWidget: true },
				undefined, {
					onDidClickLink: uri => this.onDidClickLink(uri),
					onDispose: () => { this._currentReleaseNotes = undefined; }
				});

			const iconPath = URI.parse(require.toUrl('./media/code-icon.svg'));
			this._currentReleaseNotes.iconPath = {
				light: iconPath,
				dark: iconPath
			};
			this._currentReleaseNotes.html = html;
		}

		return true;
	}

	private loadReleaseNotes(
		version: string
	): TPromise<string> {
		const match = /^(\d+\.\d+)\./.exec(version);
		if (!match) {
			return TPromise.wrapError<string>(new Error('not found'));
		}

		const versionLabel = match[1].replace(/\./g, '_');
		const baseUrl = 'https://code.visualstudio.com/raw';
		const url = `${baseUrl}/v${versionLabel}.md`;
		const unassigned = nls.localize('unassigned', "unassigned");

		const patchKeybindings = (text: string): string => {
			const kb = (match: string, kb: string) => {
				const keybinding = this._keybindingService.lookupKeybinding(kb);

				if (!keybinding) {
					return unassigned;
				}

				return keybinding.getLabel();
			};

			const kbstyle = (match: string, kb: string) => {
				const keybinding = KeybindingParser.parseKeybinding(kb, OS);

				if (!keybinding) {
					return unassigned;
				}

				const resolvedKeybindings = this._keybindingService.resolveKeybinding(keybinding);

				if (resolvedKeybindings.length === 0) {
					return unassigned;
				}

				return resolvedKeybindings[0].getLabel();
			};

			return text
				.replace(/kb\(([a-z.\d\-]+)\)/gi, kb)
				.replace(/kbstyle\(([^\)]+)\)/gi, kbstyle);
		};

		if (!this._releaseNotesCache[version]) {
			this._releaseNotesCache[version] = this._requestService.request({ url }, CancellationToken.None)
				.then(asText)
				.then(text => {
					if (!/^#\s/.test(text)) { // release notes always starts with `#` followed by whitespace
						return TPromise.wrapError<string>(new Error('Invalid release notes'));
					}

					return TPromise.wrap(text);
				})
				.then(text => patchKeybindings(text));
		}

		return this._releaseNotesCache[version];
	}

	private onDidClickLink(uri: URI) {
		addGAParameters(this._telemetryService, this._environmentService, uri, 'ReleaseNotes')
			.then(updated => this._openerService.open(updated))
			.then(null, onUnexpectedError);
	}

	private async renderBody(text: string) {
		const content = await this.renderContent(text);
		const colorMap = TokenizationRegistry.getColorMap();
		const css = generateTokensCSSForColorMap(colorMap);
		const body = renderBody(content, css);
		return body;
	}

	private async renderContent(text: string): Promise<string> {
		const renderer = await this.getRenderer(text);
		return marked(text, { renderer });
	}

	private async getRenderer(text: string) {
		let result: TPromise<ITokenizationSupport>[] = [];
		const renderer = new marked.Renderer();
		renderer.code = (code, lang) => {
			const modeId = this._modeService.getModeIdForLanguageName(lang);
			result.push(this._extensionService.whenInstalledExtensionsRegistered().then(_ => {
				this._modeService.triggerMode(modeId);
				return TokenizationRegistry.getPromise(modeId);
			}));
			return '';
		};

		marked(text, { renderer });
		await TPromise.join(result);

		renderer.code = (code, lang) => `<code>${tokenizeToString(code, TokenizationRegistry.get(lang))}</code>`;
		return renderer;
	}
}
