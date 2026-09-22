export type Nonce = {
    isStale: () => boolean;
};
export type NonceManager = ReturnType<typeof makeNonceManager>;
export declare const makeNonceManager: () => {
    createAsyncOperation: () => {
        isStale: () => boolean;
    };
};
