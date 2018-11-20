/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from 'vs/base/browser/dom';
import { IKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { IMouseEvent } from 'vs/base/browser/mouseEvent';
import { GestureEvent } from 'vs/base/browser/touch';
import { CountBadge } from 'vs/base/browser/ui/countBadge/countBadge';
import { IconLabel } from 'vs/base/browser/ui/iconLabel/iconLabel';
import { ISashEvent, IVerticalSashLayoutProvider, Sash } from 'vs/base/browser/ui/sash/sash';
import { Color } from 'vs/base/common/color';
import { onUnexpectedError } from 'vs/base/common/errors';
import { Emitter, Event } from 'vs/base/common/event';
import { getBaseLabel } from 'vs/base/common/labels';
import { dispose, IDisposable, IReference } from 'vs/base/common/lifecycle';
import { Schemas } from 'vs/base/common/network';
import { basenameOrAuthority, dirname } from 'vs/base/common/resources';
import * as strings from 'vs/base/common/strings';
import * as tree from 'vs/base/parts/tree/browser/tree';
import { ClickBehavior } from 'vs/base/parts/tree/browser/treeDefaults';
import 'vs/css!./media/referencesWidget';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EmbeddedCodeEditorWidget } from 'vs/editor/browser/widget/embeddedCodeEditorWidget';
import { IEditorOptions } from 'vs/editor/common/config/editorOptions';
import { IRange, Range } from 'vs/editor/common/core/range';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { IModelDeltaDecoration, TrackedRangeStickiness } from 'vs/editor/common/model';
import { ModelDecorationOptions, TextModel } from 'vs/editor/common/model/textModel';
import { Location } from 'vs/editor/common/modes';
import { ITextEditorModel, ITextModelService } from 'vs/editor/common/services/resolverService';
import * as nls from 'vs/nls';
import { RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ILabelService } from 'vs/platform/label/common/label';
import { WorkbenchTree, WorkbenchTreeController } from 'vs/platform/list/browser/listService';
import { activeContrastBorder, contrastBorder, registerColor } from 'vs/platform/theme/common/colorRegistry';
import { attachBadgeStyler } from 'vs/platform/theme/common/styler';
import { ITheme, IThemeService, registerThemingParticipant } from 'vs/platform/theme/common/themeService';
import { PeekViewWidget } from './peekViewWidget';
import { FileReferences, OneReference, ReferencesModel } from './referencesModel';


class DecorationsManager implements IDisposable {

	private static readonly DecorationOptions = ModelDecorationOptions.register({
		stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
		className: 'reference-decoration'
	});

	private _decorations = new Map<string, OneReference>();
	private _decorationIgnoreSet = new Set<string>();
	private _callOnDispose: IDisposable[] = [];
	private _callOnModelChange: IDisposable[] = [];

	constructor(private _editor: ICodeEditor, private _model: ReferencesModel) {
		this._callOnDispose.push(this._editor.onDidChangeModel(() => this._onModelChanged()));
		this._onModelChanged();
	}

	public dispose(): void {
		this._callOnModelChange = dispose(this._callOnModelChange);
		this._callOnDispose = dispose(this._callOnDispose);
		this.removeDecorations();
	}

	private _onModelChanged(): void {
		this._callOnModelChange = dispose(this._callOnModelChange);
		const model = this._editor.getModel();
		if (model) {
			for (const ref of this._model.groups) {
				if (ref.uri.toString() === model.uri.toString()) {
					this._addDecorations(ref);
					return;
				}
			}
		}
	}

	private _addDecorations(reference: FileReferences): void {
		this._callOnModelChange.push(this._editor.getModel().onDidChangeDecorations((event) => this._onDecorationChanged()));

		const newDecorations: IModelDeltaDecoration[] = [];
		const newDecorationsActualIndex: number[] = [];

		for (let i = 0, len = reference.children.length; i < len; i++) {
			let oneReference = reference.children[i];
			if (this._decorationIgnoreSet.has(oneReference.id)) {
				continue;
			}
			newDecorations.push({
				range: oneReference.range,
				options: DecorationsManager.DecorationOptions
			});
			newDecorationsActualIndex.push(i);
		}

		const decorations = this._editor.deltaDecorations([], newDecorations);
		for (let i = 0; i < decorations.length; i++) {
			this._decorations.set(decorations[i], reference.children[newDecorationsActualIndex[i]]);
		}
	}

