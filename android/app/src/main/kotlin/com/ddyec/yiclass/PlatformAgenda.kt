package com.ddyec.yiclass

import android.app.*
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PlatformAgenda {
    fun snapshot(context: Context): JSONObject = JSONObject(context.getSharedPreferences("agenda", Context.MODE_PRIVATE).getString("snapshot", "{}") ?: "{}")
    fun events(data: JSONObject): List<JSONObject> {
        val list = data.optJSONArray("events") ?: JSONArray()
        return (0 until list.length()).map { list.getJSONObject(it) }.sortedBy { it.optLong("startMs") }
    }
    fun launch(context: Context): PendingIntent = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun pending(context: Context, id: Int, event: String? = null): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).putExtra("event", event)
        return PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun sync(context: Context) {
        val data = snapshot(context)
        val alarm = context.getSystemService(AlarmManager::class.java)
        val prefs = context.getSharedPreferences("agenda", Context.MODE_PRIVATE)
        val previous = prefs.getStringSet("alarms", emptySet()) ?: emptySet()
        previous.forEach { alarm.cancel(pending(context, it.toInt())) }
        // Clear notifications for removed, completed or expired entries on every edit.
        val manager = context.getSystemService(NotificationManager::class.java)
        val activeIds = events(data).filter { !it.optBoolean("completed") && it.optLong("endMs") > System.currentTimeMillis() }.map { (it.optString("id") + it.optLong("startMs")).hashCode() }.toSet()
        manager.activeNotifications.filter { !data.optBoolean("enabled") || it.id !in activeIds }.forEach { manager.cancel(it.id) }
        val ids = mutableSetOf<String>()
        val now = System.currentTimeMillis()
        if (data.optBoolean("enabled")) {
            events(data).filter { !it.optBoolean("completed") && it.optLong("endMs") > now }.take(128).forEach { event ->
                val trigger = event.optLong("startMs") - data.optLong("lead",10) * 60000
                // Enabling reminders mid-course should not create repeated notifications.
                if (trigger > now) {
                    val id = (event.optString("id") + event.optLong("startMs")).hashCode()
                    val pi = pending(context, id, event.toString())
                    if (Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                    else alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                    ids.add(id.toString())
                }
            }
        }
        // Refresh course widgets at actual starts/ends, including midnight.
        val next = events(data).flatMap { listOf(it.optLong("startMs"),it.optLong("endMs")) }.filter { it > now }.minOrNull()
        if (next != null) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next + 1000,pending(context,Int.MIN_VALUE))
            ids.add(Int.MIN_VALUE.toString())
        }
        prefs.edit().putStringSet("alarms",ids).apply()
        refresh(context)
    }
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in listOf(ScheduleWidget::class.java,TodoWidget::class.java)) {
            val ids = manager.getAppWidgetIds(ComponentName(context,provider))
            ids.forEach { update(context,manager,it,provider == TodoWidget::class.java) }
        }
    }
    fun update(context: Context, manager: AppWidgetManager, id: Int, todo: Boolean) {
        val data = snapshot(context); val now = System.currentTimeMillis()
        val views = RemoteViews(context.packageName,R.layout.agenda_widget)
        val time = SimpleDateFormat("HH:mm",Locale.getDefault())
        val date = SimpleDateFormat("MM月dd日",Locale.CHINA)
        views.setTextViewText(R.id.heading,if(todo) "待办" else data.optString("tableName","YIClass"))
        val rows = if(todo) {
            val list = data.optJSONArray("todos") ?: JSONArray()
            (0 until list.length()).map { list.getJSONObject(it) }.filter { it.isNull("completedAt") }
                .sortedWith(compareBy<JSONObject> { it.optString("deadline","9999").let { d -> if(d == "null") "9999" else d } }.thenByDescending { it.optString("importance") == "high" })
                .take(3).map { t -> "□ ${t.optString("title")}\n${if(t.isNull("deadline")) "未设截止时间" else t.optString("deadline").replace('T',' ').take(16)}" }
        } else events(data).filter { it.optString("kind") == "course" && it.optLong("endMs") > now }.take(2).map { e ->
            "${e.optString("title")}\n${date.format(Date(e.optLong("startMs")))} ${time.format(Date(e.optLong("startMs")))}–${time.format(Date(e.optLong("endMs")))}\n${e.optString("subtitle")}" }
        views.setTextViewText(R.id.content, rows.joinToString("\n\n").ifEmpty { if(todo) "暂无待办" else "近期没有课程\n打开 YIClass 同步最新课表" })
        views.setOnClickPendingIntent(R.id.widget_root, launch(context))
        manager.updateAppWidget(id,views)
    }
    fun notify(context: Context, event: JSONObject) {
        val now = System.currentTimeMillis()
        if(event.optLong("endMs") <= now) return
        val manager=context.getSystemService(NotificationManager::class.java)
        if(Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("lessons","课程与日程",NotificationManager.IMPORTANCE_HIGH))
        val time=SimpleDateFormat("HH:mm",Locale.getDefault())
        val builder=if(Build.VERSION.SDK_INT>=26) Notification.Builder(context,"lessons") else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_book).setContentTitle(event.optString("title"))
            .setContentText("${time.format(Date(event.optLong("startMs")))}–${time.format(Date(event.optLong("endMs")))} · ${event.optString("subtitle")}")
            .setContentIntent(launch(context)).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(Color.rgb(99,126,234)).setCategory(Notification.CATEGORY_EVENT)
        if(Build.VERSION.SDK_INT>=26)builder.setTimeoutAfter(event.optLong("endMs")-now)
        try { manager.notify((event.optString("id")+event.optLong("startMs")).hashCode(),builder.build()) } catch (_: SecurityException) { }
    }
}
class ScheduleWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { PlatformAgenda.update(context,manager,it,false) } }
}
class TodoWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { PlatformAgenda.update(context,manager,it,true) } }
}
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event=intent.getStringExtra("event")
        if(event!=null) { PlatformAgenda.refresh(context); PlatformAgenda.notify(context,JSONObject(event)) }
        else PlatformAgenda.sync(context)
    }
}
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { PlatformAgenda.sync(context) }
}
