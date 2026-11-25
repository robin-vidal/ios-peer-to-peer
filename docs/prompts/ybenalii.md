# Prompt journal, ybenalii

## Fix #92, a blob belongs to the connection that published it
> avec une nouvelle connexion, ça recrée un blob ou pas ?

> Tu proposes quoi pour ne pas perdre le blob pour chaque id apres qu'une connexion se perde

> quels fichiers modifier

> faisons le fix [texte de l'issue #92 collé]
> Ecris [registry_test.go et main_test.go] :
- couvre [Publish, Fetch, RemoveConn, la limite de 64, ValidID, et le bug : la 1re connexion se ferme, le blob de la 2e reste] ;
- main_test.go via net.Pipe, sans réseau : [refus avant AUTH, commande inconnue, ligne trop longue] ;
- reutilise les helpers d'identity_test.go sans les modifier ;
- verifie l'erreur exacte, mets un délai sur chaque lecture

