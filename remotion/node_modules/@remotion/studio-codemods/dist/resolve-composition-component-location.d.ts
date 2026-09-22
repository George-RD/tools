import type { Node } from '@babel/types';
export type SourceMapProject = {
    files: Record<string, string>;
    rootDir: string;
};
export type ResolvedCompositionComponentInProject = {
    canAddSequence: boolean;
    declaration: Node;
    exportName: string | 'default';
    filePath: string;
    location: {
        column: number;
        line: number;
        source: string;
    };
    root: Node;
    source: string;
};
export declare const resolveCompositionComponentInProject: ({ compositionFile, compositionId, project, }: {
    compositionFile: string;
    compositionId: string;
    project: SourceMapProject;
}) => ResolvedCompositionComponentInProject;
export declare const resolveCompositionComponentLocation: ({ compositionFile, compositionId, project, }: {
    compositionFile: string;
    compositionId: string;
    project: SourceMapProject;
}) => {
    source: string;
    line: number;
    column: number;
};
