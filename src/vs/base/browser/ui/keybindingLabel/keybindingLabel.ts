/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./keybindingLabel';
import { IDisposable } from 'vs/base/common/lifecycle';
import { equals } from 'vs/base/common/objects';
import { OperatingSystem } from 'vs/base/common/platform';
import { ResolvedKeybinding, ResolvedKeybindingPart } from 'vs/base/common/keyCodes';
import { UILabelProvider } from 'vs/base/common/keybindingLabels';
import * as dom from 'vs/base/browser/dom';

const $ = dom.$;

export interface PartMatches {
	ctrlKey?: boolean;
	shiftKey?: boolean;
	altKey?: boolean;
	metaKey?: boolean;
	keyCode?: boolean;
}

export interface Matches {
	firstPart: PartMatches;
	chordPart: PartMatches;
}

export class KeybindingLabel implements IDisposable {

	private domNode: HTMLElement;
	private keybinding: ResolvedKeybinding;
	private matches: Matches;
	private didEverRender: boolean;

	constructor(container: HTMLElement, private os: OperatingSystem) {
		this.domNode = dom.append(container, $('.monaco-keybinding'));
		this.didEverRender = false;
		container.appendChild(this.domNode);
	}

	get element(): HTMLElement {
		return this.domNode;
	}

	set(keybinding: ResolvedKeybinding, matches: Matches) {
		if (this.didEverRender && this.keybinding === keybinding && KeybindingLabel.areSame(this.matches, matches)) {
			return;
		}

		this.keybinding = keybinding;
		this.matches = matches;
		this.render();
	}

	private render() {
		dom.clearNode(this.domNode);

		if (this.keybinding) {
			let [firstPart, chordPart] = this.keybinding.getParts();
			if (firstPart) {
				this.renderPart(this.domNode, firstPart, this.matches ? this.matches.firstPart : null);
			}
			if (chordPart) {
				dom.append(this.domNode, $('span.monaco-keybinding-key-chord-separator', undefined, ' '));
				this.renderPart(this.domNode, chordPart, this.matches ? this.matches.chordPart : null);
			}
			this.domNode.title = this.keybinding.getAriaLabel() || '';
		}

		this.didEverRender = true;
	}

	private renderPart(parent: HTMLElement, part: ResolvedKeybindingPart, match: PartMatches | null) {
		const modifierLabels = UILabelProvider.modifierLabels[this.os];
		if (part.ctrlKey) {
			this.renderKey(parent, modifierLabels.ctrlKey, Boolean(match && match.ctrlKey), modifierLabels.separator);
		}
		if (part.shiftKey) {
			this.renderKey(parent, modifierLabels.shiftKey, Boolean(match && match.shiftKey), modifierLabels.separator);
		}
		if (part.altKey) {
			this.renderKey(parent, modifierLabels.altKey, Boolean(match && match.altKey), modifierLabels.separator);
		}
		if (part.metaKey) {
			this.renderKey(parent, modifierLabels.metaKey, Boolean(match && match.metaKey), modifierLabels.separator);
		}
		const keyLabel = part.keyLabel;
		if (keyLabel) {
			this.renderKey(parent, keyLabel, Boolean(match && match.keyCode), '');
		}
	}

	private renderKey(parent: HTMLElement, label: string, highlight: boolean, separator: string): void {
		dom.append(parent, $('span.monaco-keybinding-key' + (highlight ? '.highlight' : ''), undefined, label));
		if (separator) {
			dom.append(parent, $('span.monaco-keybinding-key-separator', undefined, separator));
		}
	}

	dispose() {
	}

	private static areSame(a: Matches, b: Matches): boolean {
		if (a === b || (!a && !b)) {
			return true;
		}
		return !!a && !!b && equals(a.firstPart, b.firstPart) && equals(a.chordPart, b.chordPart);
	}
}
