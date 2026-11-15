package id.nara.voice.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import id.nara.voice.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

/**
 * Optional accessibility service backing NARA's screen-understanding features.
 *
 * Safety contract (enforced here, not just in docs):
 *  - Password fields are never read: nodes with isPassword are skipped entirely,
 *    including their text, ids and bounds.
 *  - The service never initiates actions by itself; every tap / type / scroll is
 *    a direct response to a Flutter call that originated from a user command.
 *  - No screen content is written to disk or logged; inspection results exist
 *    only long enough to answer the current request.
 *  - NARA never bypasses authentication, CAPTCHA or financial confirmations —
 *    high-risk confirmations remain user-controlled in the app layer.
 */
class NaraAccessibilityService : AccessibilityService() {

    private val executor = Executors.newSingleThreadExecutor()
    private val currentPackageRef = AtomicReference<String?>(null)

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            event.packageName?.toString()?.let { currentPackageRef.set(it) }
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        executor.shutdown()
        super.onDestroy()
    }

    // ===== Inspection =====

    /**
     * Builds the snapshot with plain Kotlin maps/lists ONLY. org.json types
     * (JSONObject/JSONArray) are NOT encodable by Flutter's
     * StandardMessageCodec — returning them throws IllegalArgumentException
     * on the main thread and kills the process.
     */
    fun performInspect(onDone: (Map<String, Any?>) -> Unit) {
        executor.execute {
            val snapshot: Map<String, Any?> = try {
                inspectNow()
            } catch (e: Exception) {
                // A worker-thread failure must neither crash the process nor
                // leave the Dart future dangling: report an honest empty state.
                mapOf(
                    "status" to "empty",
                    "timestamp" to System.currentTimeMillis(),
                    "visibleText" to "",
                    "elements" to emptyList<Map<String, Any?>>(),
                    "truncated" to false,
                    "nodeCount" to 0,
                )
            }
            runOnMain { onDone(snapshot) }
        }
    }

    private fun inspectNow(): Map<String, Any?> {
        val root = rootInActiveWindow
        val output = HashMap<String, Any?>()
        output["timestamp"] = System.currentTimeMillis()
        if (root == null) {
            output["status"] = "empty"
            return output
        }
        try {
            output["status"] = "ok"
            output["packageName"] = root.packageName?.toString()
            if (Build.VERSION.SDK_INT >= 24) {
                val window = windows.firstOrNull { it.isActive || it.isFocused }
                output["windowTitle"] = window?.title?.toString()
            }
            val textBuilder = StringBuilder()
            val elements = ArrayList<Map<String, Any?>>()
            var nodeCount = 0
            var truncated = false
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            val visited = HashSet<AccessibilityNodeInfo>()

            while (queue.isNotEmpty()) {
                if (nodeCount >= MAX_NODES) {
                    truncated = true
                    break
                }
                val node = queue.removeFirst()
                if (!visited.add(node)) continue
                nodeCount++

                val isPassword = node.isPassword
                if (!isPassword) {
                    val text = node.text?.toString()?.trim()
                    val description = node.contentDescription?.toString()?.trim()
                    val className = node.className?.toString()
                    if (node.isClickable || node.isEditable || node.isScrollable || node.isCheckable) {
                        val element = HashMap<String, Any?>()
                        element["id"] = "e${elements.size}"
                        element["text"] = text
                        element["contentDescription"] = description
                        element["className"] = className
                        element["viewId"] = node.viewIdResourceName
                        element["clickable"] = node.isClickable
                        element["editable"] = node.isEditable
                        element["scrollable"] = node.isScrollable
                        element["checkable"] = node.isCheckable
                        element["checked"] = node.isChecked
                        val bounds = Rect()
                        node.getBoundsInScreen(bounds)
                        element["bounds"] = listOf(bounds.left, bounds.top, bounds.right, bounds.bottom)
                        element["visible"] = node.isVisibleToUser
                        elements.add(element)
                    }
                    if (!text.isNullOrEmpty()) {
                        appendVisibleText(textBuilder, text)
                    } else if (!description.isNullOrEmpty() && !node.isClickable) {
                        appendVisibleText(textBuilder, description)
                    }
                }

                if (textBuilder.length < MAX_TEXT_LENGTH) {
                    for (i in 0 until node.childCount) {
                        node.getChild(i)?.let { queue.add(it) }
                    }
                }
            }

            output["visibleText"] = textBuilder.toString().take(MAX_TEXT_LENGTH)
            output["elements"] = elements
            output["truncated"] = truncated
            output["nodeCount"] = nodeCount

            root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.let { focused ->
                if (!focused.isPassword) {
                    val focusedMap = HashMap<String, Any?>()
                    focusedMap["text"] = focused.text?.toString()
                    focusedMap["viewId"] = focused.viewIdResourceName
                    focusedMap["editable"] = focused.isEditable
                    focusedMap["className"] = focused.className?.toString()
                    output["focused"] = focusedMap
                }
            }
        } finally {
            root.recycleCompat()
        }
        return output
    }

    private fun appendVisibleText(builder: StringBuilder, text: String) {
        if (builder.isNotEmpty()) builder.append("\n")
        builder.append(text.take(MAX_LINE_LENGTH))
    }

    // ===== Actions =====

    fun tapElement(element: JSONObject, onDone: (Boolean) -> Unit) {
        executor.execute {
            val performed: Boolean = try {
                findNodeBySignature(element) { node -> node.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
                    ?: tapAtBounds(element.optJSONArray("bounds"))
            } catch (e: Exception) {
                false // Stale nodes / OEM quirks: report failure, never crash.
            }
            runOnMain { onDone(performed) }
        }
    }

    fun inputText(element: JSONObject, value: String, onDone: (Boolean) -> Unit) {
        executor.execute {
            val performed: Boolean = try {
                findNodeBySignature(element, requireEditable = true) { node ->
                    val args = Bundle()
                    args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
                    node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                } == true
            } catch (e: Exception) {
                false
            }
            runOnMain { onDone(performed) }
        }
    }

    fun scroll(forward: Boolean, onDone: (Boolean) -> Unit) {
        executor.execute {
            val performed: Boolean = try {
                val root = rootInActiveWindow
                var done = false
                if (root != null) {
                    done = findScrollable(root, forward)
                    root.recycleCompat()
                }
                if (!done) done = gestureSwipe(forward)
                done
            } catch (e: Exception) {
                false
            }
            runOnMain { onDone(performed) }
        }
    }

    fun goBack(onDone: (Boolean) -> Unit) {
        val performed = performGlobalAction(GLOBAL_ACTION_BACK)
        runOnMain { onDone(performed) }
    }

    fun currentApp(onDone: (String?) -> Unit) {
        val root = rootInActiveWindow
        val pkg = root?.packageName?.toString() ?: currentPackageRef.get()
        root?.recycleCompat()
        runOnMain { onDone(pkg) }
    }

    // ===== Node matching helpers =====

    private fun findNodeBySignature(
        element: JSONObject,
        requireEditable: Boolean = false,
        action: (AccessibilityNodeInfo) -> Boolean,
    ): Boolean? {
        val root = rootInActiveWindow ?: return null
        try {
            val viewId = element.optString("viewId", "").takeIf { it.isNotEmpty() }
            val bounds = element.optJSONArray("bounds")
            var matched: AccessibilityNodeInfo? = null
            if (viewId != null) {
                val candidates = root.findAccessibilityNodeInfosByViewId(viewId)
                matched = candidates.firstOrNull { node ->
                    (!requireEditable || node.isEditable) &&
                        (!node.isPassword) &&
                        (bounds == null || boundsMatch(node, bounds))
                }
                if (matched == null && bounds == null) {
                    matched = candidates.firstOrNull { !it.isPassword }
                }
            }
            if (matched == null && bounds != null) {
                matched = findByBounds(root, bounds)
            }
            val node = matched ?: return null
            if (requireEditable && !node.isEditable) return false
            if (node.isPassword) return false
            return action(node)
        } finally {
            root.recycleCompat()
        }
    }

    private fun findByBounds(root: AccessibilityNodeInfo, bounds: JSONArray): AccessibilityNodeInfo? {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var steps = 0
        while (queue.isNotEmpty() && steps < MAX_NODES) {
            steps++
            val node = queue.removeFirst()
            if (boundsMatch(node, bounds)) return node
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return null
    }

    private fun boundsMatch(node: AccessibilityNodeInfo, bounds: JSONArray): Boolean {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        return rect.left == bounds.optInt(0) &&
            rect.top == bounds.optInt(1) &&
            rect.right == bounds.optInt(2) &&
            rect.bottom == bounds.optInt(3)
    }

    private fun findScrollable(root: AccessibilityNodeInfo, forward: Boolean): Boolean {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var steps = 0
        while (queue.isNotEmpty() && steps < MAX_NODES) {
            steps++
            val node = queue.removeFirst()
            if (node.isPassword) continue
            if (node.isScrollable) {
                val action = if (forward) {
                    AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                } else {
                    AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                }
                if (node.performAction(action)) return true
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return false
    }

    // ===== Gestures =====

    private fun tapAtBounds(bounds: JSONArray?): Boolean {
        if (bounds == null || bounds.length() < 4) return false
        val left = bounds.optInt(0)
        val top = bounds.optInt(1)
        val right = bounds.optInt(2)
        val bottom = bounds.optInt(3)
        if (right <= left || bottom <= top) return false
        val x = left + (right - left) / 2
        val y = top + (bottom - top) / 2
        return dispatchTap(x, y)
    }

    private fun dispatchTap(x: Int, y: Int): Boolean {
        if (Build.VERSION.SDK_INT < 24) return false
        val stroke = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(buildPath(x, y), 0, 60))
            .build()
        var result = false
        val latch = java.util.concurrent.CountDownLatch(1)
        dispatchGesture(stroke, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                result = true
                latch.countDown()
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                result = false
                latch.countDown()
            }
        }, null)
        latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
        return result
    }

    private fun buildPath(x: Int, y: Int): android.graphics.Path {
        val path = android.graphics.Path()
        path.moveTo(x.toFloat(), y.toFloat())
        path.lineTo(x.toFloat() + 0.1f, y.toFloat() + 0.1f)
        return path
    }

    private fun gestureSwipe(forward: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < 24) return false
        val metrics = resources.displayMetrics
        val centerX = metrics.widthPixels / 2
        val startY = if (forward) (metrics.heightPixels * 0.7f).toInt() else (metrics.heightPixels * 0.3f).toInt()
        val endY = if (forward) (metrics.heightPixels * 0.3f).toInt() else (metrics.heightPixels * 0.7f).toInt()
        val builder = GestureDescription.Builder()
        val path = android.graphics.Path()
        path.moveTo(centerX.toFloat(), startY.toFloat())
        path.lineTo(centerX.toFloat(), endY.toFloat())
        builder.addStroke(GestureDescription.StrokeDescription(path, 0, 220))
        var result = false
        val latch = java.util.concurrent.CountDownLatch(1)
        dispatchGesture(builder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                result = true
                latch.countDown()
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                result = false
                latch.countDown()
            }
        }, null)
        latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
        return result
    }

    private fun runOnMain(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    companion object {
        private const val MAX_NODES = 400
        private const val MAX_TEXT_LENGTH = 6000
        private const val MAX_LINE_LENGTH = 400

        @Volatile
        var instance: NaraAccessibilityService? = null
            private set

        val isConnected: Boolean get() = instance != null
    }
}

/** AccessibilityNodeInfo.recycle() was removed in API 33; pooling is managed by the OS. */
private fun AccessibilityNodeInfo.recycleCompat() {
    if (Build.VERSION.SDK_INT < 33) {
        @Suppress("DEPRECATION")
        try {
            recycle()
        } catch (e: Exception) {
            // Node already recycled by the framework.
        }
    }
}