	private _onDecorationChanged(): void {
		const toRemove: string[] = [];

		this._decorations.forEach((reference, decorationId) => {
			const newRange = this._editor.getModel().getDecorationRange(decorationId);

			if (!newRange) {
				return;
			}

			let ignore = false;

			if (Range.equalsRange(newRange, reference.range)) {
				return;

			} else if (Range.spansMultipleLines(newRange)) {
				ignore = true;

			} else {
				const lineLength = reference.range.endColumn - reference.range.startColumn;
				const newLineLength = newRange.endColumn - newRange.startColumn;

				if (lineLength !== newLineLength) {
					ignore = true;
				}
			}

			if (ignore) {
				this._decorationIgnoreSet.add(reference.id);
				toRemove.push(decorationId);
			} else {
				reference.range = newRange;
			}
		});

		for (let i = 0, len = toRemove.length; i < len; i++) {
			this._decorations.delete(toRemove[i]);
		}
		this._editor.deltaDecorations(toRemove, []);
	}

	public removeDecorations(): void {
		let toRemove: string[] = [];
		this._decorations.forEach((value, key) => {
			toRemove.push(key);
		});
		this._editor.deltaDecorations(toRemove, []);
		this._decorations.clear();
	}
}

class DataSource implements tree.IDataSource {

	constructor(
		@ITextModelService private readonly _textModelResolverService: ITextModelService
	) {
		//
	}

	public getId(tree: tree.ITree, element: any): string {
		if (element instanceof ReferencesModel) {
			return 'root';
		} else if (element instanceof FileReferences) {
			return (<FileReferences>element).id;
		} else if (element instanceof OneReference) {
			return (<OneReference>element).id;
		}
		return undefined;
	}

	public hasChildren(tree: tree.ITree, element: any): boolean {
		if (element instanceof ReferencesModel) {
			return true;
		}
		if (element instanceof FileReferences && !(<FileReferences>element).failure) {
			return true;
		}
		return false;
	}

	public getChildren(tree: tree.ITree, element: ReferencesModel | FileReferences): Promise<any[]> {
		if (element instanceof ReferencesModel) {
			return Promise.resolve(element.groups);
		} else if (element instanceof FileReferences) {
			return element.resolve(this._textModelResolverService).then(val => {
				if (element.failure) {
					// refresh the element on failure so that
					// we can update its rendering
					return tree.refresh(element).then(() => val.children);
				}
				return val.children;
			});
		} else {
			return Promise.resolve([]);
		}
	}

	public getParent(tree: tree.ITree, element: any): Promise<any> {
		let result: any = null;
		if (element instanceof FileReferences) {
			result = (<FileReferences>element).parent;
		} else if (element instanceof OneReference) {
			result = (<OneReference>element).parent;
		}
		return Promise.resolve(result);
	}
}

class Controller extends WorkbenchTreeController {

	private _onDidFocus = new Emitter<any>();
	readonly onDidFocus: Event<any> = this._onDidFocus.event;

	private _onDidSelect = new Emitter<any>();
	readonly onDidSelect: Event<any> = this._onDidSelect.event;

	private _onDidOpenToSide = new Emitter<any>();
	readonly onDidOpenToSide: Event<any> = this._onDidOpenToSide.event;

	public onTap(tree: tree.ITree, element: any, event: GestureEvent): boolean {
		if (element instanceof FileReferences) {
			event.preventDefault();
			event.stopPropagation();
			return this._expandCollapse(tree, element);
		}

		let result = super.onTap(tree, element, event);

		this._onDidFocus.fire(element);
		return result;
	}

