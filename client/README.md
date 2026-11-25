# Warband Keeper : client PC

Petit programme Windows pour installer et mettre à jour l'addon sans manipuler de zip.
Warband Keeper est fait pour **WoW Forever** seulement : le client ne propose que ses installations.
Après chaque mise à jour, il dit s'il faut redémarrer complètement le jeu (nouveaux fichiers) ou si un `/reload` suffit.

Un rail d'icônes à gauche (Accueil, Addon, Découvertes) ; en haut de chaque page ses chiffres clés et l'état de
l'addon et du client ; la roue en haut à droite ouvre les Réglages.

- **Accueil** : or du compte et sa courbe (7 / 30 / 90 jours), persos (niveau, or, repos), dernières 24 h par cause,
  « À surveiller » (Rangement, courrier, enchères, recharges, listes d'achat) et « En bref » (séance, addon, client,
  découvertes, sauvegarde, HV) : résumé écrit par l'addon à chaque déconnexion.
- **Addon** : version installée et dernière version publiée, « Mettre à jour » / « Vérifier », client PC, sauvegardes
  de tes réglages (SavedVariables, faites avant chaque mise à jour, restaurables en un clic, jeu fermé), version
  précédente de l'addon (« Remettre »), et « Quoi de neuf » en deux volets : addon et client (client/CHANGELOG.md).
- **Découvertes** : ce que l'addon a appris en jeu, envoyé tout seul sur GitHub (voir plus bas).
- **Réglages** (roue), en onglets : Dossier, GitHub, Mises à jour, Notifications (notifications Windows : enchères qui
  expirent, recharges prêtes, repos plein, courrier ; heures calmes), Données.
- **Installation de l'addon** : le client cherche WoW tout seul (registre de Windows, réglages de Battle.net,
  tous les disques) et ne garde que WoW Forever ; s'il en trouve plusieurs, il te laisse choisir
  (« Installer ici »). Le dossier `Interface\AddOns` est créé s'il manque.
- **Réglages** : dossier du jeu (« Détecter » ou « Parcourir »), jeton GitHub,
  **Mises à jour** (toutes les heures par défaut, toutes les 6 h, au démarrage seulement ou à la demande ; le client prévient en clignotant dans la barre des tâches ; installation automatique ; lancement avec Windows, réduit),
  **Données** (vérification sur GitHub chaque jour, chaque lundi ou à la demande ; publication automatique
  ou PR à valider ; « Lancer maintenant » ; état de la dernière vérification).
- Le client se met à jour lui-même quand une nouvelle version est publiée.

## Installation

1. Sur GitHub, page **Releases** du dépôt : télécharger `WarbandKeeper-Client-x.y.z.exe`.
2. Le lancer. Windows peut afficher « Windows a protégé votre ordinateur » (programme non signé) :
   **Informations complémentaires > Exécuter quand même**.

## Jeton GitHub (facultatif)

Le dépôt est public : **aucun jeton n'est nécessaire pour installer l'addon et le client**.

Sur le **même réseau** que le mainteneur, rien à faire : sans jeton, le client passe tout seul tes découvertes à son
client (ouvert sur son PC), qui les envoie sur GitHub (Windows peut lui demander une fois d'autoriser le client sur
le réseau privé).

Ailleurs, pour **partager tes découvertes** (page Découvertes) sans être mainteneur : un jeton « classique » de ton compte
GitHub (gratuit) avec le seul droit **public_repo** (bouton « Jeton pour proposer » de Réglages > GitHub). Le client
crée ta copie (fork) du dépôt et propose tes nouveautés par une demande de fusion ; le mainteneur les accepte (ou
toutes seules si ton compte est dans ses « Joueurs de confiance… »).

Mainteneur (envoi direct, réglage des données) : jeton fine-grained du dépôt :

1. github.com > Settings > Developer settings > **Fine-grained tokens** > Generate new token
   (bouton « Créer un jeton » du client).
2. Repository access : **Only select repositories** > `WarbandKeeper`.
3. Permissions > Repository permissions > **Contents : Read-only**. Rien d'autre.
   Pour régler aussi les **Données** depuis le client : **Contents : Read and write** et **Actions : Read and write**
   (le client modifie `tools/update_schedule.json` et lance la vérification).
4. Copier le jeton dans **Réglages > Accès à GitHub** du client, puis « Enregistrer ».

Le jeton reste sur ton PC (`%APPDATA%\WarbandKeeper Client\config.json`).

## Pour le développement

- Lancer depuis les sources : `python client/wk_client.py` (Python 3.9+ avec Tkinter).
- Notes du client : `client/CHANGELOG.md` (à part de celles de l'addon), joint à chaque Release et embarqué dans l'exe.
- Logo : `python3 client/make_assets.py` (Pillow).
- L'exe est construit par `.github/workflows/release.yml` (PyInstaller, Windows) et joint à chaque Release.
- Nouvelle page : une classe qui hérite de `Page`, décorée par `@page("clé", "Libellé", "icône")` ;
  `on_state()` est appelé quand quelque chose change. Monter `CLIENT_VERSION` pour publier un nouveau client.
