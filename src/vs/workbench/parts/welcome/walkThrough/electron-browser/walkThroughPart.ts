/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./walkThroughPart';
import { DomScrollableElement } from 'vs/base/browser/ui/scrollbar/scrollableElement';
import { ScrollbarVisibility } from 'vs/base/common/scrollable';
import * as strings from 'vs/base/common/strings';
import { URI } from 'vs/base/common/uri';
import { IDisposable, dispose, toDisposable } from 'vs/base/common/lifecycle';
import { EditorOptions, IEditorMemento } from 'vs/workbench/common/editor';
import { BaseEditor } from 'vs/workbench/browser/parts/editor/baseEditor';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { WalkThroughInput } from 'vs/workbench/parts/welcome/walkThrough/node/walkThroughInput';
import { IOpenerService } from 'vs/platform/opener/common/opener';
import * as marked from 'vs/base/common/marked/marked';
import { IModelService } from 'vs/editor/common/services/modelService';
import { CodeEditorWidget } from 'vs/editor/browser/widget/codeEditorWidget';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { localize } from 'vs/nls';
import { IStorageService } from 'vs/platform/storage/common/storage';
import { RawContextKey, IContextKey, IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { once } from 'vs/base/common/event';
import { isObject } from 'vs/base/common/types';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { IEditorOptions } from 'vs/editor/common/config/editorOptions';
import { IThemeService, registerThemingParticipant } from 'vs/platform/theme/common/themeService';
import { registerColor, focusBorder, textLinkForeground, textLinkActiveForeground, textPreformatForeground, contrastBorder, textBlockQuoteBackground, textBlockQuoteBorder } from 'vs/platform/theme/common/colorRegistry';
import { getExtraColor } from 'vs/workbench/parts/welcome/walkThrough/node/walkThroughUtils';
import { UILabelProvider } from 'vs/base/common/keybindingLabels';
import { OS, OperatingSystem } from 'vs/base/common/platform';
import { deepClone } from 'vs/base/common/objects';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { Dimension, size } from 'vs/base/browser/dom';
import { IEditorGroupsService } from 'vs/workbench/services/group/common/editorGroupsService';
import { CancellationToken } from 'vs/base/common/cancellation';

export const WALK_THROUGH_FOCUS = new RawContextKey<boolean>('interactivePlaygroundFocus', false);

const UNBOUND_COMMAND = localize('walkThrough.unboundCommand', "unbound");
const WALK_THROUGH_EDITOR_VIEW_STATE_PREFERENCE_KEY = 'walkThroughEditorViewState';

interface IViewState {
	scrollTop: number;
	scrollLeft: number;
}

interface IWalkThroughEditorViewState {
	viewState: IViewState;
}

export class WalkThroughPart extends BaseEditor {

	static readonly ID: string = 'workbench.editor.walkThroughPart';

	private disposables: IDisposable[] = [];
	private contentDisposables: IDisposable[] = [];
	private content: HTMLDivElement;
	private scrollbar: DomScrollableElement;
	private editorFocus: IContextKey<boolean>;
	private lastFocus: HTMLElement;
	private size: Dimension;
	private editorMemento: IEditorMemento<IWalkThroughEditorViewState>;

	constructor(
		@ITelemetryService telemetryService: ITelemetryService,
		@IThemeService themeService: IThemeService,
		@IModelService modelService: IModelService,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IOpenerService private openerService: IOpenerService,
		@IKeybindingService private keybindingService: IKeybindingService,
		@IStorageService storageService: IStorageService,
		@IContextKeyService private contextKeyService: IContextKeyService,
		@IConfigurationService private configurationService: IConfigurationService,
		@INotificationService private notificationService: INotificationService,
		@IEditorGroupsService editorGroupService: IEditorGroupsService
	) {
		super(WalkThroughPart.ID, telemetryService, themeService, storageService);
		this.editorFocus = WALK_THROUGH_FOCUS.bindTo(this.contextKeyService);
		this.editorMemento = this.getEditorMemento<IWalkThroughEditorViewState>(editorGroupService, WALK_THROUGH_EDITOR_VIEW_STATE_PREFERENCE_KEY);
	}

	createEditor(container: HTMLElement): void {
		this.content = document.createElement('div');
		this.content.tabIndex = 0;
		this.content.style.outlineStyle = 'none';

		this.scrollbar = new DomScrollableElement(this.content, {
			horizontal: ScrollbarVisibility.Auto,
			vertical: ScrollbarVisibility.Auto
		});
		this.disposables.push(this.scrollbar);
		container.appendChild(this.scrollbar.getDomNode());

		this.registerFocusHandlers();
		this.registerClickHandler();

		this.disposables.push(this.scrollbar.onScroll(e => this.updatedScrollPosition()));
	}

	private updatedScrollPosition() {
		const scrollDimensions = this.scrollbar.getScrollDimensions();
		const scrollPosition = this.scrollbar.getScrollPosition();
		const scrollHeight = scrollDimensions.scrollHeight;
		if (scrollHeight && this.input instanceof WalkThroughInput) {
			const scrollTop = scrollPosition.scrollTop;
			const height = scrollDimensions.height;
			this.input.relativeScrollPosition(scrollTop / scrollHeight, (scrollTop + height) / scrollHeight);
		}
	}

	private addEventListener<K extends keyof HTMLElementEventMap, E extends HTMLElement>(element: E, type: K, listener: (this: E, ev: HTMLElementEventMap[K]) => any, useCapture?: boolean): IDisposable;
	private addEventListener<E extends HTMLElement>(element: E, type: string, listener: EventListenerOrEventListenerObject, useCapture?: boolean): IDisposable;
	private addEventListener<E extends HTMLElement>(element: E, type: string, listener: EventListenerOrEventListenerObject, useCapture?: boolean): IDisposable {
		element.addEventListener(type, listener, useCapture);
		return toDisposable(() => { element.removeEventListener(type, listener, useCapture); });
	}

	private registerFocusHandlers() {
		this.disposables.push(this.addEventListener(this.content, 'mousedown', e => {
			this.focus();
		}));
		this.disposables.push(this.addEventListener(this.content, 'focus', e => {
			this.editorFocus.set(true);
		}));
		this.disposables.push(this.addEventListener(this.content, 'blur', e => {
			this.editorFocus.reset();
		}));
		this.disposables.push(this.addEventListener(this.content, 'focusin', e => {
			// Work around scrolling as side-effect of setting focus on the offscreen zone widget (#18929)
			if (e.target instanceof HTMLElement && e.target.classList.contains('zone-widget-container')) {
				const scrollPosition = this.scrollbar.getScrollPosition();
				this.content.scrollTop = scrollPosition.scrollTop;
				this.content.scrollLeft = scrollPosition.scrollLeft;
			}
			if (e.target instanceof HTMLElement) {
				this.lastFocus = e.target;
			}
		}));
	}

	private registerClickHandler() {
		this.content.addEventListener('click', event => {
			for (let node = event.target as HTMLElement; node; node = node.parentNode as HTMLElement) {
				if (node instanceof HTMLAnchorElement && node.href) {
					let baseElement = window.document.getElementsByTagName('base')[0] || window.location;
					if (baseElement && node.href.indexOf(baseElement.href) >= 0 && node.hash) {
						const scrollTarget = this.content.querySelector(node.hash);
						const innerContent = this.content.firstElementChild;
						if (scrollTarget && innerContent) {
							const targetTop = scrollTarget.getBoundingClientRect().top - 20;
							const containerTop = innerContent.getBoundingClientRect().top;
							this.scrollbar.setScrollPosition({ scrollTop: targetTop - containerTop });
						}
					} else {
						this.open(URI.parse(node.href));
					}
					event.preventDefault();
					break;
				} else if (node instanceof HTMLButtonElement) {
					const href = node.getAttribute('data-href');
					if (href) {
						this.open(URI.parse(href));
					}
					break;
				} else if (node === event.currentTarget) {
					break;
				}
			}
		});
	}

	private open(uri: URI) {
		if (uri.scheme === 'command' && uri.path === 'git.clone' && !CommandsRegistry.getCommand('git.clone')) {
			this.notificationService.info(localize('walkThrough.gitNotFound', "It looks like Git is not installed on your system."));
			return;
		}
		this.openerService.open(this.addFrom(uri));
	}

	private addFrom(uri: URI) {
		if (uri.scheme !== 'command' || !(this.input instanceof WalkThroughInput)) {
			return uri;
		}
		const query = uri.query ? JSON.parse(uri.query) : {};
		query.from = this.input.getTelemetryFrom();
		return uri.with({ query: JSON.stringify(query) });
	}

	layout(dimension: Dimension): void {
		this.size = dimension;
		size(this.content, dimension.width, dimension.height);
		this.updateSizeClasses();
		this.contentDisposables.forEach(disposable => {
			if (disposable instanceof CodeEditorWidget) {
				disposable.layout();
			}
		});
		this.scrollbar.scanDomNode();
	}

	private updateSizeClasses() {
		const innerContent = this.content.firstElementChild;
		if (this.size && innerContent) {
			const classList = innerContent.classList;
			classList[this.size.height <= 685 ? 'add' : 'remove']('max-height-685px');
		}
	}

	focus(): void {
		let active = document.activeElement;
		while (active && active !== this.content) {
			active = active.parentElement;
		}
		if (!active) {
			(this.lastFocus || this.content).focus();
		}
		this.editorFocus.set(true);
	}

	arrowUp() {
		const scrollPosition = this.scrollbar.getScrollPosition();
		this.scrollbar.setScrollPosition({ scrollTop: scrollPosition.scrollTop - this.getArrowScrollHeight() });
	}

	arrowDown() {
		const scrollPosition = this.scrollbar.getScrollPosition();
		this.scrollbar.setScrollPosition({ scrollTop: scrollPosition.scrollTop + this.getArrowScrollHeight() });
	}

	private getArrowScrollHeight() {
		let fontSize = this.configurationService.getValue<number>('editor.fontSize');
		if (typeof fontSize !== 'number' || fontSize < 1) {
			fontSize = 12;
		}
		return 3 * fontSize;
	}

	pageUp() {
		const scrollDimensions = this.scrollbar.getScrollDimensions();
		const scrollPosition = this.scrollbar.getScrollPosition();
		this.scrollbar.setScrollPosition({ scrollTop: scrollPosition.scrollTop - scrollDimensions.height });
	}

	pageDown() {
		const scrollDimensions = this.scrollbar.getScrollDimensions();
		const scrollPosition = this.scrollbar.getScrollPosition();
		this.scrollbar.setScrollPosition({ scrollTop: scrollPosition.scrollTop + scrollDimensions.height });
	}

	setInput(input: WalkThroughInput, options: EditorOptions, token: CancellationToken): Thenable<void> {
		if (this.input instanceof WalkThroughInput) {
			this.saveTextEditorViewState(this.input);
		}

		this.contentDisposables = dispose(this.contentDisposables);
		this.content.innerHTML = '';

		return super.setInput(input, options, token)
			.then(() => {
				return input.resolve();
			})
			.then(model => {
				if (token.isCancellationRequested) {
					return;
				}

				const content = model.main.textEditorModel.getLinesContent().join('\n');
				if (!strings.endsWith(input.getResource().path, '.md')) {
					this.content.innerHTML = content;
					this.updateSizeClasses();
					this.decorateContent();
					this.contentDisposables.push(this.keybindingService.onDidUpdateKeybindings(() => this.decorateContent()));
					if (input.onReady) {
						input.onReady(this.content.firstElementChild as HTMLElement);
					}
					this.scrollbar.scanDomNode();
					this.loadTextEditorViewState(input);
					this.updatedScrollPosition();
					return;
				}

				let i = 0;
				const renderer = new marked.Renderer();
				renderer.code = (code, lang) => {
					const id = `snippet-${model.snippets[i++].textEditorModel.uri.fragment}`;
					return `<div id="${id}" class="walkThroughEditorContainer" ></div>`;
				};
				const innerContent = document.createElement('div');
				innerContent.classList.add('walkThroughContent'); // only for markdown files
				const markdown = this.expandMacros(content);
				innerContent.innerHTML = marked(markdown, { renderer });
				this.content.appendChild(innerContent);

				model.snippets.forEach((snippet, i) => {
					const model = snippet.textEditorModel;
					const id = `snippet-${model.uri.fragment}`;
					const div = innerContent.querySelector(`#${id.replace(/\./g, '\\.')}`) as HTMLElement;

					const options = this.getEditorOptions(snippet.textEditorModel.getModeId());
					/* __GDPR__FRAGMENT__
						"EditorTelemetryData" : {
							"target" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
							"snippet": { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true }
						}
					*/
					const telemetryData = {
						target: this.input instanceof WalkThroughInput ? this.input.getTelemetryFrom() : undefined,
						snippet: i
					};
					const editor = this.instantiationService.createInstance(CodeEditorWidget, div, options, {
						telemetryData: telemetryData
					});
					editor.setModel(model);
					this.contentDisposables.push(editor);

					const updateHeight = (initial: boolean) => {
						const lineHeight = editor.getConfiguration().lineHeight;
						const height = `${Math.max(model.getLineCount() + 1, 4) * lineHeight}px`;
						if (div.style.height !== height) {
							div.style.height = height;
							editor.layout();
							if (!initial) {
								this.scrollbar.scanDomNode();
							}
						}
					};
					updateHeight(true);
					this.contentDisposables.push(editor.onDidChangeModelContent(() => updateHeight(false)));
					this.contentDisposables.push(editor.onDidChangeCursorPosition(e => {
						const innerContent = this.content.firstElementChild;
						if (innerContent) {
							const targetTop = div.getBoundingClientRect().top;
							const containerTop = innerContent.getBoundingClientRect().top;
							const lineHeight = editor.getConfiguration().lineHeight;
							const lineTop = (targetTop + (e.position.lineNumber - 1) * lineHeight) - containerTop;
							const lineBottom = lineTop + lineHeight;
							const scrollDimensions = this.scrollbar.getScrollDimensions();
							const scrollPosition = this.scrollbar.getScrollPosition();
							const scrollTop = scrollPosition.scrollTop;
							const height = scrollDimensions.height;
							if (scrollTop > lineTop) {
								this.scrollbar.setScrollPosition({ scrollTop: lineTop });
							} else if (scrollTop < lineBottom - height) {
								this.scrollbar.setScrollPosition({ scrollTop: lineBottom - height });
							}
						}
					}));

					this.contentDisposables.push(this.configurationService.onDidChangeConfiguration(() => {
						if (snippet.textEditorModel) {
							editor.updateOptions(this.getEditorOptions(snippet.textEditorModel.getModeId()));
						}
					}));

					this.contentDisposables.push(once(editor.onMouseDown)(() => {
						/* __GDPR__
							"walkThroughSnippetInteraction" : {
								"from" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"type": { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"snippet": { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true }
							}
						*/
						this.telemetryService.publicLog('walkThroughSnippetInteraction', {
							from: this.input instanceof WalkThroughInput ? this.input.getTelemetryFrom() : undefined,
							type: 'mouseDown',
							snippet: i
						});
					}));
					this.contentDisposables.push(once(editor.onKeyDown)(() => {
						/* __GDPR__
							"walkThroughSnippetInteraction" : {
								"from" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"type": { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"snippet": { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true }
							}
						*/
						this.telemetryService.publicLog('walkThroughSnippetInteraction', {
							from: this.input instanceof WalkThroughInput ? this.input.getTelemetryFrom() : undefined,
							type: 'keyDown',
							snippet: i
						});
					}));
					this.contentDisposables.push(once(editor.onDidChangeModelContent)(() => {
						/* __GDPR__
							"walkThroughSnippetInteraction" : {
								"from" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"type": { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
								"snippet": { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true }
							}
						*/
						this.telemetryService.publicLog('walkThroughSnippetInteraction', {
							from: this.input instanceof WalkThroughInput ? this.input.getTelemetryFrom() : undefined,
							type: 'changeModelContent',
							snippet: i
						});
					}));
				});
				this.updateSizeClasses();
				this.multiCursorModifier();
				this.contentDisposables.push(this.configurationService.onDidChangeConfiguration(e => {
					if (e.affectsConfiguration('editor.multiCursorModifier')) {
						this.multiCursorModifier();
					}
				}));
				if (input.onReady) {
					input.onReady(innerContent);
				}
				this.scrollbar.scanDomNode();
				this.loadTextEditorViewState(input);
				this.updatedScrollPosition();
			});
	}

	private getEditorOptions(language: string): IEditorOptions {
		const config = deepClone(this.configurationService.getValue<IEditorOptions>('editor', { overrideIdentifier: language }));
		return {
			...isObject(config) ? config : Object.create(null),
			scrollBeyondLastLine: false,
			scrollbar: {
				verticalScrollbarSize: 14,
				horizontal: 'auto',
				useShadows: true,
				verticalHasArrows: false,
				horizontalHasArrows: false
			},
			overviewRulerLanes: 3,
			fixedOverflowWidgets: true,
			lineNumbersMinChars: 1,
			minimap: { enabled: false },
		};
	}

	private expandMacros(input: string) {
		return input.replace(/kb\(([a-z.\d\-]+)\)/gi, (match: string, kb: string) => {
			const keybinding = this.keybindingService.lookupKeybinding(kb);
			const shortcut = keybinding ? keybinding.getLabel() : UNBOUND_COMMAND;
			return `<span class="shortcut">${strings.escape(shortcut)}</span>`;
		});
	}

	private decorateContent() {
		const keys = this.content.querySelectorAll('.shortcut[data-command]');
		Array.prototype.forEach.call(keys, (key: Element) => {
			const command = key.getAttribute('data-command');
			const keybinding = command && this.keybindingService.lookupKeybinding(command);
			const label = keybinding ? keybinding.getLabel() : UNBOUND_COMMAND;
			while (key.firstChild) {
				key.removeChild(key.firstChild);
			}
			key.appendChild(document.createTextNode(label));
		});
		const ifkeys = this.content.querySelectorAll('.if_shortcut[data-command]');
		Array.prototype.forEach.call(ifkeys, (key: HTMLElement) => {
			const command = key.getAttribute('data-command');
			const keybinding = command && this.keybindingService.lookupKeybinding(command);
			key.style.display = !keybinding ? 'none' : '';
		});
	}

	private multiCursorModifier() {
		const labels = UILabelProvider.modifierLabels[OS];
		const value = this.configurationService.getValue<string>('editor.multiCursorModifier');
		const modifier = labels[value === 'ctrlCmd' ? (OS === OperatingSystem.Macintosh ? 'metaKey' : 'ctrlKey') : 'altKey'];
		const keys = this.content.querySelectorAll('.multi-cursor-modifier');
		Array.prototype.forEach.call(keys, (key: Element) => {
			while (key.firstChild) {
				key.removeChild(key.firstChild);
			}
			key.appendChild(document.createTextNode(modifier));
		});
	}

	private saveTextEditorViewState(input: WalkThroughInput): void {
		const scrollPosition = this.scrollbar.getScrollPosition();

		this.editorMemento.saveEditorState(this.group, input, {
			viewState: {
				scrollTop: scrollPosition.scrollTop,
				scrollLeft: scrollPosition.scrollLeft
			}
		});
	}

	private loadTextEditorViewState(input: WalkThroughInput) {
		const state = this.editorMemento.loadEditorState(this.group, input);
		if (state) {
			this.scrollbar.setScrollPosition(state.viewState);
		}
	}

	public clearInput(): void {
		if (this.input instanceof WalkThroughInput) {
			this.saveTextEditorViewState(this.input);
		}
		super.clearInput();
	}

	protected saveState(): void {
		if (this.input instanceof WalkThroughInput) {
			this.saveTextEditorViewState(this.input);
		}

		super.saveState();
	}

	dispose(): void {
		this.editorFocus.reset();
		this.contentDisposables = dispose(this.contentDisposables);
		this.disposables = dispose(this.disposables);
		super.dispose();
	}
}

// theming

export const embeddedEditorBackground = registerColor('walkThrough.embeddedEditorBackground', { dark: null, light: null, hc: null }, localize('walkThrough.embeddedEditorBackground', 'Background color for the embedded editors on the Interactive Playground.'));

registerThemingParticipant((theme, collector) => {
	const color = getExtraColor(theme, embeddedEditorBackground, { dark: 'rgba(0, 0, 0, .4)', extra_dark: 'rgba(200, 235, 255, .064)', light: '#f4f4f4', hc: null });
	if (color) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent .monaco-editor-background,
			.monaco-workbench > .part.editor > .content .walkThroughContent .margin-view-overlays { background: ${color}; }`);
	}
	const link = theme.getColor(textLinkForeground);
	if (link) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent a { color: ${link}; }`);
	}
	const activeLink = theme.getColor(textLinkActiveForeground);
	if (activeLink) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent a:hover,
			.monaco-workbench > .part.editor > .content .walkThroughContent a:active { color: ${activeLink}; }`);
	}
	const focusColor = theme.getColor(focusBorder);
	if (focusColor) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent a:focus { outline-color: ${focusColor}; }`);
	}
	const shortcut = theme.getColor(textPreformatForeground);
	if (shortcut) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent code,
			.monaco-workbench > .part.editor > .content .walkThroughContent .shortcut { color: ${shortcut}; }`);
	}
	const border = theme.getColor(contrastBorder);
	if (border) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent .monaco-editor { border-color: ${border}; }`);
	}
	const quoteBackground = theme.getColor(textBlockQuoteBackground);
	if (quoteBackground) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent blockquote { background: ${quoteBackground}; }`);
	}
	const quoteBorder = theme.getColor(textBlockQuoteBorder);
	if (quoteBorder) {
		collector.addRule(`.monaco-workbench > .part.editor > .content .walkThroughContent blockquote { border-color: ${quoteBorder}; }`);
	}
});
