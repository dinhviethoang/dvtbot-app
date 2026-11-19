package com.lhht.ai_assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * User-enabled accessibility bridge.
 *
 * This service provides bounded primitives only. The AI must send an explicit,
 * validated action from an allow-listed command dispatcher. Do not scrape or
 * transmit password fields, payment data, private messages, or other sensitive
 * screen content to a remote model.
 */
class XiaozhiAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "XiaozhiAccessibility"
        @Volatile var instance: XiaozhiAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        serviceInfo = serviceInfo.apply {
            flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally do not collect screen text automatically.
        // Query the active window only in response to a user-authorized action.
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility interrupted")
    }

    fun performBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun openRecents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)

    private val prohibitedKeywords = listOf(
        "thanh toan", "thanh toán", "pay", "payment",
        "mua", "mua ngay", "buy", "purchase",
        "chuyen khoan", "chuyển khoản", "transfer",
        "xoa", "xóa", "delete", "destroy", "format",
        "gui", "gửi", "send", "post", "dang bai", "đăng bài",
        "mat khau", "mật khẩu", "password", "pin", "otp",
        "bao mat", "bảo mật", "security"
    )

    fun clickVisibleText(label: String): Boolean {
        val safeLabel = label.trim()
        if (safeLabel.isEmpty() || safeLabel.length > 120) return false

        // Kiểm tra danh sách từ khóa nguy hại / có hậu quả tài chính, bảo mật
        val lower = safeLabel.lowercase()
        if (prohibitedKeywords.any { lower.contains(it) }) {
            Log.w(TAG, "Từ chối nhấn tự động vào nút nguy hiểm / có hậu quả: '$safeLabel'")
            return false
        }

        val root = rootInActiveWindow ?: return false
        return try {
            val nodes = root.findAccessibilityNodeInfosByText(safeLabel)
            val target = nodes.firstOrNull { it.isVisibleToUser && it.isEnabled }
            target?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
        } finally {
            root.recycle()
        }
    }

    fun scrollForward(): Boolean {
        val root = rootInActiveWindow ?: return false
        return try {
            val target = findScrollableNode(root) ?: root
            target.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
        } finally {
            root.recycle()
        }
    }

    private fun findScrollableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isScrollable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findScrollableNode(child)
            if (found != null) return found
        }
        return null
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }
}
