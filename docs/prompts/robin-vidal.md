# Prompt journal, robin-vidal

Method and rules are in [README.md](README.md). Prompts are verbatim, in the
language they were written in. Order is chronological.

## Network reality and threat model

> pourquoi le 301 marche pas ? donne moi les contraintes reseau que j'oublie

Intent: understand why the first direct connection attempt between two phones
failed, and get the list of constraints that were being ignored.
Landed: the Transport section of `docs/protocol.md`, and the decision to keep a
rendezvous server instead of pretending peers can find each other.
Verdict: accepted. The useful part of the answer was the constraint list, not
the diagnosis.

> sur ios qu'est ce qui casse si l'app passe en arriere plan ?

Intent: find out whether a long lived connection survives backgrounding on iOS.
Landed: the Lifetime section of `docs/protocol.md`, and the rule that a peer
disappearing from the registry is normal and not an error.
Verdict: accepted. It set the constraint that presence cannot be assumed.

> si le serveur distribue les ip qu'est ce qu'un attaquant sur le meme wifi peut faire ? distingue lecture et injection

Intent: separate what a passive attacker on the same network learns from what
an active one can change.
Landed: `docs/protocol.md`, "What this protects, and what it does not".
Verdict: accepted after correction. The first answer treated reading and
injection as one risk, which hides the fact that reading survives TLS at the
metadata level while injection does not.

> un contact est represente par un id t'as pas peur que quelqu'un mente sur son id ?

Intent: test whether an identifier chosen by its owner can be impersonated.
Landed: `registry-server/identity.go`, where the id is derived from the public
keys instead of being declared, and `TestIDHashesBothPublicKeys` plus
`TestIDDependsOnEveryKey` in `registry-server/identity_test.go`.
Verdict: accepted. This is the prompt that removed a whole class of attack: an
id that is a hash of the keys cannot be claimed by someone who lacks them.

> donne moi les pieges d'implementation qui annulent cette garantie

Intent: get the list of mistakes that would break the derived id guarantee.
Landed: the tests above, and the parsing rules in `identity.go` checked by
`TestParseIdentityAcceptsP256Keys` and `TestParseIdentityRejectsBadKeys`.
Verdict: accepted. Hashing only one key, or hashing a non canonical encoding,
both appeared here before they could appear in the code.

> on a un systeme de gestion des messages non recus ? je pensais faire des ack avec retry mais en groupe le client qui envoie l'historique manquant pourrait mentir

Intent: check whether ack and retry is enough in a group, where the peer that
replays the missing history is also the peer that could forge it.
Landed: the Acknowledgement section of `docs/chat.md`.
Verdict: accepted. The answer confirmed that a replayed history is only
trustworthy if every message is individually signed, which is why the message
layer signs per message and not per batch.

> je veux tout prouver sauf l'absence

Intent: state the goal out loud. Authenticity and integrity are provable;
knowing that a message was never sent is not.
Landed: the "What is proven" and "What is not proven" sections of
`docs/chat.md`.
Verdict: accepted. It became the line the rest of the design is measured
against.

> explique moi pourquoi la connexion ouverte sert de mecanisme de presence plutot qu'un heartbeat

Intent: justify tying presence to the TCP connection rather than to an
application level heartbeat.
Landed: the Lifetime section of `docs/protocol.md` and the connection scoped
lifecycle in `registry-server/registry.go`.
Verdict: accepted. The connection already carries the signal; a heartbeat would
have added a second source of truth that can disagree with the first.

## Registry server and authentication

> ecris registry.go : map id vers blobs mutex et le cycle de vie lie a la connexion pas de commentaires

Intent: get the storage layer, with entries that die with the connection that
published them.
Landed: `registry-server/registry.go`.
Verdict: accepted. Small enough that the first output was usable.

> maintenant l'authentification : HELLO CHALLENGE AUTH OK signature domaine separee justifie le prefixe

Intent: get the handshake, and force a justification for the domain separation
prefix rather than a prefix chosen because it looks safe.
Landed: the Handshake section of `docs/protocol.md`,
`registry-server/identity.go`, and the challenge tests in `identity_test.go`.
Verdict: accepted. The justification was the point: without a prefix the same
signature is valid in another context where the same key is used.

> ed25519.Verify peut paniquer ? verifie dans la doc officielle avant d'ecrire

Intent: find out whether the verification call can panic on malformed input,
before writing code that feeds it attacker controlled bytes.
Landed: the key length checks on the parsing path in `identity.go`.
Verdict: accepted after a real check of the Go standard library documentation,
which states that the function panics on a public key of the wrong length.
This is the shape every library question took afterwards: read the
documentation, then write.

> ecris un client de test en go qui verifie les 6 criteres y compris l'expiration reele du nonce

