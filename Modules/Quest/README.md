# Journal de quête — V1

Module Lua/XML natif d'Omega Hub, affiché **Journal de quête**, identifiant et dossier `Quest`. Il remplace le squelette `QuestGenerator` et reprend son réglage d'activation. Le module distinct `Quest` n'est pas modifié.

## Interface 1.5 — Grimoire

Le journal est un grimoire ouvert, avec deux pages vieillies, des tranches de papier et une reliure centrale. Son fond BLP et sa couverture sont générés depuis les SVG de `Media/Book` par `Tools/book.js` puis `Tools/book_blp.py`. Le texte sombre est affiché par WoW, indépendamment des textures. Le panneau MJ conserve les composants sombres partagés avec `OS2.UI`.

`Tools/book_paper.py`, appelé par `book_blp.py`, applique un papier à grain fixe aux pages : fibres fines, variations diffuses, vieillissement des bords et ombre limitée à la reliure. Il remplace les grands dégradés horizontaux responsables des bandes après compression. Après régénération du fond, exécuter `book_animation.py` pour reprendre ce même papier dans tous les atlas animés.

Les trois marque-pages textuels sont **Personnel** (vert), **Groupe** (bleu) et **Archive** (brun). Les remises individuelles sont personnelles ; les remises par groupe ou raid sont collectives. Ce classement est enregistré par destinataire et conservé lors des mises à jour. Les quêtes terminées, échouées ou annulées passent dans Archive. Les anciennes remises sans catégorie sont personnelles par défaut. `Quest.Book:RegisterCategory({id, label, color, matches})` ajoute ou remplace un marque-page et son filtre. La bande défile à la molette si nécessaire.

Pendant l'ouverture, la fermeture et les changements de page, le journal interactif reste entièrement masqué. `Quest_UI_BookMotion.lua` lit une séquence de BLP contenant des images complètes : aucune rotation, déformation ou superposition de couverture n'est calculée en jeu. Les textures sont redimensionnées sans recadrage, pour conserver les marges de cuir autour des pages.

Maj + I ouvre le grimoire en 24 images (0,70 seconde). Fermer par Maj + I, la croix ou Échap lit la même séquence à l'envers. Les changements de quête et de catégorie utilisent une seconde séquence de 16 images (0,45 seconde). Une inversion rapide reprend l'image courante et la désactivation arrête le lecteur. Le vrai texte réapparaît seulement en fin d'animation. Le sommaire reste à gauche et une quête occupe une page à droite, avec défilement interne pour les textes longs.

`Tools/book_animation.py` précalcule les images depuis les PNG du grimoire et de sa couverture (Pillow et NumPy). Chaque atlas BLP2 DXT5 de 2048 × 2048 contient quatre images de 1024 × 1024, restituées aux proportions du journal. Les dix atlas occupent environ 40 Mio ; la fermeture réutilise ceux de l'ouverture. `opening-blp.gif` et `turning-blp.gif` sont produits depuis les BLP décodés. Le lecteur, les indices et les interruptions sont testés hors jeu ; le chargement et la fluidité restent à valider dans Epsilon.

## Utilisation

### Enveloppe animée — comparaison des rendus

Le bouton **Test**, à côté de **Rédiger la lettre** dans le panneau MJ, lance l'aperçu BLP de la lettre sans créer de quête, envoyer de message ou changer le mode des prochaines lettres. La commande `/jq lettre blp` est retirée ; elle ne lance ni lettre ni journal. `/jq lettre dessin` conserve l'aperçu du dessin Lua natif et sélectionne ce mode pour les prochaines lettres ; BLP est le mode initial.

Une vraie notification attend un clic pour ouvrir le sceau, joue 3,2 secondes d'animation puis affiche une feuille seule, centrée, avec son pli au milieu. Le titre, l'objet, l'expéditeur et le corps de lettre sont du texte WoW, posé sur `paper.blp`. Le texte long défile à l'intérieur de la feuille ; les boutons **Accepter** et **Refuser** restent en bas.

**Accepter** inscrit la quête dans le journal et l'ouvre. **Refuser** écarte cet identifiant, y compris lors des mises à jour suivantes. Les lettres en attente sont enregistrées par personnage (`pending`) et réapparaissent après rechargement ; les refus sont mémorisés dans `refused`. L'accusé réseau confirme la réception technique, pas la décision du joueur : aucun retour de décision au MJ n'est ajouté. Les quêtes déjà acceptées continuent de se mettre à jour. Le déblocage manuel conserve sa remise directe sans enveloppe.

