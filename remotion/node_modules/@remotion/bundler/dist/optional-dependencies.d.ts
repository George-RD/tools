import type { Compiler } from 'webpack';
export declare class AllowOptionalDependenciesPlugin {
    filter(error: Error & {
        module?: {
            resource?: string;
            resourceResolveData?: {
                descriptionFileData?: {
                    name?: string;
                };
            };
        };
    }): boolean;
    apply(compiler: Compiler): void;
}