Intent: drive the server from the outside and check the six handshake criteria,
with a nonce that actually expires rather than one forced to expire.
Landed: nothing that is versioned. There is no standalone Go client in the tree
and the history records none being removed.
Verdict: superseded. The criteria are covered today by the nine tests of
`registry-server/identity_test.go`, and the end to end flow by
`client/test/registry_integration_test.dart`, which starts the real server.

> le nonce est rejouable sur une autre connexion ? prouve le par un test

Intent: refuse the claim that nonces are per connection unless a test says so.
Landed: `TestChallengeVerifyRejectsAnotherNonce` and
`TestChallengeVerifyRejectsMissingAndStaleChallenges` in `identity_test.go`.
Verdict: accepted. The first answer explained why replay was impossible; the
test is what makes it true.

> explique pourquoi on met pas de deadline de lecture apres authentification

Intent: justify dropping the read deadline once a peer is authenticated,
instead of copying a timeout from another design.
Landed: the Lifetime section of `docs/protocol.md`.
Verdict: accepted. A deadline after authentication would disconnect idle peers,
which is the normal state of a presence connection.

## Protocol and message layer documents

> ecris la doc du protocole pour qu'un dev ios l'implemente sans lire le source go liste exhaustive des tokens d'erreur

Intent: make the specification sufficient on its own, with every error token
listed rather than discovered by reading the server.
Landed: `docs/protocol.md`, Errors section.
Verdict: accepted after correction. The first version described the errors in
prose; the exhaustive token list is what the Dart client was written against.

> ajoute une section sur ce que le design protege pas nomme chaque limite

Intent: write the limits down instead of leaving them implied.
Landed: `docs/protocol.md`, "What this protects, and what it does not".
Verdict: accepted. Every limit named here is a limit no reviewer has to
discover.

> specifie la couche message : layout signe octet par octet pourquoi les champs sont prefixes en longeur et pourquoi le chiffrement de groupe doit garder un seul message id

Intent: specify the message layer with a byte exact signed layout, and get the
reasons for length prefixes and for a single message id across a group.
Landed: `docs/chat.md`.
Verdict: accepted. Length prefixes stop two different field splits from
producing the same signed bytes; one message id per message keeps a group
message from being counted as several.

## Dart client

> je veux un package dart pur pas une app flutter pour que mes camarades l'utilisent par dependance de chemin

Intent: keep the client usable from any Dart or Flutter project in the group
through a path dependency.
Landed: `client/`, a pure Dart package with no Flutter dependency.
Verdict: accepted.

> quelle lib dart pour ed25519 x25519 et chacha20-poly1305 ? verifie l'api reelle avant d'ecrire

Intent: pick a library and check its real API before writing against it.
Landed: the dependency in `client/pubspec.yaml`.
Verdict: obsolete, and recorded as such on purpose. The algorithms in the
question were replaced by P-256 and AES-GCM to match the iOS Secure Enclave,
and the library chosen at the time was replaced by `pointycastle`. The entry
stays because the journal records what was asked, not what survived.

> concois l'api pour que mes camarades touchent jamais une cle le scellement et la verification de signature doivent etre dans publishAddress et fetchAddress

Intent: design the surface so that no caller in the group ever handles key
material.
Landed: `client/lib/src/registry_client.dart`, where sealing and signature
verification happen inside `publishAddress` and `fetchAddress`.
Verdict: accepted. The API an average caller can misuse is the API that gets
misused.

> l'epinglage par onBadCertificate suffit ? qu'est ce qui se passe si le certificat est deja aprouve par le systeme ?

Intent: check whether pinning through that callback is enough, given that the
callback is not called when the system already trusts the certificate.
Landed: the certificate pinning section of `client/README.md`.
Verdict: accepted after correction. The first answer said the callback was
sufficient, which is wrong for exactly the case in the question. This is the
clearest example in this journal of a confident answer that a test of the
premise invalidated.

> chaque token ERR doit devenir une exception typee pas une string a parser

Intent: stop callers from matching on error strings.
Landed: `client/lib/src/exceptions.dart`, one type per token of the Errors
section of `docs/protocol.md`.
Verdict: accepted.

> ecris un test d'integration qui compile et lance le vrai serveur go avec un certificat genere puis deroule tout le flux

Intent: prove the Dart and Go sides agree, against the real server rather than
a mock.
Landed: `client/test/registry_integration_test.dart`.
Verdict: accepted. It is the test that proved the wire format matches byte for
byte between the two implementations.

## Hygiene

> verifie que l'arbre apres rebase est identique a celui que t'as teste par hash

Intent: refuse to trust a rebase on inspection, and compare the resulting tree
by hash against the tree that was tested.
Landed: no file. It is a working rule.
Verdict: accepted. A rebase that looks right and a rebase that is right are
different claims.
