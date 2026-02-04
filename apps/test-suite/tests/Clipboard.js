import * as Clipboard from 'expo-clipboard';
import { Platform } from 'react-native';

export const name = 'Clipboard';

export function test({ describe, expect, it, afterEach, ...t }) {
  describe('Clipboard', () => {
    const throws = async (run) => {
      let error = null;
      try {
        await run();
      } catch (e) {
        error = e;
      }
      expect(error).toBeTruthy();
    };

    afterEach(async () => {
      await Clipboard.setStringAsync('');
    });

    describe('Strings', () => {
      it('sets and gets a string', async () => {
        await Clipboard.setStringAsync('test string');
        const result = await Clipboard.getStringAsync();
        expect(result).toEqual('test string');
      });

      it('checks if clipboard has string content', async () => {
        await Clipboard.setStringAsync('test string');
        const result = await Clipboard.hasStringAsync();
        expect(result).toBe(true);
      });

      it('gets and sets HTML string', async () => {
        await Clipboard.setStringAsync('<p>test</p>', {
          inputFormat: Clipboard.StringFormat.HTML,
        });
        const result = await Clipboard.getStringAsync({
          preferredFormat: Clipboard.StringFormat.HTML,
        });
        // The OS can add some atributes or inner tags to the HTML string, so we can't just
        // check for equality.
        expect(/<p(\s.*)?>(<.*>)?test(<\/.*>)?<\/p>/gi.test(result)).toBe(true);
      });

      it('gets plain text from copied HTML', async () => {
        await Clipboard.setStringAsync('<p>test</p>', {
          inputFormat: Clipboard.StringFormat.HTML,
        });
        const result = await Clipboard.getStringAsync({
          preferredFormat: Clipboard.StringFormat.PLAIN_TEXT,
        });
        expect(result.trim()).toEqual('test');
      });

      it('falls back to plain text if no HTML is copied', async () => {
        await Clipboard.setStringAsync('test', { inputFormat: Clipboard.StringFormat.PLAIN_TEXT });
        const result = await Clipboard.getStringAsync({
          preferredFormat: Clipboard.StringFormat.HTML,
        });
        expect(result).toEqual('test');
      });
    });

    if (Platform.OS === 'ios') {
      describe('URLs', () => {
        it('sets and gets an url', async () => {
          const exampleUrl = 'https://example.com';
          let hasUrl = await Clipboard.hasUrlAsync();
          expect(hasUrl).toEqual(false);
          await Clipboard.setUrlAsync(exampleUrl);
          hasUrl = await Clipboard.hasUrlAsync();
          expect(hasUrl).toEqual(true);
          const result = await Clipboard.getUrlAsync();
          expect(result).toEqual(exampleUrl);
        });
      });
    }

    describe('Images', () => {
      it('sets and gets a png image', async () => {
        const imageBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
        const expectedResultRegex = 'data:image/png;base64,[A-Za-z0-9+/=]*';
        let hasImage = await Clipboard.hasImageAsync();
        expect(hasImage).toEqual(false);
        await Clipboard.setImageAsync(imageBase64);
        hasImage = await Clipboard.hasImageAsync();
        expect(hasImage).toEqual(true);
        const result = await Clipboard.getImageAsync({ format: 'png' });
        expect(result.data).toMatch(expectedResultRegex);
      });

      if (Platform.OS !== 'web') {
        it('sets and gets a jpg image', async () => {
          const imageBase64 =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
          const expectedResultRegex = 'data:image/jpeg;base64,[A-Za-z0-9+/=]*';
          let hasImage = await Clipboard.hasImageAsync();
          expect(hasImage).toEqual(false);
          await Clipboard.setImageAsync(imageBase64);
          hasImage = await Clipboard.hasImageAsync();
          expect(hasImage).toEqual(true);
          const result = await Clipboard.getImageAsync({ format: 'jpeg' });
          expect(result.data).toMatch(expectedResultRegex);
        });

        it('rejects invalid base64', async () => {
          const imageBase64 = 'invalid';
          await throws(() => Clipboard.setImageAsync(imageBase64));
          const hasImage = await Clipboard.hasImageAsync();
          expect(hasImage).toEqual(false);
        });
      }
    });

    describe('TTL (Time To Live)', () => {
      it('clears plain text after TTL expires', async () => {
        const testText = 'sensitive data';
        await Clipboard.setStringAsync(testText, { ttl: 2 });

        // Verify content is set
        let result = await Clipboard.getStringAsync();
        expect(result).toEqual(testText);

        // Wait for TTL to expire
        await new Promise((resolve) => setTimeout(resolve, 2500));

        // Verify content is cleared
        result = await Clipboard.getStringAsync();
        expect(result).toEqual('');
      });

      it('clears HTML text after TTL expires', async () => {
        const testHtml = '<p>sensitive html</p>';
        await Clipboard.setStringAsync(testHtml, {
          inputFormat: Clipboard.StringFormat.HTML,
          ttl: 2,
        });

        // Verify content is set
        let result = await Clipboard.getStringAsync({
          preferredFormat: Clipboard.StringFormat.HTML,
        });
        expect(/<p(\s.*)?>(<.*>)?sensitive html(<\/.*>)?<\/p>/gi.test(result)).toBe(true);

        // Wait for TTL to expire
        await new Promise((resolve) => setTimeout(resolve, 2500));

        // Verify content is cleared
        result = await Clipboard.getStringAsync();
        expect(result).toEqual('');
      });

      it('does not clear clipboard if content was changed by user', async () => {
        const originalText = 'original text';
        const newText = 'user changed this';

        await Clipboard.setStringAsync(originalText, { ttl: 2 });

        // User changes clipboard content before TTL expires
        await new Promise((resolve) => setTimeout(resolve, 500));
        await Clipboard.setStringAsync(newText);

        // Wait for original TTL to expire
        await new Promise((resolve) => setTimeout(resolve, 2000));

        // Verify new content is still there (not cleared)
        const result = await Clipboard.getStringAsync();
        expect(result).toEqual(newText);
      });

      it('replaces previous TTL when setting new content', async () => {
        // Set first content with long TTL
        await Clipboard.setStringAsync('first content', { ttl: 10 });

        // Immediately set second content with short TTL
        await Clipboard.setStringAsync('second content', { ttl: 2 });

        // Wait for second TTL to expire
        await new Promise((resolve) => setTimeout(resolve, 2500));

        // Verify clipboard is cleared (second TTL took effect)
        const result = await Clipboard.getStringAsync();
        expect(result).toEqual('');
      });

      if (Platform.OS !== 'web') {
        it('clears image after TTL expires', async () => {
          const imageBase64 =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

          await Clipboard.setImageAsync(imageBase64, { ttl: 2 });

          // Verify image is set
          let hasImage = await Clipboard.hasImageAsync();
          expect(hasImage).toBe(true);

          // Wait for TTL to expire
          await new Promise((resolve) => setTimeout(resolve, 2500));

          // Verify image is cleared
          hasImage = await Clipboard.hasImageAsync();
          expect(hasImage).toBe(false);
        });
      }

      if (Platform.OS === 'ios') {
        it('clears URL after TTL expires', async () => {
          const exampleUrl = 'https://example.com';

          await Clipboard.setUrlAsync(exampleUrl, { ttl: 2 });

          // Verify URL is set
          let hasUrl = await Clipboard.hasUrlAsync();
          expect(hasUrl).toBe(true);

          // Wait for TTL to expire
          await new Promise((resolve) => setTimeout(resolve, 2500));

          // Verify URL is cleared
          hasUrl = await Clipboard.hasUrlAsync();
          expect(hasUrl).toBe(false);
        });
      }
    });
  });
}
