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

  override fun doWork(): Result {
    val clipboardManager = applicationContext
      .getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
      ?: return Result.failure() // Clipboard service unavailable

    val originalText = inputData.getString("originalText")

    if (shouldClearClipboard(clipboardManager, originalText)) {
      clearClipboard(clipboardManager)
    }

    return Result.success()
  }

  /**
   * Checks whether the clipboard should be cleared.
   * Attempts to compare the current clipboard content with the original text.
   * If reading fails, or if the content matches the original, it should be cleared.
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

      currentText == null || currentText == originalText
    } catch (_: Throwable) {
      true
    }
  }

  /**
   * Clears the clipboard content based on API level.
   * On Android P+, uses [ClipboardManager.clearPrimaryClip].
   * On lower versions, sets a zero-width space to simulate clearing.
   */
  private fun clearClipboard(clipboardManager: ClipboardManager) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      clipboardManager.clearPrimaryClip()
    } else {
      clipboardManager.setPrimaryClip(ClipData.newPlainText(null, "\u200B"))
    }
  }
}
