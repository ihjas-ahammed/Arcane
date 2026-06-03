package me.ihjas.missions.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import me.ihjas.missions.MainActivity

/**
 * Receives taps from the active-mission widget's quick-action buttons
 * (ENGAGE / CHECK / FINISH).
 *
 * If the app is already alive, the action is applied silently in the running
 * Flutter isolate — the app is NOT brought to the foreground. Only when the
 * process is dead do we launch the app (via the same deep link the plugin
 * observes) so the action still applies. Buttons that need UI (OPEN PLAN,
 * title tap) keep using a normal launch intent instead of this receiver.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.data?.getQueryParameter("action") ?: return

        if (MainActivity.dispatchWidgetAction(action)) return

        // App not running — open it with the launch deep link so the existing
        // cold-start handler applies the action.
        val launch = Intent(context, MainActivity::class.java).apply {
            data = intent.data
            this.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        context.startActivity(launch)
    }
}
