export type EmbeddedFontStyle = {
    blob: Blob;
    cacheKey: string;
    css: string;
};
export declare const getEmbeddedFontStyleForSvg: (svg: SVGSVGElement) => EmbeddedFontStyle | null;