	public onMouseDown(tree: tree.ITree, element: any, event: IMouseEvent): boolean {
		let isDoubleClick = event.detail === 2;
		if (event.leftButton) {
			if (element instanceof FileReferences) {
				if (this.openOnSingleClick || isDoubleClick || this.isClickOnTwistie(event)) {
					event.preventDefault();
					event.stopPropagation();
					return this._expandCollapse(tree, element);
				}
			}

			let result = super.onClick(tree, element, event);
			let openToSide = event.ctrlKey || event.metaKey || event.altKey;
			if (openToSide && (isDoubleClick || this.openOnSingleClick)) {
				this._onDidOpenToSide.fire(element);
			} else if (isDoubleClick) {
				this._onDidSelect.fire(element);
			} else if (this.openOnSingleClick) {
				this._onDidFocus.fire(element);
			}
			return result;
		}

		return false;
	}

	public onClick(tree: tree.ITree, element: any, event: IMouseEvent): boolean {
		if (event.leftButton) {
			return false; // Already handled by onMouseDown
		}

		return super.onClick(tree, element, event);
	}

	private _expandCollapse(tree: tree.ITree, element: any): boolean {

		if (tree.isExpanded(element)) {
			tree.collapse(element).then(null, onUnexpectedError);
		} else {
			tree.expand(element).then(null, onUnexpectedError);
		}
		return true;
	}

	public onEscape(tree: tree.ITree, event: IKeyboardEvent): boolean {
		return false;
	}

	dispose(): void {
		this._onDidFocus.dispose();
		this._onDidSelect.dispose();
		this._onDidOpenToSide.dispose();
	}
}

class FileReferencesTemplate {

	readonly file: IconLabel;
	readonly badge: CountBadge;
	readonly dispose: () => void;

	constructor(
		container: HTMLElement,
		@ILabelService private readonly _uriLabel: ILabelService,
		@IThemeService themeService: IThemeService,
	) {
		const parent = document.createElement('div');
		dom.addClass(parent, 'reference-file');
		container.appendChild(parent);
		this.file = new IconLabel(parent);

		this.badge = new CountBadge(dom.append(parent, dom.$('.count')));
		const styler = attachBadgeStyler(this.badge, themeService);

		this.dispose = () => {
			this.file.dispose();
			styler.dispose();
		};
	}

	set(element: FileReferences) {
		let parent = dirname(element.uri);
		this.file.setValue(getBaseLabel(element.uri), parent ? this._uriLabel.getUriLabel(parent, { relative: true }) : undefined, { title: this._uriLabel.getUriLabel(element.uri) });
		const len = element.children.length;
		this.badge.setCount(len);
		if (element.failure) {
			this.badge.setTitleFormat(nls.localize('referencesFailre', "Failed to resolve file."));
		} else if (len > 1) {
			this.badge.setTitleFormat(nls.localize('referencesCount', "{0} references", len));
		} else {
			this.badge.setTitleFormat(nls.localize('referenceCount', "{0} reference", len));
		}
	}
}

class OneReferenceTemplate {

	readonly before: HTMLSpanElement;
	readonly inside: HTMLSpanElement;
	readonly after: HTMLSpanElement;

	constructor(container: HTMLElement) {
		const parent = document.createElement('div');
		this.before = document.createElement('span');
		this.inside = document.createElement('span');
		this.after = document.createElement('span');
		dom.addClass(this.inside, 'referenceMatch');
		dom.addClass(parent, 'reference');
		parent.appendChild(this.before);
		parent.appendChild(this.inside);
		parent.appendChild(this.after);
		container.appendChild(parent);
	}

	set(element: OneReference): void {
		const { before, inside, after } = element.parent.preview.preview(element.range);
		this.before.innerHTML = strings.escape(before);
		this.inside.innerHTML = strings.escape(inside);
		this.after.innerHTML = strings.escape(after);
	}
}

class Renderer implements tree.IRenderer {

	private static readonly _ids = {
		FileReferences: 'FileReferences',
		OneReference: 'OneReference'
	};

	constructor(
		@IThemeService private readonly _themeService: IThemeService,
		@ILabelService private readonly _uriLabel: ILabelService,
	) {
		//
	}

	getHeight(tree: tree.ITree, element: FileReferences | OneReference): number {
		return 23;
	}

	getTemplateId(tree: tree.ITree, element: FileReferences | OneReference): string {
		if (element instanceof FileReferences) {
			return Renderer._ids.FileReferences;
		} else if (element instanceof OneReference) {
			return Renderer._ids.OneReference;
		}
		throw element;
	}

