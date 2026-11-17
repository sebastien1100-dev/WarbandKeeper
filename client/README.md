# Warband Keeper : client PC

Petit programme Windows pour installer et mettre à jour l'addon sans manipuler de zip.
Warband Keeper est fait pour **WoW Forever** seulement : le client ne propose que ses installations.
Après chaque mise à jour, il dit s'il faut redémarrer complètement le jeu (nouveaux fichiers) ou si un `/reload` suffit.

- **Accueil** : version installée et dernière version publiée, bouton « Mettre à jour », nouveautés depuis ta version.
- **Nouveautés** : les notes de toutes les versions.
- **Sauvegardes** : tes réglages de l'addon (SavedVariables) sont sauvegardés avant chaque mise à jour,
  restaurables en un clic (jeu fermé) ; la version précédente de l'addon est gardée (« Revenir à cette version »).
- **Installation de l'addon** : le client cherche WoW tout seul (registre de Windows, réglages de Battle.net,
  tous les disques) et ne garde que WoW Forever ; s'il en trouve plusieurs, il te laisse choisir
  (« Installer ici »). Le dossier `Interface\AddOns` est créé s'il manque.
- **Réglages** : dossier du jeu (« Détecter » ou « Parcourir »), jeton GitHub, options.
- Le client se met à jour lui-même quand une nouvelle version est publiée.

## Installation

1. Sur GitHub, page **Releases** du dépôt : télécharger `WarbandKeeper-Client-x.y.z.exe`.
2. Le lancer. Windows peut afficher « Windows a protégé votre ordinateur » (programme non signé) :
   **Informations complémentaires > Exécuter quand même**.

## Dépôt privé : jeton GitHub

Tant que le dépôt est privé, le client a besoin d'un jeton en lecture seule :

1. github.com > Settings > Developer settings > **Fine-grained tokens** > Generate new token
   (bouton « Créer un jeton » du client).
2. Repository access : **Only select repositories** > `WarbandKeeper`.
3. Permissions > Repository permissions > **Contents : Read-only**. Rien d'autre.
4. Copier le jeton dans **Réglages > Accès à GitHub** du client, puis « Enregistrer ».

Le jeton reste sur ton PC (`%APPDATA%\WarbandKeeper Client\config.json`). Si le dépôt devient public, il n'est plus utile.

## Pour le développement

- Lancer depuis les sources : `python client/wk_client.py` (Python 3.9+ avec Tkinter).
- Logo : `python3 client/make_assets.py` (Pillow).
- L'exe est construit par `.github/workflows/release.yml` (PyInstaller, Windows) et joint à chaque Release.
- Nouvelle page : une classe qui hérite de `Page`, décorée par `@page("clé", "Libellé", "icône")` ;
  `on_state()` est appelé quand quelque chose change. Monter `CLIENT_VERSION` pour publier un nouveau client.
