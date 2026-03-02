# Git Commits Guidelines

- DO NOT COMMIT automatically unless asked to do so by the user.
- Always ask for confirmation before making any commits to the repository.
- This ensures that you have the user's approval and that they are aware of the changes being made to the codebase.

When committing, always use atomic commits format with Conventional Commits format. This means that each commit should represent a single logical change to the codebase, and the commit message should follow the Conventional Commits format, which includes a type, scope, and description of the change.

Be extremely concise in commit messages, sacrifice grammar for sake of conciseness.

Don't add co-authored by any AI tools in any commits. e.g. Claude, Copilot, ChatGPT, Gemini, etc.

# After Review

- When review has been completed, and there are changes to be made, add regression tests first reproducing the findings.
- After adding regression tests, make the necessary code changes to fix the issues identified during the review process.