	renderTemplate(tree: tree.ITree, templateId: string, container: HTMLElement) {
		if (templateId === Renderer._ids.FileReferences) {
			return new FileReferencesTemplate(container, this._uriLabel, this._themeService);
		} else if (templateId === Renderer._ids.OneReference) {
			return new OneReferenceTemplate(container);
		}
		throw templateId;
	}

	renderElement(tree: tree.ITree, element: FileReferences | OneReference, templateId: string, templateData: any): void {
		if (element instanceof FileReferences) {
			(<FileReferencesTemplate>templateData).set(element);
		} else if (element instanceof OneReference) {
			(<OneReferenceTemplate>templateData).set(element);
		} else {
			throw templateId;
		}
	}

	disposeTemplate(tree: tree.ITree, templateId: string, templateData: FileReferencesTemplate | OneReferenceTemplate): void {
		if (templateData instanceof FileReferencesTemplate) {
			templateData.dispose();
		}
	}
}

class AriaProvider implements tree.IAccessibilityProvider {

	getAriaLabel(tree: tree.ITree, element: FileReferences | OneReference): string {
		if (element instanceof FileReferences) {
			return element.getAriaMessage();
		} else if (element instanceof OneReference) {
			return element.getAriaMessage();
		} else {
			return undefined;
		}
	}
}

class VSash {

	private _disposables: IDisposable[] = [];
	private _sash: Sash;
	private _ratio: number;
	private _height: number;
	private _width: number;
	private _onDidChangePercentages = new Emitter<VSash>();

	constructor(container: HTMLElement, ratio: number) {
		this._ratio = ratio;
		this._sash = new Sash(container, <IVerticalSashLayoutProvider>{
			getVerticalSashLeft: () => this._width * this._ratio,
			getVerticalSashHeight: () => this._height
		});

		// compute the current widget clientX postion since
		// the sash works with clientX when dragging
		let clientX: number;
		this._disposables.push(this._sash.onDidStart((e: ISashEvent) => {
			clientX = e.startX - (this._width * this.ratio);
		}));

		this._disposables.push(this._sash.onDidChange((e: ISashEvent) => {
			// compute the new position of the sash and from that
			// compute the new ratio that we are using
			let newLeft = e.currentX - clientX;
			if (newLeft > 20 && newLeft + 20 < this._width) {
				this._ratio = newLeft / this._width;
				this._sash.layout();
				this._onDidChangePercentages.fire(this);
			}
		}));
	}

	dispose() {
		this._sash.dispose();
		this._onDidChangePercentages.dispose();
		dispose(this._disposables);
	}

	get onDidChangePercentages() {
		return this._onDidChangePercentages.event;
	}

	set width(value: number) {
		this._width = value;
		this._sash.layout();
	}

	set height(value: number) {
		this._height = value;
		this._sash.layout();
	}

	get percentages() {
		let left = 100 * this._ratio;
		let right = 100 - left;
		return [`${left}%`, `${right}%`];
	}

	get ratio() {
		return this._ratio;
	}
}

export interface LayoutData {
	ratio: number;
	heightInLines: number;
}

export interface SelectionEvent {
	kind: 'goto' | 'show' | 'side' | 'open';
	source: 'editor' | 'tree' | 'title';
	element: Location;
}

export const ctxReferenceWidgetSearchTreeFocused = new RawContextKey<boolean>('referenceSearchTreeFocused', true);

/**
 * ZoneWidget that is shown inside the editor
 */
export class ReferenceWidget extends PeekViewWidget {

	private _model: ReferencesModel;
	private _decorationsManager: DecorationsManager;

	private _disposeOnNewModel: IDisposable[] = [];
	private _callOnDispose: IDisposable[] = [];
	private _onDidSelectReference = new Emitter<SelectionEvent>();

	private _tree: WorkbenchTree;
	private _treeContainer: HTMLElement;
	private _sash: VSash;
	private _preview: ICodeEditor;
	private _previewModelReference: IReference<ITextEditorModel>;
	private _previewNotAvailableMessage: TextModel;
	private _previewContainer: HTMLElement;
	private _messageContainer: HTMLElement;

