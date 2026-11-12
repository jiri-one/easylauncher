package one.jiri.easylauncher

import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.view.View
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val settings by lazy { getSharedPreferences("launcher", Context.MODE_PRIVATE) }
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false
    private var pendingHome = false

    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.data?.scheme == "package" && intent.action in PACKAGE_ACTIONS) {
                emit("appsChanged")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureSystemBars()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methodChannel = MethodChannel(messenger, "one.jiri.easylauncher/platform").also {
            it.setMethodCallHandler { call, result ->
                if (call.method in setOf("getApps", "loadSettings", "saveSettings")) {
                    worker.execute { handleMethodCall(call, result) }
                } else {
                    handleMethodCall(call, result)
                }
            }
        }
        eventChannel = EventChannel(messenger, "one.jiri.easylauncher/events").also {
            it.setStreamHandler(this)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        stopListening()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        stopListening()
        worker.shutdown()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            if (eventSink == null) pendingHome = true else emit("home")
        }
    }

    override fun onStart() {
        super.onStart()
        // Flutter waits for onResume, so home shown again under a popup would otherwise stay paused.
        flutterEngine?.lifecycleChannel?.appIsInactive()
    }

    override fun onResume() {
        super.onResume()
        emit("resume")
    }

    override fun onPostResume() {
        super.onPostResume()
        configureSystemBars()
    }

    // Flutter asks Android to finish when Back reaches its root route.
    override fun popSystemNavigator(): Boolean = true

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stopListening()
        eventSink = events
        val filter = IntentFilter().apply {
            PACKAGE_ACTIONS.forEach { addAction(it) }
            addDataScheme("package")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(packageReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(packageReceiver, filter)
            }
            receiverRegistered = true
        } catch (_: RuntimeException) {
            events.error("EVENTS_UNAVAILABLE", "Změny aplikací nelze sledovat.", null)
        }
        if (pendingHome) {
            pendingHome = false
            emit("home")
        }
    }

    override fun onCancel(arguments: Any?) = stopListening()

    private fun stopListening() {
        eventSink = null
        if (receiverRegistered) {
            receiverRegistered = false
            try {
                unregisterReceiver(packageReceiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    private fun emit(type: String) {
        eventSink?.success(mapOf("type" to type))
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getApps" -> result.success(getApps())
                "loadSettings" -> result.success(settings.getString("settings", null))
                "openNotifications" -> result.success(NotificationAccessibilityService.openNotifications())
                "getStatus" -> result.success(
                    mapOf(
                        "isDefaultLauncher" to isDefaultLauncher(),
                        "isAccessibilityEnabled" to NotificationAccessibilityService.isEnabled(this),
                    ),
                )
                else -> {
                    when (call.method) {
                        "saveSettings" -> {
                            val json = (call.arguments as? Map<*, *>)?.get("json") as? String
                                ?: throw IllegalArgumentException("Chybí text nastavení.")
                            if (!settings.edit().putString("settings", json).commit()) {
                                throw IOException("Nastavení se nepodařilo uložit.")
                            }
                        }
                        "launchApp" -> launchApp(
                            requiredString(call, "packageName"),
                            optionalString(call, "activityName"),
                        )
                        "openAlarms" -> openAlarms()
                        "openCalendar" -> openIntent(
                            Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CALENDAR),
                        )
                        "openCamera" -> openIntent(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA))
                        "openContacts" -> openIntent(
                            Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CONTACTS),
                        )
                        "requestDefaultLauncher" -> requestDefaultLauncher()
                        "openAccessibilitySettings" -> openIntent(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        "openAppDetails" -> openIntent(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", requiredString(call, "packageName"), null),
                            ),
                        )
                        else -> {
                            result.notImplemented()
                            return
                        }
                    }
                    result.success(null)
                }
            }
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", error.message, null)
        } catch (error: ActivityNotFoundException) {
            result.error("NOT_FOUND", error.message, null)
        } catch (_: SecurityException) {
            result.error("PERMISSION_DENIED", "Systém nedovolil tuto akci.", null)
        } catch (error: IOException) {
            result.error("SAVE_FAILED", error.message, null)
        } catch (_: RuntimeException) {
            result.error("PLATFORM_ERROR", "Akci se nepodařilo dokončit.", null)
        }
    }

    private fun requiredString(call: MethodCall, key: String): String =
        optionalString(call, key) ?: throw IllegalArgumentException("Chybí parametr $key.")

    private fun optionalString(call: MethodCall, key: String): String? {
        val value = (call.arguments as? Map<*, *>)?.get(key) ?: return null
        require(value is String && value.isNotBlank()) { "Neplatný parametr $key." }
        return value
    }

    private fun getApps(): List<Map<String, String>> =
        queryActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER))
            .mapNotNull { it.activityInfo }
            .filter { it.packageName != packageName && isAvailable(it) }
            .distinctBy { ComponentName(it.packageName, it.name) }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "activityName" to it.name,
                    "label" to it.loadLabel(packageManager).toString().ifBlank { it.packageName },
                )
            }

    private fun launchApp(targetPackage: String, activityName: String?) {
        if (activityName != null) {
            val fullName = when {
                activityName.startsWith(".") -> targetPackage + activityName
                "." !in activityName -> "$targetPackage.$activityName"
                else -> activityName
            }
            if (tryLaunchApp(Intent.makeMainActivity(ComponentName(targetPackage, fullName)), targetPackage)) {
                return
            }
        }
        val fallback = packageManager.getLaunchIntentForPackage(targetPackage)
        if (fallback != null && tryLaunchApp(fallback, targetPackage)) return
        throw ActivityNotFoundException("Aplikace není dostupná nebo ji nelze otevřít.")
    }

    private fun tryLaunchApp(intent: Intent, targetPackage: String): Boolean {
        val component = intent.component ?: return false
        if (component.packageName != targetPackage) return false
        val info = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getActivityInfo(component, PackageManager.ComponentInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getActivityInfo(component, 0)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            return false
        }
        return isAvailable(info) && tryStartActivity(
            intent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
        )
    }

    private fun isAvailable(info: ActivityInfo): Boolean = try {
        info.exported &&
            enabled(packageManager.getApplicationEnabledSetting(info.packageName), info.applicationInfo.enabled) &&
            enabled(packageManager.getComponentEnabledSetting(ComponentName(info.packageName, info.name)), info.enabled)
    } catch (_: IllegalArgumentException) {
        false
    }

    private fun enabled(setting: Int, default: Boolean): Boolean = when (setting) {
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> default
        else -> false
    }

    private fun queryActivities(intent: Intent, flags: Int = 0): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, flags)
        }

    private fun resolveActivity(intent: Intent): ActivityInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
            )?.activityInfo
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo
        }

    private fun openAlarms() {
        if (tryStartActivity(Intent(AlarmClock.ACTION_SHOW_ALARMS))) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            tryStartActivity(Intent(AlarmClock.ACTION_SHOW_TIMERS))
        ) return
        val alarmIntent = Intent(AlarmClock.ACTION_SET_ALARM)
        val defaultClock = resolveActivity(alarmIntent)
        if (defaultClock != null && queryActivities(alarmIntent, PackageManager.MATCH_DEFAULT_ONLY).any {
                it.activityInfo?.packageName == defaultClock.packageName && it.activityInfo?.name == defaultClock.name
            }
        ) {
            // Launch the clock's front door without permission to create or change alarms.
            launchApp(defaultClock.packageName, null)
            return
        }
        throw ActivityNotFoundException("Nebyla nalezena aplikace budíku.")
    }

    private fun tryStartActivity(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private fun openIntent(intent: Intent) {
        if (!tryStartActivity(intent)) throw ActivityNotFoundException("Pro tuto akci není dostupná aplikace.")
    }

    private fun isDefaultLauncher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = getSystemService(RoleManager::class.java)
            if (roles?.isRoleAvailable(RoleManager.ROLE_HOME) == true) {
                return roles.isRoleHeld(RoleManager.ROLE_HOME)
            }
        }
        return resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))?.packageName == packageName
    }

    private fun requestDefaultLauncher() {
        if (isDefaultLauncher()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = getSystemService(RoleManager::class.java)
            if (roles?.isRoleAvailable(RoleManager.ROLE_HOME) == true) {
                try {
                    startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_HOME), 1)
                    return
                } catch (_: ActivityNotFoundException) {
                } catch (_: SecurityException) {
                }
            }
        }
        openIntent(Intent(Settings.ACTION_HOME_SETTINGS))
    }

    @Suppress("DEPRECATION")
    private fun configureSystemBars() {
        if (Build.VERSION.SDK_INT < 35) {
            window.statusBarColor = Color.WHITE
            window.navigationBarColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Color.WHITE else Color.BLACK
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
            window.decorView.isForceDarkAllowed = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val appearance = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(appearance, appearance)
        } else {
            var visibility = window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                visibility = visibility or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            }
            window.decorView.systemUiVisibility = visibility
        }
    }

    companion object {
        private val PACKAGE_ACTIONS = setOf(
            Intent.ACTION_PACKAGE_ADDED,
            Intent.ACTION_PACKAGE_REMOVED,
            Intent.ACTION_PACKAGE_CHANGED,
            Intent.ACTION_PACKAGE_REPLACED,
        )
    }
}
