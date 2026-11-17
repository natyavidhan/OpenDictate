# OpenDictate privacy policy

Last updated: November 18, 2026

OpenDictate is an open-source voice dictation app for Android, published by natyavidhan ([github.com/natyavidhan/OpenDictate](https://github.com/natyavidhan/OpenDictate)). This policy explains what the app accesses, where that data goes and what it keeps.

## Summary

- OpenDictate has no servers, accounts, ads or analytics. The developer never receives your data.
- When you dictate, the recording goes directly from your phone to Groq, under your own Groq API key, to be transcribed.
- Each recording is deleted from your phone as soon as it has been transcribed.

## What the app accesses

### Microphone

OpenDictate records audio only after you tap or hold the dictation button, and stops when you tap again or let go. It does not listen in the background.

### Accessibility service

OpenDictate uses Android's AccessibilityService API to:

- detect when a text field is focused and the on-screen keyboard is open, so it can show the dictation button (it never appears in password fields);
- read the text and cursor position of the focused field, so it can insert your words at the cursor;
- insert the transcribed text into that field.

It does not collect or store other screen content. Text read from the focused field leaves your phone only in the assistant case described below.

### Clipboard

If no text field is focused when a transcription finishes, or a field doesn't accept inserted text, the text is copied to your clipboard so you can paste it. OpenDictate never reads your clipboard.

## What is sent to Groq

OpenDictate uses Groq's API (`api.groq.com`) for speech-to-text and text processing. Requests go directly from your phone to Groq over HTTPS, authenticated with the API key you enter. Depending on what you do, a request contains:

- **Dictation:** your audio recording, the transcription model and language you selected, and a hint made of your assistant name and dictionary words.
- **AI cleanup** (on by default): the transcribed text, your cleanup prompt and your dictionary words.
- **Assistant** (when you start with your assistant's name): your spoken command, the text of the focused field (up to the last 4,000 characters), any selected text, the package name of the app you are typing in, and your assistant prompt.

Groq processes this data under its own terms and [privacy policy](https://groq.com/privacy-policy/). You manage your Groq account and API keys at [console.groq.com](https://console.groq.com).

## What is stored on your phone

- **Settings:** your Groq API key, assistant name, language, dictionary, models, prompts and the button's position. They are kept in the app's private storage, excluded from Android backups, and deleted when you uninstall the app or clear its data. The API key is stored unencrypted in that private storage.
- **Recordings:** each recording is written to the app's private cache while you speak and deleted as soon as its transcription finishes, fails or is cancelled.

## Sharing

OpenDictate does not sell or share your data. The only third party involved is Groq, which you choose and authenticate with your own key.

## Children

OpenDictate is not directed at children.

## Changes

Updates to this policy are published in this file, and its full history is visible in the repository.

## Contact

Questions or requests: [open an issue](https://github.com/natyavidhan/OpenDictate/issues).