	constructor(
		editor: ICodeEditor,
		private _defaultTreeKeyboardSupport: boolean,
		public layoutData: LayoutData,
		@IThemeService themeService: IThemeService,
		@ITextModelService private _textModelResolverService: ITextModelService,
		@IInstantiationService private _instantiationService: IInstantiationService,
		@ILabelService private _uriLabel: ILabelService
	) {
		super(editor, { showFrame: false, showArrow: true, isResizeable: true, isAccessible: true });

		this._applyTheme(themeService.getTheme());
		this._callOnDispose.push(themeService.onThemeChange(this._applyTheme.bind(this)));
		this.create();
	}

	private _applyTheme(theme: ITheme) {
		const borderColor = theme.getColor(peekViewBorder) || Color.transparent;
		this.style({
			arrowColor: borderColor,
			frameColor: borderColor,
			headerBackgroundColor: theme.getColor(peekViewTitleBackground) || Color.transparent,
			primaryHeadingColor: theme.getColor(peekViewTitleForeground),
			secondaryHeadingColor: theme.getColor(peekViewTitleInfoForeground)
		});
	}

	public dispose(): void {
		this.setModel(null);
		this._callOnDispose = dispose(this._callOnDispose);
		dispose<IDisposable>(this._preview, this._previewNotAvailableMessage, this._tree, this._sash, this._previewModelReference);
		super.dispose();
	}

	get onDidSelectReference(): Event<SelectionEvent> {
		return this._onDidSelectReference.event;
	}

	show(where: IRange) {
		this.editor.revealRangeInCenterIfOutsideViewport(where, editorCommon.ScrollType.Smooth);
		super.show(where, this.layoutData.heightInLines || 18);
	}

	focus(): void {
		this._tree.domFocus();
	}

	protected _onTitleClick(e: IMouseEvent): void {
		if (this._preview && this._preview.getModel()) {
			this._onDidSelectReference.fire({
				element: this._getFocusedReference(),
				kind: e.ctrlKey || e.metaKey || e.altKey ? 'side' : 'open',
				source: 'title'
			});
		}
	}

	protected _fillBody(containerElement: HTMLElement): void {
		this.setCssClass('reference-zone-widget');

		// message pane
		this._messageContainer = dom.append(containerElement, dom.$('div.messages'));
		dom.hide(this._messageContainer);

		// editor
		this._previewContainer = dom.append(containerElement, dom.$('div.preview.inline'));
		let options: IEditorOptions = {
			scrollBeyondLastLine: false,
			scrollbar: {
				verticalScrollbarSize: 14,
				horizontal: 'auto',
				useShadows: true,
				verticalHasArrows: false,
				horizontalHasArrows: false
			},
			overviewRulerLanes: 2,
			fixedOverflowWidgets: true,
			minimap: {
				enabled: false
			}
		};
		this._preview = this._instantiationService.createInstance(EmbeddedCodeEditorWidget, this._previewContainer, options, this.editor);
		dom.hide(this._previewContainer);
		this._previewNotAvailableMessage = TextModel.createFromString(nls.localize('missingPreviewMessage', "no preview available"));

		// sash
		this._sash = new VSash(containerElement, this.layoutData.ratio || .8);
		this._sash.onDidChangePercentages(() => {
			let [left, right] = this._sash.percentages;
			this._previewContainer.style.width = left;
			this._treeContainer.style.width = right;
			this._preview.layout();
			this._tree.layout();
			this.layoutData.ratio = this._sash.ratio;
		});

		// tree
		this._treeContainer = dom.append(containerElement, dom.$('div.ref-tree.inline'));
		let controller = this._instantiationService.createInstance(Controller, { keyboardSupport: this._defaultTreeKeyboardSupport, clickBehavior: ClickBehavior.ON_MOUSE_UP /* our controller already deals with this */ });
		this._callOnDispose.push(controller);

		let config = <tree.ITreeConfiguration>{
			dataSource: this._instantiationService.createInstance(DataSource),
			renderer: this._instantiationService.createInstance(Renderer),
			controller,
			accessibilityProvider: new AriaProvider()
		};

		let treeOptions: tree.ITreeOptions = {
			twistiePixels: 20,
			ariaLabel: nls.localize('treeAriaLabel', "References")
		};

		this._tree = this._instantiationService.createInstance(WorkbenchTree, this._treeContainer, config, treeOptions);

		ctxReferenceWidgetSearchTreeFocused.bindTo(this._tree.contextKeyService);

		// listen on selection and focus
		let onEvent = (element: any, kind: 'show' | 'goto' | 'side') => {
			if (element instanceof OneReference) {
				if (kind === 'show') {
					this._revealReference(element, false);
				}
				this._onDidSelectReference.fire({ element, kind, source: 'tree' });
			}
		};
		this._disposables.push(this._tree.onDidChangeFocus(event => {
			if (event && event.payload && event.payload.origin === 'keyboard') {
				onEvent(event.focus, 'show'); // only handle events from keyboard, mouse/touch is handled by other listeners below
			}
		}));
		this._disposables.push(this._tree.onDidChangeSelection(event => {
			if (event && event.payload && event.payload.origin === 'keyboard') {
				onEvent(event.selection[0], 'goto'); // only handle events from keyboard, mouse/touch is handled by other listeners below
			}
		}));
		this._disposables.push(controller.onDidFocus(element => onEvent(element, 'show')));
		this._disposables.push(controller.onDidSelect(element => onEvent(element, 'goto')));
		this._disposables.push(controller.onDidOpenToSide(element => onEvent(element, 'side')));
		dom.hide(this._treeContainer);
	}

