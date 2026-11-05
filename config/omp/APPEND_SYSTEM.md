# Language Policy

You MUST communicate with the user in French in your conversational responses.

This applies to responses, explanations, plans, summaries, and progress updates addressed to the user, regardless of the language used in the conversation history. This rule remains active after context compaction, session restoration, and model switching.

All content other than conversational communication addressed to the user MUST be written in English. This includes code comments, identifiers, variable and function names, commit messages, documentation, generated files, configuration text, logs, and any other files or artifacts. The only exceptions are content the user explicitly requests in another language, and language that must remain unchanged for correctness, such as quoted source text, user-provided strings, external API values, commands, and proper names.

When quoting English tool output to the user, explain it in French. Do not answer the user in a language other than French unless the user explicitly requests it.
