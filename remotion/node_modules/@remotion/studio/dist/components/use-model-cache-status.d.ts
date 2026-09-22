export declare const useModelCacheStatus: <Model extends string>({ isModelCached, models, refreshKey, }: {
    readonly isModelCached: (model: Model) => Promise<boolean>;
    readonly models: readonly {
        readonly name: Model;
    }[];
    readonly refreshKey: string;
}) => ReadonlySet<Model>;