	protected _doLayoutBody(heightInPixel: number, widthInPixel: number): void {
		super._doLayoutBody(heightInPixel, widthInPixel);

		const height = heightInPixel + 'px';
		this._sash.height = heightInPixel;
		this._sash.width = widthInPixel;

		// set height/width
		const [left, right] = this._sash.percentages;
		this._previewContainer.style.height = height;
		this._previewContainer.style.width = left;
		this._treeContainer.style.height = height;
		this._treeContainer.style.width = right;
		// forward
		this._tree.layout(heightInPixel);
		this._preview.layout();

		// store layout data
		this.layoutData = {
			heightInLines: this._viewZone.heightInLines,
			ratio: this._sash.ratio
		};
	}

	public _onWidth(widthInPixel: number): void {
		this._sash.width = widthInPixel;
		this._preview.layout();
	}

	public setSelection(selection: OneReference): Promise<any> {
		return this._revealReference(selection, true).then(() => {
			if (!this._model) {
				// disposed
				return;
			}
			// show in tree
			this._tree.setSelection([selection]);
			this._tree.setFocus(selection);
		});
	}

	public setModel(newModel: ReferencesModel): Thenable<any> {
		// clean up
		this._disposeOnNewModel = dispose(this._disposeOnNewModel);
		this._model = newModel;
		if (this._model) {
			return this._onNewModel();
		}
		return undefined;
	}

	private _onNewModel(): Thenable<any> {

		if (this._model.empty) {
			this.setTitle('');
			this._messageContainer.innerHTML = nls.localize('noResults', "No results");
			dom.show(this._messageContainer);
			return Promise.resolve(void 0);
		}

		dom.hide(this._messageContainer);
		this._decorationsManager = new DecorationsManager(this._preview, this._model);
		this._disposeOnNewModel.push(this._decorationsManager);

		// listen on model changes
		this._disposeOnNewModel.push(this._model.onDidChangeReferenceRange(reference => this._tree.refresh(reference)));

		// listen on editor
		this._disposeOnNewModel.push(this._preview.onMouseDown(e => {
			const { event, target } = e;
			if (event.detail === 2) {
				this._onDidSelectReference.fire({
					element: { uri: this._getFocusedReference().uri, range: target.range },
					kind: (event.ctrlKey || event.metaKey || event.altKey) ? 'side' : 'open',
					source: 'editor'
				});
			}
		}));

		// make sure things are rendered
		dom.addClass(this.container, 'results-loaded');
		dom.show(this._treeContainer);
		dom.show(this._previewContainer);
		this._preview.layout();
		this._tree.layout();
		this.focus();

		// pick input and a reference to begin with
		const input = this._model.groups.length === 1 ? this._model.groups[0] : this._model;
		return this._tree.setInput(input);
	}

