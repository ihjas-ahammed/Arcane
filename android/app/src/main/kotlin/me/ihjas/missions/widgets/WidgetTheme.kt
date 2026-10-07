package me.ihjas.missions.widgets

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import me.ihjas.missions.R

/**
 * Makes every Arcane widget follow the app: light / dark theme and the accent colour of the
 * selected protocol. The Dart side publishes `arcane.theme.light` and `arcane.theme.accent`; each
 * widget is created through [views] and its static colours are re-tinted at runtime. Surfaces and
 * buttons are flat shapes, so a background tint recolours them cleanly. Needs API 31
 * (`setColorStateList`); older systems keep the original dark look.
 */
object WidgetTheme {
    private const val DEFAULT_ACCENT = 0xFF00F0FF.toInt()

    class T(val light: Boolean, val accent: Int) {
        val surface: Int = if (light) ColorUtils.blendARGB(Color.WHITE, accent, 0.10f)
                           else ColorUtils.blendARGB(0xFF0B0F17.toInt(), accent, 0.10f)
        val text: Int = if (light) 0xFF14181F.toInt() else 0xFFF2F6FA.toInt()
        val mid: Int = if (light) 0xFF3C4654.toInt() else 0xFFB9C4CF.toInt()
        val muted: Int = if (light) 0xFF6B7684.toInt() else 0xFF7A8A99.toInt()
        val onAccent: Int = if (ColorUtils.calculateLuminance(accent) > 0.5) 0xFF0B0F17.toInt() else Color.WHITE
        // Accent text must stay readable on the surface.
        val accentText: Int = run {
            var c = accent
            var guard = 0
            while (ColorUtils.calculateContrast(c, surface) < 3.0 && guard++ < 12) {
                c = ColorUtils.blendARGB(c, if (light) Color.BLACK else Color.WHITE, 0.12f)
            }
            c
        }
    }

    fun get(context: Context): T {
        val p = WidgetCommon.prefs(context)
        val light = WidgetCommon.getSafeBoolean(p, "arcane.theme.light", false)
        val accent = WidgetCommon.getSafeLong(p, "arcane.theme.accent", DEFAULT_ACCENT.toLong()).toInt()
        return T(light, accent or 0xFF000000.toInt())
    }

    private val themed get() = Build.VERSION.SDK_INT >= 31

    /** Colour a provider asked for through the old palette, mapped into the current theme. */
    fun color(context: Context, res: Int): Int {
        val base = ContextCompat.getColor(context, res)
        if (!themed) return base
        val t = get(context)
        return when (res) {
            R.color.widget_accent_amber, R.color.widget_accent_cyan -> t.accentText
            R.color.widget_text_white -> t.text
            R.color.widget_text_mid -> t.mid
            R.color.widget_text_muted -> t.muted
            R.color.widget_bg_deep -> t.onAccent
            else -> base
        }
    }

    fun tint(views: RemoteViews, id: Int, color: Int) {
        if (!themed) return
        views.setColorStateList(id, "setBackgroundTintList", ColorStateList.valueOf(color))
    }

    /** Filled accent button (background) with matching foreground text. */
    fun primary(context: Context, views: RemoteViews, id: Int) {
        if (!themed) return
        val t = get(context)
        tint(views, id, t.accent)
        views.setTextColor(id, t.onAccent)
    }

    fun pip(context: Context, views: RemoteViews, id: Int, filled: Boolean) {
        if (!themed) return
        val t = get(context)
        tint(views, id, if (filled) t.accent else ColorUtils.setAlphaComponent(t.muted, 90))
    }

    private enum class R_ { TEXT, MID, MUTED, ACCENT_TEXT, ONACCENT }

    /** Creates the widget's views already themed; providers then set their dynamic state on top. */
    fun views(context: Context, layout: Int): RemoteViews {
        val v = RemoteViews(context.packageName, layout)
        if (themed) try { base(context, v, layout) } catch (_: Throwable) {}
        return v
    }