Dans l'écritoire, **Rédiger la lettre** ouvre les champs expéditeur, objet et texte. **Appliquer au brouillon**, puis **Enregistrer / actualiser** ou envoyer. Le titre vient de la quête. Ces champs publics sont conservés sur la quête et transmis par liste blanche ; les étapes masquées restent exclues. Les anciennes quêtes sans lettre utilisent le donneur, le titre et seulement les étapes révélées. MJ et destinataire doivent utiliser la version 1.4 ou ultérieure pour les nouveaux champs.

Les 64 images SVG originales sont dans `Media/Envelope`. Quatre atlas BLP2 DXT5 avec transparence regroupent les images (environ 16 Mio au total). `Tools/envelope.js` reconstruit les SVG/PNG avec Sharp ; `Tools/envelope_blp.py` convertit les atlas avec Pillow et les relit pour contrôle. `opening.gif` fournit un aperçu hors jeu issu des BLP décodés. Le papier est vieilli : teinte chaude, bords assombris, petites marques fixes et pli central visible. La feuille reste entièrement dépliée et l'enveloppe s'efface. La version Lua utilise des lignes et des remplissages unis ; ses ombrages sont volontairement plus simples que ceux des images.

Les tests hors jeu vérifient les deux lecteurs, la file des lettres et l'arrêt des animations. Le décodage BLP est contrôlé avec Pillow ; le rendu et la fluidité dans le client Epsilon restent à valider en jeu.

### Journal et rédaction

1. Faire `/reload`, puis activer **Journal de quête** dans `/omh` si nécessaire.
2. **Maj + I** ouvre ou ferme le livre. Le raccourci est installé à la première activation et modifiable dans **Raccourcis → AddOns → Omega Hub**. Les commandes `/jq` et `/quest` restent disponibles. Le sommaire reste sur la page gauche ; une quête occupe la page droite avec défilement interne. Les signets séparent les quêtes actives des archives.
3. `/jq mj` ouvre l'écritoire pour Nytherah et les personnages MJ autorisés. Le bouton dans le livre donne le même accès.
4. Rédiger titre, donneur et étapes. Sélectionner une étape pour modifier son texte et sa révélation. Le statut se choisit en cliquant sur le bouton de statut.
5. **Enregistrer / actualiser** valide les changements et prépare automatiquement leur transmission à tous les destinataires connus. Les champs en cours de saisie constituent un brouillon ; ils ne sont pas transmis à chaque frappe.
6. **Lettre individuelle** utilise le nom saisi ou le personnage ciblé. **Lettre de groupe** utilise le groupe ou raid actuel du MJ. **Quête débloquée** remet au personnage saisi sans lettre animée. **Transmission raid** remet individuellement à chaque membre du raid du MJ.
7. **Nouvelle trame** crée un dossier narratif (parent) reprenant le titre en cours. Une trame regroupe plusieurs quêtes distinctes de la même histoire ; une quête reste libre tant qu'elle n'est rattachée à aucune trame.
8. **Supprimer** demande confirmation et retire la quête des journaux destinataires à réception de l'ordre.

Toutes les étapes et le statut sont **communs à tous les destinataires**, conformément au choix V1. Un MJ travaille sur les dossiers créés par son personnage et conservés sur son installation ; les dossiers complets ne sont pas partagés entre MJ par le réseau.

Le sommaire de l'écritoire (« Mes quêtes ») affiche une arborescence : chaque trame est une ligne repliable (icône +/-, avec son nombre de quêtes), ses quêtes enfants apparaissent indentées en dessous avec une pastille de couleur selon leur statut, et un groupe **Quêtes libres** rassemble les quêtes sans trame. Cliquer une trame la replie ou la déplie ; cliquer une quête l'ouvre dans l'écritoire. Sélectionner une trame affiche deux boutons **Éd.** (renommer, via un champ compact au-dessus de la liste) et **Suppr.** (supprime la trame et détache ses quêtes sans les effacer, après confirmation). **Rattacher la quête**, au-dessus de la liste, arme un mode de sélection : cliquer ensuite une trame (ou **Quêtes libres**) déplace la quête actuellement ouverte dans l'écritoire vers ce dossier.

L'écritoire a sa propre identité visuelle (police Morpheus pour les titres, palette ambre/brou de noix, cartes distinctes « Identité », « Étapes & récit », « Diffusion »), indépendante du reste du module. **Accès MJ** est une fenêtre séparée, ouverte depuis son propre bouton dans l'en-tête de l'écritoire, plutôt qu'une section du panneau principal.

Le texte accepte les couleurs WoW `|cffRRGGBBtexte|r` et les icônes `|TInterface\Icons\INV_Misc_Book_09:16|t`. Cliquer dans le texte termine l'écriture et arrête le son. La fermeture du livre et la désactivation du module arrêtent également les animations et le son.

## Accès

