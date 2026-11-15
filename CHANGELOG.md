# Patch notes

Toutes les modifications de Warband Keeper, version par version.
Ce fichier est généré à partir de `Core/Changelog.lua` (les mêmes notes sont visibles en jeu : `/wk notes`).

## À venir

_Prévu, pas encore commencé._

- Alerte de prix : prévenir quand un objet suivi passe sous un prix choisi à l'hôtel des ventes (Auctionator).
- Prix moyen de vente : ce que tu vends vraiment chaque objet (d'après tes ventes HV), comparé au prix Auctionator.
- Recherche globale : trouver un objet, une recette ou un perso dans tout l'addon.
- Mini-fenêtre « À faire » déplaçable, sans ouvrir la fenêtre principale.
- Conseil de métier : la recette orange ou jaune la moins chère parmi celles que le perso connaît.
- Recherche « Qui peut fabriquer… ? » sur tous les persos.
- Annonce de métier : une phrase prête pour la guilde ou le commerce, avec le lien du métier et tes meilleures recettes.
- Maj + clic sur une tuile de métier ou une recette pour mettre son lien dans le chat.
- Pile d'alertes pour tous les rappels (buffs, poisons, guidage, familier) : elle sert déjà aux rappels du chasseur.
- Icônes des filons et plantes pistés sur la minimap (technique fragile, à étudier).

## v0.50.1 — 15/11/2026

### Corrections
- Micro menu : l'heure et les barres FPS / latence paraissaient décentrées. Les deux barres vont maintenant d'un bord du texte à l'autre, leur partie vide reste visible, et le gras n'est plus décalé d'un côté.

## v0.50.0 — 15/11/2026

### Ajouts
- Micro menu : l'heure peut s'afficher en gras.
- Micro menu : taille de l'heure réglable à part (0 = suit la taille des raccourcis).
- Micro menu : police de l'heure au choix (police de l'interface, Friz Quadrata, Arial Narrow, Morpheus, Skurri), indépendante du reste de l'addon.

### Modifications
- Mode édition : le panneau (grille, aimant, disposition, Terminer) est maintenant en bas de l'écran.
- Micro menu : le fond de l'heure s'adapte à la taille du texte, et les raccourcis restent centrés en hauteur.

## v0.49.0 — 15/11/2026

### Modifications
- QoL : les 9 classes sont rangées dans un seul onglet « Classes » de la colonne. Elles se choisissent dans une barre d'onglets en haut de la page (icône, nom, nombre d'alertes ; classes non jouées en grisé).
- QoL : l'onglet « Classes » rouvre la dernière classe consultée, sinon celle du perso joué.

## v0.48.1 — 15/11/2026

### Modifications
- Micro menu : plus de fond derrière les raccourcis de gauche et de droite. Seule l'heure garde le sien, les icônes restent sur leurs tuiles.

## v0.48.0 — 15/11/2026

### Modifications
- Indicateur de distance : sans cible, un anneau beige en pointillés avec un viseur au centre remplace le texte « sans cible », qui était coupé.
- Flèche de guidage plus compacte, sur deux lignes : le nom, puis le rôle (maître des écuries, banquier…) et la distance dans une pastille à la couleur du thème.
- Nouvelles textures : relancer le jeu (un /reload ne suffit pas).

## v0.47.0 — 15/11/2026

### Ajouts
- Micro menu : réglage « Taille » (raccourcis et heure), dans Qualité de vie > Micro menu.

### Modifications
- Micro menu : le fond est séparé en trois (raccourcis de gauche, heure, raccourcis de droite). Les côtés glissent depuis l'heure au survol.
- Micro menu : avec l'effet loupe, le fond de chaque côté grandit avec les icônes au lieu de les laisser déborder.
- Micro menu : FPS et latence sont maintenant deux petites barres sous l'heure, remplies selon la valeur (vert, orange, rouge).

## v0.46.0 — 15/11/2026

### Modifications
- Micro menu : nouvelles icônes dessinées au trait fin, à la couleur du thème, sur des tuiles sombres arrondies. Les douze raccourcis ont maintenant le même style.
- Nouvelles textures : relancer le jeu (un /reload ne suffit pas).

## v0.45.2 — 15/11/2026

### Ajouts
- Indicateur de distance : option « Masquer sans cible ».

### Corrections
- Indicateur de distance : sans cible, l'anneau gris et transparent était presque invisible. Il est maintenant beige sur un fond sombre, avec « sans cible » au centre.

## v0.45.1 — 15/11/2026

### Modifications
- Cadre du familier plus compact : la barre de vie prend toute la largeur, et une seule ligne en dessous réunit les boutons (à gauche), l'humeur (au milieu) et la nourriture avec son nombre (à droite).

### Corrections
- Cadre du familier : le chiffre de vie était illisible sur la barre verte. Il a maintenant un contour noir et la barre est un peu plus sombre.

## v0.45.0 — 15/11/2026

### Modifications
- QoL : nouvelle entrée « Micro menu » sous Halo, avec les réglages de l'horloge et des raccourcis (heure locale ou serveur, format, effet loupe, FPS et latence, place de chaque raccourci). Dans le mode édition, l'élément s'appelle aussi « Micro menu ».

### Corrections
- Les réglages de l'horloge et des raccourcis avaient disparu de QoL > Général depuis la 0.43.1 (retirés par erreur avec la carte « Disposition à l'écran »). Ils sont de retour, dans « Micro menu ».

## v0.44.3 — 15/11/2026

### Modifications
- QoL > Chasseur > Familier : le bouton « Macro Nourrir » est retiré (le cadre du familier et son raccourci clavier font mieux) ; il reste le bouton « Maître des écuries », à la couleur du thème.

## v0.44.2 — 15/11/2026

### Modifications
- Mode édition : la fenêtre de Warband Keeper se rouvre à la sortie si elle était ouverte au moment d'entrer.

## v0.44.1 — 15/11/2026

### Modifications
- « Éditer l'interface » devient un bouton à droite de l'en-tête, sur toutes les pages, à la couleur d'accent du thème (au lieu d'une pastille de la page QoL).

## v0.44.0 — 15/11/2026

### Ajouts
- Chasseur : indicateur de distance, un anneau coloré selon la cible : vert à portée de tir, orange au corps à corps, jaune dans la zone morte (5 à 8 m, option), rouge trop loin, gris sans cible. Fourchette de distance estimée au centre.
- Réglages dans QoL > Chasseur > Indicateur de distance (seulement en combat, zone morte, distance au centre) ; position et taille en mode édition.

### Modifications
- Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).

## v0.43.2 — 15/11/2026

### Modifications
- Cadre du familier : les boutons Nourrir et Soigner deviennent des icônes (Nourrir le familier, Guérison du familier, et Ressusciter quand il est mort), avec leur nom au survol. Sous la nourriture, seulement le nombre en sac.

### Corrections
- Cadre du familier : la vie ne s'affichait pas sur WoW Forever (le jeu la donne parfois sous forme masquée, que l'addon ne peut pas lire). La barre et le chiffre sont maintenant affichés par le jeu lui-même, même dans ce cas.

## v0.43.1 — 15/11/2026

### Modifications
- La « carte du familier » s'appelle maintenant « cadre du familier ».
- Mode édition : pastille « Éditer l'interface » dans l'en-tête de la page QoL (et /wk edit) ; l'option « disposition propre à chaque perso » est dans la barre du mode édition. La carte « Disposition à l'écran » quitte QoL > Général.
- Chasseur : quand HunterSuite est chargé, une note le signale dans la fiche Chasseur, avec une option pour garder quand même le cadre et le bouton du familier, le bouton d'aspect et les rappels de Warband Keeper (sinon masqués pour ne pas faire doublon).