    private fun base(context: Context, v: RemoteViews, layout: Int) {
        val t = get(context)
        val card = when (layout) {
            R.layout.widget_bus -> R.id.widget_bus_card
            R.layout.widget_dayplan -> R.id.widget_dayplan_card
            R.layout.widget_finance -> R.id.widget_finance_card
            R.layout.widget_goals -> R.id.widget_goals_card
            R.layout.widget_journal -> R.id.widget_journal_card
            else -> R.id.widget_running_card
        }
        tint(v, card, t.surface)
        v.setViewVisibility(R.id.widget_bg_art, View.GONE)

        fun text(id: Int, c: Int) = v.setTextColor(id, c)
        fun soft(id: Int) { tint(v, id, t.accent); text(id, t.accentText) }
        fun solid(id: Int) { tint(v, id, t.accent); text(id, t.onAccent) }

        when (layout) {
            R.layout.widget_bus -> {
                text(R.id.widget_bus_status_badge, t.accentText); text(R.id.widget_bus_speed_label, t.muted)
                text(R.id.widget_bus_route, t.muted); text(R.id.widget_bus_main_time, t.text)
                text(R.id.widget_bus_substop_info, t.accentText)
                soft(R.id.widget_bus_btn_swap); solid(R.id.widget_bus_btn_open)
                progress(v, R.id.widget_bus_progress, t)
            }
            R.layout.widget_dayplan -> {
                text(R.id.widget_dayplan_status_badge, t.accentText); text(R.id.widget_dayplan_capacity, t.muted)
                text(R.id.widget_dayplan_primary_title, t.text); text(R.id.widget_dayplan_next_label, t.muted)
                text(R.id.widget_dayplan_next_title, t.accentText); text(R.id.widget_dayplan_items_count, t.accentText)
                solid(R.id.widget_dayplan_btn_open); soft(R.id.widget_dayplan_btn_check); soft(R.id.widget_dayplan_btn_task)
                progress(v, R.id.widget_dayplan_progress, t)
            }
            R.layout.widget_finance -> {
                text(R.id.widget_fin_balance, t.text); text(R.id.widget_fin_today, t.mid); text(R.id.widget_fin_mtd, t.mid)
                soft(R.id.widget_finance_btn_income); soft(R.id.widget_finance_btn_expense)
                progress(v, R.id.widget_fin_budget, t)
            }
            R.layout.widget_goals -> {
                text(R.id.widget_goals_status_badge, t.accentText); soft(R.id.widget_goals_xp_badge)
                text(R.id.widget_goals_progress_pct, t.muted)
                for ((c, ti, tg) in listOf(
                    Triple(R.id.widget_goal_0_check, R.id.widget_goal_0_title, R.id.widget_goal_0_tag),
                    Triple(R.id.widget_goal_1_check, R.id.widget_goal_1_title, R.id.widget_goal_1_tag),
                    Triple(R.id.widget_goal_2_check, R.id.widget_goal_2_title, R.id.widget_goal_2_tag),
                )) { solid(c); text(ti, t.text); text(tg, t.muted) }
                text(R.id.widget_goals_empty_title, t.text); text(R.id.widget_goals_empty_subtitle, t.muted)
                progress(v, R.id.widget_goals_progress, t)
            }
            R.layout.widget_journal -> {
                text(R.id.widget_journal_count, t.text)
                solid(R.id.widget_journal_btn_new); soft(R.id.widget_journal_btn_open)
            }
            else -> {
                text(R.id.widget_status_label, t.accentText); text(R.id.widget_capacity, t.muted)
                tint(v, R.id.widget_btn_dayplan, ColorUtils.setAlphaComponent(t.muted, 110)); text(R.id.widget_btn_dayplan, t.mid)
                text(R.id.widget_task_subtitle, t.muted); text(R.id.widget_task_title, t.text)
                text(R.id.widget_time_mode_label, t.muted)
                text(R.id.widget_task_chronometer, t.accentText); text(R.id.widget_task_today, t.accentText)
                soft(R.id.widget_btn_check); soft(R.id.widget_btn_finish)
                progress(v, R.id.widget_task_progress, t)
            }
        }
    }

    private fun progress(v: RemoteViews, id: Int, t: T) {
        v.setColorStateList(id, "setProgressTintList", ColorStateList.valueOf(t.accent))
        v.setColorStateList(id, "setProgressBackgroundTintList", ColorStateList.valueOf(ColorUtils.setAlphaComponent(t.muted, 70)))
    }
}
