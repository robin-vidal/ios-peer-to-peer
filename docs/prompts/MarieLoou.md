# Prompt journal, MarieLoou

Prompts as sent, in the language they were written in, chronological order.
Method and rules are in [README.md](README.md).

---

Hi, first analyse this repo.
Especially, read the /docs so you have everything in mind

```
---

# feat(app): secure enclave signing key through a swift plugin

The long term signing key must be generated inside the Secure Enclave and never leave it. The enclave is P-256 only, which is why the protocol moved to that curve.

## Acceptance criteria

- [ ] A Swift plugin generates a `SecureEnclave.P256.Signing.PrivateKey`
- [ ] It returns the 65 byte x963 public key to Dart
- [ ] It signs a 32 byte digest and returns raw r||s, 64 bytes
- [ ] Creation failure is handled apart from `SecureEnclave.isAvailable`, which can read true where creation still fails
- [ ] No third party wrapper touches the key

Is there anything missing to complete the task?
Do you have any questions?

First tell me your plan to
- achieve this task
- how can I test what you do
- what tests you will add

---

Check the docs for answers

The app isn't available for macOS or Android

---
```

Check session.md docs for answer. If it is not in it, add app reinstall, and explicit “delete identity” actions in it

---

Nice, you can do the changes. Organize yourself in clean commit. After each modification, propose a commit name, I'll read the changes and commit if I approve them

---

Please apply your plan

---

Thanks. Please read the ticket again and verify the code fills out all the requirements

---

