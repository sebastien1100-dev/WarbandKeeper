local ADDON_NAME, WK = ...

-- Référence de la collection de pêche (écrite pour Warband Keeper, numéros d'objets vérifiés) :
-- ce que la pêche peut donner et où ça mord. C'est un repère : les zones sont approximatives et
-- le carnet (Modules/FishingLog.lua) complète tout seul la collection avec tes vraies prises
-- (une espèce imprévue rejoint l'album, une zone où tu as pêché rejoint l'atlas).
--   species = { { id, cat, tier } } : cat = "fish" (poissons), "chest" (coffres et caisses),
--             "curio" (curiosités : trophées, poissons gonflés, message…) ; tier = palier de
--             compétence (1 : 1-75, 2 : 75-150, 3 : 150-225, 4 : 225 et plus)
--   zones   = { [carte] = { skill, { poissons } } } : skill = compétence conseillée pour pêcher
--             sans que ça s'échappe (eaux libres ; les bancs suivent les mêmes zones)
WK.FishDB = {
    TIERS = { { 1, 75 }, { 75, 150 }, { 150, 225 }, { 225, 300 } },
    species = {
        -- poissons
        { 6291, "fish", 1 },  -- Petit poisson brillant cru
        { 6289, "fish", 1 },  -- Lutjan à grande mâchoire cru
        { 6303, "fish", 1 },  -- Maquereau à peau glissante cru
        { 6317, "fish", 1 },  -- Frénésie du Loch crue
        { 6361, "fish", 1 },  -- Thon à nageoires arc-en-ciel cru
        { 6522, "fish", 1 },  -- Poisson déviant
        { 6308, "fish", 2 },  -- Poisson-chat à moustaches cru
        { 6358, "fish", 2 },  -- Bouche-noire huileux
        { 6359, "fish", 2 },  -- Lutjan aileron de feu
        { 21071, "fish", 2 }, -- Sagefish cru
        { 6362, "fish", 2 },  -- Morue à écailles rocheuses crue
        { 6360, "fish", 2 },  -- Écrase-poisson à écailles d'acier
        { 8365, "fish", 3 },  -- Truite tête-de-mithril crue
        { 4603, "fish", 3 },  -- Queue-jaune tachetée crue
        { 13422, "fish", 3 }, -- Anguille pierreécaille
        { 21153, "fish", 3 }, -- Grand sagefish cru
        { 13754, "fish", 3 }, -- Poisson-force luisant cru
        { 13755, "fish", 4 }, -- Calmar d'hiver
        { 13756, "fish", 4 }, -- Bar d'été cru
        { 13757, "fish", 4 }, -- Anguille électrique
        { 13758, "fish", 4 }, -- Ouïe-rouge crue
        { 13759, "fish", 4 }, -- Lutjan nageoire-de-nuit cru
        { 13760, "fish", 4 }, -- Saumon écaille-de-soleil cru
        { 13889, "fish", 4 }, -- Saumon écaille-blanche cru
        { 13888, "fish", 4 }, -- Homard pince-noire
        { 13893, "fish", 4 }, -- Grand poisson-force cru
        -- coffres et caisses
        { 6351, "chest", 1 }, { 6352, "chest", 1 }, { 6353, "chest", 2 }, { 6354, "chest", 2 },
        { 6356, "chest", 2 }, { 6357, "chest", 2 }, { 6355, "chest", 3 }, { 13874, "chest", 3 },
        { 13875, "chest", 4 }, { 13918, "chest", 4 }, { 21113, "chest", 4 }, { 21150, "chest", 4 },
        { 21228, "chest", 4 },
        -- curiosités
        { 6307, "curio", 1 },  -- Message dans une bouteille
        { 6643, "curio", 1 }, { 6645, "curio", 1 }, { 6647, "curio", 2 }, { 8366, "curio", 3 },
        { 13881, "curio", 4 }, { 13891, "curio", 4 }, -- poissons gonflés
        { 6309, "curio", 2 }, { 6310, "curio", 2 }, { 6311, "curio", 2 }, { 6363, "curio", 2 }, { 6364, "curio", 2 }, -- poissons-chats trophées
        { 13876, "curio", 4 }, { 13877, "curio", 4 }, { 13878, "curio", 4 }, { 13879, "curio", 4 }, { 13880, "curio", 4 }, -- mérous trophées
    },
    zones = {
        -- villes et zones de départ
        [1429] = { 1, { 6291, 6289 } },        -- Forêt d'Elwynn
        [1426] = { 1, { 6291, 6289, 6317 } },  -- Dun Morogh
        [1411] = { 1, { 6291, 6289, 6303 } },  -- Durotar
        [1412] = { 1, { 6291, 6289 } },        -- Mulgore
        [1438] = { 1, { 6291, 6289, 6303 } },  -- Teldrassil
        [1420] = { 1, { 6291, 6289 } },        -- Clairières de Tirisfal
        [1453] = { 1, { 6291, 6289 } },        -- Hurlevent
        [1455] = { 1, { 6291, 6289 } },        -- Forgefer
        [1454] = { 1, { 6291, 6289 } },        -- Orgrimmar
        [1456] = { 1, { 6291, 6289 } },        -- Les Pitons-du-Tonnerre
        [1458] = { 1, { 6291, 6289 } },        -- Fossoyeuse
        [1457] = { 1, { 6291, 6289 } },        -- Darnassus
        -- 20 à 75
        [1432] = { 20, { 6289, 6317, 6308 } },                    -- Loch Modan
        [1439] = { 20, { 6289, 6303, 6361, 6308, 6358 } },        -- Sombrivage
        [1413] = { 20, { 6289, 6303, 6361, 6308, 6522, 6358 } },  -- Les Tarides
        [1421] = { 20, { 6289, 6303, 6361, 6308 } },              -- Forêt des Pins-Argentés
        [1436] = { 55, { 6289, 6303, 6361, 6308, 6358 } },        -- Marche de l'Ouest
        -- 55 à 150
        [1433] = { 55, { 6308, 6358, 21071 } },                   -- Les Carmines
        [1437] = { 55, { 6308, 6361, 6358, 6359, 6362, 21071 } }, -- Les Paluns
        [1431] = { 55, { 6308, 6358, 6359 } },                    -- Bois de la Pénombre
        [1440] = { 55, { 6308, 6358, 6359, 21071 } },             -- Orneval
        [1424] = { 55, { 6308, 6361, 6358, 6359, 6362 } },        -- Contreforts de Hautebrande
        [1442] = { 55, { 6308, 6358, 21071 } },                   -- Les Serres-Rocheuses
        -- 130 à 225
        [1441] = { 130, { 8365, 4603, 6362 } },                   -- Mille pointes
        [1434] = { 130, { 8365, 4603, 6362, 6358, 6359, 13422 } },-- Vallée de Strangleronce
        [1435] = { 130, { 8365, 4603, 6362, 13422 } },            -- Marais des Chagrins
        [1443] = { 130, { 8365, 4603, 6362, 13422 } },            -- Désolace
        [1445] = { 130, { 8365, 4603, 6362, 6358, 6359, 13422 } },-- Marécage d'Âprefange
        [1417] = { 130, { 8365, 4603, 6362, 13422, 21153 } },     -- Hautes-terres d'Arathi
        [1416] = { 130, { 8365, 4603 } },                         -- Montagnes d'Alterac
        -- 205 et plus
        [1444] = { 205, { 8365, 4603, 13754, 13422, 21153 } },    -- Féralas
        [1425] = { 205, { 8365, 4603, 13754, 13422, 21153 } },    -- Les Hinterlands
        [1446] = { 205, { 4603, 13754, 13422, 13757, 13755, 13756 } }, -- Tanaris
        [1447] = { 205, { 13754, 13422, 13757, 13755, 13756 } },  -- Azshara
        [1448] = { 205, { 13758, 13759, 13760, 13422 } },         -- Gangrebois
        [1449] = { 205, { 13758, 13759, 13760, 13422 } },         -- Cratère d'Un'Goro
        [1422] = { 205, { 13758, 13759, 13760, 13422 } },         -- Maleterres de l'Ouest
        [1450] = { 205, { 13758, 13759, 13760 } },                -- Reflet-de-Lune
        [1423] = { 330, { 13758, 13759, 13760, 13422 } },         -- Maleterres de l'Est
        [1452] = { 330, { 13758, 13759, 13760, 13889, 13757 } },  -- Berceau-de-l'Hiver
    },
}
-- Bancs de pêche (n° des données de ForeverDB, Modules/ForeverGatherDB.lua : ordre de FISH_POOLS dans
-- tools/gen_foreverdb.py ; libellés écrits pour Warband Keeper)
WK.FishDB.POOLS = {
    "Banc de poissons bleus", "Banc mixte d'eau saumâtre", "Banc de lutjans aileron de feu", "Débris flottants",
    "Épave flottante", "Banc de grands sagefish", "Banc mixte des hautes-terres", "Eaux boueuses tourbillonnantes",
    "Banc de poissons-boue", "Nappe de pétrole", "Banc de bouches-noires huileux", "Flaque d'eau élémentaire",
    "Eau pure", "Banc de sagefish", "Banc de dards", "Banc de poissons déviants", "Banc de poissons",
    "Banc de poissons savoureux", "Banc de poissons-spores", "Débris de la pompe à vapeur",
    "Nuée d'anguilles pierreécaille", "Bassin étrange",
}