## v0.43.0 — 15/11/2026

### Ajouts
- Horloge en haut de l'écran : l'heure et deux points de couleur pour les FPS et la latence. Au survol, les raccourcis glissent de chaque côté avec un effet loupe façon dock, et se replient quand la souris s'en va. Clic sur l'heure : calendrier ; infobulle : date, heure du serveur, durée de la session, FPS et latence.
- Raccourcis au choix, à gauche ou à droite : Warband Keeper, courrier (point doré s'il y a du courrier), pierre de foyer, personnage, grimoire, talents, carte, journal de quêtes, social, métier principal, session de farm (point vert si elle tourne), menu du jeu.
- Réglages dans QoL > Général > Horloge et raccourcis : heure locale ou du serveur, 24 h ou 12 h, effet loupe (curseur), FPS et latence, et la place de chaque raccourci. Position et taille en mode édition.

### Modifications
- Nouveau fichier : relancer le jeu (un /reload ne suffit pas).

## v0.42.0 — 15/11/2026

### Modifications
- Barre de vol redessinée en « arc de vol » : le trajet en arc pointillé comme un vol vu de côté, le griffon qui glisse le long de l'arc (partie parcourue en couleur du thème), les relais en balises plantées sur l'arc avec leur nom.
- Médaillon à droite avec le temps restant et l'heure d'arrivée ; le bouton dit directement « Atterrir à … » avec le nom du prochain relais.

## v0.41.2 — 15/11/2026

### Ajouts
- Barre de vol : les étapes du trajet (relais intermédiaires) sont placées sur la piste avec leur nom, à la bonne distance ; celles déjà passées prennent la couleur du thème. « Atterrir » indique le relais où tu te poseras.

## v0.41.1 — 15/11/2026

### Modifications
- Carte du familier : quand le familier est mort, la carte reste affichée et « Soigner » devient « Ressusciter » (bouton, clic droit sur la carte et raccourci clavier). La barre et l'humeur indiquent « Mort ».

## v0.41.0 — 15/11/2026

### Ajouts
- Chasseur : bouton d'aspect avec l'icône de l'aspect actif (et en petit, le prochain). Clic : aspect suivant de ta liste ; clic droit : aspect principal. Marche en combat.
- Réglages dans QoL > Chasseur > Bouton d'aspect : aspects à alterner et aspect principal. Position et taille en mode édition.
- Raccourcis clavier (Options du jeu > Raccourcis > AddOns > Warband Keeper) : aspect suivant, aspect principal, nourrir le familier, soigner le familier.

### Modifications
- Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).

## v0.40.0 — 15/11/2026

### Ajouts
- Chasseur : carte du familier, affichée tant qu'un familier est là : nom et niveau, barre de vie, humeur (segments et texte), nourriture prévue (icône, nombre en sac et nom), boutons Nourrir et Soigner. Clic sur la carte : nourrir ; clic droit : Guérison du familier. Marche en combat.
- Réglages de la carte (QoL > Chasseur) : largeur, hauteur de la barre, chiffres (aucun, valeur, valeur / max, pourcentage), couleur (humeur, vie ou thème), humeur, nourriture, boutons, nom, quand l'afficher (toujours, hors combat, si besoin avec un seuil de vie), opacité hors combat. Position et taille en mode édition.

### Modifications
- Nouveau fichier : relancer le jeu (un /reload ne suffit pas).

## v0.39.1 — 15/11/2026

### Corrections
- Loot : avec les sacs pleins, les objets que le filtre voulait ramasser restaient au sol sans être comptés (la liste des objets laissés restait vide). Ils sont maintenant ajoutés à la liste, marqués « sacs pleins », et la fenêtre de butin se ferme comme d'habitude.

## v0.39.0 — 15/11/2026

### Ajouts
- Barre de vol : au départ d'un vol, « Départ › Arrivée », temps restant en grand, piste avec un griffon qui avance, et boutons « Atterrir » (se poser au prochain relais, si le jeu le permet), « Carte » et fermer.
- Durée des vols apprise au premier vol complet de chaque trajet, partagée entre tes persos ; avant ça, estimée d'après la distance (ou temps écoulé au tout premier vol).
- Réglage dans QoL > Général > Confort ; la barre se place et se redimensionne en mode édition.

### Modifications
- Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).

## v0.38.1 — 15/11/2026

### Ajouts
- Chasseur : bouton « Maître des écuries » dans QoL > Chasseur > Familier, qui guide vers le maître des écuries le plus proche (aussi avec /wk guide ecurie). Les maîtres des écuries de WoW Forever sont ajoutés à la base des lieux.

## v0.38.0 — 15/11/2026

