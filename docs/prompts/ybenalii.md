# Prompt journal, ybenalii


> Je te donne crypto.dart et address_blob.dart. Rends aesGcmSeal et aesGcmOpen dependants d'un nonce et de données associées obligatoires, avec un refus si le nonce ne fait pas 12 octets. Les appels de address_blob.dart passent les 12 zéros explicitement. Le format des blobs ne doit pas changer, aucune dépendance ajoutee, style du repo respecte. Rends chaque modif complete

> ecris client/test/crypto_test.dart : un aller-retour avec un nonce non nul et des données associées, l'ancien usage avec les zéros, lechec du tag si les données associées changent, et le refus d'un nonce de mauvaise taille pour seal et pour open. Donne un tableau test / case du ticket.


> Depuis client/, dart analyze --fatal-infos et dart test donnent la sortie ci-dessous explique la cause et la correction minimale stp

> verifie que aesGcmSeal et aesGcmOpen exigent un nonce et des données associees, que la taille du nonce est controlee, que les appels de address_blob.dart passent les zeros explicitement, et que crypto_test.dart couvre les 4 cases du ticket. Signale tout ecart, et tout risque de réutilisation de nonce que je n'aurais pas couvert


## Fix #93, refuse a hostile address blob field instead of crashing

> Je travaille sur le paquet Dart pur client/ (sans Flutter, Dart 3.14, lints recommended et strict-casts), et je dois traiter le ticket #93 que je te colle ci-dessous avec address_blob.dart, registry_client.dart, codec.dart et exceptions.dart ; RegistryException est une sealed class ; est-ce que tu peux lister chaque endroit ou une donnee venant d'un contact ou du serveur peut lever une erreur qui n'est pas une RegistryException, avec la ligne, la valeur qui declenche l'erreur et l'exception obtenue, y compris les cas que le ticket ne cite pas

> Avant d'ecrire du code, explique-moi pourquoi ces erreurs sont atteignables malgre la verification de signature : qui controle ces champs, a quel moment la signature est verifiee, et pourquoi un contact malveillant ou compromis peut quand meme envoyer ces valeurs

> Propose la correction en langage naturel pour chaque cas, sans code : ou placer le controle, quelle valeur limite utiliser et pourquoi, et quel message d'erreur, sans reveler de donnee sensible  precise ce qui ne change pas pour un client honnete

> Pour chaque cas que tu as trouve transforme l'erreur en ProtocolException en controlant la valeur avant de l'utiliser : la borne de DateTime.fromMillisecondsSinceEpoch verifiee avant l'appel, l'hote decode en UTF-8 strict avec un refus explicite et le base64 du challenge et du blob decode par une seule fonction qui refuse proprement je ne veux pas de try/catch large qui avalerait d'autres erreurs, et le format des blobs comme les messages d'erreur existants doivent rester identiques rends-moi les fichiers complets termines par un retour a la ligne avec un resume des changements

> J'ai besoin de tests qui fabriquent un blob correctement chiffre et signe par l'auteur attendu, mais avec une date hors des bornes de DateTime dans les deux sens, un hote en UTF-8 invalide, et un champ base64 malforme cote client ; chaque refus doit etre une ProtocolException, donc une RegistryException ; utilise expectLater pour les appels asynchrones et laisse les tests existants intacts  donne-moi les fichiers de test complets et un tableau test

> Depuis client/, dart analyze --fatal-infos et dart test donnent la sortie ci-dessous ; explique la cause de chaque erreur et la correction minimale, en distinguant ce qui vient de mon code et ce qui vient de l'environnement ou du dossier depuis lequel j'ai lance la commande
