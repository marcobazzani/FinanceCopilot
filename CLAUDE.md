# Build & Deploy

- Always build first, then kill the running app, then start the new build. Never kill before the build completes.
  ```
  flutter build macos --release && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
  ```

# Git Workflow

- Commit into git when detecting the user is starting a new task (not iterating on a previous task).
- Use concise, meaningful commit messages.
