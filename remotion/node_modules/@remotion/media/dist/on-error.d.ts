export type MediaErrorEvent = {
    error: Error;
};
export type MediaErrorAction = 'fallback' | 'fail';
export type MediaOnError = (error: Error) => MediaErrorAction | undefined;
export declare const callOnErrorAndResolve: ({ onError, error, disallowFallback, isClientSideRendering, clientSideError, }: {
    onError: MediaOnError | undefined;
    error: Error;
    clientSideError: Error;
    disallowFallback: boolean;
    isClientSideRendering: boolean;
}) => [MediaErrorAction, Error];
