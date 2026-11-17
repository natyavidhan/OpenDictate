package dev.natya.opendictate

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView

/** One plain settings screen, built in code (no layouts, no AndroidX). */
class MainActivity : Activity() {
    private lateinit var cfg: Cfg
    private lateinit var status: TextView
    private lateinit var enableBtn: Button
    private lateinit var micBtn: Button
    private val fields = mutableMapOf<String, EditText>()
    private val prompts = mutableMapOf<String, Pair<EditText, String>>()
    private lateinit var cleanup: Switch

    private val d by lazy { resources.displayMetrics.density }
    private fun dp(v: Int) = (v * d).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cfg = Cfg(this)
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(28), dp(20), dp(40))
        }
        col.addView(TextView(this).apply {
            text = "OpenDictate"; textSize = 30f; typeface = Typeface.DEFAULT_BOLD
        })
        col.addView(note("Tap the floating pill above your keyboard to dictate, tap again to finish. " +
            "Hold it for push-to-talk. Drag it to move. Start with “${cfg.agentName}, …” to ask the assistant " +
            "(select text first to have it rewrite that selection)."))

        status = TextView(this).apply { textSize = 15f; setPadding(0, dp(16), 0, dp(4)) }
        col.addView(status)
        enableBtn = Button(this).apply {
            text = "Turn on OpenDictate in Accessibility"
            setOnClickListener { showDisclosure() }
        }
        micBtn = Button(this).apply {
            text = "Allow microphone"
            setOnClickListener { requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1) }
        }
        col.addView(enableBtn)
        col.addView(micBtn)
        col.addView(note("Sideloaded and the toggle is greyed out? App info → ⋮ → Allow restricted settings."))
        col.addView(Button(this).apply {
            text = "Open app info"
            setOnClickListener {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
            }
        })

        col.addView(field(Cfg.KEY, "Groq API key", "gsk_…", secret = true))
        cleanup = Switch(this).apply {
            text = "AI cleanup (remove ums, fix punctuation, apply self-corrections)"
            isChecked = cfg.cleanup
            setOnCheckedChangeListener { _, _ -> save() }
            setPadding(0, dp(12), 0, dp(4))
        }
        col.addView(cleanup)
        col.addView(field(Cfg.AGENT, "Assistant name", Cfg.DEF_AGENT))
        col.addView(field(Cfg.LANG, "Language code (blank = auto)", "en"))
        col.addView(field(Cfg.DICT, "Dictionary (names, jargon; comma separated)", "Groq, Kotlin, Kubernetes", multi = true))
        col.addView(field(Cfg.STT, "Transcription model", Cfg.DEF_STT))
        col.addView(field(Cfg.LLM, "Cleanup / assistant model", Cfg.DEF_LLM))
        col.addView(promptField(Cfg.CLEANUP_PROMPT, "Cleanup prompt (dictionary is appended automatically)", Prompts.CLEANUP))
        col.addView(promptField(Cfg.ASSISTANT_PROMPT, "Assistant prompt ({name} = assistant name)", Prompts.ASSISTANT))

        col.addView(TextView(this).apply {
            text = "Try it"; textSize = 18f; typeface = Typeface.DEFAULT_BOLD; setPadding(0, dp(24), 0, dp(4))
        })
        col.addView(EditText(this).apply {
            hint = "Tap here, then tap the pill…"; minLines = 3
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        })
        col.addView(Button(this).apply {
            text = "Privacy policy"
            setOnClickListener { launch(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_URL))) }
        })

        setContentView(ScrollView(this).apply { addView(col); isFillViewport = true })
    }

    /**
     * Google Play's prominent disclosure for the AccessibilityService API: say what the service reads and where
     * data goes, and open Accessibility settings only after the user agrees.
     */
    private fun showDisclosure() {
        AlertDialog.Builder(this)
            .setTitle("How OpenDictate uses Accessibility")
            .setMessage(
                "OpenDictate uses Android's Accessibility service to type for you in other apps. While it's on, it:\n\n" +
                    "• Notices when a text field is focused and the keyboard is open, to show the mic button. " +
                    "It never shows in password fields.\n" +
                    "• Reads the text and cursor position of that field, to put your words in the right place.\n" +
                    "• Types the transcribed text into the field.\n\n" +
                    "Your voice is recorded only after you tap the button, until you stop. The recording is sent to " +
                    "Groq (groq.com) with your API key to turn it into text and, if AI cleanup is on, to tidy it up. " +
                    "When you start with “${cfg.agentName}, …”, the field's text, any selected text and the app's name " +
                    "are also sent to Groq so the assistant can answer.\n\n" +
                    "OpenDictate has no servers and no analytics. Nothing else leaves your phone, and each recording " +
                    "is deleted once it's transcribed."
            )
            .setPositiveButton("Agree") { _, _ -> launch(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
            .setNegativeButton("No thanks", null)
            .show()
    }

    private fun launch(intent: Intent) {
        runCatching { startActivity(intent) }
    }

    private fun note(t: String) = TextView(this).apply {
        text = t; textSize = 13f; alpha = 0.7f; setPadding(0, dp(6), 0, dp(6))
    }

    private fun field(key: String, label: String, hintText: String, secret: Boolean = false, multi: Boolean = false) =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, 0)
            addView(TextView(context).apply { text = label; textSize = 13f; alpha = 0.7f })
            addView(EditText(context).apply {
                hint = hintText
                setText(cfg.p.getString(key, ""))
                inputType = InputType.TYPE_CLASS_TEXT or when {
                    secret -> InputType.TYPE_TEXT_VARIATION_PASSWORD
                    multi -> InputType.TYPE_TEXT_FLAG_MULTI_LINE
                    else -> InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                }
                layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
                setOnFocusChangeListener { _, has -> if (!has) save() }
                fields[key] = this
            })
        }

    /** Multiline prompt editor prefilled with the default; saved only when it differs from it. */
    private fun promptField(key: String, label: String, default: String) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(0, dp(12), 0, 0)
        addView(TextView(context).apply { text = label; textSize = 13f; alpha = 0.7f })
        val edit = EditText(context).apply {
            setText(cfg.p.getString(key, "")!!.ifBlank { default })
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            textSize = 13f
            typeface = Typeface.MONOSPACE
            setOnFocusChangeListener { _, has -> if (!has) save() }
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        }
        prompts[key] = edit to default
        addView(edit)
        addView(Button(context).apply {
            text = "Reset to default"
            setOnClickListener { edit.setText(default); save() }
        })
    }

    override fun onResume() {
        super.onResume()
        val am = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
        val on = am.getEnabledAccessibilityServiceList(-1).any { it.resolveInfo.serviceInfo.packageName == packageName }
        val mic = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        status.text = "Service: ${if (on) "on ✓" else "off"}    Mic: ${if (mic) "allowed ✓" else "not allowed"}"
        enableBtn.visibility = if (on) View.GONE else View.VISIBLE
        micBtn.visibility = if (mic) View.GONE else View.VISIBLE
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) =
        onResume()

    override fun onPause() {
        super.onPause()
        save()
    }

    private fun save() {
        cfg.p.edit().apply {
            fields.forEach { (k, v) -> putString(k, v.text.toString().trim()) }
            putBoolean(Cfg.CLEANUP, cleanup.isChecked)
            prompts.forEach { (k, v) ->
                val text = v.first.text.toString().trim()
                if (text.isEmpty() || text == v.second) remove(k) else putString(k, text)
            }
        }.apply()
    }

    companion object {
        private const val PRIVACY_URL = "https://github.com/natyavidhan/OpenDictate/blob/main/PRIVACY.md"
    }
}
