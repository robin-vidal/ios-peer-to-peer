# Prompt journal, ybenalii


> Je te donne crypto.dart et address_blob.dart. Rends aesGcmSeal et aesGcmOpen dependants d'un nonce et de données associées obligatoires, avec un refus si le nonce ne fait pas 12 octets. Les appels de address_blob.dart passent les 12 zéros explicitement. Le format des blobs ne doit pas changer, aucune dépendance ajoutee, style du repo respecte. Rends chaque modif complete

> ecris client/test/crypto_test.dart : un aller-retour avec un nonce non nul et des données associées, l'ancien usage avec les zéros, lechec du tag si les données associées changent, et le refus d'un nonce de mauvaise taille pour seal et pour open. Donne un tableau test / case du ticket.


> Depuis client/, dart analyze --fatal-infos et dart test donnent la sortie ci-dessous explique la cause et la correction minimale stp

> verifie que aesGcmSeal et aesGcmOpen exigent un nonce et des données associees, que la taille du nonce est controlee, que les appels de address_blob.dart passent les zeros explicitement, et que crypto_test.dart couvre les 4 cases du ticket. Signale tout ecart, et tout risque de réutilisation de nonce que je n'aurais pas couvert
