export type GetImageOptions = {
    /**
     * The format of the clipboard image to be converted to.
     */
    format: 'png' | 'jpeg';
    /**
     * Specify the quality of the returned image, between `0` and `1`. Defaults to `1` (highest quality).
     * Applicable only when `format` is set to `jpeg`, ignored otherwise.
     * @default 1
     */
    jpegQuality?: number;
};
export type ClipboardImage = {
    /**
     * A Base64-encoded string of the image data. Its format is dependent on the `format` option.
     * You can use it directly as the source of an `Image` element.
     *
     * > **NOTE:** The string is already prepended with `data:image/png;base64,` or `data:image/jpeg;base64,` prefix.
     * @example
     * ```ts
     * <Image
     *   source={{ uri: clipboardImage.data }}
     *   style={{ width: 200, height: 200 }}
     * />
     * ```
     */
    data: string;
    /**
     * Dimensions (`width` and `height`) of the image pasted from clipboard.
     */
    size: {
        width: number;
        height: number;
    };
};
/**
 * Type used to define what type of data is stored in the clipboard.
 */
export declare enum ContentType {
    PLAIN_TEXT = "plain-text",
    HTML = "html",
    IMAGE = "image",
    /**
     * @platform iOS
     */
    URL = "url"
}
/**
 * Type used to determine string format stored in the clipboard.
 */
export declare enum StringFormat {
    PLAIN_TEXT = "plainText",
    HTML = "html"
}
export type GetStringOptions = {
    /**
     * The target format of the clipboard string to be converted to, if possible.
     *
     * @default StringFormat.PLAIN_TEXT
     */
    preferredFormat?: StringFormat;
};
export type CommonSetClipboardOptions = {
    /**
     * Time-to-live (TTL) in seconds after which the clipboard content should automatically expire and be cleared.
     *
     * When the expiration time is reached, the clipboard will only be cleared if the content hasn't been
     * modified by the user (e.g., if they copied something else). This prevents accidentally clearing
     * content that the user intended to keep.
     *
     * If omitted, the content persists indefinitely until manually cleared or replaced.
     *
     * **Platform behavior:**
     * - **iOS**: Uses native `UIPasteboard` expiration. Content is cleared only if it matches what was originally set.
     * - **Android**: Uses `WorkManager` to schedule expiration. On Android 10 (API 29) and above, background clipboard
     *   access is restricted, so the content may be cleared unconditionally when the TTL expires, even if the user
     *   has since copied other content.
     *
     * @platform ios, android
     * @example
     * ```ts
     * // Clear clipboard after 5 minutes
     * await Clipboard.setStringAsync('sensitive data', { ttl: 300 });
     * ```
     */
    ttl?: number;
};
export type SetStringOptions = CommonSetClipboardOptions & {
    /**
     * The input format of the provided string.
     * Adjusting this option can help other applications interpret copied string properly.
     *
     * @default StringFormat.PLAIN_TEXT
     */
    inputFormat?: StringFormat;
};
export type SetUrlOptions = CommonSetClipboardOptions;
export type SetImageOptions = CommonSetClipboardOptions;
export type AcceptedContentType = 'plain-text' | 'image' | 'url' | 'html';
export type CornerStyleType = 'dynamic' | 'fixed' | 'capsule' | 'large' | 'medium' | 'small';
export type DisplayModeType = 'iconAndLabel' | 'iconOnly' | 'labelOnly';
export type PasteEventPayload = TextPasteEvent | ImagePasteEvent;
export type TextPasteEvent = {
    text: string;
    type: 'text';
};
export type ImagePasteEvent = {
    type: 'image';
} & ClipboardImage;
export type ClipboardEvent = {
    /**
     * An array of content types that are available on the clipboard.
     */
    contentTypes: ContentType[];
};
//# sourceMappingURL=Clipboard.types.d.ts.map