	private _getFocusedReference(): OneReference {
		const element = this._tree.getFocus();
		if (element instanceof OneReference) {
			return element;
		} else if (element instanceof FileReferences) {
			if (element.children.length > 0) {
				return element.children[0];
			}
		}
		return undefined;
	}

	private async _revealReference(reference: OneReference, revealParent: boolean): Promise<void> {

		// Update widget header
		if (reference.uri.scheme !== Schemas.inMemory) {
			this.setTitle(basenameOrAuthority(reference.uri), this._uriLabel.getUriLabel(dirname(reference.uri)));
		} else {
			this.setTitle(nls.localize('peekView.alternateTitle', "References"));
		}

		const promise = this._textModelResolverService.createModelReference(reference.uri);

		if (revealParent) {
			await this._tree.reveal(reference.parent);
		}

		return Promise.all([promise, this._tree.reveal(reference)]).then(values => {
			const ref = values[0];

			if (!this._model) {
				ref.dispose();
				// disposed
				return;
			}

			dispose(this._previewModelReference);

			// show in editor
			const model = ref.object;
			if (model) {
				this._previewModelReference = ref;
				let isSameModel = (this._preview.getModel() === model.textEditorModel);
				this._preview.setModel(model.textEditorModel);
				let sel = Range.lift(reference.range).collapseToStart();
				this._preview.setSelection(sel);
				this._preview.revealRangeInCenter(sel, isSameModel ? editorCommon.ScrollType.Smooth : editorCommon.ScrollType.Immediate);
			} else {
				this._preview.setModel(this._previewNotAvailableMessage);
				ref.dispose();
			}
		}, onUnexpectedError);
	}
}

// theming

export const peekViewTitleBackground = registerColor('peekViewTitle.background', { dark: '#1E1E1E', light: '#FFFFFF', hc: '#0C141F' }, nls.localize('peekViewTitleBackground', 'Background color of the peek view title area.'));
export const peekViewTitleForeground = registerColor('peekViewTitleLabel.foreground', { dark: '#FFFFFF', light: '#333333', hc: '#FFFFFF' }, nls.localize('peekViewTitleForeground', 'Color of the peek view title.'));
export const peekViewTitleInfoForeground = registerColor('peekViewTitleDescription.foreground', { dark: '#ccccccb3', light: '#6c6c6cb3', hc: '#FFFFFF99' }, nls.localize('peekViewTitleInfoForeground', 'Color of the peek view title info.'));
export const peekViewBorder = registerColor('peekView.border', { dark: '#007acc', light: '#007acc', hc: contrastBorder }, nls.localize('peekViewBorder', 'Color of the peek view borders and arrow.'));

export const peekViewResultsBackground = registerColor('peekViewResult.background', { dark: '#252526', light: '#F3F3F3', hc: Color.black }, nls.localize('peekViewResultsBackground', 'Background color of the peek view result list.'));
export const peekViewResultsMatchForeground = registerColor('peekViewResult.lineForeground', { dark: '#bbbbbb', light: '#646465', hc: Color.white }, nls.localize('peekViewResultsMatchForeground', 'Foreground color for line nodes in the peek view result list.'));
export const peekViewResultsFileForeground = registerColor('peekViewResult.fileForeground', { dark: Color.white, light: '#1E1E1E', hc: Color.white }, nls.localize('peekViewResultsFileForeground', 'Foreground color for file nodes in the peek view result list.'));
export const peekViewResultsSelectionBackground = registerColor('peekViewResult.selectionBackground', { dark: '#3399ff33', light: '#3399ff33', hc: null }, nls.localize('peekViewResultsSelectionBackground', 'Background color of the selected entry in the peek view result list.'));
export const peekViewResultsSelectionForeground = registerColor('peekViewResult.selectionForeground', { dark: Color.white, light: '#6C6C6C', hc: Color.white }, nls.localize('peekViewResultsSelectionForeground', 'Foreground color of the selected entry in the peek view result list.'));
export const peekViewEditorBackground = registerColor('peekViewEditor.background', { dark: '#001F33', light: '#F2F8FC', hc: Color.black }, nls.localize('peekViewEditorBackground', 'Background color of the peek view editor.'));
export const peekViewEditorGutterBackground = registerColor('peekViewEditorGutter.background', { dark: peekViewEditorBackground, light: peekViewEditorBackground, hc: peekViewEditorBackground }, nls.localize('peekViewEditorGutterBackground', 'Background color of the gutter in the peek view editor.'));

