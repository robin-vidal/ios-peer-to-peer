# Prompt journals

Every member of the group keeps a journal of the prompts used to produce the
code, the specs and the documents of this repository. This file is the index.
Each member owns one file and nobody else writes in it.

## Index

| Member | File |
| --- | --- |
| robin-vidal | [robin-vidal.md](robin-vidal.md) |
| corentin-dupaigne | [corentin-dupaigne.md](corentin-dupaigne.md) |
| marie-lou-allain | [marie-lou-allain.md](marie-lou-allain.md) |
| romain-vidal | [romain-vidal.md](romain-vidal.md) |
| yasmine-benali | [yasmine-benali.md](yasmine-benali.md) |

A file that holds no prompt yet is a file whose owner has not written their journal, not a file to delete. The file is named after your GitHub
handle, lowercase, so that `git log` and the index agree on who wrote what.

Markdown has no include directive, so this index links the member files instead
of inlining them. Read it as the table of contents of one document split in
parts, not as a summary: nothing is repeated here.

## Method

A prompt is recorded as it was sent. Spelling is normalised, nothing else is:
same wording, same language, same content. A prompt that is rewritten
afterwards no longer proves what was asked.

Order is chronological inside a file.

An entry is added in the same commit as the work it describes. A journal
reconstructed at the end of the project is worth nothing, because the prompt
that was rejected is exactly the one nobody remembers.

Anything beyond the prompt itself is commentary: what the prompt was after,
what it produced, whether the output was kept, corrected or thrown away. That
commentary is written by the member, by hand, and never by a model. A model
describing the intent behind a prompt it answered is the one thing this journal
cannot contain, since the point of the exercise is that a human judged the
output.

## Rules

A prompt is recorded, so a prompt that carries a secret is never recorded at
all. No passphrase, no private key, no certificate fingerprint, no
token, no personal data about anyone. If a prompt needed one of those, write
the entry without it and say that the value was redacted.

The journal describes how the system was designed. It is not the place for a
finding from the security audit, for an attack path, or for anything learned
about another group during the cross audit. Those stay in the handover of #55.
