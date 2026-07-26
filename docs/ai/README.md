# Maliyati AI Integration Pack

This folder contains the canonical contract for generating scripts accepted by
Maliyati's **Input by script** feature.

## Easiest option: one prompt only

Open `MALIYATI_ALL_IN_ONE_PROMPT.txt`, copy all of its contents, and paste it
into ChatGPT, Gemini, or another AI assistant as the main instruction. It is
standalone and does not require uploading any of the other files.

## Files

- `MALIYATI_ALL_IN_ONE_PROMPT.txt`: complete standalone prompt containing the
  workflow, accounting rules, operations, validation, and examples.
- `MALIYATI_SYSTEM_PROMPT.md`: upload or paste this as the AI system
  instruction.
- `SUPPORTED_OPERATIONS.md`: human-readable command and accounting reference.
- `maliyati_action_schema.json`: machine-readable JSON Schema for structured
  output tools.
- `maliyati_training_examples.jsonl`: reviewed conversation examples in chat
  JSONL format.

## Recommended use with ChatGPT or Gemini

1. Create a dedicated assistant, Gem, or project.
2. Add `MALIYATI_SYSTEM_PROMPT.md` as the main instruction.
3. Upload `SUPPORTED_OPERATIONS.md` and
   `maliyati_training_examples.jsonl` as reference knowledge.
4. When structured output or a response schema is supported, use
   `maliyati_action_schema.json`.
5. Ask the AI for a financial action in normal Arabic or English.
6. Review the AI summary and answer its questions.
7. Confirm the summary.
8. Copy only the final JSON block into Maliyati.

The JSONL file is useful as reference or as a starting point for a chat
fine-tuning dataset. Fine-tuning formats differ between providers, so check the
provider's current dataset requirements before starting a training job.

## Important behavior

- The AI must ask for confirmation before emitting executable JSON.
- A single command can be one JSON object.
- Multiple commands should be a JSON array or an object with an `actions` list.
- Canonical action names are `add_transaction`, `edit_transaction`,
  `delete_transaction`, and `settle_transaction`.
- Omitting settlement amounts means **settle the full remaining balance**.
- Editing by title requires the exact existing title. Transaction ID is safer.
- Firestore remains the live database. These files contain no credentials.
