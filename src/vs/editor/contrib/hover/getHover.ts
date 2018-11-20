/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { coalesce } from 'vs/base/common/arrays';
import { CancellationToken } from 'vs/base/common/cancellation';
import { onUnexpectedExternalError } from 'vs/base/common/errors';
import { registerDefaultLanguageCommand } from 'vs/editor/browser/editorExtensions';
import { Position } from 'vs/editor/common/core/position';
import { ITextModel } from 'vs/editor/common/model';
import { Hover, HoverProviderRegistry } from 'vs/editor/common/modes';

export function getHover(model: ITextModel, position: Position, token: CancellationToken): Promise<Hover[]> {

	const supports = HoverProviderRegistry.ordered(model);

	const promises = supports.map(support => {
		return Promise.resolve(support.provideHover(model, position, token)).then(hover => {
			return hover && isValid(hover) ? hover : undefined;
		}, err => {
			onUnexpectedExternalError(err);
			return undefined;
		});
	});

	return Promise.all(promises).then(coalesce);
}

registerDefaultLanguageCommand('_executeHoverProvider', (model, position) => getHover(model, position, CancellationToken.None));

function isValid(result: Hover) {
	const hasRange = (typeof result.range !== 'undefined');
	const hasHtmlContent = typeof result.contents !== 'undefined' && result.contents && result.contents.length > 0;
	return hasRange && hasHtmlContent;
}