export const peekViewResultsMatchHighlight = registerColor('peekViewResult.matchHighlightBackground', { dark: '#ea5c004d', light: '#ea5c004d', hc: null }, nls.localize('peekViewResultsMatchHighlight', 'Match highlight color in the peek view result list.'));
export const peekViewEditorMatchHighlight = registerColor('peekViewEditor.matchHighlightBackground', { dark: '#ff8f0099', light: '#f5d802de', hc: null }, nls.localize('peekViewEditorMatchHighlight', 'Match highlight color in the peek view editor.'));
export const peekViewEditorMatchHighlightBorder = registerColor('peekViewEditor.matchHighlightBorder', { dark: null, light: null, hc: activeContrastBorder }, nls.localize('peekViewEditorMatchHighlightBorder', 'Match highlight border in the peek view editor.'));


registerThemingParticipant((theme, collector) => {
	const findMatchHighlightColor = theme.getColor(peekViewResultsMatchHighlight);
	if (findMatchHighlightColor) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree .referenceMatch { background-color: ${findMatchHighlightColor}; }`);
	}
	const referenceHighlightColor = theme.getColor(peekViewEditorMatchHighlight);
	if (referenceHighlightColor) {
		collector.addRule(`.monaco-editor .reference-zone-widget .preview .reference-decoration { background-color: ${referenceHighlightColor}; }`);
	}
	const referenceHighlightBorder = theme.getColor(peekViewEditorMatchHighlightBorder);
	if (referenceHighlightBorder) {
		collector.addRule(`.monaco-editor .reference-zone-widget .preview .reference-decoration { border: 2px solid ${referenceHighlightBorder}; box-sizing: border-box; }`);
	}
	const hcOutline = theme.getColor(activeContrastBorder);
	if (hcOutline) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree .referenceMatch { border: 1px dotted ${hcOutline}; box-sizing: border-box; }`);
	}
	const resultsBackground = theme.getColor(peekViewResultsBackground);
	if (resultsBackground) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree { background-color: ${resultsBackground}; }`);
	}
	const resultsMatchForeground = theme.getColor(peekViewResultsMatchForeground);
	if (resultsMatchForeground) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree { color: ${resultsMatchForeground}; }`);
	}
	const resultsFileForeground = theme.getColor(peekViewResultsFileForeground);
	if (resultsFileForeground) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree .reference-file { color: ${resultsFileForeground}; }`);
	}
	const resultsSelectedBackground = theme.getColor(peekViewResultsSelectionBackground);
	if (resultsSelectedBackground) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree .monaco-tree.focused .monaco-tree-rows > .monaco-tree-row.selected:not(.highlighted) { background-color: ${resultsSelectedBackground}; }`);
	}
	const resultsSelectedForeground = theme.getColor(peekViewResultsSelectionForeground);
	if (resultsSelectedForeground) {
		collector.addRule(`.monaco-editor .reference-zone-widget .ref-tree .monaco-tree.focused .monaco-tree-rows > .monaco-tree-row.selected:not(.highlighted) { color: ${resultsSelectedForeground} !important; }`);
	}
	const editorBackground = theme.getColor(peekViewEditorBackground);
	if (editorBackground) {
		collector.addRule(
			`.monaco-editor .reference-zone-widget .preview .monaco-editor .monaco-editor-background,` +
			`.monaco-editor .reference-zone-widget .preview .monaco-editor .inputarea.ime-input {` +
			`	background-color: ${editorBackground};` +
			`}`);
	}
	const editorGutterBackground = theme.getColor(peekViewEditorGutterBackground);
	if (editorGutterBackground) {
		collector.addRule(
			`.monaco-editor .reference-zone-widget .preview .monaco-editor .margin {` +
			`	background-color: ${editorGutterBackground};` +
			`}`);
	}
});