Nytherah est toujours administratrice, même sur une installation neuve. Elle seule ajoute ou retire des noms dans le panneau et diffuse la liste versionnée. Les listes reçues sont acceptées uniquement si l'expéditeur réel du whisper addon est Nytherah sur le royaume local. Un nom sans royaume est normalisé vers le royaume local ; un nom qualifié reste associé à son royaume.

Chaque activation demande la liste à Nytherah. Celle-ci conserve les personnages qui l'ont contactée, ainsi que ses destinataires, pour diffuser les changements. **Diffuser les accès** réémet la liste ; les autres MJ disposent d'**Actualiser les accès**. Nytherah doit être connectée avec le module actif pour fournir une liste nouvelle ou actualisée. Hors connexion, les clients conservent leur dernière liste reçue ; une révocation n'a donc pas d'effet sur un client avant réception de cette actualisation.

L'accès à l'écritoire et chaque opération de données sont contrôlés. Côté destinataire, les quêtes sont acceptées seulement d'un MJ connu ; leur auteur est lié à l'expéditeur. Une remise d'un MJ encore inconnu attend brièvement une réponse directe de Nytherah, puis repose sur les nouvelles tentatives si nécessaire.

## Données et confidentialité

- `OmegaHubDB.Quest_MJ` : schéma `version = 2`, permissions, trames (dossiers narratifs parents), quêtes complètes (chacune avec un `trame_id` optionnel), contacts, compteur d'identifiants et remises publiques en attente.
- `OmegaHubDB.Quest_Joueur` : schéma `version = 1`, puis `personnages[Nom-Royaume normalisé] = { quetes, tombstones }`. Cette partition est nécessaire parce qu'`OmegaHubDB` est une SavedVariable de compte : chaque personnage consulte exclusivement son journal.
- Une quête MJ possède un identifiant stable, un auteur, une révision croissante, ses étapes complètes et ses destinataires. Une quête joueur contient `nombre_etapes` et la table clairsemée `etapes_revelees`, jamais la liste complète des étapes.
- Les deux migrations sont idempotentes et refusent un schéma futur. Le numéro de schéma est indépendant de la version du code `1.1.0`.

`Project()` construit une nouvelle table par liste blanche : les textes non révélés ne sont jamais copiés. `PublicEnvelope()` reconstruit ensuite l'enveloppe réseau, sans accepter de champs de travail supplémentaires. Seuls ces objets publics entrent dans la file d'envoi et le sérialiseur. Aucun `loadstring`, aucune exécution de Lua reçu, aucune dépendance réseau externe.

**Remasquer** retire le texte du prochain état transmis et rétablit `?????` dans le journal normal. Cela ne peut pas effacer un texte que le destinataire a déjà reçu et copié lorsqu'il était révélé.

## Transport

Préfixe `OMEGAHUB_QUEST`, exclusivement `C_ChatInfo.SendAddonMessage(..., "WHISPER", destinataire)`. Aucun message de discussion visible, ni diffusion publique en raid. Même la remise de groupe procède par whispers individuels.

Le codec typé utilise des longueurs explicites. Les enveloppes sont fragmentées en blocs de 180 octets avec identifiant de transfert, index et nombre de fragments. Les longueurs, types, champs, révisions et indices sont validés. Les réassemblages et attentes d'autorisation ont des bornes de taille et expirent. Les fragments peuvent arriver dans le désordre ; un doublon est toléré, un fragment contradictoire invalide le transfert.

La file envoie au maximum un fragment toutes les 1,05 seconde et conserve les remises jusqu'à l'accusé de réception du bon destinataire et de la bonne révision. Elle reprend après une reconnexion ou un rechargement, tant que le MJ créateur et le destinataire sont connectés avec le module actif. Les échecs sont réessayés avec un délai croissant, plafonné à cinq minutes. Les modifications remplacent les versions encore en attente. Les contrôles passent avant les remises non commencées.

Le compteur du panneau indique les remises sans accusé de réception : un joueur hors ligne ou sans addon reste en attente. Les longues quêtes remises à un raid prennent du temps avec ce débit volontairement prudent. Une suppression conserve une pierre tombale versionnée chez le joueur pour empêcher qu'un ancien paquet ne réintroduise la quête.

Limites V1 : 50 étapes, 8 192 octets par étape, 50 000 octets de texte total par quête, 100 MJ. Les champs affichent une erreur lorsque ces limites sont dépassées.

## Composants

Lors d'une sélection dans le journal, le contenu actuel s'efface en 0,3 seconde, puis la page tourne. Le nouveau contenu apparaît ensuite de 0 à 100 % en 0,3 seconde, sans redémarrer l'écriture lettre par lettre. Les marque-pages restent visibles. Une fermeture ou une nouvelle sélection annule le fondu en cours et sa sélection différée.

