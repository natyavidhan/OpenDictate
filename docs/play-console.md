# Play Console answers

Draft answers for the forms Google only lets the developer fill in on the website. They match what the code does as of version 0.4; re-check them when data handling changes.

## Store settings

- **Category:** Productivity.
- **Contact email and website:** already set through the Play API. Keep contact details out of `app/src/main/play`: Gradle Play Publisher replaces all of them at once, so a website file on its own wipes the email, and Play then refuses to save the listing.

## App content

### Privacy policy

`https://github.com/natyavidhan/OpenDictate/blob/main/PRIVACY.md`

### App access

Choose **All or some functionality is restricted**: nothing works without a Groq API key. Create a separate Groq key for reviewers (you can revoke it after review) and add these instructions:

> OpenDictate needs a Groq API key. Open the app and paste this key into "Groq API key": `<reviewer key>`. Tap "Allow microphone", then "Turn on OpenDictate in Accessibility", read the disclosure and tap Agree, and enable OpenDictate in Accessibility settings. Open any app with a text field (for example Messages), tap the field, then tap the round mic button above the keyboard, speak, and tap it again. The transcription is typed into the field.

### Ads

No, the app doesn't contain ads.

### Content rating

Category: **Utility, Productivity, Communication, or Other**. Answer **No** to every content question (violence, sexuality, language, controlled substances, gambling). Users can't interact with each other, share their location, or buy digital goods. If asked about AI-generated content: yes, an optional assistant writes text from the user's own voice command, and the text is typed into the user's own field.

### Target audience

18 and over. The app isn't designed to appeal to children.

### News app

No.

### Data safety

- Collects or shares required user data types: **Yes**.
- All data encrypted in transit: **Yes** (HTTPS to `api.groq.com`).
- Account creation: **The app doesn't allow users to create an account.**
- Way to request data deletion: **No**. The developer stores nothing. Recordings are deleted from the phone after transcription, and data sent to Groq falls under the user's own Groq account.

| Data type | Collected | Shared | Ephemeral | Required? | Purpose |
| --- | --- | --- | --- | --- | --- |
| Audio → Voice or sound recordings | Yes | No | No | Required | App functionality |
| App activity → Other user-generated content (dictated text sent for cleanup; field text and selection in assistant mode) | Yes | No | No | Optional | App functionality |
| App activity → Installed apps (package name of the app being typed in, assistant mode only) | Yes | No | No | Optional | App functionality |

Mark "Shared" as No. Data goes only to Groq, a service the user chooses and authenticates with their own key, which falls under Google's service-provider and user-initiated exemptions. Nothing else is collected: no location, contacts, identifiers, analytics or crash logs.

### Government, financial and health apps

Not a government app, no financial features, no health features.

### Accessibility API (sensitive permissions declaration)

- **Accessibility tool:** No (the service doesn't set `isAccessibilityTool`).
- **Description:**

> OpenDictate is a voice-typing utility. Its core feature is a dictation button that floats above the keyboard in any app. The AccessibilityService is used to (1) detect when an editable, non-password text field is focused and the soft keyboard is visible, so the button can be shown; (2) read the focused field's text and cursor position, so the transcription can be inserted at the cursor; and (3) insert the transcribed text into that field (ACTION_SET_TEXT, with ACTION_PASTE as a fallback). Before the app opens Accessibility settings, users see an in-app disclosure of this behaviour and must tap Agree. Audio, and the field's text only when the user addresses the voice assistant, are sent to Groq's API under the user's own API key. Nothing is sent to the developer.

- **Video:** upload a short, unlisted YouTube video that shows the disclosure, the user tapping Agree, and dictation working in another app. The screenshot workflow saves `disclosure.mp4` (disclosure → Agree → Accessibility settings) as a start. A phone recording of real dictation shows the feature best.

## If review asks about AI-generated content

OpenDictate isn't a chatbot. AI cleans up the user's own dictation and, optionally, drafts text the user asks for by voice. The output is typed into the user's own text field, where they see it and can edit it before sending.

## Closed testing (new personal accounts)

Personal developer accounts created after November 13, 2023 must run a closed test with at least 12 testers who stay opted in for 14 days before they can apply for production access. Add testers to the **Closed testing** track (an email list or Google Group), then publish builds there with `./gradlew publishBundle --track alpha`.
