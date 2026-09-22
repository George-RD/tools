import type { BlockStatement, File, Function as BabelFunction, Statement } from '@babel/types';
import type { namedTypes } from 'ast-types';
import { type SourceEdit } from './source-edits';
export type FunctionNode = BabelFunction;
export type FunctionSourceSnapshot = {
    body: FunctionNode['body'];
    functionNode: FunctionNode;
    statements: Statement[] | null;
};
export declare const captureFunctionSourceSnapshots: (ast: File) => FunctionSourceSnapshot[];
export declare const getFunctionSourceEditsForPrependedStatements: ({ indentationUnit, input, printNode, reprintBlockBodies, snapshots, }: {
    indentationUnit: string;
    input: string;
    printNode: (node: namedTypes.Node) => string;
    reprintBlockBodies: ReadonlySet<BlockStatement>;
    snapshots: FunctionSourceSnapshot[];
}) => {
    coveredRanges: {
        end: number;
        start: number;
    }[];
    edits: SourceEdit[];
};
