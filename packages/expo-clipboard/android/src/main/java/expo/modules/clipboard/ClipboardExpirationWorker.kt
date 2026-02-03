package expo.modules.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import androidx.work.Worker
import androidx.work.WorkerParameters

class ClipboardExpirationWorker(
  appContext: Context,
  workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

  companion object {
    private val TAG = ClipboardExpirationWorker::class.java.simpleName
  }

  override fun doWork(): Result {
    android.util.Log.d(TAG, "ClipboardExpirationWorker started")

    val clipboardManager = applicationContext
      .getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
      ?: return Result.failure().also {
        android.util.Log.e(TAG, "Clipboard service unavailable")
      }

    val originalText = inputData.getString("originalText")
    android.util.Log.d(TAG, "Original text: '$originalText'")

    if (shouldClearClipboard(clipboardManager, originalText)) {
      android.util.Log.d(TAG, "Clearing clipboard")
      clearClipboard(clipboardManager)
    } else {
      android.util.Log.d(TAG, "Not clearing clipboard - content has changed")
    }

    return Result.success()
  }

  /**
   * Determines whether the clipboard should be cleared based on content comparison.
   *
   * Compares the current clipboard content with the original text that was set. The clipboard
   * should be cleared if:
   * - The content matches the original (user hasn't copied anything else)
   * - The clipboard is empty
   * - Reading the clipboard fails (e.g., due to Android 10+ background restrictions)
   *
   * This conditional clearing prevents accidentally removing content that the user intended
   * to keep, while ensuring expired sensitive content is removed as requested.
   */
  private fun shouldClearClipboard(
    clipboardManager: ClipboardManager,
    originalText: String?
  ): Boolean {
    return try {
      val currentText = clipboardManager.primaryClip
        ?.takeIf { it.itemCount > 0 }
        ?.getItemAt(0)
        ?.coerceToText(applicationContext)
        ?.toString()

      android.util.Log.d(TAG, "Current text: '$currentText'")
      android.util.Log.d(TAG, "Comparison: currentText='$currentText' vs originalText='$originalText'")

      val shouldClear = currentText == null || currentText == originalText
      android.util.Log.d(TAG, "Should clear: $shouldClear")

      shouldClear
    } catch (e: Throwable) {
      // If reading fails (e.g., background restrictions on Android 10+),
      // clear the clipboard to ensure TTL behavior is respected
      android.util.Log.e(TAG, "Error reading clipboard, will clear", e)
      true
    }
  }

  /**
   * Clears the clipboard using the appropriate method for the current API level.
   *
   * - **API 28+ (Android P):** Uses the native [ClipboardManager.clearPrimaryClip] method
   * - **API 27 and below:** Sets a zero-width space character (`\u200B`) as a fallback,
   *   since `clearPrimaryClip()` doesn't exist on older Android versions
   */
  private fun clearClipboard(clipboardManager: ClipboardManager) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      clipboardManager.clearPrimaryClip()
    } else {
      clipboardManager.setPrimaryClip(ClipData.newPlainText(null, "\u200B"))
    }
  }
}
