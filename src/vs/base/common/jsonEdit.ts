/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ParseError, Node, JSONPath, Segment, parseTree, findNodeAtLocation } from './json';
import { Edit, format, isEOL, FormattingOptions } from './jsonFormatter';


export function removeProperty(text: string, path: JSONPath, formattingOptions: FormattingOptions): Edit[] {
	return setProperty(text, path, void 0, formattingOptions);
}

export function setProperty(text: string, originalPath: JSONPath, value: any, formattingOptions: FormattingOptions, getInsertionIndex?: (properties: string[]) => number): Edit[] {
	let path = originalPath.slice();
	let errors: ParseError[] = [];
	let root = parseTree(text, errors);
	let parent: Node | undefined = void 0;

	let lastSegment: Segment | undefined = void 0;
	while (path.length > 0) {
		lastSegment = path.pop();
		parent = findNodeAtLocation(root, path);
		if (parent === void 0 && value !== void 0) {
			if (typeof lastSegment === 'string') {
				value = { [lastSegment]: value };
			} else {
				value = [value];
			}
		} else {
			break;
		}
	}

	if (!parent) {
		// empty document
		if (value === void 0) { // delete
			throw new Error('Can not delete in empty document');
		}
		return withFormatting(text, { offset: root ? root.offset : 0, length: root ? root.length : 0, content: JSON.stringify(value) }, formattingOptions);
	} else if (parent.type === 'object' && typeof lastSegment === 'string' && Array.isArray(parent.children)) {
		let existing = findNodeAtLocation(parent, [lastSegment]);
		if (existing !== void 0) {
			if (value === void 0) { // delete
				if (!existing.parent) {
					throw new Error('Malformed AST');
				}
				let propertyIndex = parent.children.indexOf(existing.parent);
				let removeBegin: number;
				let removeEnd = existing.parent.offset + existing.parent.length;
				if (propertyIndex > 0) {
					// remove the comma of the previous node
					let previous = parent.children[propertyIndex - 1];
					removeBegin = previous.offset + previous.length;
				} else {
					removeBegin = parent.offset + 1;
					if (parent.children.length > 1) {
						// remove the comma of the next node
						let next = parent.children[1];
						removeEnd = next.offset;
					}
				}
				return withFormatting(text, { offset: removeBegin, length: removeEnd - removeBegin, content: '' }, formattingOptions);
			} else {
				// set value of existing property
				return withFormatting(text, { offset: existing.offset, length: existing.length, content: JSON.stringify(value) }, formattingOptions);
			}
		} else {
			if (value === void 0) { // delete
				return []; // property does not exist, nothing to do
			}
			let newProperty = `${JSON.stringify(lastSegment)}: ${JSON.stringify(value)}`;
			let index = getInsertionIndex ? getInsertionIndex(parent.children.map(p => p.children![0].value)) : parent.children.length;
			let edit: Edit;
			if (index > 0) {
				let previous = parent.children[index - 1];
				edit = { offset: previous.offset + previous.length, length: 0, content: ',' + newProperty };
			} else if (parent.children.length === 0) {
				edit = { offset: parent.offset + 1, length: 0, content: newProperty };
			} else {
				edit = { offset: parent.offset + 1, length: 0, content: newProperty + ',' };
			}
			return withFormatting(text, edit, formattingOptions);
		}
	} else if (parent.type === 'array' && typeof lastSegment === 'number' && Array.isArray(parent.children)) {
		let insertIndex = lastSegment;
		if (insertIndex === -1) {
			// Insert
			let newProperty = `${JSON.stringify(value)}`;
			let edit: Edit;
			if (parent.children.length === 0) {
				edit = { offset: parent.offset + 1, length: 0, content: newProperty };
			} else {
				let previous = parent.children[parent.children.length - 1];
				edit = { offset: previous.offset + previous.length, length: 0, content: ',' + newProperty };
			}
			return withFormatting(text, edit, formattingOptions);
		} else {
			if (value === void 0 && parent.children.length >= 0) {
				//Removal
				let removalIndex = lastSegment;
				let toRemove = parent.children[removalIndex];
				let edit: Edit;
				if (parent.children.length === 1) {
					// only item
					edit = { offset: parent.offset + 1, length: parent.length - 2, content: '' };
				} else if (parent.children.length - 1 === removalIndex) {
					// last item
					let previous = parent.children[removalIndex - 1];
					let offset = previous.offset + previous.length;
					let parentEndOffset = parent.offset + parent.length;
					edit = { offset, length: parentEndOffset - 2 - offset, content: '' };
				} else {
					edit = { offset: toRemove.offset, length: parent.children[removalIndex + 1].offset - toRemove.offset, content: '' };
				}
				return withFormatting(text, edit, formattingOptions);
			} else {
				throw new Error('Array modification not supported yet');
			}
		}
	} else {
		throw new Error(`Can not add ${typeof lastSegment !== 'number' ? 'index' : 'property'} to parent of type ${parent.type}`);
	}
}

function withFormatting(text: string, edit: Edit, formattingOptions: FormattingOptions): Edit[] {
	// apply the edit
	let newText = applyEdit(text, edit);

	// format the new text
	let begin = edit.offset;
	let end = edit.offset + edit.content.length;
	if (edit.length === 0 || edit.content.length === 0) { // insert or remove
		while (begin > 0 && !isEOL(newText, begin - 1)) {
			begin--;
		}
		while (end < newText.length && !isEOL(newText, end)) {
			end++;
		}
	}

	let edits = format(newText, { offset: begin, length: end - begin }, formattingOptions);

	// apply the formatting edits and track the begin and end offsets of the changes
	for (let i = edits.length - 1; i >= 0; i--) {
		let edit = edits[i];
		newText = applyEdit(newText, edit);
		begin = Math.min(begin, edit.offset);
		end = Math.max(end, edit.offset + edit.length);
		end += edit.content.length - edit.length;
	}
	// create a single edit with all changes
	let editLength = text.length - (newText.length - end) - begin;
	return [{ offset: begin, length: editLength, content: newText.substring(begin, end) }];
}

export function applyEdit(text: string, edit: Edit): string {
	return text.substring(0, edit.offset) + edit.content + text.substring(edit.offset + edit.length);
}

export function isWS(text: string, offset: number) {
	return '\r\n \t'.indexOf(text.charAt(offset)) !== -1;
}