type FileLocation = {
    readonly source: string | null;
    readonly line: number | null;
};
export type RelativeFileLocation = {
    readonly filename: string;
    readonly line: number;
};
export declare const getRelativeFileLocation: ({ location, root, }: {
    readonly location: FileLocation | null;
    readonly root: string;
}) => RelativeFileLocation | null;
export declare const formatFileLocation: ({ location, root, }: {
    readonly location: FileLocation | null;
    readonly root: string;
}) => string | null;
export declare const formatContextForAgents: ({ name, location, root, }: {
    readonly name: string | null;
    readonly location: FileLocation | null;
    readonly root: string;
}) => string | null;
export {};