Le fond et les animations du grimoire utilisent `Media/Book/BindingEdges` : pli central ombré, épaules des pages éclairées, couverture biseautée et emblème embossé. Le contour supérieur et inférieur de la couverture, le biseau et les filets suivent la courbure de la charnière. Pour les régénérer, définir `OMEGA_BOOK_OUT` sur le chemin absolu de ce dossier, puis exécuter `Tools/book.js`, `Tools/book_blp.py` et `Tools/book_animation.py` dans cet ordre. Les marque-pages restent dans `Media/Book`. Le préchauffage utilise les mêmes atlas BindingEdges que le lecteur.

Pendant un changement de page, les marque-pages ignorent l'alpha du livre et passent au-dessus de la planche animée. Ils retrouvent leur comportement normal à la fin ; ouverture et fermeture les masquent toujours. Le ruban noir `MJ`, ancré en bas du bord droit, remplace le bouton de l'écritoire et conserve la restriction d'affichage aux MJ.

Au démarrage, `WarmAnimationTextures` prépare les 14 planches, le fond du journal, le papier de la lettre et les cinq marque-pages. Chaque image entière est dessinée seule dans une région de 2 × 2 pixels à faible opacité pendant trois mises à jour après chargement, plutôt que de ne présenter qu'un texel transparent. L'animation demandée devient prioritaire et attend la fin de cette préparation. Les autres chargements sont suspendus pendant sa lecture. La passe s'annule à la désactivation ; après 15 secondes de préparation sans achèvement, les lecteurs reviennent à la vue statique. Le comportement du cache graphique reste à vérifier sur le client Epsilon.

Les dix planches du journal et les quatre de l'enveloppe sont affectées à des régions masquées dès l'activation, puis conservées pour les prochaines lectures. Les animations changent la région visible et ses coordonnées, sans rappeler `SetTexture`. Lorsque le client propose `IsObjectLoaded`, elles suspendent leur progression tant qu'une planche est en chargement. Le temps passé à attendre est ignoré et chaque mise à jour avance au maximum d'une pose : une saccade allonge légèrement la lecture au lieu de sauter plusieurs images. La feuille de lecture est aussi créée dès l'activation. Ce cache conserve davantage de textures en mémoire ; aucune animation factice ni lettre de démonstration n'est lancée. Référence : [API Region de Blizzard](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua).

Les catégories du journal utilisent des rubans BLP étroits, à pointe fendue, avec leur libellé tourné de 90° du bas vers le haut. `Tools/bookmarks.py` régénère les textures et leur aperçu (à lancer avant `Tools/book_blp.py`). Pour une catégorie supplémentaire, fournir `bookmark` avec le chemin de sa texture et son libellé intégré ; sans texture, un ruban neutre affiche le nom dans son infobulle.

- `Quest_UI_Write.lua` : `Write:Tokens`, `Start`, `Finish`, `Stop`. Le demandeur fournit la frame d'animation et le FontString ; il appelle `Stop` lorsqu'il masque son composant.
- `Quest_UI_Book.lua` : `Book:CreateContents(parent, width, height, onSelect)` puis `SetEntries(entries)` ; entrées `{ id, titre, sous_titre }`. Le composant ne dépend pas du stockage des quêtes.
- `Styles/parchemin.lua` : thème partagé avec `OS2.UI`, surfaces unies, défilement et son de plume. Le nom historique est conservé pour le chargement du TOC.
- `Media/Quill.ogg` : son original synthétisé pour ce module ; source reproductible dans `Tests/generate_quill.py`.

## Vérification

Depuis la racine de l'addon :

```text
fengari Modules/Quest/Tests/Quest_test.lua
```

La suite couvre notamment les migrations, l'isolation des personnages, les droits, la confidentialité des projections et enveloppes, les entrées malformées, la fragmentation, les accusés, les mises à jour, les suppressions, les trames, les composants UI simulés et un échange entre trois clients séparés avec reconnexion.

Le code est vérifié syntaxiquement en Lua 5.1. Les tests utilisent des doublures des API WoW et ne remplacent pas la vérification en jeu du rendu, du son et du transport Epsilon. Parcours de recette : ouvrir le livre, rédiger une quête longue avec seulement l'étape 2 révélée, l'envoyer à un joueur, révéler la première étape, archiver puis supprimer ; répéter une remise sur le groupe et le raid du MJ.

Référence API du client : [documentation ChatInfo 11.2.0 de l'interface Blizzard](https://github.com/Gethe/wow-ui-source/blob/11.2.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).

Pas de suivi de carte, de pins, d'annotations ni de tableau d'enquête dans cette V1.
