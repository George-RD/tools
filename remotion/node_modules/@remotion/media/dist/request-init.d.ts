export type MediaHeadersInit = Record<string, string> | [string, string][];
export type MediaRequestInit = {
    cache?: RequestCache;
    credentials?: RequestCredentials;
    headers?: MediaHeadersInit;
    integrity?: string;
    mode?: RequestMode;
    redirect?: RequestRedirect;
    referrer?: string;
    referrerPolicy?: ReferrerPolicy;
};
export type MediaRequestInitOptions = {
    credentials: RequestCredentials | undefined;
    requestInit: MediaRequestInit | undefined;
};
export declare const normalizeMediaHeaders: (headers: HeadersInit | undefined) => [string, string][] | undefined;
export declare const normalizeMediaRequestInit: (requestInit: MediaRequestInit | undefined) => MediaRequestInit | undefined;
export declare const getMediaRequestInitFingerprint: (requestInit: MediaRequestInit | undefined) => (string | [string, string][] | Record<string, string> | null)[] | null;
export declare const resolveRequestInit: ({ credentials, requestInit, }: MediaRequestInitOptions) => MediaRequestInit | undefined;
