package expo.modules.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import androidx.work.Data
import androidx.work.testing.TestListenableWorkerBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.P])
class ClipboardExpirationWorkerTest {

  private val context: Context
    get() = ApplicationProvider.getApplicationContext()

  private val clipboardManager: ClipboardManager
    get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

  @Test
  fun `should clear clipboard when original text matches`() {
    // Setup: Set clipboard content
    val originalText = "sensitive data"
    clipboardManager.setPrimaryClip(ClipData.newPlainText(null, originalText))

    // Create worker with original text
    val inputData = Data.Builder()
      .putString("originalText", originalText)
      .build()

    val worker = TestListenableWorkerBuilder<ClipboardExpirationWorker>(context)
      .setInputData(inputData)
      .build()

    // Execute worker
    val result = worker.doWork()

    // Assert success and clipboard is cleared
    assertEquals(androidx.work.ListenableWorker.Result.success(), result)
    val clipboardContent = clipboardManager.primaryClip
      ?.takeIf { it.itemCount > 0 }
      ?.getItemAt(0)
      ?.coerceToText(context)
      ?.toString()

    // Clipboard should be cleared
    assertNull(clipboardContent)
  }

  // Tests for API < 28 (Pre-Android P) - uses zero-width space fallback
  @Test
  @Config(sdk = [Build.VERSION_CODES.O])
  fun `should clear clipboard using zero-width space when original text matches on API 27`() {
    // Setup: Set clipboard content
    val originalText = "sensitive data"
    clipboardManager.setPrimaryClip(ClipData.newPlainText(null, originalText))

    // Create worker with original text
    val inputData = Data.Builder()
      .putString("originalText", originalText)
      .build()

    val worker = TestListenableWorkerBuilder<ClipboardExpirationWorker>(context)
      .setInputData(inputData)
      .build()

    // Execute worker
    val result = worker.doWork()

    // Assert success
    assertEquals(androidx.work.ListenableWorker.Result.success(), result)

    // On API < 28, clipboard should be set to zero-width space
    val clipboardContent = clipboardManager.primaryClip
      ?.getItemAt(0)
      ?.coerceToText(context)
      ?.toString()

    assertEquals("\u200B", clipboardContent)
  }

  @Test
  fun `should not clear clipboard when content has changed`() {
    // Setup: Set clipboard with different content
    val originalText = "original content"
    val newText = "user changed this"
    clipboardManager.setPrimaryClip(ClipData.newPlainText(null, newText))

    // Create worker with original text
    val inputData = Data.Builder()
      .putString("originalText", originalText)
      .build()

    val worker = TestListenableWorkerBuilder<ClipboardExpirationWorker>(context)
      .setInputData(inputData)
      .build()

    // Execute worker
    val result = worker.doWork()

    // Assert success and clipboard content is unchanged
    assertEquals(androidx.work.ListenableWorker.Result.success(), result)
    val clipboardContent = clipboardManager.primaryClip
      ?.getItemAt(0)
      ?.coerceToText(context)
      ?.toString()

    assertEquals(newText, clipboardContent)
  }

  @Test
  fun `should clear clipboard when original text is empty`() {
    // Setup: Set clipboard with empty content
    clipboardManager.setPrimaryClip(ClipData.newPlainText(null, ""))

    // Create worker with empty original text
    val inputData = Data.Builder()
      .putString("originalText", "")
      .build()

    val worker = TestListenableWorkerBuilder<ClipboardExpirationWorker>(context)
      .setInputData(inputData)
      .build()

    // Execute worker
    val result = worker.doWork()

    // Assert success and clipboard is cleared
    assertEquals(androidx.work.ListenableWorker.Result.success(), result)
    val clipboardContent = clipboardManager.primaryClip
      ?.takeIf { it.itemCount > 0 }
      ?.getItemAt(0)
      ?.coerceToText(context)
      ?.toString()

    // Clipboard should be cleared
    assertNull(clipboardContent)
  }

  @Test
  fun `should handle empty clipboard gracefully`() {
    // Setup: Clear clipboard
    clipboardManager.clearPrimaryClip()

    // Create worker with some original text
    val inputData = Data.Builder()
      .putString("originalText", "some text")
      .build()

    val worker = TestListenableWorkerBuilder<ClipboardExpirationWorker>(context)
      .setInputData(inputData)
      .build()

    // Execute worker
    val result = worker.doWork()

    // Assert success - should handle empty clipboard without errors
    assertEquals(androidx.work.ListenableWorker.Result.success(), result)
  }
}
