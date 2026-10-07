# Gemini AI Assistant Rules for Ascent

1. **Branching**: Always develop on a feature branch (`feature/<name>`). Never commit unverified changes directly to `main`.
2. **Performance First**: Keep the Home screen lightning fast (<100ms render). No continuous GPS listeners, no heavy fluid animation loops, no multi-stream lag on Home.
3. **UI / UX**: Translucent glass containers with subtle 1px border. Deep soothing background. Tactile haptics on every interaction.
4. **AI Gateway**: Keep AI interaction centralized in the floating "Riya se Baat" button linking to `/ai-assistant`.
5. **Back Button**: Double-tap back on Home to exit, and back from other tabs reverts to Home tab first.
6. **Deployment**: Merge after self-audit with user approval, compile APK, and install on device via ADB.
