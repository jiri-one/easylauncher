package one.jiri.easylauncher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import java.lang.ref.WeakReference

class NotificationAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = WeakReference(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        clearReference()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        clearReference()
        super.onDestroy()
    }

    private fun clearReference() {
        if (activeService.get() === this) activeService.clear()
    }

    companion object {
        private var activeService = WeakReference<NotificationAccessibilityService>(null)

        fun openNotifications(): Boolean = try {
            activeService.get()?.performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS) ?: false
        } catch (_: RuntimeException) {
            false
        }

        fun isEnabled(context: Context): Boolean {
            val manager = context.getSystemService(AccessibilityManager::class.java) ?: return false
            val component = ComponentName(context, NotificationAccessibilityService::class.java)
            return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK).any {
                val info = it.resolveInfo.serviceInfo
                ComponentName(info.packageName, info.name) == component
            }
        }
    }
}
