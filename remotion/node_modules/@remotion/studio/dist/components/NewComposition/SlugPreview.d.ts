import React from 'react';
export declare const SlugPreview: React.FC<{
    readonly action: 'create' | 'rename';
    readonly currentName: string | null;
    readonly input: string;
    readonly slug: string;
}>;
