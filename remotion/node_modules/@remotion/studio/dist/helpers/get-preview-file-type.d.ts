export type AssetFileType = 'audio' | 'font' | 'video' | 'image' | 'json' | 'lut' | 'txt' | 'other';
export declare const getPreviewFileType: (fileName: string | null) => AssetFileType;