### Ajouts
- Mode édition plein écran (QoL > Général > Disposition à l'écran, ou /wk edit) : grille, chaque élément encadré avec son nom et des exemples. Glisser pour déplacer (aimanté à la grille, Maj pour placer librement), tirer le coin pour la taille, flèches du clavier pour ajuster au pixel (Maj : 10), Échap ou « Terminer » pour quitter.
- Un clic sur un élément ouvre ses réglages : taille, opacité, réinitialisation ; pour la pile d'alertes, sens d'empilement (vers le bas ou le haut) et icônes affichées ou non. « Tout réinitialiser » (Maj + clic) remet tout en place.
- Disposition commune au compte, ou propre à chaque perso (option).
- Éléments concernés : pile d'alertes, bouton du familier, flèche de guidage. Leurs anciennes positions sont reprises.

### Modifications
- Le mode édition se ferme tout seul au début d'un combat (le jeu interdit de déplacer le bouton du familier en combat).
- Nouveau fichier : relancer le jeu (un /reload ne suffit pas).

## v0.37.0 — 15/11/2026

### Modifications
- QoL, fiches de classe : nouvelles tuiles des persos, une par ligne. Liseré et portrait à la couleur de classe, nom avec « classe · niveau », puis jusqu'à trois colonnes avec icône, valeur en grand, libellé et petite jauge ; une valeur passe en orange ou en rouge sous son seuil d'alerte.
- Chiffres de chaque classe : munitions, minutes de tir et humeur du familier (chasseur) ; poisons et crochetage (voleur) ; fragments d'âme, pierre de soins et pierre d'âme (démoniste) ; totems, ankhs et réincarnation (chaman) ; composants utiles au niveau du perso (mage, prêtre, paladin, druide) ; munitions et état de l'équipement (guerrier).

### Corrections
- Le « ~ » des estimations (« ~34 min de tir », « dans ~5 j ») s'affichait comme un petit accent en hauteur avec la police du jeu : remplacé par « env. ».

## v0.36.1 — 15/11/2026

### Ajouts
- Munitions : l'alerte donne aussi les minutes de tir restantes (« munitions basses (120, ~2 min de tir) »), dans « À faire », la fenêtre de connexion et le guidage.
- Munitions : nouveau seuil d'alerte en minutes de tir (QoL > fiche de classe > Munitions), en plus ou à la place du seuil en nombre.

## v0.36.0 — 15/11/2026

### Ajouts
- Munitions : les minutes de tir restantes (d'après ta vitesse de tir) s'affichent à côté du nombre de munitions dans les tuiles de la fiche de classe.
- Pile d'alertes : petites vignettes empilées (icône, texte, liseré de couleur) dans un cadre que l'on déplace en le glissant. Elle reste affichée tant que le problème n'est pas réglé.
- Chasseur : rappels dans la pile d'alertes, chacun désactivable dans QoL > Chasseur > Rappels : aucun aspect actif (hors combat), Guépard ou Meute en combat (hébétement), Grondement activé en donjon ou désactivé en solo, pistage des humanoïdes en champ de bataille (désactivé au départ).
- Chasseur : gros bouton rond qui pulse quand le familier est absent ou mort, même en combat. Clic : appeler, ou ressusciter s'il est mort ; clic droit : ressusciter ; Maj + glisser pour le déplacer. Désactivable dans QoL > Chasseur > Familier.
- Si l'addon HunterSuite est chargé, ces rappels et ce bouton se mettent en retrait pour ne pas faire doublon.

### Modifications
- Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).

## v0.35.0 — 15/11/2026

### Modifications
- Chasseur : la nourriture que le familier accepte est demandée directement au jeu (plus besoin de le nourrir une première fois à la main), avec son régime (viande, poisson…). La macro « Nourrir » est juste tout de suite.
- Munitions : l'achat automatique prend la meilleure munition vendue pour ton arme (flèches pour arc et arbalète, balles pour fusil) et utilisable à ton niveau, et l'équipe si elle est meilleure que celle en place.

### Corrections
- Chasseur : l'humeur du familier n'était jamais lue sur WoW Forever (la fonction du jeu a changé de place), donc l'alerte « n'est plus heureux » ne se déclenchait pas.

## v0.34.1 — 15/11/2026

### Modifications
- QoL > Général > Guidage : les boutons « le plus proche » prennent la couleur d'accent du thème, et le bouton « Arrêter » est retiré (la croix ou le clic droit sur la flèche arrêtent le guidage, comme /wk guide stop).

## v0.34.0 — 15/11/2026

### Modifications
- La « lueur de récolte » s'appelle maintenant « Halo » et passe dans QoL : nouvelle entrée « Halo » sous Général (avec son état, activé ou non), mêmes réglages qu'avant (portée, taille, intensité, quand ne pas l'afficher, objets et couleurs).
- Options > Récolte ne garde que les coins de récolte sur la carte du monde.

## v0.33.0 — 15/11/2026

### Modifications
- Patch notes : trois couleurs distinctes et fixes (vert sauge pour les ajouts, ambre pour les modifications, vieux rose pour les corrections), avec un symbole dans le badge (+, ~, !) et un liseré de couleur à gauche de chaque rubrique.
- Historique (or, richesse, matériaux suivis) : au-delà de 30 jours, un seul point par jour est gardé. Les courbes ne changent pas, mais les données ne grossissent plus sans fin (connexion et déconnexion plus rapides à la longue).
- Options > Récolte : la lueur précise qu'il faut l'éteindre avant de désinstaller l'addon (les réglages du jeu qu'elle modifie sont rendus à l'arrêt).

### Corrections
- Barre latérale : avec une fenêtre basse, le groupe « Confort » (QoL) passait sous « Patch notes » et « Options ». L'espacement se resserre maintenant quand la place manque.
- QoL : la colonne des classes se resserre aussi dans une fenêtre basse, pour garder une marge sous la dernière classe.
- Courrier : après un envoi raté, le message d'erreur d'un échec précédent pouvait réapparaître dans le diagnostic.
- Fiche métier d'un autre perso : « Recettes lues le… » chevauchait le libellé « Artisan » de la barre des rangs ; il est maintenant sur la ligne des boutons.

## v0.32.5 — 15/11/2026

### Modifications
- Métiers : le bouton « Link tchat » et le réglage de son texte sont retirés sur Herboristerie, Dépeçage et Pêche, qui n'ont pas de lien de métier.

## v0.32.4 — 15/11/2026

### Modifications
- Métiers : le bouton « Lier dans le chat » s'appelle maintenant « Link tchat ».

### Corrections
- Link tchat sur Herboristerie, Dépeçage ou Pêche : l'addon essayait d'ouvrir une fenêtre de métier qui n'existe pas, puis affichait « Le jeu n'a pas donné le lien ». Ces métiers n'ont pas de lien : le nom et le niveau sont envoyés tout de suite, sans message.

## v0.32.3 — 15/11/2026

### Corrections
- Messages du chat : « Warband Keeper » s'affichait toujours en bleu. Il prend maintenant la couleur d'accent du thème choisi.

## v0.32.2 — 15/11/2026

### Modifications
- Chat épuré : plus de message « chargé » à chaque connexion (seulement à la première installation), plus de liste d'alertes à la connexion quand la fenêtre de rappels est active (sinon une seule ligne).
- Courrier : un seul bilan à la fin de l'envoi automatique (« Courrier envoyé : 24 à Lapine, 12 à Brumefer ») au lieu d'une ligne par lettre.
- Marchand : réparation, objets gris vendus et achats automatiques regroupés sur une seule ligne.
- Montants plus courts : les parties à zéro ne sont plus écrites (« 50pa » au lieu de « 0po 50pa 0pc »).
- Les rappels (familier, poisons, buffs, guidage, maître de classe) ne s'affichent plus qu'au milieu de l'écran, plus dans le chat. Invitations acceptées et duels refusés se font sans message. Les boutons de guidage n'écrivent plus rien quand la flèche est affichée.

## v0.32.1 — 15/11/2026

### Modifications
- Métiers > Lier dans le chat : si le lien n'est pas encore enregistré, l'addon ouvre la fenêtre du métier une fois pour le lire, la referme et colle le lien (perso connecté). Pour un autre perso, le message explique qu'il faut le connecter et ouvrir son métier une fois. L'infobulle du bouton le précise aussi.

## v0.32.0 — 15/11/2026

### Ajouts
- QoL > Général > Marchand : la fenêtre du marchand se ferme toute seule après une réparation automatique (une fois les objets gris vendus et les achats faits). Maj enfoncée en parlant au marchand : elle reste ouverte. Désactivable.

## v0.31.1 — 15/11/2026

### Corrections
- Erreur au chargement « Attempt to register unknown event CRAFT_SHOW » : un évènement absent de ce client faisait échouer le chargement d'une partie de l'addon. Les évènements inconnus du client sont maintenant ignorés sans erreur.

## v0.31.0 — 15/11/2026

### Ajouts
- Guidage vers le lieu utile le plus proche : boîte aux lettres, banque, réparation, marchand, munitions, composants de classe et maître de classe. Une flèche à l'écran (déplaçable, clic droit pour arrêter) indique la direction et la distance, et un repère s'affiche sur la carte du monde.
- Les alertes de QoL guident d'elles-mêmes : sacs presque pleins (boîte aux lettres, banque ou marchand le plus proche), équipement à réparer, composants ou munitions bas (marchand qui les vend). Hors combat et hors donjon, une fois toutes les 10 minutes par sujet.
- Maître de classe : à chaque niveau pair (nouveaux sorts), guidage vers le maître de ta classe le plus proche.
- QoL > Général > Guidage : réglages, boutons « le plus proche » et commande /wk guide (boite, banque, reparer, marchand, maitre, munitions, stop).
- Les lieux viennent de la base de données de Questie pour WoW Forever (QuestieDB, licence GPLv3), avec les noms français des PNJ : rien à apprendre, tout est connu dès le départ. Les marchands saisonniers (fêtes, foire) sont écartés.

### Modifications
- Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).

## v0.30.1 — 15/11/2026

### Ajouts
- Commande /wk lien : ce que le jeu a répondu à la dernière ouverture d'un métier, et les liens gardés pour le perso (pour comprendre un lien qui ne vient pas).

### Corrections
- Métiers > Lier dans le chat : le lien de la fenêtre du métier n'était jamais retenu sur ce client (seul le nom et le niveau partaient). L'addon essaie maintenant toutes les façons de l'obtenir à l'ouverture du métier, et retient aussi un lien de métier que tu mets toi-même dans le chat depuis la fenêtre du jeu.

## v0.30.0 — 15/11/2026

### Ajouts
- Nouvel onglet QoL (qualité de vie), dans un nouveau groupe « Confort » du menu : une colonne avec Général et les 9 classes (grisées quand aucun perso ne les joue), le nombre d'alertes à côté de chacune.
- QoL > Général : réparation automatique chez le marchand (plafond possible, or de guilde d'abord en option) et vente automatique des objets gris avec le total dans le chat.
- QoL > Général : durabilité de l'équipement et places libres dans les sacs et la banque de chaque perso (banque relevée à chaque visite), avec une alerte sous un seuil choisi (dans « À faire » et la fenêtre de connexion).
- QoL > Général : accepter les invitations de groupe des amis et de la guilde, refuser les duels (sauf amis et guilde en option), libérer l'esprit en champ de bataille, confirmer le butin lié quand on est seul, descendre de monture ou se lever quand une action l'exige, passer les cinématiques.
- Fiches de classe : tes persos de la classe en tête (stock de leurs composants), puis les composants de la classe avec un seuil d'alerte et un achat automatique chez le marchand jusqu'à la quantité voulue.
- Munitions (chasseur, guerrier, voleur) : alerte quand il en reste peu et achat automatique du même type de munitions.
- Chasseur : alerte quand le familier n'est plus heureux, nourriture qu'il accepte (apprise quand tu le nourris) et macro « Nourrir » qui choisit la nourriture toute seule.
- Voleur : alerte avant la fin des poisons sur les armes, coffres à crocheter dans les sacs de tes persos avec la compétence demandée, or volé à la tire.
- Démoniste : nombre maximum de fragments d'âme et bouton pour supprimer ceux en trop (Maj + clic). Mage : annonce de portail prête pour le chat. Guerrier : deux équipements d'armes (deux mains, arme et bouclier) à enregistrer et équiper en un clic. Chaman : totems en sac et temps de recharge de la Réincarnation.
- Rappels à l'écran hors combat : Robustesse du groupe (prêtre), aura et bénédiction (paladin), Marque du fauve (druide).
- Pastilles de l'en-tête QoL : composants bas, persos à réparer, sacs pleins et classes jouées.

### Modifications
- Nouveaux fichiers et nouvelle icône : relancer le jeu (un /reload ne suffit pas).

## v0.29.1 — 14/11/2026

### Ajouts
- Message dans le chat quand des objets voulus n'ont pas pu être ramassés (sacs pleins).

### Corrections
- Filtre de loot : la fenêtre de butin pouvait rester ouverte, vide ou avec des objets voulus, quand le jeu donnait son contenu un peu tard. Le filtre attend maintenant le contenu, ferme une fenêtre vide et réessaie de ramasser les objets voulus.

## v0.29.0 — 14/11/2026

### Ajouts
- Inventaire > À regrouper : les composants, consommables, gemmes et recettes présents chez plusieurs persos, avec le perso conseillé (celui qui en a le plus, ou celui d'une règle d'envoi existante) et un bouton « Regrouper » qui crée la règle d'envoi.
- Inventaire > Oubliés en banque : les objets de valeur qui dorment dans une banque (perso ou bataillon) depuis 7, 14 ou 30 jours, avec leur valeur et le total à revendre.

### Modifications
- La date depuis laquelle chaque objet dort en banque est suivie à partir de cette version : ouvre tes banques une fois pour démarrer le suivi.

## v0.28.0 — 14/11/2026

### Ajouts
- Coins de récolte : chaque plante, minerai ou cuir ramassé note l'endroit (tous les persos). Sur la carte du monde, une pastille par coin, de la couleur de la ressource et plus grosse là où tu récoltes souvent ; son survol détaille ce que tu y as récolté.
- Options > Récolte : enregistrer les récoltes, les afficher sur la carte du monde, et Maj + clic pour tout effacer.
- Farm en direct : or à l'heure, objets à l'heure et valeur du butin à l'heure sur les tuiles ; « Total / heure » comparé au record des 7 derniers jours (au survol : la zone du record). Le meilleur spot de la semaine est dans les pastilles et dans la mini-fenêtre.
- Fenêtre de rappels à la connexion d'un perso : les tâches du moment (comme « À faire » du Résumé), cliquables. Désactivable, avec un aperçu, dans Options > Général.

### Modifications
- Options : la section « Lueur » devient « Récolte » (lueur et coins de récolte).
- Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).

## v0.27.0 — 14/11/2026

### Ajouts
- Lueur de récolte : plantes, filons, objets de quête, coffres et flotteur de pêche brillent à ton approche (soft targeting du jeu). Halo qui respire, plus vif avec un anneau quand l'objet est à portée.
- Options > Lueur : activation (éteinte par défaut), portée, taille, intensité, couleur et activation par type d'objet, et masquage en combat, en instance ou sans le métier de récolte.
- Les réglages du jeu modifiés pour la lueur sont rendus à l'arrêt. Si l'addon Lueur est installé, cette lueur reste éteinte pour ne pas se disputer avec lui.

### Modifications
- Nouveaux fichiers et textures : relancer le jeu (un /reload ne suffit pas).

## v0.26.0 — 14/11/2026

### Ajouts
- Fiche métier (tous les métiers) : bouton « Lier dans le chat » qui colle le lien de la fenêtre du métier du jeu, cliquable par les autres joueurs. Le lien est enregistré à chaque ouverture du métier, on peut donc le coller depuis n'importe quel perso.
- Texte personnalisé par métier (roue dentée à côté du bouton) : ajouté après le lien quand l'interrupteur « Ajouter ce texte au lien » est activé, avec un aperçu.

## v0.25.0 — 14/11/2026

### Ajouts
- Fiche métier > « Manquantes » : les recettes que le perso ne connaît pas (toutes les recettes de WoW Forever, d'après wowtbc.gg), avec le niveau requis, où les obtenir (maître, vendeur et sa zone, ou à trouver) et leur prix à l'HV. Filtre « Apprenables » (les plus utiles d'abord) ou « Toutes ».
- Métiers > Recettes : bouton « Rentables maintenant » qui ne garde que les recettes rentables faisables avec les composants du compte, triées par gain total possible.
- Temps de recharge des fabrications (transmutations, étoffe lunaire…) : enregistrés à l'ouverture du métier, affichés sur la recette, et « de nouveau disponible » dans « À faire » du Résumé.
- Hôtel des ventes : les ventes et achats sont lus sur les factures du courrier quand tu en prends l'or ou l'objet. Ils apparaissent dans le Journal (filtre « HV ») et la pastille « Bilan HV 7 j » des Stats donne ventes, achats et meilleures ventes.

### Modifications
- Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).

## v0.24.1 — 14/11/2026

### Ajouts
- Guides : pour chaque recette à acheter, sa disponibilité à l'hôtel des ventes d'après Auctionator (« HV : 1 po 50 pa (vu il y a 2 j) » ou « pas vu à l'HV »), sur la ligne de l'étape, au survol et dans les matériaux.

## v0.24.0 — 14/11/2026

### Ajouts
- Guides de montée de WoW Forever pour l'Alchimie, la Forge, l'Enchantement, l'Ingénierie et la Couture : tous les métiers d'artisanat ont maintenant leur guide.
- Guides : les outils nécessaires (bâtonnets runiques, clé Arclight, marteau de forgeron…) apparaissent au survol des étapes ; un outil à acheter, comme le marteau de forgeron, est ajouté aux matériaux.

### Modifications
- Les enchantements, qui ne fabriquent pas d'objet, s'affichent avec le nom de la recette du jeu ; une recette d'enchantement déjà apprise est reconnue.

## v0.23.4 — 14/11/2026

### Modifications
- Infobulles de l'addon : mêmes couleurs que les cadres du thème choisi (fond et bordure), quel que soit le thème.

## v0.23.3 — 14/11/2026

### Modifications
- Bouton fermer (fenêtre et liste des objets laissés au sol) : la croix prend la couleur d'accent du thème, sans infobulle.

## v0.23.2 — 14/11/2026

### Modifications
- Guides de montée : les étapes qui demandent une recette l'indiquent clairement (« Recette à acheter chez … » avec le vendeur et sa zone quand elle est connue, ou « Recette connue » si le perso l'a déjà).
- Survol d'une étape : la recette et la liste complète de ses vendeurs avec leur zone.

### Corrections
- Matériaux du guide : l'infobulle d'une recette renvoyait au guide, qui n'en disait rien. Elle donne maintenant l'étape concernée et les vendeurs.

## v0.23.1 — 14/11/2026

### Modifications
- Infobulles de l'addon : fond très sombre, bordure fine et claire, coins arrondis, sans liseré de couleur.

## v0.23.0 — 14/11/2026

### Modifications
- Métiers > Niveaux : chaque métier d'un perso devient une tuile cliquable avec son icône, son niveau, une mini-barre des rangs (1-300) et ce qu'il y a à faire ensuite : étape du guide en cours, ressource et zone conseillées pour la récolte, ou « Plafond atteint : va voir le maître » (tuile encadrée en orange).
- Les cartes des persos prennent toute la largeur ; les tuiles s'adaptent à la taille de la fenêtre.

## v0.22.2 — 14/11/2026

### Modifications
- Fiche d'un métier : les onglets « Niveaux / Recettes / Liste de courses » sont masqués (ils reviennent sur la liste des métiers) et la fiche remonte à leur place.

## v0.22.1 — 14/11/2026

### Modifications
- Fiche métier (tous les métiers) : nouvel en-tête avec une barre des rangs de 1 à 300, découpée en Apprenti, Compagnon, Expert et Artisan, le rang en cours en clair et un repère à ton niveau.
- Fiche métier : la flèche de retour devient un bouton « Niveaux » plus visible.

## v0.22.0 — 14/11/2026

### Modifications
- Métiers de récolte : « Où aller à ton niveau » devient des tuiles de zones, avec le niveau des monstres de chaque zone et les ressources utiles qu'on y trouve (pastille orange ou jaune). Ta zone actuelle passe en premier, encadrée avec « tu y es ».
- Toutes les infobulles de l'addon prennent son style : fond et bordure du thème, coins arrondis, liseré de la couleur d'accent. Les infobulles du jeu et des autres addons ne changent pas.

## v0.21.1 — 14/11/2026

### Modifications
- Guides de montée : les objets que le guide fabrique lui-même (peaux traitées, bandages…) n'apparaissent plus dans les matériaux. Les cuirs fabriqués seulement pour monter restent comptés, moins ce que le guide en produit.
- Matériaux du guide : le prix de ce qui manque sur chaque ligne (« ok » quand tu as tout), le prix unitaire au survol, et le total à acheter en bas.
- Les recettes à acheter chez un vendeur font partie des matériaux, sauf celles que le perso connaît déjà.

## v0.21.0 — 14/11/2026

### Ajouts
- Résumé : carte « À faire » à gauche de la courbe, avec les actions utiles du moment, les plus urgentes d'abord : courrier à récupérer (en rouge s'il expire bientôt), butin automatique du jeu qui bloque le filtre, métier au plafond de son rang à faire monter chez le maître, objets à envoyer ou à déposer, banque pas vue, session de farm en pause, composants manquants de la liste de courses.
- Chaque ligne de « À faire » est cliquable et mène à la bonne page.

## v0.20.1 — 14/11/2026

### Modifications
- Résumé : le bloc « Or du compte » et ses tuiles (persos, temps de jeu, règles, à envoyer) est retiré, il faisait doublon avec les pastilles du haut. La courbe d'évolution de l'or prend toute la largeur.
- Persos : la pastille « Temps de jeu total » (tous les persos) passe en premier.
- Persos : survoler la pastille « Alertes » liste chaque alerte (perso et raison) ; un clic ouvre Options > Alertes.

### Corrections
- Métiers : les pastilles comptaient plusieurs fois un métier ou une recette connus par plusieurs persos.

## v0.20.0 — 14/11/2026

### Ajouts
- Guides de montée de WoW Forever pour le Travail du cuir, le Secourisme et la Cuisine (d'après wowtbc.gg) : dans la fiche du métier, onglet « Guide de montée ».
- Le guide met en avant l'étape en cours selon le niveau du perso (avec les fabrications qui restent), grise les étapes faites, et indique les maîtres de chaque rang pour la faction du perso, ainsi que les recettes à acheter et leurs vendeurs.
- Matériaux jusqu'au max : ce qu'il faut, ce que le compte possède déjà, ce qui manque et son coût. Bouton « Liste Auctionator » pour les manquants, et « Envoyer à ce perso » pour créer les règles d'envoi des composants.

### Modifications
- Nouveau fichier : relancer le jeu (un /reload ne suffit pas).

## v0.19.0 — 14/11/2026

### Ajouts
- Métiers de récolte (Minage, Herboristerie, Dépeçage) : la fiche du métier liste chaque ressource avec son niveau requis et les zones où la trouver, au lieu des recettes.
- Les ressources orange et jaunes pour le niveau du perso sont mises en valeur, et une carte « Où aller à ton niveau » donne les zones conseillées (ta zone actuelle en vert).
- Dépeçage : niveau des monstres par type de cuir, et niveau maximal des monstres que le perso peut dépecer.

### Modifications
- Nouveau fichier : relancer le jeu (un /reload ne suffit pas).

## v0.18.0 — 14/11/2026

### Modifications
- En haut des pages, le titre et la phrase d'explication sont remplacés par des pastilles avec les chiffres clés de la page (or, richesse, courrier en attente, session de farm, objets et valeur des stocks, règles, objets à envoyer…).
- Certaines pastilles sont cliquables et mènent à la bonne page : courrier en attente, liste de courses, source des prix, valeur laissée au sol…

## v0.17.1 — 14/11/2026

### Modifications
- La fenêtre s'ouvre toujours sur le Résumé (un raccourci vers une page précise, comme le clic droit sur le bouton minimap, ouvre toujours cette page).

## v0.17.0 — 14/11/2026

### Ajouts
- Loot : bouton « Voir la liste » qui affiche tous les objets laissés au sol, avec la quantité, le nombre de fois, la dernière fois, le prix à l'unité et la valeur totale.
- Liste des objets laissés au sol : tri par valeur, quantité ou récents, total en haut, bouton + pour toujours ramasser un objet, et Maj + clic sur « Vider la liste » pour repartir de zéro.

### Modifications
- Les objets laissés au sol sont maintenant cumulés depuis la dernière remise à zéro (avant, seuls les 40 derniers étaient gardés).

## v0.16.2 — 14/11/2026

### Modifications
- Loot : « Activation auto » devient « Se charge tout seul », avec une phrase qui explique le choix (« Jamais (bouton Charger) », zone, donjon, raid, JcJ, session de farm).

### Corrections
- Loot : le choix « Zone » proposait la zone où tu étais à l'ouverture de la fenêtre au lieu de ta zone actuelle.

## v0.16.1 — 14/11/2026

### Modifications
- Loot : le filtre s'active dans un bandeau en haut de la page, qui montre son état et le profil chargé (au lieu d'un petit interrupteur en bas de la colonne).
- Courrier : la ligne « Mes persos » est remplacée par un petit bouton liste à côté du destinataire, qui propose tes persos avec leur nom complet. Le champ reste libre pour un autre joueur.

## v0.16.0 — 14/11/2026

### Ajouts
- Options > Courrier : tous les réglages du courrier et de la banque au même endroit (envoi automatique, fermeture de la boîte aux lettres, tri des sacs, prise automatique, dépôt automatique).
- Page Courrier : bouton « Réglages » qui mène à Options > Courrier, et état de l'automatisme de l'onglet (activé / désactivé).

### Modifications
- Options : Thèmes et Apparence ne forment plus qu'une section « Apparence ».
- La page Courrier ne garde que les règles et les boîtes aux lettres : plus de place pour la liste.

## v0.15.1 — 14/11/2026

### Corrections
- L'infobulle de la pierre de foyer listait inutilement tous les persos qui l'ont dans leurs sacs.

## v0.15.0 — 14/11/2026

### Ajouts
- Résumé : une enveloppe à côté du nom des persos qui ont du courrier en attente. Elle passe au rouge quand le courrier expire bientôt (seuil réglé dans Options > Alertes).
- Survol de l'enveloppe : nombre de lettres, objets, or et jours avant expiration.

## v0.14.0 — 14/11/2026

### Ajouts
- Les sacs sont triés automatiquement après l'envoi du courrier (et la prise automatique) et après le dépôt en banque, avec le tri du jeu.
- Option « Trier les sacs ensuite » dans Courrier > Envoi et dans Courrier > Dépôt banque (activée par défaut).

### Modifications
- Le tri n'a lieu que si quelque chose a été envoyé ou déposé ; la boîte aux lettres se ferme juste après le tri.

## v0.13.0 — 14/11/2026

### Ajouts
- Courrier : la boîte aux lettres se ferme toute seule après l'envoi automatique (après la prise automatique si elle est activée). Option dans Courrier > Envoi.
- Règles d'envoi et de dépôt en banque par perso : « Envoyé par » / « Déposé par » permet de choisir un perso, ou tous les persos.
- La liste des règles indique pour qui vaut chaque règle (« par Brumefer » ou « tous les persos »).

### Modifications
- Une règle propre à un perso passe avant la règle « tous les persos » pour le même objet ou la même catégorie. Les règles existantes valent pour tous les persos.

## v0.12.0 — 14/11/2026

### Ajouts
- Courrier : nouvelles catégories « Objets LQE (vert et +) », « (bleu et +) » et « (épiques) » pour envoyer automatiquement les objets liés quand équipés à un perso (enchanteur, vendeur à l'HV...). Elles marchent aussi pour le dépôt en banque.

### Modifications
- Un objet LQE déjà équipé (donc lié) n'est jamais envoyé. Si plusieurs règles LQE existent, la plus exigeante l'emporte : un épique va à la règle « épiques ».

## v0.11.0 — 14/11/2026

### Ajouts
- Portraits à côté du nom des persos (Résumé, Persos, Inventaire, Métiers, Courrier) : le vrai portrait pour le perso connecté, l'icône de race et de sexe pour les autres.
- Options > Apparence : « Portraits des persos » pour revenir aux icônes de classe.

### Modifications
- Le sexe de chaque perso est enregistré à la connexion : connecte chaque perso une fois pour avoir la bonne icône.

## v0.10.1 — 14/11/2026

### Ajouts
- Métiers > Niveaux : le nombre de recettes connues est affiché à côté de chaque métier, par exemple « Cuisine (4 recettes) ».
- Options > Général > Combat : « Fermer la fenêtre en combat ». La fenêtre se ferme au début d'un combat ; la mini-fenêtre de la session de farm reste affichée.

### Corrections
- Le bouton « Ouvrir le métier » pouvait empêcher de fermer la fenêtre pendant un combat.
- Options : certaines descriptions étaient coupées (par exemple « Auto : celle du j... »).

## v0.10.0 — 14/11/2026

### Ajouts
- Métiers : clic sur un métier dans l'onglet Niveaux pour ouvrir sa fiche : niveau, recettes connues du perso avec leur couleur (orange, jaune, vert, gris), composants possédés sur tout le compte, coût et bénéfice.
- Fiche métier : filtres « Font monter » (recettes orange, jaunes et vertes) et « Possibles » (composants déjà sur le compte), recherche, et bouton + vers la liste de courses.
- Fiche métier : bouton « Ouvrir le métier » pour le perso connecté. Pour les autres persos, la date à laquelle leurs recettes ont été lues.

### Modifications
- Les couleurs des recettes sont enregistrées à l'ouverture de chaque métier : ouvre-le une fois sur chaque perso pour les voir.

## v0.9.5 — 14/11/2026

### Modifications
- Le nom complet des persos (« Prénom Nom ») est affiché dans tout l'addon : résumé, persos, inventaire, métiers, stats, farm, journal, alertes, infobulles et messages du chat.
- Persos : clic droit sur un perso pour corriger son nom complet (comme dans Courrier). Un nom trop long est coupé proprement au lieu de déborder sur les colonnes.

## v0.9.4 — 14/11/2026

### Corrections
- La barre de défilement ne réagissait pas à la souris : un clic sur la barre amène la liste à cet endroit, et le curseur se fait glisser.

## v0.9.3 — 14/11/2026

### Ajouts
- Noms en deux parties (« Prénom Nom ») : l'envoi automatique utilise le nom complet de tes persos.
- Clic droit sur un perso dans Courrier > Nouvelle règle pour corriger son nom complet si le jeu ne le donne pas.
- Commande /wk nom : affiche le nom utilisé pour le courrier.

### Modifications
- Une règle écrite avec le prénom seul est envoyée au nom complet du perso du compte, s'il n'y a pas d'ambiguïté.
- En cas d'échec d'un envoi, le chat indique le destinataire utilisé et la raison donnée par le jeu.

### Corrections
- /wk envoi ajoute ne gardait que le dernier mot d'un nom en deux parties.

## v0.9.2 — 14/11/2026

### Ajouts
- Prix : nouvelle source « Les deux ». L'Inventaire affiche le prix HV et le prix marchand côte à côte, et l'infobulle des objets donne les deux prix à l'unité. Les calculs (stocks, richesse, butin, rentabilité, filtre de loot) prennent le meilleur des deux : ce que tu tirerais vraiment de l'objet.

### Modifications
- Options > Prix : la description indique ce que fait la source choisie.

## v0.9.1 — 14/11/2026

### Modifications
- Redimensionnement fluide : les pages suivent la souris en direct pendant qu'on agrandit ou réduit la fenêtre (cartes, colonnes des tableaux, tuiles, catégories du loot), et les graphiques sont redessinés au fur et à mesure. Plus besoin de relâcher la souris.
- Replier ou déplier le menu redimensionne aussi les pages en direct.
- « Notes de patch » devient « Patch notes ».
- Patch notes : la section « À venir » est toujours en haut, au-dessus des versions. Pareil dans CHANGELOG.md sur GitHub.

### Corrections
- Sur une grande fenêtre, la ligne d'objectif des Stats s'arrêtait avant le bord du graphique.

## v0.9.0 — 14/11/2026

### Ajouts
- Filtres de loot : profils de ramassage par situation (Tout ramasser, Farm, Donjon, Raid, Or et quêtes seulement…), à créer, dupliquer, renommer et charger d'un clic. Les objets refusés restent sur le corps.
- Chaque profil fixe une qualité minimale, une valeur minimale (au prix Auctionator ou marchand), des catégories toujours ramassées et des listes « toujours » et « jamais » (Maj + clic). L'or, les monnaies et les objets de quête sont toujours ramassés, tout comme, si tu le souhaites, les objets de tes règles d'envoi et de dépôt.
- Activation automatique d'un profil selon la zone, le type d'instance (donjon, raid, JcJ) ou une session de farm, avec un message dans le chat quand le profil change. Le profil actif apparaît dans la mini-fenêtre de farm.
- Liste des derniers objets laissés au sol : un clic en ajoute un à la liste « toujours ». Maj maintenue en ouvrant un butin désactive le filtre pour ce butin. Un bouton désactive le butin automatique du jeu, qui empêche le filtre de choisir.
- Fenêtre redimensionnable avec la poignée en bas à droite : les pages se redessinent à la nouvelle taille (tableaux, listes et graphiques s'étirent), et la taille est mémorisée.

### Modifications
- Nouvelle disposition : barre latérale groupée (Compte, Économie, Farm, puis Notes de patch et Options), repliable en icônes avec « Réduire le menu ». Le titre de la page et les boutons Scanner et Fermer passent dans l'en-tête du contenu.
- Les colonnes des tableaux du Résumé et des Persos suivent la largeur de la fenêtre.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

## v0.8.2 — 14/11/2026

### Modifications
- Ordre des sections des Options : Général, Prix, Alertes, Thèmes, Apparence, À propos. Général s'ouvre par défaut.

## v0.8.1 — 14/11/2026

### Modifications
- Options rangées en sections verticales à gauche : Thème, Apparence, Général (langue, bouton minimap, position de la fenêtre), Prix, Alertes et À propos. La dernière section ouverte est mémorisée.
- Les vignettes de thèmes passent sur deux rangées pour rester lisibles.
- À propos : bouton pour ouvrir les notes de patch.

## v0.8.0 — 14/11/2026

### Ajouts
- Rentabilité des fabrications : pour chaque recette, coût des composants, prix de vente de l'objet fabriqué et bénéfice, au prix d'Auctionator (sinon prix marchand). Tri des recettes par nom, bénéfice ou nombre de fabrications possibles ; le détail est dans l'infobulle.
- Meilleurs spots de farm : la page Farm classe les zones par or/heure (or ramassé + valeur du butin au prix actuel), avec le nombre de sessions, le temps passé et le meilleur perso. Clique sur un spot pour voir tout le butin récolté dans cette zone.
- Thème personnalisé : un 8e thème dont tu choisis les 7 couleurs (fond, bordures, cadre, halo, textes, accent) avec le sélecteur de couleur du jeu, en partant si tu veux du thème actuel.

### Modifications
- Le thème, la police, l'arrondi, l'opacité et la langue s'appliquent tout de suite, sans recharger l'interface : la fenêtre, le bouton minimap et la mini-fenêtre de farm sont redessinés.
- La carte Historique de la page Farm a deux vues : Sessions et Meilleurs spots.

## v0.7.0 — 14/11/2026

### Ajouts
- Valeur du compte : les stocks (sacs, banques, courrier, bataillon) sont estimés au prix d'Auctionator, ou au prix marchand si Auctionator n'est pas installé ou n'a pas de prix. Le Résumé affiche la valeur des stocks sous l'or du compte.
- Nouvelle série « Richesse totale » (or + stocks) dans les Stats, avec son historique.
- Inventaire : valeur estimée de chaque ligne et du contenu de l'onglet.
- Objectifs : sur l'or, la richesse totale ou un matériau, depuis la page Stats. Ligne pointillée sur le graphique, pourcentage atteint et date estimée au rythme des 7 derniers jours. Les objectifs apparaissent aussi en bandeau sur le Résumé.
- Métiers > Recettes : les recettes connues de chaque perso (enregistrées à l'ouverture de la fenêtre de métier), qui peut les fabriquer et combien de fois avec le stock du compte. L'infobulle détaille les composants possédés.
- Métiers > Liste de courses : fabrications prévues (+ / -), composants nécessaires, possédés et manquants, coût des manquants. Bouton « Créer la liste Auctionator » pour acheter les composants manquants dans Auctionator.
- Options : choix de la source des prix (Auctionator ou marchand).

### Modifications
- La session de farm estime la valeur du butin au prix d'Auctionator quand il est disponible.
- Les en-têtes en majuscules gardent leurs accents (POSSÉDÉ, COÛT…).
- Les flèches du Journal utilisent « » », un symbole que la police du jeu sait afficher.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

## v0.6.1 — 14/11/2026

### Ajouts
- Inventaire : onglets par personnage dans une colonne à gauche (icône et couleur de classe, nombre d'objets), plus « Tout le compte » et « Banque de bataillon ».
- Sur l'onglet d'un personnage, chaque objet indique où il se trouve (sacs, banque, courrier), et l'en-tête résume sacs occupés, dernière visite à la banque et lettres en attente.

### Modifications
- L'Inventaire retient le dernier onglet ouvert. La recherche et les filtres Sacs / Banque / Courrier s'appliquent à l'onglet choisi.

## v0.6.0 — 14/11/2026

### Ajouts
- Thèmes : 7 thèmes au choix dans les Options, avec un aperçu de chacun. Coffre-fort (bois et or), Givre (bleu nuit et cyan), Graphite (gris neutre), Héraldique (aux couleurs de ta classe), Faction (bleu et or pour l'Alliance, rouge et fer pour la Horde), Gangrefeu (vert gangrené) et Néant (violet).
- Couleur d'accent : en plus des couleurs fixes, « Thème » suit l'accent du thème choisi et « Classe » prend la couleur de classe du perso connecté.
- Réglages d'apparence : police (Friz Quadrata ou Arial Narrow), arrondi (fort, moyen ou carré) et opacité du fond de la fenêtre.

### Modifications
- Les Options commencent par la carte Thème. Un bouton « Recharger pour appliquer » apparaît quand un réglage demande de recharger l'interface (thème, police, arrondi, opacité, langue).
- Les thèmes Héraldique et Faction s'adaptent au perso connecté.
- Changer de thème remet l'accent sur celui du thème.
- Nouveau fichier : redémarrer complètement le jeu après la mise à jour.

## v0.5.0 — 14/11/2026

### Ajouts
- Règles par catégorie : étoffes, cuirs, métaux et pierres, herbes, éléments, enchantement, gemmes… Une seule règle suffit pour envoyer tout un type de composant. Une règle sur un objet précis reste prioritaire.
- Seuil « Garder » : une règle peut garder une quantité dans les sacs (ex. garder 20 potions) et n'envoie ou ne dépose que le surplus, en partageant une pile si besoin.
- Page Farm : session de farm avec chrono, pause, or ramassé, nombre d'objets, valeur marchande du butin et or par heure. Le butin est listé avec sa quantité par heure, et chaque session terminée est gardée dans un historique consultable (zone, durée, or/h).
- Mini-fenêtre déplaçable pendant une session : chrono, or par heure, nombre d'objets, boutons pause et fin. Commande /wk farm pour démarrer ou terminer.
- « Tout prendre » : un bouton dans la boîte de réception du jeu récupère l'or et les objets de toutes les lettres, sauf les contre-remboursements, et s'arrête quand les sacs sont pleins. Option pour le faire automatiquement après les envois. Commande /wk prendre.
- Dépôt automatique en banque : à l'ouverture de la banque, les objets ou catégories choisis sont rangés dans la banque du perso ou de bataillon, en complétant les piles existantes.
- Onglet Réception : les boîtes aux lettres de tous les persos (lettres, objets, or, expiration).
- Journal : dépôts en banque et sessions de farm terminées.

### Modifications
- La page Courrier devient « Courrier et banque », avec trois onglets : Envoi, Dépôt banque et Réception.
- Nouvelle règle : choix Objet ou Catégorie dans une liste déroulante, et champ « Garder ».
- Le butin ne compte pas pendant le courrier, la banque, un marchand, un échange ou l'hôtel des ventes.
- Les sommes de moins d'1 po s'affichent en pièces d'argent au lieu de « 0 po ».
- Barre du haut plus compacte pour faire de la place à l'onglet Farm ; la loupe est retirée (la recherche reste dans l'Inventaire).
- Les anciennes règles d'envoi sont converties automatiquement.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

### Corrections
- Une session de farm interrompue par un crash ou une déconnexion garde le temps écoulé jusqu'à la dernière activité.

## v0.4.0 — 14/11/2026

### Ajouts
- Page Journal : courriers envoyés, or gagné ou dépensé, progrès de métier et niveaux, regroupés par jour, avec des filtres Tout / Or / Courrier / Métiers. Les variations d'or et les progrès d'un même métier sont regroupés par heure.
- Boîte aux lettres : son contenu est lu à l'ouverture (objets, or, nombre de lettres, date d'expiration). Les objets envoyés par l'envoi automatique à un autre perso du compte sont comptés tout de suite dans sa boîte.
- Les objets du courrier comptent dans les totaux, les infobulles et les stats. Nouveau filtre « Courrier » dans l'Inventaire.
- Alertes : banque d'un perso (niveau 10+) jamais ouverte ou pas vue depuis 7 jours, courrier qui expire dans moins de 3 jours. Rappel dans le chat à la connexion et colonnes en orange. Seuils réglables dans les Options.
- Page Persos : nouvelles colonnes Banque (dernière visite) et Courrier (lettres en attente et jours avant expiration).
- Stats : vue « Par perso » pour les matériaux, avec une courbe par personnage en couleur de classe et une légende.
- Version anglaise de l'interface et des messages du chat. Choix de la langue dans les Options : Auto (celle du jeu), Français ou English.

### Modifications
- Options : la page défile et regroupe Apparence, Langue, Bouton minimap, Alertes et À propos.
- Les commandes du chat existent aussi en anglais (/wk help, gold, chars, find, prof, mail add / del).
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour (un /reload ne suffit pas).

## v0.3.1 — 14/11/2026

### Ajouts
- Page « Notes de patch » : toutes les versions avec leurs ajouts, modifications et corrections, plus ce qui est prévu.
- Icône « Notes de patch » dans la barre du haut et commande /wk notes.
- Message dans le chat à la première connexion après une mise à jour.
- Fichier CHANGELOG.md sur GitHub, généré à partir des mêmes notes.

## v0.3.0 — 14/11/2026

### Ajouts
- Page Résumé : or du compte en grand, variation sur 7 jours et 4 chiffres clés (personnages, temps de jeu, règles de courrier, objets à envoyer).
- Courbe d'évolution de l'or sur 7 j, 30 j, 90 j ou 1 an, avec repère au survol (date et montant).
- Tableau des personnages avec le gain ou la perte sur 7 jours et une mini-courbe de tendance.
- Boutons ronds dans la barre du haut : rechercher un objet, scanner le personnage, fermer.

### Modifications
- Nouveau design « Registre » aux couleurs « Coffre-fort » : bois sombre, parchemin et or, double bordure dorée et halo chaud.
- Navigation en pilules dans la barre du haut : la barre latérale disparaît.
- Titre « Warband Keeper » dans la police médiévale du jeu, liserés dorés sur les cartes.
- Page Stats : une courbe remplace les barres, et l'échelle s'adapte aux valeurs pour rendre les variations visibles.
- Couleur d'accent par défaut : or. Nouveau choix : cuivre.

### Corrections
- Les sous-titres des pages s'affichaient au milieu de la page au lieu d'à côté du titre.
- Positionnement corrigé dans l'inventaire, les séries des stats, les tuiles et les descriptions des réglages.
- Le bouton « Recentrer la fenêtre » chevauchait l'interrupteur du bouton minimap dans les Options.

## v0.2.4 — 14/11/2026

### Modifications
- Nouveau logo : l'étendard de bataillon (drapeau avec un W), sur le bouton minimap et dans la fenêtre.

## v0.2.3 — 14/11/2026

### Modifications
- Les quantités par personnage ne s'ajoutent plus aux infobulles de comparaison d'équipement (plus de doublons).
- Noms des personnages en couleur de classe dans l'infobulle des objets, sans le royaume.

### Corrections
- Erreur au survol d'un objet (« attempt to call a nil value » dans Inventory.lua) : l'objet est maintenant identifié avec l'API d'infobulles moderne.

## v0.2.2 — 14/11/2026

### Corrections
- Carte « Ce personnage » : le nom complet Nom-Royaume sortait de la carte. Le nom s'affiche seul et le royaume passe sur sa propre ligne.
- Page Personnages : un royaume au nom long pouvait chevaucher la colonne Niveau.

## v0.2.1 — 14/11/2026

### Ajouts
- Banque de bataillon : lue à l'ouverture de la banque, visible dans l'inventaire (« Bataillon »), les infobulles et les totaux.
- Banque du personnage à onglets prise en charge.
- Le sac de composants est compté avec les sacs.

### Modifications
- Métiers lus avec l'API moderne du jeu.

### Corrections
- Erreur sur la page Inventaire (« attempt to call a nil value » dans Theme.lua) : GetItemInfo n'existe plus sur ce client, remplacé par C_Item.GetItemInfo.
- Insertion des liens d'objets (Maj + clic) compatible avec le nouveau chat.

## v0.2.0 — 14/11/2026

### Ajouts
- Fenêtre principale aux coins arrondis, avec les pages Vue d'ensemble, Personnages, Inventaire, Métiers, Statistiques, Courrier automatique et Options.
- Bouton minimap rond et déplaçable : clic gauche pour ouvrir, clic droit pour les options.
- Ouverture depuis le menu des addons du jeu.
- Couleur d'accent au choix et échelle de la fenêtre réglable.
- Recherche d'objets dans tous les sacs et banques, avec filtre Tout / Sacs / Banque.
- Suivi de n'importe quel matériau dans les statistiques (Maj + clic sur l'objet).
- Ajout des règles de courrier depuis la fenêtre, avec choix rapide du destinataire.

### Modifications
- /wk ouvre la fenêtre. /wk aide affiche les commandes du chat.

### Corrections
- Conflit de nom entre l'interrupteur et l'ouverture de la fenêtre (trouvé avant la publication).

## v0.1.0 — 14/11/2026

### Ajouts
- Enregistrement de chaque personnage : or, niveau, classe, temps de jeu.
- Contenu des sacs et de la banque de tous les personnages, avec les quantités dans l'infobulle des objets.
- Métiers et niveaux de compétence.
- Historique de l'or et des matériaux suivis pour les statistiques.
- Envoi automatique à l'ouverture de la boîte aux lettres : chaque objet assigné part vers son personnage, 12 pièces jointes par courrier.
- Commandes du chat : /wk or, persos, cherche, metiers, stats, envoi.
