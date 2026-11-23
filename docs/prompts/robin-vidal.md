# Prompt journal, robin-vidal

Prompts as sent, in the language they were written in, chronological order.
Method and rules are in [README.md](README.md).

## Network reality and threat model

> pourquoi le 301 marche pas ? donne moi les contraintes reseau que j'oublie

> sur ios qu'est ce qui casse si l'app passe en arriere plan ?

> si le serveur distribue les ip qu'est ce qu'un attaquant sur le meme wifi peut faire ? distingue lecture et injection

> un contact est represente par un id t'as pas peur que quelqu'un mente sur son id ?

> donne moi les pieges d'implementation qui annulent cette garantie

> on a un systeme de gestion des messages non recus ? je pensais faire des ack avec retry mais en groupe le client qui envoie l'historique manquant pourrait mentir

> je veux tout prouver sauf l'absence

> explique moi pourquoi la connexion ouverte sert de mecanisme de presence plutot qu'un heartbeat

## Registry server and authentication

> ecris registry.go : map id vers blobs mutex et le cycle de vie lie a la connexion pas de commentaires

> maintenant l'authentification : HELLO CHALLENGE AUTH OK signature domaine separee justifie le prefixe

> ed25519.Verify peut paniquer ? verifie dans la doc officielle avant d'ecrire

> ecris un client de test en go qui verifie les 6 criteres y compris l'expiration reele du nonce

> le nonce est rejouable sur une autre connexion ? prouve le par un test

> explique pourquoi on met pas de deadline de lecture apres authentification

## Protocol and message layer documents

> ecris la doc du protocole pour qu'un dev ios l'implemente sans lire le source go liste exhaustive des tokens d'erreur

> ajoute une section sur ce que le design protege pas nomme chaque limite

> specifie la couche message : layout signe octet par octet pourquoi les champs sont prefixes en longeur et pourquoi le chiffrement de groupe doit garder un seul message id

## Dart client

> je veux un package dart pur pas une app flutter pour que mes camarades l'utilisent par dependance de chemin

> quelle lib dart pour ed25519 x25519 et chacha20-poly1305 ? verifie l'api reelle avant d'ecrire

> concois l'api pour que mes camarades touchent jamais une cle le scellement et la verification de signature doivent etre dans publishAddress et fetchAddress

> l'epinglage par onBadCertificate suffit ? qu'est ce qui se passe si le certificat est deja aprouve par le systeme ?

> chaque token ERR doit devenir une exception typee pas une string a parser

> ecris un test d'integration qui compile et lance le vrai serveur go avec un certificat genere puis deroule tout le flux

## Hygiene

> verifie que l'arbre apres rebase est identique a celui que t'as teste par hash

## Project management and toolchain

> je veux que tu organises le projet github en passant en ready tous les trucs pas bloques et en backlog tous les trucs bloques

> est-ce qu'il y a des issues qui recoupent ca ? - rapport sonarqube sast / sast avec rapport en artefact (lien sonar ou static) - accepter merge si pas de failles critiques / high - faciliter pipeline de test redteam en blackbox et acces au code

> il faudrait separer le milestone red team du milestone secu, peut-etre en mettre un en 0.8.0 et un en 0.7.0

> sur les issues dev mets a la fois ozone et ybenalii

> chacun doit avoir son fichier de prompts et un fichier global qui importe les autres
