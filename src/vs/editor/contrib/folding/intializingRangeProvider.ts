/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ITextModel, IModelDeltaDecoration, TrackedRangeStickiness } from 'vs/editor/common/model';
import { FoldingRegions, ILineRange } from 'vs/editor/contrib/folding/foldingRanges';
import { RangeProvider } from './folding';
import { CancellationToken } from 'vs/base/common/cancellation';
import { IFoldingRangeData, sanitizeRanges } from 'vs/editor/contrib/folding/syntaxRangeProvider';

export const ID_INIT_PROVIDER = 'init';

export class InitializingRangeProvider implements RangeProvider {
	readonly id = ID_INIT_PROVIDER;

	private decorationIds: string[] | undefined;
	private timeout: any;

	constructor(private editorModel: ITextModel, initialRanges: ILineRange[], onTimeout: () => void, timeoutTime: number) {
		if (initialRanges.length) {
			let toDecorationRange = (range: ILineRange): IModelDeltaDecoration => {
				return {
					range: {
						startLineNumber: range.startLineNumber,
						startColumn: 0,
						endLineNumber: range.endLineNumber,
						endColumn: editorModel.getLineLength(range.endLineNumber)
					},
					options: {
						stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
					}
				};
			};
			this.decorationIds = editorModel.deltaDecorations([], initialRanges.map(toDecorationRange));
			this.timeout = setTimeout(onTimeout, timeoutTime);
		}
	}

	dispose(): void {
		if (this.decorationIds) {
			this.editorModel.deltaDecorations(this.decorationIds, []);
			this.decorationIds = void 0;
		}
		if (typeof this.timeout === 'number') {
			clearTimeout(this.timeout);
			this.timeout = void 0;
		}
	}

	compute(cancelationToken: CancellationToken): Thenable<FoldingRegions> {
		let foldingRangeData: IFoldingRangeData[] = [];
		if (this.decorationIds) {
			for (let id of this.decorationIds) {
				let range = this.editorModel.getDecorationRange(id);
				if (range) {
					foldingRangeData.push({ start: range.startLineNumber, end: range.endLineNumber, rank: 1 });
				}
			}
		}
		return Promise.resolve(sanitizeRanges(foldingRangeData, Number.MAX_VALUE));
	}
}

