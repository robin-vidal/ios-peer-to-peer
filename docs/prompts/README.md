# Prompt journals

Every member of the group keeps a journal of the prompts used to produce the
code, the specs and the documents of this repository. This file is the index.
Each member owns one file and nobody else writes in it.

## Index

| Member | File |
| --- | --- |
| robin-vidal | [robin-vidal.md](robin-vidal.md) |

Add your line when you create your file. The file is named after your GitHub
handle, lowercase, so that `git log` and the index agree on who wrote what.

Markdown has no include directive, so this index links the member files instead
of inlining them. Read it as the table of contents of one document split in
parts, not as a summary: nothing is repeated here.

## Method

An entry is written in the same commit as the work it describes. A journal
reconstructed at the end of the project is worth nothing, because the prompt
that was rejected is exactly the one nobody remembers.

Each entry carries four things.

- The prompt, verbatim. Same wording, same typos, same language. A prompt that
  is cleaned up afterwards no longer proves what was asked.
- The intent. What the prompt was trying to obtain, in one sentence.
- Where it landed. The file, the test or the section of a document that came
  out of it. An entry that produced nothing says so.
- The verdict. Accepted, accepted after correction, or rejected, and the
  reason. A rejection is the most useful line in the journal: it records a
  wrong answer that did not reach the code.

Order is chronological inside a file.

## Rules

A prompt is recorded verbatim, so a prompt that carries a secret is never
recorded at all. No passphrase, no private key, no certificate fingerprint, no
token, no personal data about anyone. If a prompt needed one of those, write
the entry without it and say that the value was redacted.

The journal describes how the system was designed. It is not the place for a
finding from the security audit, for an attack path, or for anything learned
about another group during the cross audit. Those stay in the handover of #55.

A model answer is not a source. When an entry says that something was checked
in the official documentation, the check happened, and the entry names what was
read.
