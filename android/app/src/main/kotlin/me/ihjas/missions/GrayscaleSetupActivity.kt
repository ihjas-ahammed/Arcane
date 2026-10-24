package me.ihjas.missions

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * One-time setup guide for the Grayscale tile. Opened by [GrayscaleTileService] when
 * WRITE_SECURE_SETTINGS is missing. Shows the adb steps and copies the grant command.
 */
class GrayscaleSetupActivity : Activity() {

    private val grantCommand =
        "adb shell pm grant me.ihjas.missions android.permission.WRITE_SECURE_SETTINGS"

    private val steps = listOf(
        "Settings › About phone: tap Build number 7 times to enable Developer options.",
        "Settings › Developer options: turn on USB debugging (Wireless debugging also works on Android 11+).",
        "Install platform-tools (adb) on a computer, connect the phone by USB, and accept the \"Allow USB debugging\" prompt.",
        "On the computer, run `adb devices`. The phone must be listed as \"device\".",
        "Run the grant command below.",
        "Come back here, tap CHECK, then tap the Grayscale tile."
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
    }

    private fun buildContent(): ScrollView {
        val card = column().apply {
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = box(PANEL, CYAN, 1, 6)
        }
        card.addView(text("GRAYSCALE · SETUP", 18f, CYAN, bold = true).apply { letterSpacing = 0.12f })
        card.addView(text("One-time permission needed", 13f, MID).withTopMargin(dp(4)))

        steps.forEachIndexed { index, step ->
            card.addView(
                text("${index + 1}.  $step", 13f, WHITE).withTopMargin(dp(12))
            )
        }

        card.addView(text("COMMAND", 11f, MUTED, bold = true).apply { letterSpacing = 0.15f }.withTopMargin(dp(16)))
        card.addView(
            text(grantCommand, 12f, AMBER).apply {
                typeface = Typeface.MONOSPACE
                setTextIsSelectable(true)
                setPadding(dp(10), dp(8), dp(10), dp(8))
                background = box(DEEP, MUTED, 1, 4)
            }.withTopMargin(dp(6))
        )

        card.addView(
            button("COPY COMMAND") {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("adb command", grantCommand))
                Toast.makeText(this, "Command copied", Toast.LENGTH_SHORT).show()
            }.withTopMargin(dp(14))
        )
        card.addView(
            button("CHECK") {
                if (DisplayGrayscale.hasPermission(this)) {
                    Toast.makeText(this, "Permission granted. Tap the Grayscale tile.", Toast.LENGTH_LONG).show()
                    finish()
                } else {
                    Toast.makeText(this, "Not granted yet. Run the command first.", Toast.LENGTH_LONG).show()
                }
            }.withTopMargin(dp(8))
        )

        return ScrollView(this).apply {
            setBackgroundColor(DEEP)
            isFillViewport = true
            addView(
                card,
                ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            )
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
    }

    private fun column() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    private fun text(value: String, sizeSp: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color)
        if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private fun button(label: String, onClick: () -> Unit) = text(label, 13f, CYAN, bold = true).apply {
        gravity = Gravity.CENTER
        letterSpacing = 0.12f
        setPadding(dp(12), dp(12), dp(12), dp(12))
        background = box(DEEP, CYAN, 1, 4)
        setOnClickListener { onClick() }
    }

    /** Sets a top margin on a view that is already in a LinearLayout. */
    private fun <T : android.view.View> T.withTopMargin(px: Int): T {
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = px }
        return this
    }

    private fun box(fill: Int, stroke: Int, strokeDp: Int, radiusDp: Int) = GradientDrawable().apply {
        setColor(fill)
        setStroke(dp(strokeDp), stroke)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    private companion object {
        val DEEP = Color.parseColor("#FF05080C")
        val PANEL = Color.parseColor("#FF090F16")
        val CYAN = Color.parseColor("#FF00F0FF")
        val AMBER = Color.parseColor("#FFFFB547")
        val WHITE = Color.parseColor("#FFF0F4F8")
        val MID = Color.parseColor("#FFA8B3C7")
        val MUTED = Color.parseColor("#FF62778D")
    }
}
