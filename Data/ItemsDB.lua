-- FICHIER GÉNÉRÉ par tools/gen_items.py : ne pas modifier à la main.
-- Objets portables de WoW Forever (qualité verte et plus), pour la liste BiS.
-- Données : wowlayerup-forever/opendata (https://github.com/wowlayerup-forever/opendata), licence CC BY 4.0,
-- reprises et réduites ; noms français : table ItemSparse du client (wago.tools).
-- WK.LoadItemsDB() rend WK.ItemsDB = { { n°, groupe d'emplacement, classe, sous-classe, qualité, niveau d'objet, niveau requis,
--   nom, caractéristiques, source ("q<quête>", "c<métier>:<compétence>" ou "") }, ... }
-- Chargé à la demande (WK.LoadItemsDB) : une seule chaîne tant que la liste BiS n'est pas ouverte.
local WK = WarbandKeeper -- table de l'addon principal (dossier chargé à la demande)
WK.ItemsDBRaw = [==[
744	trinket	4	0	2	44	0	Flacon de botte de Thunderbrew	Esp +8	
810	main	2	4	4	54	49	Marteau du vent nordique		
864	one	2	7	2	38	33	Epée longue des chevaliers		
935	one	2	7	3	20	15	Epée de veilleur	End +4	
1009	main	2	4	2	13	0	Marteau compact	End +1	
1077	finger	4	0	2	26	21	Anneau de mage défias	Int +4 · Esp +3	
1116	finger	4	0	2	31	0	Anneau d'argent pur	End +1 · Esp +6	
1131	off	4	0	2	25	0	Totem d'affliction		q101
1172	off	4	0	2	21	0	Torche de Grayson	Esp +4	
1189	finger	4	0	2	20	15	Anneau de surveillant	For +3	
1270	back	4	1	2	15	0	Cape finement tissée	Esp +2	
1273	chest	4	3	2	25	0	Cotte d'anneaux de la forêt	End +2 · Esp +8	
1275	chest	4	3	2	25	0	Lorica d'adjoint	End +4 · Esp +7	
1276	off	4	6	2	27	0	Targe en acier trempé	Esp +5	q19
1282	head	4	3	2	33	0	Camail en métal étincelant	For +9 · Esp +8	
1302	hands	4	2	2	18	0	Gants de dragonnet noir	For +2 · Agi +3	
1303	hands	4	3	2	20	0	Gants d'ouvrier du pont	For +4 · Esp +2	
1304	hands	4	1	2	20	0	Gants d'équitation	Agi +3 · Int +3	
1306	wrist	4	2	2	20	0	Garde-poignets en crinière de loup	Agi +2 · End +2	
1310	legs	4	2	2	20	0	Pantalon de Smith	For +4 · Agi +4	
1319	finger	4	0	2	25	0	Anneau de volonté de fer	End +4 · Esp +2	q126
1436	legs	4	2	2	17	0	Culotte des frontaliers	For +3 · Agi +3	q217
1444	trinket	4	0	3	40	35	[PÉRIMÉ] Pierre d'Inferno		
1449	finger	4	0	2	24	0	Anneau de canalisation mineure	Int +2 · Puiss. sorts +5	
1462	finger	4	0	2	25	20	Anneau des ténèbres	Rés. ombre +5	
1480	main	2	4	2	17	0	Marteau de la milice du peuple	For +2	
1547	off	4	6	2	30	0	Bouclier de la Foi	Esp +6	
1557	off	4	6	2	20	0	Targe des Mers	Esp +2 · Puiss. sorts +2	
1561	chest	4	1	2	15	0	Robe de moissonneur	Esp +2 · Puiss. sorts +2	
1566	two	2	8	2	17	0	Grande lame de la milice du peuple	End +5	
1832	legs	4	1	2	17	0	Pantalon de chance	Agi +2 · End +2 · Esp +3	q217
1893	two	2	1	2	20	0	Piolet vengeur	Esp +6	
1913	main	2	4	2	12	7	Masse cloutée	For +1	
1993	finger	4	0	2	36	31	Anneau de concentration	Int +7 · Esp +3	
1996	finger	4	0	2	37	32	Anneau vaudou	Int +7 · Esp +3	
2000	two	2	8	2	35	0	Archeus		
2032	wrist	4	1	2	36	0	Crispins de Gallan	End +3 · Int +7	
2036	hands	4	2	2	18	0	Gants de mine poussiéreux	For +3 · Agi +2	
2037	feet	4	3	2	18	0	Bottes de tunnelier	End +3 · Esp +2	
2043	finger	4	0	2	35	0	Anneau des Esprits glacés	End +2 · Puiss. sorts +8	
2044	main	2	0	2	35	0	Hache des Esprits glacés	Esp +6	
2189	main	2	4	6	100	95	Tigole's Boomstick (TEST)		
2194	one	2	4	3	25	20	Marteau diamant	For +3 · End +4	
2218	one	2	15	2	13	0	Dague d'artisan	Agi +1	
2230	hands	4	3	2	24	0	Gants de musculation	For +6	
2231	chest	4	1	2	40	0	Robe d'Inferno		
2236	one	2	15	3	25	20	Dard noir	Esp +2 · Rés. ombre +5	
2263	main	2	7	2	25	0	Phytolame		
2275	head	4	3	3	20	15	[PÉRIMÉ] Camail de sentinelle		
2300	chest	4	2	2	12	7	Gilet en cuir estampé	End +2	c165:1
2303	legs	4	2	2	10	5	Pantalon en cuir cousu main	Agi +1	c165:1
2307	feet	4	2	2	18	13	Bottes élégantes en cuir	Agi +3 · End +2	c165:1
2308	back	4	1	2	15	10	Cape élégante en cuir	End +2	c165:1
2309	feet	4	2	2	15	10	Bottes en cuir estampé	End +2 · Puiss. sorts +2	c165:1
2310	back	4	1	2	13	8	Cape en cuir estampé	Agi +1	c165:1
2311	chest	4	2	2	13	8	Pourpoint blanc en cuir	For +2 · Puiss. sorts +2	c165:1
2312	hands	4	2	2	15	10	Gants élégants en cuir	Int +2 · Puiss. sorts +2	c165:1
2315	feet	4	2	2	20	15	Bottes en cuir gris	Agi +5	c165:1
2316	back	4	1	2	22	17	Cape noire en cuir	For +2 · Agi +3	c165:1
2317	chest	4	2	2	20	15	Tunique noire en cuir	Agi +6	c165:1
2545	legs	4	3	2	26	0	Jambières en mailles de l'apprenti	For +7 · Agi +3 · End +3	
2569	feet	4	1	2	13	8	Bottes en lin	End +2	c197:1
2572	chest	4	1	2	10	5	Robe rouge en lin	Int +1	c197:1
2578	chest	4	1	2	14	9	Gilet barbare en lin	End +2 · Puiss. sorts +2	c197:1
2580	back	4	1	2	12	7	Cape en lin renforcé	Puiss. sorts +1	c197:1
2582	chest	4	1	2	17	12	Gilet vert en laine	Esp +4 · Puiss. sorts +4	c197:1
2583	feet	4	1	2	19	14	Bottes en laine	Int +2 · Esp +2 · Puiss. sorts +2	c197:1
2584	back	4	1	2	16	11	Cape en laine	Esp +1 · Puiss. sorts +1	c197:1
2585	chest	4	1	2	21	16	Robe grise en laine	Int +5 · Puiss. sorts +4	c197:1
2694	legs	4	3	2	17	0	Jambières de colon	Agi +3 · Esp +3	
2805	back	4	1	2	34	0	Cape en fourrure de yéti	For +3 · Agi +6	
2817	chest	4	2	2	12	0	Tunique en cuir souple	End +2	
2818	legs	4	2	2	15	0	Pantalon en cuir étiré	For +2 · Agi +2	
2820	trinket	4	0	2	50	0	Chouette chronomètre		
2847	one	2	7	2	10	4	Epée courte en cuivre	For +1	c164:40
2848	one	2	4	2	22	17	Masse en bronze	End +3	c164:75
2849	one	2	0	2	23	18	Hache en bronze	For +3	c164:85
2850	one	2	7	2	24	19	Epée courte en bronze	Agi +3	c164:95
2851	waist	4	3	2	11	6	Ceinture en anneaux de cuivre	End +1	c164:1
2852	legs	4	3	2	10	4	Pantalon en anneaux de cuivre	End +1	c164:40
2854	wrist	4	3	2	19	14	Brassards runiques en cuivre	For +2 · End +2	c164:1
2857	waist	4	3	2	18	13	Ceinture runique en cuivre	For +3 · End +2	c164:80
2864	chest	4	3	2	18	13	Cuirasse runique en cuivre	For +4 · End +3	c164:90
2865	legs	4	3	2	21	16	Jambières grossières en bronze	End +5 · Esp +4	c164:95
2866	chest	4	3	2	23	18	Cuirasse grossière en bronze	End +8	c164:105
2867	wrist	4	3	2	23	18	Brassards grossiers en bronze	End +4	c164:1
2868	wrist	4	3	2	25	20	Brassards guillochés en bronze	For +5	c164:120
2869	chest	4	3	2	26	21	Cuirasse en bronze argenté	For +5 · End +5 · Esp +4	c164:1
2870	chest	4	3	3	29	24	Cuirasse en argent lumineux	For +14 · End +6	c164:135
2902	back	4	1	2	30	0	Cape de la foi	End +4 · Esp +4	
2903	ranged	2	2	2	15	0	Arc de chasse de Daryl	Agi +1	
2904	ranged	2	3	2	16	0	Carabine de chasse de Daryl	For +2	
2907	two	2	1	2	20	0	Hache de bûcheron naine		
2908	one	2	15	2	20	0	Aiguillon	Agi +3	
2910	feet	4	3	2	25	0	Bottes en or de la milice	For +3 · End +5	q126
2913	shoulder	4	1	2	28	0	Mantelet de Gamn en soie	Int +6 · Esp +4	
2916	off	4	6	2	34	0	Bouclier du lion d'or	For +2 · End +5 · Esp +3	
2917	finger	4	0	2	34	0	Anneau tranquille	Int +1 · Esp +7	
2933	finger	4	0	3	31	0	Sceau de Wrynn	For +3 · Agi +3 · End +4 · Int +4 · Esp +3	
2943	off	4	0	2	31	0	Oeil de Paleth	Dégâts sorts +4 · Soins +13	
2944	off	4	0	2	31	26	Oeil maudit de Paleth	End +-3	
2949	feet	4	2	2	25	0	Bottes des marins	Agi +1 · End +6	
2950	two	2	10	2	25	0	Bâtonnet glacial	Int +4	
2953	back	4	1	2	33	0	Cape de maître du guet	End +7	
2954	legs	4	1	2	33	0	Pantalon de veilleur	End +9 · Int +8	
3041	ranged	2	3	2	31	26	Tromblon "Oeil du mage"	Agi +5	
3068	head	4	1	2	32	27	[PÉRIMÉ] Capuche argentée	Int +8 · Esp +8	
3079	ranged	2	3	2	12	0	Carabine de Skorn	Agi +1	
3103	two	2	5	2	12	0	Marteau des Frigères	For +1 · Esp +1	
3154	main	2	0	2	18	0	Hache de Thelsamar	Agi +2	
3160	off	4	6	2	15	0	Targe doublée de fer	Puiss. sorts +2	q307
3161	chest	4	1	2	15	0	Robe du gardien	End +4	q307
3166	chest	4	3	2	15	0	Cotte d'anneaux Coeur-de-fer	End +4	q307
3184	one	2	15	2	20	15	Dague crochet		
3209	two	2	8	2	32	0	Ancienne épée de guerre	For +9 · End +6	
3217	waist	4	1	2	15	0	Ceinture de contremaître	End +2 · Esp +2	
3224	wrist	4	1	2	12	7	Brassards bordés d'argent	End +1	
3225	one	2	15	2	11	6	Couteau taché de sang	Agi +1	
3235	finger	4	0	2	20	0	Anneau de dédain	End +4 · Esp +-3	
3344	waist	4	1	2	15	0	Echarpe du capitaine Sander	End +2 · Esp +2	
3431	chest	4	2	2	25	0	Cuir clouté d'os	For +6 · Agi +1 · End +5	
3440	two	2	5	2	13	0	Brise-os	For +3	
3446	two	2	10	2	13	0	Bâton de sombrebois	End +3	
3449	back	4	1	2	15	0	Châle mystique	Puiss. sorts +2	
3450	off	4	6	2	15	0	Bouclier de Faerleia	For +2	
3451	off	4	0	2	18	0	Décoction de lueur nocturne	Esp +3	
3452	two	2	10	2	22	0	Bâtonnet de céranium	End +7	
3457	legs	4	1	2	18	0	Pantalon estampillé	Int +3 · Esp +3	
3458	hands	4	3	2	18	0	Gantelets en mailles robustes	For +3 · End +1	
3461	chest	4	1	2	24	0	Grande robe de l'adjudicateur	Int +2 · Puiss. sorts +8	
3462	main	2	7	2	24	0	Ecorcheuse	Agi +3	
3463	ranged	2	16	2	37	0	Etoile d'argent	Agi +6	
3469	feet	4	3	2	10	4	Bottes en anneaux de cuivre	End +1	c164:1
3471	chest	4	3	2	10	5	Lorica en cuivre	For +1	c164:1
3472	hands	4	3	2	12	7	Gantelets runiques en cuivre	For +1 · End +1	c164:1
3473	legs	4	3	2	13	8	Pantalon runique en cuivre	For +2 · End +2	c164:1
3474	hands	4	3	2	15	10	Gantelets ornementés en cuivre		c164:1
3480	shoulder	4	3	2	22	17	Epaulières grossières en bronze	For +3 · End +4	c164:1
3481	shoulder	4	3	2	25	20	Epaulières en bronze argenté	For +3 · End +3 · Esp +3	c164:1
3482	feet	4	3	2	26	21	Bottes en bronze argenté	For +4 · End +4 · Esp +3	c164:1
3483	hands	4	3	2	27	22	Gantelets en bronze argenté	For +4 · End +4 · Esp +3	c164:1
3484	feet	4	3	2	29	24	Bottes en fer émeraude	For +3 · End +7	c164:1
3485	hands	4	3	2	30	25	Gantelets en fer émeraude	For +5 · End +6	c164:1
3487	two	2	8	2	19	14	Lourde épée large en cuivre	End +6	c164:1
3488	two	2	1	2	13	8	Hache de guerre en cuivre	End +3	c164:1
3489	one	2	0	2	17	12	Hache de guerre lourde	For +1 · End +1	c164:1
3490	one	2	15	2	25	20	Poignard mortel en bronze	Agi +4	c164:1
3491	one	2	4	2	25	20	Masse lourde en bronze	For +4	c164:1
3492	one	2	4	2	30	25	Puissant marteau en fer	For +5	c164:1
3493	ranged	2	2	2	30	0	Carnassier	Agi +3 · End +3	
3511	back	4	1	2	15	0	Cape de la milice du peuple	Agi +2	
3555	chest	4	1	2	25	0	Robe de Solomon	End +7 · Esp +3	
3556	head	4	1	2	30	0	Chapeau de mage d’effroi	Int +7 · Esp +7	
3558	chest	4	1	2	25	0	Robe de gardien des tourbières	Esp +9	
3559	hands	4	3	2	21	0	Gantelets de veilleur	For +4 · Agi +1	
3560	shoulder	4	1	2	35	0	Mantelet d'honneur	Int +7 · Esp +7	
3561	back	4	1	2	26	0	Poncho de résistance	End +5	
3565	hands	4	1	2	20	0	Gants tachés de bière	For +3 · End +3	
3566	chest	4	2	2	29	0	Armure de la plaie des raptors	End +3 · PA +16	
3567	ranged	2	3	2	19	0	Canne à pêche naine	For +2	q150
3570	main	2	4	2	16	0	Pilon fracasseur	For +2	
3572	one	2	7	2	17	0	Epée courte de Daryl	Agi +2	
3578	legs	4	2	2	15	0	Pantalon de moissonneur	Agi +2 · Esp +3	
3581	one	2	15	2	18	0	Couteau-scie	Agi +1 · End +1	
3582	back	4	1	2	18	0	Cape résistante à l'acide	End +3	
3585	chest	4	2	2	22	0	Tunique camouflée	Agi +2 · End +6	
3586	two	2	1	2	16	0	Fendeuse	For +3 · End +2	
3687	two	2	8	6	40	35	[PÉRIMÉ] Vengeur impie		
3719	back	4	1	2	30	25	Cape d'homme des collines	End +4 · Puiss. sorts +5	c165:1
3733	chest	4	3	2	23	0	Cotte d'anneaux de guerre orque	For +6 · End +3	
3738	two	2	10	2	25	0	Bâtonnet de brasseur	End +6 · Esp +5	
3739	finger	4	0	2	25	0	Anneau du crâne	End +3 · Int +3	
3741	feet	4	2	2	24	0	Bottes écrasantes	For +4 · Agi +4	
3742	ranged	2	2	2	28	0	Arc des pilleurs	Agi +3 · End +3	
3743	off	4	6	2	28	0	Targe de factionnaire	Int +1 · Esp +5	
3747	waist	4	2	2	30	0	Echarpe de méditation	End +6 · Esp +5	
3749	back	4	1	2	30	0	Cape de grand apothicaire	End +2 · Esp +5	
3750	chest	4	2	2	30	0	Cuirasse côtelée	For +5 · End +5 · Esp +5	
3751	legs	4	3	2	30	0	Jambières des mercenaires	For +7 · Agi +7	
3752	chest	4	1	2	22	0	Gilet de grunt	For +5 · Esp +4	
3753	waist	4	2	2	34	0	Ceinturon de berger	End +7 · Puiss. sorts +7	
3754	hands	4	2	2	33	0	Gants de berger	For +7 · Agi +6	
3755	main	2	0	2	32	0	Eviscératrice	Esp +5	
3758	waist	4	3	2	33	0	Ceinture du Croisé	For +7 · End +6	
3759	hands	4	1	2	33	0	Gants vitaux des sages	End +7 · Int +6	
3760	finger	4	0	2	32	0	Anneau de Fossoyeuse	End +3 · Esp +5	
3761	off	4	6	2	32	0	Bouclier Tête de mort	For +1 · End +7	
3763	off	4	6	2	40	0	Targe lunaire	For +3 · Esp +8	
3764	feet	4	1	2	40	0	Bottes Mantis	For +3 · Agi +2 · Esp +7	
3765	shoulder	4	3	2	40	0	Epauliers de brigand	For +8 · End +8	
3822	two	2	8	2	32	0	Noirâtre runique		
3835	wrist	4	3	2	33	28	Brassards en fer émeraude	For +4 · End +5	c164:1
3836	head	4	3	2	34	29	Heaume en fer émeraude	For +5 · End +11	c164:1
3837	head	4	3	2	38	33	Camail en écailles dorées	For +10 · End +10	c164:1
3840	shoulder	4	3	2	32	27	Epaulières en fer émeraude	For +4 · End +7	c164:1
3841	shoulder	4	3	2	35	30	Epaulières en écailles dorées	For +7 · End +6	c164:1
3842	legs	4	3	2	31	26	Jambières en fer émeraude	For +8 · End +8	c164:1
3843	legs	4	3	2	34	29	Jambières en écailles dorées	For +11 · End +5	c164:1
3844	chest	4	3	3	36	31	Haubert en fer émeraude	For +7 · End +11 · Armure +120	c164:1
3845	chest	4	3	2	40	35	Cuirasse en écailles dorées	For +14 · End +6	c164:1
3846	feet	4	3	2	37	32	Bottes en acier poli	End +11	c164:1
3847	feet	4	3	2	40	35	Bottes en écailles dorées	For +8 · End +8	c164:1
3848	one	2	15	2	20	15	Grand couteau en bronze	End +3	c164:1
3849	one	2	7	2	32	27	Epée courte en fer trempé	End +5	c164:1
3850	one	2	7	2	35	30	Serpentine de jade	Agi +4 · PA +4	c164:1
3851	two	2	5	2	31	26	Solide maillet en fer	End +12	c164:1
3852	two	2	5	2	34	29	Destructeur en fer doré	For +11 · Puiss. sorts +4	c164:1
3853	two	2	8	2	36	31	Epée d'acier lunaire	For +4 · Puiss. sorts +12	c164:1
3854	two	2	8	2	40	35	Tigresse glaciale	Crit. +14	c164:1
3855	two	2	1	2	37	32	Gigantesque hache en fer	For +11 · End +7	c164:1
3856	two	2	1	2	40	35	Croissant des ombres	For +11 · Puiss. sorts +10	c164:1
3895	main	2	0	5	30	25	TEST Legendary		
3933	main	2	7	3	23	18	[PÉRIMÉ] Glaive lunaire		
3934	main	2	8	3	24	19	[PÉRIMÉ] Lame du gardien		
4086	ranged	2	3	2	37	0	Carabine foudroyante	For +5 · End +3	
4107	hands	4	2	2	37	0	Gants de chasseur de tigres	For +7 · Agi +8	
4108	legs	4	2	2	40	0	Jambières du chasseur de panthères	Agi +10 · End +11	
4109	feet	4	2	2	41	0	Bottes d'Excelsior	For +7 · Agi +9	
4110	ranged	2	2	2	45	0	Arc de maître-chasseur		
4111	ranged	2	3	2	45	0	Carabine de maître-chasseur		
4112	neck	4	0	2	44	0	Collier du Grand chaman	Int +5 · Esp +8	
4113	back	4	1	2	45	0	Couverture-médecine	End +4 · Esp +9	
4114	back	4	1	2	42	0	Cape de sombreflux	Agi +6 · End +7	
4115	off	4	6	2	37	0	Targe de Grom'gol	For +2 · End +3 · Esp +7	
4117	waist	4	1	2	44	0	Echarpe brûlante	Esp +9	
4118	wrist	4	3	2	50	0	Anneau de nez de Poobah	End +12	
4119	chest	4	2	2	43	0	Tunique de chasseur de raptors	For +4 · Agi +3 · End +16	
4120	chest	4	1	2	40	0	Robe des eaux cristallines	End +8 · Int +10 · Esp +9	
4121	hands	4	1	2	35	0	Gants ornementés	Agi +5 · Int +6 · Esp +5	
4122	main	2	4	2	37	0	Sceptre fracassant	Int +6	
4123	shoulder	4	3	2	37	0	Espauliers en métal glacial	End +11	
4124	head	4	2	2	40	0	Coiffe d'harmonie	End +11 · Esp +10	
4125	off	4	0	2	46	0	Orbe de tranquillité	End +4 · Esp +9	
4126	main	2	0	2	34	0	Fendoir de la guérilla	Agi +3 · End +4	
4127	ranged	2	3	2	40	0	Crache-mitraille	Agi +5 · Int +4	
4128	two	2	5	2	41	0	Fatale	End +4 · Esp +15	
4129	off	4	6	2	44	0	Légendaire	For +2 · End +9	
4130	trinket	4	0	2	50	0	Boussole de Smotts	Esquive +12	
4131	waist	4	2	2	44	0	Ceinture de corruption	End +9 · Int +9	
4132	wrist	4	3	2	37	0	Brachiales darkspear	For +7 · End +2	
4133	wrist	4	1	2	37	0	Crispins darkspear	End +3 · Int +7	
4134	two	2	10	2	46	0	Bâton mystique de Nimboya	Int +8 · Esp +15	
4135	finger	4	0	2	35	0	Anneau de pierre de sang	End +7 · Esp +2	
4136	feet	4	3	2	42	0	Bottes darkspear	For +9 · Esp +8	
4137	feet	4	1	2	42	0	Chaussures darkspear	End +7 · Int +3 · Esp +3	
4138	chest	4	3	2	45	0	Tunique des Flots noirs	For +7 · Esp +15	
4139	feet	4	1	2	37	0	Sandales du marcheur de la jungle	End +8 · Int +5 · Esp +2	
4140	shoulder	4	1	2	34	0	Mantelet en feuille de palmier	Int +7 · Esp +6	
4196	shoulder	4	2	3	30	25	Mantelet de plumes		
4237	waist	4	2	2	10	5	Ceinture en cuir cousu main	For +1	c165:1
4239	hands	4	2	2	13	8	Gants en cuir estampé	Agi +1 · End +1	c165:1
4242	legs	4	2	2	15	10	Pantalon en cuir estampé	End +2 · Puiss. sorts +3	c165:1
4243	chest	4	2	2	17	12	Tunique élégante en cuir	Agi +4 · End +3	c165:1
4244	chest	4	2	2	20	15	Gilet d'homme des collines en cuir	End +4 · Puiss. sorts +4	c165:1
4246	waist	4	2	2	16	11	Ceinture élégante en cuir	Agi +2 · End +2	c165:1
4247	hands	4	2	2	29	24	Gants d'homme des collines en cuir	End +6 · Puiss. sorts +5	c165:1
4248	hands	4	2	2	26	21	Gants noirs en cuir		c165:1
4249	waist	4	2	2	25	20	Ceinture noire en cuir	Agi +4 · End +4	c165:1
4250	waist	4	2	2	25	20	Ceinture d'homme des collines	End +4 · Puiss. sorts +4	c165:1
4251	shoulder	4	2	2	26	21	Epaulières d'homme des collines	End +5 · Esp +3	c165:1
4252	shoulder	4	2	2	28	23	Epaulières noires en cuir	Agi +7	c165:1
4253	hands	4	2	3	27	22	Gants en cuir raffermi	For +6 · Agi +6 · End +3	c165:1
4254	hands	4	2	2	30	25	Gants barbares	For +4 · Agi +4 · End +5	c165:1
4255	chest	4	2	2	31	26	Armure verte en cuir	Agi +8 · Int +8	c165:1
4256	chest	4	2	2	35	30	Armure de gardien	Int +10 · Puiss. sorts +9	c165:1
4257	waist	4	2	2	32	27	Ceinture verte en cuir	Agi +6 · Int +6	c165:1
4258	waist	4	2	2	34	29	Ceinture de gardien	Int +7 · Puiss. sorts +6	c165:1
4259	wrist	4	2	2	36	31	Brassards verts en cuir	Agi +6 · Int +5	c165:1
4260	wrist	4	2	2	39	34	Brassards de gardien en cuir	Int +6 · Puiss. sorts +6	c165:1
4261	legs	4	1	2	10	5	Pantalon de Solliden	For +1	
4262	waist	4	2	3	37	32	Ceinture en cuir clouté de gemmes	End +8 · PA +6	c165:1
4264	waist	4	2	2	40	35	Ceinture barbare	For +11	c165:1
4302	one	2	15	2	12	7	Petite dague verte	End +1	
4307	hands	4	1	2	10	5	Gants en lin épais	Puiss. sorts +1	c197:1
4308	wrist	4	1	2	12	7	Brassards verts en lin	Esp +1	c197:1
4309	legs	4	1	2	14	9	Culottes en lin cousu main	Int +2 · Puiss. sorts +2	c197:1
4310	hands	4	1	2	17	12	Gants en laine épaisse	Int +2 · Puiss. sorts +2	c197:1
4311	back	4	1	2	21	16	Cape en laine épaisse	Esp +4 · Puiss. sorts +4	c197:1
4312	feet	4	1	2	16	11	Bottes en lin à semelle souple	End +2 · Puiss. sorts +2	c197:1
4313	feet	4	1	2	20	15	Bottes rouges en laine	Esp +5 · Puiss. sorts +4	c197:1
4314	shoulder	4	1	2	22	17	Épaulières à double couture en laine	End +4 · Puiss. sorts +4	c197:1
4315	shoulder	4	1	2	24	19	Epaulières renforcées en laine	Int +4 · Puiss. sorts +5	c197:1
4316	legs	4	1	2	22	17	Pantalon en laine épaisse	Esp +6 · Puiss. sorts +3	c197:1
4317	legs	4	1	2	25	20	Pantalon du phénix	Int +4	c197:1
4318	hands	4	1	2	26	21	Gants de méditation	Esp +7 · Puiss. sorts +5	c197:1
4319	hands	4	1	2	29	24	Gants azur en soie	Esp +3	c197:1
4320	feet	4	1	3	25	20	Bottes en soie d'araignée	End +4 · Int +4 · Puiss. sorts +7	c197:1
4321	feet	4	1	2	28	23	Mules en soie d'araignée	Esp +7 · Puiss. sorts +3	c197:1
4322	head	4	1	2	33	28	Capuche d'enchanteur	Int +10 · Puiss. sorts +6	c197:1
4323	head	4	1	2	34	29	Chaperon des ombres	Int +11	c197:1
4324	chest	4	1	2	30	25	Gilet azur en soie	Int +9	c197:1
4325	feet	4	1	2	35	30	Bottes de l'enchanteur	Esp +8 · Puiss. sorts +5	c197:1
4326	back	4	1	2	37	32	Longue cape en soie	Int +5 · Puiss. sorts +6	c197:1
4327	back	4	1	3	40	35	Cape glaciale	Esp +6 · Puiss. sorts +7 · Rés. givre +8	c197:1
4328	waist	4	1	2	36	31	Ceinture de l'araignée	Int +8	c197:1
4329	waist	4	1	2	40	35	Ceinture de l'étoile	Esp +4 · Puiss. sorts +13	c197:1
4331	hands	4	1	2	25	20	Gants du phénix		c197:1
4343	legs	4	1	2	10	5	Pantalon marron en lin	Puiss. sorts +1	c197:1
4362	ranged	2	3	2	10	5	Espingole grossière	End +1	c202:1
4368	head	4	1	2	20	0	Lunettes de tigre volant	End +4 · Esp +4	c202:1
4369	ranged	2	3	2	21	16	Tromblon mortel	Agi +3	c202:1
4372	ranged	2	3	2	24	19	Espingole amoureusement construite	Esp +3	c202:1
4373	head	4	1	2	24	0	Lunettes des ombres	Int +5 · Esp +6	c202:1
4379	ranged	2	3	2	26	21	Fusil plaqué argent	End +4	c202:1
4381	trinket	4	0	2	28	0	Recombobulateur mineur		c202:1
4383	ranged	2	3	2	29	24	Carabine vise-lune	Toucher +4	c202:1
4385	head	4	1	2	30	0	Lunettes teintées vertes	End +8 · Esp +7	c202:1
4393	head	4	1	2	37	32	Monocle d'artisan	Int +15	c202:1
4430	neck	4	0	2	43	0	Talisman éthéré	For +5 · Agi +4 · End +6	
4443	shoulder	4	3	2	36	0	Espauliers sinistres	For +7 · Esp +7	
4455	chest	4	2	2	33	28	Harnais en peau de raptor	End +13	c165:1
4456	waist	4	2	2	33	28	Ceinture en peau de raptor	For +6 · End +6	c165:1
4504	back	4	1	2	31	0	Cape de garde nain	Agi +1 · End +6	
4505	legs	4	1	2	31	0	Pantalon des marécages	End +11 · Int +4	
4507	off	4	6	2	42	0	Bouclier du combattant des abîmes	For +8 · End +3	
4508	chest	4	3	2	42	0	Armure souillée de sang	For +5 · End +15	
4509	hands	4	2	2	40	0	Gants de loup de mer	For +11 · Agi +3	
4511	main	2	4	2	40	0	Marteau des Flots noirs	For +7	
4535	finger	4	0	2	31	0	Anneau mémorial de Forgefer	End +5 · Esp +4	
4543	head	4	2	2	40	0	Coiffe en peau de drake blanc	Esp +10 · Puiss. sorts +13	
4545	wrist	4	1	2	40	0	Brassards radieux en argent	Int +8 · Puiss. sorts +4	
4547	ranged	2	19	2	40	0	Baguette gnome	End +5 · Puiss. sorts +4	
4548	two	2	5	2	41	0	Marteau de guerre servomécanique		
4549	finger	4	0	2	46	0	Anneau de mer de feu	For +2 · Agi +2 · End +10	
4550	finger	4	0	2	46	0	Anneau de Coldwater	Int +3 · Esp +9	
4568	one	2	0	2	21	16	Hache de grunt		
4614	neck	4	0	2	35	30	Pendentif de Myzrael	End +4 · Esp +6	
4652	off	4	6	2	45	0	Bouclier de Salbac	For +9 · Esp +3	
4653	feet	4	3	2	45	0	Bottes en fer armé	For +10 · End +9	
4741	legs	4	3	2	37	0	Jambières de cavalier de Stromgarde	For +8 · Agi +2 · End +6	
4743	neck	4	0	2	50	0	Fragment de cristal palpitant	End +8 · Esp +8	
4744	wrist	4	1	2	39	0	Brassards runiques des arcanes	End +1 · Puiss. sorts +9	
4745	wrist	4	3	2	40	0	Brassards de chevaucheur martial	Agi +3 · End +8	
4763	ranged	2	2	2	9	4	Arc incurvé de noirbois		
4765	main	2	7	2	14	9	Epée large en émail	For +1	
4766	main	2	7	2	13	8	Lame farouche	Agi +1	
4777	two	2	5	2	18	13	Maillet en bois de fer	End +5	
4778	two	2	5	2	19	14	Lourde masse à pointes	For +6	
4781	chest	4	1	2	20	15	Gilet des murmures	Esp +6	
4782	chest	4	1	2	18	13	Robe du solstice	End +1 · Int +1 · Esp +5	
4786	waist	4	1	2	20	15	Ceinture de grand sage	Int +5	
4788	feet	4	2	2	20	15	Bottes agiles	Agi +5	
4789	feet	4	2	2	18	13	Bottes d'écurie	End +4	
4790	back	4	1	2	25	20	Cape d'Inferno	Rés. feu +5	
4792	back	4	1	2	23	18	Cape spirituelle	Esp +4	
4793	back	4	1	2	24	19	Cape sylvestre	End +2 · Esp +4	
4794	wrist	4	2	2	25	20	Brassards du loup	Agi +4 · End +2	
4795	wrist	4	2	2	25	20	Brassards de l'ours	End +5	
4796	wrist	4	2	2	25	20	Brassards de la chouette	Int +5	
4797	back	4	1	2	25	20	Cape flamboyante	Rés. feu +5	
4798	back	4	1	2	25	20	Cape runique lourde	End +3 · Esp +3	
4799	back	4	1	2	23	18	Cape antique	Esp +4	
4800	legs	4	3	2	23	18	Pantalon en mailles de la puissance	For +5 · End +5	
4816	legs	4	3	2	24	19	Jambières de légionnaire	For +5 · Esp +5	
4817	two	2	8	2	22	17	Claymore sacrée	End +7	
4818	two	2	8	2	24	19	Epée du bourreau	For +8	
4820	off	4	6	2	25	20	Targe de gardien	End +3 · Esp +3	
4821	off	4	6	2	23	18	Targe de l'ours	For +3 · End +3	
4822	off	4	6	2	23	18	Disque de la chouette	Int +4	
4824	main	2	0	2	27	22	Hache de confusion	Agi +4	
4825	one	2	0	2	29	24	Hache calleuse	PA +8	
4826	main	2	0	2	26	21	Hache de maraudeur	End +4	
4827	waist	4	1	2	28	23	Ceinture de sorcier	Int +8	
4828	waist	4	1	2	27	22	Ceinture du vent nocturne	End +3 · Int +6	
4829	waist	4	1	2	29	24	Ceinture du rêveur	Int +7 · Esp +2	
4830	legs	4	2	2	28	23	Jambières du sabre	Agi +7 · Esp +6	
4831	legs	4	2	2	26	21	Pantalon de traque	Agi +6 · End +6	
4832	legs	4	2	2	29	24	Sarong mystique	End +7 · Esp +7	
4833	shoulder	4	3	2	28	23	Epaulières glorieuses	End +5 · Esp +5	
4835	shoulder	4	3	2	30	25	Epaulières de soldat d'élite	For +6 · End +5	
4836	off	4	0	2	28	23	Orbe ignifugé	Rés. feu +6	
4837	off	4	0	2	30	25	Force de la volonté	Esp +6	
4838	off	4	0	2	26	21	Orbe de puissance	End +2 · Int +4	
4909	legs	4	2	2	15	0	Jambières du chasseur de kodo	Agi +4	
4939	two	2	8	2	11	0	Solide bâtarde	Agi +2	
4947	one	2	15	2	11	0	Dague dentelée	For +1	
4948	main	2	4	2	11	0	Masse hérissée	For +1	
4964	two	2	5	2	12	0	Ecraseur gobelin	For +2	
4971	main	2	4	2	12	0	Marteau de Skorn	For +1	
4974	one	2	15	2	12	0	Couteau de combat compact	Agi +1	
4975	off	4	6	2	39	0	Targe de vigilance	End +7 · Blocage +5	
4976	legs	4	2	2	41	0	Kilt de Mistspray	Esp +17	
4977	main	2	7	2	41	0	Epée de Trépas-d'Orgrim	For +4 · End +5	
4978	main	2	4	2	36	0	Marteau de Ryedol	For +6	
4979	wrist	4	1	2	42	0	Brassards enchantés en étoffe de pierre	End +4 · Int +8	
4983	two	2	5	2	42	0	Destructeur de roc	PA +34	
4984	off	4	0	2	41	0	Crâne de malédiction imminente	Int +7	
4987	one	2	7	2	45	0	Epée du capitaine nain	End +9	
4988	finger	4	0	2	50	0	Anneau ardent en obsidienne	End +12	
4989	chest	4	1	2	50	0	Robe de mage-dragon	For +7 · Esp +18	
5000	finger	4	0	2	26	21	Bague de corail	End +4 · Int +3	
5008	finger	4	0	2	36	31	Anneau de vif-argent	Agi +7 · Esp +3	
5016	legs	4	1	2	35	0	Pantalon de l'ouvrier	Agi +9 · Esp +9	
5029	neck	4	0	2	47	42	Talisman du seigneur naga	For +2 · End +10	
5079	trinket	4	0	2	40	35	Oeil de basilic Oeil-de-glace	Rés. givre +9	
5240	ranged	2	19	2	21	0	Baguette d'Illumination	Puiss. sorts +4	
5241	ranged	2	19	2	18	0	Bâton de flammes nain	Esp +2	
5242	ranged	2	19	2	16	0	Baguette de cendres	Puiss. sorts +2	
5244	ranged	2	19	2	30	0	Baguette consacrée	Int +3 · Esp +3	
5246	ranged	2	19	2	30	0	Bâtonnet d'excavation	End +3 · Puiss. sorts +4	
5247	ranged	2	19	2	40	0	Bâtonnet de désolation	End +5 · Esp +4	
5248	ranged	2	19	2	37	0	Baguette éclairante	Int +5 · Esp +3	
5249	ranged	2	19	2	40	0	Branchette ardente	Puiss. sorts +8	
5250	ranged	2	19	2	28	0	Baguette carbonisée	Int +3 · Puiss. sorts +3	
5252	ranged	2	19	2	21	0	Baguette de putréfaction	Int +3	
5253	ranged	2	19	2	40	0	Boute-feu gobelin	Int +5 · Esp +4	
5274	shoulder	4	1	2	27	0	Mantelet rose	Int +5 · Puiss. sorts +5	
5275	waist	4	2	2	15	0	Ceinturon de lien	Int +3	
5279	one	2	15	2	20	0	Eventreur de harpies	Agi +3	
5299	hands	4	2	2	20	0	Gants de la lune	Agi +3 · End +3	
5302	off	4	6	2	20	0	Targe en cobalt	End +3	
5306	two	2	10	2	20	0	Bâton du cavalier céleste	Esp +6	
5309	ranged	2	3	2	20	0	Mousquet de corsaire	Agi +3	
5310	legs	4	1	2	20	0	Culotte du loup de mer	For +4 · Esp +4	
5311	feet	4	2	2	21	0	Bottes sanglées	End +4 · Int +2 · Puiss. sorts +1	
5312	hands	4	3	2	21	0	Gantelets à rivets	For +4 · End +1	
5313	finger	4	0	2	25	0	Anneau de clan totémique	Int +3 · Esp +3	
5314	back	4	1	2	20	0	Cape de chasseur de sanglier	Agi +3	
5315	wrist	4	1	2	18	0	Garde-bras de bûcheron	End +2 · Esp +2	
5316	chest	4	2	2	25	0	Tunique de nacrécorce	End +4 · Puiss. sorts +8	
5317	chest	4	2	2	25	0	Tunique de mousse sèche	Agi +2 · End +8	
5318	two	2	1	2	20	0	Hache de Zhovur	End +6	
5320	feet	4	3	2	16	0	Bottes de lamelles matelassées	For +2 · End +2	
5321	one	2	7	2	20	0	Elégante épée courte	End +3	
5322	two	2	5	2	26	0	Marteau de démolition	For +9	
5323	off	4	0	2	25	0	Lanterne éternelle	Esp +3	
5324	main	2	4	2	16	0	Marteau d'ingénieur	End +2	
5325	off	4	6	2	16	0	Bouclier soudé	End +2	
5326	ranged	2	19	2	18	0	Bâton de vision	Int +2	
5327	legs	4	2	2	18	0	Pantalon graisseux d'artisan	For +3 · Agi +3	
5328	waist	4	3	2	15	0	Ceinture sanglée	For +2 · End +2	
5337	hands	4	1	2	16	0	Gants de randonnée	Esp +3	
5340	two	2	10	2	15	0	Touille-chaudron	End +4	
5341	chest	4	2	2	15	0	Tunique couverte de spores	End +1 · Esp +3	
5343	back	4	1	2	18	0	Cape d'aubergiste	End +3	
5344	main	2	0	2	14	0	Hache à pointe	Agi +1	
5345	two	2	5	2	14	0	Marteau en bois de fer	End +3	
5346	ranged	2	2	2	14	0	Arc de bataille orc	For +1	
5351	finger	4	0	2	20	0	Anneau du chasseur de primes	Agi +3 · End +1	
5355	waist	4	2	2	28	0	Ceinturon de belluaire	Agi +5 · End +5	
5356	ranged	2	19	2	27	0	Bâtonnet de flétrissure	Int +3 · Puiss. sorts +3	
5357	off	4	6	2	27	0	Bouclier des vallons	Int +1 · Esp +5	
5420	chest	4	1	2	14	0	Armure de la Banshee	End +3	
5459	main	2	0	2	13	0	Hache de défenseur	Armure +10	
5540	one	2	15	2	23	18	Dague à perles	Agi +2 · End +2	c164:1
5541	one	2	4	2	28	23	Marteau iridescent	For +3 · End +3	c164:1
5542	back	4	1	2	19	14	Cape brodée de perles	Int +3 · Puiss. sorts +2	c197:1
5587	main	2	4	2	13	0	Gourdin de ronceterre	End +1	
5604	ranged	2	19	2	13	0	Baguette elfique	Int +1	
5609	waist	4	2	2	22	0	Cordelière inébranlable	For +4 · End +3	
5610	back	4	1	2	15	0	Cape des terres venteuses	End +2	
5611	off	4	0	2	16	0	Larme de douleur	Int +5 · Esp +-3	
5613	two	2	10	2	23	0	Bâton du purificateur	Esp +8	
5614	two	2	8	2	31	0	Frappe du Séraphin	For +3 · Esp +10	
5615	two	2	8	2	20	0	Epée du bûcheron	Agi +2 · End +5	
5617	legs	4	2	2	13	0	Jambières du vagabond	For +2 · Agi +1	
5622	finger	4	0	2	22	0	Anneau du clergé	End +1 · Esp +3	
5626	two	2	1	2	20	0	Broie-crâne	For +6 · End +1	
5627	one	2	15	2	20	0	Lame de relique	End +3	
5629	hands	4	2	2	20	0	Gants poing-de-marteau	For +3 · Agi +3	
5630	hands	4	2	2	20	0	Gants du vent mordant	Int +3 · Puiss. sorts +4	
5739	chest	4	2	2	38	33	Harnais barbare	For +7 · Agi +8 · End +8	c165:1
5743	finger	4	0	2	40	35	Anneau prismatique	Int +9	
5757	main	2	4	2	20	0	Trique de bois dur	For +2 · End +2	
5766	chest	4	1	2	27	22	Robe de sorcier inférieur	Int +8 · Puiss. sorts +5	c197:1
5770	chest	4	1	2	30	25	Robe d'Arcana	Esp +7 · Puiss. sorts +8	c197:1
5780	waist	4	2	2	18	13	Ceinture en écailles de murloc	For +2 · Agi +3	c165:1
5781	chest	4	2	2	19	14	Cuirasse en écailles de murloc	For +5 · Agi +3	c165:1
5782	chest	4	2	2	34	29	Armure épaisse de murloc	For +9 · End +8	c165:1
5783	wrist	4	2	2	38	33	Brassards en écailles de murloc	For +5 · End +6	c165:1
5812	chest	4	1	2	25	0	Robe des temps anciens	Int +2 · Esp +8	
5813	two	2	8	2	32	0	Flamme d'Emil	For +11 · End +3	
5814	chest	4	2	2	30	0	Armure du ruisseau	For +4 · Esp +9	
5815	two	2	5	2	31	0	Pierre glaciale		
5817	ranged	2	2	2	30	0	Arc Lunaris	Agi +3 · End +3	
5818	ranged	2	19	2	30	0	Baguette d'éclat lunaire	Int +3 · Puiss. sorts +4	
5820	shoulder	4	1	2	32	0	Mantelet des fées	Int +6 · Esp +6	
5821	feet	4	2	2	24	0	Bottes de Traqueur noir	Agi +5 · End +2	
5822	hands	4	3	2	24	0	Gantelets du hallier	For +5 · End +2	
5828	finger	4	0	6	1	1	Ring of Uber Resists (TEST)	Rés. feu +315 · Rés. givre +315 · Rés. nature +315 · Rés. ombre +315 · Rés. arcanes +315	
5944	feet	4	3	2	15	0	Grèves de la milice du peuple	End +3	
5957	chest	4	2	2	10	3	Gilet en cuir cousu main	Agi +1	c165:1
5958	legs	4	2	2	21	16	Pantalon élégant en cuir	Int +5 · Esp +4	c165:1
5961	legs	4	2	2	23	18	Pantalon noir en cuir	Agi +8	c165:1
5962	legs	4	2	2	32	27	Pantalon de gardien	Int +8 · Puiss. sorts +8	c165:1
5963	legs	4	2	2	34	29	Jambières barbares	For +7 · Agi +7 · End +7	c165:1
5964	shoulder	4	2	2	35	30	Epaulières barbares	For +5 · Agi +5 · End +6	c165:1
5965	back	4	1	2	37	32	Cape de gardien	Int +5 · Puiss. sorts +6	c165:1
5966	hands	4	2	2	38	33	Gants de gardien	Int +8 · Puiss. sorts +8	c165:1
6040	wrist	4	3	2	37	32	Brassards en écailles dorées	For +6 · End +5	c164:1
6084	legs	4	3	2	13	0	Jambières de garde de Hurlevent	For +3	
6085	chest	4	2	2	13	0	Tunique de fantassin	Agi +1 · End +2	
6092	feet	4	2	2	18	0	Bottes de dragonnet noir	End +4	
6093	two	2	5	2	27	0	Concassorc	For +8 · End +4	q19
6095	feet	4	1	2	24	0	Bottes d'errance	End +4 · Int +4	
6186	two	2	8	2	18	0	Découpeur de trogg	Esp +5	
6187	off	4	6	2	17	0	Défenseur nain	End +3	q217
6188	feet	4	3	2	15	0	Ecrase-boue	End +3	
6189	shoulder	4	3	2	24	0	Epaulières en mailles solides	End +6	
6191	feet	4	1	2	24	0	Bottes de Kimbra	Int +4 · Esp +3	
6194	main	2	0	2	32	0	Désosseuse	End +5	
6203	off	4	6	2	13	8	Bouclier des nervis	For +1	
6214	two	2	5	2	16	11	Grand maillet en cuivre	For +4	c164:1
6215	two	2	10	2	13	0	Bâton de combat équilibré	Agi +2 · End +2	
6223	off	4	6	2	35	0	Cimier de Darkshire	For +2 · End +7	
6238	chest	4	1	2	10	5	Robe marron en lin	Esp +1	c197:1
6239	chest	4	1	2	12	7	Gilet rouge en lin	Int +2 · Puiss. sorts +1	c197:1
6240	chest	4	1	2	12	7	Gilet bleu en lin	Esp +2 · Puiss. sorts +1	c197:1
6241	chest	4	1	2	10	5	Robe blanche en lin	Int +1	c197:1
6242	chest	4	1	2	14	9	Robe bleue en lin	Esp +3 · Puiss. sorts +2	c197:1
6243	chest	4	1	2	18	13	Robe verte en laine	Int +3 · Puiss. sorts +3	c197:1
6263	chest	4	1	2	20	15	Salopette bleue	For +4 · End +4	c197:1
6264	chest	4	1	2	23	18	Robe d'adepte supérieur	Int +2 · Esp +7 · Puiss. sorts +1	c197:1
6282	legs	4	1	2	32	0	Pantalon de rituel funéraire	For +3 · Int +5 · Esp +9	
6350	feet	4	3	2	18	13	Bottes grossières en bronze	For +2 · End +3	c164:1
6360	one	2	4	2	25	20	Poisson aux écailles d'acier	For +4	
6466	back	4	1	2	18	13	Cape en écailles de déviant	Agi +2 · End +2	c165:1
6467	hands	4	2	2	21	16	Gants en écailles de déviant	Agi +3 · End +3	c165:1
6468	waist	4	2	3	23	18	Ceinture en écailles de déviant	For +3 · Agi +5 · End +6	c165:1
6477	waist	4	1	2	20	0	Echarpe de la prairie	End +3 · Int +3	
6478	feet	4	1	2	23	0	Ecrabouille-rat	For +3 · Esp +4	
6482	feet	4	1	2	24	0	Bottes de marchefeu	Int +1 · Esp +5 · Puiss. sorts +2	
6502	chest	4	3	2	22	0	Broigne violette	End +6 · Esp +1	
6503	chest	4	1	2	22	0	Robe bigarrée	Int +2 · Esp +6	
6589	finger	4	0	2	26	21	Anneau viridien		
6659	legs	4	1	2	20	0	Pantalon du scarabée	End +4 · Esp +4	
6664	shoulder	4	1	2	26	0	Mantelet vaudou	End +4 · Esp +5	
6665	wrist	4	3	2	26	0	Brassards maléficiés	Agi +2 · End +4	
6666	feet	4	3	2	22	0	Bottes de boueux	Agi +3 · End +4	
6667	back	4	1	2	27	0	Cape d'ingénieur	End +5 · Int +2	
6668	feet	4	2	2	27	0	Bottes du conscrit	For +5 · End +5	
6669	finger	4	0	2	25	0	Anneau sacré	Esp +4 · Puiss. sorts +2	
6670	chest	4	2	2	27	0	Armure de la panthère	For +2 · Agi +9	
6671	legs	4	3	2	27	0	Jambières du molosse	For +10	
6675	wrist	4	3	2	27	0	Brassards trempés	End +5 · Esp +1	
6676	off	4	6	2	27	0	Targe du connétable	End +4 · Esp +3	
6677	ranged	2	19	2	26	0	Baguette de sortilèges	Puiss. sorts +5	
6678	finger	4	0	2	28	0	Anneau de grâce elfique	End +3 · Esp +4	
6698	finger	4	0	6	1	1	Pierre de Pierce		
6707	finger	4	0	6	1	1	Pierre de Lapidis		
6708	finger	4	0	6	1	1	Pierre de Goodman		
6709	chest	4	2	2	18	13	Gilet Lueur-de-lune	Int +3 · Puiss. sorts +4	c165:1
6711	finger	4	0	6	1	1	Pierre de Kurtz		
6719	waist	4	2	2	30	0	Ceinture des vents	Agi +6 · End +5	
6720	head	4	2	2	37	0	Coiffure de chasseur d'esprit	Agi +10 · Esp +9	
6721	chest	4	3	2	24	0	Pansière de Kor	For +4 · End +4 · Esp +4	
6722	wrist	4	3	2	30	0	Maniques bestiales	For +1 · End +6	
6724	finger	4	0	6	1	1	Pierre de Backus		
6726	waist	4	1	2	41	0	Ceinture de sécurité personnalisée de Razzeric	End +1 · Int +12	
6727	hands	4	2	2	41	0	Gants de course de Razzeric	Agi +8 · End +9	
6728	finger	4	0	6	1	1	Pierre de Brownell		
6729	ranged	2	19	2	38	0	Boute-feu de Fizzle	Int +3 · Puiss. sorts +5	
6730	chest	4	3	2	16	11	Cotte d'anneaux de Forgefer	End +4	c164:1
6731	chest	4	3	2	20	15	Cuirasse de Forgefer	For +3 · End +3 · Armure +30	c164:1
6732	hands	4	2	2	38	0	Gants de mécanicien gnome	For +8 · Int +7	
6733	hands	4	3	2	28	23	Gantelets de Forgefer	PA +12 · Armure +50	c164:1
6737	legs	4	1	2	35	0	Pantalon des feuilles sèches	End +9 · Esp +9	
6738	main	2	0	2	35	0	Croissant sanglant		
6739	ranged	2	2	2	29	0	Visée du rôdeur	Agi +3 · Int +3	
6740	waist	4	2	2	29	0	Echarpe azur	End +3 · Int +7	
6744	hands	4	1	2	33	0	Gants de Kapelan	For +7 · Int +6	
6745	back	4	1	2	33	0	Cape de vélocité	Agi +6 · End +2	
6746	off	4	6	2	40	0	Targe de basalte	End +2 · Int +8	
6747	shoulder	4	3	2	40	0	Espauliers de massacreur	For +8 · End +8	
6757	finger	4	0	2	38	0	Chevalière de Jaina	For +3 · End +7	
6773	chest	4	3	2	42	0	Cotte d’anneaux de maraudeur kolkar	For +14 · Agi +7	
6774	off	4	0	2	42	0	Doigt de traître	End +5 · Int +5 · Esp +5	
6780	waist	4	1	2	36	0	Echarpe lilas	Int +9 · Esp +3	
6784	hands	4	2	2	36	0	Garde-mains à fermoir	Agi +7 · End +7	
6787	chest	4	1	2	22	17	Robe blanche en laine	End +5 · Esp +4	c197:1
6788	waist	4	2	2	42	0	Ceinture de chasse kolkar	Agi +8 · End +9	
6789	back	4	1	2	42	0	Couverture de cérémonie centaure	Int +2 · Esp +9	
6790	finger	4	0	2	32	0	Anneau de calme	Esp +7	
6791	feet	4	1	2	40	0	Bottes d'Hellion	Agi +3 · Int +5 · Esp +9	
6792	shoulder	4	3	2	40	0	Espauliers sanguins	For +8 · Esp +8	
6793	wrist	4	3	2	40	0	Brassards d'Auric	End +8 · Int +3	
6794	hands	4	2	2	40	0	Gantelets flamme-tempête	For +10 · Esp +4	
6797	ranged	2	19	2	37	0	Pique-oeil	End +3 · Esp +5	
6798	ranged	2	3	2	37	0	Haquebute explosive	Agi +3 · End +5	
6801	chest	4	1	2	40	0	Tablier baroque	For +6 · End +6 · Esp +7	
6828	off	4	6	2	38	0	Targe du visionnaire	End +4 · Esp +7	
6832	back	4	1	3	42	0	Cape du chancre	Esp +13	
6898	off	4	0	3	25	0	Orbe de Soran'ruk		
6900	chest	4	1	3	38	0	Robe sanglante dorée enchantée	End +10 · Int +17	
6953	two	2	5	3	31	0	Poing de Verigan	End +5 · Int +6 · Esp +10	
6966	main	2	0	2	15	0	Hache d'Elunite	End +1	
6967	main	2	7	2	15	0	Epée d'Elunite	End +1	
6968	main	2	4	2	15	0	Marteau d'Elunite	End +1	
6969	one	2	15	2	15	0	Dague d'Elunite	End +1	
6970	off	4	6	2	20	0	Faveur de Furen	For +3	
6971	head	4	3	2	31	0	Camail en acier trempé	Agi +7 · End +8	
6972	chest	4	3	3	30	0	Haubert en acier trempé	For +5 · End +14	
6973	legs	4	3	2	29	0	Jambières en acier trempé	For +7 · End +7	
6974	hands	4	3	2	31	0	Gantelets en acier trempé	For +6 · End +6	
6975	two	2	1	3	40	0	Hache de tourbillon	For +16 · End +15	
6976	two	2	5	3	40	0	Marteau de tourbillon	For +16 · End +15	
6977	two	2	8	3	40	0	Epée de tourbillon	For +16 · End +15	
6978	main	2	0	2	15	0	Hache d'Umbral	End +1	
6979	main	2	0	2	15	0	Hache de Haggard	End +1	
6980	one	2	15	2	15	0	Dague de Haggard	End +1	
6981	one	2	15	2	15	0	Dague d'Umbral	End +1	
6982	main	2	4	2	15	0	Masse d'Umbral	End +1	
6983	main	2	4	2	15	0	Marteau d'Haggard	End +1	
6984	main	2	7	2	15	0	Epée d'Umbral	End +1	
6985	main	2	7	2	15	0	Epée de Haggard	End +1	
7027	feet	4	1	2	28	23	Bottes des ténèbres	End +5	c197:1
7046	legs	4	1	2	28	23	Pantalon azur en soie	Int +6	c197:1
7047	hands	4	1	2	29	24	Mains des ténèbres	Esp +5	c197:1
7048	head	4	1	2	29	24	Chaperon azur en soie	End +8	c197:1
7049	hands	4	1	2	30	25	Gants de vraie foi	Int +3 · Dégâts sorts +5 · Soins +15	c197:1
7050	head	4	1	2	32	27	Bandeau en soie	End +8 · Puiss. sorts +9	c197:1
7051	chest	4	1	2	34	29	Gilet terrestre	End +6 · Esp +10	c197:1
7052	waist	4	1	2	35	30	Ceinture azur en soie	End +5	c197:1
7053	back	4	1	2	35	30	Cape azur en soie	Esp +3	c197:1
7054	chest	4	1	3	38	33	Robe de puissance	Int +12 · Esp +8 · Puiss. sorts +14	c197:1
7055	waist	4	1	2	35	30	Ceinture cramoisie en soie	Int +7 · Puiss. sorts +6	c197:1
7056	back	4	1	2	36	31	Cape cramoisie en soie	End +3 · Puiss. sorts +5 · Rés. feu +6	c197:1
7057	shoulder	4	1	2	36	31	Epaulières vertes en soie	Int +11 · Puiss. sorts +8	c197:1
7058	chest	4	1	2	37	32	Gilet cramoisi en soie	Int +10 · Puiss. sorts +12	c197:1
7059	shoulder	4	1	2	38	33	Epaulières cramoisies en soie	Int +8 · Esp +7	c197:1
7060	shoulder	4	1	2	38	33	Epaulières azur	End +5	c197:1
7061	waist	4	1	2	39	34	Ceinture terrestre en soie	Esp +8 · Dégâts sorts +6 · Soins +8	c197:1
7062	legs	4	1	2	39	34	Culotte cramoisie en soie	Int +13 · Puiss. sorts +8	c197:1
7063	chest	4	1	2	41	36	Robe cramoisie en soie	Int +15	c197:1
7064	hands	4	1	2	42	37	Gants cramoisis en soie	Int +6	c197:1
7065	chest	4	1	2	33	28	Armure verte en soie	Int +13 · Puiss. sorts +9	c197:1
7106	hands	4	1	2	33	0	Gants du zodiaque	Int +4 · Esp +7	q181
7107	waist	4	3	2	33	0	Ceinture des étoiles	For +6 · End +6	q181
7115	main	2	0	2	15	0	Hache de l'héritier	End +1	
7116	one	2	15	2	15	0	Dague de l'héritier	End +1	
7117	main	2	4	2	15	0	Marteau de l'héritier	End +1	
7118	main	2	7	2	15	0	Epée de l'héritier	End +1	
7120	off	4	6	2	20	0	Bouclier de Ruga	For +3	
7129	hands	4	3	2	31	0	Gantelets de brutalité	For +6 · End +6	
7130	head	4	3	2	31	0	Camail de brutalité	Agi +7 · End +8	
7132	legs	4	3	2	29	0	Jambières de brutalité	For +7 · End +7	
7133	chest	4	3	3	30	0	Haubert de brutalité	For +5 · End +14	
7166	one	2	15	2	11	6	Dague en cuivre	Agi +1	c164:1
7189	feet	4	1	2	45	0	Bottes-fusées gobelines		c202:1
7229	chest	4	3	2	13	0	Broigne d'explorateur	End +2 · Int +1	
7280	legs	4	2	2	11	6	Pantalon en cuir robuste	End +1	c165:1
7281	wrist	4	2	2	14	9	Brassards en cuir léger	For +1 · Agi +1	c165:1
7282	legs	4	2	2	19	14	Pantalon en cuir léger	Agi +5 · End +3	c165:1
7283	back	4	1	2	20	15	Cape de dragonnet noir	Puiss. sorts +3	c165:1
7284	hands	4	2	2	24	19	Gants en cuir de dragonnet rouge		c165:1
7285	hands	4	2	2	24	19	Gants d'agilité en cuir	Agi +4 · End +4	c165:1
7298	one	2	15	2	13	0	Lame de malice	Agi +2	
7326	main	2	0	2	15	0	Hache de Thun'grim	End +1	
7327	one	2	15	2	15	0	Dague de Thun'grim	End +1	
7328	main	2	4	2	15	0	Masse de Thun'grim	End +1	
7329	main	2	7	2	15	0	Epée de Thun'grim	End +1	
7334	chest	4	1	2	28	0	Robe efflorescente	End +9 · Int +2	
7335	chest	4	2	2	28	0	Tunique du grizzly	End +10	
7336	chest	4	3	2	24	0	Cotte d'anneaux forestière	For +8 · Agi +1	
7344	off	4	0	2	33	0	Torche de la sainte flamme	Esp +5	
7348	hands	4	2	2	25	20	Gants de fabricant d'arcs	Crit. +14	c165:1
7349	hands	4	2	2	27	22	Gants d'herboriste		c165:1
7352	shoulder	4	2	2	27	22	Epaulières terrestres en cuir	End +7	c165:1
7358	hands	4	2	2	28	23	Gants de chapardeur	Agi +8	c165:1
7359	hands	4	2	2	29	24	Gants terrestres lourds	PA +16	c165:1
7373	legs	4	2	2	33	28	Jambières en cuir mat	Agi +13	c165:1
7374	chest	4	2	2	35	30	Armure en cuir mat	Agi +14	c165:1
7375	chest	4	2	2	35	30	Armure de dragonnet vert	End +11	c165:1
7377	back	4	1	2	36	31	Cape de givre en cuir		c165:1
7378	wrist	4	2	2	37	32	Brassards mats	Agi +8	c165:1
7386	wrist	4	2	2	38	33	Brassards de dragonnet vert	Int +8	c165:1
7387	waist	4	2	2	39	34	Ceinture matte	Agi +8 · End +8	c165:1
7390	feet	4	2	2	40	35	Bottes mattes	Agi +11 · End +3	c165:1
7391	feet	4	2	2	40	35	Bottes de rapidité	End +10	c165:1
7426	finger	4	0	2	30	25	Anneau céruléen		
7427	neck	4	0	2	31	26	Talisman céruléen		
7466	finger	4	0	2	37	32	Anneau vermeil		
7467	neck	4	0	2	35	30	Collier vermeil		
7497	finger	4	0	2	40	35	Anneau d'ivoire		
7506	trinket	4	0	2	25	0	Télécommande universelle gnome		c202:1
7507	off	4	0	2	10	0	Orbe des arcanes	Esp +1	
7508	off	4	0	2	10	0	Orbe de Ley	Esp +1	
7509	chest	4	1	2	20	0	Robe en tisse-mana	Int +6	
7510	chest	4	1	2	20	0	Robe du feu-sorcier mineur	Int +6	
7511	chest	4	1	2	31	0	Robe du noeud astral	End +6 · Int +6 · Esp +6	
7512	chest	4	1	2	31	0	Robe du Néant	End +6 · Int +6 · Esp +6	
7513	ranged	2	19	3	40	0	Baguette de Ragefire	Int +4	
7514	ranged	2	19	3	40	0	Baguette d'Icefury	Int +4	
7515	off	4	0	3	40	0	Orbe céleste	Int +3 · Puiss. sorts +13	
7547	finger	4	0	2	46	41	Anneau d'onyx		
7548	neck	4	0	2	46	41	Foulard d'onyx		
7554	off	4	0	2	19	14	Branche de saule		
7555	off	4	0	2	45	40	Etoile régalienne		
7556	off	4	0	2	40	35	Orbe du crépuscule		
7558	off	4	0	2	25	20	Douve chatoyante		
7608	off	4	0	2	21	16	Chope ornée de prophète	Int +3 · Esp +1	
7609	off	4	0	2	35	30	Bâton d'ambre de doyen		
7610	off	4	0	2	41	36	Sphère de l'aurore	Int +7 · Esp +4	
7738	hands	4	1	2	18	0	Gants vert sapin	Int +3 · Esp +2	
7739	back	4	1	2	18	0	Cape de bûcheron	Esp +3	
7748	off	4	6	2	45	0	Targe de Forcestone	End +3 · Esp +9	
7913	shoulder	4	3	2	32	27	Epaulières barbares en fer	For +6 · Agi +6	c164:1
7914	chest	4	3	2	32	27	Cuirasse barbare en fer	For +12	c164:1
7915	head	4	3	2	35	30	Casque barbare en fer	For +9 · Agi +9	c164:1
7916	feet	4	3	2	36	31	Bottes barbares en fer	For +7 · Agi +7	c164:1
7917	hands	4	3	2	37	32	Gants barbares en fer	For +11	c164:1
7918	shoulder	4	4	2	41	40	Epaulières lourdes en mithril	End +12	c164:1
7919	hands	4	4	2	41	40	Gantelets lourds en mithril	End +8 · Armure +80	c164:1
7920	legs	4	3	2	42	40	Jambières en plaques de mithril	Esp +11 · Esquive +12	c164:1
7921	legs	4	4	2	42	40	Jambières lourdes en mithril	End +11 · Armure +120	c164:1
7922	head	4	4	2	43	40	Heaume en plaques d'acier	For +12 · End +12	c164:1
7924	wrist	4	3	2	43	40	Brassards en plaques de mithril	End +6 · Esp +7	c164:1
7925	hands	4	3	2	44	40	Gants en plaques de mithril	End +9 · Esp +10	c164:1
7926	legs	4	4	2	44	40	Jambières ornées en mithril	For +12 · Esquive +12	c164:1
7927	hands	4	4	2	44	40	Gants ornés en mithril	Crit. +14	c164:1
7928	shoulder	4	4	2	45	40	Épaulières ornées en mithril	For +5 · Esquive +12	c164:1
7929	legs	4	3	2	42	40	Jambières de guerre orques	For +17	c164:1
7930	chest	4	4	2	46	41	Cuirasse lourde en mithril	End +15 · Armure +90	c164:1
7931	head	4	3	2	46	41	Camail en mithril	End +12 · Esp +13	c164:1
7932	shoulder	4	3	2	47	42	Épaulières en plaques de mithril	End +10 · Esp +10	c164:1
7933	feet	4	4	2	47	42	Bottes lourdes en mithril	End +12 · Armure +70	c164:1
7934	head	4	4	2	47	42	Heaume lourd en mithril	End +15 · Armure +100	c164:1
7935	chest	4	4	2	48	43	Cuirasse ornée en mithril	Crit. +14 · Esquive +12	c164:1
7936	feet	4	4	2	49	44	Bottes ornées en mithril	Esquive +12	c164:1
7937	head	4	4	2	49	44	Heaume orné en mithril	For +10 · Crit. +14	c164:1
7938	hands	4	4	3	45	40	Gantelets en vrai-argent	For +16 · End +7	c164:1
7939	chest	4	4	3	49	44	Cuirasse en vrai-argent	End +12	c164:1
7941	one	2	0	2	42	37	Hache lourde en mithril	End +7	c164:1
7942	one	2	0	2	44	39	Hache lumineuse bleue	Agi +8	c164:1
7943	one	2	7	2	45	40	Lame corrompue en mithril	For +6 · Agi +4	c164:1
7944	one	2	7	2	48	43	Rapière éblouissante en mithril	Agi +8	c164:1
7945	one	2	4	2	46	41	Grande masse noire	For +8	c164:1
7946	one	2	4	2	49	44	Marteau runique en mithril	End +7 · Déf. +4	c164:1
7947	one	2	15	2	51	46	Kriss d'ébène	Agi +9	c164:1
7948	waist	4	2	2	32	0	Ceinturon de Thero-shan	Agi +6 · End +6	
7949	legs	4	2	2	36	0	Jambières de Thero-shan	Agi +10 · PA +10 · Rés. givre +11	
7950	chest	4	2	2	42	0	Armure de Thero-shan	Agi +7 · Toucher +10	
7951	hands	4	2	2	32	0	Mains de Thero-shan	Rés. nature +8	
7952	feet	4	2	2	36	0	Bottes de Thero-shan	Agi +10 · End +3	
7953	head	4	2	2	42	0	Masque de Thero-shan	Agi +14	
7954	one	2	4	3	47	42	Le Briseur		c164:1
7955	two	2	8	2	11	6	Claymore en cuivre	For +1 · End +1	c164:1
7956	two	2	5	2	25	20	Marteau de guerre en bronze	For +6 · End +6	c164:1
7957	two	2	8	2	26	21	Epée de guerre en bronze	End +6 · Puiss. sorts +7	c164:1
7958	two	2	1	2	27	22	Hache de guerre en bronze	For +10	c164:1
7959	two	2	6	3	50	45	Corruptrice		c164:1
7960	two	2	8	3	52	47	Championne en vrai-argent		c164:1
7961	one	2	7	3	49	44	Lame fantôme		c164:1
7963	chest	4	3	2	40	35	Cuirasse en acier	End +12 · Blocage +10	c164:1
8174	head	4	2	2	40	35	Chapeau de cuir confortable	End +11 · Puiss. sorts +10	c165:1
8175	chest	4	2	2	41	36	Tunique de la nuit	Agi +15 · End +6	c165:1
8176	head	4	2	2	41	36	Bandeau de la nuit	Agi +12 · End +11	c165:1
8185	legs	4	3	2	47	42	Jambières en écailles de tortue	End +11 · Int +10 · Puiss. sorts +11	c165:1
8187	hands	4	3	2	41	36	Gants en écailles de tortue	End +7 · Int +6 · Puiss. sorts +6	c165:1
8189	chest	4	3	2	42	37	Cuirasse en écailles de tortue	End +9 · Int +9 · Puiss. sorts +9	c165:1
8191	head	4	3	2	46	41	Casque en écailles de tortue	End +10 · Int +10 · Puiss. sorts +10	c165:1
8192	shoulder	4	2	2	42	37	Epaulières de la nuit	Agi +11 · End +5	c165:1
8193	legs	4	2	2	46	41	Pantalon de la nuit	Agi +16 · End +7	c165:1
8195	back	4	1	2	46	41	Cape de la nuit	Agi +10 · End +3	c165:1
8197	feet	4	2	2	47	42	Bottes de la nuit	Agi +12	c165:1
8198	wrist	4	3	2	42	37	Brassards en écailles de tortue	End +5 · Int +5 · Puiss. sorts +6	c165:1
8200	chest	4	2	2	43	38	Robe du grand vaudou	Int +14 · Puiss. sorts +9	c165:1
8201	head	4	2	2	44	39	Masque du grand vaudou	Int +14 · Puiss. sorts +9	c165:1
8202	legs	4	2	2	47	42	Pantalon du grand vaudou	Int +10 · Puiss. sorts +15	c165:1
8203	chest	4	3	2	44	39	Cuirasse armée du scorpide	Agi +15 · Int +7	c165:1
8204	hands	4	3	2	45	40	Gants armés du scorpide	Agi +10 · Int +9	c165:1
8205	wrist	4	3	2	44	39	Brassards armés du scorpide	Agi +7 · Int +6	c165:1
8206	legs	4	3	2	49	44	Jambières armées du scorpide	Agi +17 · Int +10	c165:1
8207	shoulder	4	3	2	48	43	Epaulières armées du scorpide	Agi +10 · Int +10	c165:1
8208	head	4	3	2	50	45	Casque armé du scorpide	Agi +14 · Int +14	c165:1
8209	feet	4	3	2	47	42	Bottes armées du scorpide	Agi +12 · Int +7	c165:1
8210	shoulder	4	2	2	44	39	Epaulières en cuir sauvage		c165:1
8211	chest	4	2	2	45	40	Gilet en cuir sauvage		c165:1
8212	legs	4	2	2	50	45	Jambières en cuir sauvage		c165:1
8213	feet	4	2	2	49	44	Bottes en cuir sauvage		c165:1
8214	head	4	2	2	45	40	Casque en cuir sauvage		c165:1
8215	back	4	1	2	50	45	Cape en cuir sauvage		c165:1
8216	back	4	1	2	48	43	Cape du grand vaudou	Int +9 · Puiss. sorts +5	c165:1
8345	head	4	2	3	45	40	Casque tête-de-loup	Esp +10	c165:1
8346	hands	4	2	3	46	41	Gantelets de la mer	Agi +7 · Dégâts sorts +18 · Soins +6	c165:1
8347	hands	4	3	3	45	40	Gantelets en écailles de dragon	Agi +6 · End +7 · Crit. +14	c165:1
8348	head	4	2	3	50	45	Casque de feu	Agi +17 · End +10 · Rés. feu +5	c165:1
8349	chest	4	2	3	50	45	Cuirasse de plumes	Int +10 · Esp +24 · Puiss. sorts +19	c165:1
8367	chest	4	3	3	51	46	Cuirasse en écailles de dragon	End +10 · Rés. feu +13 · Rés. givre +13 · Rés. nature +13 · Rés. ombre +13	c165:1
8663	trinket	4	0	2	40	0	Insigne en mithril	Armure +50	
8708	main	2	4	4	50	40	Marteau d'expertise		
9362	finger	4	0	2	31	0	Anneau d'or brillant	End +4 · Esp +4	
9366	hands	4	3	2	41	36	Gantelets en écailles dorées	For +11 · End +4	c164:1
9380	one	2	7	3	50	45	Jang'thraze le Protecteur		
9417	neck	4	0	3	47	42	Amulette archaïque		
9513	two	2	10	2	10	0	Bâton de Ley	Int +1 · Esp +1	
9514	two	2	10	2	10	0	Bâton des arcanes	Int +1 · Esp +1	
9515	chest	4	1	2	31	0	Tunique du Néant	End +6 · Int +9	
9516	chest	4	1	2	31	0	Chemisette du noeud astral	End +6 · Int +9	
9517	two	2	10	3	40	0	Bâton céleste	Int +8	
9518	hands	4	2	2	36	0	Presse-boue	For +11	
9519	feet	4	1	2	36	0	Bottes de Durtfeet	For +4 · Esp +9	
9520	one	2	15	2	41	0	Tueuse muette	Agi +7	
9521	two	2	1	2	41	0	Tranche-tête	For +15 · End +4	
9598	chest	4	1	2	10	0	Robe du dormeur	End +1	
9599	legs	4	3	2	10	0	Jambières en mailles d'écorce	End +1	
9602	two	2	8	2	10	0	Lame Brushwood	End +1	
9603	two	2	10	2	10	0	Bâton Gritroot	End +1	
9607	off	4	6	2	25	0	Bastion de Hurlevent	Déf. +3	
9622	finger	4	0	2	35	0	Anneau Reedknot	End +3 · Puiss. sorts +7	
9630	feet	4	2	2	45	0	Bottes artisanales de Pratt	Agi +11 · End +6	
9631	hands	4	2	2	45	0	Gants artisanaux de Pratt	For +10 · Agi +9	
9632	hands	4	2	2	45	0	Gants artisanaux de Jangdor	For +10 · Agi +9	
9633	feet	4	2	2	45	0	Bottes artisanales de Jangdor	Agi +11 · End +6	
9634	hands	4	1	2	46	0	Gants de manipulation habile	Agi +6 · End +6 · Int +10	
9635	back	4	1	2	45	0	Cape de maître apothicaire	Int +1 · Esp +10	
9636	waist	4	1	2	45	0	Echarpe de bretteur	For +10 · End +9	
9637	feet	4	4	2	45	0	Bottes Shinkicker	For +10 · Agi +9	
9638	wrist	4	3	2	50	0	Crispins chéloniens	End +4 · Int +10	
9642	finger	4	0	2	50	0	Anneau de la grande tortue	Armure +120	
9643	off	4	6	2	51	0	Déflecteur optomatique	For +5 · Blocage +10	
9644	off	4	0	2	51	0	Minuteur thermostatique	Agi +3 · Esp +11	
9645	feet	4	1	2	49	0	Bottes d'inventeur gnome	End +7 · Int +2 · Esp +11	
9646	feet	4	4	2	49	0	Bottes engloutissantes gnomes	Agi +-5 · End +16	
9647	shoulder	4	2	2	48	0	Expérience de vol ratée	For +10 · Agi +10	
9648	back	4	1	2	48	0	Serviette en cotte de mailles	Int +3 · Esp +10	
9649	chest	4	1	2	55	0	Habit de faveur royale	End +3 · Int +3 · Esp +16	
9650	chest	4	3	2	55	0	Plastron de la garde d'honneur	For +22 · End +3 · Int +3	
9651	main	2	4	2	53	0	Marteau-tempête des chevaucheurs de gryphon		
9652	legs	4	2	2	53	0	Jambières des chevaucheurs de gryphon	For +15 · Agi +15	
9653	head	4	1	2	50	0	Lunettes de sprinter	Agi +14 · Int +14	
9654	ranged	2	19	2	50	0	Bâton de flamboyance	Int +6 · Esp +6	
9655	finger	4	0	2	50	0	Anneau de concentration	For +4 · Esp +10	
9656	hands	4	4	2	49	0	Poignes de granit	For +15	
9657	waist	4	2	2	49	0	Cordelière de la charmille	For +14 · End +3	
9658	feet	4	1	2	43	0	Bottes des Maharishi	Agi +4 · Int +9 · Esp +6	
9660	back	4	1	2	43	0	Cape d'astronome	Esp +10	
9661	off	4	6	2	43	0	Barrière naturelle	End +1 · Esp +9	
9662	feet	4	4	2	43	0	Bottes Rushridge	Agi +7 · End +10	
9663	chest	4	3	2	45	0	Plastron du cavalier de l'aube	Agi +16 · Esp +5	
9664	head	4	4	2	45	0	Casque de sentinelle	Agi +9 · End +12 · Esp +6	
9665	hands	4	1	2	50	0	Gants du cimier ailé	End +11 · Int +10	
9666	waist	4	3	2	50	0	Ceinturon Forte-corne	End +11 · Int +10	
9678	two	2	5	2	43	0	Castagneur de Tok'kar	End +18	
9679	two	2	1	2	43	0	Découpeur de Tok'kar	For +15 · End +6	
9680	one	2	15	2	43	0	Perforeuse de Tok'kar	Agi +6 · End +3	
9682	waist	4	2	2	44	0	Ceinture du cuistot en cuir	End +3 · Int +12	
9683	two	2	10	2	50	0	Force du tréant	End +7 · Int +18	
9684	main	2	0	2	51	0	Force de l'hippogryphe	Agi +9	
9685	two	2	1	2	51	46	Volonté du géant des montagnes	For +15 · End +14	
9686	main	2	4	2	51	0	Esprit du dragon féérique	End +9	
9687	waist	4	2	2	33	0	Ceinture de lutteur	For +7 · End +5	
9698	hands	4	2	2	33	0	Gants de clairvoyance	End +7 · Puiss. sorts +7	
9699	back	4	1	2	33	0	Cape de la garnison	Agi +3 · End +6	
9703	back	4	1	2	43	0	Cape brûlée	End +2 · Esp +9	
9704	hands	4	2	2	43	0	Gants de voleur de bétail	For +9 · Int +9	
9705	waist	4	2	2	43	0	Lacet de Tharg	For +13	
9706	off	4	6	2	43	0	Bouclier de Tharg	End +10	
9718	one	2	7	3	38	33	Lame des héros reforgée	For +3 · End +8	
9769	off	4	0	2	27	22	Branche en tisse-vert		
9800	off	4	0	2	29	24	Orbe sylvestre		
9882	off	4	0	2	43	38	Sphère de sorcier		
9888	off	4	6	2	36	31	[PÉRIMÉ] Protecteur elfique		
9914	off	4	0	2	48	43	Sceptre royal		
9998	chest	4	1	2	41	36	Gilet noir en tisse-mage	Esp +12 · Puiss. sorts +11	c197:1
9999	legs	4	1	2	41	36	Pantalon noir en tisse-mage	Esp +14 · Puiss. sorts +8	c197:1
10001	chest	4	1	2	42	37	Robe noire en tisse-mage	Int +8 · Esp +14	c197:1
10002	legs	4	1	2	42	37	Pantalon en tisse-ombre	End +6	c197:1
10003	hands	4	1	2	43	38	Gants noirs en tisse-mage	Puiss. sorts +15	c197:1
10004	chest	4	1	2	43	38	Robe en tisse-ombre	Esp +7	c197:1
10007	chest	4	1	2	43	38	Gilet rouge en tisse-mage	Int +18	c197:1
10008	head	4	1	2	43	38	Masque blanc de bandit	For +11 · Agi +11	c197:1
10009	legs	4	1	2	43	38	Pantalon rouge en tisse-mage	Int +12 · Puiss. sorts +14	c197:1
10010	legs	4	1	2	44	39	Pantalon en étoffe-tempête	Esp +15 · Dégâts sorts +5 · Soins +15	c197:1
10011	hands	4	1	2	44	39	Gants en étoffe-tempête	Int +12 · Dégâts sorts +4 · Soins +11	c197:1
10018	hands	4	1	2	45	40	Gants rouges en tisse-mage	Int +10 · Puiss. sorts +11	c197:1
10019	hands	4	1	3	45	40	Gants en tisse-rêve	Int +4 · Esp +7 · Puiss. sorts +18	c197:1
10020	chest	4	1	2	45	40	Gilet en étoffe-tempête	End +8 · Esp +8 · Dégâts sorts +10 · Soins +58	c197:1
10021	chest	4	1	3	45	40	Gilet en tisse-rêve	Int +9 · Esp +14 · Puiss. sorts +18	c197:1
10023	hands	4	1	2	45	40	Gants en tisse-ombre	Int +5	c197:1
10024	head	4	1	2	46	41	Bandeau noir en tisse-mage	Int +12 · Puiss. sorts +13	c197:1
10025	head	4	1	2	49	44	Masque en tisse-ombre	Int +10	c197:1
10026	feet	4	1	2	46	41	Bottes noires en tisse-mage	Int +7 · Puiss. sorts +11	c197:1
10027	shoulder	4	1	2	46	41	Epaulières noires en tisse-mage	Int +9 · Puiss. sorts +10	c197:1
10028	shoulder	4	1	2	47	42	Epaulières en tisse-ombre	End +7	c197:1
10029	shoulder	4	1	2	47	42	Epaulières rouges en tisse-mage	Int +15 · Puiss. sorts +7	c197:1
10030	head	4	1	2	48	43	Bicorne d'amiral		c197:1
10031	feet	4	1	2	48	43	Bottes en tisse-ombre	Esp +10	c197:1
10032	head	4	1	2	48	43	Bandeau en étoffe-tempête	Int +10 · Esp +10 · Dégâts sorts +8 · Soins +24	c197:1
10033	head	4	1	2	48	43	Bandeau rouge en tisse-mage	Int +20 · Puiss. sorts +19	c197:1
10037	head	4	1	2	49	44	DEPRECATED		
10038	shoulder	4	1	2	49	44	Epaulières en étoffe-tempête	End +10 · Dégâts sorts +7 · Soins +22	c197:1
10039	feet	4	1	2	50	45	Bottes en étoffe-tempête	End +10 · Dégâts sorts +8 · Soins +24	c197:1
10041	head	4	1	3	50	45	Diadème en tisse-rêve	Int +10 · Esp +12 · Puiss. sorts +21	c197:1
10042	chest	4	1	2	45	40	Robe en étoffe cendrée		c197:1
10043	legs	4	1	2	31	0	Chausses pieuses	End +8 · Esp +7	
10044	feet	4	1	2	49	44	Bottes en étoffe cendrée		c197:1
10047	legs	4	1	2	15	10	Kilt simple	End +3 · Puiss. sorts +2	c197:1
10048	legs	4	1	2	19	14	Kilt coloré	Esp +5 · Puiss. sorts +5	c197:1
10049	one	2	15	2	25	0	Lame du diaboliste		
10143	chest	4	1	2	64	59	Robe de grand conseiller		
10249	back	4	1	2	61	56	Cape de maître		
10264	chest	4	2	2	65	60	Tunique d'aventurier		
10298	finger	4	0	2	30	25	Anneau de Gnomeregan		
10299	neck	4	0	2	31	26	Amulette de Gnomeregan		
10384	chest	4	4	2	65	60	Armure d'Hypérion		
10418	trinket	4	3	2	50	0	Insigne rougeoyant en mithril	Armure +100	
10421	chest	4	3	2	10	2	Haubergeon grossier en cuivre	End +1	c164:1
10423	legs	4	3	2	31	26	Jambières en bronze argenté	For +7 · End +6 · Esp +6	c164:1
10461	wrist	4	1	2	45	0	Brassards des ténèbres	Int +8 · Esp +4	
10462	waist	4	1	2	47	0	Ceinture des ténèbres	End +7 · Int +11 · Esp +4	
10499	head	4	1	2	35	0	Lunettes d'oeil brillant	End +9 · Esp +9	c202:1
10500	head	4	1	2	41	0	Lunettes de feu	Rés. feu +17	c202:1
10501	head	4	1	2	44	0	Lunettes d'oeil de chat		c202:1
10502	head	4	1	2	43	0	Lunettes de fortification des sorts	Puiss. sorts +21	c202:1
10503	head	4	1	2	46	0	Lunettes roses	Int +12 · Esp +13	c202:1
10504	head	4	1	3	49	0	Lentille verte	End +10	c202:1
10506	head	4	1	2	46	0	Casque de scaphandrier	End +4	c202:1
10508	ranged	2	3	2	41	36	Tromblon en mithril	Agi +7	c202:1
10510	ranged	2	3	2	44	39	Carabine de gros calibre en mithril	PA dist. +19	c202:1
10518	back	4	1	2	45	0	Cape parachute	Agi +8	c202:1
10542	head	4	3	2	41	0	Casque de mineur gobelin	End +15	c202:1
10543	head	4	1	2	41	0	Casque de chantier gobelin	Rés. feu +15	c202:1
10545	head	4	1	2	42	0	Lunettes gnomes	Agi +9 · End +9 · Esp +9	c202:1
10549	legs	4	1	2	12	0	Pantalon de Rancher	Esp +1 · Puiss. sorts +1	
10588	head	4	1	2	47	0	Heaume-fusée gobelin	End +15	c202:1
10637	hands	4	1	2	15	0	Gants de brasseur	For +2 · Int +2	
10638	back	4	1	2	15	0	Longue cape drapée	End +2	
10652	two	2	1	2	51	0	Volonté du géant des montagnes	For +15 · End +14	
10653	feet	4	2	2	30	0	Bottes Trailblazer	Agi +7 · End +3	
10654	hands	4	1	2	30	0	Gants en jute tressée	Int +5 · Puiss. sorts +6	
10659	trinket	4	0	2	57	0	Éclat des Sabots-Fendus	Mana/5 +6	
10686	off	4	6	2	55	0	Egide de guerre	Agi +6 · End +10	
10696	main	2	7	2	60	0	Epée Felbane en azsharite enchanté	PA +18	
10697	one	2	15	2	60	0	Dague Felbane en azsharite enchanté	PA +18	
10698	two	2	10	2	60	0	Bâton Felbane en azsharite enchanté	PA +40	
10700	feet	4	1	2	45	0	Bottes Encarmine	End +8 · Int +8 · Esp +4	
10701	feet	4	3	2	45	0	Bottes de Zua'tec	End +13 · Esp +2	
10702	feet	4	2	2	43	0	Enormes bottes d'ogre	For +9 · End +9	
10703	one	2	15	2	45	0	Dague démoniaque	For +8	
10704	ranged	2	19	2	46	0	Bâton Chillnail	Esp +8	
10705	wrist	4	1	2	47	0	Protège-poignets du saule épineux	Agi +2 · Int +10	
10706	waist	4	3	2	47	0	Ceinturon de la nuit	For +14 · End +2	
10707	feet	4	4	2	52	0	Bottes des forgeurs	For +11 · End +11	
10708	off	4	0	2	52	0	Orbe Crânesort	Int +12	
10709	off	4	0	2	55	0	Orbe funéraire	Esp +13	
10721	waist	4	2	2	43	0	Ceinture de prévention gnome	End +6	c202:1
10724	feet	4	1	2	45	0	Bottes-fusées gnomes		c202:1
10726	head	4	1	2	47	0	Coiffe de contrôle mental gnome	Esp +14	c202:1
10739	finger	4	0	2	53	0	Anneau de robustesse	End +10 · Esp +6	
10740	legs	4	4	2	53	0	Cuissards de centurion	For +15 · Agi +15	
10741	head	4	2	2	53	0	Casque de Lordrec	Agi +16 · End +10 · Esp +3	
10742	legs	4	1	2	51	0	Jambières des dragons	For +6 · Agi +13 · Esp +14	
10743	head	4	3	2	51	0	Protège-front drakefeu	For +5 · Int +9 · Esp +15	
10744	main	2	0	2	51	0	Hache du drake d'ébène	For +9	
10745	shoulder	4	2	2	50	0	Epaulières Kaylari	For +11 · End +10	
10746	wrist	4	4	2	50	0	Protège-bras d'acier runique	For +2 · End +11	
10747	waist	4	1	2	41	0	Echarpe de professeur	End +1 · Int +12	
10748	feet	4	2	2	41	0	Bottes des errants	For +5 · Agi +10	
10778	neck	4	0	2	60	0	Collier de sanctuaire	Rés. feu +10 · Rés. ombre +10	
10779	trinket	4	0	2	60	0	Sang de démon	Déf. +4 · Rés. ombre +15	
10820	waist	4	1	2	15	0	Ceinture Jackseed	Int +3	
10821	back	4	1	2	15	0	Cape de semeur	Esp +2	
10826	two	2	10	2	48	0	Bâton du savoir	Int +5 · Esp +18	
10827	chest	4	2	2	48	0	Tunique de géomètre	For +11 · Esp +15	
11120	main	2	4	2	55	0	Marteau de Belgrom	For +10	
11193	chest	4	2	2	57	0	Cuirasse des vents brûlants	For +3 · Agi +23 · End +5	
11194	chest	4	3	2	57	0	Haubert en écailles prismatiques	End +3 · Int +4 · Esp +23	
11195	chest	4	4	2	57	0	Pansière de guerre	For +24 · End +2	
11196	neck	4	0	2	57	0	Médaillon d'explosion mentale	Int +6 · Esp +5 · Puiss. sorts +6	
11229	waist	4	3	2	32	0	Ceinturon en écailles luisantes	For +6 · End +6	
11263	ranged	2	19	3	40	0	Baguette de force du Néant	Int +4	
11265	two	2	5	3	42	0	Maillet de Cragwood	End +24	
11287	ranged	2	19	2	15	5	Baguette magique inférieure	Puiss. sorts +1	c333:1
11288	ranged	2	19	2	23	13	Baguette magique supérieure	Puiss. sorts +3	c333:1
11289	ranged	2	19	2	31	26	Baguette mystique inférieure	Int +5	c333:1
11303	ranged	2	2	2	16	11	Bon arc court	Agi +2	
11304	ranged	2	2	2	19	14	Bon arc long	PA +4	
11305	ranged	2	2	2	35	30	Arc court dense	Déf. +5	
11306	ranged	2	2	2	32	27	Arc long solide	End +5	
11307	ranged	2	2	2	47	42	Arc long de puissance		
11308	ranged	2	2	2	49	44	Arc court sylvestre	Rés. nature +9	
11469	wrist	4	1	2	47	0	Brassards de bandelettes sanglantes	Int +9 · Esp +3 · Puiss. sorts +5	
11502	shoulder	4	2	2	46	0	Epaulières de connaissance en cuir	For +10 · Esp +9	
11604	chest	4	4	3	59	54	Harnois en sombrefer	End +12 · Armure +200 · Rés. feu +19	c164:1
11605	shoulder	4	4	2	58	53	Epaulières en sombrefer	End +10 · Armure +100 · Rés. feu +10	c164:1
11606	chest	4	3	2	56	51	Cotte de mailles en sombrefer	End +13 · Armure +130 · Rés. feu +12	c164:1
11607	two	2	1	3	57	52	Découpeuse en sombrefer		c164:1
11608	two	2	5	3	55	50	Pulvériseur en sombrefer		c164:1
11853	feet	4	2	2	18	0	Bottes de randonnée	Agi +3 · End +1	
11854	two	2	8	2	19	0	Tournevis Samophlange	Esp +6	
11855	off	4	0	2	19	0	Clé de Tork	For +2 · Int +2	
11856	one	2	15	2	45	0	Lame de cérémonie elfique	Agi +6 · End +3	
11857	two	2	10	2	46	0	Bâtonnet sanctifié	End +4 · Esp +17	
11858	back	4	1	2	45	0	Cape de briscard	End +8 · PA +10	
11859	off	4	0	2	45	0	Orbe de jadelune	End +3 · Int +4 · Esp +8	
11860	ranged	2	19	2	46	0	Bâtonnet d'éclair chargé	Int +5 · Puiss. sorts +6	
11861	waist	4	3	2	46	0	Ceinturon de représailles	For +12	
11862	finger	4	0	2	52	0	Anneau d'os blanc	PA +24	
11863	off	2	13	2	52	0	Griffes d'os blanc	For +4 · Agi +7	
11864	two	2	6	2	52	0	Lance d'os blanc	End +21 · Int +3	
11867	hands	4	3	2	53	0	Gantelets exaspérants	For +15 · Agi +5	
11868	finger	4	0	2	53	0	Anneau d'apnée	Esp +13	
11869	finger	4	0	2	53	0	Anneau de Sha'ni	End +10 · Esp +6	
11870	off	4	0	2	54	0	Orbe d'oubli	End +4 · Esp +11	
11871	shoulder	4	2	2	54	0	Spallières de Snarkshaw	For +12 · End +11	
11872	feet	4	4	2	54	0	Bottes d'Eschewal	End +11 · Esquive +12	
11873	back	4	1	2	56	0	Cape des brumes éthérées	Int +3 · Esp +12	
11874	shoulder	4	2	2	56	0	Mantelet des nuages	For +12 · Agi +12	
11875	wrist	4	1	2	54	0	Brassards de la brise	End +3 · Int +12	
11876	chest	4	2	2	56	0	Tunique de rôdeur des plaines	Agi +4 · End +23	
11882	legs	4	3	2	56	0	Jambières de voltigeur	For +16 · End +16	
11884	shoulder	4	1	2	33	0	Amict lunaires	End +7 · Puiss. sorts +7	
11888	hands	4	1	2	50	0	Gants de recherche de Quintis	Int +11 · Esp +10	
11889	shoulder	4	4	2	50	0	Espauliers en écorce de fer	For +11 · Agi +5 · Esp +8	
11905	trinket	4	0	2	56	0	Boomerang de Linken		
11906	main	2	4	2	55	0	Fracasse-bêtes	PA +16	
11907	two	2	1	2	55	0	Tranche-bêtes	PA +36	
11908	feet	4	1	2	55	0	Bottes de fouilles de l'Archéologue	Agi +9 · End +10 · Int +9	
11909	waist	4	2	2	55	0	Ceinture d'outils d'excavateur	End +4 · Int +16	
11910	legs	4	4	2	55	0	Jambières enchâssées	End +15 · Esp +8 · Esquive +12	
11911	legs	4	1	2	55	0	Jambières de la canopée	End +8 · Int +8 · Esp +18	
11913	head	4	3	2	55	0	Casque de Clayridge	Agi +16 · Esp +15	
11915	off	4	6	2	55	0	Bouclier de Shizzle	For +13 · End +1	
11916	shoulder	4	2	2	55	0	Culasse de Shizzle	For +6 · End +6 · Esp +12	
11917	wrist	4	1	2	55	0	Chiffon à tuyères de Shizzle	End +3 · Int +12 · Esp +3	
11918	hands	4	3	2	55	0	Gants de Grotslab	Agi +12 · Int +12	
11919	feet	4	4	2	55	0	Bottes de Cragplate	For +12 · End +12	
11936	waist	4	1	2	20	0	Ceinture de chasseur de reliques	For +2 · Int +4 · Esp +2	
11945	finger	4	0	2	53	48	Anneau en sombrefer		
11946	neck	4	0	2	52	47	Collier d'opale rougeoyante		
12018	head	4	3	3	54	0	Heaume de conservateur	End +22 · Esp +20	
12021	feet	4	4	3	54	0	Bottillons renforcés	For +12 · End +15 · Esp +9	
12041	legs	4	2	3	54	0	Jambières de Windshear	Agi +19 · End +5 · Esp +22	
12050	feet	4	1	2	54	0	Bottes de la brume	Agi +4 · End +8 · Esp +7	
12051	hands	4	3	2	54	0	Gantelets en laiton	For +12 · Agi +12 · End +2	
12102	finger	4	0	2	54	0	Anneau aristocratique	End +10 · Esp +6	
12104	chest	4	2	2	60	0	Tunique d'épines tavelées	End +22 · PA +20	
12105	legs	4	3	2	60	0	Jambières de fierté	Esp +13	
12106	chest	4	4	2	60	0	Cuirasse peau-de-roche	For +13 · Armure +200	
12107	legs	4	1	2	60	0	Jambières chuchotantes	Esp +20 · Puiss. sorts +15	
12185	head	4	5	3	60	0	Bicorne d'amiral de la Voile sanglante		
12247	one	2	15	2	32	27	Couteau à lame large	End +5	
12248	one	2	15	2	34	29	Miséricorde audacieuse	Agi +5	
12249	two	2	1	2	31	26	Hache impitoyable	For +12	
12250	two	2	1	2	34	29	Hache de minuit		
12251	two	2	10	2	37	32	Grand bâton	For +15	
12252	two	2	10	2	39	34	Bâton de protection	Armure +100	
12253	back	4	1	2	41	36	Cape rouge brillante	End +9	
12254	back	4	1	2	44	39	Cape bien huilée	End +10	
12255	legs	4	1	2	46	41	Jambières pâles	Int +13 · Esp +12	
12256	legs	4	1	2	49	44	Jambières en étoffe cendrée	Esp +15	
12257	waist	4	3	2	42	37	Ceinture lourde abimée	For +10 · End +6	
12258	waist	4	3	2	44	39	Ceinture à boucle serpentine	Crit. +14	
12259	one	2	15	2	36	31	Dague d'acier luisante	PA +12	c164:1
12260	one	2	15	2	39	34	Lame dorée flamboyante	Int +7	c164:1
12295	legs	4	1	2	15	0	Jambières de la milice du peuple	For +2 · Puiss. sorts +2	
12296	ranged	2	19	2	17	0	Eclat de la milice du peuple	Puiss. sorts +2	
12405	chest	4	4	2	50	45	Armure en thorium	End +15 · Rés. feu +8 · Rés. givre +8 · Rés. nature +8 · Rés. ombre +8	c164:1
12406	waist	4	4	2	50	45	Ceinture en thorium	End +12 · Rés. feu +6 · Rés. givre +6 · Rés. nature +6 · Rés. ombre +6	c164:1
12408	wrist	4	4	2	51	46	Brassards en thorium	End +8 · Rés. feu +5 · Rés. givre +5 · Rés. nature +5 · Rés. ombre +5	c164:1
12409	feet	4	4	2	56	51	Bottes en thorium	Rés. feu +7 · Rés. givre +7 · Rés. nature +7 · Rés. ombre +7 · Rés. arcanes +7	c164:1
12410	head	4	4	2	56	51	Heaume en thorium	End +18 · Rés. feu +10 · Rés. givre +10 · Rés. nature +10 · Rés. ombre +10	c164:1
12414	legs	4	4	2	60	55	Jambières en thorium	End +19 · Rés. feu +10 · Rés. givre +10 · Rés. nature +10 · Rés. ombre +10	c164:1
12415	chest	4	3	2	54	49	Cuirasse radieuse	Rés. givre +16 · Rés. ombre +16	c164:1
12416	waist	4	3	2	52	47	Ceinture radieuse	End +7 · Rés. givre +12 · Rés. ombre +12	c164:1
12417	head	4	3	2	59	54	Diadème radieux	End +9 · Rés. givre +18 · Rés. ombre +18	c164:1
12418	hands	4	3	2	57	52	Gantelets radieux	End +9 · Rés. givre +12 · Rés. ombre +12	c164:1
12419	feet	4	3	2	58	53	Bottes radieuses	End +9 · Rés. givre +15 · Rés. ombre +15	c164:1
12420	legs	4	3	2	61	56	Jambières radieuses	End +12 · Rés. givre +18 · Rés. ombre +18	c164:1
12422	chest	4	4	2	60	55	Pansière impériale	For +18 · End +17	c164:1
12424	waist	4	4	2	53	47	Ceinture impériale en plaques	For +12 · End +11	c164:1
12425	wrist	4	4	2	54	49	Brassards impériaux en plaques	For +9 · End +8	c164:1
12426	feet	4	4	2	59	54	Bottes impériales en plaques	For +13 · End +12	c164:1
12427	head	4	4	2	59	54	Heaume impérial en plaques	For +18 · End +17	c164:1
12428	shoulder	4	4	2	53	47	Epaulières impériales en plaques	For +12 · End +11	c164:1
12429	legs	4	4	2	61	56	Jambières impériales en plaques	For +18 · End +18	c164:1
12522	hands	4	2	2	15	0	Gants de vol de Bingles	Agi +2 · Int +2	q2038
12584	one	2	7	4	78	60	Epée longue de connétable	End +7 · PA +28 · Crit. +14	
12610	shoulder	4	4	2	60	55	Epaulières runiques en plaques	End +14 · Rés. feu +10 · Rés. nature +10	c164:1
12611	feet	4	4	2	60	55	Bottes runiques en plaques	End +14 · Rés. feu +10 · Rés. nature +10	c164:1
12612	head	4	4	2	61	56	Heaume runique en plaques	End +19 · Rés. feu +14 · Rés. nature +14	c164:1
12613	chest	4	4	2	62	57	Cuirasse runique	End +18 · Rés. feu +15 · Rés. nature +15	c164:1
12614	legs	4	4	2	62	57	Jambières runiques en plaques	End +19 · Rés. feu +14 · Rés. nature +14	c164:1
12615	chest	4	3	2	62	57	Tunique en mailles sauvages	For +27	
12616	feet	4	3	2	63	58	Bottes en mailles sauvages	For +13 · End +15	
12617	shoulder	4	3	2	63	58	Epaulières en mailles sauvages	For +10 · End +17	
12618	chest	4	4	3	63	58	Cuirasse en thorium enchanté	For +12 · End +26 · Déf. +9	c164:1
12619	legs	4	4	3	63	58	Jambières en thorium enchanté	For +20 · End +21 · Déf. +8	c164:1
12620	head	4	4	3	62	57	Heaume en thorium enchanté	For +12 · End +25 · Déf. +9	c164:1
12624	chest	4	3	3	54	49	Cotte de mailles Ronce-sauvage	End +5 · Puiss. sorts +11 · Toucher +10	c165:1
12625	shoulder	4	4	3	58	53	Epaulières du point du jour	Esp +10 · Dégâts sorts +15 · Soins +44	c164:1
12631	hands	4	4	3	58	53	Gantelets en plaques de feu	Rés. feu +10	c164:1
12632	hands	4	3	3	59	54	Gantelets tempêtes	End +7 · Puiss. sorts +18 · Toucher +10	c165:1
12633	head	4	4	3	60	55	Heaume d'âme blanche	Int +15 · Esp +15 · Dégâts sorts +12 · Soins +35 · Armure +120	c164:1
12636	head	4	3	3	61	56	Heaume du grand chef	Esp +12 · Dégâts sorts +15 · Soins +30	c165:1
12639	hands	4	4	4	62	57	Gantelets de la forteresse	End +18 · Crit. +14	c164:1
12640	head	4	4	4	61	56	Heaume Coeur-de-lion	For +18 · Crit. +28 · Toucher +20	c164:1
12641	chest	4	3	4	63	57	Cotte de mailles invulnérable	End +20	c165:1
12764	two	2	8	2	52	47	Epée de guerre en thorium	For +22	c164:1
12769	two	2	1	3	54	49	Bois morne taillé	For +11 · End +5	c164:1
12772	two	2	5	2	54	49	Marteau damasquiné en thorium	For +23	c164:1
12773	one	2	0	2	55	50	Hachette ornée en thorium	For +10	c164:1
12774	one	2	0	3	55	50	Courroux de l'aube	Crit. +14	c164:1
12775	two	2	1	2	56	51	Grande hache en thorium		c164:1
12776	two	2	5	3	56	51	Marteau de guerre enchanté	Toucher +20 · Rés. arcanes +4	c164:1
12777	one	2	7	3	56	51	Rapière flamboyante		c164:1
12781	one	2	4	3	57	52	Sérénité		c164:1
12782	two	2	8	3	58	53	Corruption	For +30 · End +30	c164:1
12783	one	2	15	3	63	58	Crève-coeur	Agi +4 · Crit. +14	c164:1
12784	two	2	1	3	63	58	Déchireuse en arcanite	End +13 · PA +62	c164:1
12790	two	2	8	3	63	58	Championne en arcanite		c164:1
12792	one	2	4	2	58	53	Marteau volcanique		c164:1
12794	one	2	4	3	63	57	Marteau-tempête ouvragé		c164:1
12795	main	2	13	3	60	55	Serre de sang		c164:1
12796	two	2	5	3	63	58	Marteau des Titans	For +15	c164:1
12797	one	2	7	3	63	58	Gardienne de givre		c164:1
12798	one	2	0	3	63	58	Annihilateur	PA +14	c164:1
12802	two	2	6	3	60	55	Lance noire		c164:1
12805	trinket	4	0	2	46	0	Orbe de feu		
12904	head	4	1	2	61	61	Chapeau pandit super spécial de Shawn		
12947	finger	4	0	6	60	0	Anneau audacieux d'Alex	Déf. +1000	
12970	chest	4	4	3	63	58	Harnois de cérémonie de général	End +30 · Armure +140	
12976	one	2	7	3	20	15	Lame Ironpatch	For +4 · End +2	
12990	one	2	0	3	23	18	Lacératrice	For +4 · Esp +2	
13080	chest	4	1	3	63	58	Caresse de la Veuve	End +10 · Int +24 · Esp +15 · Rés. arcanes +13	
13090	chest	4	3	3	63	58	Plastron de l'élu	For +14 · Agi +14 · End +14 · Int +14 · Esp +14	
13092	chest	4	2	3	63	58	[PÉRIMÉ] Tunique pendragonne	Int +25 · Esp +12 · Puiss. sorts +18	
13164	trinket	4	0	3	61	56	Coeur de l'Ecaille		
13242	feet	4	2	2	60	55	[PÉRIMÉ] Bottes de Stormrage	Soins +22	
13262	two	2	8	5	76	60	Porte-cendres		
13371	off	4	0	2	58	0	Père des flammes	Rés. feu +10	
13473	neck	4	0	2	54	0	Porte-bonheur de Felstone	Rés. ombre +13	
13474	ranged	2	3	2	56	0	Fusil du fermier Dalson	End +10	
13475	finger	4	0	2	55	0	Alliance de la famille Dalson	End +13	
13503	trinket	4	0	2	50	45	Pierre des alchimistes	Esp +4	c171:1
13811	neck	4	0	2	60	0	Collier de l'Aube	End +15	
13812	finger	4	0	2	58	0	Anneau de l'Aube	End +14	
13856	waist	4	1	2	51	46	Ceinture en étoffe runique	Int +12 · Puiss. sorts +8	c197:1
13857	chest	4	1	2	52	47	Tunique en étoffe runique	Int +11 · Puiss. sorts +17	c197:1
13858	chest	4	1	2	52	47	Robe en étoffe runique	Int +17 · Puiss. sorts +11	c197:1
13860	back	4	1	2	53	48	Cape en étoffe runique	Int +8 · Puiss. sorts +9	c197:1
13863	hands	4	1	2	55	50	Gants en étoffe runique	Int +9 · Esp +9 · Puiss. sorts +12	c197:1
13864	feet	4	1	2	56	51	Bottes en étoffe runique	Esp +14 · Puiss. sorts +11	c197:1
13865	legs	4	1	2	57	52	Pantalon en étoffe runique	Esp +20 · Puiss. sorts +14	c197:1
13866	head	4	1	2	59	54	Bandeau en étoffe runique	Int +20 · Puiss. sorts +15	c197:1
13867	shoulder	4	1	2	61	56	Epaulières en étoffe runique	Int +15 · Puiss. sorts +12	c197:1
13868	chest	4	1	2	51	46	Robe tisse-givre	Esp +11	c197:1
13869	chest	4	1	2	51	46	Tunique tisse-givre	Int +11	c197:1
13870	hands	4	1	2	53	47	Gants tisse-givre	Int +6	c197:1
13871	legs	4	1	2	56	51	Pantalon tisse-givre	Esp +12	c197:1
13936	head	4	1	3	62	57	[PÉRIMÉ] Voile du maître de l'effroi	Int +20 · Esp +13 · Puiss. sorts +23	
14042	chest	4	1	2	52	47	Gilet en étoffe cendrée	Esp +11	c197:1
14043	hands	4	1	2	54	49	Gants en étoffe cendrée	Esp +11	c197:1
14044	back	4	1	2	55	50	Cape en étoffe cendrée	Int +8	c197:1
14045	legs	4	1	2	56	51	Pantalon en étoffe cendrée	Int +12	c197:1
14100	chest	4	1	2	54	49	Robe en étoffe lumineuse	Puiss. sorts +18 · Rés. givre +16 · Rés. ombre +16	c197:1
14101	hands	4	1	2	54	49	Gants en étoffe lumineuse	Puiss. sorts +13 · Rés. givre +12 · Rés. ombre +12	c197:1
14103	back	4	1	2	55	50	Cape en étoffe lumineuse	Rés. givre +7 · Rés. ombre +7	c197:1
14104	legs	4	1	2	58	53	Pantalon en étoffe lumineuse	Puiss. sorts +19 · Rés. givre +17 · Rés. ombre +17	c197:1
14106	chest	4	1	2	61	56	Robe en gangrétoffe	End +7	c197:1
14107	legs	4	1	2	55	50	Pantalon en gangrétoffe	Int +12	c197:1
14108	feet	4	1	2	57	52	Bottes en gangrétoffe	Esp +12	c197:1
14111	head	4	1	2	58	53	Chaperon en gangrétoffe	Int +10	c197:1
14112	shoulder	4	1	2	62	57	Epaulières en gangrétoffe	Esp +5	c197:1
14128	chest	4	1	2	60	55	Robe en tisse-sorcier	Puiss. sorts +20 · Rés. feu +18 · Rés. arcanes +18	c197:1
14130	head	4	1	2	61	56	Turban en tisse-sorcier	Puiss. sorts +21 · Rés. feu +18 · Rés. arcanes +18	c197:1
14132	legs	4	1	2	55	50	Jambières en tisse-sorcier	Puiss. sorts +19 · Rés. feu +16 · Rés. arcanes +16	c197:1
14134	back	4	1	3	55	50	Cape de feu	Rés. feu +6	c197:1
14136	chest	4	1	3	57	52	Robe de la nuit hivernale	Int +12	c197:1
14137	legs	4	1	3	58	53	Jambières en étoffe lunaire	End +12 · Esp +21 · Dégâts sorts +11 · Soins +31	c197:1
14138	chest	4	1	3	60	55	Gilet en étoffe lunaire	Int +20 · Esp +19 · Dégâts sorts +9 · Soins +26	c197:1
14139	shoulder	4	1	3	61	56	Epaulières en étoffe lunaire	End +9 · Esp +11 · Dégâts sorts +13 · Soins +37	c197:1
14140	head	4	1	3	62	57	Diadème en étoffe lunaire	End +13 · Esp +15 · Dégâts sorts +17 · Soins +51	c197:1
14141	chest	4	1	2	55	50	Gilet en tisse-fantôme	Esp +20 · Puiss. sorts +9 · Mana/5 +8	c197:1
14142	hands	4	1	2	54	49	Gants en tisse-fantôme	Esp +15 · Puiss. sorts +9	c197:1
14143	waist	4	1	2	53	48	Ceinture en tisse-fantôme	Esp +9 · Puiss. sorts +8	c197:1
14144	legs	4	1	2	58	53	Pantalon en tisse-fantôme	Esp +20 · Puiss. sorts +26	c197:1
14146	hands	4	1	4	62	57	Gants de maîtrise magique	Int +10 · Puiss. sorts +9 · Crit. +28	c197:1
14152	chest	4	1	4	62	57	Robe de l'archimage	Int +12 · Puiss. sorts +40 · Crit. +14	c197:1
14153	chest	4	1	4	62	57	Robe du Vide	End +10 · Int +9 · Puiss. sorts +46	c197:1
14154	chest	4	1	4	62	57	Habit de vraie foi	End +14 · Esp +16 · Dégâts sorts +25 · Soins +73	c197:1
14158	chest	4	1	2	26	21	Gilet païen		
14363	legs	4	1	2	16	11	[PÉRIMÉ] Chausses en étoffe runique	Agi +3 · Esp +2	
14389	shoulder	4	1	3	1	0	Protège-épaules endurants		
14550	wrist	4	2	4	49	44	Garde-bras plaie-des-lames	For +6 · Agi +10 · End +10 · Esp +8	
14597	off	4	6	2	41	36	[PÉRIMÉ] Targe du Gardien	End +4 · Esp +7	
14609	off	4	6	2	17	12	[PÉRIMÉ] Targe de cérémonie	For +1 · Int +2	
14652	waist	4	2	2	45	40	Echarpe scorpashi	For +4 · Agi +10 · End +7	
14661	waist	4	2	2	49	44	Corde de vigilant	For +6 · Int +7 · Esp +9	
14674	waist	4	2	2	55	50	Ceinturon du seigneur de la harde	For +4 · Agi +12 · End +8	
14727	legs	4	3	2	19	14	Jambières aux peintures de guerre	For +3 · Agi +1 · End +4	
14864	waist	4	4	2	59	54	Ceinture de chef de guerre	For +6 · End +10 · Esp +6	
15045	chest	4	3	3	52	47	Cuirasse en écailles de dragon vert	End +10 · Dégâts sorts +21 · Soins +10 · Rés. nature +11	c165:1
15046	legs	4	3	3	54	49	Jambières en écailles de dragon vert	End +10 · Dégâts sorts +17 · Soins +22 · Rés. nature +11	c165:1
15047	chest	4	3	3	61	56	Cuirasse en écailles de dragon rouge	Dégâts sorts +19 · Soins +57 · Rés. feu +20	c165:1
15048	chest	4	3	3	57	52	Cuirasse en écailles de dragon bleu	Int +28 · Puiss. sorts +8 · Rés. arcanes +8	c165:1
15049	shoulder	4	3	3	59	54	Epaulières en écailles de dragon bleu	Int +21 · Puiss. sorts +6 · Rés. arcanes +6	c165:1
15050	chest	4	3	3	58	53	Cuirasse en écailles de dragon noir	End +8 · PA +50 · Rés. feu +12	c165:1
15051	shoulder	4	3	3	60	55	Epaulières en écailles de dragon noir	End +9 · PA +40 · Rés. feu +6	c165:1
15052	legs	4	3	3	62	57	Jambières en écailles de dragon noir	End +8 · PA +54 · Rés. feu +13	c165:1
15053	chest	4	2	2	57	52	Cuirasse volcanique	End +11 · Rés. feu +20	c165:1
15054	legs	4	2	2	54	49	Jambières volcaniques	End +10 · Rés. feu +20	c165:1
15055	shoulder	4	2	2	61	56	Epaulières volcaniques	End +4 · Rés. givre +13	c165:1
15056	chest	4	2	3	57	52	Armure tempétueuse	Crit. +28 · Esquive +12	c165:1
15057	legs	4	2	3	55	50	Pantalon tempétueux	Crit. +28 · Esquive +12	c165:1
15058	shoulder	4	2	3	59	54	Epaulières tempétueuses	End +12 · Crit. +14 · Esquive +12	c165:1
15059	chest	4	2	3	60	55	Cuirasse vivante	End +10 · Esp +25 · Dégâts sorts +9 · Soins +26 · Rés. nature +5	c165:1
15060	legs	4	2	3	57	52	Jambières vivantes	End +8 · Esp +25 · Dégâts sorts +9 · Soins +26 · Rés. nature +5	c165:1
15061	shoulder	4	2	3	54	49	Epaulières vivantes	End +8 · Esp +13 · Dégâts sorts +10 · Soins +31 · Rés. nature +3	c165:1
15062	legs	4	2	3	60	55	Jambières diablosaures	End +12 · PA +46 · Crit. +14	c165:1
15063	hands	4	2	3	58	53	Gantelets diablosaures	End +9 · PA +28 · Crit. +14	c165:1
15064	chest	4	2	3	55	50	Harnais de l'ours de guerre	For +11 · Agi +18 · End +27	c165:1
15065	legs	4	2	3	57	52	Jambières de l'ours de guerre	For +28 · Agi +18 · End +12	c165:1
15066	chest	4	2	3	58	53	Cuirasse en plumacier	Int +12 · Esp +28 · Puiss. sorts +21	c165:1
15067	shoulder	4	2	3	54	49	Epaulières en plumacier	Int +20 · Esp +8 · Puiss. sorts +15	c165:1
15068	chest	4	2	2	62	57	Tunique de sabre-de-givre	End +12 · Rés. givre +18 · Rés. ombre +18	c165:1
15069	legs	4	2	2	57	52	Jambières de sabre-de-givre	End +11 · Rés. feu +17 · Rés. ombre +17	c165:1
15070	hands	4	2	2	59	54	Gants de sabre-de-givre	End +7 · Rés. givre +13 · Rés. ombre +13	c165:1
15071	feet	4	2	2	55	50	Bottes de sabre-de-givre	End +9 · Rés. feu +12 · Rés. ombre +12	c165:1
15072	legs	4	2	2	56	51	Jambières chimériques	End +11 · Rés. nature +16 · Rés. arcanes +16	c165:1
15073	feet	4	2	2	55	50	Bottes chimériques	End +9 · Rés. nature +12 · Rés. arcanes +12	c165:1
15074	hands	4	2	2	53	48	Gants chimériques	End +8 · Rés. nature +12 · Rés. arcanes +12	c165:1
15075	chest	4	2	2	58	53	Gilet chimérique	End +11 · Rés. nature +17 · Rés. arcanes +17	c165:1
15076	chest	4	3	2	53	48	Broigne en écailles de scorpide épaisses	Agi +15 · End +16	c165:1
15077	wrist	4	3	2	51	46	Brassards en écailles de scorpide épaisses	Agi +8 · End +8	c165:1
15078	hands	4	3	2	55	50	Gantelets en écailles de scorpide épaisses	Agi +12 · End +12	c165:1
15079	legs	4	3	2	57	52	Jambières en écailles de scorpide épaisses	Agi +20 · End +12	c165:1
15080	head	4	3	2	59	54	Casque en écailles de scorpide épaisses	Agi +13 · End +20	c165:1
15081	shoulder	4	3	2	61	56	Epaulières en écailles de scorpide épaisses	Agi +13 · End +14	c165:1
15082	waist	4	3	2	56	51	Ceinture en écailles de scorpide épaisses	Agi +12 · End +12	c165:1
15083	hands	4	2	2	52	47	Gantelets corrompus en cuir	Agi +12 · End +11	c165:1
15084	wrist	4	2	2	53	48	Brassards corrompus en cuir	Agi +11 · End +5	c165:1
15085	chest	4	2	2	61	56	Armure corrompue en cuir	Agi +25 · End +7	c165:1
15086	head	4	2	2	56	51	Bandeau corrompu en cuir	Agi +16 · End +16	c165:1
15087	legs	4	2	2	58	53	Pantalon corrompu en cuir	Agi +20 · End +12	c165:1
15088	waist	4	2	2	60	55	Ceinture corrompue en cuir	Agi +14 · End +13	c165:1
15090	chest	4	2	2	62	57	Armure runique en cuir	Int +21 · Puiss. sorts +13	c165:1
15091	hands	4	2	2	54	49	Gantelets runiques en cuir	Int +8 · Puiss. sorts +14	c165:1
15092	wrist	4	2	2	55	50	Brassards runiques en cuir	Int +10 · Puiss. sorts +10	c165:1
15093	waist	4	2	2	56	51	Ceinture runique en cuir	Int +14 · Puiss. sorts +9	c165:1
15094	head	4	2	2	58	53	Bandeau runique en cuir	Int +20 · Puiss. sorts +12	c165:1
15095	legs	4	2	2	60	55	Pantalon runique en cuir	Int +13 · Puiss. sorts +20	c165:1
15096	shoulder	4	2	2	62	57	Epaulières runiques en cuir	Int +15 · Puiss. sorts +10	c165:1
15104	feet	4	1	2	39	0	Bottes des ailés	Esp +10 · Puiss. sorts +6	
15105	two	2	10	2	40	0	Bâton de Noh'Orahil	End +3 · Int +4 · Crit. +14	
15106	two	2	10	2	40	0	Bâton de Dar'Orahil	End +3 · Int +11 · Toucher +10	
15107	off	4	0	3	40	0	Orbe de Noh'Orahil	Int +5	
15108	off	4	0	3	40	0	Orbe de Dar'Orahil	Int +5	
15109	two	2	10	3	25	0	Bâton de Soran'ruk	End +14	
15138	back	4	1	3	60	55	Cape en écailles d'Onyxia	End +7 · Rés. feu +16	c165:1
15141	chest	4	3	4	62	57	Cuirasse en écailles d'Onyxia	For +15 · Agi +15 · End +15 · Int +14 · Esp +14	c165:1
15180	waist	4	2	2	53	48	Ceinturon prétorien		
15200	neck	4	0	3	35	30	Insigne de sergent-chef	End +9 · Esp +4	
15202	legs	4	2	2	18	0	Jambières de gardien de fauves	Agi +4 · End +1 · Esp +2	
15203	legs	4	3	2	18	0	Jambières de Guststorm	For +3 · End +3 · Esp +1	
15204	ranged	2	19	2	18	0	Baguette en pierre de lune	Int +2	
15205	ranged	2	3	2	20	0	Carabine œil-de-chouette	Agi +3	
15206	off	4	0	2	20	0	Bâton Jadefinger	End +2 · Esp +2	
15207	off	4	6	2	20	0	Bouclier de renforcement	For +2 · End +2	
15211	one	2	7	2	22	17	Epée courte militante		
15224	one	2	4	2	25	20	Ecrasante		
15324	ranged	2	3	2	56	51	Carabine brûle-flanc		
15335	one	2	7	2	14	0	Epée courte de Briarsteel	End +1	
15388	waist	4	2	2	52	47	Ceinture Jadefeu		
15396	one	2	15	2	14	0	Dague de Curvewood	End +1	
15397	two	2	10	2	14	0	Bâton d'Oakthrush	End +2 · Int +2	
15399	waist	4	2	2	14	0	Ceinture d'herbe-sèche	Int +2	
15401	hands	4	1	2	14	0	Gants goutte-de-puits	Int +2	
15402	hands	4	3	2	14	0	Gantelets du collet	For +2	
15403	wrist	4	2	2	18	0	Brassards de la dorsale	End +2 · Esp +2	
15404	waist	4	3	2	18	0	Ceinturon des brisants	Agi +2 · End +3	
15405	hands	4	2	2	17	0	Gants d'écailleur	End +2 · Int +2	
15406	feet	4	3	2	17	0	Bottes crustacéennes	End +3	
15455	chest	4	1	2	37	0	Robe Poussière-d'automne	End +8 · Puiss. sorts +13	
15456	legs	4	2	2	37	0	Jambières du pas léger	Agi +13 · End +5	
15457	shoulder	4	1	2	28	0	Epaulières du désert	Int +5 · Esp +5	
15458	feet	4	2	2	28	0	Bottes de la toundra	End +2 · Int +6 · Esp +3	
15459	wrist	4	3	2	28	0	Garde-poignets de dur-labeur	For +5 · Agi +1 · End +2	
15461	feet	4	1	2	25	0	Bottes du pas rapide	Int +4 · Esp +4	
15462	wrist	4	2	2	25	0	Brassards du terreau	Agi +5	
15463	hands	4	3	2	25	0	Gants du trotteur solitaire	For +5 · End +2	
15464	two	2	5	2	28	0	Marteau brutal	For +4 · Agi +1 · End +8	
15465	ranged	2	19	2	28	0	Baguette du dard	End +3 · Int +3	
15466	off	4	6	2	28	0	Bouclier résonnant	For +3 · Agi +2 · End +4	
15467	finger	4	0	2	31	0	Anneau de la Ligue des Inventeurs	End +4 · Esp +4	
15468	back	4	1	2	29	0	Drapé chantevent	Esp +4 · Puiss. sorts +5	
15469	waist	4	2	2	29	0	Cordelière Windsong	End +5 · PA +12	
15470	legs	4	3	2	29	0	Jambières du Garde des plaines	For +7 · End +8	
15471	chest	4	2	2	29	0	Armure de peau coriace	Agi +4 · End +9 · Esp +3	
15585	hands	4	1	2	35	0	Poignes de Pardoc	End +5 · Esp +8	
15587	waist	4	2	2	35	0	Ceinturon de Ringtail	End +5 · PA +16	
15588	waist	4	3	2	35	0	Ceinture d'acier armé	For +4 · Agi +4 · End +7	
15689	finger	4	0	2	35	0	Anneau des marchands	End +8	
15690	neck	4	0	2	41	0	Collier en os de kodo	End +7 · Esp +4	
15691	ranged	2	3	2	38	0	Pétoire de flanqueur	For +4 · Agi +4	
15692	ranged	2	19	2	38	0	Marqueur de kodo	End +4 · Puiss. sorts +5	
15695	off	4	6	2	38	0	Bouclier riveté	For +6 · End +4	
15697	feet	4	1	2	38	0	Bottes de voleur de kodo	End +3 · Int +8 · Esp +5	
15698	shoulder	4	3	2	38	0	Spallières de renforcement	For +8 · Agi +2 · End +6	
15702	finger	4	0	2	55	0	Anneau des chimistes	End +4 · Int +10 · Esp +4	
15703	back	4	1	2	55	0	Blouse de chimiste	Agi +3 · End +12	
15704	neck	4	0	2	60	0	Médaille des chasseurs	End +15	
15705	one	2	7	2	57	0	Epée Tidecrest	For +8 · Esp +5	
15706	one	2	15	2	57	0	Dague de poursuite	Agi +8 · Esp +5	
15707	waist	4	1	2	58	0	Echarpe de Brantwood	End +9 · Int +10 · Esp +10	
15708	hands	4	2	2	58	0	Gants en cuir chancreux	For +8 · Agi +13 · End +8	
15709	waist	4	4	2	58	0	Ceinturon de Gearforge	For +16 · Agi +4 · End +5	
15782	one	2	7	2	60	0	Lame de bestiaire	PA +18	
15783	one	2	15	2	60	0	Dague du chasseur de bête	PA +18	
15784	shoulder	4	1	2	59	0	Mantelet de la brise cristalline	End +12 · Esp +13	
15786	chest	4	2	2	59	0	Pourpoint de veine-fougère	End +5 · Int +8 · Puiss. sorts +26	
15787	chest	4	3	2	59	0	Haubert du saule	Agi +20 · End +10 · Int +6	
15789	back	4	1	2	56	0	Cape du fleuve profond	Agi +11 · End +7	
15791	waist	4	1	2	58	0	Echarpe turquoise	Agi +6 · Int +15 · Esp +6	
15792	shoulder	4	2	2	58	0	Spallières du laboureur	End +6 · Int +15 · Esp +6	
15795	hands	4	4	2	58	0	Gantelets de la brume émeraude	For +12 · End +13	
15796	wrist	4	3	2	59	0	Brassards d'écume	End +12 · Int +4	
15797	wrist	4	4	2	59	0	Plates de bras scintillantes	For +2 · End +13	
15799	neck	4	0	2	58	0	Médaille de valeur héroïque	End +12 · Esp +5	
15800	one	2	7	2	58	0	Epée courte intrépide	End +11	
15801	main	2	7	2	58	0	Epée courte vaillante	Int +11	
15802	feet	4	1	3	56	51	Bottes en étoffe lunaire	Int +14 · Esp +13 · Dégâts sorts +8 · Soins +24	c197:1
15804	back	4	1	2	56	0	Drapé cerise	Agi +6 · End +7 · Int +6 · Esp +6	
15812	shoulder	4	1	2	56	0	Amict de l'orchidée	For +4 · End +4 · Int +15 · Esp +3	
15813	waist	4	3	2	56	0	Ceinture tressée d'or	End +12 · Int +12	
15814	one	2	7	2	60	0	Pourfendeuse d'Hameya		
15815	back	4	1	2	60	0	Cape d'Hameya	Rés. arcanes +15	
15822	shoulder	4	2	2	55	0	Spallières en peau d'ombre	Agi +18	
15823	hands	4	3	2	55	0	Gantelets brique-d'acier	For +18	
15855	finger	4	0	3	60	0	Anneau de protection	End +9 · Armure +150	
15856	neck	4	0	3	60	0	Talisman de grande lumière	End +8 · Int +10 · Puiss. sorts +12	
15857	off	4	0	3	60	0	Baguette de résistance magique	Rés. feu +10 · Rés. givre +10 · Rés. arcanes +10	
15862	one	2	0	2	54	0	Foudroyante	PA +20	
15863	main	2	4	2	54	0	Sceptre des tombes	Int +8 · Esp +5	
15864	wrist	4	1	2	39	0	Brassards du condor	End +6 · Puiss. sorts +7	
15865	off	4	6	2	39	0	Targe d'Anchorhold	Int +6 · Puiss. sorts +5	
15866	off	4	0	2	15	0	Sac médecine de voile-poussière	Int +1 · Esp +1	
15888	off	4	6	2	60	55	[PÉRIMÉ] Bouclier glorieux		
15889	off	4	6	2	57	52	[PÉRIMÉ] Bouclier de Jademir en écailles		
15912	off	4	0	2	23	18	Orbe de boucanier		
15918	off	4	0	2	38	33	Sphère d'invocateur		
15925	off	4	0	2	10	5	Bâton de compagnon	End +1	
15926	off	4	0	2	17	12	Orbe de lieur de sort	Int +3	
15927	off	4	0	2	27	22	Sphère éclatante	Int +4 · Esp +2	
15928	off	4	0	2	31	26	Bâtonnet broché d'argent	End +3 · Esp +5	
15929	off	4	0	2	37	32	Orbe nocturne	End +2 · Int +6 · Esp +3	
15930	off	4	0	2	56	51	Sceptre impérial rouge	Agi +2 · End +4 · Int +12	
15931	off	4	0	2	61	56	Etoile des arcanes	End +5 · Int +10 · Esp +8	
15932	off	4	0	2	12	7	Chope de disciple		
15933	off	4	0	2	15	10	Branche simple		
15934	off	4	0	2	32	27	Bâton de sage		
15935	off	4	0	2	34	29	Bâtonnet solide		
15936	off	4	0	2	55	50	Branche tissée de crépuscule		
15937	off	4	0	2	51	46	Sphère hivernale	Esp +12	
15938	off	4	0	2	58	53	Orbe mystique		
15939	off	4	0	2	59	54	Sceptre de conseiller		
15940	off	4	0	2	62	57	Sceptre élégant		
15941	off	4	0	2	64	59	Sceptre de grand conseiller		
15942	off	4	0	2	65	60	Bâtonnet de maître		
15944	off	4	0	2	12	7	Orbe ancestral	Int +1	
15945	off	4	0	2	18	13	Baguette runique	End +2 · Esp +2	
15946	off	4	0	2	23	18	Sphère de mystique	End +2 · Esp +3	
15947	off	4	0	2	28	23	Etoile sanguine	End +4 · Esp +4	
15962	off	4	0	2	33	28	Bâtonnet du satyre	Agi +1 · Int +6 · Esp +2	
15963	off	4	0	2	39	34	Branche étoffe-de-pierre	For +3 · End +8	
15964	off	4	0	2	44	39	Etoile Sable-soie	End +2 · Esp +9	
15966	off	4	0	2	54	49	Orbe du voile vénéneux	End +5 · Esp +10 · Rés. nature +3	
15967	off	4	0	2	59	54	Etoile de bien-né	Agi +3 · End +6 · Int +11	
15968	off	4	0	2	64	59	Sphère élunarienne	Agi +2 · End +3 · Int +14	
15969	off	4	0	2	10	5	Orbe perlé		
15970	off	4	0	2	15	10	Branche indigène		
15971	off	4	0	2	20	15	Bâtonnet aborigène		
15972	off	4	0	2	24	19	Chope rituelle		
15973	off	4	0	2	30	25	Etoile de gardien		
15974	off	4	0	2	26	21	Bâtonnet païen		
15975	off	4	0	2	31	26	Sceptre d'invocateur de pluie		
15976	off	4	0	2	36	31	Branche crin-de-chardon		
15977	off	4	0	2	37	32	Orbe vital		
15978	off	4	0	2	41	36	Bâtonnet de géomancien		
15979	off	4	0	2	42	37	Bâton de braise-soie		
15980	off	4	0	2	46	41	Orbe de Sombrebrume		
15981	off	4	0	2	47	42	Sphère lunaire		
15982	off	4	0	2	51	46	Bâtonnet tissé de sang		
15983	off	4	0	2	52	47	Sceptre de Gaïa		
15984	off	4	0	2	56	51	Sceptre opulent		
15985	off	4	0	2	57	52	Branche arachnéenne		
15986	off	4	0	2	60	55	Etoile d'ossomancien		
15987	off	4	0	2	61	56	Orbe astral		
15988	off	4	0	2	63	58	Orbe resplendissant		
15989	off	4	0	2	65	60	Bâtonnet éternel		
15995	ranged	2	3	2	52	47	Carabine en thorium	PA dist. +22	c202:1
15999	head	4	1	2	54	0	Lunettes de concentration extrême	Puiss. sorts +27	c202:1
16004	ranged	2	3	3	55	50	Carabine en sombrefer		c202:1
16007	ranged	2	3	3	61	56	Carabine en arcanite sans défaut	End +12 · PA dist. +14	c202:1
16008	head	4	1	2	58	0	Lunettes de maître ingénieur	End +16 · Esp +17	c202:1
16009	neck	4	0	2	58	0	Modulateur d'amplification vocale		c202:1
16022	trinket	4	0	3	60	50	Petit dragon en arcanite		c202:1
16067	finger	4	0	3	61	0	Test Fire Res Ring	Rés. feu +8	
16121	head	4	1	2	35	30	Test Nature Res Head Cloth	Rés. nature +14	
16123	neck	4	0	2	35	30	Test Nature Res Neck	Rés. nature +8	
16124	neck	4	0	2	35	30	Test Frost Res Neck	Rés. givre +8	
16125	neck	4	0	2	35	30	Test Arcane Res Neck	Rés. arcanes +8	
16160	shoulder	4	4	2	40	40	Test Arcane Res Shoulders Plate	Rés. arcanes +12	
16161	hands	4	4	2	40	40	Test Shadow Res Hands Plate	Rés. ombre +12	
16309	neck	4	0	3	63	50	Amulette drakefeu	End +10 · Rés. feu +15	
16315	back	4	1	3	30	25	Cape du Sergent-major	For +4 · Agi +4 · End +4 · Int +4 · Esp +4	
16335	neck	4	0	3	63	58	Insigne de sergent-chef	End +17 · Esp +7	
16336	back	4	1	3	45	40	Cape du Sergent-major	For +6 · Agi +6 · End +6 · Int +6 · Esp +6	
16337	back	4	1	3	60	55	Cape du Sergent-major	For +8 · Agi +8 · End +8 · Int +8 · Esp +8	
16341	back	4	1	3	50	45	Cape de sergent	End +14 · Armure +60	
16342	back	4	1	3	63	58	Pèlerine de sergent	End +17 · Armure +70	
16345	one	2	7	4	78	60	Lame de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
16367	waist	4	1	3	60	55	Ceinture de chevalier-capitaine en soie	End +10 · Int +17 · Esp +10	
16369	feet	4	1	3	63	58	Bottes de chevalier-lieutenant en soie	End +16 · Int +15 · Puiss. sorts +12	
16370	wrist	4	1	3	60	55	Bracelets de chevalier-capitaine en soie	End +15 · Int +7 · Esp +3	
16391	hands	4	1	3	63	58	Gants de chevalier-lieutenant en soie	End +11 · Puiss. sorts +21	
16392	feet	4	2	3	63	58	Bottes de chevalier-lieutenant en cuir	Agi +11 · End +18	
16393	feet	4	2	3	63	58	Bottes de chevalier-lieutenant en peau de dragon	For +12 · Agi +5 · End +12 · Int +5 · Esp +5	
16394	wrist	4	2	3	60	55	Bracelets de chevalier-capitaine en cuir	Agi +15 · End +9	
16395	wrist	4	2	3	60	55	Bracelets de chevalier-capitaine en peau de dragon	End +14 · Int +10	
16396	hands	4	2	3	63	58	Gantelets de chevalier-lieutenant en cuir	Agi +10 · End +15 · PA +32	
16397	hands	4	2	3	63	58	Gants de chevalier-lieutenant en peau de dragon	For +12 · Agi +12 · End +12	
16398	waist	4	2	3	60	55	Ceinture de chevalier-capitaine en cuir	For +9 · Agi +15 · End +14	
16399	waist	4	2	3	60	55	Ceinture de chevalier-capitaine en peau de dragon	For +5 · End +10 · Int +15 · Esp +8	
16400	waist	4	3	3	60	55	Ceinture de chevalier-capitaine en chaînes	Agi +14 · End +15 · Int +9	
16401	feet	4	3	3	63	58	Bottes de chevalier-lieutenant en anneaux	Agi +10 · End +17 · Esquive +12	
16402	wrist	4	3	3	60	55	Brassards de chevalier-capitaine en chaînes	For +5 · Agi +17	
16403	hands	4	3	3	63	58	Gantelets de chevalier-lieutenant en anneaux	Agi +11 · End +18	
16404	wrist	4	4	3	60	55	Bracelets de chevalier-capitaine en plaques	For +10 · End +14	
16405	feet	4	4	3	63	58	Bottes de chevalier-lieutenant en plaques	For +8 · Agi +5 · End +23	
16406	hands	4	4	3	63	58	Gantelets de chevalier-lieutenant en plaques	For +16 · End +15	
16407	waist	4	4	3	60	55	Ceinture de chevalier-capitaine en plaques	For +19 · Agi +6 · End +8 · Esp +6	
16409	feet	4	4	3	63	58	Sandales lamellaires de chevalier-lieutenant	For +15 · Agi +6 · End +16 · Int +7	
16410	hands	4	4	3	63	58	Gantelets lamellaires de chevalier-lieutenant	For +15 · End +16	
16411	waist	4	4	3	60	55	Ceinture lamellaire de chevalier-capitaine	For +9 · End +15 · Int +10 · Esp +9	
16412	wrist	4	4	3	60	55	Bracelets lamellaires de chevalier-capitaine	For +7 · End +13 · Int +7	
16413	chest	4	1	3	63	58	Grande tenue de chevalier-capitaine en soie	End +20 · Int +20 · Crit. +14	
16414	legs	4	1	3	63	58	Pantalon de chevalier-capitaine en soie	End +16 · Int +13 · Esp +16 · Puiss. sorts +19	
16415	shoulder	4	1	3	63	58	Spallières de lieutenant-commandant en soie	End +16 · Int +15 · Puiss. sorts +12	
16416	head	4	1	3	63	58	Couronne de lieutenant-commandant	End +16 · Int +16 · Esp +16 · Crit. +14	
16417	chest	4	2	3	63	58	Armure de chevalier-capitaine en cuir	Agi +13 · End +25 · Crit. +14	
16418	head	4	2	3	63	58	Cagoule de lieutenant-commandant en cuir	End +26 · PA +12 · Toucher +10 · Esquive +12	
16419	legs	4	2	3	63	58	Jambières de chevalier-capitaine en cuir	For +7 · End +13 · Crit. +28	
16420	shoulder	4	2	3	63	58	Spallières de lieutenant-commandant en cuir	Agi +7 · End +23 · PA +12	
16421	chest	4	2	3	63	58	Tunique de chevalier-capitaine en peau de dragon	For +13 · Agi +9 · End +14 · Int +8 · Puiss. sorts +16	
16422	legs	4	2	3	63	58	Jambières de chevalier-capitaine en peau de dragon	For +12 · Agi +12 · End +12 · Int +9 · Esp +12	
16423	shoulder	4	2	3	63	58	Epaulettes de lieutenant-commandant en peau de dragon	For +10 · Agi +10 · End +10 · Int +6 · Esp +10	
16424	head	4	2	3	63	58	Voile de lieutenant-commandant en peau de dragon	For +11 · Agi +11 · End +16 · Int +11 · Esp +9	
16425	chest	4	3	3	63	58	Haubert de chevalier-capitaine en anneaux	Agi +16 · End +18 · PA +26 · Crit. +14	
16426	legs	4	3	3	63	58	Jambières de chevalier-capitaine en anneaux	Agi +18 · End +17 · Crit. +14 · Esquive +12	
16427	shoulder	4	3	3	63	58	Espauliers de lieutenant-commandant en anneaux	Agi +10 · End +20 · PA +12	
16428	head	4	3	3	63	58	Casque de lieutenant-commandant en anneaux	Agi +15 · End +24 · Int +10 · PA +12	
16429	head	4	4	3	63	58	Casque de lieutenant-commandant en plaques	For +9 · Agi +8 · End +31	
16430	chest	4	4	3	63	58	Corselet de chevalier-capitaine en plaques	For +9 · Agi +6 · End +25 · Crit. +14	
16431	legs	4	4	3	63	58	Jambières de chevalier-capitaine en plaques	For +7 · End +13 · Crit. +28	
16432	shoulder	4	4	3	63	58	Espauliers de lieutenant-commandant en plaques	For +7 · Agi +6 · End +23	
16433	chest	4	4	3	63	58	Cuirasse lamellaire de chevalier-capitaine	For +9 · Agi +8 · End +25 · Crit. +14	
16434	head	4	4	3	63	58	Casque lamellaire de lieutenant-commandant	For +9 · Agi +8 · End +31	
16435	legs	4	4	3	63	58	Jambières lamellaires de chevalier-capitaine	For +7 · End +13 · Crit. +28	
16436	shoulder	4	4	3	63	58	Epaulières lamellaires de lieutenant-commandant	For +12 · Agi +12 · End +12 · Int +7 · Esp +5	
16437	feet	4	1	4	71	60	Bottes de maréchal en soie	End +23 · Int +14 · Esp +6 · Puiss. sorts +21 · Toucher +10	
16438	wrist	4	1	4	65	60	Bracelets de maréchal en soie	End +10 · Int +19 · Esp +10	
16439	waist	4	1	4	65	60	Ceinture de maréchal en soie	End +15 · Int +23 · Esp +15	
16440	hands	4	1	4	71	60	Gants de maréchal en soie	End +22 · Int +12 · Esp +5 · Puiss. sorts +27 · Armure +40	
16441	head	4	1	4	74	60	Cerclet de grand maréchal	End +28 · Int +17 · Esp +6 · Puiss. sorts +33 · Crit. +14	
16442	legs	4	1	4	71	60	Jambières de maréchal en soie	End +26 · Int +20 · Esp +10 · Puiss. sorts +30 · Crit. +14	
16443	chest	4	1	4	74	60	Habit de grand maréchal en soie	End +28 · Int +17 · Esp +6 · Puiss. sorts +33 · Crit. +14	
16444	shoulder	4	1	4	74	60	Spallières de grand maréchal en soie	End +21 · Int +15 · Esp +5 · Puiss. sorts +25 · Armure +50	
16445	wrist	4	2	4	65	60	Bracelets en peau de dragon de maréchal	End +10 · Int +19 · Esp +10	
16446	feet	4	2	4	71	60	Bottes de maréchal en cuir	Agi +22 · End +25 · Armure +40	
16447	waist	4	2	4	65	60	Ceinture de maréchal en peau de dragon	End +18 · Int +25 · Esp +10	
16448	hands	4	2	4	71	60	Gantelets de maréchal en peau de dragon	For +20 · Agi +19 · End +15 · Puiss. sorts +12 · Armure +40	
16449	shoulder	4	2	4	74	60	Spallières de grand maréchal en peau de dragon	For +14 · Agi +14 · End +13 · Int +11 · Esp +11	
16450	legs	4	2	4	71	60	Jambières de maréchal en peau de dragon	For +24 · Agi +18 · End +18 · Int +15 · Esp +13	
16451	head	4	2	4	74	60	Heaume de grand maréchal en peau de dragon	For +20 · Agi +19 · End +19 · Int +15 · Esp +7	
16452	chest	4	2	4	74	60	Cuirasse de grand maréchal en peau de dragon	For +25 · Agi +14 · End +19 · Int +13 · Puiss. sorts +21	
16453	chest	4	2	4	74	60	Plastron de grand maréchal en cuir	Agi +26 · End +31 · Crit. +14 · Toucher +10 · Armure +40	
16454	hands	4	2	4	71	60	Manicles de maréchal en cuir	Agi +20 · End +23 · Crit. +14 · Armure +60	
16455	head	4	2	4	74	60	Masque de grand maréchal en cuir	Agi +27 · End +31 · Crit. +14 · Toucher +10 · Armure +50	
16456	legs	4	2	4	71	60	Jambières de maréchal en cuir	Agi +27 · End +27 · Crit. +14 · Toucher +20 · Armure +50	
16457	shoulder	4	2	4	74	60	Epaulettes de grand maréchal en cuir	Agi +21 · End +27 · Toucher +10 · Armure +50	
16458	waist	4	2	4	65	60	Ceinture de maréchal en cuir	For +26 · Agi +15 · End +11	
16459	feet	4	2	4	71	60	Bottes de maréchal en peau de dragon	For +18 · Agi +11 · End +14 · Int +10 · Esp +10	
16460	wrist	4	2	4	65	60	Brassards de maréchal en cuir	For +10 · Agi +19 · End +10	
16461	wrist	4	3	4	65	60	Bracelets de maréchal en chaînes	Agi +20 · End +10 · Int +7	
16462	feet	4	3	4	71	60	Bottes de maréchal en anneaux	Agi +26 · End +20 · Int +9 · Toucher +10 · Armure +50	
16463	hands	4	3	4	71	60	Poignes de maréchal en anneaux	Agi +21 · End +20 · Int +4 · Crit. +14 · Armure +40	
16464	waist	4	3	4	65	60	Ceinture de maréchal en chaînes	For +5 · Agi +18 · End +18 · Int +18	
16465	head	4	3	4	74	60	Casque de grand maréchal en anneaux	Agi +34 · End +28 · Int +12 · Crit. +14 · Armure +50	
16466	chest	4	3	4	74	60	Cuirasse de grand maréchal en anneaux	Agi +34 · End +28 · Int +12 · Crit. +14 · Armure +50	
16467	legs	4	3	4	71	60	Jambières de maréchal en anneaux	Agi +34 · End +27 · Int +12 · Crit. +14 · Armure +50	
16468	shoulder	4	3	4	74	60	Spallières de grand maréchal en anneaux	Agi +26 · End +21 · Int +10 · Toucher +10 · Armure +50	
16469	wrist	4	4	4	65	60	Brassards lamellaires de maréchal	For +14 · End +19 · Int +4	
16470	waist	4	4	4	65	60	Ceinture lamellaire de maréchal	For +8 · Agi +8 · End +16 · Int +16 · Esp +16	
16471	hands	4	4	4	71	60	Gants lamellaires de maréchal	For +18 · End +17 · Int +16 · Crit. +14	
16472	feet	4	4	4	71	60	Bottes lamellaires de maréchal	For +15 · End +16 · Int +15 · Puiss. sorts +18 · Mana/5 +6	
16473	chest	4	4	4	74	60	Pansière lamellaire de grand maréchal	For +21 · End +21 · Int +20 · Puiss. sorts +25 · Crit. +14	
16474	head	4	4	4	74	60	Casque lamellaire de grand maréchal	For +21 · End +21 · Int +20 · Puiss. sorts +25 · Crit. +14	
16475	legs	4	4	4	71	60	Jambières lamellaires de maréchal	For +20 · End +20 · Int +17 · Puiss. sorts +27 · Crit. +14	
16476	shoulder	4	4	4	74	60	Espauliers lamellaires de grand maréchal	For +16 · End +16 · Int +15 · Puiss. sorts +19 · Mana/5 +6	
16477	chest	4	4	4	74	60	Armure de plaques de grand maréchal	For +16 · Agi +14 · End +33 · Crit. +14 · Armure +40	
16478	head	4	4	4	74	60	Casque de grand maréchal en plaques	For +28 · End +34 · Crit. +14 · Armure +40	
16479	legs	4	4	4	71	60	Jambières de maréchal en plaques	For +20 · End +28 · Crit. +28 · Toucher +10 · Armure +40	
16480	shoulder	4	4	4	74	60	Garde-épaules de grand maréchal en plaques	For +18 · Agi +16 · End +23 · Toucher +10	
16481	wrist	4	4	4	65	60	Bracelets de maréchal en plaques	For +17 · Agi +7 · End +17	
16482	waist	4	4	4	65	60	Ceinture de maréchal en plaques	For +25 · Agi +12 · End +15	
16483	feet	4	4	4	71	60	Bottes de maréchal en plaques	For +18 · Agi +12 · End +24 · Toucher +10 · Armure +40	
16484	hands	4	4	4	71	60	Gantelets de maréchal en plaques	For +20 · End +23 · Crit. +14 · Armure +30	
16485	feet	4	1	3	63	58	Bottines de garde de sang en soie	End +16 · Int +15 · Puiss. sorts +12	
16486	wrist	4	1	3	63	58	Crispins d'adjudant en soie	End +17 · Int +7	
16487	hands	4	1	3	63	58	Gants de garde de sang en soie	End +11 · Puiss. sorts +21	
16488	waist	4	1	3	60	55	Ceinture de légionnaire en soie	End +10 · Int +17 · Esp +10	
16489	head	4	1	3	63	58	Chaperon de champion en soie	End +16 · Int +16 · Esp +16 · Crit. +14	
16490	legs	4	1	3	63	58	Pantalon de légionnaire en soie	End +16 · Int +13 · Esp +16 · Puiss. sorts +19	
16491	chest	4	1	3	63	58	Robe de légionnaire en soie	End +20 · Int +20 · Crit. +14	
16492	shoulder	4	1	3	63	58	Protège-épaules de champion en soie	End +16 · Int +15 · Puiss. sorts +12	
16493	wrist	4	2	3	60	55	Brassards de légionnaire en peau de dragon	End +14 · Int +10	
16494	feet	4	2	3	63	58	Bottes de garde de sang en peau de dragon	For +12 · Agi +5 · End +12 · Int +5 · Esp +5	
16495	waist	4	2	3	60	55	Ceinture de légionnaire en peau de dragon	For +5 · End +10 · Int +15 · Esp +8	
16496	hands	4	2	3	63	58	Gantelets de champion en peau de dragon	For +12 · Agi +12 · End +12	
16497	wrist	4	2	3	63	58	Garde-bras d'adjudant en cuir	Agi +7 · End +17	
16498	feet	4	2	3	63	58	Bottes de garde de sang en cuir	Agi +11 · End +18	
16499	hands	4	2	3	63	58	Cestes de garde de sang en cuir	Agi +10 · End +15 · PA +32	
16500	waist	4	2	3	60	55	Ceinture de légionnaire en cuir	For +9 · Agi +15 · End +14	
16501	shoulder	4	2	3	63	58	Spallières de champion en peau de dragon	For +10 · Agi +10 · End +10 · Int +6 · Esp +10	
16502	legs	4	2	3	63	58	Pantalon de légionnaire en peau de dragon	For +12 · Agi +12 · End +12 · Int +9 · Esp +12	
16503	head	4	2	3	63	58	Casque de champion en peau de dragon	For +11 · Agi +11 · End +16 · Int +11 · Esp +9	
16504	chest	4	2	3	63	58	Cuirasse de légionnaire en peau de dragon	For +13 · Agi +9 · End +14 · Int +8 · Puiss. sorts +16	
16505	chest	4	2	3	63	58	Haubert de légionnaire en cuir	Agi +13 · End +25 · Crit. +14	
16506	head	4	2	3	63	58	Casque de champion en cuir	End +26 · PA +12 · Toucher +10 · Esquive +12	
16507	shoulder	4	2	3	63	58	Mantelet de champion en cuir	Agi +7 · End +23 · PA +12	
16508	legs	4	2	3	63	58	Jambières de légionnaire en cuir	For +7 · End +13 · Crit. +28	
16509	feet	4	4	3	63	58	Bottes de garde de sang en plaques	For +8 · Agi +5 · End +23	
16510	hands	4	4	3	63	58	Gants de garde de sang en plaques	For +16 · End +15	
16511	waist	4	4	3	60	55	Ceinture de légionnaire en plaques	For +19 · Agi +6 · End +8 · Esp +6	
16512	wrist	4	4	3	60	55	Bracelets de légionnaire en plaques	For +10 · End +14	
16513	chest	4	4	3	63	58	Armure de plaques de légionnaire	For +9 · Agi +6 · End +25 · Crit. +14	
16514	head	4	4	3	63	58	Heaume de champion en plaques	For +9 · Agi +8 · End +31	
16515	legs	4	4	3	63	58	Jambières de légionnaire en plaques	For +7 · End +13 · Crit. +28	
16516	shoulder	4	4	3	63	58	Espauliers de champion en plaques	For +7 · Agi +6 · End +23	
16517	wrist	4	3	3	60	55	Bracelets de légionnaire en chaînes	For +5 · Agi +17	
16518	feet	4	3	3	63	58	Bottes de garde de sang en mailles	End +14 · Int +10 · Puiss. sorts +14	
16519	hands	4	3	3	63	58	Poignes de garde de sang en mailles	For +6 · End +15 · Int +7 · Puiss. sorts +19	
16520	waist	4	3	3	60	55	Ceinture de légionnaire en mailles	For +7 · End +11 · Int +17 · Esp +4	
16521	head	4	3	3	63	58	Heaume de champion en mailles	For +8 · End +25 · Int +9 · Crit. +14	
16522	chest	4	3	3	63	58	Plastron de légionnaire en mailles	End +20 · Int +20 · Crit. +14	
16523	legs	4	3	3	63	58	Jambières de légionnaire en mailles	Agi +5 · End +20 · Int +11 · Puiss. sorts +25	
16524	shoulder	4	3	3	63	58	Epaulières de champion en mailles	For +5 · Agi +5 · End +16 · Int +15 · Puiss. sorts +6	
16525	chest	4	3	3	63	58	Cuirasse de légionnaire en anneaux	Agi +16 · End +18 · PA +26 · Crit. +14	
16527	legs	4	3	3	63	58	Jambières de légionnaire en anneaux	Agi +18 · End +17 · Crit. +14 · Esquive +12	
16528	shoulder	4	3	3	63	58	Espauliers de champion en anneaux	Agi +10 · End +20 · PA +12	
16529	waist	4	3	3	60	55	Ceinture de légionnaire en chaînes	Agi +14 · End +15 · Int +9	
16530	hands	4	3	3	63	58	Gantelets de garde de sang en anneaux	Agi +11 · End +18	
16531	feet	4	3	3	63	58	Bottes de garde de sang en anneaux	Agi +10 · End +17 · Esquive +12	
16532	wrist	4	3	3	63	58	Garde-poignets d'adjudant en mailles	End +17 · Int +7	
16533	head	4	1	4	74	60	Capuche de seigneur de guerre en soie	End +28 · Int +17 · Esp +6 · Puiss. sorts +33 · Crit. +14	
16534	legs	4	1	4	71	60	Pantalon de général en soie	End +26 · Int +20 · Esp +10 · Puiss. sorts +30 · Crit. +14	
16535	chest	4	1	4	74	60	Grande tenue de seigneur de guerre en soie	End +28 · Int +17 · Esp +6 · Puiss. sorts +33 · Crit. +14	
16536	shoulder	4	1	4	74	60	Amict de seigneur de guerre en soie	End +21 · Int +15 · Esp +5 · Puiss. sorts +25 · Armure +50	
16537	waist	4	1	4	65	60	Ceinture de général en soie	End +15 · Int +23 · Esp +15	
16538	wrist	4	1	4	65	60	Bracelets de général en soie	End +10 · Int +19 · Esp +10	
16539	feet	4	1	4	71	60	Bottes de général en soie	End +23 · Int +14 · Esp +6 · Puiss. sorts +21 · Toucher +10	
16540	hands	4	1	4	71	60	Garde-mains de général en soie	End +22 · Int +12 · Esp +5 · Puiss. sorts +27 · Armure +40	
16541	chest	4	4	4	74	60	Armure de plaques de seigneur de guerre	For +16 · Agi +14 · End +33 · Crit. +14 · Armure +40	
16542	head	4	4	4	74	60	Heaume de seigneur de guerre en plaques	For +28 · End +34 · Crit. +14 · Armure +40	
16543	legs	4	4	4	71	60	Jambières de général en plaques	For +20 · End +28 · Crit. +28 · Toucher +10 · Armure +40	
16544	shoulder	4	4	4	74	60	Epaulières de seigneur de guerre en plaques	For +18 · Agi +16 · End +23 · Toucher +10	
16545	feet	4	4	4	71	60	Bottes de général en plaques	For +18 · Agi +12 · End +24 · Toucher +10 · Armure +40	
16546	wrist	4	4	4	65	60	Brassards de général en plaques	For +17 · Agi +7 · End +17	
16547	waist	4	4	4	65	60	Ceinture de général en plaques	For +25 · Agi +12 · End +15	
16548	hands	4	4	4	71	60	Gantelets de général en plaques	For +20 · End +23 · Crit. +14 · Armure +30	
16549	chest	4	2	4	74	60	Haubert de seigneur de guerre en peau de dragon	For +25 · Agi +14 · End +19 · Int +13 · Puiss. sorts +21	
16550	head	4	2	4	74	60	Casque de seigneur de guerre en peau de dragon	For +20 · Agi +19 · End +19 · Int +15 · Esp +7	
16551	shoulder	4	2	4	74	60	Epaulettes de seigneur de guerre en peau de dragon	For +14 · Agi +14 · End +13 · Int +11 · Esp +11	
16552	legs	4	2	4	71	60	Jambières de général en peau de dragon	For +24 · Agi +18 · End +18 · Int +15 · Esp +13	
16553	wrist	4	2	4	65	60	Bracelets de général en peau de dragon	End +10 · Int +19 · Esp +10	
16554	feet	4	2	4	71	60	Bottes de général en peau de dragon	For +18 · Agi +11 · End +14 · Int +10 · Esp +10	
16555	hands	4	2	4	71	60	Gants de général en peau de dragon	For +20 · Agi +19 · End +15 · Puiss. sorts +12 · Armure +40	
16556	waist	4	2	4	65	60	Ceinture de général en peau de dragon	End +18 · Int +25 · Esp +10	
16557	waist	4	2	4	65	60	Ceinture de général en cuir	For +26 · Agi +15 · End +11	
16558	feet	4	2	4	71	60	Bottes de général en cuir	Agi +22 · End +25 · Armure +40	
16559	wrist	4	2	4	65	60	Bracelets de général en cuir	For +10 · Agi +19 · End +10	
16560	hands	4	2	4	71	60	Mitaines de général en cuir	Agi +20 · End +23 · Crit. +14 · Armure +60	
16561	head	4	2	4	74	60	Casque de seigneur de guerre en cuir	Agi +27 · End +31 · Crit. +14 · Toucher +10 · Armure +50	
16562	shoulder	4	2	4	74	60	Spallières de seigneur de guerre en cuir	Agi +21 · End +27 · Toucher +10 · Armure +50	
16563	chest	4	2	4	74	60	Cuirasse de seigneur de guerre en cuir	Agi +26 · End +31 · Crit. +14 · Toucher +10 · Armure +40	
16564	legs	4	2	4	71	60	Jambières de général en cuir	Agi +27 · End +27 · Crit. +14 · Toucher +20 · Armure +50	
16565	chest	4	3	4	74	60	Plastron de seigneur de guerre en anneaux	Agi +34 · End +28 · Int +12 · Crit. +14 · Armure +50	
16566	head	4	3	4	74	60	Heaume de seigneur de guerre en anneaux	Agi +34 · End +28 · Int +12 · Crit. +14 · Armure +50	
16567	legs	4	3	4	71	60	Jambières de général en anneaux	Agi +34 · End +27 · Int +12 · Crit. +14 · Armure +50	
16568	shoulder	4	3	4	74	60	Epaulières de seigneur de guerre en anneaux	Agi +26 · End +21 · Int +10 · Toucher +10 · Armure +50	
16569	feet	4	3	4	71	60	Solerets de général en anneaux	Agi +26 · End +20 · Int +9 · Toucher +10 · Armure +50	
16570	wrist	4	3	4	65	60	Bracelets de général en chaînes	Agi +20 · End +10 · Int +7	
16571	hands	4	3	4	71	60	Gants de général en anneaux	Agi +21 · End +20 · Int +4 · Crit. +14 · Armure +40	
16572	waist	4	3	4	65	60	Ceinture de général en chaînes	For +5 · Agi +18 · End +18 · Int +18	
16573	feet	4	3	4	71	60	Bottes de général en mailles	End +18 · Int +17 · Puiss. sorts +20 · Mana/5 +5	
16574	hands	4	3	4	71	60	Gantelets de général en mailles	For +17 · End +18 · Int +17 · Crit. +14 · Armure +70	
16575	waist	4	3	4	65	60	Ceinture de général en mailles	For +5 · End +15 · Int +25 · Esp +10	
16576	wrist	4	3	4	65	60	Bracelets de général en mailles	End +19 · Int +10 · Esp +10	
16577	chest	4	3	4	74	60	Armure de seigneur de guerre en mailles	For +9 · End +35 · Int +20 · Puiss. sorts +9 · Crit. +14	
16578	head	4	3	4	74	60	Heaume de seigneur de guerre en mailles	For +11 · End +35 · Int +19 · Puiss. sorts +9 · Crit. +14	
16579	legs	4	3	4	71	60	Jambières de général en mailles	End +23 · Int +23 · Puiss. sorts +27 · Crit. +14	
16580	shoulder	4	3	4	74	60	Spallières de seigneur de guerre en mailles	For +17 · Agi +9 · End +18 · Int +18 · Puiss. sorts +16	
16604	chest	4	1	2	10	0	Robe lunaire d'Elune	Esp +1	
16605	chest	4	1	2	5	0	Robe de moine de la lumière	Esp +1	
16606	chest	4	1	2	5	0	Robe juju maléfique	Esp +1	
16607	chest	4	1	2	5	0	Robe sacrificielle d'acolyte	Esp +1	
16608	waist	4	2	2	16	0	Ceinture du Verseau	End +2 · Int +2	
16622	ranged	2	2	2	57	0	Thornflinger	Agi +10	
16623	neck	4	0	2	57	0	Médaillon d'opaline	End +3 · Int +13	
16658	back	4	1	2	32	0	Cape de chasseur de fauves	End +2 · PA +10	
16659	waist	4	2	2	27	0	Ceinture d'équilibriste	Agi +4 · End +3 · PA +12	
16660	off	4	6	2	27	0	Bouclier de Driftmire	For +2 · End +3 · Int +3	
16661	back	4	1	2	27	0	Cape du saule souple	Int +5	
16664	wrist	4	3	2	54	49	Brassards ornés		
16738	hands	4	1	2	48	0	Gants de sèchegraine	Esp +13 · Puiss. sorts +8	
16739	shoulder	4	2	2	48	0	Mantelet en bois d'acacia	Int +11 · Esp +4 · Puiss. sorts +7	
16740	hands	4	1	2	31	0	Gants de manipulation du Déchiqueteur	Agi +2 · End +5 · Int +6	
16741	hands	4	2	2	31	0	Protège-mains huilés	End +2 · Int +2 · Puiss. sorts +9	
16768	off	4	0	2	52	0	Sac-médecine furbolg	End +10	
16769	main	2	4	2	52	47	Totem-médecine furbolg	End +6 · Esp +6	
16788	off	4	6	2	36	0	Roue du capitaine Rackmore	End +8	
16789	ranged	2	19	2	36	0	Barre du capitaine Rackmore	Esp +4 · Dégâts sorts +3 · Soins +9	
16791	wrist	4	1	2	38	0	Crispins flot-de-soie	End +4 · Int +5 · Esp +4	
16792	main	2	4	2	37	32	Gourdin géant		
16793	shoulder	4	3	2	38	0	Epaulières d'Arcmetal	Agi +9 · End +5	
16794	wrist	4	3	2	38	0	Garde-poignets poigne-d'acier	For +5 · Agi +3 · End +5	
16873	hands	4	2	2	38	0	Gants en fourrure tressée	End +5 · Int +7 · Esp +4	
16889	two	2	10	2	24	0	Bâton de marche poli	End +3 · Int +7	
16890	one	2	7	2	24	0	Coutelas de Slatemetal	For +2 · Agi +2	
16891	one	2	7	2	21	0	Epée courte de Claystone	End +3	
16894	two	2	10	2	21	0	Bâtonnet en cristal transparent	End +4 · Int +5	
16975	waist	4	1	3	27	0	Echarpe chanteguerre	End +4 · Puiss. sorts +11	
16977	feet	4	2	3	27	0	Bottes chanteguerres	Agi +8 · End +6	
16978	hands	4	3	3	27	0	Gantelets chanteguerres	For +10 · End +3	
16979	hands	4	1	4	62	57	Gants Coeur-de-braise	End +10 · Int +14 · Rés. feu +25	c197:1
16980	shoulder	4	1	4	61	56	Mantelet Coeur-de-braise	End +9 · Int +10 · Esp +10 · Rés. feu +24	c197:1
16981	wrist	4	1	2	20	0	Brassards de Barbe-huante	End +1 · Int +2 · Puiss. sorts +1	
16982	feet	4	2	4	59	54	Bottes du Magma	Agi +13 · End +10 · Rés. feu +24	c165:1
16983	head	4	2	4	60	55	Casque de la fournaise	End +16 · Esquive +12 · Rés. feu +29	c165:1
16984	feet	4	3	4	61	56	Bottes en écailles de dragon noir	End +10 · PA +28 · Rés. feu +24	c165:1
16985	feet	4	1	2	25	0	Bottes de Cherchevent	Esp +6	
16986	hands	4	3	2	25	0	Gants du Pic de sable	For +5 · End +2	
16987	waist	4	2	2	27	0	Ceinture d'hurleur	End +3 · Int +5 · Esp +2 · PA +12	
16988	shoulder	4	3	4	62	57	Epaulières en anneaux de feu	End +10 · Int +14 · Rés. feu +25	c164:1
16989	waist	4	3	4	59	54	Ceinturon en anneaux de feu	End +10 · Int +9 · Esp +8 · Rés. feu +24	c164:1
16990	back	4	1	2	27	0	Cape des fées	Agi +4 · End +3	
16992	ranged	2	3	2	60	0	Lanceur explosif de Smokey	Rés. feu +11	
16993	ranged	2	19	2	60	0	Tire-flammes de Smokey	Rés. feu +11	
16994	hands	4	2	2	60	0	Gants de Crépuscaile	End +11 · Int +14 · Esp +5	
16995	shoulder	4	2	2	60	0	Mantelet de Crépuscaile	Agi +17 · End +6	
16996	ranged	2	2	3	62	0	Arc Gorewood	For +3 · Agi +4 · End +12	
16997	ranged	2	19	3	62	0	Tempétueuse	End +11 · Int +7	
16998	off	4	6	3	62	0	Protecteur sacré	End +15 · Int +10	
16999	finger	4	0	3	59	54	Sceau royal d'Alexis	End +10 · Int +10 · Esp +8	
17000	finger	4	0	2	62	0	Anneau de l’âme en peine	Rés. ombre +10 · Rés. arcanes +10	
17002	one	2	0	2	61	0	Cracheur d'ichor		
17003	main	2	4	2	61	0	Marteau de Skullstone	End +4 · Int +9 · Esp +3	
17004	two	2	10	2	61	0	Guide de Sarah	End +20 · Int +15	
17005	chest	4	2	2	27	0	Tunique de rustre	Agi +7 · End +6	
17006	legs	4	3	2	27	0	Jambières en cobalt	For +5 · Agi +3 · End +7	
17013	legs	4	4	4	60	55	Jambières en sombrefer	End +14 · Armure +180 · Rés. feu +30	c164:1
17014	wrist	4	4	4	59	54	Brassards en sombrefer	End +7 · Armure +100 · Rés. feu +18	c164:1
17015	one	2	7	3	65	60	Déchireur en sombrefer	End +10 · Rés. feu +6	c164:1
17016	one	2	0	3	65	60	Destructeur en sombrefer	For +10 · Rés. feu +6	c164:1
17046	one	2	0	2	31	0	Eventreuse	For +3 · End +3	
17047	shoulder	4	1	2	30	0	Amict luminescent	End +6 · Int +4 · Esp +2	
17073	two	2	5	4	66	60	Trembleterre	PA +22	
17111	neck	4	0	4	68	60	Médaillon Blazefury	Agi +13 · End +14 · Rés. feu +12	
17142	one	2	15	5	70	60	Eclat du Souilleur	Crit. +210	
17182	two	2	5	5	80	60	Sulfuras, Main de Ragnaros	For +12 · End +12 · Rés. feu +30	
17193	two	2	5	4	67	60	Marteau en sulfuron		c164:1
17223	two	2	6	4	63	58	Tonitruante		
17523	back	4	1	2	58	0	Drapé de Smokey	End +9 · Rés. feu +10	
17562	feet	4	1	3	63	58	Bottes de chevalier-lieutenant en tisse-effroi	End +10 · Int +15 · Puiss. sorts +19	
17563	wrist	4	1	3	60	55	Bracelets de chevalier-capitaine en tissu-effroi	End +15 · Int +7 · Esp +3	
17564	hands	4	1	3	63	58	Gants de chevalier-lieutenant en tisse-effroi	End +18 · Int +11	
17565	waist	4	1	3	60	55	Ceinture de chevalier-capitaine en tissu-effroi	End +10 · Int +17 · Esp +10	
17566	head	4	1	3	63	58	Protège-front de lieutenant-commandant	End +20 · Int +20 · Puiss. sorts +16	
17567	legs	4	1	3	63	58	Jambières de chevalier-capitaine en tisse-effroi	End +21 · Int +20 · Puiss. sorts +16	
17568	chest	4	1	3	63	58	Robe de chevalier-capitaine en tisse-effroi	End +20 · Int +20 · Puiss. sorts +16	
17569	shoulder	4	1	3	63	58	Mantelet de lieutenant-commandant en tisse-effroi	End +16 · Int +15 · Puiss. sorts +12	
17570	head	4	1	3	63	58	Chaperon de champion en tisse-effroi	End +20 · Int +20 · Puiss. sorts +16	
17571	legs	4	1	3	63	58	Jambières de légionnaire en tisse-effroi	End +15 · Int +13 · Puiss. sorts +28	
17572	chest	4	1	3	63	58	Robe de légionnaire en tisse-effroi	End +20 · Int +20 · Puiss. sorts +16	
17573	shoulder	4	1	3	63	58	Epaulières de champion en tisse-effroi	End +16 · Int +15 · Puiss. sorts +12	
17574	waist	4	1	3	60	55	Ceinture de légionnaire en tissu-effroi	End +10 · Int +17 · Esp +10	
17575	wrist	4	1	3	60	55	Bracelets de légionnaire en tissu-effroi	End +15 · Int +7 · Esp +3	
17576	feet	4	1	3	63	58	Bottes de garde de sang en tisse-effroi	End +16 · Int +15 · Puiss. sorts +12	
17577	hands	4	1	3	63	58	Gants de garde de sang en tisse-effroi	End +11 · Puiss. sorts +21	
17578	head	4	1	4	74	60	Couronne de grand maréchal	End +30 · Int +24 · Puiss. sorts +32 · Armure +40	
17579	legs	4	1	4	71	60	Jambières de maréchal en tisse-effroi	End +28 · Int +19 · Puiss. sorts +37 · Armure +40	
17580	shoulder	4	1	4	74	60	Epaulières de grand maréchal en tisse-effroi	End +24 · Int +17 · Puiss. sorts +25 · Armure +30	
17581	chest	4	1	4	74	60	Robe de grand maréchal en tisse-effroi	End +30 · Int +24 · Puiss. sorts +32 · Armure +40	
17582	wrist	4	1	4	65	60	Bracelets de maréchal en tissu-effroi	End +10 · Int +19 · Esp +10	
17583	feet	4	1	4	71	60	Bottes de maréchal en tisse-effroi	End +22 · Int +13 · Puiss. sorts +26 · Armure +60	
17584	hands	4	1	4	71	60	Gants de maréchal en tisse-effroi	End +20 · Int +6 · Puiss. sorts +30	
17585	waist	4	1	4	65	60	Ceinture de maréchal en tissu-effroi	End +15 · Int +23 · Esp +15	
17586	feet	4	1	4	71	60	Bottes de général en tisse-effroi	End +22 · Int +13 · Puiss. sorts +26 · Armure +60	
17587	wrist	4	1	4	65	60	Bracelets de général en tissu-effroi	End +10 · Int +19 · Esp +10	
17588	hands	4	1	4	71	60	Gants de général en tisse-effroi	End +20 · Int +6 · Puiss. sorts +30	
17589	waist	4	1	4	65	60	Ceinture de général en tissu-effroi	End +15 · Int +23 · Esp +15	
17590	shoulder	4	1	4	74	60	Mantelet de seigneur de guerre en tisse-effroi	End +24 · Int +17 · Puiss. sorts +25 · Armure +30	
17591	head	4	1	4	74	60	Chaperon de seigneur de guerre en tisse-effroi	End +30 · Int +24 · Puiss. sorts +32 · Armure +40	
17592	chest	4	1	4	74	60	Robe de seigneur de guerre en tisse-effroi	End +30 · Int +24 · Puiss. sorts +32 · Armure +40	
17593	legs	4	1	4	71	60	Pantalon de général en tisse-effroi	End +28 · Int +19 · Puiss. sorts +37 · Armure +40	
17594	feet	4	1	3	63	58	Bottes de chevalier-lieutenant en satin	End +16 · Int +15 · Puiss. sorts +12	
17595	wrist	4	1	3	60	55	Bracelets de chevalier-capitaine en satin	End +15 · Int +7 · Esp +3	
17596	hands	4	1	3	63	58	Gants de chevalier-lieutenant en satin	End +11 · Puiss. sorts +21	
17597	waist	4	1	3	60	55	Ceinture de chevalier-capitaine en satin	End +10 · Int +17 · Esp +10	
17598	head	4	1	3	63	58	Diadème de lieutenant-commandant	End +20 · Int +20 · Puiss. sorts +16	
17599	legs	4	1	3	63	58	Jambières de chevalier-capitaine en satin	End +16 · Int +13 · Esp +16 · Puiss. sorts +19	
17600	chest	4	1	3	63	58	Robe de chevalier-capitaine en satin	End +20 · Int +20 · Puiss. sorts +16	
17601	shoulder	4	1	3	63	58	Amict de lieutenant-commandant en satin	End +16 · Int +15 · Puiss. sorts +12	
17602	head	4	1	4	74	60	Coiffure de grand maréchal	End +30 · Int +28 · Puiss. sorts +33 · Mana/5 +4 · Armure +70	
17603	legs	4	1	4	71	60	Pantalon de maréchal en satin	End +30 · Int +21 · Puiss. sorts +32 · Mana/5 +4 · Armure +70	
17604	shoulder	4	1	4	74	60	Mantelet de grand maréchal en satin	End +22 · Int +20 · Puiss. sorts +25 · Armure +60	
17605	chest	4	1	4	74	60	Habit de grand maréchal en satin	End +30 · Int +28 · Puiss. sorts +33 · Mana/5 +4 · Armure +70	
17606	wrist	4	1	4	65	60	Bracelets de maréchal en satin	End +10 · Int +19 · Esp +10	
17607	feet	4	1	4	71	60	Sandales de maréchal en satin	End +21 · Int +18 · Puiss. sorts +23 · Armure +50	
17608	hands	4	1	4	71	60	Gants de maréchal en satin	End +21 · Int +13 · Puiss. sorts +23 · Armure +50	
17609	waist	4	1	4	65	60	Ceinture de maréchal en satin	End +15 · Int +23 · Esp +15	
17610	head	4	1	3	63	58	Capuche de champion en satin	End +20 · Int +20 · Puiss. sorts +16	
17611	legs	4	1	3	63	58	Pantalon de légionnaire en satin	End +16 · Int +13 · Esp +16 · Puiss. sorts +19	
17612	chest	4	1	3	63	58	Habit de légionnaire en satin	End +20 · Int +20 · Puiss. sorts +16	
17613	shoulder	4	1	3	63	58	Protège-épaules de champion en satin	End +16 · Int +15 · Puiss. sorts +12	
17614	waist	4	1	3	60	55	Ceinture de légionnaire en satin	End +10 · Int +17 · Esp +10	
17615	wrist	4	1	3	60	55	Bracelets de légionnaire en satin	End +15 · Int +7 · Esp +3	
17616	feet	4	1	3	63	58	Bottes de garde de sang en satin	End +16 · Int +15 · Puiss. sorts +12	
17617	hands	4	1	3	63	58	Gants de garde de sang en satin	End +11 · Puiss. sorts +21	
17618	feet	4	1	4	71	60	Bottes de général en satin	End +21 · Int +18 · Puiss. sorts +23 · Armure +50	
17619	wrist	4	1	4	65	60	Bracelets de général en satin	End +10 · Int +19 · Esp +10	
17620	hands	4	1	4	71	60	Gants de général en satin	End +21 · Int +13 · Puiss. sorts +23 · Armure +50	
17621	waist	4	1	4	65	60	Ceinture de général en satin	End +15 · Int +23 · Esp +15	
17622	shoulder	4	1	4	74	60	Mantelet de seigneur de guerre en satin	End +22 · Int +20 · Puiss. sorts +25 · Armure +60	
17623	head	4	1	4	74	60	Capuche de seigneur de guerre en satin	End +30 · Int +28 · Puiss. sorts +33 · Mana/5 +4 · Armure +70	
17624	chest	4	1	4	74	60	Robe de seigneur de guerre en satin	End +30 · Int +28 · Puiss. sorts +33 · Mana/5 +4 · Armure +70	
17625	legs	4	1	4	71	60	Jambières de général en satin	End +30 · Int +21 · Puiss. sorts +32 · Mana/5 +4 · Armure +70	
17686	ranged	2	2	2	43	0	Arc de maître-chasseur	Agi +7	
17687	ranged	2	3	2	43	0	Carabine de maître-chasseur	For +5 · Agi +5	
17688	feet	4	4	2	40	0	Bottes de la jungle	For +7 · End +4	
17690	trinket	4	0	2	60	0	Insigne loup-de-givre grade 1	Rés. givre +5	
17691	trinket	4	0	2	60	0	Insigne foudrepique grade 1	Rés. givre +5	
17692	finger	4	0	2	23	0	Anneau de la corne	End +3 · Esp +2	
17704	one	2	0	2	38	33	Lame de l'hiver	End +3	c164:1
17721	hands	4	2	2	38	33	Gants du Grandpère	Dégâts sorts +24 · Soins +26	c165:1
17733	main	2	4	3	53	48	Poing de pierre	End +11 · Esp +5	
17759	trinket	4	0	2	60	0	Marque de résolution		
17769	shoulder	4	3	2	47	0	Spallières d'armoise	Agi +15	
17782	neck	4	0	5	80	60	Talisman de l'éclat de lien	For +13 · Agi +5 · End +8 · Rés. feu +24 · Rés. nature +24	
17783	neck	4	0	5	80	60	Talisman du fragment de lien	For +13 · Agi +5 · End +8 · Rés. feu +24 · Rés. nature +24	
17802	main	2	7	5	80	100	[PÉRIMÉ] Lame-tonnerre, épée bénie du Cherchevent	Agi +5 · End +8 · Rés. feu +8 · Rés. nature +9	
17900	trinket	4	0	2	60	0	Insigne foudrepique grade 2	Rés. givre +5	
17901	trinket	4	0	2	60	0	Insigne foudrepique grade 3	Esquive +12 · Rés. givre +5	
17902	trinket	4	0	3	60	0	Insigne foudrepique grade 4	Esquive +12 · Rés. givre +8	
17903	trinket	4	0	3	60	0	Insigne foudrepique grade 5	Esquive +12 · Rés. givre +10	
17904	trinket	4	0	4	60	0	Insigne foudrepique grade 6	Esquive +24 · Rés. givre +10	
17905	trinket	4	0	2	60	0	Insigne loup-de-givre grade 2	Rés. givre +5	
17906	trinket	4	0	2	60	0	Insigne loup-de-givre grade 3	Esquive +12 · Rés. givre +5	
17907	trinket	4	0	3	60	0	Insigne loup-de-givre grade 4	Esquive +12 · Rés. givre +8	
17908	trinket	4	0	3	60	0	Insigne loup-de-givre grade 5	Esquive +12 · Rés. givre +10	
17909	trinket	4	0	4	60	0	Insigne loup-de-givre grade 6	Esquive +24 · Rés. givre +10	
18023	neck	4	0	3	59	54	Pendentif en rubis de sang	End +10 · Int +10	
18168	off	4	6	4	65	60	Disque de force réactif	End +11 · Armure +80	c202:1
18238	hands	4	2	3	40	35	Gants en peau d'ombre	End +6 · Crit. +14	c165:1
18263	wrist	4	1	4	64	60	Couvre-bras Coeur-de-braise	Int +8 · Mana/5 +9 · Rés. feu +7	c197:1
18282	ranged	2	3	4	65	60	Carabine de tireur d'élite endurci	PA dist. +29 · Toucher +13	c202:1
18355	trinket	4	0	3	60	55	Collier de Ferra		
18398	finger	4	0	3	63	0	Anneau des flots	End +4 · Int +7 · Esp +4 · Rés. feu +15	
18399	finger	4	0	3	63	0	Brise de l'océan	For +4 · Agi +7 · End +4 · Rés. feu +15	
18400	finger	4	0	2	57	0	Anneau de pierre vivante	For +10 · End +9	
18402	finger	4	0	2	57	0	Anneau de cristal luminescent	End +5 · Int +12	
18403	finger	4	0	4	65	0	Chevalière du tueur de dragon	End +11 · Int +11 · Puiss. sorts +7 · Crit. +14 · Rés. feu +6	
18404	neck	4	0	4	65	0	Pendentif en dent d'Onyxia	Agi +7 · End +8 · Crit. +14 · Toucher +10 · Rés. feu +10	
18405	waist	4	1	4	62	57	Ceinture de l'archimage	End +10 · Int +16 · Puiss. sorts +20 · Crit. +14	c197:1
18406	trinket	4	0	4	65	0	Talisman de sang d'Onyxia	Rés. feu +20	
18407	hands	4	1	3	62	57	Gants en gangrétoffe	End +9	c197:1
18408	hands	4	1	3	62	57	Gants d'Inferno	Int +9	c197:1
18409	hands	4	1	3	62	57	Gants en étoffe lunaire	End +9 · Int +16 · Dégâts sorts +11 · Soins +33	c197:1
18413	back	4	1	3	62	57	Cape de sauvegarde	Déf. +5 · Armure +170	c197:1
18427	back	4	1	3	35	30	Cape de sergent	End +9 · Armure +40	
18428	neck	4	0	3	50	45	Insigne de sergent-chef	End +14 · Esp +6	
18429	wrist	4	4	3	63	58	Brassards d'adjudant en plaques	For +7 · End +17	
18430	wrist	4	4	3	50	45	Brassards d'adjudant en plaques	For +6 · End +14	
18432	wrist	4	3	3	50	45	Garde-poignets d'adjudant en mailles	End +14 · Int +6	
18434	wrist	4	2	3	63	58	Garde-bras d'adjudant en cuir de dragon	End +17 · Int +7	
18435	wrist	4	2	3	50	45	Garde-bras d'adjudant en cuir	Agi +6 · End +14	
18436	wrist	4	2	3	50	45	Garde-bras d'adjudant en cuir de dragon	End +14 · Int +6	
18437	wrist	4	1	3	50	45	Crispins d'adjudant en soie	End +14 · Int +6	
18440	back	4	1	3	35	30	Pèlerine de sergent	End +9 · Armure +40	
18441	back	4	1	3	50	45	Pèlerine de sergent	End +14 · Armure +60	
18442	neck	4	0	3	35	30	Insigne de sergent-chef	End +9 · Esp +4	
18443	neck	4	0	3	63	58	Insigne de sergent-chef	End +17 · Esp +7	
18444	neck	4	0	3	50	45	Insigne de sergent-chef	End +14 · Esp +6	
18445	wrist	4	4	3	63	58	Garde-poignets de sergent-major en plaques	For +7 · End +17	
18447	wrist	4	4	3	50	45	Garde-poignets de sergent-major en plaques	For +6 · End +14	
18448	wrist	4	3	3	63	58	Garde-bras de sergent-major en mailles	End +17 · Int +7	
18449	wrist	4	3	3	50	45	Garde-bras de sergent-major en mailles	End +14 · Int +6	
18452	wrist	4	2	3	63	58	Brachiales de sergent-major en cuir	Agi +7 · End +17	
18453	wrist	4	2	3	50	45	Brachiales de sergent-major en cuir	Agi +6 · End +14	
18454	wrist	4	2	3	63	58	Brachiales de sergent-major en cuir de dragon	End +17 · Int +7	
18455	wrist	4	2	3	50	45	Brachiales de sergent-major en cuir de dragon	End +14 · Int +6	
18456	wrist	4	1	3	63	58	Crispins de sergent-major en soie	End +17 · Int +7	
18457	wrist	4	1	3	50	45	Crispins de sergent-major en soie	End +14 · Int +6	
18461	back	4	1	3	63	58	Cape de sergent	End +17 · Armure +70	
18486	chest	4	1	3	61	56	Robe en étoffe lunaire	End +12 · Int +25 · Dégâts sorts +9 · Soins +26	c197:1
18504	waist	4	2	3	62	57	Ceinturon de clairvoyance	End +9 · Int +23 · Puiss. sorts +15	c165:1
18506	feet	4	2	3	62	57	Bottes de la mangouste	Agi +23 · End +9	c165:1
18508	wrist	4	3	3	62	57	Brassards de vol rapide	End +7 · PA dist. +41	c165:1
18509	back	4	1	4	62	57	Cape chromatique	End +10 · Crit. +14 · Rés. feu +12 · Rés. ombre +12	c165:1
18510	back	4	1	4	62	57	Peau du Fauve	End +8 · Int +10 · Dégâts sorts +14 · Soins +42	c165:1
18511	back	4	1	4	62	57	Cape changeante	Agi +17 · End +8 · Esquive +12	c165:1
18543	finger	4	0	4	66	60	Anneau d'Entropie	End +11 · Int +13 · Esp +8 · Crit. +14	
18582	one	2	7	6	100	70	Les Lames Jumelles d'Azzinoth	Agi +75 · End +100 · Int +150 · Toucher +200 · Rés. ombre +100	
18583	one	2	7	6	100	70	Glaive de guerre d'Azzinoth (droit)	Agi +40 · End +50 · Int +60 · Rés. ombre +50 · Rés. arcanes +60	
18584	one	2	7	6	100	70	Glaive de guerre d'Azzinoth (gauche)	Agi +60 · End +50 · Int +40 · Rés. ombre +60 · Rés. arcanes +50	
18585	finger	4	0	3	35	0	Anneau d'allégeance	For +9 · End +4	
18586	finger	4	0	3	35	0	Anneau de Lonetree	End +6 · Int +6 · Esp +4	
18602	off	4	0	3	60	0	Tome du Sacrifice	End +12	
18608	two	2	10	4	75	60	Bénédiction	End +10 · Int +31 · Esp +12 · Rés. ombre +20	
18609	two	2	10	4	75	60	Anathème	End +22 · Int +31 · Mana/5 +7 · Rés. ombre +20	
18634	trinket	4	0	3	52	47	Réflectoglace gyrogivre	Rés. givre +15	c202:1
18637	trinket	4	0	2	55	0	Recombobulateur majeur		c202:1
18638	trinket	4	0	3	58	53	Réflectoflamme hyper-radiant	Rés. feu +18	c202:1
18639	trinket	4	0	3	60	55	Réflectombre ultra-flash	Rés. ombre +20	c202:1
18646	trinket	4	0	4	71	60	L'Oeil de la divinité		
18665	trinket	4	0	4	71	60	L'Oeil de l'ombre		
18706	trinket	4	0	2	40	35	Maître de l'arène	End +7	
18713	ranged	2	2	4	75	60	Rhok'delar, arc long des Gardiens anciens	PA dist. +23 · Crit. +19	
18715	two	2	10	4	75	60	Lok'delar, bâton des Gardiens anciens	End +26 · Int +15 · Crit. +28 · Rés. nature +10	
18747	shoulder	4	1	3	63	58	Test propriétés d'un objet	PA +40 · Puiss. sorts +12 · Crit. +70	
18760	finger	4	0	3	62	57	Anneau nécromantique	Rés. ombre +15	
18762	off	4	0	3	54	0	Eclat de la Flamme verte	End +12	
18763	ranged	2	3	2	52	47	TEST GUN Alliance20	PA dist. +22	
18764	ranged	2	3	2	52	47	TEST GUN Raid	PA dist. +22	
18765	ranged	2	3	2	52	47	TEST GUN Horde50	PA dist. +22	
18800	main	2	4	4	67	60	TEST 1H Amberseal Keeper	Int +20 · Puiss. sorts +57 · Mana/5 +12 · Rés. feu +5 · Rés. givre +5	
18801	main	2	10	4	75	60	TEST 1H Benediction	End +10 · Int +31 · Esp +12 · Rés. ombre +20	
18807	head	4	3	3	62	0	Casque du pouvoir latent	End +12 · Int +14 · Esp +12 · Puiss. sorts +14 · Crit. +14	
18814	neck	4	0	4	78	60	Collier du Seigneur du Feu	End +7 · Int +7 · Puiss. sorts +34	
18815	trinket	4	0	4	75	60	Essence de la Flamme pure		
18820	trinket	4	0	4	66	60	Talisman de pouvoir éphémère		
18821	finger	4	0	4	67	60	Anneau de frappe rapide	For +5 · End +8 · PA +30 · Crit. +14	
18825	off	4	6	4	78	60	Egide de connétable	For +10 · End +23	
18826	off	4	6	4	78	60	Pavois de grand seigneur de guerre	For +10 · End +23	
18827	one	2	0	4	78	60	Hachette de connétable	End +7 · PA +28 · Crit. +14	
18828	one	2	0	4	78	60	Fendoir de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
18830	two	2	1	4	78	60	Découpeuse de connétable	For +26 · End +41 · Crit. +14	
18831	two	2	1	4	78	60	Hache de bataille de grand seigneur de guerre	For +26 · End +41 · Crit. +14	
18833	ranged	2	2	4	78	60	Viseur de connétable	End +9 · PA dist. +49	
18834	trinket	4	0	3	1	0	Insigne de la Horde		
18835	ranged	2	2	4	78	60	Arc courbe de grand seigneur de guerre	End +9 · PA dist. +49	
18836	ranged	2	18	4	78	60	Arme à répétition de connétable	End +9 · PA dist. +49	
18837	ranged	2	18	4	78	60	Arbalète de grand seigneur de guerre	End +9 · PA dist. +49	
18838	one	2	15	4	78	60	Miséricorde de connétable	End +7 · PA +28 · Crit. +14	
18840	one	2	15	4	78	60	Rasoir de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
18843	main	2	13	4	78	60	Lame de connétable (main droite)	End +7 · PA +28 · Crit. +14	
18844	main	2	13	4	78	60	Griffe droite de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
18845	trinket	4	0	3	1	0	Insigne de la Horde		
18846	trinket	4	0	3	1	0	Insigne de la Horde		
18847	off	2	13	4	78	60	Lame de connétable (main gauche)	End +7 · PA +28 · Crit. +14	
18848	off	2	13	4	78	60	Griffe gauche de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
18849	trinket	4	0	3	1	0	Insigne de la Horde		
18850	trinket	4	0	3	1	0	Insigne de la Horde		
18851	trinket	4	0	3	1	0	Insigne de la Horde		
18852	trinket	4	0	3	1	0	Insigne de la Horde		
18853	trinket	4	0	3	1	0	Insigne de la Horde		
18854	trinket	4	0	3	1	0	Insigne de l'Alliance		
18855	ranged	2	3	4	78	60	Canon à main de connétable	End +9 · PA dist. +49	
18856	trinket	4	0	3	1	0	Insigne de l'Alliance		
18857	trinket	4	0	3	1	0	Insigne de l'Alliance		
18858	trinket	4	0	3	1	0	Insigne de l'Alliance		
18859	trinket	4	0	3	1	0	Insigne de l'Alliance		
18860	ranged	2	3	4	78	60	Balayeur de rue de grand seigneur de guerre	End +9 · PA dist. +49	
18862	trinket	4	0	3	1	0	Insigne de l'Alliance		
18863	trinket	4	0	3	1	0	Insigne de l'Alliance		
18864	trinket	4	0	3	1	0	Insigne de l'Alliance		
18865	one	2	4	4	78	60	Punisseur de connétable	End +7 · PA +28 · Crit. +14	
18866	one	2	4	4	78	60	Massue de grand seigneur de guerre	End +7 · PA +28 · Crit. +14	
18867	two	2	5	4	78	60	Marteau d'armes de connétable	For +26 · End +41 · Crit. +14	
18868	two	2	5	4	78	60	Pulvériseur de seigneur de guerre	For +26 · End +41 · Crit. +14	
18869	two	2	6	4	78	60	Vouge de connétable	For +26 · End +41 · Crit. +14	
18871	two	2	6	4	78	60	Aiguillon de grand seigneur de guerre	For +26 · End +41 · Crit. +14	
18873	two	2	10	4	78	60	Bâton de connétable	End +41 · Int +23 · Esp +17 · Puiss. sorts +71	
18874	two	2	10	4	78	60	Bâton de guerre de grand seigneur de guerre	End +41 · Int +23 · Esp +17	
18876	two	2	8	4	78	60	Claymore de connétable	For +26 · End +41 · Crit. +14	
18877	two	2	8	4	78	60	Grande épée de grand seigneur de guerre	For +26 · End +41 · Crit. +14	
18879	finger	4	0	4	66	60	Anneau épais en sombrefer	End +20 · Déf. +5 · Armure +110	
18881	two	2	5	5	80	60	TEST Ragnaros Hammer	For +12 · End +12 · Rés. feu +30	
18882	two	2	8	4	80	60	TEST Level 80 Epic	Crit. +14	
18948	wrist	4	2	3	32	27	Brassards barbares	For +4 · Agi +4 · End +6	c165:1
18951	trinket	4	0	2	50	0	Oreiller d'atterrissage d'Evonice	Esp +10	
18957	one	2	7	2	10	0	Lame des broussailles	End +1	
18968	finger	4	0	4	60	0	Ring of Critical Testing	Crit. +700	
18970	finger	4	0	4	60	0	Ring of Critical Testing 2	Crit. +700	
18971	finger	4	0	4	60	0	Ring of Critical Testing 3		
18982	finger	4	0	4	60	0	Ring of Critical Testing 4	Crit. +700	
19019	one	2	7	5	80	60	Lame-tonnerre, épée bénie du Cherchevent	Agi +5 · End +8 · Rés. feu +8 · Rés. nature +9	
19022	two	2	20	2	50	0	FC-5000 de Nat Pagle, pêcheur de l'extrême		
19024	trinket	4	0	3	55	50	Grand maître de l'arène	Esquive +12	
19037	shoulder	4	4	2	48	0	Spallières du pic d'Emeraude	For +7 · Agi +6 · End +10	
19038	finger	4	0	2	48	0	Anneau de subtilité	Mana/5 +4	
19039	head	4	2	2	48	0	Chapeau imperméable de Zorbin	End +9 · Int +14 · Esp +8	
19040	one	2	7	2	48	0	Méga-trancheur de Zorbin	Agi +6 · End +5	
19041	chest	4	2	2	48	0	Tunique artisanale de Pratt	For +6 · Agi +7 · End +15	
19042	chest	4	2	2	48	0	Tunique artisanale de Jangdor	For +6 · Agi +7 · End +15	
19043	waist	4	3	3	58	53	Ceinture épaisse grumegueule	End +9 · PA +42	c165:1
19044	waist	4	2	3	58	53	Pouvoir des Grumegueules	For +21 · Agi +14 · End +9	c165:1
19047	waist	4	1	3	58	53	Sagesse des Grumegueules	Int +14 · Esp +9 · Dégâts sorts +11 · Soins +31	c197:1
19048	feet	4	3	3	61	56	Bottes lourdes grumegueule	End +21 · PA +20	c165:1
19049	hands	4	2	3	61	56	Batailleurs grumegueules	For +21 · Agi +14 · End +9	c165:1
19050	shoulder	4	1	3	61	56	Mantelet des Grumegueules	Int +13 · Puiss. sorts +17 · Crit. +14	c197:1
19051	waist	4	4	3	58	53	Ceinturon de l'Aube	For +21 · End +9	c164:1
19052	feet	4	2	3	58	53	Demi-bottes de l'aube	For +9 · Agi +14 · End +18	c165:1
19056	feet	4	1	3	58	53	Bottes de l'Aube d'argent	End +21 · Puiss. sorts +8 · Rés. ombre +4	c197:1
19057	hands	4	4	3	61	56	Gants de l'Aube	For +21 · End +9	c164:1
19058	shoulder	4	2	3	61	56	Mantelet doré de l'Aube	For +13 · Agi +11 · End +20	c165:1
19059	shoulder	4	1	3	61	56	Epaulières de l'Aube d'argent	Esp +7 · Puiss. sorts +25 · Rés. ombre +5	c197:1
19065	finger	4	0	3	59	0	Cercle d'émeraude	End +14 · Esp +8	
19083	back	4	1	3	60	55	Cape de légionnaire loup-de-givre	End +11 · PA +24 · Rés. givre +5	
19084	back	4	1	3	60	55	Cape de soldat foudrepique	End +11 · PA +24 · Rés. givre +5	
19085	back	4	1	3	60	55	Cape de conseiller loup-de-givre	End +11 · Puiss. sorts +14 · Rés. givre +5	
19086	back	4	1	3	60	55	Cape de sage foudrepique	End +11 · Puiss. sorts +14 · Rés. givre +5	
19087	waist	4	4	3	60	55	Ceinture de plaques loup-de-givre	For +18 · Agi +7 · End +8 · Rés. givre +5	
19088	waist	4	3	3	60	55	Ceinture de mailles loup-de-givre	Agi +12 · End +12 · Int +12 · Rés. givre +5	
19089	waist	4	2	3	60	55	Ceinture de cuir loup-de-givre	For +11 · Agi +10 · End +15 · Rés. givre +5	
19090	waist	4	1	3	60	55	Ceinture de tissu loup-de-givre	End +11 · Int +10 · Puiss. sorts +18 · Rés. givre +5	
19091	waist	4	4	3	60	55	Ceinturon foudrepique en plaques	For +18 · Agi +7 · End +8 · Rés. givre +5	
19092	waist	4	3	3	60	55	Ceinturon foudrepique en mailles	Agi +12 · End +12 · Int +12 · Rés. givre +5	
19093	waist	4	2	3	60	55	Ceinturon foudrepique en cuir	For +11 · Agi +10 · End +15 · Rés. givre +5	
19094	waist	4	1	3	60	55	Ceinturon foudrepique en tissu	End +11 · Int +10 · Puiss. sorts +18 · Rés. givre +5	
19095	neck	4	0	3	60	55	Pendentif de légionnaire loup-de-givre	End +15 · PA +18	
19096	neck	4	0	3	60	55	Pendentif de conseiller loup-de-givre	End +10 · Int +10 · Mana/5 +4	
19097	neck	4	0	3	60	55	Pendentif de soldat foudrepique	End +15 · PA +18	
19098	neck	4	0	3	60	55	Pendentif de sage foudrepique	End +10 · Int +10 · Mana/5 +4	
19099	one	2	15	3	65	60	Lame glaciale	Agi +10	
19100	one	2	15	3	65	60	Dague électrifiée	Agi +10	
19101	two	2	10	3	65	60	Bâton blanchi	End +25 · Int +16	
19102	two	2	10	3	65	60	Bâton crépitant	Int +25 · Puiss. sorts +25	
19103	one	2	0	3	65	60	Frimaire	For +15	
19104	one	2	4	3	65	60	Marteau foudrepique	For +15	
19106	two	2	6	3	63	0	Lance de glace barbelée	For +13 · Agi +21 · End +20	
19107	ranged	2	18	3	63	0	Sanguinaire	For +11 · Agi +10	
19108	ranged	2	19	3	63	0	Baguette du froid mordant		
19109	finger	4	0	3	63	58	Anneau des racines profondes	End +10 · Int +10 · Puiss. sorts +12	
19114	ranged	2	2	2	51	0	Arc des Hautes-terres	Agi +6 · End +5	
19115	off	4	0	2	51	0	Flacon de mojo sylvestre	Int +8 · Puiss. sorts +9	
19116	hands	4	1	2	50	0	Protège-mains vertefeuille	Int +11 · Dégâts sorts +7 · Soins +22	
19117	legs	4	4	2	50	0	Cuissards de plaques de bois laquées	For +17 · End +10	
19118	ranged	2	19	2	50	0	Souffle de la Nature	End +4 · Int +8	
19119	hands	4	2	2	50	0	Gants en cuir de chouettard	End +8 · Int +9 · Esp +8	
19120	trinket	4	0	2	51	0	Rune de capitaine de la garde	Toucher +7	
19121	back	4	1	3	51	0	Cape des bois profonds	End +6 · Int +9 · Puiss. sorts +12	
19123	hands	4	1	2	48	0	Protège-mains calorifères	Int +10 · Mana/5 +4	
19124	legs	4	4	2	48	0	Jambières de plaques mâchefer	For +12 · End +12 · Déf. +3	
19125	waist	4	3	2	49	0	Ceinturon de mailles calcinées	Agi +12 · End +7	
19126	hands	4	4	2	49	0	Gantelets de plaques mâchefer	For +12 · End +7	
19127	chest	4	2	2	50	0	Tunique carbonisée en cuir	Agi +18 · End +8	
19128	chest	4	3	2	50	0	Haubergeon calciné	Agi +11 · End +11 · Int +11	
19129	chest	4	1	2	49	0	Robe brasillante	Int +11 · Esp +11 · Puiss. sorts +13	
19138	finger	4	0	4	78	60	Anneau de Sulfuras	End +13 · Int +23 · Esp +10	
19140	finger	4	0	4	71	60	Anneau de cautérisation	End +9 · Int +12 · Dégâts sorts +15 · Soins +46	
19141	trinket	4	0	2	50	0	Chiffon		
19147	finger	4	0	4	66	60	Anneau de puissance de sort	Puiss. sorts +33	
19148	head	4	4	4	66	60	Heaume en sombrefer	End +20 · Armure +150 · Rés. feu +35	c164:1
19149	waist	4	2	4	66	60	Ceinture de lave	End +15 · Armure +110 · Rés. feu +26	c165:1
19156	chest	4	1	4	66	60	Robe Coeur-de-braise	End +35 · Puiss. sorts +23 · Rés. feu +15	c197:1
19157	hands	4	3	4	70	60	Gantelets chromatiques	PA +44 · Crit. +14 · Rés. feu +5 · Rés. givre +5 · Rés. nature +5	c165:1
19158	two	2	5	5	80	60	TEST Sulfuras, Hand of Ragnaros	For +12 · End +12 · Rés. feu +30	
19159	neck	4	0	3	51	0	Collier de lierre tressé	For +6 · Agi +9 · End +10	
19162	waist	4	2	4	70	60	Ceinture du Magma	Int +16 · Dégâts sorts +21 · Soins +62 · Rés. feu +12	c165:1
19163	waist	4	2	4	70	60	Ceinture de la fournaise	Agi +28 · End +16 · Rés. feu +12	c165:1
19164	hands	4	4	4	70	60	Gantelets en sombrefer	Agi +12 · End +16 · Rés. feu +28	c164:1
19165	legs	4	1	4	70	60	Jambières Coeur-de-braise	End +21 · Puiss. sorts +43 · Rés. feu +16	c197:1
19166	one	2	15	4	66	60	Amnistie noire		c164:1
19167	two	2	6	4	66	60	Fureur noire	For +35 · End +15 · Crit. +14 · Rés. feu +10	c164:1
19168	one	2	7	4	70	60	Garde noire	End +12	c164:1
19169	two	2	1	4	70	60	Crépuscule		c164:1
19170	one	2	4	4	70	60	Main d'ébène	End +9 · Rés. feu +7	c164:1
19184	two	2	1	3	63	58	3800 Test 2h Axe 63 blue		
19185	two	2	1	3	63	58	2100 Test 2h Axe 63 blue		
19186	two	2	1	3	63	58	2700 Test 2h Axe 63 blue		
19187	two	2	1	3	63	58	3200 Test 2h Axe 63 blue		
19188	two	2	1	3	63	58	2200 Test 2h Axe 63 blue		
19189	two	2	1	3	63	58	2300 Test 2h Axe 63 blue		
19190	two	2	1	3	63	58	2400 Test 2h Axe 63 blue		
19191	two	2	1	3	63	58	2500 Test 2h Axe 63 blue		
19192	two	2	1	3	63	58	2600 Test 2h Axe 63 blue		
19193	two	2	1	3	63	58	2800 Test 2h Axe 63 blue		
19194	two	2	1	3	63	58	2900 Test 2h Axe 63 blue		
19195	two	2	1	3	63	58	3000 Test 2h Axe 63 blue		
19196	two	2	1	3	63	58	3100 Test 2h Axe 63 blue		
19197	two	2	1	3	63	58	3300 Test 2h Axe 63 blue		
19198	two	2	1	3	63	58	3400 Test 2h Axe 63 blue		
19199	two	2	1	3	63	58	3500 Test 2h Axe 63 blue		
19200	two	2	1	3	63	58	3600 Test 2h Axe 63 blue		
19201	two	2	1	3	63	58	3700 Test 2h Axe 63 blue		
19287	trinket	4	0	4	66	60	Carte de Sombrelune : Héroïsme		
19288	trinket	4	0	4	66	60	Carte de Sombrelune : Dragon bleu		
19289	trinket	4	0	4	66	60	Carte de Sombrelune : Maelström		
19290	trinket	4	0	4	66	60	Carte de Sombrelune : Néant distordu		
19302	finger	4	0	3	55	50	Anneau de Sombrelune	End +14	
19303	neck	4	0	3	55	50	Collier de Sombrelune	Int +6 · Mana/5 +6	
19308	off	4	0	4	65	60	Tome de domination des arcanes	Mana/5 +3	
19309	off	4	0	4	65	60	Tome de force d'ombre	End +8	
19310	off	4	0	4	65	60	Tome du Seigneur de glace	Int +9	
19311	off	4	0	4	65	60	Tome de l'arcane ardente		
19312	off	4	0	4	65	60	Lei du Donneur de vie	End +12 · Dégâts sorts +13 · Soins +40 · Mana/5 +5	
19313	one	2	15	3	63	58	1300 Test Dagger 63 blue		
19314	one	2	15	3	63	58	2000 Test Dagger 63 blue		
19315	off	4	0	4	65	60	Toucher de Therazane	Puiss. sorts +31	
19321	off	4	6	4	65	60	L'Objet inébranlable	End +15	
19323	two	2	5	4	65	60	La Force irrésistible	For +19 · End +15 · Crit. +28	
19324	one	2	15	4	65	60	Le Lobotomiseur		
19325	finger	4	0	4	65	60	Anneau de Don Julio	End +11 · PA +16 · Crit. +14 · Toucher +10	
19336	trinket	4	0	4	76	60	Gemme imprégnée d'arcanes		
19337	trinket	4	0	4	76	60	Le Livre noir		
19339	trinket	4	0	4	76	60	Gemme de vivacité d'esprit		
19340	trinket	4	0	4	76	60	Rune de transformation		
19341	trinket	4	0	4	76	60	Gemme donneuse de vie		
19342	trinket	4	0	4	76	60	Totem venimeux		
19343	trinket	4	0	4	76	60	Parchemin de lumière aveuglante		
19344	trinket	4	0	4	76	60	Cristal d'alignement sur la nature		
19345	trinket	4	0	4	76	60	Egide de préservation		
19366	off	4	0	4	83	60	Orbe du Maître-tueur de dragon	End +10 · Int +14 · Puiss. sorts +28	
19371	neck	4	0	4	74	60	Pendentif du dragon déchu	End +9 · Int +12 · Mana/5 +9	
19376	finger	4	0	4	83	60	Bague de rétorsion d'Archimtiros	Agi +14 · End +28	
19377	neck	4	0	4	83	60	Talisman de perfidie de Prestor	Agi +30 · Toucher +10	
19379	trinket	4	0	4	83	60	Larme de Neltharion	Puiss. sorts +44 · Toucher +20	
19382	finger	4	0	4	83	60	Anneau d'élémentium pur	End +9 · Int +10 · Esp +10 · Soins +53	
19383	neck	4	0	4	83	60	Médaillon du Maître-tueur de dragon	Agi +14 · End +24 · Déf. +7	
19384	finger	4	0	4	83	60	Bague du Maître-tueur de dragon	End +14 · PA +48 · Toucher +10	
19395	trinket	4	0	4	75	60	Gemme de récupération	Soins +66 · Mana/5 +9	
19397	finger	4	0	4	75	60	Bague de Rochenoire	Puiss. sorts +19 · Mana/5 +9	
19403	finger	4	0	4	75	60	Anneau de Concentration forcée	End +9 · Int +12 · Puiss. sorts +21 · Toucher +10	
19406	trinket	4	0	4	75	60	Talisman croc-de-drake	PA +56 · Toucher +20 · Esquive +12	
19426	neck	4	0	4	65	60	Orbe de Sombrelune	End +11 · Esp +8 · Puiss. sorts +22	
19427	one	2	7	3	63	58	1500 Test sword 63 blue		
19428	one	2	7	3	63	58	2900 Test sword 63 blue		
19431	trinket	4	0	4	75	60	Scarabée d'obstruction de Styleen	Déf. +13 · Blocage +25	
19432	finger	4	0	4	75	60	Cercle de la force appliquée	For +12 · Agi +22 · End +9	
19434	finger	4	0	4	70	60	Anneau de sombre domination	End +12 · Int +6	
19455	two	2	1	4	70	60	3500 Test 2h Axe 70 purple		
19456	one	2	7	4	80	60	2900 Test sword 80 purple		
19457	one	2	7	4	80	60	1500 Test sword 80 purple		
19489	ranged	2	18	3	63	60	3300 Test Crossbow 63 blue		
19490	ranged	2	2	3	63	60	2800 Test Bow 63 Blue		
19491	neck	4	0	4	65	60	Amulette de la Sombrelune	For +10 · Agi +19 · End +10	
19502	one	2	7	3	63	58	2200 Test sword 63 blue		
19503	one	2	7	4	80	58	2200 Test sword 80 purple		
19504	one	2	7	4	70	58	2200 Test sword 70 purple		
19510	finger	4	0	3	63	58	Anneau de légionnaire	For +12 · Agi +11 · End +8	
19511	finger	4	0	3	53	48	Anneau de légionnaire	For +10 · Agi +9 · End +6	
19512	finger	4	0	3	43	38	Anneau de légionnaire	For +8 · Agi +8 · End +5	
19513	finger	4	0	3	33	28	Anneau de légionnaire	For +6 · Agi +6 · End +4	
19514	finger	4	0	3	63	58	Anneau de protecteur	For +12 · Agi +11 · End +8	
19515	finger	4	0	3	43	38	Anneau de protecteur	For +8 · Agi +8 · End +5	
19516	finger	4	0	3	53	48	Anneau de protecteur	For +10 · Agi +9 · End +6	
19517	finger	4	0	3	33	28	Anneau de protecteur	For +6 · Agi +6 · End +4	
19518	finger	4	0	3	63	58	Bague de conseiller	End +8 · Puiss. sorts +14 · Mana/5 +4	
19519	finger	4	0	3	53	48	Bague de conseiller	End +6 · Puiss. sorts +12 · Mana/5 +4	
19520	finger	4	0	3	43	38	Bague de conseiller	End +5 · Puiss. sorts +9 · Mana/5 +3	
19521	finger	4	0	3	33	28	Bague de conseiller	End +4 · Puiss. sorts +7 · Mana/5 +2	
19522	finger	4	0	3	63	58	Bague de gardien du savoir	End +8 · Puiss. sorts +14 · Mana/5 +4	
19523	finger	4	0	3	53	48	Bague de gardien du savoir	End +6 · Puiss. sorts +12 · Mana/5 +4	
19524	finger	4	0	3	43	38	Bague de gardien du savoir	End +5 · Puiss. sorts +9 · Mana/5 +3	
19525	finger	4	0	3	33	28	Bague de gardien du savoir	End +4 · Puiss. sorts +7 · Mana/5 +2	
19526	back	4	1	3	63	58	Cape de soigneur de bataille	End +11 · Esp +8 · Dégâts sorts +9 · Soins +26	
19527	back	4	1	3	53	48	Cape de soigneur de bataille	End +9 · Esp +6 · Dégâts sorts +7 · Soins +22	
19528	back	4	1	3	43	38	Cape de soigneur de bataille	End +8 · Esp +5 · Dégâts sorts +6 · Soins +18	
19529	back	4	1	3	33	28	Cape de soigneur de bataille	End +6 · Esp +4 · Dégâts sorts +4 · Soins +13	
19530	back	4	1	3	63	58	Cape de conservateur	End +11 · Esp +8 · Dégâts sorts +9 · Soins +26	
19531	back	4	1	3	53	48	Cape de conservateur	End +9 · Esp +6 · Dégâts sorts +7 · Soins +22	
19532	back	4	1	3	43	38	Cape de conservateur	End +8 · Esp +5 · Dégâts sorts +6 · Soins +18	
19533	back	4	1	3	33	28	Cape de conservateur	End +6 · Esp +4 · Dégâts sorts +4 · Soins +13	
19534	neck	4	0	3	63	58	Médaillon d'éclaireur	Agi +15 · End +10	
19535	neck	4	0	3	53	48	Médaillon d'éclaireur	Agi +12 · End +8	
19536	neck	4	0	3	43	38	Médaillon d'éclaireur	Agi +11 · End +7	
19537	neck	4	0	3	33	28	Médaillon d'éclaireur	Agi +8 · End +5	
19538	neck	4	0	3	63	58	Médaillon de sentinelle	Agi +15 · End +10	
19539	neck	4	0	3	53	48	Médaillon de sentinelle	Agi +12 · End +8	
19540	neck	4	0	3	43	38	Médaillon de sentinelle	Agi +11 · End +7	
19541	neck	4	0	3	33	28	Médaillon de sentinelle	Agi +8 · End +5	
19542	one	2	15	3	63	58	Lame d'éclaireur	Agi +13 · End +5	
19543	one	2	15	3	53	48	Lame d'éclaireur	Agi +11 · End +5	
19544	one	2	15	3	43	38	Lame d'éclaireur	Agi +8 · End +3	
19545	one	2	15	3	33	28	Lame d'éclaireur	Agi +7 · End +3	
19546	one	2	15	3	63	58	Lame de sentinelle	Agi +13 · End +5	
19547	one	2	15	3	53	48	Lame de sentinelle	Agi +11 · End +5	
19548	one	2	15	3	43	38	Lame de sentinelle	Agi +8 · End +3	
19549	one	2	15	3	33	28	Lame de sentinelle	Agi +7 · End +3	
19550	one	2	7	3	63	58	Epée de légionnaire	For +13 · End +5	
19551	one	2	7	3	53	48	Epée de légionnaire	For +11 · End +5	
19552	one	2	7	3	43	38	Epée de légionnaire	For +8 · End +3	
19553	one	2	7	3	33	28	Epée de légionnaire	For +7 · End +3	
19554	one	2	7	3	63	58	Epée de protecteur	For +13 · End +5	
19555	one	2	7	3	53	48	Epée de protecteur	For +11 · End +5	
19556	one	2	7	3	43	38	Epée de protecteur	For +8 · End +3	
19557	one	2	7	3	33	28	Epée de protecteur	For +7 · End +3	
19558	ranged	2	2	3	63	58	Arc de voltigeur	Agi +5 · End +14	
19559	ranged	2	2	3	53	48	Arc de voltigeur	Agi +4 · End +10	
19560	ranged	2	2	3	43	38	Arc de voltigeur	Agi +4 · End +8	
19561	ranged	2	2	3	33	28	Arc de voltigeur	Agi +3 · End +6	
19562	ranged	2	2	3	63	58	Arc d'estafette	Agi +5 · End +14	
19563	ranged	2	2	3	53	48	Arc d'estafette	Agi +4 · End +10	
19564	ranged	2	2	3	43	38	Arc d'estafette	Agi +4 · End +8	
19565	ranged	2	2	3	33	28	Arc d'estafette	Agi +3 · End +6	
19566	two	2	10	3	63	58	Bâton noueux de conseiller	End +21 · Int +13 · Mana/5 +8	
19567	two	2	10	3	53	48	Bâton noueux de conseiller	End +18 · Int +11 · Mana/5 +7	
19568	two	2	10	3	43	38	Bâton noueux de conseiller	End +14 · Int +9 · Mana/5 +6	
19569	two	2	10	3	33	28	Bâton noueux de conseiller	End +11 · Int +7 · Mana/5 +4	
19570	two	2	10	3	63	58	Bâton de gardien du savoir	End +21 · Int +13 · Mana/5 +8	
19571	two	2	10	3	53	48	Bâton de gardien du savoir	End +18 · Int +11 · Mana/5 +7	
19572	two	2	10	3	43	38	Bâton de gardien du savoir	End +14 · Int +9 · Mana/5 +6	
19573	two	2	10	3	33	28	Bâton de gardien du savoir	End +11 · Int +7 · Mana/5 +4	
19574	neck	4	0	2	60	0	Force de Mugamba	For +7 · End +10 · Déf. +4	
19575	neck	4	0	3	60	0	Force de Mugamba	For +7 · Agi +6 · End +10 · Déf. +4	
19576	neck	4	0	3	68	0	Force de Mugamba	For +8 · Agi +8 · End +13 · Déf. +5	
19577	neck	4	0	4	65	0	Rage de Mugamba	For +8 · Agi +8 · End +13 · Déf. +6 · Blocage +10	
19578	wrist	4	4	4	65	60	Brassards de berserker	For +19 · Agi +8 · End +11	
19579	neck	4	0	2	60	0	Marque du païen	For +8 · End +8 · Esp +7	
19580	wrist	4	4	4	55	50	Brassards de berserker	For +17 · Agi +7 · End +9	
19581	wrist	4	4	4	45	40	Brassards de berserker	For +14 · Agi +6 · End +8	
19582	wrist	4	3	4	65	60	Garde-poignets de messager du vent	End +8 · Int +8 · Esp +7 · PA +38	
19583	wrist	4	3	4	55	50	Garde-poignets de messager du vent	End +7 · Int +6 · Esp +6 · PA +34	
19584	wrist	4	3	4	45	40	Garde-poignets de messager du vent	End +6 · Int +6 · Esp +5 · PA +28	
19585	neck	4	0	3	60	0	Marque du païen	For +8 · End +8 · Int +6 · Esp +7	
19586	neck	4	0	3	68	0	Marque du païen	For +10 · End +10 · Int +6 · Esp +9	
19587	wrist	4	2	4	65	60	Brassards de traqueuse sylvestre	For +11 · Agi +19 · End +8	
19588	neck	4	0	4	65	0	Marque de héros	For +10 · End +10 · Int +6 · Esp +9	
19589	wrist	4	2	4	55	50	Brassards de traqueuse sylvestre	For +9 · Agi +17 · End +7	
19590	wrist	4	2	4	45	40	Brassards de traqueuse sylvestre	For +8 · Agi +14 · End +6	
19591	neck	4	0	2	60	0	L'Oeil de Zuldazar	End +6 · Int +7 · Esp +10	
19592	neck	4	0	3	60	0	L'Oeil de Zuldazar	End +6 · Int +7 · Esp +10 · Soins +13	
19593	neck	4	0	3	68	0	L'Oeil de Zuldazar	End +8 · Int +8 · Esp +13 · Soins +18	
19594	neck	4	0	4	65	0	L'Oeil omnivoyant de Zuldazar	End +8 · Int +8 · Esp +13 · Soins +18	
19595	wrist	4	1	4	65	60	Manchettes de dryade	End +8 · Int +8 · Esp +7 · Puiss. sorts +22	
19596	wrist	4	1	4	55	50	Manchettes de dryade	End +7 · Int +6 · Esp +6 · Puiss. sorts +20	
19597	wrist	4	1	4	45	40	Manchettes de dryade	End +6 · Int +6 · Esp +5 · Puiss. sorts +16	
19598	neck	4	0	2	60	0	Caillou de Kajaro	End +7 · Int +10 · Puiss. sorts +7	
19599	neck	4	0	3	60	0	Caillou de Kajaro	End +7 · Int +10 · Esp +6 · Puiss. sorts +7	
19600	neck	4	0	3	68	0	Caillou de Kajaro	End +8 · Int +13 · Esp +8 · Puiss. sorts +9	
19601	neck	4	0	4	65	0	Joyau de Kajaro	End +8 · Int +13 · Esp +8 · Puiss. sorts +9	
19602	neck	4	0	2	60	0	Souillure de Kezan	End +10 · Puiss. sorts +12	
19603	neck	4	0	3	60	0	Souillure de Kezan	End +10 · Int +6 · Puiss. sorts +12	
19604	neck	4	0	3	68	0	Souillure de Kezan	End +13 · Int +8 · Puiss. sorts +14	
19605	neck	4	0	4	65	0	Souillure irrésistible de Kezan	End +13 · Int +8 · Puiss. sorts +14	
19606	neck	4	0	2	60	0	Vision de Voodress	End +8 · Int +8 · Esp +7	
19607	neck	4	0	3	60	0	Vision de Voodress	For +6 · End +8 · Int +8 · Esp +7	
19608	neck	4	0	3	68	0	Vision de Voodress	For +6 · End +10 · Int +10 · Esp +9	
19609	neck	4	0	4	65	0	Vision limpide de Voodress	For +6 · End +10 · Int +10 · Esp +9	
19610	neck	4	0	2	60	0	Varech enchanté des Mers du sud	End +8 · Int +8 · Esp +7	
19611	neck	4	0	3	60	0	Varech enchanté des Mers du sud	For +6 · End +8 · Int +8 · Esp +7	
19612	neck	4	0	3	68	0	Varech enchanté des Mers du sud	For +6 · End +10 · Int +10 · Esp +9	
19613	neck	4	0	4	65	0	Varech enchanté des Mers du sud en parfait état	For +6 · End +10 · Int +10 · Esp +9	
19614	neck	4	0	2	60	0	Talisman de l'ombre zandalarien	Agi +12 · End +7	
19615	neck	4	0	3	60	0	Talisman de l'ombre zandalarien	For +6 · Agi +12 · End +7	
19616	neck	4	0	3	68	0	Talisman de l'ombre zandalarien	For +6 · Agi +15 · End +9	
19617	neck	4	0	4	65	0	Talisman de maîtrise de l'ombre zandalarien	For +6 · Agi +15 · End +9	
19618	neck	4	0	2	60	0	Vrille du maelström	Agi +12 · End +7	
19619	neck	4	0	3	60	0	Vrille du maelström	Agi +12 · End +7 · Int +6	
19620	neck	4	0	3	68	0	Vrille du maelström	Agi +15 · End +9 · Int +6	
19621	neck	4	0	4	65	0	Courroux du maelström	Agi +15 · End +9 · Int +6	
19622	one	2	15	3	63	58	1800 Test Dagger 63 blue		
19662	two	2	1	4	80	60	3500 Test 2h Axe 80 purple		
19682	chest	4	1	3	65	60	Gilet en vignesang	Int +13 · Puiss. sorts +27 · Toucher +20	c197:1
19683	legs	4	1	3	65	60	Jambières  en vignesang	Int +6 · Puiss. sorts +37 · Toucher +10	c197:1
19684	feet	4	1	3	65	60	Bottes en vignesang	Int +16 · Puiss. sorts +19 · Toucher +10	c197:1
19685	chest	4	2	3	65	60	Pourpoint en peau de chauve-souris primordiale	Agi +32 · End +6 · Toucher +10	c165:1
19686	hands	4	2	3	65	60	Gants en peau de chauve-souris primordiale	Agi +10 · End +9 · Toucher +20	c165:1
19687	wrist	4	2	3	65	60	Brassards en peau de chauve-souris primordiale	Agi +14 · End +7 · Toucher +10	c165:1
19688	chest	4	2	3	65	60	Cuirasse du tigre-sang	For +17 · End +17 · Int +16 · Esp +13	c165:1
19689	shoulder	4	2	3	65	60	Epaulières du tigre-sang	For +13 · End +13 · Int +12 · Esp +10	c165:1
19690	chest	4	3	3	65	60	Cuirasse d'âmesang	Agi +9 · End +13 · Crit. +28	c164:1
19691	shoulder	4	3	3	65	60	Epaulières d'âmesang	Agi +24 · End +10	c164:1
19692	hands	4	3	3	65	60	Gantelets d'âmesang	Agi +10 · End +17 · Crit. +14	c164:1
19693	chest	4	4	3	65	60	Cuirasse de ténébrâme	End +32 · Toucher +10 · Armure +60	c164:1
19694	legs	4	4	3	65	60	Jambières de ténébrâme	End +22 · Toucher +20 · Armure +130	c164:1
19695	shoulder	4	4	3	65	60	Epaulières de ténébrâme	End +24 · Toucher +10	c164:1
19742	legs	4	2	3	60	55	Earthborn Kilt TEST	End +12 · Esp +29	
19743	head	4	2	2	38	33	Cloaked Hood TEST	Agi +10 · End +10	
19809	two	2	1	3	60	58	2500 Test 2h Axe 60 blue		
19810	one	2	15	3	60	58	1000 Test dagger 60 blue		
19811	two	2	1	3	60	58	2500 Test 2h Axe 60 blue (bear)		
19822	chest	4	4	4	65	0	Cuirasse de redresseur de torts zandalar	For +23 · Agi +15 · End +24 · Déf. +4 · Armure +90	
19823	waist	4	4	4	61	0	Ceinture de redresseur de torts zandalar	For +25 · End +10 · Crit. +14	
19824	wrist	4	4	4	61	0	Garde-bras de redresseur de torts zandalar	For +13 · Agi +13 · End +13	
19825	chest	4	4	4	65	0	Cuirasse de libre-penseur zandalar	For +19 · End +26 · Int +16 · Esp +7 · Crit. +14	
19826	waist	4	4	4	61	0	Ceinture de libre-penseur zandalar	For +16 · Agi +10 · End +16 · Int +12 · Soins +26	
19827	wrist	4	4	4	61	0	Garde-bras de libre-penseur zandalar	For +12 · Agi +6 · End +12 · Int +10 · Soins +11	
19828	chest	4	3	4	65	0	Haubert d'augure zandalar	End +19 · Int +15 · Puiss. sorts +34 · Crit. +14	
19829	waist	4	3	4	61	0	Ceinture d'augure zandalar	End +10 · Int +21 · Puiss. sorts +12 · Mana/5 +4	
19830	wrist	4	3	4	61	0	Brassards d'augure zandalar	End +12 · Int +11 · Puiss. sorts +13 · Mana/5 +4	
19831	shoulder	4	3	4	68	0	Mantelet de prédateur zandalar	Agi +22 · End +15 · Int +11 · Mana/5 +4	
19832	waist	4	3	4	61	0	Ceinture de prédateur zandalar	Agi +20 · End +12 · Int +12 · Esp +9 · Toucher +10	
19833	wrist	4	3	4	61	0	Brassards de prédateur zandalar	End +10 · Int +10 · PA dist. +34 · Mana/5 +4	
19834	chest	4	2	4	65	0	Tunique d'insensé zandalar	End +19 · PA +44 · Crit. +28	
19835	shoulder	4	2	4	61	0	Mantelet d'insensé zandalar	For +12 · Agi +20 · End +12 · Toucher +10	
19836	wrist	4	2	4	61	0	Brassards d'insensé zandalar	For +9 · Agi +14 · End +14	
19837	ranged	4	2	3	65	0	Test Ranged Slot	Mana/5 +21	
19838	chest	4	2	4	65	0	Tunique d'haruspice zandalar	End +15 · Int +24 · Esp +23 · Soins +33 · Armure +90	
19839	waist	4	2	4	61	0	Ceinture d'haruspice zandalar	End +10 · Int +21 · Esp +12 · Soins +15 · Armure +60	
19840	wrist	4	2	4	61	0	Brassards d'haruspice zandalar	End +9 · Int +11 · Esp +11 · Soins +24 · Armure +40	
19841	shoulder	4	1	4	68	0	Mantelet de confesseur zandalar	End +11 · Int +24 · Esp +15 · Soins +22	
19842	waist	4	1	4	61	0	Cordon de confesseur zandalar	End +12 · Int +20 · Esp +12 · Soins +26	
19843	wrist	4	1	4	61	0	Couvre-bras de confesseur zandalar	End +10 · Int +11 · Esp +12 · Soins +24	
19844	chest	4	1	4	65	0	[PÉRIMÉ] Veste d'illusionniste zandalar	End +23 · Int +24 · Puiss. sorts +16 · Toucher +20	
19845	shoulder	4	1	4	61	0	Mantelet d'illusionniste zandalar	End +13 · Int +21 · Esp +10 · Puiss. sorts +12	
19846	wrist	4	1	4	61	0	Couvre-bras d'illusionniste zandalar	End +11 · Int +11 · Esp +9 · Puiss. sorts +14	
19847	chest	4	1	4	65	0	[PÉRIMÉ] Veste de démoniaque zandalar	End +35 · Puiss. sorts +16 · Toucher +20	
19848	wrist	4	1	4	61	0	Couvre-bras de démoniaque zandalar	End +15 · Int +8 · Puiss. sorts +16	
19849	shoulder	4	1	4	61	0	Mantelet de démoniaque zandalar	End +23 · Int +19 · Puiss. sorts +12	
19868	ranged	2	2	4	66	60	[PÉRIMÉ] Aiguillon de Mandokir	Agi +15 · End +11	
19884	two	2	10	4	66	60	Jugement de Jin'do	End +10 · Int +10 · Toucher +20 · Mana/5 +14	
19926	chest	4	1	4	63	60	[PÉRIMÉ] Veste rituelle flottante	End +14 · Int +22 · Esp +23 · Puiss. sorts +23	
19948	trinket	4	0	4	68	0	Insigne de héros zandalarien		
19949	trinket	4	0	4	68	0	Médaillon de héros zandalarien		
19950	trinket	4	0	4	68	0	Charme de héros zandalarien		
19951	trinket	4	0	4	65	60	Charme de puissance de Gri'lek		
19952	trinket	4	0	4	65	60	Charme de courage de Gri'lek		
19953	trinket	4	0	4	65	60	Charme des bêtes de Renataki		
19954	trinket	4	0	4	65	60	Charme de supercherie de Renataki		
19955	trinket	4	0	4	65	60	Charme de nature de Wushoolay		
19956	trinket	4	0	4	65	60	Charme-esprits de Wushoolay		
19957	trinket	4	0	4	65	60	Charme de destruction d'Hazza'rah		
19958	trinket	4	0	4	65	60	Charme de soin d'Hazza'rah		
19959	trinket	4	0	4	65	60	Charme de magie d'Hazza'rah		
19966	ranged	2	2	3	68	60	[PÉRIMÉ] Arc long à triple corde	Agi +13 · End +5	
19969	feet	4	1	2	40	0	Bottes de pêche extrême de Nat Pagle	End +12	
19970	two	2	20	3	20	0	Canne à pêche en arcanite		
19972	head	4	1	2	40	0	Chapeau du pêcheur chanceux	End +15	
19979	trinket	4	0	3	65	0	Hameçon du maître pêcheur		
19986	head	4	2	3	52	0	Couvre-oeil de pirate	Agi +12 · End +20	
19989	off	4	0	3	52	0	Tome des ombres dévorantes	Rés. nature +6	
19998	head	4	2	3	65	60	Lentille en vignesang	End +12 · Crit. +28	c202:1
19999	head	4	1	3	65	60	Lunettes en vignesang	Crit. +14 · Toucher +20 · Mana/5 +9	c202:1
20003	main	2	13	3	52	0	Griffes de diablosaure	Agi +4 · Toucher +10	
20005	off	2	13	3	52	0	Griffes de diablosaure	Agi +4	
20033	chest	4	1	4	65	0	Robe de démoniaque zandalar	End +35 · Puiss. sorts +27 · Toucher +10	
20034	chest	4	1	4	65	0	Robe d'illusionniste zandalar	End +23 · Int +24 · Puiss. sorts +27 · Toucher +10	
20039	feet	4	4	4	70	60	Bottes en sombrefer	Armure +120 · Rés. feu +28	c164:1
20041	waist	4	4	3	63	58	Ceinturon des Hautes-terres en plaques	For +17 · End +10 · Crit. +14	
20042	waist	4	4	3	63	58	Ceinturon des Hautes-terres lamellaire	For +15 · End +6 · Int +10 · Crit. +14	
20043	waist	4	3	3	63	58	Ceinturon des Hautes-terres en anneaux	End +10 · PA +34 · Crit. +14	
20044	waist	4	3	3	63	58	Ceinturon des Hautes-terres en mailles	End +10 · Int +17 · Crit. +14	
20045	waist	4	2	3	63	58	Ceinturon des Hautes-terres en cuir	End +7 · PA +34 · Crit. +14 · Armure +60	
20046	waist	4	2	3	63	58	Ceinturon des Hautes-terres en cuir de lézard	End +7 · Int +17 · Crit. +14 · Armure +60	
20047	waist	4	1	3	63	58	Ceinturon des Hautes-terres en tissu	End +7 · Int +6 · Puiss. sorts +14 · Crit. +14 · Armure +100	
20048	feet	4	4	3	63	58	Grèves des Hautes-terres en plaques	For +14 · Agi +12 · End +12	
20049	feet	4	4	3	63	58	Grèves des Hautes-terres lamellaires	For +14 · Agi +12 · End +8 · Int +8	
20050	feet	4	3	3	63	58	Grèves des Hautes-terres en anneaux	Agi +15 · End +16 · Int +8	
20051	feet	4	3	3	63	58	Grèves des Hautes-terres en mailles	Agi +15 · End +16 · Int +8	
20052	feet	4	2	3	63	58	Bottes des Hautes-terres en cuir	Agi +12 · End +16 · PA +16 · Armure +60	
20053	feet	4	2	3	63	58	Bottes des Hautes-terres en cuir de lézard	Agi +8 · End +16 · Int +8 · PA +16 · Armure +60	
20054	feet	4	1	3	63	58	Bottes des Hautes-terres en tissu	End +16 · Int +8 · Puiss. sorts +12 · Armure +100	
20055	shoulder	4	3	4	65	60	Espauliers des Hautes-terres en anneaux	Agi +20 · End +18 · Int +17	
20056	shoulder	4	3	4	65	60	Espauliers des Hautes-terres en mailles	For +11 · Agi +10 · End +18 · Int +17 · Mana/5 +4	
20057	shoulder	4	4	4	65	60	Spallières des Hautes-terres en plaques	For +18 · Agi +17 · End +20	
20058	shoulder	4	4	4	65	60	Spallière des Hautes-terres lamellaire	For +18 · Agi +17 · End +15 · Int +10	
20059	shoulder	4	2	4	65	60	Epaulières des Hautes-terres en cuir	Agi +18 · End +17 · PA +30 · Armure +110	
20060	shoulder	4	2	4	65	60	Epaulières des Hautes-terres en cuir de lézard	Agi +12 · End +17 · Int +12 · PA +30 · Armure +110	
20061	shoulder	4	1	4	65	60	Epaulettes des Hautes-terres	End +18 · Int +17 · Puiss. sorts +12 · Mana/5 +4 · Armure +110	
20068	back	4	1	4	65	60	Cape de garde noir	Agi +5 · End +11 · PA +34	
20069	two	2	10	4	65	60	Bâton d'écorcefer	End +19 · Int +10 · Crit. +28 · Armure +100	
20070	main	2	15	4	65	60	Griffe du sage	End +8 · Crit. +14 · Armure +40	
20071	trinket	4	0	3	63	58	Talisman d'Arathor	End +12	
20072	trinket	4	0	3	63	58	Talisman du Profanateur	End +12	
20073	back	4	1	4	65	60	Cape de la garde d'honneur	Agi +5 · End +11 · PA +34	
20086	ranged	2	16	2	52	0	Couteau de lancer du crépuscule d'acier	Agi +9	
20088	waist	4	3	3	53	48	Ceinturon des Hautes-terres en anneaux	End +8 · PA +20 · Crit. +14	
20089	waist	4	3	3	43	40	Ceinturon des Hautes-terres en anneaux	End +6 · PA +8 · Crit. +14	
20090	waist	4	2	3	33	28	Ceinturon des Hautes-terres en anneaux	End +5 · PA +24	
20091	feet	4	3	3	53	48	Grèves des Hautes-terres en anneaux	Agi +12 · End +13 · Int +6	
20092	feet	4	3	3	43	40	Grèves des Hautes-terres en anneaux	Agi +10 · End +10 · Int +3	
20093	feet	4	2	3	33	28	Grèves des Hautes-terres en anneaux	Agi +8 · End +8	
20094	feet	4	1	3	53	48	Bottes des Hautes-terres en tissu	End +13 · Int +6 · Puiss. sorts +9 · Armure +80	
20095	feet	4	1	3	43	38	Bottes des Hautes-terres en tissu	End +10 · Int +3 · Puiss. sorts +8 · Armure +60	
20096	feet	4	1	3	33	28	Bottes des Hautes-terres en tissu	End +8 · Puiss. sorts +7 · Armure +50	
20097	waist	4	1	3	53	48	Ceinturon des Hautes-terres en tissu	End +6 · Int +5 · Puiss. sorts +9 · Crit. +14 · Armure +70	
20098	waist	4	1	3	43	38	Ceinturon des Hautes-terres en tissu	End +4 · Int +4 · Puiss. sorts +14 · Armure +70	
20099	waist	4	1	3	33	28	Ceinturon des Hautes-terres en tissu	End +4 · Int +3 · Puiss. sorts +11 · Armure +60	
20100	feet	4	2	3	53	48	Bottes des Hautes-terres en cuir de lézard	Agi +8 · End +13 · Int +7 · PA +12 · Armure +40	
20101	feet	4	2	3	43	38	Bottes des Hautes-terres en cuir de lézard	Agi +6 · End +10 · Int +5 · PA +6 · Armure +40	
20102	feet	4	2	3	33	28	Bottes des Hautes-terres en cuir de lézard	Agi +5 · End +8 · Int +4 · Armure +30	
20103	waist	4	2	3	53	48	Ceinturon des Hautes-terres en cuir de lézard	End +6 · Int +10 · Crit. +14 · Armure +50	
20104	waist	4	2	3	43	38	Ceinturon des Hautes-terres en cuir de lézard	End +4 · Int +15 · Armure +40	
20105	waist	4	2	3	33	28	Ceinturon des Hautes-terres en cuir de lézard	End +4 · Int +12 · Armure +30	
20106	waist	4	4	3	53	48	Ceinturon des Hautes-terres lamellaire	For +11 · End +4 · Int +8 · Crit. +14	
20107	waist	4	4	3	43	40	Ceinturon des Hautes-terres lamellaire	For +12 · End +6 · Int +6	
20108	waist	4	3	3	33	28	Ceinturon des Hautes-terres lamellaire	For +11 · End +4 · Int +5	
20109	feet	4	4	3	53	48	Grèves des Hautes-terres lamellaires	For +11 · Agi +10 · End +7 · Int +6	
20110	feet	4	4	3	43	40	Grèves des Hautes-terres lamellaires	For +8 · Agi +8 · End +6 · Int +5	
20111	feet	4	3	3	33	28	Grèves des Hautes-terres lamellaires	For +6 · Agi +6 · End +4 · Int +4	
20112	feet	4	2	3	53	48	Bottes des Hautes-terres en cuir	Agi +11 · End +13 · PA +12 · Armure +40	
20113	feet	4	2	3	43	38	Bottes des Hautes-terres en cuir	Agi +8 · End +10 · PA +6 · Armure +40	
20114	feet	4	2	3	33	28	Bottes des Hautes-terres en cuir	Agi +7 · End +8 · Armure +30	
20115	waist	4	2	3	53	48	Ceinturon des Hautes-terres en cuir	End +6 · PA +20 · Crit. +14 · Armure +50	
20116	waist	4	2	3	43	38	Ceinturon des Hautes-terres en cuir	End +4 · PA +30 · Armure +40	
20117	waist	4	2	3	33	28	Ceinturon des Hautes-terres en cuir	End +4 · PA +24 · Armure +30	
20118	waist	4	3	3	53	48	Ceinturon des Hautes-terres en mailles	End +8 · Int +10 · Crit. +14	
20119	waist	4	3	3	43	40	Ceinturon des Hautes-terres en mailles	End +6 · Int +15	
20120	waist	4	2	3	33	28	Ceinturon des Hautes-terres en mailles	End +5 · Int +12	
20121	feet	4	3	3	53	48	Grèves des Hautes-terres en mailles	Agi +12 · End +13 · Int +6	
20122	feet	4	3	3	43	40	Grèves des Hautes-terres en mailles	Agi +10 · End +10 · Int +3	
20123	feet	4	2	3	33	28	Grèves des Hautes-terres en mailles	Agi +8 · End +8	
20124	waist	4	4	3	53	48	Ceinturon des Hautes-terres en plaques	For +10 · End +8 · Crit. +14	
20125	waist	4	4	3	43	40	Ceinturon des Hautes-terres en plaques	For +15 · End +6	
20126	waist	4	3	3	33	28	Ceinturon des Hautes-terres en plaques	For +12 · End +5	
20127	feet	4	4	3	53	48	Grèves des Hautes-terres en plaques	For +11 · Agi +10 · End +10	
20128	feet	4	4	3	43	40	Grèves des Hautes-terres en plaques	For +8 · Agi +8 · End +8	
20129	feet	4	3	3	33	28	Grèves des Hautes-terres en plaques	For +6 · Agi +6 · End +6	
20135	wrist	4	4	4	90	60	90 Epic Warrior Bracelets	For +18 · End +17 · Crit. +14 · Toucher +10	
20136	chest	4	4	4	90	60	90 Epic Warrior Breastplate	For +32 · End +31 · Toucher +20 · Rés. feu +10 · Rés. givre +10	
20137	hands	4	4	4	90	60	90 Epic Warrior Gauntlets	For +24 · End +23 · Crit. +14 · Armure +200	
20138	head	4	4	4	90	60	90 Epic Warrior Helm	For +32 · End +31 · Toucher +20	
20139	legs	4	4	4	90	60	90 Epic Warrior Legplates	For +32 · End +31 · Rés. feu +10 · Rés. givre +10 · Rés. nature +10	
20140	shoulder	4	4	4	90	60	90 Epic Warrior Pauldrons	For +24 · End +23 · Crit. +14 · Armure +200	
20141	feet	4	4	4	90	60	90 Epic Warrior Sabatons	For +24 · End +23 · Crit. +14 · Rés. feu +8 · Rés. givre +8	
20142	waist	4	4	4	90	60	90 Epic Warrior Waistband	For +24 · End +23 · Armure +200 · Rés. feu +5 · Rés. givre +6	
20143	neck	4	0	4	90	0	90 Epic Warrior Neck	For +18 · End +17 · Crit. +14	
20144	finger	4	0	4	90	0	90 Epic Warrior Ring	For +18 · End +17 · Crit. +14	
20145	back	4	1	4	90	60	90 Epic Warrior Cloak	For +18 · End +17 · Crit. +14 · Toucher +10	
20146	ranged	2	3	4	90	60	90 Epic Warrior Gun	For +13 · End +13 · Crit. +18 · Rés. feu +4 · Rés. givre +3	
20149	two	2	1	4	90	60	90 Epic Warrior Axe	For +32 · End +31	
20150	waist	4	3	3	63	58	Ceinturon de Profanateur en anneaux	End +10 · PA +34 · Crit. +14	
20151	waist	4	3	3	53	48	Ceinturon de Profanateur en anneaux	End +8 · PA +20 · Crit. +14	
20152	waist	4	2	3	33	28	Ceinturon de Profanateur en anneaux	End +5 · PA +24	
20153	waist	4	3	3	43	40	Ceinturon de Profanateur en anneaux	End +6 · PA +8 · Crit. +14	
20154	feet	4	3	3	63	58	Grèves de Profanateur en anneaux	Agi +15 · End +16 · Int +8	
20155	feet	4	3	3	53	48	Grèves de Profanateur en anneaux	Agi +12 · End +13 · Int +6	
20156	feet	4	3	3	43	40	Grèves de Profanateur en anneaux	Agi +10 · End +10 · Int +3	
20157	feet	4	2	3	33	28	Grèves de Profanateur en anneaux	Agi +8 · End +8	
20158	shoulder	4	3	4	65	60	Espauliers de Profanateur en anneaux	Agi +20 · End +18 · Int +17	
20159	feet	4	1	3	63	58	Bottes de Profanateur en tissu	End +16 · Int +8 · Puiss. sorts +12 · Armure +100	
20160	feet	4	1	3	53	48	Bottes de Profanateur en tissu	End +13 · Int +6 · Puiss. sorts +9 · Armure +80	
20161	feet	4	1	3	43	38	Bottes de Profanateur en tissu	End +10 · Int +3 · Puiss. sorts +8 · Armure +60	
20162	feet	4	1	3	33	28	Bottes de Profanateur en tissu	End +8 · Puiss. sorts +7 · Armure +50	
20163	waist	4	1	3	63	58	Ceinturon de Profanateur en tissu	End +7 · Int +6 · Puiss. sorts +14 · Crit. +14 · Armure +100	
20164	waist	4	1	3	33	28	Ceinturon de Profanateur en tissu	End +4 · Int +3 · Puiss. sorts +11 · Armure +60	
20165	waist	4	1	3	53	48	Ceinturon de Profanateur en tissu	End +6 · Int +5 · Puiss. sorts +9 · Crit. +14 · Armure +70	
20166	waist	4	1	3	43	38	Ceinturon de Profanateur en tissu	End +4 · Int +4 · Puiss. sorts +14 · Armure +70	
20167	feet	4	2	3	63	58	Bottes de Profanateur en cuir de lézard	Agi +8 · End +16 · Int +8 · PA +16 · Armure +60	
20168	feet	4	2	3	43	38	Bottes de Profanateur en cuir de lézard	Agi +6 · End +10 · Int +5 · PA +6 · Armure +40	
20169	feet	4	2	3	33	28	Bottes de Profanateur en cuir de lézard	Agi +5 · End +8 · Int +4 · Armure +30	
20170	feet	4	2	3	53	48	Bottes de Profanateur en cuir de lézard	Agi +8 · End +13 · Int +7 · PA +12 · Armure +40	
20171	waist	4	2	3	63	58	Ceinturon de Profanateur en cuir de lézard	End +7 · Int +17 · Crit. +14 · Armure +60	
20172	waist	4	2	3	33	28	Ceinturon de Profanateur en cuir de lézard	End +4 · Int +12 · Armure +30	
20173	waist	4	2	3	43	38	Ceinturon de Profanateur en cuir de lézard	End +4 · Int +15 · Armure +40	
20174	waist	4	2	3	53	48	Ceinturon de Profanateur en cuir de lézard	End +6 · Int +10 · Crit. +14 · Armure +50	
20175	shoulder	4	2	4	65	60	Epaulières de Profanateur en cuir de lézard	Agi +12 · End +17 · Int +12 · PA +30 · Armure +110	
20176	shoulder	4	1	4	65	60	Epaulettes de Profanateur	End +18 · Int +17 · Puiss. sorts +12 · Mana/5 +4 · Armure +110	
20177	waist	4	4	3	63	58	Ceinturon lamellaire de Profanateur	For +15 · End +6 · Int +10 · Crit. +14	
20178	waist	4	3	3	33	28	Ceinturon de Profanateur lamellaire	For +11 · End +4 · Int +5	
20179	waist	4	4	3	53	48	Ceinturon lamellaire de Profanateur	For +11 · End +4 · Int +8 · Crit. +14	
20180	waist	4	4	3	43	40	Ceinturon de Profanateur lamellaire	For +12 · End +6 · Int +6	
20181	feet	4	4	3	63	58	Grèves de Profanateur lamellaires	For +14 · Agi +12 · End +8 · Int +8	
20182	feet	4	3	3	33	28	Grèves de Profanateur lamellaires	For +6 · Agi +6 · End +4 · Int +4	
20183	feet	4	4	3	43	40	Grèves de Profanateur lamellaires	For +8 · Agi +8 · End +6 · Int +5	
20184	shoulder	4	4	4	65	60	Spallière de Profanateur lamellaire	For +18 · Agi +17 · End +15 · Int +10	
20185	feet	4	4	3	53	48	Grèves de Profanateur lamellaires	For +11 · Agi +10 · End +7 · Int +6	
20186	feet	4	2	3	63	58	Bottes de Profanateur en cuir	Agi +12 · End +16 · PA +16 · Armure +60	
20187	feet	4	2	3	43	38	Bottes de Profanateur en cuir	Agi +8 · End +10 · PA +6 · Armure +40	
20188	feet	4	2	3	33	28	Bottes de Profanateur en cuir	Agi +7 · End +8 · Armure +30	
20189	feet	4	2	3	53	48	Bottes de Profanateur en cuir	Agi +11 · End +13 · PA +12 · Armure +40	
20190	waist	4	2	3	63	58	Ceinturon de Profanateur en cuir	End +7 · PA +34 · Crit. +14 · Armure +60	
20191	waist	4	2	3	33	28	Ceinturon de Profanateur en cuir	End +4 · PA +24 · Armure +30	
20192	waist	4	2	3	43	38	Ceinturon de Profanateur en cuir	End +4 · PA +30 · Armure +40	
20193	waist	4	2	3	53	48	Ceinturon de Profanateur en cuir	End +6 · PA +20 · Crit. +14 · Armure +50	
20194	shoulder	4	2	4	65	60	Epaulières de Profanateur en cuir	Agi +18 · End +17 · PA +30 · Armure +110	
20195	waist	4	3	3	63	58	Ceinturon de Profanateur en mailles	End +10 · Int +17 · Crit. +14	
20196	waist	4	3	3	53	48	Ceinturon de Profanateur en mailles	End +8 · Int +10 · Crit. +14	
20197	waist	4	2	3	33	28	Ceinturon de Profanateur en mailles	End +5 · Int +12	
20198	waist	4	3	3	43	40	Ceinturon de Profanateur en mailles	End +6 · Int +15	
20199	feet	4	3	3	63	58	Grèves de Profanateur en mailles	Agi +15 · End +16 · Int +8	
20200	feet	4	3	3	43	40	Grèves de Profanateur en mailles	Agi +10 · End +10 · Int +3	
20201	feet	4	2	3	33	28	Grèves de Profanateur en mailles	Agi +8 · End +8	
20202	feet	4	3	3	53	48	Grèves de Profanateur en mailles	Agi +12 · End +13 · Int +6	
20203	shoulder	4	3	4	65	60	Espauliers de Profanateur en mailles	For +11 · Agi +10 · End +18 · Int +17 · Mana/5 +4	
20204	waist	4	4	3	63	58	Ceinturon de Profanateur en plaques	For +17 · End +10 · Crit. +14	
20205	waist	4	4	3	53	48	Ceinturon de Profanateur en plaques	For +10 · End +8 · Crit. +14	
20206	waist	4	4	3	43	40	Ceinturon de Profanateur en plaques	For +15 · End +6	
20207	waist	4	3	3	33	28	Ceinturon de Profanateur en plaques	For +12 · End +5	
20208	feet	4	4	3	63	58	Grèves de Profanateur en plaques	For +14 · Agi +12 · End +12	
20209	feet	4	4	3	43	40	Grèves de Profanateur en plaques	For +8 · Agi +8 · End +8	
20210	feet	4	3	3	33	28	Grèves de Profanateur en plaques	For +6 · Agi +6 · End +6	
20211	feet	4	4	3	53	48	Grèves de Profanateur en plaques	For +11 · Agi +10 · End +10	
20212	shoulder	4	4	4	65	60	Spallières de Profanateur en plaques	For +18 · Agi +17 · End +20	
20213	waist	4	4	3	70	0	Ceinture de têtes rétrécies	For +23 · Agi +7 · End +11	
20214	main	2	15	4	65	60	Croc de l'esprit	End +8 · Crit. +14 · Armure +40	
20215	waist	4	3	3	70	0	Ceinture de têtes réduites	Agi +11 · End +18 · Int +11 · Esp +7	
20216	waist	4	2	3	70	0	Ceinture de têtes préservées	For +14 · Agi +15 · End +11 · Toucher +10	
20217	waist	4	1	3	70	0	Ceinture de têtes minuscules	End +13 · Int +17 · Mana/5 +7	
20218	back	4	1	3	59	0	Cape hakkari terne	End +5 · Int +8 · Mana/5 +6	
20219	back	4	1	3	59	0	Cape hakkari rapiécée	For +11 · End +10	
20220	two	2	10	4	65	60	Bâton d'écorcefer	End +19 · Int +10 · Crit. +28 · Armure +100	
20238	two	2	1	2	90	60	90 Green Warrior Axe	For +28 · End +27	
20239	wrist	4	4	2	90	60	90 Green Warrior Bracelets	For +16 · End +15	
20240	chest	4	4	2	90	60	90 Green Warrior Breastplate	For +28 · End +27	
20241	back	4	1	2	90	60	90 Green Warrior Cloak	For +16 · End +15	
20242	hands	4	4	2	90	60	90 Green Warrior Gauntlets	For +21 · End +20	
20245	ranged	2	3	2	90	60	90 Green Warrior Gun	For +12 · End +11	
20246	head	4	4	2	90	60	90 Green Warrior Helm	For +28 · End +27	
20247	legs	4	4	2	90	60	90 Green Warrior Legplates	For +28 · End +27	
20248	neck	4	0	2	90	60	90 Green Warrior Neck	For +16 · End +15	
20249	shoulder	4	4	2	90	60	90 Green Warrior Pauldrons	For +21 · End +20	
20250	finger	4	0	2	90	0	90 Green Warrior Ring	For +16 · End +15	
20251	feet	4	4	2	90	60	90 Green Warrior Sabatons	For +21 · End +20	
20252	waist	4	4	2	90	60	90 Green Warrior Waistband	For +21 · End +20	
20267	waist	4	2	4	90	60	90 Epic Rogue Belt	For +18 · Agi +19 · End +18 · Crit. +14 · Rés. feu +8	
20268	feet	4	2	4	90	60	90 Epic Rogue Boots	For +18 · Agi +19 · End +18 · Crit. +14 · Armure +200	
20269	wrist	4	2	4	90	60	90 Epic Rogue Bracers	For +13 · Agi +14 · End +14 · Crit. +14 · Rés. feu +4	
20270	head	4	2	4	90	60	90 Epic Rogue Cap	For +24 · Agi +25 · End +25 · Esquive +24 · Armure +200	
20271	hands	4	2	4	90	60	90 Epic Rogue Gloves	For +18 · Agi +19 · End +18 · Crit. +14 · Armure +200	
20272	legs	4	2	4	90	60	90 Epic Rogue Pants	For +24 · Agi +25 · End +25 · Armure +250	
20273	shoulder	4	2	4	90	60	90 Epic Rogue Spaulders	For +18 · Agi +19 · End +18 · Crit. +14 · Armure +200	
20274	chest	4	2	4	90	60	90 Epic Rogue Tunic	For +24 · Agi +25 · End +25 · Esquive +24 · Armure +200	
20275	neck	4	0	4	90	60	90 Epic Rogue Neck	For +13 · Agi +14 · End +14 · Crit. +14 · Rés. feu +4	
20276	back	4	1	4	90	60	90 Epic Rogue Cloak	For +13 · Agi +14 · End +14 · Crit. +14 · Rés. feu +5	
20277	finger	4	0	4	90	60	90 Epic Rogue Ring	For +13 · Agi +14 · End +14 · Crit. +14	
20278	ranged	2	2	4	90	60	90 Epic Rogue Bow	For +9 · Agi +11 · End +11 · Mana/5 +3 · Rés. feu +4	
20279	one	2	15	4	90	60	90 Epic Rogue Dagger	For +10 · Agi +11 · End +10 · Esquive +12 · Rés. feu +2	
20280	two	2	1	2	63	58	63 Green Warrior Axe	For +19 · End +18	
20281	wrist	4	4	2	63	58	63 Green Warrior Bracelets	For +10 · End +10	
20282	chest	4	4	2	63	58	63 Green Warrior Breastplate	For +19 · End +18	
20283	back	4	1	2	63	58	63 Green Warrior Cloak	For +14 · End +14	
20284	hands	4	4	2	63	58	63 Green Warrior Gauntlets	For +14 · End +14	
20285	ranged	2	3	2	63	58	63 Green Warrior Gun	For +8 · End +8	
20286	head	4	4	2	63	58	63 Green Warrior Helm	For +19 · End +18	
20287	legs	4	4	2	63	58	63 Green Warrior Legplates	For +19 · End +18	
20288	neck	4	0	2	63	58	63 Green Warrior Neck	For +10 · End +10	
20289	shoulder	4	4	2	63	58	63 Green Warrior Pauldrons	For +14 · End +14	
20290	finger	4	0	2	63	58	63 Green Warrior Ring	For +10 · End +10	
20291	feet	4	4	2	63	58	63 Green Warrior Sabatons	For +14 · End +14	
20292	waist	4	4	2	63	58	63 Green Warrior Waistband	For +14 · End +14	
20295	legs	4	3	3	60	55	Jambières en écailles de dragon bleu	Int +20 · Puiss. sorts +19 · Rés. arcanes +12	c165:1
20296	hands	4	3	3	56	51	Gantelets en écailles de dragon vert	End +5 · Dégâts sorts +14 · Soins +40 · Rés. nature +18	c165:1
20297	waist	4	2	2	90	60	90 Green Rogue Belt	Agi +24 · End +15	
20298	feet	4	2	2	90	60	90 Green Rogue Boots	Agi +24 · End +15	
20299	ranged	2	2	2	90	60	90 Green Rogue Bow	Agi +14 · End +8	
20300	wrist	4	2	2	90	60	90 Green Rogue Bracers	Agi +18 · End +11	
20301	head	4	2	2	90	60	90 Green Rogue Cap	Agi +32 · End +20	
20302	back	4	1	2	90	60	90 Green Rogue Cloak	Agi +18 · End +11	
20303	one	2	15	2	90	60	90 Green Rogue Dagger	Agi +14 · End +8	
20304	hands	4	2	2	90	60	90 Green Rogue Gloves	Agi +24 · End +15	
20305	neck	4	0	2	90	60	90 Green Rogue Neck	Agi +18 · End +11	
20306	legs	4	2	2	90	60	90 Green Rogue Pants	Agi +32 · End +20	
20307	finger	4	0	2	90	60	90 Green Rogue Ring	Agi +18 · End +11	
20308	shoulder	4	2	2	90	60	90 Green Rogue Spaulders	Agi +24 · End +15	
20309	chest	4	2	2	90	60	90 Green Rogue Tunic	Agi +32 · End +20	
20311	waist	4	2	2	63	58	63 Green Rogue Belt	Agi +17 · End +10	
20312	feet	4	2	2	63	58	63 Green Rogue Boots	Agi +17 · End +10	
20313	ranged	2	2	2	63	58	63 Green Rogue Bow	Agi +9 · End +5	
20314	wrist	4	2	2	63	58	63 Green Rogue Bracers	Agi +12 · End +7	
20315	head	4	2	2	63	58	63 Green Rogue Cap	Agi +21 · End +14	
20316	back	4	1	2	63	58	63 Green Rogue Cloak	Agi +12 · End +7	
20317	one	2	15	2	63	58	63 Green Rogue Dagger	Agi +9 · End +6	
20318	hands	4	2	2	63	58	63 Green Rogue Gloves	Agi +17 · End +10	
20319	neck	4	0	2	63	58	63 Green Rogue Neck	Agi +12 · End +7	
20320	legs	4	2	2	63	58	63 Green Rogue Pants	Agi +21 · End +14	
20321	finger	4	0	2	63	58	63 Green Rogue Ring	Agi +12 · End +7	
20322	shoulder	4	2	2	63	58	63 Green Rogue Spaulders	Agi +17 · End +10	
20323	chest	4	2	2	63	58	63 Green Rogue Tunic	Agi +21 · End +14	
20324	waist	4	1	4	90	60	90 Epic Frost Belt	End +12 · Int +27 · Esp +11 · Crit. +14	
20325	wrist	4	1	4	90	60	90 Epic Frost Bindings	End +9 · Int +20 · Esp +8 · Mana/5 +4	
20326	feet	4	1	4	90	60	90 Epic Frost Boots	End +12 · Int +27 · Esp +11 · Crit. +14	
20327	head	4	1	4	90	60	90 Epic Frost Crown	End +16 · Int +37 · Esp +15 · Mana/5 +8	
20328	hands	4	1	4	90	60	90 Epic Frost Gloves	End +12 · Int +27 · Esp +11 · Crit. +14	
20329	legs	4	1	4	90	60	90 Epic Frost Leggings	End +16 · Int +37 · Esp +15 · Mana/5 +8	
20330	shoulder	4	1	4	90	60	90 Epic Frost Mantle	End +12 · Int +27 · Esp +11 · Crit. +14	
20331	chest	4	1	4	90	60	90 Epic Frost Robes	End +16 · Int +37 · Esp +15 · Mana/5 +8	
20332	neck	4	0	4	90	60	90 Epic Frost Neck	End +9 · Int +20 · Esp +8 · Mana/5 +4	
20333	finger	4	0	4	90	60	90 Epic Frost Ring	End +9 · Int +20 · Esp +8 · Mana/5 +4	
20334	two	2	10	4	90	60	90 Epic Frost Staff	End +16 · Int +37 · Esp +15 · Crit. +28 · Mana/5 +5	
20335	ranged	2	19	4	90	60	90 Epic Frost Wand	End +7 · Int +16 · Esp +5 · Mana/5 +3	
20336	back	4	1	4	90	60	90 Epic Frost Shroud	End +9 · Int +20 · Esp +8 · Mana/5 +4	
20338	waist	4	1	2	90	60	90 Green Frost Belt	End +21	
20339	wrist	4	1	2	90	60	90 Green Frost Bindings	Int +16	
20340	feet	4	1	2	90	60	90 Green Frost Boots	Esp +21	
20341	head	4	1	2	90	60	90 Green Frost Crown	Int +28	
20342	hands	4	1	2	90	60	90 Green Frost Gloves	Int +21	
20343	legs	4	1	2	90	60	90 Green Frost Leggings	Int +28	
20344	shoulder	4	1	2	90	60	90 Green Frost Mantle	Int +21	
20345	neck	4	0	2	90	60	90 Green Frost Neck	Esp +16	
20346	finger	4	0	2	90	60	90 Green Frost Ring	Int +16	
20347	chest	4	1	2	90	60	90 Green Frost Robes	Int +28	
20348	back	4	1	2	90	60	90 Green Frost Shroud	End +16	
20349	two	2	10	2	90	60	90 Green Frost Staff	End +27 · Int +28	
20350	ranged	2	19	2	90	60	90 Green Frost Wand	Int +12	
20351	waist	4	1	2	63	58	63 Green Frost Belt	End +14	
20352	wrist	4	1	2	63	58	63 Green Frost Bindings	Int +10	
20353	feet	4	1	2	63	58	63 Green Frost Boots	Esp +14	
20354	head	4	1	2	63	58	63 Green Frost Crown	Int +19	
20355	hands	4	1	2	63	58	63 Green Frost Gloves	Int +14	
20356	legs	4	1	2	63	58	63 Green Frost Leggings	Int +19	
20357	shoulder	4	1	2	63	58	63 Green Frost Mantle	Int +14	
20358	neck	4	0	2	63	58	63 Green Frost Neck	Esp +10	
20359	finger	4	0	2	63	58	63 Green Frost Ring	Int +10	
20360	chest	4	1	2	63	58	63 Green Frost Robes	Int +19	
20361	back	4	1	2	63	58	63 Green Frost Shroud	End +10	
20362	two	2	10	2	63	58	63 Green Frost Staff	Int +19	
20363	ranged	2	19	2	63	58	63 Green Frost Wand	Int +8	
20368	ranged	2	2	3	60	60	Arc de fermeté quelconque		
20370	two	2	10	4	90	60	Test Staff 90 epic	For +37 · Agi +16 · End +15 · Esquive +24	
20372	two	2	10	4	77	60	Test Staff 77 epic	For +22 · Agi +21 · End +21 · Esquive +24	
20380	chest	4	3	4	68	60	Cuirasse de rêvécaille	Agi +15 · End +15 · Int +14 · Mana/5 +4 · Rés. nature +30	c165:1
20406	shoulder	4	1	2	60	60	Mantelet de sectateur du crépuscule		
20407	chest	4	1	2	60	60	Robe de sectateur du crépuscule		
20408	head	4	1	2	60	60	Capuche de sectateur du crépuscule		
20425	two	2	10	3	23	18	Bâton noueux de conseiller	End +8 · Int +4 · Mana/5 +3	
20426	finger	4	0	3	23	18	Bague de conseiller	End +2 · Puiss. sorts +5 · Mana/5 +2	
20427	back	4	1	3	23	18	Cape de soigneur de bataille	End +4 · Esp +2 · Dégâts sorts +3 · Soins +9	
20428	back	4	1	3	23	18	Cape de conservateur	End +4 · Esp +2 · Dégâts sorts +3 · Soins +9	
20429	finger	4	0	3	23	18	Anneau de légionnaire	For +4 · Agi +4 · End +2	
20430	one	2	7	3	23	18	Epée de légionnaire	For +4 · End +2	
20431	finger	4	0	3	23	18	Bague de gardien du savoir	End +2 · Puiss. sorts +5 · Mana/5 +2	
20434	two	2	10	3	23	18	Bâton de gardien du savoir	End +8 · Int +4 · Mana/5 +3	
20437	ranged	2	2	3	23	18	Arc de voltigeur	Agi +2 · End +4	
20438	ranged	2	2	3	23	18	Arc d'estafette	Agi +2 · End +4	
20439	finger	4	0	3	23	18	Anneau de protecteur	For +4 · Agi +4 · End +2	
20440	one	2	7	3	23	18	Epée de protecteur	For +4 · End +2	
20441	one	2	15	3	23	18	Lame d'éclaireur	Agi +4 · End +2	
20442	neck	4	0	3	23	18	Médaillon d'éclaireur	Agi +6 · End +2	
20443	one	2	15	3	23	18	Lame de Sentinelle	Agi +4 · End +2	
20444	neck	4	0	3	23	18	Médaillon de Sentinelle	Agi +6 · End +2	
20445	finger	4	0	3	60	0	Test Defense Ring +120	Déf. +120	
20446	finger	4	0	3	60	0	Test Defense Ring +80	Déf. +80	
20476	wrist	4	3	3	62	57	Brassards de traqueuse des sables	End +7 · Rés. nature +15	c165:1
20477	hands	4	3	3	62	57	Gantelets de traqueuse des sables	End +9 · Rés. nature +20	c165:1
20478	chest	4	3	3	62	57	Cuirasse de traqueuse des sables	End +13 · Rés. nature +25	c165:1
20479	chest	4	3	3	62	57	Cuirasse de crache-feu	Agi +16 · Int +16 · Esp +15 · Puiss. sorts +15	c165:1
20480	hands	4	3	3	62	57	Gantelets de crache-feu	Agi +12 · Int +12 · Esp +12 · Puiss. sorts +11	c165:1
20481	wrist	4	3	3	62	57	Brassards de crache-feu	Agi +9 · Int +9 · Esp +9 · Puiss. sorts +8	c165:1
20487	two	2	10	4	75	60	Lok'delar, bâton des Gardiens anciens DEP	End +26 · Int +15 · Crit. +28 · Rés. nature +10	
20488	ranged	2	2	4	75	60	Rhok'delar, arc long des Gardiens anciens DEP	PA dist. +23 · Crit. +19	
20502	off	4	6	3	52	0	Bouclier d'écorcefer	End +6 · Crit. +14	
20522	two	2	10	3	52	0	Bâton farouche	For +17 · Agi +16 · Armure +110	
20524	legs	4	2	3	52	0	Jambières ombrepoil	Int +12 · Esp +6 · Armure +120 · Rés. ombre +6	
20525	trinket	4	0	3	52	0	Glyphe terrestre		
20537	feet	4	1	3	63	58	Bottes runiques ténébreuses	End +8 · Rés. ombre +20	c197:1
20538	legs	4	1	3	63	58	Jambières runiques ténébreuses	End +13 · Rés. ombre +25	c197:1
20539	waist	4	1	3	63	58	Ceinture runique ténébreuse	End +10 · Rés. ombre +20	c197:1
20549	hands	4	4	3	63	58	Gantelets de sombrerune	End +8 · Blocage +10 · Rés. ombre +20	c164:1
20550	chest	4	4	3	63	58	Cuirasse de sombrerune	End +14 · Esquive +12 · Rés. ombre +25	c164:1
20551	head	4	4	3	63	58	Heaume de sombrerune	End +13 · Crit. +14 · Rés. ombre +25	c164:1
20575	chest	4	2	2	20	15	Tunique de dragonnet noir	Int +5 · Puiss. sorts +3	c165:1
20580	main	2	4	4	71	60	Marteau de fureur bestiale	For +13 · End +12 · Armure +90	
20583	head	4	5	2	45	0	Masque de naine solide		
20584	head	4	5	2	45	0	Masque de gnome solide (F)		
20585	head	4	5	2	45	0	Masque d'humaine solide		
20586	head	4	5	2	45	0	Masque solide d’Elfe de la nuit (femme)		
20587	head	4	5	2	45	0	Masque d'orque solide		
20588	head	4	5	2	45	0	Masque de taurène solide		
20589	head	4	5	2	45	0	Masque de trollesse solide		
20590	head	4	5	2	45	0	Masque de morte-vivante solide		
20591	head	4	5	2	45	0	Masque de nain solide		
20592	head	4	5	2	45	0	Masque de gnome solide (H)		
20593	head	4	5	2	45	0	Masque d'humain solide		
20594	head	4	5	2	45	0	Masque solide d’Elfe de la nuit (homme)		
20595	head	4	5	2	45	0	Masque d'orc solide		
20596	head	4	5	2	45	0	Masque de tauren solide		
20597	head	4	5	2	45	0	Masque de troll solide		
20598	head	4	5	2	45	0	Masque de mort-vivant solide		
20600	finger	4	0	4	72	60	Chevalière de Malfurion	End +17 · Rés. nature +20	
20622	neck	4	0	4	71	60	Collier coeur-de-dragon	End +21 · Int +6 · Esp +6 · PA +24	
20624	finger	4	0	4	72	60	Anneau des non-vivants	Agi +21 · End +16	
20632	finger	4	0	4	71	60	Anneau de la déchirure d'esprit	End +6 · Int +6 · Puiss. sorts +22 · Crit. +14	
20636	trinket	4	0	4	71	60	Cristal d'hibernation		
20639	legs	4	4	4	72	60	Cuissards ornés de glyphes étranges	For +20 · Agi +12 · End +20 · Int +21 · Esp +16	
20640	head	4	4	2	45	0	Seau de tête des Mers du sud	For +6 · End +15 · Déf. +4	
20641	feet	4	1	2	45	0	Bottes mojo des Mers du sud	Int +11 · Puiss. sorts +8	
20642	chest	4	1	2	47	0	Tunique noble antique	End +10 · Int +10 · Puiss. sorts +13	
20643	head	4	2	2	47	0	Coiffe de réserviste de Fossoyeuse	For +10 · Agi +11 · End +10	
20645	neck	4	0	2	60	0	Murmure de la nature	End +10 · Int +5 · Rés. nature +8	
20646	ranged	2	2	2	59	0	Marque de trotteur des sables	End +11	
20647	main	2	15	2	59	0	Dague en cristal noir	Int +3 · Mana/5 +4	
20648	main	2	4	3	63	0	Marteau forgé à froid	End +5 · Int +9 · Mana/5 +3	
20649	neck	4	0	2	60	0	Pendentif du prisme solaire	Agi +12 · End +7	
20650	hands	4	4	2	60	0	Gantelets du vent du désert	For +11 · End +10 · Déf. +6	
20682	finger	4	0	4	65	60	Anneau de focalisation élémentaire	End +8 · Int +11 · Puiss. sorts +22	
20685	neck	4	0	4	65	60	Collier du front de mer	End +5 · Int +6 · Dégâts sorts +8 · Soins +24 · Mana/5 +8	
20692	finger	4	0	2	60	55	Anneau multicolore	End +10	
20695	neck	4	0	3	63	58	Collier de guerre abyssal	End +15 · PA +20	
20699	legs	4	4	3	63	0	Cuissards de réserviste cénariens	End +13 · Déf. +9 · Rés. nature +25	
20700	legs	4	4	3	63	0	Cuissards de réserviste cénariens	End +13 · Int +13 · Rés. nature +25	
20701	legs	4	3	3	63	0	Cuissots de réserviste cénariens	End +13 · Int +13 · Rés. nature +25	
20702	legs	4	3	3	63	0	Cuissots de réserviste cénariens	Agi +13 · End +13 · Rés. nature +25	
20703	legs	4	2	3	63	0	Jambières de réserviste cénariennes	End +13 · PA +26 · Rés. nature +25	
20704	legs	4	2	3	63	0	Jambières de réserviste cénariennes	End +13 · Dégâts sorts +10 · Soins +29 · Rés. nature +25	
20705	legs	4	1	3	63	0	Pantalon de réserviste cénarien	End +13 · Puiss. sorts +15 · Rés. nature +25	
20706	legs	4	1	3	63	0	Pantalon de réserviste cénarien	End +13 · Puiss. sorts +15 · Rés. nature +25	
20707	legs	4	1	3	63	0	Pantalon de réserviste cénarien	End +13 · Dégâts sorts +10 · Soins +29 · Rés. nature +25	
20710	feet	4	4	3	63	0	Grèves incrustées de cristaux	End +21 · Déf. +5 · Armure +60	
20711	feet	4	4	3	63	0	Grèves revêtues de cristaux	For +12 · End +12 · Int +12 · Dégâts sorts +5 · Soins +15	
20712	hands	4	3	3	63	0	Gantelets de la marche aride	For +10 · Agi +10 · End +10 · Int +10 · Esp +10	
20713	hands	4	3	3	63	0	Gantelets de traqueur du désert	Agi +16 · End +15 · Int +10	
20714	feet	4	2	3	63	0	Bottes de tempête de sable	End +12 · Int +12 · Puiss. sorts +14 · Mana/5 +4	
20715	feet	4	2	3	63	0	Bottes d'arpenteur de dunes	For +9 · Agi +19 · End +10	
20716	hands	4	1	3	63	0	Gants en peau de ver des sables	End +8 · Int +5 · Puiss. sorts +27	
20717	hands	4	1	3	63	0	Gants de la fleur du désert	End +5 · Int +5 · Esp +5 · Dégâts sorts +17 · Soins +51	
20721	finger	4	0	3	65	60	Anneau du sectateur	For +7 · Agi +12 · End +12	
20723	main	2	0	2	62	0	Pioche loyale de Brann	For +11	
20724	two	2	10	2	62	0	Bâton noirbois corrompu	End +11 · Int +22	
21101	two	2	10	3	63	58	Staff of Spell Penetration - Fire (TEST)		
21102	two	2	10	3	63	58	Staff of Spell Penetration - Frost (TEST)		
21115	trinket	4	0	3	53	48	Talisman de profanateur	End +10	
21116	trinket	4	0	3	43	38	Talisman de profanateur	End +8	
21117	trinket	4	0	3	53	48	Talisman d'Arathor	End +10	
21118	trinket	4	0	3	43	38	Talisman d'Arathor	End +8	
21119	trinket	4	0	3	33	28	Talisman d'Arathor	End +6	
21120	trinket	4	0	3	33	28	Talisman de profanateur	End +6	
21124	ranged	2	19	4	75	60	Ahn'Qiraj Wand [PH]		
21125	two	2	10	4	75	60	Ahn'Qiraj Staff [PH]		
21126	one	2	15	4	84	60	Aiguillon de la mort	End +10 · PA +38	
21127	main	2	4	4	75	60	Ahn'Qiraj Mace [PH]		
21134	two	2	1	4	84	60	Sombre doloire de la démence	For +35 · Agi +19 · End +25	
21135	ranged	2	16	3	63	58	Hache de lancer de l'assassin	Agi +15	
21178	hands	4	2	3	62	0	Gants de puissance terrestre	Int +9 · Puiss. sorts +27	
21179	finger	4	0	3	62	0	Anneau du courroux terrestre	Int +8 · Crit. +14 · Mana/5 +3	
21180	trinket	4	0	4	66	0	Choc de terre		
21181	trinket	4	0	3	66	0	Grâce de la Terre		
21182	finger	4	0	3	66	0	Anneau de puissance terrestre	For +6 · Crit. +14 · Toucher +10	
21183	chest	4	1	3	66	0	Gilet de puissance de la terre	Int +22 · Puiss. sorts +25 · Crit. +14	
21184	wrist	4	4	4	62	0	Brassards de Fonderoc	For +19 · Agi +10 · End +8	
21185	off	4	0	4	62	0	Orbe calme-terre	Int +10 · Dégâts sorts +6 · Soins +18 · Mana/5 +8	
21186	wrist	4	1	4	62	0	Brassards Furie-du-roc	End +7 · Puiss. sorts +27 · Toucher +10	
21187	back	4	1	3	62	0	Cape en tisse-terre	Agi +15 · Toucher +10	
21188	two	2	5	4	66	60	Poing de Cénarius	Puiss. sorts +40 · Crit. +28	
21189	finger	4	0	4	62	0	Puissance de Cénarius	End +8 · Toucher +10	
21190	finger	4	0	4	66	0	Courroux de Cénarius		
21196	finger	4	0	4	60	60	Chevalière du Vol de bronze	For +10 · End +18 · Déf. +5	
21197	finger	4	0	4	65	60	Chevalière du Vol de bronze	For +11 · End +19 · Déf. +5	
21198	finger	4	0	4	70	60	Chevalière du Vol de bronze	For +12 · End +21 · Déf. +6	
21199	finger	4	0	4	75	60	Chevalière du Vol de bronze	For +12 · End +22 · Déf. +6	
21200	finger	4	0	4	80	60	Chevalière du Vol de bronze	For +13 · End +24 · Déf. +7	
21201	finger	4	0	4	60	60	Chevalière du Vol de bronze	Agi +18 · End +8 · Toucher +10	
21202	finger	4	0	4	65	60	Chevalière du Vol de bronze	Agi +19 · End +9 · Toucher +10	
21203	finger	4	0	4	70	60	Chevalière du Vol de bronze	Agi +21 · End +11 · Toucher +10	
21204	finger	4	0	4	75	60	Chevalière du Vol de bronze	Agi +22 · End +11 · Toucher +10	
21205	finger	4	0	4	80	60	Chevalière du Vol de bronze	Agi +24 · End +13 · Toucher +10	
21206	finger	4	0	4	60	60	Chevalière du Vol de bronze	End +6 · Int +7 · Puiss. sorts +21 · Mana/5 +3	
21207	finger	4	0	4	65	60	Chevalière du Vol de bronze	End +7 · Int +8 · Puiss. sorts +22 · Mana/5 +3	
21208	finger	4	0	4	70	60	Chevalière du Vol de bronze	End +8 · Int +8 · Puiss. sorts +25 · Mana/5 +4	
21209	finger	4	0	4	75	60	Chevalière du Vol de bronze	End +8 · Int +8 · Puiss. sorts +26 · Mana/5 +4	
21210	finger	4	0	4	80	60	Chevalière du Vol de bronze	End +8 · Int +9 · Puiss. sorts +28 · Mana/5 +5	
21242	one	2	0	4	79	60	Hache de guerre qiraji bénie	End +9 · Int +10 · PA +14 · Crit. +14	
21244	one	2	15	4	79	60	Pugio qiraji béni	End +7 · PA +18 · Crit. +14 · Toucher +10	
21268	one	2	4	4	79	60	Marteau de guerre qiraji béni	For +10 · End +12 · Déf. +8 · Armure +70	
21269	off	4	6	4	79	60	Pavois qiraji béni	End +20 · Déf. +8 · Blocage +15	
21272	ranged	2	3	4	79	60	Mousquet qiraji béni	End +14 · PA dist. +42	
21273	two	2	10	4	79	60	Bâton d'acolyte qiraji béni	End +32 · Int +33 · Crit. +14 · Toucher +20	
21275	two	2	10	4	79	60	Bâton d'augure qiraji béni	End +23 · Int +24 · Mana/5 +15	
21276	two	2	10	4	80	60	Blessed Qiraji Naturalist Staff UNUSED		
21278	hands	4	2	3	62	57	Gants tempétueux	Crit. +14 · Toucher +10	c165:1
21311	chest	4	1	2	48	0	Gilet de gardien de la terre	Int +13 · Mana/5 +6	
21312	waist	4	3	2	48	0	Ceinture du protecteur	End +6 · PA +24	
21316	legs	4	4	2	55	0	Jambières de l'ursa	For +17 · Crit. +14	
21317	head	4	2	2	55	0	Casque du guide	End +17 · Crit. +14	
21318	hands	4	1	2	58	0	Gants de gardien de la terre	Puiss. sorts +22	
21319	hands	4	2	2	58	0	Gants du guide	For +13 · Agi +12	
21320	chest	4	3	2	58	0	Haubergeon du protecteur	Agi +20 · End +12	
21322	chest	4	4	2	58	0	Etreinte d'ursa	Agi +17 · Déf. +10	
21326	trinket	4	0	4	62	0	Défenseur des Grumegueules		
21329	head	4	4	4	81	60	Couronne du Conquérant	For +29 · Agi +18 · End +34 · Déf. +6	
21330	shoulder	4	4	4	78	60	Spallières du Conquérant	For +20 · Agi +16 · End +21 · Toucher +10 · Déf. +4	
21331	chest	4	4	4	88	60	Cuirasse du Conquérant	For +34 · Agi +24 · End +38 · Déf. +6	
21332	legs	4	4	4	81	60	Cuissards du Conquérant	For +33 · Agi +21 · End +24 · Toucher +10 · Déf. +6	
21333	feet	4	4	4	78	60	Grèves du Conquérant	For +21 · Agi +17 · End +23 · Déf. +4	
21334	chest	4	1	4	88	60	Robe d'implorateur funeste	End +23 · Int +17 · Esp +7 · Puiss. sorts +41 · Crit. +14	
21335	shoulder	4	1	4	78	60	Mantelet d'implorateur funeste	End +20 · Int +11 · Esp +4 · Puiss. sorts +28 · Toucher +10	
21336	legs	4	1	4	81	60	Pantalon d'implorateur funeste	End +28 · Int +24 · Esp +9 · Puiss. sorts +34 · Crit. +14	
21337	head	4	1	4	81	60	Diadème d'implorateur funeste	End +27 · Int +24 · Esp +6 · Puiss. sorts +33 · Crit. +14	
21338	feet	4	1	4	78	60	Bottines d'implorateur funeste	End +20 · Int +16 · Esp +3 · Puiss. sorts +28	
21339	hands	4	1	4	78	60	Doomcaller's Handwraps [PH]		
21343	chest	4	1	4	88	60	Robe de l'énigme	End +19 · Int +23 · Esp +7 · Puiss. sorts +39 · Crit. +14	
21344	feet	4	1	4	78	60	Bottes de l'énigme	End +15 · Int +15 · Esp +6 · Puiss. sorts +28 · Toucher +10	
21345	shoulder	4	1	4	78	60	Protège-épaules de l'énigme	End +16 · Int +12 · Esp +4 · Puiss. sorts +30 · Mana/5 +4	
21346	legs	4	1	4	81	60	Jambières de l'énigme	End +21 · Int +26 · Esp +8 · Puiss. sorts +34 · Crit. +14	
21347	head	4	1	4	81	60	Diadème de l'énigme	End +24 · Int +24 · Esp +12 · Puiss. sorts +33 · Crit. +14	
21348	head	4	1	4	81	60	Tiare de l'oracle	End +22 · Int +22 · Esp +16 · Puiss. sorts +28 · Toucher +10	
21349	feet	4	1	4	78	60	Bottines de l'oracle	End +20 · Int +17 · Esp +12 · Puiss. sorts +21 · Mana/5 +3	
21350	shoulder	4	1	4	78	60	Mantelet de l'oracle	End +21 · Int +20 · Esp +8 · Puiss. sorts +20 · Mana/5 +3	
21351	chest	4	1	4	88	60	Habit de l'oracle	End +23 · Int +26 · Esp +15 · Puiss. sorts +36 · Crit. +14	
21352	legs	4	1	4	81	60	Pantalon de l'oracle	End +23 · Int +24 · Esp +14 · Puiss. sorts +33 · Mana/5 +6	
21353	head	4	2	4	81	60	Casque de la genèse	For +15 · Agi +12 · End +22 · Int +22 · Esp +12	
21354	shoulder	4	2	4	78	60	Protège-épaules de la genèse	For +15 · Agi +14 · End +15 · Int +13 · Esp +6	
21355	feet	4	2	4	78	60	Bottes de la genèse	For +12 · Agi +13 · End +14 · Int +14 · Esp +6	
21356	legs	4	2	4	81	60	Pantalon de la genèse	For +12 · Agi +12 · End +22 · Int +22 · Esp +9	
21357	chest	4	2	4	88	60	Gilet de la genèse	For +13 · Agi +12 · End +24 · Int +24 · Esp +11	
21359	feet	4	2	4	78	60	Bottes de dispensateur de mort	For +14 · Agi +26 · End +17 · Toucher +10	
21360	head	4	2	4	81	60	Casque de dispensateur de mort	For +25 · Agi +29 · End +27 · Crit. +14 · Toucher +10	
21361	shoulder	4	2	4	78	60	Spallières de dispensateur de mort	For +18 · Agi +27 · End +15 · Toucher +10	
21362	legs	4	2	4	81	60	Jambières de dispensateur de mort	For +18 · Agi +38 · End +25 · Crit. +14	
21364	chest	4	2	4	88	60	Gilet de dispensateur de mort	For +19 · Agi +37 · End +28 · Crit. +14 · Toucher +10	
21365	feet	4	3	4	78	60	Bottes du Frappeur	Agi +31 · End +16 · Int +8 · Esp +6 · Puiss. sorts +6	
21366	head	4	3	4	81	60	Diadème du Frappeur	Agi +29 · End +26 · Int +18 · Esp +10 · Puiss. sorts +12	
21367	shoulder	4	3	4	81	60	Espauliers du Frappeur	Agi +26 · End +24 · Int +11 · Esp +5 · Puiss. sorts +6	
21368	legs	4	3	4	81	60	Jambières du Frappeur	Agi +36 · End +22 · Int +14 · Esp +10 · Puiss. sorts +9	
21370	chest	4	3	4	88	60	Haubert du Frappeur	Agi +39 · End +26 · Int +15 · Esp +7 · Puiss. sorts +9	
21372	head	4	3	4	81	60	Diadème d'implorateur de tempête	For +12 · Agi +8 · End +22 · Int +22 · Esp +12	
21373	feet	4	3	4	78	60	Bottes d'implorateur de tempête	For +12 · Agi +9 · End +14 · Int +14 · Esp +6	
21374	chest	4	3	4	88	60	Haubert d'implorateur de tempête	For +11 · Agi +10 · End +24 · Int +24 · Esp +11	
21375	legs	4	3	4	81	60	Jambières d'implorateur de tempête	For +12 · Agi +9 · End +22 · Int +22 · Esp +12	
21376	shoulder	4	3	4	78	60	Espauliers d'implorateur de tempête	For +10 · Agi +10 · End +15 · Int +13 · Esp +6	
21387	head	4	4	4	81	60	Couronne du Vengeur	For +20 · Agi +12 · End +22 · Int +22 · Esp +12	
21388	feet	4	4	4	78	60	Grèves du Vengeur	For +18 · Agi +13 · End +18 · Int +14 · Esp +6	
21389	chest	4	4	4	88	60	Cuirasse du Vengeur	For +23 · Agi +12 · End +24 · Int +24 · Esp +11	
21390	legs	4	4	4	81	60	Cuissards du Vengeur	For +21 · Agi +12 · End +22 · Int +22 · Esp +9	
21391	shoulder	4	4	4	78	60	Espauliers du Vengeur	For +18 · Agi +14 · End +15 · Int +13 · Esp +6	
21392	one	2	0	4	70	60	Faucille de force inflexible	For +15 · Agi +6 · End +9 · Déf. +4	
21393	finger	4	0	4	65	60	Chevalière de force inflexible	For +11 · End +14 · Crit. +14	
21394	back	4	1	4	67	60	Drapé de force inflexible	For +15 · Agi +9 · End +9 · Toucher +10	
21395	main	2	7	4	70	60	Lame de justice éternelle	For +9 · End +11 · Int +7 · Mana/5 +4	
21396	finger	4	0	4	65	60	Anneau de justice éternelle	For +12 · End +11 · Int +12 · Puiss. sorts +13	
21397	back	4	1	4	67	60	Cape de justice éternelle	For +11 · End +13 · Int +12 · Mana/5 +5	
21398	main	2	4	4	70	60	Marteau de la tempête imminente	For +7 · End +10 · Int +9	
21399	finger	4	0	4	65	60	Anneau de la tempête imminente	For +8 · Agi +9 · End +10 · Int +11 · Puiss. sorts +12	
21400	back	4	1	4	67	60	Cape de la tempête imminente	For +11 · End +10 · Int +13 · Puiss. sorts +14	
21401	one	2	0	4	70	60	Faux du sentier invisible	Agi +16 · End +9 · Mana/5 +3	
21402	finger	4	0	4	65	60	Chevalière du sentier invisible	Agi +19 · End +11 · Int +8	
21403	back	4	1	4	67	60	Cape du sentier invisible	Agi +17 · End +13 · Toucher +10	
21404	one	2	15	4	70	60	Dague des ombres voilées	For +7 · Agi +15 · Toucher +10	
21405	finger	4	0	4	65	60	Anneau des ombres voilées	For +11 · Agi +18 · End +8	
21406	back	4	1	4	67	60	Cape des ombres voilées	Agi +18 · End +11 · Toucher +10	
21407	main	2	4	4	70	60	Masse de vie interminable	For +9 · Agi +7 · End +10 · Int +11	
21408	finger	4	0	4	65	60	Anneau de vie interminable	For +10 · Agi +10 · End +9 · Int +8 · Esp +7	
21409	back	4	1	4	67	60	Cape de vie interminable	For +12 · Agi +8 · End +10 · Int +10 · Esp +7	
21410	main	2	4	4	70	60	Marteau de sagesse infinie	End +10 · Int +11 · Mana/5 +4	
21411	finger	4	0	4	65	60	Anneau de sagesse infinie	End +10 · Int +13 · Mana/5 +5	
21412	back	4	1	4	67	60	Voile de sagesse infinie	End +12 · Int +14 · Esp +11 · Dégâts sorts +8 · Soins +24	
21413	main	2	7	4	70	60	Lame des secrets scellés	End +8 · Int +16 · Toucher +10	
21414	finger	4	0	4	65	60	Anneau des secrets scellés	End +9 · Puiss. sorts +18 · Crit. +14	
21415	back	4	1	4	67	60	Drapé des secrets scellés	End +14 · Int +9 · Esp +6 · Puiss. sorts +18	
21416	one	2	15	4	70	60	Kriss des noms inexprimés	End +9 · Int +7 · Puiss. sorts +59	
21417	finger	4	0	4	65	60	Anneau des noms inexprimés	End +12 · Puiss. sorts +14 · Crit. +14 · Toucher +10	
21418	back	4	1	4	67	60	Voile des noms inexprimés	End +16 · Int +9 · Puiss. sorts +18	
21473	trinket	4	0	3	74	60	Oeil de Moam		
21477	finger	4	0	3	74	60	Anneau de fureur	End +9 · PA +30 · Toucher +10	
21483	finger	4	0	3	73	60	Anneau des vents du désert	Int +9 · Puiss. sorts +9 · Crit. +14 · Mana/5 +3	
21488	trinket	4	0	3	73	60	Fétiche d'épines chitineuses		
21504	neck	4	0	4	70	60	Charme des Sables changeants	End +9 · Int +12 · Puiss. sorts +25	
21505	neck	4	0	4	70	60	Foulard des Sables changeants	End +16 · PA +42	
21506	neck	4	0	4	70	60	Pendentif des Sables changeants	For +14 · End +21 · Déf. +4	
21507	neck	4	0	4	70	60	Amulette des Sables changeants	Soins +46 · Mana/5 +6	
21516	one	2	15	3	63	58	Dagger of Spell Penetration - Fire 150 Resist (TEST)		
21517	head	4	1	4	75	60	Turban gnome de puissance psychique	End +17 · Int +31 · Mana/5 +9	
21518	one	2	15	3	63	58	Dagger of Spell Penetration - Frost 150 Resist (TEST)		
21520	one	2	7	4	76	60	Héritage de Ravencrest	For +13 · Agi +9 · End +14	
21521	main	2	7	4	76	60	Epée runique du Rouge	End +17 · Int +9 · Esp +7	
21522	one	2	15	4	76	60	Douleur de Shadowsong	For +9 · Agi +13 · End +14	
21523	main	2	15	4	76	60	Croc de Korialstrasz	End +9 · Int +14 · Esp +13	
21526	finger	4	0	4	77	60	Anneau des profondeurs glacées	End +19 · Rés. givre +20	
21527	chest	4	1	4	77	60	Robe des eaux sombres	End +17 · Int +17 · Rés. feu +30	
21529	neck	4	0	4	77	60	Amulette de bouclier contre l'ombre	End +18 · Esp +7 · Rés. ombre +20	
21530	legs	4	3	4	77	60	Jambières enchâssées d'onyx	Agi +23 · End +23 · Int +17 · Rés. ombre +30	
21531	neck	4	0	4	77	60	Collier en dents de drake	End +7 · Int +12 · Soins +26 · Rés. nature +20	
21532	feet	4	2	4	77	60	Bottes de manœuvre	For +13 · Agi +17 · End +20 · Rés. nature +20	
21563	finger	4	0	4	65	60	Anneau de Don Rodrigue	End +7 · Crit. +14	
21565	trinket	4	0	3	45	40	Rune de perfection	End +8	
21566	trinket	4	0	3	25	20	Rune de perfection	End +4	
21567	trinket	4	0	3	45	40	Rune de devoir	End +8	
21568	trinket	4	0	3	25	20	Rune de devoir	End +4	
21579	trinket	4	0	4	88	60	Tentacule de C'Thun vaincu		
21581	hands	4	4	4	88	60	Gantelets d'annihilation	For +35 · End +15 · Crit. +14 · Toucher +10	
21582	waist	4	1	4	88	60	Torsade  du Dieu très ancien	End +15 · Int +19 · Soins +59 · Mana/5 +7	
21583	back	4	1	4	88	60	Cape de clarté	End +6 · Int +12 · Esp +7 · Soins +40 · Mana/5 +8	
21584	wrist	4	3	4	88	60	Brassards de rétorsion éternelle	Agi +26 · End +20	
21585	hands	4	1	4	88	60	Gantelets du sombre orage	End +19 · Int +15 · Puiss. sorts +37 · Toucher +10	
21586	waist	4	2	4	88	60	Ceinture d'agonie sans fin	End +20 · PA +64 · Crit. +14 · Toucher +10	
21587	wrist	4	4	4	88	60	Garde-poignets de punition	For +8 · End +15 · Int +13 · Soins +40 · Mana/5 +4	
21588	wrist	4	3	4	88	60	Garde-poignets de fureur élémentaire	End +11 · Int +13 · Puiss. sorts +25 · Mana/5 +6	
21594	wrist	4	2	4	88	60	Brassards du fils déchu	End +10 · Int +15 · Puiss. sorts +27 · Toucher +10	
21596	finger	4	0	4	88	60	Anneau du tueur de dieu	Agi +27 · End +17	
21597	off	4	0	4	81	60	Sceptre royal de Vek'lor	End +10 · Int +9 · Puiss. sorts +20 · Crit. +14 · Toucher +10	
21598	waist	4	4	4	81	60	Ceinture royale qiraji	For +13 · Agi +13 · End +22 · Déf. +8	
21600	feet	4	1	4	81	60	Bottes de l'épiphanie	End +18 · Int +19 · Puiss. sorts +34	
21601	finger	4	0	4	81	60	Anneau de l'empereur Vek'lor	Agi +12 · End +18 · Déf. +9 · Armure +100	
21602	wrist	4	2	4	81	60	Brassards d'exécution quiraji	For +15 · Agi +16 · End +14 · Toucher +10	
21604	wrist	4	1	4	81	60	Bracelets de rédemption royale	End +8 · Int +10 · Esp +9 · Soins +53	
21605	hands	4	2	4	81	60	Gants du temple caché	For +18 · Agi +21 · End +22 · Armure +100 · Rés. ombre +6	
21606	waist	4	4	4	81	60	Ceinture de l'empereur déchu	For +17 · Agi +13 · End +17 · Int +18 · Soins +35	
21607	waist	4	3	4	81	60	Torsade de l'empereur déchu	For +13 · Agi +12 · End +17 · Int +17 · Puiss. sorts +19	
21608	neck	4	0	4	81	60	Amulette de Vek'nilash	End +9 · Int +5 · Puiss. sorts +27 · Crit. +14	
21609	waist	4	2	4	81	60	Ceinture régénérante de Vek'nilash	End +16 · Int +18 · Esp +13 · Soins +55	
21610	off	4	6	4	81	60	Bouclier en écailles de ver	End +10 · Int +13 · Dégâts sorts +12 · Soins +35 · Mana/5 +6	
21611	wrist	4	1	4	81	60	Brassards de fouisseur	End +10 · Int +13 · Puiss. sorts +28	
21612	feet	4	3	4	81	60	Marteleurs en écailles de ver	Agi +26 · End +12 · Int +12 · Puiss. sorts +15 · Mana/5 +5	
21613	feet	4	2	4	81	60	Bottes en peau de ver	For +18 · Agi +32 · End +13	
21614	head	4	2	4	81	60	Protecteur en peau de ver	For +18 · Agi +24 · End +26 · Rés. nature +30	
21615	head	4	1	4	81	60	Chapeau égaré de Don Rigoberto	End +18 · Int +24 · Dégâts sorts +21 · Soins +64 · Mana/5 +11	
21616	ranged	2	2	4	78	60	Aiguillon d'Huhuran	Agi +24	
21618	wrist	4	4	4	78	60	Garde-poignets de profanateur de ruche	For +23 · Agi +18	
21619	hands	4	1	4	78	60	Gants du messie	End +13 · Int +17 · Dégâts sorts +9 · Soins +26 · Mana/5 +10	
21620	finger	4	0	4	78	60	Anneau du martyr	End +10 · Soins +51 · Mana/5 +5	
21622	main	2	7	4	78	60	Fémur de silithide aiguisé	End +14 · Int +7 · Crit. +14	
21623	hands	4	4	4	78	60	Gantelets du champion vertueux	For +15 · End +17 · Int +13 · Esp +10 · Puiss. sorts +16	
21624	hands	4	3	4	78	60	Gantelets de Kalimdor	For +14 · End +15 · Int +13 · Esp +10 · Puiss. sorts +20	
21625	trinket	4	0	4	78	60	Broche scarabée		
21639	shoulder	4	4	4	77	60	Espauliers de l'Implacable	For +11 · End +30 · Déf. +9 · Esquive +12	
21645	feet	4	2	4	77	60	Bottes de tunnelière de la ruche	For +10 · Agi +17 · End +30 · Armure +60	
21647	trinket	4	0	4	77	60	Fétiche du ravageur des sables		
21648	feet	4	1	4	76	60	Bottes recomposées	End +21 · Int +13 · Puiss. sorts +20 · Rés. nature +20	
21650	one	2	7	4	77	60	Ancien éventreur qiraji	End +11 · PA +20 · Crit. +14	
21663	chest	4	1	4	77	60	Robe du saint gardien	End +20 · Int +22 · Dégâts sorts +23 · Soins +70 · Mana/5 +7	
21664	neck	4	0	4	77	60	Collier barbelé	End +10 · PA +44 · Crit. +14	
21665	shoulder	4	2	4	77	60	Mantelet de vengeance cruelle	For +16 · Agi +30 · End +14	
21667	legs	4	4	4	76	60	Cuissards de lumière flamboyante	For +9 · End +17 · Int +23 · Soins +68 · Crit. +14	
21669	head	4	2	4	76	60	Casque des lianes rampantes	End +26 · Int +23 · Esp +17 · Soins +59	
21670	trinket	4	0	4	76	60	Insigne de garde-essaim		
21672	hands	4	2	4	76	60	Gants de coercition	For +28 · Agi +20 · End +6 · Toucher +10	
21674	hands	4	4	4	76	60	Gantelets de détermination inébranlable	For +19 · Agi +18 · End +20 · Déf. +9	
21677	finger	4	0	4	78	60	Anneau de fureur qiraji	End +12 · PA +40 · Crit. +14	
21678	neck	4	0	4	76	60	Collier de pureté	End +9 · Int +13 · Puiss. sorts +8 · Rés. nature +20	
21681	finger	4	0	4	78	60	Anneau du dévoré	End +10 · Int +13 · Soins +15 · Mana/5 +8	
21685	trinket	4	0	4	76	60	Scarabée pétrifié		
21687	finger	4	0	4	76	60	Anneau de ténèbres d'Ukko	End +13 · Rés. ombre +20	
21690	neck	4	0	4	75	60	Charme d'Angelista	End +13 · Int +14 · Soins +31 · Mana/5 +6	
21693	head	4	2	4	75	60	Semblance du dévoreur	For +17 · Agi +19 · End +36 · Esquive +12 · Armure +70	
21694	shoulder	4	1	4	75	60	Mantelet ternaire	End +12 · Int +17 · Esp +20 · Soins +44	
21695	finger	4	0	4	75	60	Toucher d'Angelista	For +11 · End +17 · Déf. +6 · Esquive +12	
21700	neck	4	0	4	73	60	Pendentif du gardien qiraji	For +12 · Agi +11 · End +17 · Déf. +6	
21702	neck	4	0	4	73	60	Amulette de vile sauvegarde	End +12 · PA +24 · Rés. nature +20	
21707	finger	4	0	4	73	60	Anneau de pensée foisonnante	Puiss. sorts +26	
21709	finger	4	0	4	88	60	Anneau du dieu déchu	End +5 · Int +6 · Puiss. sorts +37 · Toucher +10	
21710	back	4	1	4	88	60	Cape du dieu déchu	For +11 · Agi +26 · End +15	
21712	neck	4	0	4	88	60	Amulette du dieu déchu	End +11 · Soins +57 · Mana/5 +6	
21782	one	2	7	3	63	58	2000 Test sword 63 blue		
21809	neck	4	0	3	71	60	Fureur de l'essaim oublié	For +8 · Crit. +14 · Toucher +10	
21836	finger	4	0	4	71	60	Anneau du chaos de Rytssin	End +6 · Puiss. sorts +25 · Crit. +14	
21839	main	2	4	4	84	60	Sceptre du faux prophète	End +10 · Int +19 · Mana/5 +3	
21888	hands	4	1	4	71	60	Gants de l'immortel	End +28 · Int +16 · Armure +120	
21890	hands	4	3	4	75	60	Gants du prophète déchu	For +12 · End +17 · Int +20 · Soins +44	
21891	trinket	4	0	4	75	60	Fragment de l'étoile tombée		
21994	waist	4	4	3	65	0	Ceinture d'héroïsme	For +15 · Agi +9 · End +12 · Déf. +7	
21995	feet	4	4	4	60	0	Bottes d'héroïsme	For +20 · End +20 · Toucher +10	
21996	wrist	4	4	3	65	0	Brassards d'héroïsme	For +9 · Agi +5 · End +14 · Déf. +3	
21997	chest	4	4	4	60	0	Cuirasse d'héroïsme	For +21 · Agi +13 · End +26 · Toucher +10	
21998	hands	4	4	4	55	0	Gantelets d'héroïsme	For +18 · End +12 · Crit. +14	
21999	head	4	4	4	60	0	Casque d'héroïsme	For +18 · End +32 · Crit. +14	
22000	legs	4	4	3	66	0	Cuissards d'héroïsme	For +25 · Agi +11 · End +16 · Déf. +5	
22001	shoulder	4	4	3	65	0	Spallières d'héroïsme	For +12 · Agi +12 · End +18	
22002	waist	4	2	3	65	0	Ceinture Sombremante	For +10 · Agi +17 · End +13	
22003	feet	4	2	4	60	0	Bottes Sombremante	Agi +24 · End +10	
22004	wrist	4	2	3	65	0	Brassards Sombremante	For +7 · Agi +15 · End +7	
22005	head	4	2	4	60	0	Coiffe Sombremante	For +13 · Agi +26 · End +18 · Crit. +14	
22006	hands	4	2	4	55	0	Gants Sombremante	For +12 · Agi +22 · End +9	
22007	legs	4	2	3	66	0	Pantalon Sombremante	For +15 · Agi +25 · End +15	
22008	shoulder	4	2	3	65	0	Spallières Sombremante	Agi +24 · End +10	
22009	chest	4	2	4	60	0	Tunique Sombremante	Agi +31 · End +15 · Toucher +20	
22010	waist	4	3	3	65	0	Ceinture de belluaire	Agi +16 · End +16 · Int +10	
22011	wrist	4	3	3	65	0	Manchettes de belluaire	Agi +16 · End +7 · Int +5	
22013	head	4	3	4	60	0	Coiffe de belluaire	Agi +22 · End +21 · Int +12 · Toucher +10	
22015	hands	4	3	4	55	0	Gants de belluaire	Agi +14 · End +12 · Int +10	
22016	shoulder	4	3	3	65	0	Mantelet de belluaire	Agi +12 · End +18 · Int +10	
22017	legs	4	3	3	66	0	Pantalon de belluaire	Agi +28 · End +14 · Int +9	
22060	chest	4	3	4	60	0	Tunique de belluaire	Agi +25 · End +16 · Int +13 · Crit. +14	
22061	feet	4	3	4	60	0	Bottes de belluaire	Agi +24 · End +9	
22062	waist	4	1	3	65	0	Ceinture du sorcier	End +12 · Int +14 · Esp +7 · Puiss. sorts +14	
22063	wrist	4	1	3	65	0	Manchettes du sorcier	End +8 · Int +12 · Esp +5 · Puiss. sorts +8	
22064	feet	4	1	4	60	0	Bottes du sorcier	End +14 · Int +16 · Esp +10 · Puiss. sorts +21	
22065	head	4	1	4	60	0	Couronne du sorcier	End +16 · Int +25 · Esp +14 · Puiss. sorts +11 · Crit. +14	
22066	hands	4	1	4	55	0	Gants du sorcier	End +12 · Int +14 · Esp +10 · Puiss. sorts +12 · Toucher +10	
22067	legs	4	1	3	66	0	Jambières du sorcier	End +17 · Int +22 · Esp +10 · Puiss. sorts +16	
22068	shoulder	4	1	3	65	0	Mantelet du sorcier	End +11 · Int +17 · Esp +7 · Puiss. sorts +9	
22069	chest	4	1	4	60	0	Robe du sorcier	End +14 · Int +25 · Esp +9 · Puiss. sorts +16	
22070	waist	4	1	3	65	0	Ceinture Mortebrume	End +16 · Int +16 · Puiss. sorts +12	
22071	wrist	4	1	3	65	0	Brassards Mortebrume	End +12 · Int +12 · Puiss. sorts +8	
22072	legs	4	1	3	66	0	Jambières Mortebrume	End +22 · Int +21 · Puiss. sorts +16	
22073	shoulder	4	1	3	65	0	Mantelet Mortebrume	End +16 · Int +16 · Puiss. sorts +12	
22074	head	4	1	4	60	0	Masque Mortebrume	End +24 · Int +24 · Puiss. sorts +16 · Toucher +10	
22075	chest	4	1	4	60	0	Robe Mortebrume	End +27 · Int +22 · Puiss. sorts +12 · Crit. +14	
22076	feet	4	1	4	60	0	Sandales Mortebrume	End +24 · Int +14 · Puiss. sorts +12	
22077	hands	4	1	4	55	0	Protège-mains Mortebrume	End +16 · Int +13 · Puiss. sorts +13 · Toucher +10	
22078	waist	4	1	3	65	0	Ceinture vertueuse	End +12 · Int +13 · Esp +12 · Puiss. sorts +12	
22079	wrist	4	1	3	65	0	Brassards vertueux	End +8 · Int +8 · Esp +8 · Puiss. sorts +9 · Mana/5 +2	
22080	head	4	1	4	60	0	Couronne vertueuse	End +16 · Int +17 · Esp +16 · Puiss. sorts +11 · Crit. +14	
22081	hands	4	1	4	55	0	Gants vertueux	End +14 · Int +15 · Esp +12 · Puiss. sorts +11	
22082	shoulder	4	1	3	65	0	Mantelet vertueux	End +12 · Int +13 · Esp +12 · Puiss. sorts +12	
22083	chest	4	1	4	60	0	Robe vertueuse	End +21 · Int +22 · Esp +12 · Puiss. sorts +14 · Mana/5 +6	
22084	feet	4	1	4	60	0	Sandales vertueuses	End +12 · Int +13 · Esp +12 · Puiss. sorts +12 · Mana/5 +7	
22085	legs	4	1	3	66	0	Jupe vertueuse	End +13 · Int +14 · Esp +12 · Puiss. sorts +16 · Mana/5 +6	
22086	waist	4	4	3	65	0	Ceinture d'Âmeforge	For +10 · End +11 · Int +11 · Puiss. sorts +12 · Mana/5 +4	
22087	feet	4	4	4	60	0	Bottes d'Âmeforge	For +12 · End +13 · Int +12 · Esp +10 · Puiss. sorts +12	
22088	wrist	4	4	3	65	0	Brassards d'Âmeforge	For +9 · End +10 · Int +9 · Puiss. sorts +8	
22089	chest	4	4	4	60	0	Cuirasse d'Âmeforge	For +16 · End +17 · Int +17 · Esp +12 · Puiss. sorts +14	
22090	hands	4	4	4	55	0	Gantelets d'Âmeforge	For +9 · End +10 · Int +10 · Puiss. sorts +11 · Crit. +14	
22091	head	4	4	4	60	0	Casque d'Âmeforge	For +16 · End +17 · Int +17 · Esp +12 · Puiss. sorts +14	
22092	legs	4	4	3	66	0	Cuissards d'Âmeforge	For +16 · End +17 · Int +17 · Esp +10 · Puiss. sorts +11	
22093	shoulder	4	4	3	65	0	Spallières d'Âmeforge	For +10 · End +11 · Int +11 · Puiss. sorts +12 · Mana/5 +4	
22095	wrist	4	3	3	65	0	Manchettes des Cinq tonnerres	End +10 · Int +9 · Esp +9 · Puiss. sorts +8	
22096	feet	4	3	4	60	0	Bottes des Cinq tonnerres	For +12 · End +13 · Int +12 · Esp +10 · Puiss. sorts +12	
22097	head	4	3	4	60	0	Coiffe des Cinq tonnerres	End +22 · Int +21 · Esp +12 · Puiss. sorts +14 · Crit. +14	
22098	waist	4	3	3	65	0	Corde des Cinq tonnerres	For +10 · End +11 · Int +11 · Puiss. sorts +12 · Mana/5 +4	
22099	hands	4	3	4	55	0	Gantelets des cinq tonnerres	For +9 · End +12 · Int +14 · Puiss. sorts +12 · Mana/5 +4	
22100	legs	4	3	3	66	0	Kilt des Cinq tonnerres	For +10 · End +17 · Int +17 · Esp +16 · Puiss. sorts +11	
22101	shoulder	4	3	3	65	0	Espauliers des Cinq tonnerres	For +10 · End +11 · Int +11 · Esp +10 · Puiss. sorts +12	
22102	chest	4	3	4	60	0	Gilet des Cinq tonnerres	For +12 · End +17 · Int +17 · Esp +16 · Puiss. sorts +14	
22106	waist	4	2	3	65	0	Ceinture Cœur-Farouche	For +6 · Agi +7 · End +9 · Int +12 · Esp +8	
22107	feet	4	2	4	60	0	Bottes Cœur-Farouche	For +12 · Agi +7 · End +13 · Int +12 · Esp +10	
22108	wrist	4	2	3	65	0	Brassards Cœur-Farouche	For +6 · Agi +6 · End +6 · Int +12 · Esp +5	
22109	head	4	2	4	60	0	Capuche Cœur-Farouche	For +14 · Agi +9 · End +17 · Int +17 · Esp +16	
22110	hands	4	2	4	55	0	Gants Cœur-Farouche	For +10 · Agi +9 · End +10 · Int +12 · Esp +10	
22111	legs	4	2	3	66	0	Kilt Cœur-Farouche	For +14 · Agi +12 · End +14 · Int +14 · Esp +14	
22112	shoulder	4	2	3	65	0	Spallières Cœur-Farouche	For +8 · Agi +5 · End +9 · Int +16 · Esp +8	
22113	chest	4	2	4	60	0	Gilet Cœur-Farouche	For +16 · Agi +9 · End +17 · Int +17 · Esp +14	
22149	neck	4	0	3	63	0	Perles de mojo ogre	End +7 · Int +12 · Puiss. sorts +13	
22150	neck	4	0	3	63	0	Perles de puissance ogre	End +7 · PA +24 · Toucher +10	
22191	chest	4	3	4	72	60	Tunique de mailles en obsidienne	PA +76 · Crit. +14	c164:1
22194	hands	4	3	4	70	60	Emprise noire du Destructeur	PA +28 · Crit. +14	c164:1
22195	waist	4	3	3	68	60	Ceinture légère en obsidienne	PA +32 · Crit. +14	c164:1
22196	chest	4	4	4	72	60	Cuirasse épaisse en obsidienne	For +38 · End +16	c164:1
22197	waist	4	4	3	68	60	Ceinture lourde en obsidienne	For +25	c164:1
22198	off	4	6	4	70	60	Bouclier dentelé en obsidienne	Blocage +10	c164:1
22206	off	4	0	2	1	0	Bouquet de roses rouges		
22230	back	4	1	3	52	0	Peau Gueule-d'horreur	For +15 · Armure +40	
22273	head	4	2	3	52	0	Chaperon d'ombrelune	Int +15 · Puiss. sorts +18 · Crit. +14	
22316	ranged	4	7	3	20	10	Test Relic	Int +3 · Rés. feu +10 · Rés. ombre +10	
22347	ranged	2	18	3	65	0	Arbalète à répétition de Fahrad	Agi +5 · Toucher +13	
22348	two	2	5	3	65	0	Mortulus prime	For +22 · End +22 · Toucher +10	
22377	one	2	15	3	65	0	Le tisonnier de Thunderwood	Agi +13 · End +6	
22378	one	2	7	3	65	0	Trancheur de Ravenholdt	End +6 · PA +26	
22379	main	2	15	3	65	0	Kriss de Shivsprocket	End +13	
22380	main	2	4	3	65	0	Marteau de culture de Simona	Int +6	
22383	main	2	7	4	64	59	Lame feuille-de-saule	End +14 · Int +6 · Toucher +10	c164:1
22384	one	2	4	4	63	58	Eloquente	Crit. +14 · Toucher +10	c164:1
22385	legs	4	4	4	60	55	Jambières titanesques	For +30 · Crit. +14 · Toucher +20	c164:1
22391	two	2	10	3	63	58	Monster - Staff, Lord Valthalak	Crit. +14	
22396	ranged	4	9	4	78	60	Totem de vie		
22399	ranged	4	8	4	78	60	Idole de santé		
22402	ranged	4	7	4	78	60	Libram de grâce		
22416	chest	4	4	4	92	60	Cuirasse de cuirassier	For +21 · End +43 · Toucher +20 · Déf. +13 · Esquive +12	
22417	legs	4	4	4	88	60	Cuissards de cuirassier	For +23 · End +37 · Déf. +13 · Esquive +12	
22418	head	4	4	4	88	60	Casque de cuirassier	For +21 · End +45 · Déf. +14 · Esquive +12	
22419	shoulder	4	4	4	86	60	Espauliers de cuirassier	For +16 · End +29 · Toucher +10 · Déf. +9	
22420	feet	4	4	4	86	60	Solerets de cuirassier	For +15 · End +34 · Déf. +9 · Esquive +12	
22421	hands	4	4	4	88	60	Gantelets de cuirassier	For +17 · End +27 · Déf. +9 · Blocage +15	
22422	waist	4	4	4	88	60	Sangle de cuirassier	For +20 · End +26 · Déf. +9 · Blocage +15	
22423	wrist	4	4	4	88	60	Brassards de cuirassier	For +14 · End +28 · Déf. +5	
22424	wrist	4	4	4	88	60	Protège-poignets de rédemption	End +22 · Int +15 · Soins +31 · Mana/5 +4	
22425	chest	4	4	4	92	60	Tunique de rédemption	End +25 · Int +31 · Soins +59 · Crit. +14 · Mana/5 +10	
22426	hands	4	4	4	88	60	Garde-mains de rédemption	End +23 · Int +22 · Soins +33 · Mana/5 +8	
22427	legs	4	4	4	88	60	Cuissards de rédemption	End +30 · Int +31 · Soins +42 · Crit. +14 · Mana/5 +8	
22428	head	4	4	4	88	60	Couvre-chef de rédemption	End +28 · Int +26 · Soins +64 · Crit. +14 · Mana/5 +8	
22429	shoulder	4	4	4	86	60	Spallières de rédemption	End +22 · Int +20 · Soins +40 · Crit. +14 · Mana/5 +4	
22430	feet	4	4	4	86	60	Bottes de rédemption	End +22 · Int +18 · Soins +42 · Crit. +14 · Mana/5 +5	
22431	waist	4	4	4	88	60	Ceinturon de rédemption	End +19 · Int +29 · Soins +40 · Mana/5 +5	
22436	chest	4	3	4	92	60	Tunique de traqueur des cryptes	Agi +45 · End +27 · Int +15 · Crit. +14 · Toucher +10	
22437	legs	4	3	4	88	60	Cuissards de traqueur des cryptes	Agi +42 · End +26 · Int +10 · Crit. +14 · Mana/5 +6	
22438	head	4	3	4	88	60	Couvre-chef de traqueur des cryptes	Agi +31 · End +30 · Int +12 · Crit. +28 · Mana/5 +3	
22439	shoulder	4	3	4	86	60	Spallières de traqueur des cryptes	Agi +29 · End +23 · Int +10 · Crit. +14	
22440	feet	4	3	4	86	60	Bottes de traqueur des cryptes	Agi +33 · End +19 · Int +8 · Toucher +10	
22441	hands	4	3	4	88	60	Garde-mains de traqueur des cryptes	Agi +24 · End +21 · Int +15 · Crit. +14 · Mana/5 +4	
22442	waist	4	3	4	88	60	Ceinturon de traqueur des cryptes	Agi +23 · End +22 · Int +12 · Crit. +14 · Toucher +10	
22443	wrist	4	3	4	88	60	Protège-poignets de traqueur des cryptes	Agi +26 · End +16 · Toucher +10	
22464	chest	4	3	4	92	60	Tunique de Brise-terre	End +26 · Int +32 · Soins +59 · Mana/5 +12	
22465	legs	4	3	4	88	60	Kilt de Brise-terre	End +28 · Int +30 · Soins +59 · Mana/5 +9	
22466	head	4	3	4	88	60	Couvre-chef de Brise-terre	End +26 · Int +30 · Soins +68 · Mana/5 +8	
22467	shoulder	4	3	4	86	60	Spallières de Brise-terre	End +24 · Int +19 · Soins +42 · Mana/5 +6	
22468	feet	4	3	4	86	60	Bottes de Brise-terre	End +20 · Int +25 · Soins +37 · Mana/5 +6	
22469	hands	4	3	4	88	60	Garde-mains de Brise-terre	End +21 · Int +28 · Soins +35 · Mana/5 +6	
22470	waist	4	3	4	88	60	Ceinturon de Brise-terre	End +18 · Int +25 · Soins +42 · Mana/5 +7	
22471	wrist	4	3	4	88	60	Protège-poignets de Brise-terre	End +17 · Int +18 · Soins +33 · Mana/5 +4	
22476	chest	4	2	4	92	60	Cuirasse de la faucheuse d'os	End +29 · PA +80 · Crit. +28 · Toucher +10	
22477	legs	4	2	4	88	60	Cuissots de la faucheuse d'os	For +31 · Agi +32 · End +25 · Crit. +14 · Toucher +10	
22478	head	4	2	4	88	60	Casque de la faucheuse d'os	For +18 · Agi +30 · End +29 · Crit. +28 · Toucher +10	
22479	shoulder	4	2	4	86	60	Espauliers de la faucheuse d'os	For +22 · Agi +22 · End +15 · Crit. +14 · Toucher +10	
22480	feet	4	2	4	86	60	Solerets de la faucheuse d'os	End +18 · PA +64 · Crit. +14 · Toucher +10	
22481	hands	4	2	4	88	60	Gantelets de la faucheuse d'os	End +20 · PA +66 · Crit. +14 · Toucher +10	
22482	waist	4	2	4	88	60	Sangle de la faucheuse d'os	For +23 · Agi +24 · End +20 · Crit. +14	
22483	wrist	4	2	4	88	60	Brassards de la faucheuse d'os	Agi +26 · End +14 · Crit. +14	
22488	chest	4	2	4	92	60	Tunique de marcherêve	End +29 · Int +29 · Esp +19 · Soins +66 · Mana/5 +8	
22489	legs	4	2	4	88	60	Cuissards de marcherêve	End +22 · Int +26 · Esp +20 · Soins +66 · Mana/5 +8	
22490	head	4	2	4	88	60	Couvre-chef de marcherêve	End +25 · Int +31 · Esp +20 · Soins +66	
22491	shoulder	4	2	4	86	60	Spallières de marcherêve	End +18 · Int +22 · Esp +12 · Soins +48 · Mana/5 +5	
22492	feet	4	2	4	86	60	Bottes de marcherêve	End +20 · Int +20 · Esp +14 · Soins +46 · Mana/5 +5	
22493	hands	4	2	4	88	60	Garde-mains de marcherêve	End +17 · Int +22 · Esp +16 · Soins +53	
22494	waist	4	2	4	88	60	Ceinturon de marcherêve	End +14 · Int +23 · Esp +13 · Soins +51 · Mana/5 +4	
22495	wrist	4	2	4	88	60	Protège-poignets de marcherêve	End +14 · Int +16 · Soins +40 · Mana/5 +5	
22496	chest	4	1	4	92	60	Robe de givrefeu	End +21 · Int +27 · Puiss. sorts +47 · Crit. +14 · Toucher +10	
22497	legs	4	1	4	88	60	Jambières de givrefeu	End +25 · Int +26 · Esp +10 · Puiss. sorts +46 · Toucher +10	
22498	head	4	1	4	88	60	Diadème de givrefeu	End +22 · Int +23 · Puiss. sorts +35 · Crit. +28 · Toucher +10	
22499	shoulder	4	1	4	86	60	Protège-épaules de givrefeu	End +17 · Int +18 · Esp +9 · Puiss. sorts +36	
22500	feet	4	1	4	86	60	Sandales de givrefeu	End +17 · Int +18 · Esp +10 · Puiss. sorts +28 · Crit. +14	
22501	hands	4	1	4	88	60	Gants de givrefeu	End +17 · Int +19 · Esp +10 · Puiss. sorts +36	
22502	waist	4	1	4	88	60	Ceinture de givrefeu	End +19 · Int +21 · Esp +10 · Puiss. sorts +28 · Toucher +10	
22503	wrist	4	1	4	88	60	Manchettes de givrefeu	End +14 · Int +15 · Puiss. sorts +27	
22504	chest	4	1	4	92	60	Robe de pestecoeur	End +27 · Int +22 · Puiss. sorts +51 · Crit. +14 · Toucher +10	
22505	legs	4	1	4	88	60	Jambières de pestecoeur	End +30 · Int +25 · Puiss. sorts +37 · Crit. +14	
22506	head	4	1	4	88	60	Diadème de pestecoeur	End +28 · Int +25 · Puiss. sorts +33 · Crit. +28 · Toucher +10	
22507	shoulder	4	1	4	86	60	Protège-épaules de pestecoeur	End +22 · Int +12 · Puiss. sorts +36 · Toucher +10	
22508	feet	4	1	4	86	60	Sandales de pestecoeur	End +20 · Int +16 · Puiss. sorts +32 · Crit. +14	
22509	hands	4	1	4	88	60	Gants de pestecoeur	End +25 · Int +17 · Puiss. sorts +26 · Crit. +14	
22510	waist	4	1	4	88	60	Ceinture de pestecoeur	End +23 · Int +12 · Puiss. sorts +34 · Crit. +14	
22511	wrist	4	1	4	88	60	Manchettes de pestecoeur	End +23 · Int +14 · Puiss. sorts +23	
22512	chest	4	1	4	92	60	Robe de foi	End +26 · Int +27 · Esp +21 · Soins +64 · Mana/5 +5	
22513	legs	4	1	4	88	60	Jambières de foi	End +25 · Int +26 · Esp +28 · Soins +66	
22514	head	4	1	4	88	60	Diadème de foi	End +22 · Int +22 · Esp +22 · Soins +75 · Mana/5 +5	
22515	shoulder	4	1	4	86	60	Protège-épaules de foi	End +17 · Int +18 · Esp +17 · Soins +51 · Mana/5 +3	
22516	feet	4	1	4	86	60	Sandales de foi	End +19 · Int +22 · Esp +13 · Soins +44 · Mana/5 +6	
22517	hands	4	1	4	88	60	Gants de foi	End +16 · Int +21 · Esp +22 · Soins +40 · Mana/5 +4	
22518	waist	4	1	4	88	60	Ceinture de foi	End +18 · Int +23 · Esp +17 · Soins +48	
22519	wrist	4	1	4	88	60	Manchettes de foi	End +11 · Int +15 · Esp +17 · Soins +40	
22589	two	2	10	5	90	60	Atiesh, grand bâton du Gardien	End +31 · Int +32 · Esp +24 · Puiss. sorts +150 · Toucher +20	
22630	two	2	10	5	90	60	Atiesh, grand bâton du Gardien	End +30 · Int +29 · Puiss. sorts +150 · Crit. +28	
22631	two	2	10	5	90	60	Atiesh, grand bâton du Gardien	End +28 · Int +28 · Esp +27 · Puiss. sorts +120 · Soins +180	
22632	two	2	10	5	90	60	Atiesh, grand bâton du Gardien	End +28 · Int +28 · Esp +27 · Soins +300	
22651	legs	4	4	4	65	60	Jambières de voltigeur en plaques	For +28 · End +27 · Crit. +14 · Toucher +10	
22652	chest	4	1	4	80	60	Gilet glaciaire	End +26 · Puiss. sorts +21 · Rés. givre +40	c197:1
22654	hands	4	1	4	80	60	Gants glaciaires	End +22 · Puiss. sorts +15 · Rés. givre +30	c197:1
22655	wrist	4	1	4	80	60	Poignets glaciaires	End +20 · Puiss. sorts +12 · Rés. givre +20	c197:1
22656	ranged	2	3	4	60	0	Le Purificateur	Crit. +18	
22657	neck	4	0	4	60	0	Amulette de l'Aube	End +13 · Int +13 · Puiss. sorts +15	
22658	back	4	1	4	80	60	Cape glaciaire	End +18 · Rés. givre +24	c197:1
22659	neck	4	0	4	60	0	Médaillon de l'Aube	End +12 · PA +24 · Crit. +14	
22660	back	4	1	3	70	60	Etreinte de Gaïa	End +6 · Rés. nature +20	c197:1
22661	chest	4	2	4	80	60	Tunique polaire	Agi +18 · End +26 · Rés. givre +40	c165:1
22662	hands	4	2	4	80	60	Gants polaires	Agi +18 · End +18 · Rés. givre +30	c165:1
22663	wrist	4	2	4	80	60	Brassards polaires	Agi +12 · End +20 · Rés. givre +20	c165:1
22664	chest	4	3	4	80	60	Cuirasse glacécaille	End +24 · PA +40 · Rés. givre +40	c165:1
22665	wrist	4	3	4	80	60	Brassards glacécaille	End +17 · PA +32 · Rés. givre +20	c165:1
22666	hands	4	3	4	80	60	Gantelets glacécaille	End +22 · PA +22 · Rés. givre +30	c165:1
22667	wrist	4	1	4	60	0	Brassards d'espoir	End +10 · Int +11 · Esp +12 · Dégâts sorts +6 · Soins +18	
22668	wrist	4	2	4	60	0	Brassards de subterfuge	For +10 · Agi +15 · End +12	
22669	chest	4	4	4	80	60	Cuirasse plaie-de-glace	For +12 · End +24 · Déf. +8 · Rés. givre +42	c164:1
22670	hands	4	4	4	80	60	Gantelets plaie-de-glace	For +9 · End +18 · Déf. +5 · Rés. givre +32	c164:1
22671	wrist	4	4	4	80	60	Brassards plaie-de-glace	For +6 · End +13 · Déf. +5 · Rés. givre +24	c164:1
22672	legs	4	4	4	65	60	Cuissards de sentinelle en plaques	For +28 · End +27 · Crit. +14 · Toucher +10	
22673	legs	4	3	4	65	60	Jambières de voltigeur en anneaux	Agi +35 · End +15 · Crit. +14 · Toucher +10	
22676	legs	4	3	4	65	60	Jambières de voltigeur en mailles	For +14 · End +22 · Int +22 · Crit. +14 · Mana/5 +6	
22678	trinket	4	0	4	60	0	Talisman d'ascendance		
22680	finger	4	0	3	66	0	Bague de résolution	End +18 · Déf. +5	
22681	finger	4	0	3	66	0	Bague de piété	End +10 · Int +10 · Dégâts sorts +7 · Soins +22 · Mana/5 +4	
22688	main	2	15	3	66	0	Dernière chance de Verimonde	End +7 · Int +8	
22689	head	4	2	3	66	0	Casque sanctifié en cuir	End +14 · Int +19 · Esp +12 · Dégâts sorts +13 · Soins +40	
22690	legs	4	3	3	66	0	Jambières du chassepeste	Agi +20 · End +16 · Int +10 · Crit. +14	
22699	legs	4	4	4	80	0	Jambières plaie-de-glace	For +10 · End +25 · Déf. +6 · Rés. givre +40	
22700	legs	4	1	4	80	0	Jambières glaciaires	End +28 · Puiss. sorts +18 · Rés. givre +40	
22701	legs	4	2	4	80	0	Jambières polaires	Agi +15 · End +28 · Rés. givre +40	
22702	legs	4	3	4	80	0	Jambières glacécaille	Agi +15 · End +28 · Rés. givre +40	
22707	finger	4	0	4	80	0	Etreinte de glace de Ramaladni	End +15 · Rés. givre +25	
22725	finger	4	0	3	70	0	Bague de Cenarius	End +10 · Rés. nature +19	
22732	neck	4	0	4	88	60	Marque de C'Thun	End +24 · Toucher +10 · Déf. +10 · Esquive +12	
22740	legs	4	2	4	65	60	Pantalon de voltigeur en cuir	Agi +28 · End +27 · Crit. +14 · Armure +60	
22741	legs	4	2	4	65	60	Pantalon de voltigeur en peau de lézard	For +22 · Agi +10 · End +22 · Int +22 · Esp +9	
22742	chest	4	5	2	1	1	Chemise de la Voile sanglante		
22743	waist	4	5	2	1	1	Echarpe de la Voile sanglante		
22744	feet	4	5	2	1	1	Bottes de la Voile sanglante		
22745	legs	4	5	2	1	1	Pantalon de la Voile sanglante		
22747	legs	4	1	4	65	60	Jambière de voltigeur en soie	End +23 · Int +19 · Esp +10 · Puiss. sorts +28 · Armure +100	
22748	legs	4	3	4	65	60	Jambières de sentinelle en anneaux	Agi +35 · End +15 · Crit. +14 · Toucher +10	
22749	legs	4	2	4	65	60	Pantalon de sentinelle en cuir	Agi +28 · End +27 · Crit. +14 · Armure +60	
22750	legs	4	2	4	65	60	Pantalon de sentinelle en peau de lézard	For +22 · Agi +10 · End +22 · Int +22 · Esp +9	
22752	legs	4	1	4	65	60	Jambières de sentinelle en soie	End +23 · Int +19 · Esp +10 · Puiss. sorts +28 · Armure +100	
22753	legs	4	4	4	65	60	Cuissards de sentinelle lamellaires	For +21 · End +21 · Puiss. sorts +25 · Crit. +14 · Toucher +10	
22756	chest	4	1	3	70	60	Gilet sylvestre	End +15 · Puiss. sorts +12 · Rés. nature +30	c197:1
22757	head	4	1	3	70	60	Couronne sylvestre	End +10 · Puiss. sorts +18 · Rés. nature +30	c197:1
22758	shoulder	4	1	3	70	60	Epaulières sylvestres	End +18 · Puiss. sorts +7 · Rés. nature +20	c197:1
22759	head	4	2	3	70	60	Casque de la ronceraie	End +20 · Rés. nature +30	c165:1
22760	feet	4	2	3	70	60	Bottes de la ronceraie	End +12 · Rés. nature +25	c165:1
22761	waist	4	2	3	70	60	Ceinture de la ronceraie	End +14 · Rés. nature +15	c165:1
22805	one	2	7	4	77	60	Naxxramas Sword 1H 1 [PH]	For +14 · Agi +14 · End +7	
22814	two	2	8	4	81	60	Naxxramas Sword 2H 2 [PH]	End +33 · PA +86	
22817	two	2	6	4	77	60	Naxxramas Polearm [PH]	Agi +41 · End +31	
22843	feet	4	3	3	66	60	Grèves de garde de sang en anneaux	Agi +20 · End +19	
22852	feet	4	2	3	66	60	Bottines de garde de sang en peau de dragon	For +13 · Agi +6 · End +13 · Int +6 · Esp +6	
22855	feet	4	1	3	66	60	Brodequins de garde de sang en tisse-effroi	End +17 · Int +13 · Puiss. sorts +18	
22856	feet	4	2	3	66	60	Brodequins de garde de sang en cuir	End +18 · PA +28 · Armure +40	
22857	feet	4	3	3	66	60	Grèves de garde de sang en mailles	For +13 · End +14 · Int +12	
22858	feet	4	4	3	66	60	Grèves de garde de sang en plaques	For +10 · Agi +9 · End +23	
22859	feet	4	1	3	66	60	Brodequins de garde de sang en satin	End +17 · Int +15 · Puiss. sorts +14	
22860	feet	4	1	3	66	60	Brodequins de garde de sang en soie	End +15 · Int +10 · Puiss. sorts +15 · Toucher +10 · Armure +40	
22862	hands	4	3	3	66	60	Cestes de garde de sang en anneaux	Agi +18 · End +16	
22863	hands	4	2	3	66	60	Poignes de garde de sang en peau de dragon	For +13 · Agi +10 · End +12 · Int +9	
22864	hands	4	2	3	66	60	Poignes de garde de sang en cuir	End +18 · PA +20 · Crit. +14 · Armure +40	
22865	hands	4	1	3	66	60	Protège-mains de garde de sang en tisse-effroi	End +14 · Int +4 · Puiss. sorts +21	
22867	hands	4	3	3	66	60	Cestes de garde de sang en mailles	End +15 · Int +9 · Puiss. sorts +13 · Crit. +14	
22868	hands	4	4	3	66	60	Gantelets de garde de sang en plaques	For +17 · End +17	
22869	hands	4	1	3	66	60	Protège-mains de garde de sang en satin	End +12 · Int +5 · Puiss. sorts +21 · Armure +40	
22870	hands	4	1	3	66	60	Protège-mains de garde de sang en soie	End +12 · Int +10 · Puiss. sorts +18 · Armure +40	
22872	chest	4	4	3	68	60	Armure de légionnaire en plaques	For +21 · End +23 · Crit. +14	
22873	legs	4	4	3	68	60	Jambières de légionnaire en plaques	For +12 · End +17 · Crit. +28	
22874	chest	4	3	3	68	60	Haubert de légionnaire en anneaux	Agi +16 · End +13 · Int +6 · Crit. +28	
22875	legs	4	3	3	68	60	Cuissards de légionnaire en anneaux	Agi +16 · End +13 · Int +6 · Crit. +28	
22876	chest	4	3	3	68	60	Haubert de légionnaire en mailles	For +17 · End +18 · Int +18 · Crit. +14	
22877	chest	4	2	3	68	60	Plastron de légionnaire en peau de dragon	For +13 · Agi +12 · End +13 · Int +12 · Puiss. sorts +15	
22878	legs	4	2	3	68	60	Jambières de légionnaire en peau de dragon	For +12 · Agi +12 · End +12 · Int +12 · Esp +5	
22879	chest	4	2	3	68	60	Plastron de légionnaire en cuir	End +22 · PA +34 · Crit. +14 · Toucher +10 · Armure +60	
22880	legs	4	2	3	68	60	Cuissards de légionnaire en cuir	End +22 · PA +34 · Crit. +14 · Toucher +10 · Armure +60	
22881	legs	4	1	3	68	60	Cuissards de légionnaire en tisse-effroi	End +21 · Int +13 · Puiss. sorts +28	
22882	legs	4	1	3	68	60	Cuissards de légionnaire en satin	End +19 · Int +15 · Puiss. sorts +21 · Mana/5 +6 · Armure +60	
22883	legs	4	1	3	68	60	Cuissards de légionnaire en soie	End +18 · Int +17 · Esp +5 · Puiss. sorts +21 · Crit. +14	
22884	chest	4	1	3	68	60	Tunique de légionnaire en tisse-effroi	End +20 · Int +20 · Puiss. sorts +25	
22885	chest	4	1	3	68	60	Tunique de légionnaire en satin	End +19 · Int +15 · Puiss. sorts +21 · Mana/5 +6 · Armure +60	
22886	chest	4	1	3	68	60	Tunique de légionnaire en soie	End +18 · Int +17 · Esp +5 · Puiss. sorts +21 · Crit. +14	
22887	legs	4	3	3	68	60	Cuissards de légionnaire en mailles	End +18 · Int +17 · Puiss. sorts +21 · Crit. +14	
22935	neck	4	0	4	83	60	Larme de givre	End +20 · Rés. givre +24	
22939	finger	4	0	4	83	60	Bague des prières inexaucées	End +11 · Int +11 · Esp +12 · Soins +51	
22940	shoulder	4	4	4	83	60	Espauliers plaie-de-glace	For +9 · End +18 · Déf. +7 · Rés. givre +33	
22941	shoulder	4	2	4	83	60	Protège-épaules polaires	End +25 · Rés. givre +33	
22943	neck	4	0	4	83	60	Pendentif de la pierre pernicieuse	End +9 · Int +8 · Puiss. sorts +28	
22947	neck	4	0	4	85	60	Pendentif des noms oubliés	Int +18 · Esp +18 · Mana/5 +7	
22954	trinket	4	0	4	85	60	Baiser de l'araignée	Crit. +14 · Toucher +10	
22961	finger	4	0	4	83	60	Bague de réanimation	Agi +34	
22967	shoulder	4	3	4	83	0	Spallières glacécaille	End +25 · Rés. givre +33	
22968	shoulder	4	1	4	83	0	Mantelet glacial	End +18 · Puiss. sorts +16 · Rés. givre +33	
22981	neck	4	0	4	83	60	Collier perdu de Gluth	End +24 · Blocage +15	
23001	trinket	4	0	4	85	60	Oeil de diminution	Crit. +28	
23004	ranged	4	8	4	83	60	Idole de longévité		
23005	ranged	4	9	4	83	60	Totem de l'eau courante		
23006	ranged	4	7	4	83	60	Libram de lumière		
23018	finger	4	0	4	83	60	Chevalière du défenseur déchu	End +24 · Toucher +10 · Armure +140	
23019	head	4	4	4	83	60	Heaume plaie-de-glace	For +12 · End +24 · Déf. +8 · Rés. givre +44	
23020	head	4	2	4	83	60	Casque polaire	Agi +18 · End +24 · Rés. givre +44	
23023	neck	4	0	4	83	60	Torque de sadique	End +24 · PA +20 · Crit. +14	
23025	finger	4	0	4	85	60	Sceau des damnés	End +17 · Puiss. sorts +21 · Crit. +14 · Toucher +10	
23027	trinket	4	0	4	85	60	Cordialité du pardon	Mana/5 +10	
23028	finger	4	0	4	83	60	Bague du grêlon	End +18 · Esquive +12 · Rés. givre +20	
23031	finger	4	0	4	83	60	Bague de l'inévitable	Puiss. sorts +36 · Toucher +10	
23032	head	4	1	4	83	60	Coiffure glaciale	End +20 · Int +21 · Puiss. sorts +18 · Rés. givre +40	
23033	head	4	3	4	83	60	Camail glacécaille	Agi +18 · End +24 · Rés. givre +44	
23034	shoulder	4	4	4	83	60	Nax PH Crit Plate Shoulders	For +33 · End +18 · Crit. +14	
23036	neck	4	0	4	83	60	Collier de nécropsie	End +10 · Int +11 · Esp +10 · Soins +53	
23037	finger	4	0	4	85	60	Anneau de ferveur spirituelle	End +11 · Int +14 · Mana/5 +10	
23038	finger	4	0	4	85	60	Bague des forces contre-nature	PA +52 · Crit. +14 · Toucher +10	
23040	trinket	4	0	4	90	60	Glyphe de déviation	Blocage +15	
23041	trinket	4	0	4	90	60	Blason de tueur	PA +64	
23042	trinket	4	0	4	85	60	Reflet d'Horreb	Rés. feu +13 · Rés. givre +13 · Rés. nature +13 · Rés. ombre +13 · Rés. arcanes +13	
23046	trinket	4	0	4	90	60	L'essence contenue de Saphiron	Puiss. sorts +40	
23047	trinket	4	0	4	90	60	Oeil du mort	Soins +70	
23053	neck	4	0	4	92	60	Talisman bouillonnant de Stormrage	End +12 · PA +26 · Crit. +28	
23057	neck	4	0	4	92	60	Gemme des innocents enchaînés	End +9 · Int +7 · Puiss. sorts +15 · Crit. +28	
23058	neck	4	0	4	92	60	Collier de canalisation de vie	Soins +70 · Mana/5 +6	
23059	finger	4	0	4	92	60	Anneau du cuirassier	End +27 · Déf. +10 · Esquive +12	
23060	finger	4	0	4	92	60	Anneau de la faucheuse d'os	For +20 · Agi +20 · End +10 · Toucher +10	
23061	finger	4	0	4	92	60	Anneau de foi	Int +16 · Esp +16 · Soins +55	
23062	finger	4	0	4	92	60	Anneau de givrefeu	End +10 · Int +10 · Puiss. sorts +30 · Crit. +14	
23063	finger	4	0	4	92	60	Anneau de pestecoeur	End +24 · Puiss. sorts +29	
23064	finger	4	0	4	92	60	Anneau de marcherêve	End +16 · Int +16 · Esp +16 · Soins +37	
23065	finger	4	0	4	92	60	Anneau de Brise-terre	End +16 · Int +16 · Soins +37 · Mana/5 +6	
23066	finger	4	0	4	92	60	Anneau de rédemption	End +16 · Int +16 · Soins +37 · Mana/5 +6	
23067	finger	4	0	4	92	60	Anneau de traqueur des cryptes	Agi +30 · Mana/5 +6	
23078	hands	4	4	3	63	0	Gantelets de tueur de mort-vivant	End +15 · PA +30	
23081	hands	4	2	3	63	0	Protège-mains de tueur de mort-vivant	End +15 · PA +30	
23082	hands	4	3	3	63	0	Garde-mains de tueur de mort-vivant	End +15 · PA +30	
23084	hands	4	1	3	63	0	Gants de purification des morts-vivants	End +10 · Int +10 · Puiss. sorts +18	
23125	neck	4	0	3	60	55	Chaînes de la liche	Puiss. sorts +22	
23169	neck	4	0	3	35	30	Sautoir glacé de Scorn	End +5 · Int +6 · Puiss. sorts +7	
23197	ranged	4	8	3	65	60	Idole de la lune		
23199	ranged	4	9	3	65	60	Totem de l'orage		
23203	ranged	4	7	3	65	60	Libram de ferveur		
23206	trinket	4	0	4	90	0	Marque du champion		
23207	trinket	4	0	4	90	0	Marque du champion		
23237	finger	4	0	4	83	60	Anneau de la flamme éternelle	Int +10 · Crit. +14	
23243	shoulder	4	4	3	71	60	Epaulières de champion en plaques	For +17 · End +18 · Crit. +14	
23244	head	4	4	3	71	60	Casque de champion en plaques	For +21 · End +24 · Crit. +14 · Toucher +10	
23251	head	4	3	3	71	60	Casque de champion en anneaux	Agi +18 · End +14 · Int +9 · Crit. +28	
23252	shoulder	4	3	3	71	60	Epaulières de champion en anneaux	Agi +18 · End +13 · Crit. +14	
23253	head	4	2	3	71	60	Protège-front de champion en peau de dragon	For +16 · Agi +12 · End +16 · Int +16 · Esp +8	
23254	shoulder	4	2	3	71	60	Epaulières de champion en peau de dragon	For +12 · Agi +6 · End +12 · Int +12 · Esp +6	
23255	head	4	1	3	71	60	Capuche de champion en tisse-effroi	End +21 · Int +18 · Puiss. sorts +21 · Crit. +14	
23256	shoulder	4	1	3	71	60	Spallières de champion en tisse-effroi	End +17 · Int +13 · Puiss. sorts +12 · Crit. +14	
23257	head	4	2	3	71	60	Casque de champion en cuir	End +23 · PA +36 · Crit. +14 · Toucher +10 · Armure +80	
23258	shoulder	4	2	3	71	60	Epaulières de champion en cuir	End +17 · PA +22 · Crit. +14 · Toucher +10 · Armure +50	
23259	head	4	3	3	71	60	Protège-front de champion en mailles	For +6 · End +24 · Int +16 · Crit. +14	
23260	shoulder	4	3	3	71	60	Espauliers de champion en mailles	For +5 · End +16 · Int +10 · Puiss. sorts +15 · Crit. +14	
23261	head	4	1	3	71	60	Chaperon de champion en satin	End +20 · Int +18 · Puiss. sorts +21 · Mana/5 +6 · Armure +50	
23262	shoulder	4	1	3	71	60	Mantelet de champion en satin	End +14 · Int +12 · Puiss. sorts +16 · Mana/5 +6 · Armure +40	
23263	head	4	1	3	71	60	Capuche de champion en soie	End +19 · Int +18 · Esp +6 · Puiss. sorts +21 · Crit. +14	
23264	shoulder	4	1	3	71	60	Mantelet de champion en soie	End +14 · Int +11 · Esp +4 · Puiss. sorts +15 · Crit. +14	
23272	chest	4	4	3	68	60	Cuirasse lamellaire de chevalier-capitaine	For +17 · End +18 · Int +12 · Puiss. sorts +25	
23273	legs	4	4	3	68	60	Jambières lamellaires de chevalier-capitaine	For +18 · End +17 · Int +12 · Puiss. sorts +25	
23274	hands	4	4	3	66	60	Gantelets lamellaires de chevalier-capitaine	For +12 · End +13 · Crit. +14	
23275	feet	4	4	3	66	60	Solerets lamellaires de chevalier-capitaine	For +12 · End +12 · Int +12 · Puiss. sorts +15	
23276	head	4	4	3	71	60	Protège-front lamellaire de lieutenant-commandant	For +18 · End +19 · Int +12 · Puiss. sorts +26	
23277	shoulder	4	4	3	71	60	Epaulières lamellaires de lieutenant-commandant	For +14 · End +14 · Int +8 · Puiss. sorts +20	
23278	feet	4	3	3	66	60	Grèves de chevalier-lieutenant en anneaux	Agi +20 · End +19	
23279	hands	4	3	3	66	60	Cestes de chevalier-lieutenant en anneaux	Agi +18 · End +16	
23280	hands	4	2	3	66	60	Poignes de chevalier-lieutenant en peau de dragon	For +13 · Agi +10 · End +12 · Int +9	
23281	feet	4	2	3	66	60	Bottines de chevalier-lieutenant en peau de dragon	For +13 · Agi +6 · End +13 · Int +6 · Esp +6	
23282	hands	4	1	3	66	60	Protège-mains de chevalier-lieutenant en tisse-effroi	End +14 · Int +4 · Puiss. sorts +21	
23283	feet	4	1	3	66	60	Brodequins de chevalier-lieutenant en tisse-effroi	End +17 · Int +13 · Puiss. sorts +18	
23284	hands	4	2	3	66	60	Poignes de chevalier-lieutenant en cuir	End +18 · PA +20 · Crit. +14 · Armure +40	
23285	feet	4	2	3	66	60	Brodequins de chevalier-lieutenant en cuir	End +18 · PA +28 · Armure +40	
23286	hands	4	4	3	66	60	Gantelets de chevalier-lieutenant en plaques	For +17 · End +17	
23287	feet	4	4	3	66	60	Grèves de chevalier-lieutenant en plaques	For +10 · Agi +9 · End +23	
23288	hands	4	1	3	66	60	Protège-mains de chevalier-lieutenant en satin	End +12 · Int +5 · Puiss. sorts +21 · Armure +40	
23289	feet	4	1	3	66	60	Brodequins de chevalier-lieutenant en satin	End +17 · Int +15 · Puiss. sorts +14	
23290	hands	4	1	3	66	60	Protège-mains de chevalier-lieutenant en soie	End +12 · Int +10 · Puiss. sorts +18 · Armure +40	
23291	feet	4	1	3	66	60	Brodequins de chevalier-lieutenant en soie	End +15 · Int +10 · Puiss. sorts +15 · Toucher +10 · Armure +40	
23292	chest	4	3	3	68	60	Haubert de chevalier-capitaine en anneaux	Agi +16 · End +13 · Int +6 · Crit. +28	
23293	legs	4	3	3	68	60	Cuissards de chevalier-capitaine en anneaux	Agi +16 · End +13 · Int +6 · Crit. +28	
23294	chest	4	2	3	68	60	Plastron de chevalier-capitaine en peau de dragon	For +13 · Agi +12 · End +13 · Int +12 · Puiss. sorts +15	
23295	legs	4	2	3	68	60	Jambières de chevalier-capitaine en peau de dragon	For +12 · Agi +12 · End +12 · Int +12 · Esp +5	
23296	legs	4	1	3	68	60	Cuissards de chevalier-capitaine en tisse-effroi	End +21 · Int +13 · Puiss. sorts +28	
23297	chest	4	1	3	68	60	Tunique de chevalier-capitaine en tisse-effroi	End +20 · Int +20 · Puiss. sorts +25	
23298	chest	4	2	3	68	60	Plastron de chevalier-capitaine en cuir	End +22 · PA +34 · Crit. +14 · Toucher +10 · Armure +60	
23299	legs	4	2	3	68	60	Cuissards de chevalier-capitaine en cuir	End +22 · PA +34 · Crit. +14 · Toucher +10 · Armure +60	
23300	chest	4	4	3	68	60	Haubert de chevalier-capitaine en plaques	For +21 · End +23 · Crit. +14	
23301	legs	4	4	3	68	60	Jambières de chevalier-capitaine en plaques	For +12 · End +17 · Crit. +28	
23302	legs	4	1	3	68	60	Cuissards de chevalier-capitaine en satin	End +19 · Int +15 · Puiss. sorts +21 · Mana/5 +6 · Armure +60	
23303	chest	4	1	3	68	60	Tunique de chevalier-capitaine en satin	End +19 · Int +15 · Puiss. sorts +21 · Mana/5 +6 · Armure +60	
23304	legs	4	1	3	68	60	Cuissards de chevalier-capitaine en soie	End +18 · Int +17 · Esp +5 · Puiss. sorts +21 · Crit. +14	
23305	chest	4	1	3	68	60	Tunique de chevalier-capitaine en soie	End +18 · Int +17 · Esp +5 · Puiss. sorts +21 · Crit. +14	
23306	head	4	3	3	71	60	Casque de lieutenant-commandant en anneaux	Agi +18 · End +14 · Int +9 · Crit. +28	
23307	shoulder	4	3	3	71	60	Epaulières de lieutenant-commandant en anneaux	Agi +18 · End +13 · Crit. +14	
23308	head	4	2	3	71	60	Protège-front de lieutenant-commandant en peau de dragon	For +16 · Agi +12 · End +16 · Int +16 · Esp +8	
23309	shoulder	4	2	3	71	60	Epaulières de lieutenant-commandant en peau de dragon	For +12 · Agi +6 · End +12 · Int +12 · Esp +6	
23310	head	4	1	3	71	60	Capuche de lieutenant-commandant en tisse-effroi	End +21 · Int +18 · Puiss. sorts +21 · Crit. +14	
23311	shoulder	4	1	3	71	60	Spallières de lieutenant-commandant en tisse-effroi	End +17 · Int +13 · Puiss. sorts +12 · Crit. +14	
23312	head	4	2	3	71	60	Casque de lieutenant-commandant en cuir	End +23 · PA +36 · Crit. +14 · Toucher +10 · Armure +80	
23313	shoulder	4	2	3	71	60	Epaulières de lieutenant-commandant en cuir	End +17 · PA +22 · Crit. +14 · Toucher +10 · Armure +50	
23314	head	4	4	3	71	60	Heaume de lieutenant-commandant en plaques	For +21 · End +24 · Crit. +14 · Toucher +10	
23315	shoulder	4	4	3	71	60	Epaulières de lieutenant-commandant en plaques	For +17 · End +18 · Crit. +14	
23316	head	4	1	3	71	60	Chaperon de lieutenant-commandant en satin	End +20 · Int +18 · Puiss. sorts +21 · Mana/5 +6 · Armure +50	
23317	shoulder	4	1	3	71	60	Mantelet de lieutenant-commandant en satin	End +14 · Int +12 · Puiss. sorts +16 · Mana/5 +6 · Armure +40	
23318	head	4	1	3	71	60	Capuche de lieutenant-commandant en soie	End +19 · Int +18 · Esp +6 · Puiss. sorts +21 · Crit. +14	
23319	shoulder	4	1	3	71	60	Mantelet de lieutenant-commandant en soie	End +14 · Int +11 · Esp +4 · Puiss. sorts +15 · Crit. +14	
23451	main	2	15	4	78	60	Magelame de connétable	End +14 · Int +8 · Crit. +14	
23452	off	4	0	4	78	60	Tome de puissance de connétable	End +17 · Int +16 · Puiss. sorts +20	
23453	off	4	0	4	78	60	Tome de restauration de connétable	End +14 · Int +14 · Esp +14 · Soins +31	
23454	one	2	4	4	78	60	Marteau de guerre de connétable	End +14 · Int +8 · Mana/5 +6	
23455	two	2	5	4	78	60	Démolisseur de connétable	End +28 · Int +27 · Puiss. sorts +27 · Mana/5 +7	
23456	one	2	7	4	78	60	Vivelame de connétable	End +7 · PA +28 · Crit. +14	
23464	one	2	4	4	78	60	Masse d'armes de grand seigneur de guerre	End +14 · Int +8 · Mana/5 +6	
23465	two	2	5	4	78	60	Destructeur de grand seigneur de guerre	End +28 · Int +27 · Puiss. sorts +27 · Mana/5 +7	
23466	main	2	15	4	78	60	Sorcelame de grand seigneur de guerre	End +14 · Int +8 · Crit. +14	
23467	one	2	7	4	78	60	Prestelame de seigneur de guerre	End +7 · PA +28 · Crit. +14	
23468	off	4	0	4	78	60	Tome de destruction de grand seigneur de guerre	End +17 · Int +16 · Puiss. sorts +20	
23469	off	4	0	4	78	60	Tome de guérison de grand seigneur	End +14 · Int +14 · Esp +14 · Soins +31	
23557	ranged	2	3	4	81	60	Larve du Grand ver	PA +24 · Crit. +19	
23558	trinket	4	0	4	81	60	La Carapace du fouisseur		
23570	trinket	4	0	4	81	60	Jom Gabbar		
24071	one	2	15	3	69	0	Dague quelconque		
24358	finger	4	0	4	6	1	QATest +1000 Spell Dmg Ring	Puiss. sorts +1000	
44803	head	4	5	2	1	0	Diadème du printemps		
49715	head	4	5	2	1	0	Rose à jamais ravissante		
134110	head	4	5	2	1	1	Heaume caché		
134111	back	4	5	2	1	1	Cape cachée		
134112	shoulder	4	5	2	1	0	Epaulières cachées		
143539	waist	4	5	2	1	1	Ceinture cachée		
158329	hands	4	5	2	1	1	Gants cachés		
168659	chest	4	5	2	1	1	Plastron caché		
168664	feet	4	5	2	1	1	Bottes cachées		
168665	wrist	4	5	2	1	0	Brassards cachés		
191312	trinket	4	0	4	60	60	Phylactère de secours		
202256	ranged	2	3	2	12	0	Pistolet orné de corsaire		
205218	ranged	4	7	2	5	5	Libram de découverte		
205420	ranged	4	7	2	1	1	Libram de jugement		
206376	ranged	4	9	2	5	3	Icône de barricade		
206381	ranged	4	9	2	1	1	Icône dyadique		
206382	ranged	4	9	2	10	1	Icône de tempête		
206383	ranged	4	9	2	5	3	Icône lithique		
206384	ranged	4	9	2	5	3	Icône astrale		
206385	ranged	4	9	2	5	3	Icône clastique		
206386	ranged	4	9	2	1	1	Icône galvanique		
206387	ranged	4	9	2	25	1	Icône kajarique		
206388	ranged	4	9	2	1	1	Icône sulfureuse		
206389	ranged	4	9	2	5	3	Icône de soufre		
206390	ranged	4	9	2	5	3	Icône ichthyane		
206391	ranged	4	9	2	5	3	Icône syzygique		
206954	ranged	4	8	2	10	1	Idole de la rage ursine		
208222	two	2	1	2	57	0	Revancharde de vieux garde	For +5 · Agi +5 · End +8	
208414	ranged	4	8	2	5	1	Idole lunaire		
208689	ranged	4	8	2	20	1	Idole féroce		
208849	ranged	4	7	2	10	1	Libram des bénédictions		
208851	ranged	4	7	2	10	1	Libram de justice		
209611	trinket	4	0	3	1	0	Insigne de l’Alliance		
209612	trinket	4	0	3	1	0	Insigne de l’Alliance		
209613	trinket	4	0	3	1	0	Insigne de l’Alliance		
209614	trinket	4	0	3	1	0	Insigne de l’Alliance		
209615	trinket	4	0	3	1	0	Insigne de l’Alliance		
209616	trinket	4	0	3	1	0	Insigne de l’Alliance		
209617	trinket	4	0	3	1	0	Insigne de l’Alliance		
209618	trinket	4	0	3	1	0	Insigne de l’Alliance		
209619	trinket	4	0	3	1	0	Insigne de la Horde		
209620	trinket	4	0	3	1	0	Insigne de la Horde		
209621	trinket	4	0	3	1	0	Insigne de la Horde		
209622	trinket	4	0	3	1	0	Insigne de la Horde		
209623	trinket	4	0	3	1	0	Insigne de la Horde		
209624	trinket	4	0	3	1	0	Insigne de la Horde		
209625	trinket	4	0	3	1	0	Insigne de la Horde		
209626	trinket	4	0	3	1	0	Insigne de la Horde		
210195	ranged	4	8	2	10	10	Idole déséquilibrée		
210534	ranged	4	8	2	25	1	Idole du fauve		
210781	wrist	4	1	3	30	25	Bandages du phénix		c197:1
211472	ranged	4	7	2	25	1	Libram de bannissement		
211940	two	2	6	3	64	59	Gardienne tribale d’Ecks’av		
211941	two	2	6	3	66	58	Yari de marche-vent		
213105	one	2	4	2	40	0	Shawarmageddon		
213391	hands	4	4	4	45	40	Gantelets en mithril électrifiés INUTILISÉS	For +16 · End +7	
213513	ranged	4	7	2	40	18	Libram de délivrance		
213594	ranged	4	8	2	40	28	Idole de moquerie		
215112	back	4	1	3	40	35	UNUSED - Cloak of Arcane Insulation	Esp +6 · Rés. givre +11	
215113	shoulder	4	2	2	40	35	UNUSED - Razor-Lined Shoulderpads		
215235	one	2	8	3	45	40	2hander Animation as 1hander test copy	For +22 · Agi +9	
215365	shoulder	4	1	2	30	25	Mantelet d’invocatrice	Int +5 · Puiss. sorts +7	c197:1
215366	waist	4	1	2	30	25	Corde d’invocatrice	Int +5 · Puiss. sorts +7	c197:1
216696	legs	4	5	2	1	1	Pantalon caché		
217270	hands	4	3	2	41	36	Gants en écailles de tortue	End +7 · Int +6 · Puiss. sorts +7	c165:1
217273	hands	4	3	2	41	36	Gantelets en écailles dorées	For +11 · Puiss. sorts +5	c164:1
217287	ranged	2	19	2	35	30	Baguette mystique supérieure	Puiss. sorts +8	c333:1
217314	ranged	2	3	2	27	23	Carabine vise-lune		
217315	ranged	2	2	2	27	23	Arc précis	Toucher +4	
219345	trinket	4	0	3	50	50	Lasso infernal	Puiss. sorts +8	
220606	ranged	4	8	3	60	55	Idole du Rêve		c333:1
220915	ranged	4	8	2	50	1	Idole du traînard enragé		
221344	off	4	0	3	55	0	Grimoire personnel	Int +9 · Puiss. sorts +16	
221518	two	2	5	3	53	0	Murmure	For +23 · Puiss. sorts +14 · Crit. +7	
225838	ranged	4	9	2	1	1	Icône voltaïque		
227444	ranged	4	8	2	60	1	Idole de la chasseresse		
227947	shoulder	4	3	3	56	51	Espauliers de golem ajustés	Agi +13 · End +17	
228175	ranged	4	7	3	60	55	Libram de la sainte rapidité		c333:1
228176	ranged	4	9	3	65	60	Totem du tonnerre		c333:1
231877	trinket	4	0	3	1	1	Tyler's Balanced Bobble		
231887	main	2	15	3	55	50	Test Dagger		
234819	hands	4	2	4	71	60	Gantelet démoniaque	End +30 · Int +15 · Esp +10 · Armure +40	
235044	hands	4	2	4	71	60	Gantelet démoniaque couvert de bave	End +30 · Int +15 · Esp +10 · Armure +40	
236755	head	4	2	2	50	45	[TMP] Funerary Headdress		
236759	two	2	10	2	50	0	[TMP] Furbolg Ritual Stave	End +7 · Int +18	
236760	one	2	7	2	57	0	[TMP] Satyrbane	For +8 · Esp +5	
239618	one	2	7	3	44	0	Monstre – Épée 1M – Épée de vainqueur (Alt)	PA +28	
239688	main	2	7	3	44	0	Monstre – Lance 2M – Cavalier écarlate – Lance	PA +28	
241089	one	2	15	2	10	5	Dague écarlate	End +1	
241090	two	2	1	2	28	23	Bardiche écarlate	For +10	
246164	main	2	4	2	13	0	Brise-crâne		
246165	two	2	5	2	13	0	Pilon en bois flotté	End +2	
246265	off	4	6	2	14	0	Grand bouclier en bois récupéré		
248005	two	2	5	2	12	0	Marteau de Comté-du-Nord	For +2	
248006	main	2	7	2	12	0	Épée de la milice	End +1	
248007	one	2	15	2	12	0	Lame courte de la milice	Agi +1	
248008	two	2	10	2	12	0	Bâton magique d’apprenti	Int +2	
249144	ranged	2	19	2	42	37	Baguette du Néant distordue	Puiss. sorts +8	c333:1
249232	ranged	2	19	2	54	49	Baguette éternelle inférieure	Puiss. sorts +11	c333:1
249234	ranged	2	19	2	48	43	Baguette branchonirique	Puiss. sorts +9	c333:1
249237	ranged	2	19	2	60	55	Baguette éternelle supérieure	Puiss. sorts +12	c333:1
249385	ranged	2	19	3	60	55	Baguette brillante	Int +10 · Puiss. sorts +12	c333:1
249392	two	2	10	3	30	25	Bâton scintillant	End +11 · Int +11	c333:1
249393	two	2	10	3	30	25	Bâton des âmes	End +11 · Esp +11	c333:1
249394	off	4	0	3	30	25	Orbe de clairvoyance mystique	Int +6 · Puiss. sorts +7	c333:1
249395	off	4	0	3	30	25	Orbe des âmes	Esp +6 · Dégâts sorts +4 · Soins +13	c333:1
249396	ranged	4	8	3	25	20	Champignon mystique		c333:1
249397	ranged	4	7	3	25	20	Doctrines de la Main d’argent		c333:1
249398	ranged	4	9	3	25	20	Icône en bois flotté poli		c333:1
249441	ranged	4	8	3	45	40	Serres de la colère		c333:1
249442	ranged	4	7	3	45	40	Libram d’invocation		c333:1
249443	ranged	4	9	3	45	40	Totem de protection ancestrale		c333:1
249453	two	2	10	3	50	45	Bâton radieux	End +19 · Int +19	c333:1
249454	two	2	10	3	50	45	Bâton onirique	End +19 · Esp +19	c333:1
249455	off	4	0	3	50	45	Conduit en vrai-argent	End +8 · Int +8 · Puiss. sorts +10	c333:1
249456	off	4	0	3	50	45	Jarre d’essence distordue	End +8 · Esp +8 · Dégâts sorts +6 · Soins +19	c333:1
249469	trinket	4	0	3	55	50	Cœur gelé de la montagne	Toucher +9 · Rés. feu +7 · Rés. givre +7 · Rés. nature +7 · Rés. ombre +7	c333:1
249470	trinket	4	0	3	55	50	Cœur brûlant de la montagne	Rés. feu +7 · Rés. givre +7 · Rés. nature +7 · Rés. ombre +7	c333:1
249473	trinket	4	0	3	55	50	Cœur dormant de la montagne	Rés. feu +7 · Rés. givre +7 · Rés. nature +7 · Rés. ombre +7	c333:1
250482	feet	4	3	3	15	10	Bottes brillantes en cuivre	Int +4 · Dégâts sorts +3 · Soins +9	c164:1
250483	feet	4	3	2	25	20	Bottes en argent fin	For +3 · End +3 · Puiss. sorts +4	c164:1
250484	legs	4	3	2	26	21	Jambières en argent fin	For +3 · End +3 · Puiss. sorts +4	c164:1
250485	hands	4	3	2	26	21	Gantelets en argent fin	For +4 · End +4 · Puiss. sorts +4	c164:1
250486	shoulder	4	3	2	27	22	Épaulières en argent fin	For +4 · End +4 · Puiss. sorts +4	c164:1
250487	chest	4	3	2	30	25	Cuirasse en argent fin	For +7 · End +6 · Puiss. sorts +7	c164:1
250488	chest	4	3	3	20	15	Cotte d’anneaux de vétéran	For +7 · Agi +4 · End +5	c164:1
250489	chest	4	3	3	20	15	Cotte d’anneaux de garde	For +4 · End +7 · Déf. +5	c164:1
250490	chest	4	3	3	20	15	Cotte d’anneaux de protecteur	End +7 · Puiss. sorts +5 · Déf. +5	c164:1
250491	chest	4	3	3	20	15	Cotte d’anneaux d’acolyte	End +4 · Int +5 · Dégâts sorts +5 · Soins +16	c164:1
250492	chest	4	3	3	20	15	Cotte d’anneaux de croisé	For +4 · End +5 · Puiss. sorts +9	c164:1
250493	legs	4	3	3	25	20	Jambières de vétéran en anneaux	For +9 · Agi +5 · End +7	c164:1
250494	legs	4	3	3	25	20	Jambières de garde en anneaux	For +5 · End +9 · Déf. +7	c164:1
250495	legs	4	3	3	25	20	Jambières de protecteur en anneaux	End +9 · Puiss. sorts +6 · Déf. +7	c164:1
250496	legs	4	3	3	25	20	Jambières d’acolyte en anneaux	End +5 · Int +7 · Dégâts sorts +7 · Soins +21	c164:1
250497	legs	4	3	3	25	20	Jambières de croisé en anneaux	For +5 · End +7 · Puiss. sorts +11	c164:1
250498	head	4	3	3	30	25	Heaume de vétéran en anneaux	For +12 · End +11	c164:1
250499	head	4	3	3	30	25	Heaume de garde en anneaux	Agi +12 · End +11	c164:1
250500	head	4	3	3	30	25	Heaume de protecteur en anneaux	End +11 · Déf. +8	c164:1
250501	head	4	3	3	30	25	Heaume d’acolyte en anneaux	End +11 · Dégâts sorts +8 · Soins +25	c164:1
250502	head	4	3	3	30	25	Heaume de croisé en anneaux	For +11 · Puiss. sorts +14	c164:1
250503	feet	4	3	3	22	17	Bottes de vétéran	For +5 · Agi +4 · End +5	c164:1
250504	feet	4	3	3	22	17	Bottes de garde	For +5 · End +5 · Déf. +4	c164:1
250505	feet	4	3	3	22	17	Bottes de protecteur	End +5 · Puiss. sorts +6 · Déf. +4	c164:1
250506	feet	4	3	3	22	17	Bottes d’acolyte	End +4 · Int +5 · Dégâts sorts +4 · Soins +11	c164:1
250507	feet	4	3	3	22	17	Bottes de croisé	For +4 · End +5 · Puiss. sorts +6	c164:1
250508	hands	4	3	3	20	15	Gants de vétéran	For +5 · Agi +3 · End +5	c164:1
250509	hands	4	3	3	20	15	Gants de garde	For +5 · End +5 · Déf. +3	c164:1
250510	hands	4	3	3	20	15	Gants de protecteur	End +5 · Puiss. sorts +5 · Déf. +3	c164:1
250511	hands	4	3	3	20	15	Gants d’acolyte	End +3 · Int +5 · Dégâts sorts +3 · Soins +10	c164:1
250512	hands	4	3	3	20	15	Gants de croisé	For +3 · End +5 · Puiss. sorts +5	c164:1
250513	waist	4	3	3	17	12	Ceinture de vétéran en anneaux	For +4 · Agi +3 · End +4	c164:1
250514	waist	4	3	3	17	12	Ceinture de garde en anneaux	For +4 · End +4 · Déf. +3	c164:1
250515	waist	4	3	3	17	12	Ceinture de protecteur en anneaux	End +4 · Puiss. sorts +5 · Déf. +3	c164:1
250516	waist	4	3	3	17	12	Ceinture d’acolyte en anneaux	End +3 · Int +4 · Dégâts sorts +3 · Soins +9	c164:1
250517	waist	4	3	3	17	12	Ceinture de croisé en anneaux	For +3 · End +4 · Puiss. sorts +5	c164:1
250518	chest	4	3	3	27	22	Cotte d’anneaux argentés de vétéran	For +10 · Agi +6 · End +7	c164:1
250519	chest	4	3	3	27	22	Cotte d’anneaux argentés de garde	For +6 · End +10 · Déf. +7	c164:1
250520	chest	4	3	3	27	22	Cotte d’anneaux argentés de protecteur	End +10 · Puiss. sorts +7 · Déf. +7	c164:1
250521	chest	4	3	3	27	22	Cotte d’anneaux argentés d’acolyte	End +6 · Int +7 · Dégâts sorts +7 · Soins +22	c164:1
250522	chest	4	3	3	27	22	Cotte d’anneaux argentés de croisé	For +6 · End +7 · Puiss. sorts +12	c164:1
250523	legs	4	3	3	30	25	Jambières de vétéran en anneaux argentés	For +11 · Agi +7 · End +8	c164:1
250524	legs	4	3	3	30	25	Jambières de garde en anneaux argentés	For +7 · End +11 · Déf. +8	c164:1
250525	legs	4	3	3	30	25	Jambières de protecteur en anneaux argentés	End +11 · Puiss. sorts +8 · Déf. +8	c164:1
250526	legs	4	3	3	30	25	Jambières d’acolyte en anneaux argentés	End +7 · Int +8 · Dégâts sorts +8 · Soins +25	c164:1
250527	legs	4	3	3	30	25	Jambières de croisé en anneaux argentés	For +7 · End +8 · Puiss. sorts +13	c164:1
250528	head	4	3	3	25	20	Heaume de vétéran en anneaux argentés	For +10 · End +9	c164:1
250529	head	4	3	3	25	20	Heaume de garde en anneaux argentés	Agi +10 · End +9	c164:1
250530	head	4	3	3	25	20	Heaume de protecteur en anneaux argentés	End +9 · Déf. +7	c164:1
250531	head	4	3	3	25	20	Heaume d’acolyte en anneaux argentés	End +9 · Dégâts sorts +7 · Soins +21	c164:1
250532	head	4	3	3	25	20	Heaume de croisé en anneaux argentés	End +9 · Puiss. sorts +11	c164:1
250533	chest	4	3	2	34	29	Thorax doré dur	For +11 · Puiss. sorts +6	c164:1
250534	feet	4	3	2	35	30	Bottes dorées dures	For +7 · Puiss. sorts +7	c164:1
250535	wrist	4	3	2	37	32	Brassards dorés durs	For +6 · Puiss. sorts +6	c164:1
250536	legs	4	3	2	38	33	Jambières dorées dures	For +10 · Puiss. sorts +12	c164:1
250537	head	4	3	2	40	35	Camail doré dur	For +14 · Puiss. sorts +7	c164:1
250538	hands	4	3	2	40	35	Gantelets dorés durs	For +8 · Puiss. sorts +9	c164:1
250539	shoulder	4	3	2	40	35	Espauliers dorés durs	For +11 · Puiss. sorts +5	c164:1
250540	chest	4	4	2	45	40	Cuirasse brillante en mithril	For +14 · Puiss. sorts +14	c164:1
250541	shoulder	4	4	2	45	40	Espauliers brillants en mithril	For +10 · Puiss. sorts +11	c164:1
250542	feet	4	4	2	45	40	Bottes brillantes en mithril	For +9 · Puiss. sorts +12	c164:1
250543	head	4	4	2	48	43	Heaume brillant en mithril	For +14 · Puiss. sorts +15	c164:1
250544	legs	4	4	2	49	44	Pantalon brillant en mithril	For +14 · Puiss. sorts +16	c164:1
250545	hands	4	4	2	49	44	Gantelets brillants en mithril	For +12 · Puiss. sorts +9	c164:1
250546	feet	4	4	3	45	40	Bottes d’officier	For +13 · Agi +7 · End +9	c164:1
250547	feet	4	4	3	45	40	Bottes de sentinelle	For +7 · End +13 · Déf. +9	c164:1
250548	feet	4	4	3	45	40	Bottes de grand gardien	End +13 · Puiss. sorts +9 · Déf. +9	c164:1
250549	feet	4	4	3	45	40	Bottes de préfet	End +7 · Int +9 · Dégâts sorts +9 · Soins +28	c164:1
250550	feet	4	4	3	45	40	Bottes de justicier	For +7 · End +9 · Puiss. sorts +15	c164:1
250551	hands	4	4	3	55	50	Gants d’officier	For +16 · Agi +9 · End +11	c164:1
250552	hands	4	4	3	55	50	Gants de sentinelle	For +9 · End +16 · Déf. +11	c164:1
250553	hands	4	4	3	55	50	Gants de grand gardien	End +16 · Puiss. sorts +11 · Déf. +11	c164:1
250554	hands	4	4	3	55	50	Gants de préfet	End +9 · Int +11 · Dégâts sorts +12 · Soins +35	c164:1
250555	hands	4	4	3	55	50	Gants de justicier	For +9 · End +11 · Puiss. sorts +19	c164:1
250556	waist	4	3	3	35	30	Ceinture d’officier	For +10 · Agi +6 · End +7	c164:1
250557	waist	4	3	3	35	30	Ceinture de sentinelle	For +6 · End +10 · Déf. +7	c164:1
250558	waist	4	3	3	35	30	Ceinture de grand gardien	End +10 · Puiss. sorts +7 · Déf. +7	c164:1
250559	waist	4	3	3	35	30	Ceinture de préfet	End +6 · Int +7 · Dégâts sorts +7 · Soins +22	c164:1
250560	waist	4	3	3	35	30	Ceinture de justicier	For +6 · End +7 · Puiss. sorts +12	c164:1
250561	feet	4	4	3	52	47	Solerets d’officier	For +13 · Agi +9 · End +12	c164:1
250562	feet	4	4	3	52	47	Solerets de sentinelle	For +12 · End +13 · Déf. +9	c164:1
250563	feet	4	4	3	52	47	Solerets de grand gardien	End +13 · Puiss. sorts +14 · Déf. +9	c164:1
250564	feet	4	4	3	52	47	Solerets de préfet	End +12 · Int +9 · Dégâts sorts +9 · Soins +27	c164:1
250565	feet	4	4	3	52	47	Solerets de justicier	For +9 · End +12 · Puiss. sorts +15	c164:1
250566	hands	4	3	3	40	35	Gantelets d’officier	For +10 · Agi +7 · End +9	c164:1
250567	hands	4	3	3	40	35	Gantelets de sentinelle	For +9 · End +10 · Déf. +7	c164:1
250568	hands	4	3	3	40	35	Gantelets de grand gardien	End +10 · Puiss. sorts +11 · Déf. +7	c164:1
250569	hands	4	3	3	40	35	Gantelets de préfet	End +9 · Int +7 · Dégâts sorts +7 · Soins +21	c164:1
250570	hands	4	3	3	40	35	Gantelets de justicier	For +7 · End +9 · Puiss. sorts +11	c164:1
250571	waist	4	4	3	55	50	Sangle d’officier	For +14 · Agi +10 · End +13	c164:1
250572	waist	4	4	3	55	50	Sangle de sentinelle	For +13 · End +14 · Déf. +10	c164:1
250573	waist	4	4	3	55	50	Sangle de grand gardien	End +14 · Puiss. sorts +15 · Déf. +10	c164:1
250574	waist	4	4	3	55	50	Sangle de préfet	End +13 · Int +10 · Dégâts sorts +10 · Soins +30	c164:1
250575	waist	4	4	3	55	50	Sangle de justicier	For +10 · End +13 · Puiss. sorts +16	c164:1
250576	shoulder	4	4	3	47	42	Espauliers d’officier	For +13 · Agi +8 · End +10	c164:1
250577	shoulder	4	4	3	47	42	Espauliers de sentinelle	For +8 · End +13 · Déf. +10	c164:1
250578	shoulder	4	4	3	47	42	Espauliers de grand gardien	End +13 · Puiss. sorts +9 · Déf. +10	c164:1
250579	shoulder	4	4	3	47	42	Espauliers de préfet	End +8 · Int +10 · Dégâts sorts +10 · Soins +29	c164:1
250580	shoulder	4	4	3	47	42	Espauliers de justicier	For +8 · End +10 · Puiss. sorts +16	c164:1
250581	wrist	4	4	3	50	45	Garde-poignets d’officier	For +11 · Agi +6 · End +8	c164:1
250582	wrist	4	4	3	50	45	Garde-poignets de sentinelle	For +6 · End +11 · Déf. +8	c164:1
250583	wrist	4	4	3	50	45	Garde-poignets de grand gardien	End +11 · Puiss. sorts +7 · Déf. +8	c164:1
250584	wrist	4	4	3	50	45	Garde-poignets de préfet	End +6 · Int +8 · Dégâts sorts +8 · Soins +23	c164:1
250585	wrist	4	4	3	50	45	Garde-poignets de justicier	For +6 · End +8 · Puiss. sorts +12	c164:1
250586	shoulder	4	4	2	52	47	Espauliers bénis en plaques	For +5 · End +7 · Puiss. sorts +15	c164:1
250587	feet	4	4	2	52	47	Bottes bénies en plaques	For +13 · End +7 · Puiss. sorts +6	c164:1
250588	hands	4	4	2	54	49	Gantelets bénis en plaques	For +5 · End +13 · Puiss. sorts +8	c164:1
250589	hands	4	4	2	57	52	Gantelets impériaux en plaques	For +12 · End +12	c164:1
250590	wrist	4	4	2	57	52	Brassards bénis en plaques	For +11 · End +6 · Puiss. sorts +4	c164:1
250591	legs	4	4	2	59	54	Jambières bénies en plaques	For +7 · End +20 · Puiss. sorts +13	c164:1
250592	waist	4	4	2	59	54	Ceinture bénie en plaques	For +15 · End +5 · Puiss. sorts +9	c164:1
250593	head	4	4	2	60	55	Heaume béni en plaques	For +11 · End +7 · Puiss. sorts +23	c164:1
250594	chest	4	4	2	61	56	Plastron béni en plaques	For +20 · End +8 · Puiss. sorts +13	c164:1
250595	chest	4	4	3	62	57	Cuirasse en thorium enrichi	End +25 · Puiss. sorts +14 · Déf. +9	c164:1
250596	legs	4	4	3	63	58	Jambières en thorium enrichi	End +26 · Puiss. sorts +14 · Déf. +9	c164:1
250597	head	4	4	3	63	58	Heaume en thorium enrichi	End +21 · Puiss. sorts +23 · Déf. +8	c164:1
250598	legs	4	4	4	61	56	Cuissards de champion	For +18 · Puiss. sorts +38 · Crit. +14	c164:1
250599	head	4	4	4	61	56	Heaume infrangible	For +12 · Puiss. sorts +38 · Toucher +20	c164:1
250600	legs	4	4	4	61	56	Cuissards de martyr	Int +14 · Esp +18 · Dégâts sorts +25 · Soins +73	c164:1
250601	chest	4	4	4	61	56	Cuirasse du salut	Int +14 · Esp +33 · Dégâts sorts +14 · Soins +40	c164:1
250602	one	2	13	2	21	16	Coup de poing en laiton	Agi +2 · End +2	c164:1
250603	two	2	6	2	25	20	Dory en bronze	Agi +8 · PA +6	c164:1
250604	one	2	13	2	31	26	Poings de fer	Agi +5	c164:1
250605	two	2	6	2	37	32	Lance en acier	Agi +13 · PA +10	c164:1
250606	main	2	4	2	38	33	Étoile du matin en fer	For +4 · Puiss. sorts +5	c164:1
250607	one	2	15	2	41	36	Épée courte en mithril	PA +14	c164:1
250608	two	2	5	2	43	38	Marteau de guerre en mithril	For +9 · Agi +14	c164:1
250609	one	2	13	2	45	40	Griffes en mithril	For +6 · Agi +5	c164:1
250610	two	2	8	2	45	40	Claymore en mithril	For +9 · End +15	c164:1
250611	one	2	15	2	47	42	Stylet en mithril	Agi +8	c164:1
250612	two	2	1	2	48	43	Hache d’armes chargée en mithril	For +14 · Puiss. sorts +15	c164:1
250613	two	2	5	3	55	50	Plombée en thorium	For +21 · Puiss. sorts +23	c164:1
250614	one	2	13	3	55	50	Ceste en thorium	End +9 · PA +16	c164:1
250615	two	2	6	3	57	52	Hache d’hast en thorium	For +13 · Agi +25 · End +10	c164:1
250616	one	2	15	2	59	54	Miséricorde audacieuse	Agi +7 · PA +16	c164:1
250617	two	2	1	3	63	58	Grave-Tempête	For +15 · End +11 · Puiss. sorts +32	c164:1
250618	one	2	13	3	63	58	Bagh Nakh	Agi +13 · End +5	c164:1
250619	two	2	6	3	63	58	Glaive en légionite	Agi +16 · PA +54 · Toucher +10	c164:1
250620	feet	4	3	3	15	10	Bottes ornées en cuivre	For +4 · End +4	c164:1
250621	feet	4	3	3	15	10	Bottes étranges en cuivre	End +4 · Puiss. sorts +5	c164:1
251485	one	2	15	2	24	0	Couteau d’Edward	Agi +2 · End +2	
251486	wrist	4	1	2	24	0	Crispins de Tabitha	End +4 · Puiss. sorts +3	
251960	two	2	1	2	10	5	Hache d’Yngwe	Agi +1 · PA +1	
252424	feet	4	2	3	15	10	Mules de dragonnet noir	Int +4 · Dégâts sorts +3 · Soins +9	c165:1
252425	feet	4	2	3	15	10	Bottes noires en cuir	Agi +4 · End +4	c165:1
252426	feet	4	2	3	15	10	Chaussures en écailles de Murloc	For +4 · End +4	c165:1
252427	feet	4	2	3	15	10	Bottes lueur-de-lune	End +4 · Puiss. sorts +5	c165:1
252428	waist	4	2	3	17	12	Ceinture de bagarreur en cuir	For +4 · Agi +4 · End +3	c165:1
252429	waist	4	2	3	17	12	Ceinture de trappeur en cuir	Agi +4 · End +4 · Int +3	c165:1
252430	waist	4	2	3	17	12	Ceinture de défenseur en cuir	For +4 · End +4 · Armure +29	c165:1
252431	waist	4	2	3	17	12	Ceinture totémique en cuir	For +4 · End +3 · Puiss. sorts +4	c165:1
252432	waist	4	2	3	17	12	Ceinture de chevaucheur de tempête en cuir	End +3 · Int +4 · Puiss. sorts +4	c165:1
252433	waist	4	2	3	17	12	Ceinture de sagesse en cuir	End +3 · Int +4 · Dégâts sorts +3 · Soins +8	c165:1
252434	chest	4	2	3	20	15	Armure de défenseur en cuir	For +7 · Agi +3 · End +5 · Armure +33	c165:1
252435	chest	4	2	3	20	15	Armure totémique en cuir	For +7 · End +3 · Int +3 · Puiss. sorts +6	c165:1
252439	feet	4	2	3	22	17	Bottes de bagarreur en cuir	For +5 · Agi +5 · End +4	c165:1
252440	feet	4	2	3	22	17	Bottes de trappeur en cuir	Agi +5 · End +5 · Int +4	c165:1
252441	feet	4	2	3	22	17	Bottes de défenseur en cuir	For +5 · End +5 · Armure +38	c165:1
252442	feet	4	2	3	22	17	Bottes totémiques en cuir	For +5 · End +4 · Puiss. sorts +6	c165:1
252443	feet	4	2	3	22	17	Bottes de chevaucheur de tempête en cuir	End +4 · Int +5 · Puiss. sorts +6	c165:1
252444	feet	4	2	3	22	17	Bottes de sagesse en cuir	End +4 · Int +5 · Dégâts sorts +4 · Soins +11	c165:1
252445	legs	4	2	3	25	20	Pantalon de défenseur en cuir	For +9 · Agi +4 · End +6 · Armure +42	c165:1
252446	legs	4	2	3	25	20	Pantalon totémique en cuir	For +9 · End +4 · Int +4 · Puiss. sorts +7	c165:1
252447	head	4	2	3	25	20	Chaperon de défenseur en cuir	For +8 · End +10	c165:1
252448	head	4	2	3	25	20	Chaperon totémique en cuir	End +10 · Puiss. sorts +9	c165:1
252449	feet	4	2	2	27	22	Bottes d’homme des collines en cuir	End +4 · Puiss. sorts +6	c165:1
252450	chest	4	2	3	27	22	Tunique de défenseur en cuir	For +6 · Agi +6 · End +8 · Armure +51	c165:1
252451	chest	4	2	3	27	22	Tunique totémique en cuir	For +8 · End +6 · Int +5 · Puiss. sorts +7	c165:1
252455	head	4	2	3	30	25	Casque de défenseur en cuir	For +12 · End +13	c165:1
252456	head	4	2	3	30	25	Casque totémique en cuir	End +13 · Puiss. sorts +12	c165:1
252457	legs	4	2	3	30	25	Kilt de défenseur en cuir	For +7 · Agi +7 · End +9 · Armure +58	c165:1
252458	legs	4	2	3	30	25	Jambières totémiques en cuir	For +9 · End +7 · Int +6 · Puiss. sorts +8	c165:1
252459	waist	4	2	3	35	30	Ceinture de rôdeur en cuir	For +9 · Agi +6 · End +6 · Int +4	c165:1
252460	waist	4	2	3	35	30	Ceinture de garde en cuir	For +6 · Agi +6 · End +9 · Armure +38	c165:1
252461	waist	4	2	3	35	30	Ceinture d’escarmouche en cuir	For +9 · End +6 · Int +4 · Puiss. sorts +7	c165:1
252465	feet	4	2	3	45	40	Chaussures de rôdeur en cuir	For +11 · Agi +7 · End +7 · Int +5	c165:1
252466	feet	4	2	3	45	40	Chaussures de garde en cuir	For +7 · Agi +7 · End +11 · Armure +49	c165:1
252467	feet	4	2	2	52	47	Chaussures en suédine bleue	For +10 · Agi +5 · End +11	c165:1
252468	feet	4	2	3	52	47	Bottes de rôdeur en cuir	For +13 · Agi +11 · End +9	c165:1
252469	feet	4	2	3	52	47	Bottes de furtivité en cuir	For +11 · Agi +13 · End +9	c165:1
252470	feet	4	2	3	52	47	Bottes de garde en cuir	For +11 · End +13 · Armure +93	c165:1
252471	feet	4	2	3	52	47	Bottes de mande-ciel en cuir	End +9 · Int +11 · Puiss. sorts +15	c165:1
252472	feet	4	2	3	52	47	Bottes de soigneur en cuir	End +9 · Int +11 · Dégâts sorts +9 · Soins +28	c165:1
252473	waist	4	2	3	55	50	Sangle de rôdeur en cuir	For +14 · Agi +12 · End +10	c165:1
252474	waist	4	2	3	55	50	Sangle de furtivité en cuir	For +12 · Agi +14 · End +10	c165:1
252475	waist	4	2	3	55	50	Sangle de garde en cuir	For +12 · End +14 · Armure +102	c165:1
252476	waist	4	2	3	55	50	Sangle de mande-ciel en cuir	End +10 · Int +12 · Puiss. sorts +16	c165:1
252477	waist	4	2	3	55	50	Sangle de soigneur en cuir	End +10 · Int +12 · Dégâts sorts +10 · Soins +30	c165:1
252478	legs	4	2	2	56	51	Pantalon en suédine bleue	For +14 · Agi +6 · End +16	c165:1
252479	feet	4	2	2	57	52	Bottes corrompues en cuir	Agi +12 · End +12	c165:1
252480	chest	4	2	2	58	53	Armure en suédine bleue	For +16 · Agi +8 · End +12	c165:1
252481	waist	4	2	2	59	54	Ceinture en suédine bleue	For +9 · Agi +4 · End +14	c165:1
252482	head	4	2	2	61	56	Chapeau en suédine bleue	For +17 · Agi +16 · End +7	c165:1
252483	chest	4	2	4	61	56	Armure de l’aube	Agi +37 · Crit. +14 · Toucher +10	c165:1
252484	chest	4	2	4	61	56	Tunique grumegueule	For +33 · Agi +18 · Crit. +14	c165:1
252485	head	4	2	4	61	56	Heaume de l’ours de guerre	For +18 · Agi +14 · End +33	c165:1
252486	legs	4	2	4	61	56	Jambières en plumacier	Int +18 · Puiss. sorts +38 · Crit. +14	c165:1
252490	chest	4	2	3	20	15	Armure de bagarreur en cuir	For +5 · Agi +7 · End +3 · Esp +3	c165:1
252491	chest	4	2	3	20	15	Armure de trappeur en cuir	Agi +7 · End +5 · Int +3 · Esp +3	c165:1
252492	chest	4	2	3	20	15	Armure de chevaucheur de tempête en cuir	End +3 · Int +5 · Esp +3 · Puiss. sorts +8	c165:1
252493	chest	4	2	3	20	15	Armure de sagesse en cuir	End +3 · Int +5 · Esp +3 · Dégâts sorts +5 · Soins +15	c165:1
252494	hands	4	2	3	20	15	Gants de bagarreur en cuir	For +4 · Agi +4 · End +3	c165:1
252495	hands	4	2	3	20	15	Gants de trappeur en cuir	Agi +4 · End +4 · Int +3	c165:1
252496	hands	4	2	3	20	15	Gants de défenseur en cuir	For +4 · End +4 · Armure +34	c165:1
252497	hands	4	2	3	20	15	Gants totémiques en cuir	For +4 · End +3 · Puiss. sorts +5	c165:1
252498	hands	4	2	3	20	15	Gants de chevaucheur de tempête en cuir	End +3 · Int +4 · Puiss. sorts +5	c165:1
252499	hands	4	2	3	20	15	Gants de sagesse en cuir	End +3 · Int +4 · Dégâts sorts +3 · Soins +10	c165:1
252500	legs	4	2	3	25	20	Pantalon de bagarreur en cuir	For +6 · Agi +9 · End +4 · Esp +4	c165:1
252501	legs	4	2	3	25	20	Pantalon de trappeur en cuir	For +6 · Agi +9 · Int +4 · Esp +4	c165:1
252502	legs	4	2	3	25	20	Pantalon de chevaucheur de tempête en cuir	End +4 · Int +6 · Esp +4 · Puiss. sorts +10	c165:1
252503	legs	4	2	3	25	20	Pantalon de sagesse en cuir	End +4 · Int +6 · Esp +4 · Dégâts sorts +7 · Soins +20	c165:1
252504	head	4	2	3	25	20	Chaperon de bagarreur en cuir	Agi +8 · End +10	c165:1
252505	head	4	2	3	25	20	Chaperon de trappeur en cuir	End +10 · Int +8	c165:1
252506	head	4	2	3	25	20	Chaperon de chevaucheur de tempête en cuir	End +10 · Esp +9	c165:1
252507	head	4	2	3	25	20	Chaperon de sagesse en cuir	End +10 · Dégâts sorts +6 · Soins +17	c165:1
252508	chest	4	2	3	27	22	Tunique de bagarreur en cuir	For +6 · Agi +8 · End +6 · Esp +5	c165:1
252509	chest	4	2	3	27	22	Tunique de trappeur en cuir	Agi +8 · End +6 · Int +6 · Esp +5	c165:1
252510	chest	4	2	3	27	22	Tunique de chevaucheur de tempête en cuir	End +6 · Int +6 · Esp +5 · Puiss. sorts +10	c165:1
252511	chest	4	2	3	27	22	Tunique de sagesse en cuir	End +5 · Int +6 · Esp +6 · Dégâts sorts +6 · Soins +18	c165:1
252512	head	4	2	3	30	25	Casque de bagarreur en cuir	Agi +10 · End +13	c165:1
252513	head	4	2	3	30	25	Casque de trappeur en cuir	End +13 · Int +10	c165:1
252514	head	4	2	3	30	25	Casque de chevaucheur de tempête en cuir	End +13 · Esp +10	c165:1
252515	head	4	2	3	30	25	Casque de sagesse en cuir	End +13 · Dégâts sorts +7 · Soins +21	c165:1
252516	legs	4	2	3	30	25	Garde-jambes de bagarreur en cuir	For +7 · Agi +9 · End +7 · Esp +6	c165:1
252517	legs	4	2	3	30	25	Garde-jambes de trappeur en cuir	Agi +9 · End +7 · Int +7 · Esp +6	c165:1
252518	legs	4	2	3	30	25	Kilt de chevaucheur de tempête en cuir	For +7 · End +6 · Int +7 · Esp +11	c165:1
252519	legs	4	2	3	30	25	Jambières de sagesse en cuir	End +6 · Int +7 · Esp +7 · Dégâts sorts +7 · Soins +21	c165:1
252520	waist	4	2	3	35	30	Ceinture de furtivité en cuir	For +6 · Agi +9 · End +6 · Esp +4	c165:1
252521	waist	4	2	3	35	30	Ceinture de traqueur en cuir	Agi +9 · End +6 · Int +6 · Esp +4	c165:1
252522	waist	4	2	3	35	30	Ceinture de mande-ciel en cuir	End +6 · Int +6 · Esp +4 · Puiss. sorts +10	c165:1
252523	waist	4	2	3	35	30	Ceinture de soigneur en cuir	End +4 · Int +6 · Esp +6 · Dégâts sorts +6 · Soins +19	c165:1
252524	hands	4	2	3	40	35	Gants de rôdeur en cuir	For +10 · Agi +9 · End +7	c165:1
252525	hands	4	2	3	40	35	Gants de furtivité en cuir	For +9 · Agi +10 · End +7	c165:1
252526	hands	4	2	3	40	35	Gants de traqueur en cuir	Agi +10 · End +9 · Int +7	c165:1
252527	hands	4	2	3	40	35	Gants de garde en cuir	For +9 · End +10 · Armure +72	c165:1
252528	hands	4	2	3	40	35	Gants d’escarmouche en cuir	For +10 · End +7 · Puiss. sorts +10	c165:1
252529	hands	4	2	3	40	35	Gants de mande-ciel en cuir	End +7 · Int +9 · Puiss. sorts +11	c165:1
252530	hands	4	2	3	40	35	Gants de soigneur en cuir	End +7 · Int +9 · Dégâts sorts +7 · Soins +21	c165:1
252531	feet	4	2	3	45	40	Chaussures de furtivité en cuir	For +7 · Agi +11 · End +7 · Esp +5	c165:1
252532	feet	4	2	3	45	40	Chaussures de mande-ciel en cuir	End +7 · Int +7 · Esp +5 · Puiss. sorts +13	c165:1
252533	feet	4	2	3	45	40	Chaussures de soigneur en cuir	End +5 · Int +7 · Esp +7 · Dégâts sorts +8 · Soins +24	c165:1
252534	shoulder	4	2	3	47	42	Épaulières de rôdeur en cuir	For +11 · Agi +9 · End +7 · Int +6	c165:1
252535	shoulder	4	2	3	47	42	Épaulières de furtivité en cuir	For +9 · Agi +11 · End +7 · Esp +6	c165:1
252536	shoulder	4	2	3	47	42	Épaulières de garde en cuir	For +9 · Agi +7 · End +11 · Armure +65	c165:1
252537	shoulder	4	2	3	47	42	Épaulières de mande-ciel en cuir	End +7 · Int +9 · Esp +6 · Puiss. sorts +13	c165:1
252538	shoulder	4	2	3	47	42	Épaulières de soigneur en cuir	End +6 · Int +9 · Esp +7 · Dégâts sorts +8 · Soins +24	c165:1
252539	wrist	4	2	3	50	45	Brassards de rôdeur en cuir	For +9 · Agi +7 · End +6 · Int +5	c165:1
252540	wrist	4	2	3	50	45	Brassards de furtivité en cuir	For +7 · Agi +9 · End +6 · Esp +5	c165:1
252541	wrist	4	2	3	50	45	Brassards de garde en cuir	For +7 · Agi +6 · End +9 · Armure +52	c165:1
252542	wrist	4	2	3	50	45	Brassards de mande-ciel en cuir	End +6 · Int +7 · Esp +5 · Puiss. sorts +10	c165:1
252543	wrist	4	2	3	50	45	Brassards de soigneur en cuir	End +5 · Int +7 · Esp +6 · Dégâts sorts +6 · Soins +19	c165:1
252544	waist	4	2	2	52	47	Ceinture ouvragée en cuir	Int +11 · Esp +8 · Puiss. sorts +9	c165:1
252545	feet	4	2	2	53	48	Bottes ouvragées en cuir	Int +5 · Esp +8 · Puiss. sorts +8	c165:1
252546	hands	4	2	2	53	48	Gants en suédine bleue	For +9 · Agi +4 · End +5	c165:1
252547	hands	4	2	3	55	50	Gantelets de rôdeur en cuir	For +14 · Agi +9 · End +9 · Int +6	c165:1
252548	hands	4	2	3	55	50	Gantelets de furtivité en cuir	For +9 · Agi +14 · End +9 · Esp +6	c165:1
252549	hands	4	2	3	55	50	Gantelets de garde en cuir	For +9 · Agi +9 · End +14 · Armure +62	c165:1
252550	hands	4	2	3	55	50	Gantelets de mande-ciel en cuir	End +9 · Int +9 · Esp +6 · Puiss. sorts +16	c165:1
252551	hands	4	2	3	55	50	Gantelets de soigneur en cuir	End +6 · Int +9 · Esp +9 · Dégâts sorts +10 · Soins +31	c165:1
252552	chest	4	2	2	56	51	Armure ouvragée en cuir	Int +16 · Esp +11 · Puiss. sorts +12	c165:1
252553	hands	4	2	2	57	52	Gantelets ouvragés en cuir	Int +12 · Esp +8 · Puiss. sorts +9	c165:1
252554	shoulder	4	2	2	57	52	Épaulières en suédine bleue	For +10 · Agi +5 · End +12	c165:1
252555	head	4	2	2	58	53	Couronne ouvragée en cuir	Int +12 · Esp +15 · Puiss. sorts +14	c165:1
252556	shoulder	4	2	2	59	54	Épaulières corrompues en cuir	Agi +11 · End +14	c165:1
252557	wrist	4	2	2	59	54	Brassards ouvragés en cuir	Int +11 · Esp +4 · Puiss. sorts +5	c165:1
252558	shoulder	4	2	2	60	55	Épaulettes ouvragées en cuir	End +13 · Esp +10 · Puiss. sorts +11	c165:1
252559	wrist	4	2	2	60	55	Brassards en suédine bleue	For +12 · Agi +3 · End +6	c165:1
252560	legs	4	2	2	61	56	Pantalon ouvragé en cuir	End +7 · Esp +17 · Puiss. sorts +19	c165:1
252561	head	4	2	4	61	56	Couronne vivante	Int +18 · Esp +14 · Dégâts sorts +25 · Soins +73	c165:1
252562	feet	4	3	3	45	40	Bottes de traqueur en mailles	Agi +11 · End +7 · Int +7 · Esp +5	c165:1
252563	feet	4	3	3	45	40	Bottes de mande-ciel en mailles	End +7 · Int +7 · Esp +5 · Puiss. sorts +13	c165:1
252564	feet	4	3	3	45	40	Bottes d’escarmouche en mailles	For +11 · End +7 · Int +5 · Puiss. sorts +9	c165:1
252565	feet	4	3	3	45	40	Bottes de soigneur en mailles	End +5 · Int +7 · Esp +7 · Dégâts sorts +8 · Soins +24	c165:1
252566	shoulder	4	3	3	47	42	Épaulières de traqueur en mailles	Agi +11 · End +9 · Int +7 · Esp +6	c165:1
252567	shoulder	4	3	3	47	42	Épaulières de mande-ciel en mailles	End +7 · Int +9 · Esp +6 · Puiss. sorts +13	c165:1
252568	shoulder	4	3	3	47	42	Épaulières d’escarmouche en mailles	For +11 · End +7 · Int +6 · Puiss. sorts +10	c165:1
252569	shoulder	4	3	3	47	42	Épaulières de soigneur en mailles	End +6 · Int +9 · Esp +7 · Dégâts sorts +8 · Soins +24	c165:1
252570	wrist	4	3	3	50	45	Brassards de traqueur en mailles	Agi +9 · End +7 · Int +6 · Esp +5	c165:1
252571	wrist	4	3	3	50	45	Brassards de mande-ciel en mailles	End +6 · Int +7 · Esp +5 · Puiss. sorts +10	c165:1
252572	wrist	4	3	3	50	45	Brassards d’escarmouche en mailles	For +9 · End +6 · Int +5 · Puiss. sorts +8	c165:1
252573	wrist	4	3	3	50	45	Brassards de soigneur en mailles	End +5 · Int +7 · Esp +6 · Dégâts sorts +6 · Soins +19	c165:1
252574	feet	4	3	2	51	46	Bottes en écailles de scorpide souples	For +8 · End +10 · Puiss. sorts +8	c165:1
252575	waist	4	3	2	51	46	Ceinture en écailles de scorpide chargées	Int +10 · Esp +8 · Puiss. sorts +8	c165:1
252576	feet	4	3	3	52	47	Solerets de traqueur en mailles	Agi +13 · End +11 · Int +9	c165:1
252577	feet	4	3	3	52	47	Solerets de mande-ciel en mailles	End +9 · Int +11 · Puiss. sorts +15	c165:1
252578	feet	4	3	3	52	47	Solerets d’escarmouche en mailles	For +13 · End +9 · Puiss. sorts +13	c165:1
252579	feet	4	3	3	52	47	Solerets de soigneur en mailles	End +9 · Int +11 · Dégâts sorts +9 · Soins +28	c165:1
252580	legs	4	3	2	53	48	Jambières en écailles de scorpide souples	For +10 · End +16 · Puiss. sorts +12	c165:1
252581	head	4	3	2	53	48	Heaume en écailles de scorpide chargées	Int +16 · Esp +10 · Puiss. sorts +12	c165:1
252582	wrist	4	3	2	55	50	Brassards en écailles de scorpide souples	For +6 · End +8 · Puiss. sorts +7	c165:1
252583	shoulder	4	3	2	55	50	Épaulières en écailles de scorpide chargées	Int +12 · Esp +8 · Puiss. sorts +9	c165:1
252584	hands	4	3	3	55	50	Gantelets de traqueur en mailles	Agi +14 · End +9 · Int +9 · Esp +6	c165:1
252585	hands	4	3	3	55	50	Gantelets de mande-ciel en mailles	End +9 · Int +9 · Esp +6 · Puiss. sorts +16	c165:1
252586	hands	4	3	3	55	50	Gantelets d’escarmouche en mailles	For +14 · End +9 · Int +6 · Puiss. sorts +11	c165:1
252587	hands	4	3	3	55	50	Gantelets de soigneur en mailles	End +6 · Int +9 · Esp +9 · Dégâts sorts +10 · Soins +31	c165:1
252588	waist	4	3	3	55	50	Ceinture de traqueur en mailles	Agi +14 · End +12 · Int +10	c165:1
252589	waist	4	3	3	55	50	Ceinture de mande-ciel en mailles	End +10 · Int +12 · Puiss. sorts +16	c165:1
252590	waist	4	3	3	55	50	Ceinture d’escarmouche en mailles	For +14 · End +10 · Puiss. sorts +15	c165:1
252591	waist	4	3	3	55	50	Ceinture de soigneur en mailles	End +10 · Int +12 · Dégâts sorts +10 · Soins +30	c165:1
252592	shoulder	4	3	2	56	51	Épaulières en écailles de scorpide souples	For +8 · End +12 · Puiss. sorts +9	c165:1
252593	wrist	4	3	2	56	51	Brassards en écailles de scorpide chargées	Int +7 · Esp +6 · Puiss. sorts +9	c165:1
252594	feet	4	3	2	56	51	Bottes en écailles de scorpide épaisses	Agi +10 · End +9	c165:1
252595	waist	4	3	2	56	51	Ceinture en écailles de scorpide souples	End +12 · Puiss. sorts +12	c165:1
252596	hands	4	3	2	56	51	Gantelets en écailles de scorpide chargées	Int +9 · Esp +8 · Puiss. sorts +12	c165:1
252597	head	4	3	2	57	52	Heaume en écailles de scorpide souples	For +11 · End +13 · Puiss. sorts +17	c165:1
252598	chest	4	3	2	57	52	Gilet en écailles de scorpide chargées	Int +15 · Esp +14 · Puiss. sorts +12	c165:1
252599	chest	4	3	2	59	54	Gilet en écailles de scorpide souples	For +15 · End +16 · Puiss. sorts +12	c165:1
252600	legs	4	3	2	59	54	Jambières en écailles de scorpide chargées	Int +9 · Esp +9 · Puiss. sorts +20	c165:1
252601	feet	4	3	2	61	56	Solerets en écailles de scorpide souples	For +7 · End +7 · Puiss. sorts +15	c165:1
252602	feet	4	3	2	61	56	Bottes en écailles de scorpide chargées	Int +9 · Esp +9 · Puiss. sorts +14	c165:1
252603	legs	4	3	4	61	56	Jambières en écailles de dragon rouge	Int +32 · Dégâts sorts +20 · Soins +20	c165:1
252604	head	4	3	4	61	56	Heaume en écailles de dragon bleu	Int +18 · Puiss. sorts +25 · Toucher +10	c165:1
252605	head	4	3	4	61	56	Heaume en écailles de dragon noir	Agi +21 · Int +38 · Crit. +14	c165:1
252606	legs	4	3	4	61	56	Jambières en écailles de scorpide immaculées	For +18 · Puiss. sorts +33 · Crit. +14	c165:1
253884	chest	4	1	2	55	50	Template Item		
253885	waist	4	1	3	15	10	Écharpe d’arcaniste novice	End +3 · Int +3 · Puiss. sorts +4	c197:1
253887	waist	4	1	3	15	10	Écharpe ardente de novice	Int +3 · Esp +3 · Dégâts sorts +2 · Soins +6	c197:1
253889	feet	4	1	3	17	12	Bottes immaculées	End +4 · Int +3 · Dégâts sorts +3 · Soins +9	c197:1
253891	feet	4	1	3	17	12	Bottes soyeuses	End +4 · Int +3	c197:1
253893	feet	4	1	3	17	12	Bottes des flammes	End +4 · Int +3	c197:1
253895	feet	4	1	3	17	12	Bottes ombreuses	End +4 · Int +3	c197:1
253897	feet	4	1	3	17	12	Bottes nacrées	End +4 · Int +3	c197:1
253899	feet	4	1	3	17	12	Bottes brillantes	End +4 · Int +3	c197:1
253901	chest	4	1	3	20	15	Robe immaculée filigranée	End +4 · Int +5 · Esp +3 · Dégâts sorts +5 · Soins +13	c197:1
253903	chest	4	1	3	20	15	Robe soyeuse filigranée	End +4 · Int +5 · Esp +3	c197:1
253905	chest	4	1	3	20	15	Robe des flammes filigranée	End +4 · Int +5 · Esp +3	c197:1
253907	chest	4	1	3	20	15	Robe ombreuse filigranée	End +4 · Int +5 · Esp +3	c197:1
253909	chest	4	1	3	20	15	Robe nacrée filigranée	End +4 · Int +5 · Esp +3	c197:1
253911	chest	4	1	3	20	15	Robe brillante filigranée	End +4 · Int +5 · Esp +3	c197:1
253913	hands	4	1	3	20	15	Gants immaculés	End +4 · Int +3 · Dégâts sorts +4 · Soins +11	c197:1
253915	hands	4	1	3	20	15	Gants soyeux	End +4 · Int +3	c197:1
253917	hands	4	1	3	20	15	Gants des flammes	End +4 · Int +3	c197:1
253919	hands	4	1	3	20	15	Gants ombreux	End +4 · Int +3	c197:1
253921	hands	4	1	3	20	15	Gants nacrés	End +4 · Int +3	c197:1
253923	hands	4	1	3	20	15	Gants brillants	End +4 · Int +3	c197:1
253925	waist	4	1	3	22	17	Écharpe immaculée	End +5 · Int +4 · Dégâts sorts +4 · Soins +11	c197:1
253927	waist	4	1	3	22	17	Écharpe soyeuse	End +5 · Int +4	c197:1
253929	waist	4	1	3	22	17	Écharpe des flammes	End +5 · Int +4	c197:1
253931	waist	4	1	3	22	17	Écharpe ombreuse	End +5 · Int +4	c197:1
253933	waist	4	1	3	22	17	Écharpe nacrée	End +5 · Int +4	c197:1
253935	waist	4	1	3	22	17	Écharpe brillante	End +5 · Int +4	c197:1
253937	legs	4	1	3	25	20	Jambières immaculées filigranées	End +5 · Int +6 · Esp +4 · Dégâts sorts +6 · Soins +18	c197:1
253939	legs	4	1	3	25	20	Jambières soyeuses filigranées	End +5 · Int +6 · Esp +4	c197:1
253941	legs	4	1	3	25	20	Jambières des flammes filigranées	End +5 · Int +6 · Esp +4	c197:1
253943	legs	4	1	3	25	20	Jambières ombreuses filigranées	End +5 · Int +6 · Esp +4	c197:1
253945	legs	4	1	3	25	20	Jambières nacrées filigranées	End +5 · Int +6 · Esp +4	c197:1
253947	legs	4	1	3	25	20	Jambières brillantes filigranées	End +5 · Int +6 · Esp +4	c197:1
253949	head	4	1	3	25	20	Diadème immaculé	End +10 · Dégâts sorts +6 · Soins +18	c197:1
253951	head	4	1	3	25	20	Diadème soyeux	End +10	c197:1
253953	head	4	1	3	25	20	Diadème des flammes	End +10	c197:1
253955	head	4	1	3	25	20	Diadème ombreux	End +10	c197:1
253957	head	4	1	3	25	20	Diadème nacré	End +10	c197:1
253959	head	4	1	3	25	20	Diadème brillant	End +10	c197:1
253961	chest	4	1	3	27	22	Robe immaculée	End +6 · Int +7 · Esp +4 · Dégâts sorts +7 · Soins +20	c197:1
253963	chest	4	1	3	27	22	Robe soyeuse	End +6 · Int +7 · Esp +4	c197:1
253965	chest	4	1	3	27	22	Robe des flammes	End +6 · Int +7 · Esp +4	c197:1
253967	chest	4	1	3	27	22	Robe ombreuse	End +6 · Int +7 · Esp +4	c197:1
253969	chest	4	1	3	27	22	Robe nacrée	End +6 · Int +7 · Esp +4	c197:1
253971	chest	4	1	3	27	22	Robe brillante	End +6 · Int +7 · Esp +4	c197:1
253975	head	4	1	3	30	25	Diadème immaculé filigrané	End +12 · Dégâts sorts +8 · Soins +22	c197:1
253977	head	4	1	3	30	25	Diadème soyeux filigrané	End +12	c197:1
253979	head	4	1	3	30	25	Diadème des flammes filigrané	End +12	c197:1
253981	head	4	1	3	30	25	Diadème ombreux filigrané	End +12	c197:1
253983	head	4	1	3	30	25	Diadème nacré filigrané	End +12	c197:1
253985	head	4	1	3	30	25	Diadème brillant filigrané	End +12	c197:1
253987	legs	4	1	3	30	25	Jambières immaculées	End +7 · Int +7 · Esp +5 · Dégâts sorts +7 · Soins +22	c197:1
253989	legs	4	1	3	30	25	Jambières soyeuses	End +7 · Int +7 · Esp +5	c197:1
253991	legs	4	1	3	30	25	Jambières des flammes	End +7 · Int +7 · Esp +5	c197:1
253993	legs	4	1	3	30	25	Jambières ombreuses	End +7 · Int +7 · Esp +5	c197:1
253995	legs	4	1	3	30	25	Jambières nacrées	End +7 · Int +7 · Esp +5	c197:1
253997	legs	4	1	3	30	25	Jambières brillantes	End +7 · Int +7 · Esp +5	c197:1
253999	legs	4	1	2	35	30	Jambières terrestres	Esp +11 · Dégâts sorts +5 · Soins +15	c197:1
254001	feet	4	1	3	35	30	Mules ambrées	End +6 · Int +7 · Esp +4 · Dégâts sorts +7 · Soins +20	c197:1
254003	feet	4	1	3	35	30	Mules écumeuses	End +6 · Int +7 · Esp +4	c197:1
254005	feet	4	1	3	35	30	Mules embrasées	End +6 · Int +7 · Esp +4	c197:1
254007	feet	4	1	3	35	30	Mules noires	End +6 · Int +7 · Esp +4	c197:1
254009	feet	4	1	3	35	30	Mules dorées	End +6 · Int +7 · Esp +4	c197:1
254011	feet	4	1	3	35	30	Mules radieuses	End +6 · Int +7 · Esp +4	c197:1
254013	feet	4	1	2	36	31	Mules terrestres en soie	Esp +7 · Puiss. sorts +18 · Dégâts sorts +6	c197:1
254015	head	4	1	2	37	32	Chaperon terrestre en soie	Esp +10 · Dégâts sorts +8 · Soins +22	c197:1
254017	hands	4	1	2	39	34	Gants terrestres en soie	Esp +8 · Dégâts sorts +6 · Soins +18	c197:1
254019	wrist	4	1	2	40	35	Crispins terrestres en soie	Esp +5 · Dégâts sorts +4 · Soins +10	c197:1
254021	hands	4	1	3	40	35	Protège-mains ambrés	End +9 · Int +7 · Dégâts sorts +8 · Soins +22	c197:1
254023	hands	4	1	3	40	35	Protège-mains écumeux	End +9 · Int +7	c197:1
254025	hands	4	1	3	40	35	Protège-mains embrasés	End +9 · Int +7	c197:1
254027	hands	4	1	3	40	35	Protège-mains noirs	End +9 · Int +7	c197:1
254029	hands	4	1	3	40	35	Protège-mains dorés	End +9 · Int +7	c197:1
254031	hands	4	1	3	40	35	Protège-mains radieux	End +9 · Int +7	c197:1
254033	shoulder	4	1	2	41	36	Épaulières terrestres en soie	Esp +8 · Dégâts sorts +6 · Soins +18	c197:1
254037	waist	4	1	3	45	40	Corde ambrée	End +8 · Int +8 · Esp +6 · Dégâts sorts +8 · Soins +22	c197:1
254039	waist	4	1	3	45	40	Corde écumeuse	End +8 · Int +8 · Esp +6	c197:1
254041	waist	4	1	3	45	40	Corde embrasée	End +8 · Int +8 · Esp +6	c197:1
254043	waist	4	1	3	45	40	Corde noire	End +8 · Int +8 · Esp +6	c197:1
254045	waist	4	1	3	45	40	Corde dorée	End +8 · Int +8 · Esp +6	c197:1
254047	waist	4	1	3	45	40	Corde radieuse	End +8 · Int +8 · Esp +6	c197:1
254049	shoulder	4	1	3	47	42	Épaulières d’or-du-Néant	End +8 · Int +8 · Esp +6 · Dégâts sorts +9 · Soins +26	c197:1
254051	shoulder	4	1	3	47	42	Épaulières d’écume-du-Néant	End +8 · Int +8 · Esp +6	c197:1
254053	shoulder	4	1	3	47	42	Épaulières de flamme-du-Néant	End +8 · Int +8 · Esp +6	c197:1
254055	shoulder	4	1	3	47	42	Épaulières de perle-du-Néant	End +8 · Int +8 · Esp +6	c197:1
254057	shoulder	4	1	3	47	42	Épaulières d’éclat-du-Néant	End +8 · Int +8 · Esp +6	c197:1
254059	shoulder	4	1	3	47	42	Épaulières de lumière-du-Néant	End +8 · Int +8 · Esp +6	c197:1
254061	wrist	4	1	3	50	45	Crispins d’or-du-Néant	End +7 · Int +7 · Esp +5 · Dégâts sorts +7 · Soins +20	c197:1
254063	wrist	4	1	3	50	45	Crispins d’écume-du-Néant	End +7 · Int +7 · Esp +5	c197:1
254065	wrist	4	1	3	50	45	Crispins de flamme-du-Néant	End +7 · Int +7 · Esp +5	c197:1
254067	wrist	4	1	3	50	45	Crispins de perle-du-Néant	End +7 · Int +7 · Esp +5	c197:1
254069	wrist	4	1	3	50	45	Crispins d’éclat-du-Néant	End +7 · Int +7 · Esp +5	c197:1
254071	wrist	4	1	3	50	45	Crispins de lumière-du-Néant	End +7 · Int +7 · Esp +5	c197:1
254073	waist	4	1	2	52	47	Corde en tisse-fantôme	Esp +11 · Puiss. sorts +14	c197:1
254075	hands	4	1	2	52	47	Gants en tisse-terrestre	Esp +11 · Dégâts sorts +9 · Soins +26	c197:1
254077	waist	4	1	2	52	47	Corde en tisse-terrestre	Esp +11 · Dégâts sorts +9 · Soins +26	c197:1
254081	waist	4	1	3	52	47	Corde cintrée ambrée	End +12 · Int +9 · Dégâts sorts +10 · Soins +29	c197:1
254083	waist	4	1	3	52	47	Corde cintrée écumeuse	End +12 · Int +9	c197:1
254085	waist	4	1	3	52	47	Corde cintrée embrasée	End +12 · Int +9	c197:1
254087	waist	4	1	3	52	47	Corde cintrée noire	End +12 · Int +9	c197:1
254089	waist	4	1	3	52	47	Corde cintrée dorée	End +12 · Int +9	c197:1
254091	waist	4	1	3	52	47	Corde cintrée radieuse	End +12 · Int +9	c197:1
254093	feet	4	1	2	54	49	Bottes en tisse-terrestre	Esp +11 · Dégâts sorts +9 · Soins +26	c197:1
254095	hands	4	1	3	55	50	Gants ambrés	End +9 · Int +10 · Esp +8 · Dégâts sorts +10 · Soins +29	c197:1
254097	hands	4	1	3	55	50	Gants écumeux	End +9 · Int +10 · Esp +8	c197:1
254099	hands	4	1	3	55	50	Gants embrasés	End +9 · Int +10 · Esp +8	c197:1
254101	hands	4	1	3	55	50	Gants noirs	End +9 · Int +10 · Esp +8	c197:1
254103	hands	4	1	3	55	50	Gants dorés	End +9 · Int +10 · Esp +8	c197:1
254105	hands	4	1	3	55	50	Gants radieux	End +9 · Int +10 · Esp +8	c197:1
254107	feet	4	1	3	55	50	Sandales ambrées	End +13 · Int +9 · Dégâts sorts +11 · Soins +31	c197:1
254109	feet	4	1	3	55	50	Sandales écumeuses	End +13 · Int +9	c197:1
254111	feet	4	1	3	55	50	Sandales embrasées	End +13 · Int +9	c197:1
254113	feet	4	1	3	55	50	Sandales noires	End +13 · Int +9	c197:1
254115	feet	4	1	3	55	50	Sandales dorées	End +13 · Int +9	c197:1
254117	feet	4	1	3	55	50	Sandales radieuses	End +13 · Int +9	c197:1
254119	shoulder	4	1	2	57	52	Mantelet en tisse-terrestre	Esp +12 · Dégâts sorts +9 · Soins +26	c197:1
254121	chest	4	1	2	59	54	Gilet en tisse-terrestre	Esp +17 · Dégâts sorts +14 · Soins +40	c197:1
254123	wrist	4	1	2	59	54	Crispins en étoffe runique	Int +10 · Puiss. sorts +11	c197:1
254125	legs	4	1	2	58	53	Jambières en tisse-terrestre	Esp +16 · Dégâts sorts +13 · Soins +37	c197:1
254127	shoulder	4	1	2	59	54	Mantelet en tisse-fantôme	Esp +12 · Puiss. sorts +15	c197:1
254129	feet	4	1	2	60	55	Bottes en tisse-fantôme	Esp +13 · Puiss. sorts +16	c197:1
254131	wrist	4	1	2	60	55	Crispins en tisse-terrestre	Esp +10 · Dégâts sorts +8 · Soins +22	c197:1
254135	head	4	1	2	61	56	Chaperon en tisse-fantôme	Esp +18 · Puiss. sorts +21	c197:1
254137	head	4	1	2	61	56	Couronne en tisse-terrestre	Esp +18 · Dégâts sorts +14 · Soins +40	c197:1
254779	one	2	7	2	12	0	A’sharahm, la tempête déchaînée	End +1	
257255	off	4	6	2	8	0	Bouclier de défense des hautes-terres	For +1	
257342	legs	4	3	2	13	0	Jambières de garde-paix d’élite	For +3	
257343	two	2	10	2	13	0	Bâton de combat équilibré	End +2 · Esp +2	
257344	chest	4	2	2	13	0	Habits de contemple-ciel	Agi +1 · End +2	
257345	two	2	5	2	13	0	Grand marteau bien poli	For +2 · Esp +2	
257346	one	2	15	2	13	0	Dague de prestelame	Agi +1	
257943	back	4	1	2	8	0	Cape de chasseur simple	End +1	
259846	head	4	1	2	48	0	Chapeau de pêche à large bord	End +13 · Esp +13	
259890	feet	4	1	2	48	0	Cuissarde de pêche des grands fonds	End +10 · Esp +10	
259891	ranged	2	3	2	48	0	Fidèle carabine de Berdun		
259892	neck	4	0	2	52	0	Amulette de Trouilleffroi purifiée	Esp +8 · Puiss. sorts +9	
260166	two	2	5	2	52	0	Meilleure massue de Hurlerage	For +15 · Esp +15	
260167	feet	4	2	2	52	0	Bottes d’aventurier perdues	Agi +4 · End +15 · Esp +8	
260168	back	4	1	2	52	0	Voile de deuil	For +7 · End +9	
260169	shoulder	4	1	2	52	0	Amict de chagrin	Int +14 · Puiss. sorts +9	
260171	neck	4	0	2	52	0	Chapelet grumegueule	Agi +10 · Esp +5	
260172	one	2	15	2	52	0	Dague de l’assassin	For +6 · Agi +6	
260178	chest	4	4	2	52	0	Armure de plaques de garde d’honneur	For +18 · End +9	
260179	waist	4	2	2	52	0	Ceinture tissée d’écorce	Esp +11 · Puiss. sorts +13	
260180	one	2	15	2	52	0	Dague d’éclaireuse	For +6 · Agi +6	
260181	chest	4	4	2	52	0	Armure de plaques de sentinelle	For +18 · End +9	
260182	waist	4	2	2	52	0	Ceinture élunaire	Esp +11 · Puiss. sorts +13	
260183	wrist	4	2	3	55	0	Bracelet sacré	End +12 · Esp +6 · Puiss. sorts +8	
260184	waist	4	4	3	55	0	Cordelière de marcheur des falaises	For +17 · Agi +8 · End +9	
260185	feet	4	3	3	55	0	Bottes en peau d’hippogriffe	For +17 · End +9 · Puiss. sorts +9	
260186	two	2	8	2	55	0	Sombrelame		
260195	head	4	1	2	55	0	Coiffure des damnés	End +16	
260196	waist	4	2	2	55	0	Ceinture des ombres	For +12 · Agi +14	
260201	off	4	0	2	55	0	Cristal de mémoire de Bien-né	Esp +9 · Dégâts sorts +6 · Soins +19	
260205	trinket	4	0	2	55	0	Tablette de recherches de Bien-né		
260207	two	2	10	2	55	0	Bâton de l’archimage Selwyn	End +16 · Int +16	
260208	off	4	0	2	55	0	Orbe de prélat	Esp +13	
260209	main	2	4	2	55	0	Marteau de Chantevrai	For +10	
260210	off	4	6	3	56	0	Un bouclier plus grand	Agi +7 · End +7 · Déf. +4	
260211	hands	4	2	3	56	0	Mains de panique	For +13 · Agi +13 · End +13	
260212	head	4	1	3	56	0	Mauvais chapeau	Int +17 · Esp +17 · Dégâts sorts +12 · Soins +37	
260819	trinket	4	0	2	60	55	Transporteur de terrain Ev-Lan vers Gadgetzan		c202:1
260820	trinket	4	0	2	60	55	Déchiqueteur d’urgence SUR-T – Long-Guet		c202:1
260821	trinket	4	0	2	60	60	Transporteur de terrain SUR-VLAN vers le mont Hyjal		c202:1
260824	trinket	4	0	3	60	60	Pouletisateur gnome		c202:1
260828	waist	4	0	2	60	55	Nitro-survolteurs SUR-T		c202:1
260829	waist	4	0	2	60	55	Piston magnétique Ev-Lan		c202:1
260830	waist	4	0	2	60	55	Téléporteur SUR-T		c202:1
263305	off	4	6	2	10	0	Bouclier soufflé	For +1	
263306	hands	4	2	2	11	0	Gants de la Noctegriffe	Agi +1	
263307	legs	4	1	2	11	0	Pantalon trombenoire	Puiss. sorts +2	
263308	feet	4	3	2	11	0	Bottes de chasse à la secte	End +1	
263309	feet	4	2	2	11	0	Brodequins de la liberté	For +1	
263310	hands	4	1	2	11	0	Gants tristechant	Int +1	
263311	wrist	4	3	2	11	0	Crispins éraflés	For +1	
263312	two	2	5	2	10	0	Pelle à plantations	For +1	
263313	one	2	4	2	10	0	Clé à molette fiable	Agi +1	
263314	one	2	4	2	10	0	Marteau à toiture	Esp +1	
263329	one	2	4	2	9	0	Tapette à voltemouches		
263330	legs	4	2	2	13	0	Pantalon de pisteur	Agi +3	
263332	chest	4	1	2	13	0	Tunique d’ancien	Int +4	
263333	chest	4	3	2	13	0	Cotte de mailles de garde-paix	End +3	
263335	waist	4	2	2	13	0	Corde de chasseur	End +2	
263336	wrist	4	1	2	13	0	Bracelets chantevent	Puiss. sorts +1	
263337	hands	4	3	2	13	0	Gantelets briseurs	For +2	
263338	wrist	4	2	2	13	0	Brassards de défense	End +1	
263339	feet	4	1	2	13	0	Mules de Souffle-Bise	Esp +2	
263340	legs	4	3	2	13	0	Garde-jambes de garde-paix	Agi +3	
263401	chest	4	2	2	11	0	Armure de martyr	Agi +2	
263402	waist	4	1	2	11	0	Écharpe de chagrin	Int +1	
263403	waist	4	3	2	11	0	Cilice de regret	For +1	
263404	ranged	2	2	2	13	0	Ruban des heures	Agi +1	
263405	waist	4	2	2	15	0	Ceinture des lames	For +2 · Agi +2	
263406	feet	4	1	2	15	0	Chaussures empyréennes	Esp +2 · Puiss. sorts +2	
263407	two	2	8	2	15	0	Estramaçon empyréen	For +4	
263411	ranged	4	8	2	16	0	Idole des flots changeants		
263412	ranged	4	9	2	10	0	Totem des flammes chargées		
263430	ranged	2	19	2	10	0	Baguette de soufflebranche	Int +1	
263431	off	4	6	2	10	0	Égide de défense	For +1	
263432	one	2	15	2	10	0	Coutelas de furtivité	Agi +1	
263434	two	2	10	2	10	0	Bâton de bête ailée	Agi +1	
263435	ranged	4	8	2	10	0	Marque d’Urs’endris		
263436	ranged	4	9	2	10	0	Totem de tempête de feu		
268484	two	2	8	2	31	0	Lame de sélénargent	End +7 · Int +7	
268873	trinket	4	0	4	62	55	Défenseur peau-d’écorce		
269501	wrist	4	1	2	60	55	Garde-poignets en mailles elfiques	End +10 · Puiss. sorts +5 · Armure +150	
269502	chest	4	4	2	58	53	Plaque naine	For +7 · Agi +6 · End +13 · Armure +60	
269503	feet	4	2	2	60	56	Bottes de braconnage	For +3 · Agi +15 · End +7	
269716	main	2	15	2	19	0	Couteau à dépecer effilé	Int +2	
269717	two	2	8	2	19	0	Estramaçon de Fauvétripe	For +6	
269741	trinket	4	0	2	58	0	Broche en runebois parfumé		
269742	ranged	2	3	2	20	0	Deuxième arme préférée de Walton	Agi +3	
270000	chest	4	1	2	13	0	Robe d’apprenti sorcier	Int +2 · Puiss. sorts +2	
270004	hands	4	2	2	14	0	Gants en peau de Murloc	Agi +2	
270006	feet	4	2	2	17	0	Bottes de la milice du peuple	Puiss. sorts +4	
270007	waist	4	1	2	18	0	Corde cintrée de mineur usée	End +2 · Int +3	
270010	wrist	4	3	2	20	0	Brassards de la crête du raptor	For +3 · End +1	
270011	legs	4	1	2	21	0	Jambières brodées	End +5 · Puiss. sorts +4	
270012	hands	4	1	2	20	0	Gants de travail de mineur	End +5	
270013	feet	4	2	2	20	0	Bottes de travail de mineur	Esp +5	
270014	legs	4	2	2	20	0	Pantalon en peau de daim	For +5 · End +3	
270019	feet	4	2	2	24	0	Brodequins du loch	Agi +4 · Esp +3	
270020	legs	4	2	2	24	0	Pantalon en peau de Gnoll	For +6 · End +4	
270022	chest	4	1	2	20	0	Robe d’archéologue	Esp +5 · Puiss. sorts +2	
270028	wrist	4	1	2	27	0	Bracelets de harpie	End +1 · Int +4	
270033	wrist	4	2	2	27	0	Brassards en peau de démon	For +3 · Agi +4	
270034	hands	4	3	2	27	0	Gantelets de l’ombre	For +5 · End +4	
270035	chest	4	1	2	27	0	Robe de récupérateur	End +5 · Int +8	
270037	legs	4	2	2	28	0	Jambières fumantes	Int +9 · Esp +3	
270038	hands	4	3	2	30	0	Gantelets runiques	For +5 · End +5	
270039	shoulder	4	2	2	29	0	Épaulières de griffe de raptor	Int +3 · Puiss. sorts +7	
270044	shoulder	4	2	2	35	0	Garde-épaules de Sombre-Comté	End +7 · Esp +7	
270046	shoulder	4	1	2	30	0	Mantelet éthérien	Int +5 · Esp +5	
270048	one	2	4	2	32	0	Casse-tête d’Uthil	End +3 · Esp +3	
270049	two	2	10	2	32	0	Bâton de guerre de Mavoris	For +11 · End +3	
270050	finger	4	0	2	34	0	Anneau de rage	For +6 · Esp +2	
270051	finger	4	0	2	35	0	Anneau d’héritage de Ladimore	Int +6 · Puiss. sorts +5	
270052	finger	4	0	2	35	0	Anneau lacustre	Agi +2 · PA +14	
270053	finger	4	0	2	35	0	Anneau de la ruine	For +4 · Agi +6	
270056	legs	4	1	2	37	0	Jambières de bibliothécaire de Stromgarde	End +6 · Int +9 · Puiss. sorts +9	
270057	legs	4	2	2	37	0	Pantalon d’agent de Stromgarde	For +8 · Agi +9 · End +6	
270065	off	4	6	2	38	0	Bouclier oublié de long-voyant	End +4 · Puiss. sorts +7	
270066	feet	4	2	2	39	0	Bottes de la tour	For +9 · End +6	
270067	head	4	2	2	39	0	Coiffure sauvage	Int +11 · Puiss. sorts +12	
270068	wrist	4	3	2	39	0	Brassards de Stromgarde	For +8 · End +3	
270069	main	2	15	2	41	0	Tranche-esprit	Int +7	
270070	main	2	15	2	40	0	Lame du dément	Esp +7	
270071	two	2	5	2	40	0	Marteau au cœur noir	For +12 · End +8	
270072	hands	4	2	2	40	0	Gants d’assassin d’Alterac	Agi +12	
270073	wrist	4	3	2	40	0	Crispins de Stromgarde	For +8 · End +3	
270076	wrist	4	2	2	40	0	Brassards de la marée	For +5 · Agi +5 · End +3	
270077	legs	4	3	2	40	0	Garde-jambes du ressac	For +9 · Agi +6 · End +8	
270079	chest	4	1	2	41	0	Robe de féticheur	Int +17	
270080	wrist	4	2	2	40	0	Bracières arathies	For +7 · Agi +5	
270082	chest	4	1	2	42	0	Blouse de cérémonie	Int +11 · Puiss. sorts +13	
270083	legs	4	2	2	42	0	Pantalon ensanglanté	Agi +13 · End +9	
270084	ranged	2	19	2	43	0	Baguette de maître-chasseur	Puiss. sorts +8	
270085	two	2	8	2	43	0	Sorcépée de maître-chasseur	For +12 · Puiss. sorts +14	
270086	hands	4	1	2	43	0	Mitaines d’Ogre surdimensionnées	Int +11 · Puiss. sorts +4	
270087	waist	4	3	2	43	0	Ceinture d’Ogre épaisse	For +10 · Agi +7	
270088	main	2	4	2	45	0	Marteau de thane	Int +8	
270089	hands	4	2	2	45	0	Gants d’agent de Forgefer	For +7 · Agi +11	
270090	legs	4	1	2	44	0	Jambières de mendiant	Esp +12 · Puiss. sorts +14	
270091	wrist	4	2	2	44	0	Crispins de loup de mer usés	Agi +8 · End +5	
270092	one	2	7	2	45	0	Cimeterre des Flots noirs	For +5 · Agi +5	
270093	head	4	1	2	45	0	Coiffe des Flots noirs	Int +17 · Puiss. sorts +6	
270094	feet	4	2	2	45	0	Bottes de dragonnet noir	Agi +9 · Esp +9	
270096	chest	4	4	2	46	0	Cuirasse de rebelle	For +14 · End +10	
270097	legs	4	3	2	46	0	Jambières d’archer	Agi +17 · End +6	
270100	wrist	4	2	2	47	0	Bracières de flibustier	End +10 · PA +6	
270101	feet	4	2	2	49	0	Appareil de flottaison gnome	For +10 · End +10	
270102	wrist	4	2	2	51	0	Redirigeurs de projectile	For +5 · Agi +10	
270103	wrist	4	3	2	51	0	Bracières d’aide à la recharge	Agi +10 · Esp +5	
270104	feet	4	2	2	50	0	Mules de marchepierre	End +12 · Int +8	
270105	wrist	4	4	2	50	0	Garde-bras de protecteur	For +3 · Agi +11	
270106	ranged	2	16	2	50	0	Étoiles de lancer cruelles	For +6 · Agi +6	
270107	ranged	2	2	2	50	0	Arc long taché de sang	Agi +8 · End +3	
270108	two	2	5	2	50	0	Masse longue ensanglantée	End +21	
270109	finger	4	0	2	50	0	Anneau d’auriculaire de Smotts	End +11 · Puiss. sorts +4	
270110	wrist	4	3	2	50	0	Garde-bras de second	Agi +8 · Int +8	
270111	legs	4	2	2	51	0	Jambières de Troll des forêts	For +17 · Agi +11	
270112	off	4	0	2	53	0	Cravache de chevaucheur de griffon	Int +7 · Puiss. sorts +12	
270113	chest	4	1	2	50	0	Robe roussie en étoffe	Int +14 · Puiss. sorts +16	
270114	legs	4	2	2	51	0	Pantalon en écailles de dragon	For +11 · Agi +13 · Esp +8	
270118	chest	4	1	3	54	0	Blouse en étoffe cendrée	End +16 · Int +24	
270122	legs	4	2	2	55	0	Pantalon d’hier	For +14 · End +12 · Esp +9	
270225	trinket	4	0	2	51	0	Joyau de capitaine de la garde	Crit. +7	
270226	trinket	4	0	2	50	0	Banane d’or		
270270	off	4	6	2	38	0	Écaille du Courbe-Marée		
270275	trinket	4	0	2	51	0	Médaillon vilebranche purifié	Toucher +7	
270276	trinket	4	0	2	51	0	Icône vilebranche purifiée	Crit. +7	
271664	one	2	0	2	33	0	Poids de charme	For +6	
271667	two	2	5	2	33	0	Destructeur en bois-de-fer		
271670	finger	4	0	2	33	0	Boucle de vie	End +5 · Puiss. sorts +5	
271716	back	4	1	3	33	0	Cape anti-poussière de la Ligue des explorateurs	Agi +5 · Int +5 · Esp +5	
271719	back	4	1	3	33	0	Fourrures du Cercle terrestre	For +5 · Int +5 · Esp +5	
271720	back	4	1	3	30	25	Houseaux en peau de crocilisque	For +5 · Agi +4 · End +5	
271732	wrist	4	2	2	33	0	Brassards chargés de poussière	Esp +4 · PA +10	
271740	wrist	4	1	2	33	0	Chiffon à polir les couteaux	Esp +4 · Puiss. sorts +6	
271766	two	2	5	3	33	0	Marteau de soulèvement	PA +32 · Armure +60	
271767	two	2	10	3	33	0	Bâton de soins	End +12 · Mana/5 +5	
271769	waist	4	1	2	33	0	Ceinturon de Daewyn	Esp +6 · Puiss. sorts +7	
271794	two	2	6	2	43	1	Lance de Centaure	For +11 · End +13	
271795	two	2	8	2	43	1	Épée large d’errance	End +12 · Toucher +10	
271796	one	2	7	2	43	1	Lame du clan Magram	End +4 · PA +10	
271797	two	2	10	2	43	0	Bâton des révélations	Int +10 · Esp +13	
271798	off	4	6	2	43	1	Barrière de désespoir	For +5 · End +8	
271799	main	2	15	2	43	0	Pince de clampant du désert	End +2 · Int +6	
271800	two	2	6	3	43	1	Armement magram récupéré	Agi +5 · End +14 · PA +12	
271801	two	2	1	3	43	1	Férocité abandonnée	For +12 · Agi +10 · End +4	
271802	one	2	4	3	43	1	Gourdin des vertus bafouées	For +3 · Agi +2 · End +6	
271803	two	2	10	3	43	0	Grand bâton des nécrokhans	End +16 · Int +12 · Esp +6	
271804	main	2	4	3	43	0	Masse écrase-âmes	End +3 · Int +6 · Esp +1	
271805	off	4	0	3	43	1	Effigie de triple damnation	End +2 · Int +4 · Esp +8	
271806	neck	4	0	2	43	1	Amulette de survivant	For +5 · End +8	
271807	neck	4	0	2	43	1	Collier défraîchi	End +8 · Int +5	
271808	finger	4	0	2	43	1	Anneau du charognard	End +8 · Int +5	
271809	finger	4	0	2	43	1	Bague de la désolation	End +8 · Int +5	
271810	back	4	1	3	43	1	Mue de Nécrobi	For +4 · Agi +4 · End +11	
271811	shoulder	4	3	3	43	1	Spallières claquantes en carapace	Agi +7 · End +14 · PA +8	
271812	head	4	1	3	43	1	Diadème abandonné	End +16 · Int +11 · Esp +10	
271903	trinket	4	0	3	53	48	Sceau enrichi	End +10	
271904	trinket	4	0	3	38	33	Sceau porte-bonheur de volontaire	End +7	
271905	trinket	4	0	3	38	33	Sceau enrichi	End +7	
271906	trinket	4	0	3	53	48	Sceau porte-bonheur de volontaire	End +10	
271908	finger	4	0	3	63	58	Chevalière de Theramore	End +16 · PA +17	
271909	finger	4	0	3	53	48	Chevalière de Theramore	End +14 · PA +15	
271910	finger	4	0	3	43	38	Chevalière de Theramore	End +11 · PA +12	
271911	finger	4	0	3	33	28	Chevalière de Theramore	End +8 · PA +9	
271913	finger	4	0	3	63	58	Bague de militant	End +16 · Mana/5 +3	
271914	finger	4	0	3	53	48	Bague de militant	End +14 · Mana/5 +3	
271915	finger	4	0	3	43	38	Bague de militant	End +11 · Mana/5 +2	
271916	finger	4	0	3	33	28	Bague de militant	End +8 · Mana/5 +2	
271917	neck	4	0	3	63	58	Sceau de l’expédition	End +15 · Int +10	
271918	neck	4	0	3	53	48	Sceau de l’expédition	End +13 · Int +9	
271919	neck	4	0	3	43	38	Sceau de l’expédition	End +11 · Int +7	
271920	neck	4	0	3	33	28	Sceau de l’expédition	End +8 · Int +5	
271940	hands	4	4	4	65	60	Gantelets de Theramore	For +27 · Agi +11 · End +15	
271941	hands	4	4	4	55	50	Gantelets de Theramore	For +23 · Agi +10 · End +12	
271945	hands	4	1	4	65	60	Protège-mains de Theramore	End +15 · Int +27 · Dégâts sorts +8 · Soins +24	
271946	hands	4	1	4	55	50	Protège-mains de Theramore	End +12 · Int +23 · Dégâts sorts +7 · Soins +22	
271955	shoulder	4	2	4	65	60	Espauliers de Theramore	Agi +27 · End +12 · Crit. +14	
272059	trinket	4	0	3	38	33	Sceau vaudou sombrelance	End +7	
272060	trinket	4	0	3	53	48	Sceau de chevaucheur implacable	End +10	
272061	trinket	4	0	3	53	48	Sceau vaudou sombrelance	End +10	
272062	trinket	4	0	3	38	33	Sceau de chevaucheur implacable	End +7	
272064	finger	4	0	3	63	58	Bague d’insurgé	End +16 · PA +17	
272065	finger	4	0	3	53	48	Bague d’insurgé	End +14 · PA +15	
272066	finger	4	0	3	43	38	Bague d’insurgé	End +11 · PA +12	
272067	finger	4	0	3	33	28	Bague d’insurgé	End +8 · PA +9	
272068	finger	4	0	3	63	58	Chevalière sombrelance	End +16 · Mana/5 +9	
272069	finger	4	0	3	53	48	Chevalière sombrelance	End +14 · Mana/5 +7	
272070	finger	4	0	3	43	38	Chevalière sombrelance	End +11 · Mana/5 +6	
272071	finger	4	0	3	33	28	Chevalière sombrelance	End +8 · Mana/5 +4	
272072	neck	4	0	3	63	58	Pendentif protecteur sombrelance	End +15 · Int +10	
272073	neck	4	0	3	53	48	Pendentif protecteur sombrelance	End +13 · Int +9	
272074	neck	4	0	3	43	38	Pendentif protecteur sombrelance	End +11 · Int +7	
272075	neck	4	0	3	33	28	Pendentif protecteur sombrelance	End +8 · Int +5	
272095	hands	4	4	4	65	60	Gantelets de chevaucheur	For +27 · Agi +11 · End +15	
272096	hands	4	4	4	55	50	Gantelets de chevaucheur	For +23 · Agi +10 · End +12	
272097	hands	4	1	4	65	60	Protège-mains de chevaucheur	End +15 · Int +27 · Dégâts sorts +8 · Soins +24	
272098	hands	4	1	4	55	50	Protège-mains de chevaucheur	End +12 · Int +23 · Dégâts sorts +7 · Soins +22	
272105	shoulder	4	2	4	65	60	Espauliers sombrelances	Agi +27 · End +12 · Crit. +14	
272179	two	2	8	2	43	1	Estramaçon des passés glorieux	For +14 · Int +9	
272180	one	2	7	2	43	1	Ordre de magistère spectral	For +5 · Int +4	
272181	main	2	15	2	43	0	Coutelas fantasmatique	End +5 · Int +4	
272184	neck	4	0	2	43	1	Amulette de la vengeance	For +6 · End +7	
272185	neck	4	0	2	43	1	Amulette du pardon	Esp +7 · Dégâts sorts +4 · Soins +13	
272186	wrist	4	2	3	43	1	Crispins luxuriants	Agi +7 · End +7 · PA +14	
272187	waist	4	4	3	43	1	Corde couverte d’épines	End +9 · Int +9 · Esp +9	
272394	waist	4	1	4	60	60	Cordelière de pénitence	End +14 · Esp +24 · Dégâts sorts +8 · Soins +23	
272395	waist	4	2	4	60	60	Sangle d’assassin	Agi +21 · End +11 · Toucher +20	
272396	waist	4	2	4	60	60	Ceinture de transfert	For +14 · Agi +24 · End +11	
272397	waist	4	3	4	60	60	Ceinture de forestier	Agi +24 · End +11 · Int +14	
272398	waist	4	2	4	60	60	Corde de conservateur	End +14 · Esp +24 · Dégâts sorts +8 · Soins +23	
272399	waist	4	3	4	60	60	Ceinturon de cherche-tempête	End +11 · Int +24 · Puiss. sorts +16	
272401	waist	4	2	4	60	60	Corde en élunite	End +11 · Int +24 · Puiss. sorts +16	
272402	waist	4	3	4	60	60	Corde cintrée de prophète	End +14 · Esp +24 · Dégâts sorts +8 · Soins +23	
272403	waist	4	4	4	60	60	Sangle des vaillants	For +14 · Agi +24 · End +11	
272404	waist	4	4	4	60	60	Ceinture de redresseur de torts	For +24 · End +11 · Puiss. sorts +16	
272405	waist	4	4	4	60	60	Corde cintrée de rédemption	End +24 · Dégâts sorts +8 · Soins +23 · Crit. +14	
272406	finger	4	0	3	65	60	Anneau de canaliste	Int +14 · Esp +8 · Toucher +10	
272407	finger	4	0	3	65	60	Bague de Lumière bénie	End +10 · Esp +8 · Dégâts sorts +10 · Soins +31 · Toucher +10	
272408	finger	4	0	3	65	60	Chevalière de coupe-gorge	Agi +14 · End +8 · Toucher +10	
272409	finger	4	0	3	65	60	Anneau de vigilance	For +8 · End +10 · Déf. +9	
272410	waist	4	3	4	60	60	Ceinture de cherchevent	For +24 · End +11 · Puiss. sorts +16	
272413	back	4	1	3	65	60	Drapé de récupération	End +8 · Dégâts sorts +10 · Soins +31 · Mana/5 +4	
272427	ranged	4	8	3	65	60	Idole hurlante		
272428	ranged	4	8	3	65	60	Idole enragée		
272429	ranged	4	8	3	65	60	Idole de synthèse		
272430	ranged	4	8	3	65	60	Idole grouillante		
272431	ranged	4	9	3	65	60	Totem des marées		
272432	ranged	4	9	3	65	60	Totem du maelström		
272433	ranged	4	9	3	65	60	Totem ardent		
272434	ranged	4	7	3	65	60	Libram de sentinelle		
272435	ranged	4	7	3	65	60	Libram de législation		
272436	ranged	4	7	3	65	60	Libram d’économie		
272437	trinket	4	0	3	65	60	Assistant de combat adaptatif		
272438	trinket	4	0	3	65	60	Analyseur de faiblesse	Puiss. sorts +22	
272439	trinket	4	0	3	65	60	Champ de sérénité	Dégâts sorts +14 · Soins +42	
272440	trinket	4	0	3	65	60	Stabilisateur de poigne de défense	Déf. +13	
272451	back	4	1	3	50	45	Cape de sergent	End +14 · Armure +60	
272452	one	2	7	4	65	60	Lame de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272453	feet	4	1	3	60	55	Bottillons de qualité de magus	End +19 · Int +12 · Puiss. sorts +9	
272454	wrist	4	1	3	60	55	Crispins de qualité de magus	End +15 · Int +6 · Puiss. sorts +7	
272455	hands	4	1	3	60	55	Gants de qualité de magus	End +19 · Int +10 · Puiss. sorts +12	
272456	waist	4	1	3	60	55	Ceinture de qualité de magus	End +20 · Int +10 · Puiss. sorts +8	
272457	head	4	1	3	60	55	Chaperon de qualité de magus	End +25 · Int +12 · Puiss. sorts +11 · Crit. +7	
272458	legs	4	1	3	60	55	Pantalon de qualité de magus	End +26 · Int +11 · Puiss. sorts +14	
272459	chest	4	1	3	60	55	Robe de qualité de magus	End +25 · Int +10 · Puiss. sorts +14 · Crit. +7	
272461	wrist	4	2	3	60	55	Garde-bras de qualité en cuir de kodo	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
272462	feet	4	2	3	60	55	Bottes de qualité en peau de dragon	For +12 · Agi +6 · End +19 · Int +4	
272463	waist	4	2	3	60	55	Baudrier de qualité en peau de dragon	For +11 · Agi +6 · End +19 · Int +5	
272464	hands	4	2	3	60	55	Gantelets de qualité en cuir de kodo	End +19 · Int +10 · Esp +7 · Dégâts sorts +4 · Soins +11	
272465	wrist	4	2	3	60	55	Garde-bras de qualité en pelombre	Agi +9 · End +15	
272467	hands	4	2	3	60	55	Cestes de qualité en pelombre	End +19 · PA +24 · Crit. +7	
272468	waist	4	2	3	60	55	Ceinturon de qualité en pelombre	For +7 · Agi +12 · End +19	
272469	shoulder	4	2	3	60	55	Spallières de qualité en peau de dragon	For +10 · Agi +5 · End +20 · Int +4	
272470	legs	4	2	3	60	55	Chausses de qualité en peau de peau de dragon	For +12 · Agi +5 · End +26 · Esquive +6	
272471	head	4	2	3	60	55	Heaume de qualité en peau de dragon	For +14 · Agi +7 · End +26 · Armure +30	
272472	chest	4	2	3	60	55	Cuirasse de qualité en peau de dragon	For +11 · End +26 · Int +7 · Crit. +7	
272473	chest	4	2	3	60	55	Haubert de qualité en pelombre	End +26 · PA +16 · Crit. +14	
272474	head	4	2	3	60	55	Protège-front de qualité en pelombre	End +25 · PA +14 · Crit. +14 · Esquive +6	
272475	shoulder	4	2	3	60	55	Mantelet de qualité en pelombre	End +19 · PA +24 · Crit. +7	
272476	legs	4	2	3	60	55	Jambières de qualité en pelombre	Agi +15 · End +26 · Esquive +6	
272477	feet	4	4	3	60	55	Bottes de qualité en plaques cimentières	For +9 · Agi +8 · End +20	
272478	hands	4	4	3	60	55	Gants de qualité en plaques cimentières	For +10 · Agi +10 · End +19	
272479	chest	4	4	3	60	55	Armure de plaques cimentières de qualité	For +11 · End +25 · Crit. +14	
272480	head	4	4	3	60	55	Protège-front de qualité en plaques cimentières	For +16 · End +25 · Crit. +7	
272481	legs	4	4	3	60	55	Garde-jambes de qualité en plaques cimentières	For +15 · Agi +9 · End +25	
272483	wrist	4	3	3	60	55	Brassards de qualité en anneaux	End +15 · Int +7 · PA +8	
272484	feet	4	3	3	60	55	Brodequins de qualité en mailles	End +19 · Int +10 · Puiss. sorts +7 · Crit. +7	
272485	hands	4	3	3	60	55	Poignes de qualité rivetées	For +8 · End +19 · Int +8 · Puiss. sorts +8	
272486	head	4	3	3	60	55	Heaume de qualité en mailles	End +25 · Int +10 · Puiss. sorts +14 · Crit. +7	
272487	chest	4	3	3	60	55	Plastron de qualité en mailles	End +25 · Int +11 · Puiss. sorts +12 · Crit. +7	
272488	legs	4	3	3	60	55	Jambières de qualité rivetées	For +14 · End +25 · Int +8 · Esquive +6	
272489	shoulder	4	3	3	60	55	Épaulières de qualité rivetées	For +10 · End +19 · Int +6 · Puiss. sorts +7	
272490	chest	4	3	3	60	55	Cuirasse de qualité en anneaux	Agi +14 · End +19 · Int +8 · PA +14	
272492	legs	4	3	3	60	55	Jambières de qualité en anneaux	Agi +13 · End +19 · Int +9 · Esquive +6	
272494	waist	4	3	3	60	55	Ceinturon de qualité en anneaux	Agi +12 · End +19 · Int +7	
272495	hands	4	3	3	60	55	Gantelets de qualité en anneaux	Agi +8 · End +20 · Int +6 · PA +12	
272496	feet	4	3	3	60	55	Bottes de qualité en anneaux	Agi +11 · End +19 · Int +5 · PA +12	
272497	wrist	4	3	3	60	55	Garde-poignets de qualité rivetés	For +9 · End +14 · Int +5	
272498	head	4	1	4	65	60	Capuche de qualité de magus seigneur de guerre	End +37 · Int +15 · Puiss. sorts +14 · Crit. +14	
272499	legs	4	1	4	65	60	Chausses de qualité de magus général	End +34 · Int +17 · Puiss. sorts +18 · Crit. +7	
272500	chest	4	1	4	65	60	Grande tenue de qualité de magus seigneur de guerre	End +34 · Int +12 · Puiss. sorts +18 · Crit. +14	
272501	shoulder	4	1	4	65	60	Amict de qualité de magus général	End +26 · Int +17 · Puiss. sorts +12	
272502	waist	4	1	4	65	60	Écharpe de qualité de magus légionnaire	End +26 · Int +15 · Puiss. sorts +14	
272503	wrist	4	1	4	65	60	Crispins de qualité de magus légionnaire	End +20 · Int +10 · Puiss. sorts +12	
272504	feet	4	1	4	65	60	Bottes de qualité de magus centurion	End +26 · Int +15 · Puiss. sorts +14	
272505	hands	4	1	4	65	60	Garde-mains de qualité de magus champion	End +26 · Int +15 · Puiss. sorts +14	
272506	chest	4	4	4	65	60	Armure de plaques cimentières de qualité de seigneur de guerre	For +21 · End +34 · Crit. +14	
272507	head	4	4	4	65	60	Chapel de qualité de seigneur de guerre en plaques cimentières	For +18 · End +34 · Crit. +14 · Armure +70	
272508	legs	4	4	4	65	60	Jambières de qualité de général en plaques cimentières	For +21 · Agi +13 · End +34	
272509	shoulder	4	4	4	65	60	Épaulières de qualité de général en plaques cimentières	For +14 · End +26 · Crit. +14	
272510	feet	4	4	4	65	60	Bottes de qualité de centurion en plaques cimentières	For +13 · Agi +11 · End +28	
272511	wrist	4	4	4	65	60	Garde-bras de qualité de légionnaire en plaques cimentières	For +13 · End +21	
272512	waist	4	4	4	65	60	Ceinturon de qualité de légionnaire en plaques cimentières	For +17 · Agi +10 · End +26	
272513	hands	4	4	4	65	60	Gantelets de qualité de champion en plaques cimentières	For +14 · Agi +14 · End +26	
272514	chest	4	2	4	65	60	Haubert de qualité de seigneur de guerre en peau de dragon	For +12 · End +37 · Int +8 · Crit. +14	
272515	head	4	2	4	65	60	Casque de qualité de seigneur de guerre en peau de dragon	For +18 · Agi +9 · End +37 · Armure +50	
272516	shoulder	4	2	4	65	60	Épaulettes de qualité de général en peau de dragon	For +12 · Agi +8 · End +28 · Int +6 · Armure +40	
272517	legs	4	2	4	65	60	Jambières de qualité de général en peau de dragon	For +17 · Agi +11 · End +34 · Esquive +12	
272518	wrist	4	2	4	65	60	Brassards de qualité de légionnaire en peau de dragon	For +12 · Agi +7 · End +20	
272519	feet	4	2	4	65	60	Bottes de qualité de centurion en peau de dragon	For +14 · Agi +10 · End +26 · Int +8	
272520	hands	4	2	4	65	60	Gants de qualité de champion en peau de dragon	For +16 · Agi +10 · End +26 · Armure +40	
272521	waist	4	2	4	65	60	Ceinture de qualité de légionnaire en peau de dragon	For +14 · Agi +10 · End +26 · Int +8	
272522	waist	4	2	4	65	60	Ceinturon de qualité de légionnaire en pelombre	For +10 · Agi +17 · End +26	
272523	feet	4	2	4	65	60	Bottines de qualité de centurion en pelombre	Agi +20 · End +26 · Armure +40	
272524	wrist	4	2	4	65	60	Brachiales de qualité de légionnaire en pelombre	Agi +13 · End +21	
272525	hands	4	2	4	65	60	Mitaines de qualité de champion en pelombre	End +26 · PA +28 · Crit. +14	
272526	head	4	2	4	65	60	Heaume de qualité de seigneur de guerre en pelombre	End +37 · PA +16 · Crit. +14 · Esquive +12	
272527	shoulder	4	2	4	65	60	Spallières de qualité de général en pelombre	End +26 · PA +28 · Crit. +14	
272528	chest	4	2	4	65	60	Cuirasse de qualité de seigneur de guerre en pelombre	End +37 · PA +32 · Crit. +14	
272529	legs	4	2	4	65	60	Garde-jambes de qualité de général en pelombre	Agi +17 · End +37 · Esquive +12	
272530	chest	4	3	4	65	60	Plastron de qualité de seigneur de guerre en anneaux	Agi +18 · End +34 · Int +12 · PA +24	
272531	head	4	3	4	65	60	Casque de qualité de seigneur de guerre en anneaux	Agi +18 · End +34 · Int +12 · PA +24	
272532	legs	4	3	4	65	60	Garde-jambes de qualité de général en anneaux	Agi +17 · End +34 · Int +12 · Esquive +12	
272533	shoulder	4	3	4	65	60	Épaulières de qualité de général en anneaux	Agi +17 · End +26 · PA +18	
272534	feet	4	3	4	65	60	Solerets de qualité de centurion en anneaux	Agi +14 · End +26 · Int +7 · PA +18	
272535	wrist	4	3	4	65	60	Garde-poignets de qualité de légionnaire en anneaux	End +21 · Int +10 · PA +12	
272536	hands	4	3	4	65	60	Gants de qualité de champion en anneaux	Agi +10 · End +27 · Int +10 · PA +18	
272537	waist	4	3	4	65	60	Ceinturon de qualité de légionnaire en anneaux	Agi +17 · End +26 · Int +10	
272538	feet	4	3	4	65	60	Bottes de qualité de centurion rivetées	For +12 · End +27 · Int +7 · Puiss. sorts +11	
272539	hands	4	3	4	65	60	Gantelets de qualité de champion rivetés	For +11 · End +26 · Int +10 · Puiss. sorts +14	
272540	waist	4	3	4	65	60	Baudrier de qualité de légionnaire riveté	For +15 · End +26 · Int +12	
272541	wrist	4	3	4	65	60	Brassards de qualité de légionnaire rivetés	For +12 · End +20 · Int +7	
272542	chest	4	3	4	65	60	Cotte de mailles rivetées de seigneur de guerre	For +16 · End +34 · Int +11 · Crit. +14	
272543	head	4	3	4	65	60	Heaume de qualité de seigneur de guerre riveté	For +16 · End +34 · Int +11 · Crit. +14	
272544	legs	4	3	4	65	60	Jambières de qualité de général rivetées	For +18 · End +34 · Int +10 · Esquive +12	
272545	shoulder	4	3	4	65	60	Spallières de qualité de général rivetées	For +12 · End +26 · Int +8 · Puiss. sorts +14	
272548	chest	4	1	3	60	55	Robe de qualité en tisse-gangrène	End +25 · Int +9 · Puiss. sorts +18	
272549	shoulder	4	1	3	60	55	Épaulières de qualité en tisse-gangrène	End +19 · Int +12 · Puiss. sorts +9	
272550	waist	4	1	3	60	55	Ceinture de qualité en tisse-gangrène	End +19 · Int +13 · Puiss. sorts +7	
272551	wrist	4	1	3	60	55	Brassards de qualité en tisse-gangrène	End +15 · Int +6 · Puiss. sorts +7	
272552	feet	4	1	3	60	55	Bottes de qualité en tisse-gangrène	End +19 · Int +7 · Puiss. sorts +14	
272553	hands	4	1	3	60	55	Gants de qualité en tisse-gangrène	End +19 · Int +13 · Puiss. sorts +7	
272554	feet	4	1	4	65	60	Bottes de qualité de centurion en tisse-gangrène	End +26 · Int +12 · Puiss. sorts +18	
272555	wrist	4	1	4	65	60	Brassards de qualité de légionnaire en tisse-gangrène	End +20 · Int +10 · Puiss. sorts +12	
272556	hands	4	1	4	65	60	Gants de qualité de champion en tisse-gangrène	End +26 · Int +17 · Puiss. sorts +12	
272557	waist	4	1	4	65	60	Ceinture de qualité de légionnaire en tisse-gangrène	End +26 · Int +17 · Puiss. sorts +12	
272558	shoulder	4	1	4	65	60	Mantelet de qualité de général en tisse-gangrène	End +26 · Int +12 · Puiss. sorts +14 · Crit. +7	
272559	head	4	1	4	65	60	Chaperon de qualité de seigneur de guerre en tisse-gangrène	End +34 · Int +20 · Puiss. sorts +16 · Armure +40	
272560	chest	4	1	4	65	60	Robe de qualité de seigneur de guerre en tisse-gangrène	End +34 · Int +12 · Puiss. sorts +23 · Crit. +7	
272561	legs	4	1	4	65	60	Pantalon de qualité de général en tisse-gangrène	End +34 · Int +20 · Puiss. sorts +18	
272562	head	4	1	3	60	55	Capuche de qualité en satin	End +25 · Int +15 · Puiss. sorts +11	
272563	legs	4	1	3	60	55	Chausses de qualité en satin	End +25 · Int +13 · Puiss. sorts +14	
272564	chest	4	1	3	60	55	Habits de qualité en satin	End +26 · Int +11 · Puiss. sorts +14	
272565	shoulder	4	1	3	60	55	Protège-épaules de qualité en satin	End +19 · Int +12 · Puiss. sorts +11	
272566	waist	4	1	3	60	55	Écharpe de qualité en satin	End +19 · Int +13 · Puiss. sorts +7	
272567	wrist	4	1	3	60	55	Crispins de qualité en satin	End +15 · Int +6 · Puiss. sorts +7	
272568	feet	4	1	3	60	55	Bottes de qualité en satin	End +18 · Int +11 · Puiss. sorts +14	
272569	hands	4	1	3	60	55	Gants de qualité en satin	End +19 · Int +12 · Puiss. sorts +8	
272570	feet	4	1	4	65	60	Bottes de qualité de centurion en satin	End +26 · Int +13 · Puiss. sorts +19	
272571	wrist	4	1	4	65	60	Brassards de qualité de légionnaire en satin	End +20 · Int +10 · Puiss. sorts +12	
272572	hands	4	1	4	65	60	Gants de qualité de champion en satin	End +26 · Int +15 · Puiss. sorts +14	
272573	waist	4	1	4	65	60	Cordelière de qualité de légionnaire en satin	End +26 · Int +17 · Puiss. sorts +11	
272574	shoulder	4	1	4	65	60	Mantelet de qualité de général en satin	End +26 · Int +14 · Puiss. sorts +16	
272575	head	4	1	4	65	60	Capuche de qualité de seigneur de guerre en satin	End +34 · Int +17 · Puiss. sorts +19 · Crit. +7	
272576	chest	4	1	4	65	60	Robe de qualité de seigneur de guerre en satin	End +34 · Int +16 · Puiss. sorts +21 · Armure +40	
272577	legs	4	1	4	65	60	Jambières de qualité de général en satin	End +34 · Int +18 · Puiss. sorts +18 · Crit. +7	
272578	back	4	1	3	60	55	Cape de qualité de sergent	For +8 · Agi +8 · End +8 · Int +8 · Esp +8	
272579	wrist	4	4	3	60	55	Brassards de qualité en plaques cimentières	For +9 · End +15	
272580	wrist	4	4	3	50	45	Brassards d’adjudant en plaques	For +6 · End +14	
272581	wrist	4	3	3	50	45	Garde-poignets d’adjudant en mailles	End +14 · Int +6	
272582	wrist	4	2	3	60	55	Garde-bras de qualité en peau de dragon	For +7 · Agi +4 · End +15	
272589	back	4	1	3	60	55	Pèlerine de qualité de sergent	End +16 · Armure +67	
272591	off	4	6	4	65	60	Pavois de qualité de grand seigneur de guerre	For +9 · End +21	
272592	one	2	0	4	65	60	Fendoir de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272593	two	2	1	4	65	60	Hache de bataille de qualité de grand seigneur de guerre	For +23 · End +35 · Crit. +14	
272594	ranged	2	2	4	65	60	Arc à double courbure de qualité de grand seigneur de guerre	End +8 · PA +42	
272595	ranged	2	18	4	65	60	Arbalète de qualité de grand seigneur de guerre	End +8 · PA +42	
272596	one	2	15	4	65	60	Rasoir de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272597	main	2	13	4	65	60	Griffe droite de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272598	off	2	13	4	65	60	Griffe gauche de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272599	ranged	2	3	4	65	60	Balayeur de rue de qualité de grand seigneur de guerre	End +8 · PA +42	
272600	one	2	4	4	65	60	Gourdin de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272601	two	2	5	4	65	60	Pulvériseur de qualité de grand seigneur de guerre	For +23 · End +35 · Crit. +14	
272602	two	2	6	4	65	60	Aiguillon de qualité de grand seigneur de guerre	For +23 · End +35 · Crit. +14	
272603	two	2	10	4	65	60	Bâton de guerre de qualité de grand seigneur de guerre	End +36 · Int +20	
272604	two	2	8	4	65	60	Grande épée de qualité de grand seigneur de guerre	For +23 · End +35 · Crit. +14	
272606	feet	4	2	3	60	55	Bottines de qualité en cuir de kodo	End +19 · Int +12 · Esp +4 · Dégâts sorts +4 · Soins +11	
272608	feet	4	2	3	60	55	Brodequins de qualité en pelombre	Agi +14 · End +19 · Armure +30	
272609	feet	4	3	3	60	55	Grèves de qualité rivetées	For +8 · End +20 · Int +5 · Puiss. sorts +7	
272611	feet	4	1	3	60	55	Brodequins de qualité soyeux	End +19 · Int +10 · Esp +10 · Dégâts sorts +5 · Soins +15	
272614	hands	4	2	3	60	55	Poignes de qualité en peau de dragon	For +10 · Agi +6 · End +20	
272617	hands	4	3	3	60	55	Cestes de qualité en mailles	End +19 · Int +10 · Puiss. sorts +12	
272619	hands	4	1	3	60	55	Protège-mains de qualité soyeux	End +20 · Int +9 · Dégâts sorts +6 · Soins +18	
272625	chest	4	3	3	60	55	Haubert de qualité riveté	For +11 · End +25 · Int +6 · Crit. +7	
272626	chest	4	2	3	60	55	Plastron de qualité en cuir de kodo	End +26 · Int +9 · Esp +7 · Dégâts sorts +11 · Soins +33	
272627	legs	4	2	3	60	55	Jambières de qualité en cuir de kodo	End +26 · Int +12 · Esp +4 · Dégâts sorts +7 · Soins +20	
272630	legs	4	1	3	60	55	Garde-jambes de qualité en tisse-gangrène	End +25 · Int +14 · Puiss. sorts +12	
272634	chest	4	1	3	60	55	Tunique de qualité soyeuse	End +25 · Int +10 · Esp +6 · Dégâts sorts +9 · Soins +26	
272636	legs	4	3	3	60	55	Garde-jambes de qualité en mailles	End +25 · Int +8 · Puiss. sorts +14 · Crit. +7	
272637	shoulder	4	4	3	60	55	Épaulières de qualité en plaques cimentières	For +12 · End +19 · Crit. +7	
272640	shoulder	4	3	3	60	55	Épaulières de qualité en anneaux	Agi +13 · End +19 · PA +12	
272641	head	4	2	3	60	55	Protège-front de qualité en cuir de kodo	End +26 · Int +9 · Esp +6 · Dégâts sorts +8 · Soins +24	
272642	shoulder	4	2	3	60	55	Épaulières de qualité en cuir de kodo	End +20 · Int +8 · Esp +4 · Dégâts sorts +5 · Soins +15	
272643	head	4	1	3	60	55	Capuche de qualité en tisse-gangrène	End +26 · Int +13 · Puiss. sorts +11	
272647	head	4	3	3	60	55	Protège-front de qualité riveté	For +11 · End +26 · Int +6 · Crit. +7	
272648	shoulder	4	3	3	60	55	Espauliers de qualité en mailles	End +20 · Int +9 · Puiss. sorts +9	
272649	head	4	1	3	60	55	Chaperon de qualité soyeux	End +25 · Int +10 · Esp +10 · Dégâts sorts +7 · Soins +20	
272650	shoulder	4	1	3	60	55	Mantelet de qualité soyeux	End +19 · Int +8 · Esp +8 · Dégâts sorts +5 · Soins +15	
272656	legs	4	2	3	60	55	Jambières de qualité en peau lunaire	End +26 · Int +11 · Puiss. sorts +9 · Crit. +7	
272657	legs	4	1	3	60	55	Garde-jambes de qualité en tisse-effroi	End +25 · Int +14 · Puiss. sorts +12	
272663	legs	4	1	3	60	55	Garde-jambes de qualité soyeux	End +25 · Int +14 · Dégâts sorts +8 · Soins +24	
272669	head	4	2	3	60	55	Protège-front de qualité en peau lunaire	End +26 · Int +14 · Puiss. sorts +9	
272670	shoulder	4	2	3	60	55	Épaulières de qualité en peau lunaire	End +20 · Int +8 · Puiss. sorts +7 · Armure +50	
272671	head	4	1	3	60	55	Capuche de qualité en tisse-effroi	End +26 · Int +13 · Puiss. sorts +11	
272677	head	4	1	3	60	55	Chaperon de qualité en étoffe lunaire	End +25 · Int +10 · Esp +10 · Dégâts sorts +7 · Soins +20	
272678	shoulder	4	1	3	60	55	Mantelet de qualité en étoffe lunaire	End +19 · Int +8 · Esp +8 · Dégâts sorts +5 · Soins +15	
272680	shoulder	4	1	3	60	55	Mantelet de qualité de magus	End +20 · Int +10 · Puiss. sorts +7	
272681	main	2	4	4	65	60	Masse d’armes de qualité de grand seigneur de guerre	End +12 · Int +7 · Mana/5 +5	
272682	two	2	5	4	65	60	Destructeur de qualité de grand seigneur de guerre	For +15 · End +25 · Int +24 · Puiss. sorts +24	
272683	main	2	15	4	65	60	Sorcelame de qualité de grand seigneur de guerre	End +8 · Int +7 · Crit. +14	
272684	one	2	7	4	65	60	Prestelame de qualité de grand seigneur de guerre	End +2 · PA +24 · Crit. +14	
272685	off	4	0	4	65	60	Tome de destruction de qualité de grand seigneur de guerre	End +15 · Int +14 · Puiss. sorts +18	
272686	off	4	0	4	65	60	Tome de guérison de qualité de grand seigneur de guerre	End +13 · Int +13 · Esp +13 · Dégâts sorts +9 · Soins +28	
272693	one	2	7	4	65	60	Épée longue de qualité de connétable	End +2 · PA +24 · Crit. +14	
272698	back	4	1	3	60	55	Cape de qualité de sergent	For +8 · Agi +8 · End +8 · Int +8 · Esp +8	
272699	back	4	1	3	60	55	Pèlerine de qualité de sergent	End +16 · Armure +67	
272700	waist	4	1	3	60	55	Écharpe de qualité en soie	End +20 · Int +10 · Puiss. sorts +8	
272701	feet	4	1	3	60	55	Bottes de qualité en soie	End +19 · Int +12 · Puiss. sorts +9	
272702	wrist	4	1	3	60	55	Crispins de qualité en soie	End +15 · Int +6 · Puiss. sorts +7	
272703	hands	4	1	3	60	55	Gants de qualité en soie	End +19 · Int +10 · Puiss. sorts +12	
272704	feet	4	2	3	60	55	Bottes de qualité en cuir	Agi +14 · End +19 · Armure +30	
272705	feet	4	2	3	60	55	Bottillons de qualité en peau de bête	For +12 · Agi +6 · End +19 · Int +4	
272706	wrist	4	2	3	60	55	Brassards de qualité en cuir	Agi +9 · End +15	
272707	wrist	4	2	3	60	55	Brachiales de qualité en peau de bête	For +7 · Agi +4 · End +15	
272708	hands	4	2	3	60	55	Gantelets de qualité en cuir	End +19 · PA +24 · Crit. +7	
272709	hands	4	2	3	60	55	Gants de qualité en peau de bête	For +10 · Agi +6 · End +20	
272710	waist	4	2	3	60	55	Ceinture de qualité en cuir	For +7 · Agi +12 · End +19	
272711	waist	4	2	3	60	55	Ceinturon de qualité en peau de bête	For +11 · Agi +6 · End +19 · Int +5	
272712	waist	4	3	3	60	55	Ceinturon de qualité en mailles	Agi +12 · End +19 · Int +7	
272713	feet	4	3	3	60	55	Bottes de qualité en mailles	Agi +11 · End +19 · Int +5 · PA +12	
272715	hands	4	3	3	60	55	Gantelets de qualité en mailles	Agi +8 · End +20 · Int +6 · PA +12	
272716	feet	4	4	3	60	55	Bottes de qualité en plaques	For +9 · Agi +8 · End +20	
272717	hands	4	4	3	60	55	Gantelets de qualité en plaques	For +10 · Agi +10 · End +19	
272718	feet	4	4	3	60	55	Solerets de qualité de chevalerie	For +10 · End +19 · Int +7 · Puiss. sorts +7	
272719	hands	4	4	3	60	55	Gantelets de qualité de chevalerie	For +11 · End +19 · Int +5 · Puiss. sorts +7	
272720	waist	4	4	3	60	55	Cordelière de qualité de chevalerie	For +12 · End +19 · Int +7	
272721	wrist	4	4	3	60	55	Brachiales de qualité de chevalerie	For +9 · End +14 · Int +5	
272722	chest	4	1	3	60	55	Grande tenue de qualité en soie	End +25 · Int +10 · Puiss. sorts +14 · Crit. +7	
272723	legs	4	1	3	60	55	Jambières de qualité en soie	End +26 · Int +11 · Puiss. sorts +14	
272724	shoulder	4	1	3	60	55	Spallières de qualité en soie	End +20 · Int +10 · Puiss. sorts +7	
272725	head	4	1	3	60	55	Couronne de qualité en soie	End +25 · Int +12 · Puiss. sorts +11 · Crit. +7	
272726	chest	4	2	3	60	55	Armure de qualité en cuir	End +26 · PA +16 · Crit. +14	
272727	head	4	2	3	60	55	Voile de qualité en cuir	End +25 · PA +14 · Crit. +14 · Esquive +6	
272728	legs	4	2	3	60	55	Garde-jambes de qualité en cuir	Agi +15 · End +26 · Esquive +6	
272729	shoulder	4	2	3	60	55	Spallières de qualité en cuir	End +19 · PA +24 · Crit. +7	
272730	chest	4	2	3	60	55	Tunique de qualité en peau de bête	For +11 · End +26 · Int +7 · Crit. +7	
272731	legs	4	2	3	60	55	Jambières de qualité en peau de bête	For +12 · Agi +5 · End +26 · Esquive +6	
272732	shoulder	4	2	3	60	55	Épaulettes de qualité en peau de bête	For +10 · Agi +5 · End +20 · Int +4	
272733	head	4	2	3	60	55	Voile de qualité en peau de bête	For +14 · Agi +7 · End +26 · Armure +30	
272734	chest	4	3	3	60	55	Haubert de qualité en mailles	Agi +14 · End +19 · Int +8 · PA +14	
272735	legs	4	3	3	60	55	Jambières de qualité en mailles	Agi +13 · End +19 · Int +9 · Esquive +6	
272736	shoulder	4	3	3	60	55	Espauliers de qualité en mailles	Agi +13 · End +19 · PA +12	
272737	head	4	3	3	60	55	Casque de qualité en mailles	Agi +10 · End +19 · Int +7 · PA +12	
272738	head	4	4	3	60	55	Heaume de qualité en plaques	For +16 · End +25 · Crit. +7	
272739	chest	4	4	3	60	55	Corselet de qualité en plaques	For +11 · End +25 · Crit. +14	
272740	legs	4	4	3	60	55	Jambières de qualité en plaques	For +15 · Agi +9 · End +25	
272741	shoulder	4	4	3	60	55	Espauliers de qualité en plaques	For +12 · End +19 · Crit. +7	
272742	chest	4	4	3	60	55	Cuirasse de qualité de chevalerie	For +11 · End +25 · Int +11 · Crit. +7	
272743	head	4	4	3	60	55	Protège-front de qualité de chevalerie	For +11 · End +25 · Int +7 · Puiss. sorts +7 · Crit. +7	
272744	legs	4	4	3	60	55	Jambières de qualité de chevalerie	For +13 · End +25 · Puiss. sorts +7 · Crit. +7	
272745	shoulder	4	4	3	60	55	Épaulières de qualité de chevalerie	For +11 · End +19 · Int +5 · Puiss. sorts +7	
272746	feet	4	1	4	65	60	Bottillons de qualité de chevalier-champion en soie	End +26 · Int +15 · Puiss. sorts +14	
272747	wrist	4	1	4	65	60	Brassards de qualité de chevalier-capitaine en soie	End +20 · Int +10 · Puiss. sorts +12	
272748	waist	4	1	4	65	60	Écharpe de qualité de chevalier-capitaine en soie	End +26 · Int +15 · Puiss. sorts +14	
272749	hands	4	1	4	65	60	Gants de qualité de lieutenant-commandant en soie	End +26 · Int +15 · Puiss. sorts +14	
272750	head	4	1	4	65	60	Cerclet de qualité de grand maréchal en soie	End +37 · Int +15 · Puiss. sorts +14 · Crit. +14	
272751	legs	4	1	4	65	60	Jambières de qualité de maréchal en soie	End +34 · Int +17 · Puiss. sorts +18 · Crit. +7	
272752	chest	4	1	4	65	60	Habit de qualité de grand maréchal en soie	End +34 · Int +12 · Puiss. sorts +18 · Crit. +14	
272753	shoulder	4	1	4	65	60	Spallières de qualité de maréchal en soie	End +26 · Int +17 · Puiss. sorts +12	
272754	wrist	4	2	4	65	60	Brassards de qualité de chevalier-capitaine en peau de bête	For +12 · Agi +7 · End +20	
272755	feet	4	2	4	65	60	Protège-tibias de qualité de chevalier-champion en cuir	Agi +20 · End +26 · Armure +40	
272756	waist	4	2	4	65	60	Sangle de qualité de chevalier-capitaine en peau de bête	For +14 · Agi +10 · End +26 · Int +8	
272757	hands	4	2	4	65	60	Gantelets de qualité de lieutenant-commandant en peau de bête	For +16 · Agi +10 · End +26 · Armure +40	
272758	shoulder	4	2	4	65	60	Spallières de qualité de maréchal en peau de bête	For +12 · Agi +8 · End +28 · Int +6 · Armure +40	
272759	legs	4	2	4	65	60	Garde-jambes de qualité de maréchal en peau de bête	For +17 · Agi +11 · End +34 · Esquive +12	
272760	head	4	2	4	65	60	Casque de qualité de grand maréchal en peau de bête	For +18 · Agi +9 · End +37 · Armure +50	
272761	chest	4	2	4	65	60	Cuirasse de qualité de grand maréchal en peau de bête	For +12 · End +37 · Int +8 · Crit. +14	
272762	chest	4	2	4	65	60	Plastron de qualité de grand maréchal en cuir	End +37 · PA +32 · Crit. +14	
272763	hands	4	2	4	65	60	Manicles de qualité de lieutenant-commandant en cuir	End +26 · PA +28 · Crit. +14	
272764	head	4	2	4	65	60	Masque de qualité de grand maréchal en cuir	End +37 · PA +16 · Crit. +14 · Esquive +12	
272765	legs	4	2	4	65	60	Jambières de qualité de maréchal en cuir	Agi +17 · End +37 · Esquive +12	
272766	shoulder	4	2	4	65	60	Épaulettes de qualité de maréchal en cuir	End +26 · PA +28 · Crit. +14	
272767	waist	4	2	4	65	60	Cordelière de qualité de chevalier-capitaine en cuir	For +10 · Agi +17 · End +26	
272768	feet	4	2	4	65	60	Bottes de qualité de chevalier-champion en peau de bête	For +14 · Agi +10 · End +26 · Int +8	
272769	wrist	4	2	4	65	60	Brachiales de qualité de chevalier-capitaine en cuir	Agi +13 · End +21	
272770	wrist	4	3	4	65	60	Brassards de qualité de chevalier-capitaine en mailles	End +21 · Int +10 · PA +12	
272771	feet	4	3	4	65	60	Bottes de qualité de chevalier-champion en mailles	Agi +14 · End +26 · Int +7 · PA +18	
272772	hands	4	3	4	65	60	Poignes de qualité de lieutenant-commandant en mailles	Agi +10 · End +27 · Int +10 · PA +18	
272773	waist	4	3	4	65	60	Ceinturon de qualité de chevalier-capitaine en mailles	Agi +17 · End +26 · Int +10	
272774	head	4	3	4	65	60	Heaume de qualité de grand maréchal en mailles	Agi +18 · End +34 · Int +12 · PA +24	
272775	chest	4	3	4	65	60	Cuirasse de qualité de grand maréchal en mailles	Agi +18 · End +34 · Int +12 · PA +24	
272776	legs	4	3	4	65	60	Garde-jambes de qualité de maréchal en mailles	Agi +17 · End +34 · Int +12 · Esquive +12	
272777	shoulder	4	3	4	65	60	Spallières de qualité de maréchal en mailles	Agi +17 · End +26 · PA +18	
272778	wrist	4	4	4	65	60	Garde-bras de qualité de chevalier-capitaine de chevalerie	For +12 · End +20 · Int +7	
272779	waist	4	4	4	65	60	Ceinture de qualité de chevalier-capitaine de chevalerie	For +17 · End +26 · Int +10	
272780	hands	4	4	4	65	60	Gants de qualité de lieutenant-commandant de chevalerie	For +13 · End +26 · Int +7 · Puiss. sorts +7 · Crit. +7	
272781	feet	4	4	4	65	60	Bottes de qualité de chevalier-champion de chevalerie	For +12 · End +26 · Int +8 · Puiss. sorts +14	
272782	chest	4	4	4	65	60	Pansière de qualité de grand maréchal de chevalerie	For +15 · End +34 · Int +12 · Crit. +14	
272783	head	4	4	4	65	60	Ventaille de qualité de grand maréchal de chevalerie	For +12 · End +34 · Int +8 · Puiss. sorts +14 · Crit. +14	
272784	legs	4	4	4	65	60	Cuissards de qualité de maréchal de chevalerie	For +15 · End +34 · Puiss. sorts +14 · Crit. +14	
272785	shoulder	4	4	4	65	60	Espauliers de qualité de maréchal de chevalerie	For +12 · End +26 · Int +8 · Puiss. sorts +14	
272786	chest	4	4	4	65	60	Armure de plaques de qualité de grand maréchal	For +21 · End +34 · Crit. +14	
272787	head	4	4	4	65	60	Casque de qualité de grand maréchal en plaques	For +18 · End +34 · Crit. +14 · Armure +70	
272788	legs	4	4	4	65	60	Jambières de qualité de maréchal en plaques	For +21 · Agi +13 · End +34	
272789	shoulder	4	4	4	65	60	Garde-épaules de qualité de maréchal en plaques	For +14 · End +26 · Crit. +14	
272790	wrist	4	4	4	65	60	Brassards de qualité de chevalier-capitaine en plaques	For +13 · End +21	
272791	waist	4	4	4	65	60	Ceinturon de qualité de chevalier-capitaine en plaques	For +17 · Agi +10 · End +26	
272792	feet	4	4	4	65	60	Bottes de qualité de chevalier-champion en plaques	For +13 · Agi +11 · End +28	
272793	hands	4	4	4	65	60	Gantelets de qualité de lieutenant-commandant en plaques	For +14 · Agi +14 · End +26	
272794	feet	4	1	3	60	55	Bottes de qualité en tisse-effroi	End +19 · Int +7 · Puiss. sorts +14	
272795	wrist	4	1	3	60	55	Brassards de qualité en tisse-effroi	End +15 · Int +6 · Puiss. sorts +7	
272796	hands	4	1	3	60	55	Gants de qualité en tisse-effroi	End +19 · Int +13 · Puiss. sorts +7	
272797	waist	4	1	3	60	55	Ceinture de qualité en tisse-effroi	End +19 · Int +13 · Puiss. sorts +7	
272800	chest	4	1	3	60	55	Robe de qualité en tisse-effroi	End +25 · Int +9 · Puiss. sorts +18	
272801	shoulder	4	1	3	60	55	Mantelet de qualité en tisse-effroi	End +19 · Int +12 · Puiss. sorts +9	
272802	head	4	1	4	65	60	Couronne de qualité de grand maréchal en tisse-effroi	End +34 · Int +20 · Puiss. sorts +16 · Armure +40	
272803	legs	4	1	4	65	60	Jambières de qualité de maréchal en tisse-effroi	End +34 · Int +20 · Puiss. sorts +18	
272804	shoulder	4	1	4	65	60	Épaulières de qualité de maréchal en tisse-effroi	End +26 · Int +12 · Puiss. sorts +14 · Crit. +7	
272805	chest	4	1	4	65	60	Robe de qualité de grand maréchal en tisse-effroi	End +34 · Int +12 · Puiss. sorts +23 · Crit. +7	
272806	wrist	4	1	4	65	60	Crispins de qualité de chevalier-capitaine en tisse-effroi	End +20 · Int +10 · Puiss. sorts +12	
272807	feet	4	1	4	65	60	Bottes de qualité de chevalier-champion en tisse-effroi	End +26 · Int +12 · Puiss. sorts +18	
272808	hands	4	1	4	65	60	Gants de qualité de lieutenant-commandant en tisse-effroi	End +26 · Int +17 · Puiss. sorts +12	
272809	waist	4	1	4	65	60	Écharpe de qualité de chevalier-capitaine en tisse-effroi	End +26 · Int +17 · Puiss. sorts +12	
272810	feet	4	1	3	60	55	Bottes de qualité en étoffe du Vide	End +18 · Int +11 · Puiss. sorts +14	
272811	wrist	4	1	3	60	55	Crispins de qualité en étoffe du Vide	End +15 · Int +6 · Puiss. sorts +7	
272812	hands	4	1	3	60	55	Gants de qualité en étoffe du Vide	End +19 · Int +12 · Puiss. sorts +8	
272813	waist	4	1	3	60	55	Corde de qualité en étoffe du Vide	End +19 · Int +13 · Puiss. sorts +7	
272814	head	4	1	3	60	55	Diadème de qualité en étoffe du Vide	End +25 · Int +15 · Puiss. sorts +11	
272815	legs	4	1	3	60	55	Jambières de qualité en étoffe du Vide	End +25 · Int +13 · Puiss. sorts +14	
272816	chest	4	1	3	60	55	Robe de qualité en étoffe du Vide	End +26 · Int +11 · Puiss. sorts +14	
272817	shoulder	4	1	3	60	55	Amict de qualité en étoffe du Vide	End +19 · Int +12 · Puiss. sorts +11	
272818	head	4	1	4	65	60	Coiffure de qualité de grand maréchal en étoffe du Vide	End +34 · Int +17 · Puiss. sorts +19 · Crit. +7	
272819	legs	4	1	4	65	60	Pantalon de qualité de maréchal en étoffe du Vide	End +34 · Int +18 · Puiss. sorts +18 · Crit. +7	
272820	shoulder	4	1	4	65	60	Mantelet de qualité de maréchal en étoffe du Vide	End +26 · Int +14 · Puiss. sorts +16	
272821	chest	4	1	4	65	60	Habits de qualité de grand maréchal en étoffe du Vide	End +34 · Int +16 · Puiss. sorts +21 · Armure +40	
272822	wrist	4	1	4	65	60	Brassards de qualité de chevalier-capitaine en étoffe du Vide	End +20 · Int +10 · Puiss. sorts +12	
272823	feet	4	1	4	65	60	Sandales de qualité de chevalier-champion en étoffe du Vide	End +26 · Int +13 · Puiss. sorts +19	
272824	hands	4	1	4	65	60	Gants de qualité de lieutenant-commandant en étoffe du Vide	End +26 · Int +15 · Puiss. sorts +14	
272825	waist	4	1	4	65	60	Écharpe de qualité de chevalier-capitaine en étoffe du Vide	End +26 · Int +17 · Puiss. sorts +11	
272828	wrist	4	4	3	60	55	Garde-poignets de qualité en plaques	For +9 · End +15	
272830	wrist	4	3	3	60	55	Garde-bras de qualité en mailles	End +15 · Int +7 · PA +8	
272834	wrist	4	2	3	60	55	Brachiales de qualité en peau du Rêve	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
272835	wrist	4	2	3	60	55	Brachiales de qualité en peau lunaire	End +15 · Int +7 · Puiss. sorts +5	
272838	off	4	6	4	65	60	Égide de qualité de connétable	For +9 · End +21	
272839	one	2	0	4	65	60	Hache courte de qualité de connétable	End +2 · PA +24 · Crit. +14	
272840	two	2	1	4	65	60	Découpeuse de qualité de connétable	For +23 · End +35 · Crit. +14	
272841	ranged	2	2	4	65	60	Viseur de qualité de connétable	End +8 · PA +42	
272842	ranged	2	18	4	65	60	Arme à répétition de qualité de connétable	End +8 · PA +42	
272843	one	2	15	4	65	60	Miséricorde de qualité de connétable	End +2 · PA +24 · Crit. +14	
272844	main	2	13	4	65	60	Lame de qualité de connétable (main droite)	End +2 · PA +24 · Crit. +14	
272845	off	2	13	4	65	60	Lame de qualité de connétable (main gauche)	End +2 · PA +24 · Crit. +14	
272846	ranged	2	3	4	65	60	Canon à main de qualité de connétable	End +8 · PA +42	
272847	one	2	4	4	65	60	Punisseur de qualité de connétable	End +2 · PA +24 · Crit. +14	
272848	two	2	5	4	65	60	Marteau d’armes de qualité de connétable	For +23 · End +35 · Crit. +14	
272849	two	2	6	4	65	60	Couteau de brèche de qualité de connétable	For +23 · End +35 · Crit. +14	
272850	two	2	10	4	65	60	Bâton de qualité de connétable	End +36 · Int +20	
272851	two	2	8	4	65	60	Claymore de qualité de connétable	For +23 · End +35 · Crit. +14	
272852	chest	4	4	3	60	55	Cuirasse de qualité lumineuse	End +26 · Int +7 · Dégâts sorts +7 · Soins +22 · Mana/5 +4	
272853	legs	4	4	3	60	55	Jambières de qualité lumineuses	End +25 · Int +14 · Dégâts sorts +7 · Soins +22	
272854	head	4	4	3	60	55	Protège-front de qualité lumineux	End +25 · Int +9 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
272855	shoulder	4	4	3	60	55	Épaulières de qualité lumineuses	End +19 · Int +4 · Dégâts sorts +6 · Soins +18 · Mana/5 +4	
272856	main	2	15	4	65	60	Magelame de qualité de connétable	End +8 · Int +7 · Crit. +14	
272857	main	2	4	4	65	60	Marteau de guerre de qualité de connétable	End +12 · Int +7 · Mana/5 +5	
272858	two	2	5	4	65	60	Démolisseur de qualité de connétable	For +15 · End +25 · Int +24 · Puiss. sorts +24	
272859	one	2	7	4	65	60	Vivelame de qualité de connétable	End +2 · PA +24 · Crit. +14	
273324	waist	4	4	3	60	55	Ceinturon de qualité en plaques cimentières	For +12 · Agi +7 · End +19	
273325	waist	4	4	3	60	55	Ceinturon de qualité en plaques	For +12 · Agi +7 · End +19	
273327	wrist	4	4	4	65	60	Garde-bras de qualité de chevalier-capitaine lumineux	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273328	waist	4	4	4	65	60	Ceinture de qualité de chevalier-capitaine lumineuse	End +26 · Int +11 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
273329	hands	4	4	4	65	60	Gants de qualité de lieutenant-commandant lumineux	End +28 · Int +12 · Dégâts sorts +8 · Soins +26	
273330	feet	4	4	4	65	60	Bottes de qualité de chevalier-champion lumineuses	End +26 · Int +11 · Dégâts sorts +8 · Soins +26 · Mana/5 +4	
273331	chest	4	4	4	65	60	Pansière de qualité de grand maréchal lumineuse	End +33 · Int +13 · Dégâts sorts +11 · Soins +33 · Crit. +7	
273332	head	4	4	4	65	60	Ventaille de qualité de grand maréchal lumineuse	End +34 · Int +15 · Dégâts sorts +10 · Soins +29 · Mana/5 +5	
273333	legs	4	4	4	65	60	Cuissards de qualité de maréchal lumineux	End +34 · Int +18 · Dégâts sorts +11 · Soins +33 · Crit. +7	
273334	shoulder	4	4	4	65	60	Espauliers de qualité de maréchal lumineux	End +26 · Int +12 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
273336	feet	4	3	4	65	60	Bottes de qualité de centurion en mailles	End +26 · Int +10 · Puiss. sorts +11 · Crit. +14	
273337	hands	4	3	4	65	60	Gantelets de qualité de champion en mailles	End +26 · Int +14 · Puiss. sorts +16	
273338	waist	4	3	4	65	60	Baudrier de qualité de légionnaire en mailles	End +28 · Int +18 · Puiss. sorts +14	
273339	wrist	4	3	4	65	60	Brassards de qualité de légionnaire en mailles	End +20 · Int +10 · Puiss. sorts +12	
273340	chest	4	3	4	65	60	Cottes de mailles de qualité de seigneur de guerre	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
273341	head	4	3	4	65	60	Heaume de qualité de seigneur de guerre en mailles	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
273342	legs	4	3	4	65	60	Jambières de qualité de général en mailles	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
273343	shoulder	4	3	4	65	60	Spallières de qualité de général en mailles	End +28 · Int +12 · Puiss. sorts +14	
273344	feet	4	3	4	65	60	Bottes de qualité de centurion en mailles annelées	End +26 · Int +14 · Dégâts sorts +10 · Soins +31	
273345	hands	4	3	4	65	60	Gantelets de qualité de champion en mailles annelées	End +26 · Int +10 · Esp +11 · Dégâts sorts +8 · Soins +26	
273346	waist	4	3	4	65	60	Baudrier de qualité de légionnaire en mailles annelées	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
273347	wrist	4	3	4	65	60	Brassards de qualité de légionnaire en mailles annelées	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273348	chest	4	3	4	65	60	Armure de qualité de seigneur de guerre en mailles annelées	End +34 · Int +14 · Dégâts sorts +10 · Soins +31 · Crit. +14	
273349	head	4	3	4	65	60	Heaume de qualité de seigneur de guerre en mailles annelées	End +37 · Int +11 · Esp +10 · Dégâts sorts +11 · Soins +33	
273350	legs	4	3	4	65	60	Jambières de qualité de général en mailles annelées	End +34 · Int +14 · Dégâts sorts +10 · Soins +31 · Crit. +14	
273351	shoulder	4	3	4	65	60	Spallières de qualité de général en mailles annelées	End +26 · Int +13 · Esp +9 · Dégâts sorts +7 · Soins +22	
273352	waist	4	3	3	60	55	Ceinturon de qualité riveté	For +12 · End +19 · Int +8	
273353	wrist	4	3	3	60	55	Garde-poignets de qualité en mailles	End +15 · Int +6 · Puiss. sorts +7	
273355	feet	4	3	3	60	55	Brodequins de qualité en mailles annelées	End +19 · Int +10 · Dégâts sorts +7 · Soins +22	
273356	head	4	3	3	60	55	Heaume de qualité en mailles annelées	End +26 · Int +8 · Esp +8 · Dégâts sorts +7 · Soins +22	
273357	chest	4	3	3	60	55	Plastron de qualité en mailles annelées	End +25 · Int +11 · Dégâts sorts +7 · Soins +22 · Crit. +7	
273358	hands	4	3	3	60	55	Cestes de qualité en mailles annelées	End +19 · Int +7 · Esp +6 · Dégâts sorts +5 · Soins +15	
273359	legs	4	3	3	60	55	Garde-jambes de qualité en mailles annelées	End +25 · Int +11 · Dégâts sorts +7 · Soins +22 · Crit. +7	
273360	shoulder	4	3	3	60	55	Espauliers de qualité en mailles annelées	End +19 · Int +9 · Esp +6 · Dégâts sorts +5 · Soins +15	
273361	wrist	4	3	3	60	55	Garde-poignets de qualité en mailles annelées	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
273362	waist	4	3	3	60	55	Ceinturon de qualité en mailles annelées	End +19 · Int +8 · Esp +8 · Dégâts sorts +5 · Soins +15	
273363	hands	4	4	3	60	55	Gantelets de qualité lumineux	End +20 · Int +9 · Dégâts sorts +6 · Soins +18	
273364	wrist	4	4	3	60	55	Brachiales de qualité lumineuses	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
273365	feet	4	4	3	60	55	Solerets de qualité lumineux	End +19 · Int +10 · Dégâts sorts +7 · Soins +22	
273366	waist	4	4	3	60	55	Cordelière de qualité lumineuse	End +19 · Int +7 · Dégâts sorts +4 · Soins +13 · Mana/5 +4	
273367	waist	4	2	3	60	55	Baudrier de qualité en cuir de kodo	End +19 · Int +10 · Esp +8 · Dégâts sorts +4 · Soins +11	
273368	hands	4	2	3	60	55	Gants de qualité en peau lunaire	End +21 · Int +8 · Puiss. sorts +7	
273369	waist	4	2	3	60	55	Ceinturon de qualité en peau lunaire	End +20 · Int +10 · Puiss. sorts +7	
273370	feet	4	2	3	60	55	Bottillons de qualité en peau lunaire	End +20 · Int +10 · Puiss. sorts +7	
273371	chest	4	2	3	60	55	Tunique de qualité en peau lunaire	End +26 · Int +11 · Puiss. sorts +9 · Crit. +7	
273372	waist	4	3	3	60	55	Ceinturon de qualité en mailles	End +20 · Int +9 · Puiss. sorts +9	
273373	legs	4	2	3	60	55	Jambières de qualité en peau du Rêve	End +26 · Int +12 · Esp +4 · Dégâts sorts +7 · Soins +20	
273374	head	4	2	3	60	55	Protège-front de qualité en peau du Rêve	End +26 · Int +9 · Esp +6 · Dégâts sorts +8 · Soins +24	
273375	shoulder	4	2	3	60	55	Épaulières de qualité en peau du Rêve	End +20 · Int +8 · Esp +4 · Dégâts sorts +5 · Soins +15	
273377	hands	4	2	3	60	55	Gants de qualité en peau du Rêve	End +19 · Int +10 · Esp +7 · Dégâts sorts +4 · Soins +11	
273378	waist	4	2	3	60	55	Ceinturon de qualité en peau du Rêve	End +19 · Int +10 · Esp +8 · Dégâts sorts +4 · Soins +11	
273379	feet	4	2	3	60	55	Bottillons de qualité en peau du Rêve	End +19 · Int +12 · Esp +4 · Dégâts sorts +4 · Soins +11	
273380	chest	4	2	3	60	55	Tunique de qualité en peau du Rêve	End +26 · Int +9 · Esp +7 · Dégâts sorts +11 · Soins +33	
273381	wrist	4	2	3	60	55	Garde-bras de qualité en peau de wyrm	End +15 · Int +7 · Puiss. sorts +5	
273382	hands	4	2	3	60	55	Gantelets de qualité en peau de wyrm	End +21 · Int +8 · Puiss. sorts +7	
273383	feet	4	2	3	60	55	Bottines de qualité en peau de wyrm	End +20 · Int +10 · Puiss. sorts +7	
273384	chest	4	2	3	60	55	Plastron de qualité en peau de wyrm	End +26 · Int +11 · Puiss. sorts +9 · Crit. +7	
273385	legs	4	2	3	60	55	Jambières de qualité en peau de wyrm	End +26 · Int +11 · Puiss. sorts +9 · Crit. +7	
273386	head	4	2	3	60	55	Protège-front de qualité en peau de wyrm	End +26 · Int +14 · Puiss. sorts +9	
273387	shoulder	4	2	3	60	55	Épaulières de qualité en peau de wyrm	End +20 · Int +8 · Puiss. sorts +7 · Armure +50	
273388	waist	4	2	3	60	55	Baudrier de qualité en peau de wyrm	End +20 · Int +10 · Puiss. sorts +7	
273389	wrist	4	2	4	65	60	Brassards de qualité de chevalier-capitaine en peau lunaire	End +21 · Int +10 · Puiss. sorts +7	
273390	waist	4	2	4	65	60	Sangle de qualité de chevalier-capitaine en peau lunaire	End +28 · Int +14 · Puiss. sorts +11	
273391	hands	4	2	4	65	60	Gantelets de qualité de lieutenant-commandant en peau lunaire	End +28 · Int +14 · Puiss. sorts +11	
273392	shoulder	4	2	4	65	60	Spallières de qualité de maréchal en peau lunaire	End +28 · Int +11 · Puiss. sorts +11 · Armure +70	
273393	legs	4	2	4	65	60	Garde-jambes de qualité de maréchal en peau lunaire	End +34 · Int +15 · Puiss. sorts +14 · Crit. +14	
273394	head	4	2	4	65	60	Casque de qualité de grand maréchal en peau lunaire	End +37 · Int +18 · Puiss. sorts +13	
273395	chest	4	2	4	65	60	Cuirasse de qualité de grand maréchal en peau lunaire	End +34 · Int +15 · Puiss. sorts +14 · Crit. +14	
273396	feet	4	2	4	65	60	Bottes de qualité de chevalier-champion en peau lunaire	End +28 · Int +14 · Puiss. sorts +11	
273397	wrist	4	2	4	65	60	Brassards de qualité de chevalier-capitaine en peau du Rêve	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273398	waist	4	2	4	65	60	Sangle de qualité de chevalier-capitaine en peau du Rêve	End +26 · Int +12 · Esp +12 · Dégâts sorts +6 · Soins +18	
273399	hands	4	2	4	65	60	Gantelets de qualité de lieutenant-commandant en peau du Rêve	End +26 · Int +14 · Esp +8 · Dégâts sorts +7 · Soins +22	
273400	shoulder	4	2	4	65	60	Spallières de qualité de maréchal en peau du Rêve	End +28 · Int +10 · Esp +7 · Dégâts sorts +7 · Soins +22	
273401	legs	4	2	4	65	60	Garde-jambes de qualité de maréchal en peau du Rêve	End +37 · Int +14 · Esp +5 · Dégâts sorts +11 · Soins +33	
273402	head	4	2	4	65	60	Casque de qualité de grand maréchal en peau du Rêve	End +34 · Int +14 · Esp +13 · Dégâts sorts +11 · Soins +33	
273403	chest	4	2	4	65	60	Cuirasse de qualité de grand maréchal en peau du Rêve	End +34 · Int +12 · Esp +8 · Dégâts sorts +15 · Soins +44	
273404	feet	4	2	4	65	60	Bottes de qualité de chevalier-champion en peau du Rêve	End +26 · Int +14 · Esp +8 · Dégâts sorts +7 · Soins +22	
273405	chest	4	2	4	65	60	Haubert de qualité de seigneur de guerre en peau de wyrm	End +34 · Int +15 · Puiss. sorts +14 · Crit. +14	
273406	head	4	2	4	65	60	Casque de qualité de seigneur de guerre en peau de wyrm	End +37 · Int +18 · Puiss. sorts +13	
273407	shoulder	4	2	4	65	60	Épaulettes de qualité de général en peau de wyrm	End +28 · Int +11 · Puiss. sorts +11 · Armure +70	
273408	legs	4	2	4	65	60	Jambières de qualité de général en peau de wyrm	End +34 · Int +15 · Puiss. sorts +14 · Crit. +14	
273409	wrist	4	2	4	65	60	Brassards de qualité de légionnaire en peau de wyrm	End +21 · Int +10 · Puiss. sorts +7	
273410	feet	4	2	4	65	60	Bottes de qualité de centurion en peau de wyrm	End +28 · Int +14 · Puiss. sorts +11	
273411	hands	4	2	4	65	60	Gants de qualité de champion en peau de wyrm	End +28 · Int +14 · Puiss. sorts +11	
273412	waist	4	2	4	65	60	Ceinture de qualité de légionnaire en peau de wyrm	End +28 · Int +14 · Puiss. sorts +11	
273413	chest	4	2	4	65	60	Haubert de qualité de seigneur de guerre en cuir de kodo	End +34 · Int +12 · Esp +8 · Dégâts sorts +15 · Soins +44	
273414	head	4	2	4	65	60	Casque de qualité de seigneur de guerre en cuir de kodo	End +34 · Int +14 · Esp +13 · Dégâts sorts +11 · Soins +33	
273415	shoulder	4	2	4	65	60	Épaulettes de qualité de général en cuir de kodo	End +28 · Int +10 · Esp +7 · Dégâts sorts +7 · Soins +22	
273416	legs	4	2	4	65	60	Jambières de qualité de général en cuir de kodo	End +37 · Int +14 · Esp +5 · Dégâts sorts +11 · Soins +33	
273417	wrist	4	2	4	65	60	Brassards de qualité de légionnaire en cuir de kodo	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273418	feet	4	2	4	65	60	Bottes de qualité de centurion en cuir de kodo	End +26 · Int +14 · Esp +8 · Dégâts sorts +7 · Soins +22	
273419	hands	4	2	4	65	60	Gants de qualité de champion en cuir de kodo	End +26 · Int +14 · Esp +8 · Dégâts sorts +7 · Soins +22	
273420	waist	4	2	4	65	60	Ceinture de qualité de légionnaire en cuir de kodo	End +26 · Int +12 · Esp +12 · Dégâts sorts +6 · Soins +18	
273421	head	4	1	4	65	60	Coiffure de qualité de grand maréchal en étoffe lunaire	End +34 · Int +14 · Esp +13 · Dégâts sorts +11 · Soins +33	
273422	legs	4	1	4	65	60	Pantalon de qualité de maréchal en étoffe lunaire	End +34 · Int +17 · Esp +8 · Dégâts sorts +11 · Soins +33	
273423	shoulder	4	1	4	65	60	Mantelet de qualité de maréchal en étoffe lunaire	End +26 · Int +10 · Esp +10 · Dégâts sorts +9 · Soins +26	
273424	chest	4	1	4	65	60	Habits de qualité de grand maréchal en étoffe lunaire	End +34 · Int +14 · Esp +9 · Dégâts sorts +13 · Soins +40	
273425	wrist	4	1	4	65	60	Brassards de qualité de chevalier-capitaine en étoffe lunaire	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273426	feet	4	1	4	65	60	Sandales de qualité de chevalier-champion en étoffe lunaire	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
273427	hands	4	1	4	65	60	Gants de qualité de lieutenant-commandant en étoffe lunaire	End +28 · Int +12 · Dégâts sorts +9 · Soins +26	
273428	waist	4	1	4	65	60	Écharpe de qualité de chevalier-capitaine en étoffe lunaire	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
273429	feet	4	1	4	65	60	Bottes de qualité de centurion soyeuses	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
273430	wrist	4	1	4	65	60	Brassards de qualité de légionnaire soyeux	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
273431	hands	4	1	4	65	60	Gants de qualité de champion soyeux	End +28 · Int +12 · Dégâts sorts +9 · Soins +26	
273432	waist	4	1	4	65	60	Cordelière de qualité de légionnaire soyeuse	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
273433	shoulder	4	1	4	65	60	Mantelet de qualité de général soyeux	End +26 · Int +10 · Esp +10 · Dégâts sorts +9 · Soins +26	
273434	head	4	1	4	65	60	Capuche de qualité de seigneur de guerre soyeuse	End +34 · Int +14 · Esp +13 · Dégâts sorts +11 · Soins +33	
273435	chest	4	1	4	65	60	Robe de qualité de seigneur de guerre soyeuse	End +34 · Int +14 · Esp +9 · Dégâts sorts +13 · Soins +40	
273436	legs	4	1	4	65	60	Jambières soyeuses de qualité de général	End +34 · Int +17 · Esp +8 · Dégâts sorts +11 · Soins +33	
273443	feet	4	1	3	60	55	Bottes de qualité en étoffe lunaire	End +19 · Int +10 · Esp +10 · Dégâts sorts +5 · Soins +15	
273444	wrist	4	1	3	60	55	Crispins de qualité en étoffe lunaire	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
273445	hands	4	1	3	60	55	Gants de qualité en étoffe lunaire	End +20 · Int +9 · Dégâts sorts +6 · Soins +18	
273447	legs	4	1	3	60	55	Jambières de qualité en étoffe lunaire	End +25 · Int +14 · Dégâts sorts +8 · Soins +24	
273448	chest	4	1	3	60	55	Robe de qualité en étoffe lunaire	End +25 · Int +10 · Esp +6 · Dégâts sorts +9 · Soins +26	
273449	waist	4	1	3	60	55	Corde de qualité en étoffe lunaire	End +19 · Int +8 · Esp +8 · Dégâts sorts +6 · Soins +18	
273450	wrist	4	1	3	60	55	Crispins de qualité soyeux	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
273654	back	4	1	2	35	30	Cape au fil de cristal	End +4 · Armure +40	
273800	finger	4	0	2	58	0	Anneau de Thomas	Esp +9 · PA +20	
273875	feet	4	2	2	15	0	Bottines empyréennes	Int +3	
273876	hands	4	1	2	13	0	Gants de sectateur brisé	Esp +2	
273878	head	4	1	4	61	60	[DNT] Crafted Tier Piece Placeholder		
274021	head	4	5	3	1	1	Bandeau des Tarides		
274022	head	4	5	3	1	1	Couvre-œil de dur-à-cuire		
274023	head	4	5	3	1	1	Capuche de Bat-le-désert volée		
274024	head	4	5	3	1	1	Fédora flamboyant de Klaqueboulon		
274027	head	4	1	4	61	60	Placeholder		
274035	back	4	1	2	57	0	Drapé en peau de cerf	Agi +7 · End +7 · Esp +8	
274176	feet	4	3	3	60	55	Brodequins de qualité en écailles	End +19 · Int +10 · Puiss. sorts +7 · Crit. +7	
274177	hands	4	3	3	60	55	Poignes de qualité en mailles plates	For +8 · End +19 · Int +8 · Puiss. sorts +8	
274178	head	4	3	3	60	55	Heaume de qualité en écailles	End +25 · Int +10 · Puiss. sorts +14 · Crit. +7	
274179	chest	4	3	3	60	55	Plastron de qualité en écailles	End +24 · Int +11 · Puiss. sorts +12 · Crit. +7	
274180	legs	4	3	3	60	55	Jambières de qualité en mailles plates	For +14 · End +25 · Int +8 · Esquive +6	
274181	shoulder	4	3	3	60	55	Épaulières de qualité en mailles plates	For +10 · End +19 · Int +6 · Puiss. sorts +7	
274182	wrist	4	3	3	60	55	Garde-poignets de qualité en mailles plates	For +9 · End +14 · Int +5	
274183	feet	4	3	4	65	60	Bottes de qualité de chevalier-champion en mailles plates	For +12 · End +27 · Int +7 · Puiss. sorts +11	
274184	hands	4	3	4	65	60	Gantelets de qualité de lieutenant-commandant en mailles plates	For +11 · End +26 · Int +10 · Puiss. sorts +14	
274185	waist	4	3	4	65	60	Baudrier de qualité de chevalier-capitaine en mailles plates	For +15 · End +26 · Int +12	
274186	wrist	4	3	4	65	60	Brassards de qualité de chevalier-capitaine en mailles plates	For +12 · End +20 · Int +7	
274187	chest	4	3	4	65	60	Cotte de mailles plates de qualité de grand maréchal	For +16 · End +34 · Int +11 · Crit. +14	
274188	head	4	3	4	65	60	Heaume de qualité de grand maréchal en mailles plates	For +16 · End +34 · Int +11 · Crit. +14	
274189	legs	4	3	4	65	60	Jambières de qualité de maréchal en mailles plates	For +18 · End +34 · Int +10 · Esquive +12	
274190	shoulder	4	3	4	65	60	Spallières de qualité de maréchal en mailles plates	For +12 · End +26 · Int +8 · Puiss. sorts +14	
274192	feet	4	3	3	60	55	Grèves de qualité en mailles plates	For +8 · End +20 · Int +5 · Puiss. sorts +7	
274193	hands	4	3	3	60	55	Cestes de qualité en écailles	End +19 · Int +10 · Puiss. sorts +12	
274194	chest	4	3	3	60	55	Haubert de qualité en mailles plates	For +11 · End +25 · Int +6 · Crit. +7	
274195	legs	4	3	3	60	55	Garde-jambes de qualité en écailles	End +25 · Int +8 · Puiss. sorts +14 · Crit. +7	
274196	head	4	3	3	60	55	Protège-front de qualité en mailles plates	For +11 · End +26 · Int +6 · Crit. +7	
274197	shoulder	4	3	3	60	55	Espauliers de qualité en écailles	End +20 · Int +9 · Puiss. sorts +9	
274198	feet	4	3	4	65	60	Bottes de qualité de chevalier-champion en écailles	End +26 · Int +10 · Puiss. sorts +11 · Crit. +14	
274199	hands	4	3	4	65	60	Gantelets de qualité de lieutenant-commandant en écailles	End +26 · Int +14 · Puiss. sorts +16	
274200	waist	4	3	4	65	60	Baudrier de qualité de chevalier-capitaine en écailles	End +28 · Int +18 · Puiss. sorts +14	
274201	wrist	4	3	4	65	60	Brassards de qualité de chevalier-capitaine en écailles	End +20 · Int +10 · Puiss. sorts +12	
274202	chest	4	3	4	65	60	Cotte d’écailles de qualité de grand maréchal	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
274203	head	4	3	4	65	60	Heaume de qualité de grand maréchal en écailles	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
274204	legs	4	3	4	65	60	Jambières de qualité de maréchal en écailles	End +34 · Int +14 · Puiss. sorts +16 · Crit. +14	
274205	shoulder	4	3	4	65	60	Spallières de qualité de maréchal en écailles	End +28 · Int +12 · Puiss. sorts +14	
274206	feet	4	3	4	65	60	Bottes de qualité de chevalier-champion en mailles rivetées	End +26 · Int +14 · Dégâts sorts +10 · Soins +31	
274207	hands	4	3	4	65	60	Gantelets de qualité de lieutenant-commandant en mailles rivetées	End +26 · Int +10 · Esp +11 · Dégâts sorts +8 · Soins +26	
274208	waist	4	3	4	65	60	Baudrier de qualité de chevalier-capitaine en mailles rivetées	End +26 · Int +12 · Esp +11 · Dégâts sorts +7 · Soins +22	
274209	wrist	4	3	4	65	60	Brassards de qualité de chevalier-capitaine en mailles rivetées	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
274210	chest	4	3	4	65	60	Cotte de mailles rivetées de qualité de grand maréchal	End +34 · Int +14 · Dégâts sorts +10 · Soins +31 · Crit. +14	
274211	head	4	3	4	65	60	Heaume de qualité de grand maréchal en mailles rivetées	End +37 · Int +11 · Esp +10 · Dégâts sorts +11 · Soins +33	
274212	legs	4	3	4	65	60	Jambières de qualité de maréchal en mailles rivetées	End +34 · Int +14 · Dégâts sorts +10 · Soins +31 · Crit. +14	
274213	shoulder	4	3	4	65	60	Spallières de qualité de maréchal en mailles rivetées	End +26 · Int +13 · Esp +9 · Dégâts sorts +7 · Soins +22	
274214	waist	4	3	3	60	55	Ceinturon de qualité en mailles plates	For +12 · End +19 · Int +8	
274215	wrist	4	3	3	60	55	Garde-poignets de qualité en écailles	End +15 · Int +6 · Puiss. sorts +7	
274217	feet	4	3	3	60	55	Brodequins de qualité en mailles rivetées	End +19 · Int +10 · Dégâts sorts +7 · Soins +22	
274218	head	4	3	3	60	55	Heaume de qualité en mailles rivetées	End +26 · Int +8 · Esp +8 · Dégâts sorts +7 · Soins +22	
274219	chest	4	3	3	60	55	Plastron de qualité en mailles rivetées	End +25 · Int +11 · Dégâts sorts +7 · Soins +22 · Crit. +7	
274220	hands	4	3	3	60	55	Cestes de qualité en mailles rivetées	End +19 · Int +7 · Esp +6 · Dégâts sorts +5 · Soins +15	
274221	legs	4	3	3	60	55	Garde-jambes de qualité en mailles rivetées	End +25 · Int +11 · Dégâts sorts +7 · Soins +22 · Crit. +7	
274222	shoulder	4	3	3	60	55	Espauliers de qualité en mailles rivetées	End +19 · Int +9 · Esp +6 · Dégâts sorts +5 · Soins +15	
274223	wrist	4	3	3	60	55	Garde-poignets de qualité en mailles rivetées	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
274224	waist	4	3	3	60	55	Ceinturon de qualité en mailles rivetées	End +19 · Int +8 · Esp +8 · Dégâts sorts +5 · Soins +15	
274225	waist	4	3	3	60	55	Ceinturon de qualité en écailles	End +20 · Int +9 · Puiss. sorts +9	
274226	feet	4	4	3	60	55	Solerets de qualité en écailles	For +10 · End +19 · Int +7 · Puiss. sorts +7	
274227	hands	4	4	3	60	55	Gantelets de qualité en écailles	For +11 · End +19 · Int +5 · Puiss. sorts +7	
274228	waist	4	4	3	60	55	Cordelière de qualité en écailles	For +12 · End +19 · Int +7	
274229	wrist	4	4	3	60	55	Brachiales de qualité en écailles	For +9 · End +14 · Int +5	
274230	chest	4	4	3	60	55	Cuirasse de qualité en écailles	For +11 · End +25 · Int +11 · Crit. +7	
274231	head	4	4	3	60	55	Protège-front de qualité en écailles	For +11 · End +25 · Int +7 · Puiss. sorts +7 · Crit. +7	
274232	legs	4	4	3	60	55	Jambières de qualité en écailles	For +13 · End +25 · Puiss. sorts +7 · Crit. +7	
274233	shoulder	4	4	3	60	55	Épaulières de qualité en écailles	For +11 · End +19 · Int +5 · Puiss. sorts +7	
274234	wrist	4	4	4	65	60	Garde-bras de qualité de légionnaire en écailles	For +12 · End +20 · Int +7	
274235	waist	4	4	4	65	60	Ceinture de qualité de légionnaire en écailles	For +17 · End +26 · Int +10	
274236	hands	4	4	4	65	60	Gants de qualité de champion en écailles	For +13 · End +26 · Int +7 · Puiss. sorts +7 · Crit. +7	
274237	feet	4	4	4	65	60	Bottes de qualité de centurion en écailles	For +12 · End +26 · Int +8 · Puiss. sorts +14	
274238	chest	4	4	4	65	60	Pansière de qualité de seigneur de guerre en écailles	For +15 · End +34 · Int +12 · Crit. +14	
274239	head	4	4	4	65	60	Ventaille de qualité de seigneur de guerre en écailles	For +12 · End +34 · Int +8 · Puiss. sorts +14 · Crit. +14	
274240	legs	4	4	4	65	60	Cuissards de qualité de général en écailles	For +15 · End +34 · Puiss. sorts +14 · Crit. +14	
274241	shoulder	4	4	4	65	60	Espauliers de qualité de général en écailles	For +12 · End +26 · Int +8 · Puiss. sorts +14	
274244	chest	4	4	3	60	55	Cuirasse de qualité lamellaire	End +26 · Int +7 · Dégâts sorts +7 · Soins +22 · Mana/5 +4	
274245	legs	4	4	3	60	55	Jambières de qualité lamellaires	End +25 · Int +14 · Dégâts sorts +7 · Soins +22	
274246	head	4	4	3	60	55	Protège-front de qualité lamellaire	End +25 · Int +9 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
274247	shoulder	4	4	3	60	55	Épaulières de qualité lamellaires	End +19 · Int +4 · Dégâts sorts +6 · Soins +18 · Mana/5 +4	
274248	wrist	4	4	4	65	60	Garde-bras de qualité de légionnaire lamellaires	End +20 · Int +12 · Dégâts sorts +6 · Soins +18	
274249	waist	4	4	4	65	60	Ceinture de qualité de légionnaire lamellaire	End +26 · Int +11 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
274250	hands	4	4	4	65	60	Gants de qualité de champion lamellaires	End +28 · Int +12 · Dégâts sorts +8 · Soins +26	
274251	feet	4	4	4	65	60	Bottes de qualité de centurion lamellaires	End +26 · Int +11 · Dégâts sorts +8 · Soins +26 · Mana/5 +4	
274252	chest	4	4	4	65	60	Pansière lamellaire de qualité de seigneur de guerre	End +33 · Int +13 · Dégâts sorts +11 · Soins +33 · Crit. +7	
274253	head	4	4	4	65	60	Ventaille lamellaire de qualité de seigneur de guerre	End +34 · Int +15 · Dégâts sorts +10 · Soins +29 · Mana/5 +5	
274254	legs	4	4	4	65	60	Jambières lamellaires de qualité de général	End +34 · Int +18 · Dégâts sorts +11 · Soins +33 · Crit. +7	
274255	shoulder	4	4	4	65	60	Espauliers de qualité de général lamellaires	End +26 · Int +12 · Dégâts sorts +8 · Soins +24 · Mana/5 +4	
274256	hands	4	4	3	60	55	Gantelets de qualité lamellaires	End +20 · Int +9 · Dégâts sorts +6 · Soins +18	
274257	wrist	4	4	3	60	55	Brachiales de qualité lamellaires	End +14 · Int +9 · Dégâts sorts +4 · Soins +11	
274258	feet	4	4	3	60	55	Solerets de qualité lamellaires	End +19 · Int +10 · Dégâts sorts +7 · Soins +22	
274259	waist	4	4	3	60	55	Cordelière de qualité lamellaire	End +19 · Int +7 · Dégâts sorts +4 · Soins +13 · Mana/5 +4	
274383	one	2	15	2	58	0	Couteau de Kanai	Agi +9 · PA +10	
274384	neck	4	0	2	58	0	Plaques illisibles	End +5 · Int +4 · Puiss. sorts +13	
274386	trinket	4	0	2	58	0	Petit soldat		
274417	off	4	0	3	58	53	Colifichet peau-d’écorce	End +10 · Esp +10 · Dégâts sorts +7 · Soins +22	
274418	off	4	6	3	58	53	Barricade de terrier	End +15 · Armure +82	
274419	two	2	6	3	58	53	Aiguillon à ours	Agi +24 · End +9 · PA +27	
274420	two	2	10	3	58	53	Totem sage-patte	End +19 · Int +23	
274444	trinket	4	0	3	1	0	Insigne supérieur de la Horde		
274445	trinket	4	0	3	1	0	Insigne supérieur de l’Alliance		
274490	feet	4	2	2	40	35	Cache-sabots de centaure	Agi +4 · End +10	
274718	feet	4	4	2	58	0	Solerets de vétéran perdu	For +11 · End +14	
274719	feet	4	2	2	58	0	Chaussures oubliées	Agi +15 · Esp +9	
274720	feet	4	3	2	58	0	Bottes abandonnées	For +13 · Int +12	
274721	feet	4	1	2	58	0	Sandales en lambeaux	Int +14 · Dégâts sorts +8 · Soins +22	
274740	back	4	1	2	25	20	Cape capitonnée	Agi +3 · End +4	
274741	legs	4	1	2	25	20	Kilt fripé	End +7 · Puiss. sorts +5	
274742	wrist	4	2	2	25	20	Bandelettes de Cabestan	Agi +3 · Int +4	
274743	off	4	0	3	25	20	Samophlange défectueux	Int +5 · Esp +5	
274744	main	2	4	3	25	20	Écraseur des Tarides	For +2 · End +5	
274745	hands	4	3	2	35	30	Mitaines de récure-pont	For +2 · Agi +9	
274746	finger	4	0	2	35	30	Anneau d’orteil de géant des mers	Dégâts sorts +6 · Soins +18	
274747	feet	4	1	2	35	30	Bottes détrempées	Int +4 · Esp +8	
274748	ranged	2	3	3	35	30	Chevrotine de cogneur de Baie-du-Butin	End +4 · PA +12	
274749	neck	4	0	3	35	30	Coquillage souvenir	End +13	
274750	wrist	4	4	2	45	40	Garde-poignets réfléchissants	Int +8 · Dégâts sorts +3 · Soins +9	
274751	shoulder	4	2	2	45	40	Spallières d’insolation	Agi +11 · PA +12	
274752	back	4	1	2	45	40	Protection de tempête de sable	Esp +8 · Puiss. sorts +4	
274753	one	2	15	3	45	40	Tournevis égaré de Jhordy	For +6 · Agi +9 · Int +-1	
274754	finger	4	0	3	45	40	Pièce détachée suspecte	For +7 · End +11	
274755	hands	4	1	2	55	50	Poignes de Gentepression	Int +9 · Esp +14	
274756	head	4	2	2	55	50	Cache-oreilles peu pratique	Agi +13 · End +13 · Rés. givre +13	
274757	waist	4	3	2	55	50	Chaîne de ceinture médiocre	Agi +15 · PA +13	
274758	chest	4	4	2	55	50	Garde givremétal	For +19 · End +11	
274759	trinket	4	0	3	55	50	Sculpte-chemin de Long-Guet	Rés. nature +20	
274760	trinket	4	0	3	55	50	Robot de livraison de Long-Guet	Rés. givre +20	
274761	trinket	4	0	3	55	50	Bipeur de prêtre parachutiste	Rés. ombre +20	
274915	finger	4	0	2	38	0	Bague de sacristie	End +7 · Dégâts sorts +2 · Soins +6	
274916	feet	4	3	2	38	0	Grèves de bedeau	For +7 · Puiss. sorts +8	
274919	ranged	2	19	2	40	0	Baguette de néophyte		
274920	one	2	7	2	40	0	Découpeuse du Crépuscule	End +4 · PA +10	
274928	one	2	0	2	39	0	Couperet de Kurty	End +6 · Déf. +2	
274929	two	2	1	2	39	0	Hache d’abattage d’Hurley	For +7	
274938	chest	4	2	2	40	0	Tunique en peau de Gnoll	Agi +11 · Esp +11	
274939	legs	4	3	2	40	0	Jambières de la garde du Sud	For +13 · End +8	
274940	two	2	6	2	40	0	Bâton de combat déséquilibré	For +13 · End +8	
274941	chest	4	1	2	40	0	Robe de mystique des collines hirsutes	Int +11 · Puiss. sorts +12	
274942	chest	4	2	2	40	0	Gilet peau-hirsute	Agi +8 · End +12	
274943	legs	4	3	2	40	0	Jambières écrase-Gnoll	For +11 · Int +11	
274944	two	2	6	2	40	0	Frappeuse de flaire-sang	End +11 · PA +18	
274946	chest	4	1	2	40	0	Robe de sang de Gnoll	Esp +11 · Puiss. sorts +11	
274948	main	2	15	2	42	0	Bouteille du port de Poudremèche	Int +7	
274955	neck	4	0	2	42	0	Pierre cubique de Cognerok	For +7	
274957	hands	4	2	2	38	0	Convoyeurs à bois	For +11	
274961	finger	4	0	2	39	0	Bague de bruticide	Int +6	
274963	two	2	6	3	42	0	Harpon couvert de pourriture		
274968	neck	4	0	3	60	55	Insigne de qualité de sergent-chef	End +16 · Esp +7	
274969	neck	4	0	3	60	55	Insigne de qualité de sergent-chef	End +16 · Esp +7	
275028	head	4	1	2	45	0	Lueur de mine du Crépuscule	End +12 · Puiss. sorts +13	
275043	finger	4	0	3	45	0	Anneau de maître du sang	End +7 · Int +6 · Puiss. sorts +9	
275044	finger	4	0	3	45	0	Bague de combat à mort	End +6 · PA +22	
275045	finger	4	0	3	45	0	Anneau de corne ogre	For +4 · Agi +3 · End +10 · Déf. +3	
275046	back	4	1	2	46	0	Drapé de suzerain du Crépuscule	End +9 · Dégâts sorts +4 · Soins +11	
275049	off	4	6	2	46	0	Bastion de Fort-Lointain	For +9 · End +5	
275050	back	4	1	2	46	0	Cape de la secte	End +9 · Dégâts sorts +4 · Soins +11	
275051	off	4	6	2	46	0	Barrière du Crépuscule	For +9 · End +5	
275291	two	2	10	2	58	0	Bâton du Cri-Puissant	End +13 · Int +12 · Esp +14	
275293	main	2	4	2	58	0	Sceptre peau-d’écorce	Int +13	
275296	ranged	2	3	2	58	0	Espingole mort-bois	End +8 · PA +11	
275347	trinket	4	0	2	58	0	Lichemort	Rés. feu +4 · Rés. givre +4 · Rés. nature +4 · Rés. ombre +4 · Rés. arcanes +4	
275390	wrist	4	1	2	58	0	Manchettes superficielles	End +9 · Puiss. sorts +11	
275434	waist	4	3	2	58	0	Ceinturon de bourbe-né	End +10 · Int +10 · PA +18	
275437	waist	4	1	3	60	55	Écharpe de qualité soyeuse	End +19 · Int +8 · Esp +8 · Dégâts sorts +6 · Soins +18	
275438	feet	4	4	2	58	0	Grèves du deuil	For +13 · Dégâts sorts +9 · Soins +26	
275439	ranged	2	2	2	59	0	Arc en os de Bourdeflame		
275441	ranged	2	2	2	59	0	Arc long de crémation		
275604	hands	4	1	3	58	53	Gants de crache-venin	End +19 · Int +11 · Rés. nature +5	c197:1
275605	waist	4	1	3	58	53	Corde de crache-venin	End +17 · Int +14 · Rés. nature +6	c197:1
275606	feet	4	1	3	58	53	Souliers de crache-venin	Esp +8 · Puiss. sorts +22 · Rés. nature +8	c197:1
275607	hands	4	1	3	58	53	Gants de couve-colonie	Esp +20 · Dégâts sorts +5 · Soins +16 · Rés. nature +7	c197:1
275608	waist	4	1	3	58	53	Corde de couve-colonie	End +21 · Dégâts sorts +5 · Soins +16 · Rés. nature +4	c197:1
275609	feet	4	1	3	58	53	Souliers de couve-colonie	End +10 · Dégâts sorts +14 · Soins +43 · Rés. nature +4	c197:1
275610	hands	4	2	3	58	53	Griffes de cloque-bilieuse	End +19 · Int +11 · Rés. nature +5	c165:1
275611	waist	4	2	3	58	53	Ceinturon de cloque-bilieuse	End +17 · Int +14 · Rés. nature +6	c165:1
275612	feet	4	2	3	58	53	Bottes de cloque-bilieuse	Esp +8 · Puiss. sorts +22 · Rés. nature +8	c165:1
275613	hands	4	2	3	58	53	Griffes de saccage-essaim	Agi +7 · End +20 · Rés. nature +7	c165:1
275614	waist	4	2	3	58	53	Ceinturon de saccage-essaim	Agi +7 · End +21 · Rés. nature +4	c165:1
275615	feet	4	2	3	58	53	Bottes de saccage-essaim	Agi +19 · End +10 · Rés. nature +4	c165:1
275616	hands	4	3	3	58	53	Agrippeurs de tripécaille	Agi +11 · End +19 · Rés. nature +5	c165:1
275617	waist	4	3	3	58	53	Ceinture de tripécaille	Agi +14 · End +17 · Rés. nature +6	c165:1
275618	feet	4	3	3	58	53	Bottines de tripécaille	Agi +8 · PA +38 · Rés. nature +8	c165:1
275619	hands	4	3	3	58	53	Agrippeurs de garde-couvée	Esp +20 · Dégâts sorts +5 · Soins +16 · Rés. nature +7	c165:1
275620	waist	4	3	3	58	53	Ceinture de garde-couvée	End +21 · Dégâts sorts +5 · Soins +16 · Rés. nature +4	c165:1
275621	feet	4	3	3	58	53	Bottines de garde-couvée	End +10 · Dégâts sorts +14 · Soins +43 · Rés. nature +4	c165:1
275622	hands	4	4	3	58	53	Poignes de sangtaille	For +11 · End +19 · Rés. nature +5	c164:1
275623	waist	4	4	3	58	53	Support de sangtaille	For +14 · End +17 · Rés. nature +6	c164:1
275624	feet	4	4	3	58	53	Croquenots de sangtaille	End +8 · PA +38 · Rés. nature +8	c164:1
275625	hands	4	4	3	58	53	Poignes de couverain	For +7 · End +20 · Rés. nature +7	c164:1
275626	waist	4	4	3	58	53	Support de couverain	For +7 · End +21 · Rés. nature +4	c164:1
275627	feet	4	4	3	58	53	Croquenots de couverain	For +19 · End +10 · Rés. nature +4	c164:1
275630	off	4	0	2	58	0	Œil d’influence épuisé	Puiss. sorts +12	
275645	two	2	6	2	59	0	Lance reforgée	For +14 · End +13	
275647	main	2	15	2	59	0	Kriss rituel purifié	Esp +4	
275648	two	2	10	2	59	0	Bâton en écorce noueuse purifié	Esp +19 · Crit. +14	
275649	off	4	6	2	59	0	Barrière en écorce de roncier	For +6 · End +7	
275666	shoulder	4	2	2	59	0	Plateau de Blanchetête	Esp +11 · Puiss. sorts +16	
275668	back	4	1	2	59	0	Drapé du sommet	For +8 · Int +10	
275669	hands	4	2	2	58	0	Boxeurs d’Uppercut	For +13	
275671	off	4	0	2	58	0	Boisson d’agent de terrain	Esp +4	
275685	finger	4	0	2	58	0	Sceau du Service de Renseignement de Hurlevent	Agi +9 · Int +8 · Dégâts sorts +4 · Soins +11	
275698	main	2	4	2	58	0	Outil de réparation de Yaely	Int +11	
275700	one	2	4	2	58	0	Silencieux de lanceur de glaive	For +6 · End +7	
275701	two	2	10	2	58	0	Tuyau plaqué en cuivre	Agi +20 · Int +12	
275708	chest	4	2	3	61	0	Tunique en peau de Ghansurok	Agi +26 · End +11 · Rés. nature +15	
275711	back	4	1	3	61	0	Cape d’aile de chimère	End +10 · Dégâts sorts +8 · Soins +22 · Rés. nature +10	
275715	hands	4	1	2	58	0	Gants de pilote de fusée	Esp +12	
275729	two	2	8	2	58	0	Lame d’hélice rouillée	For +21 · Esp +5	
275736	neck	4	0	3	61	0	Corne de Ve’han	End +10 · Toucher +13 · Déf. +5	
275737	shoulder	4	3	3	61	0	Espauliers de l’ermite	Esp +13 · PA +26 · Toucher +13	
275738	finger	4	0	3	61	0	Babiole de Jereman	Int +11 · Esp +7 · Puiss. sorts +15	
275739	wrist	4	2	3	61	0	Garde-poignets sauvages	For +14 · End +7 · Esp +7	
275740	finger	4	0	3	61	0	Anneau des cycles de la nature	Esp +14 · Dégâts sorts +7 · Soins +20	
275741	waist	4	3	3	61	0	Ceinture rivetée de Ketharas	End +10 · Int +13 · Puiss. sorts +20	
275742	two	2	6	2	59	0	Lame du fléau des démons	PA +38	
275824	two	2	1	3	48	1	Scinde-protection		
275827	waist	4	1	2	58	0	Baudrier cousu en laine	Esp +10 · Dégâts sorts +8 · Soins +24 · Rés. givre +8	
275831	finger	4	0	2	58	0	Bracelet hauteplume	Agi +12 · Int +5	
275832	chest	4	2	2	58	0	Tunique plume-de-corbeau	Agi +11 · Int +10 · Puiss. sorts +20	
275833	back	4	1	2	58	0	Cape poil-de-pin	End +10	
275836	main	2	15	2	57	0	Lame d’acolyte	End +5 · Esp +8	
275837	ranged	2	19	2	58	0	Allumette de Gangrechique	Puiss. sorts +11	
275838	neck	4	0	2	58	0	Pendentif de piétine-poussière	For +11 · Esp +6	
275968	finger	4	0	3	63	60	Chevalière de férocité d’initiation	End +10 · PA +20 · Toucher +10	
275969	finger	4	0	3	63	60	Chevalière de clairvoyance d’initiation	End +6 · Puiss. sorts +8 · Crit. +14	
275970	finger	4	0	3	63	60	Chevalière de détermination d’initiation	End +10 · Esp +10 · Dégâts sorts +7 · Soins +22	
275971	finger	4	0	3	63	60	Chevalière de vigilance d’initiation	End +10 · Déf. +6	
275972	finger	4	0	3	68	60	Chevalière de férocité de traque	End +11 · PA +24 · Toucher +10	
275973	finger	4	0	3	68	60	Chevalière de clairvoyance de traque	End +8 · Puiss. sorts +10 · Crit. +14	
275974	finger	4	0	3	68	60	Chevalière de détermination de traque	End +10 · Esp +11 · Dégâts sorts +9 · Soins +26	
275975	finger	4	0	3	68	60	Chevalière de vigilance de traque	End +14 · Déf. +7	
275976	finger	4	0	4	60	60	Chevalière de férocité de veille	End +13 · PA +30 · Toucher +10	
275977	finger	4	0	4	60	60	Chevalière de clairvoyance de veille	End +10 · Puiss. sorts +15 · Crit. +14	
275979	finger	4	0	4	60	60	Chevalière de détermination de veille	End +10 · Esp +13 · Dégâts sorts +11 · Soins +33	
275980	finger	4	0	4	60	60	Chevalière de vigilance de veille	End +16 · Déf. +8	
275981	finger	4	0	4	65	60	Chevalière de férocité de garde	End +14 · PA +34 · Toucher +10	
275982	finger	4	0	4	65	60	Chevalière de clairvoyance de garde	End +12 · Puiss. sorts +17 · Crit. +14	
275983	finger	4	0	4	65	60	Chevalière de détermination de garde	End +10 · Esp +14 · Dégâts sorts +12 · Soins +37	
275984	finger	4	0	4	65	60	Chevalière de vigilance de garde	End +18 · Déf. +8	
276102	two	2	8	2	42	0	Lame-vent	For +10 · End +4	
276105	head	4	2	3	43	0	Couvre-œil du maître-éclaireur	End +16 · Esp +13 · Toucher +7	
276199	head	4	5	3	1	1	Monocle d’arrogance		
276200	hands	4	4	2	45	40	Claqueurs de clampant	End +11 · PA +12	
276201	legs	4	3	2	45	40	Culotte égarée	Int +13 · Esp +13	
276202	finger	4	0	2	45	40	Anneau de désengagement	Agi +8 · Esp +5	
276203	two	2	6	3	45	40	Canne à pêche primitive	For +7 · Agi +10 · End +20	
276204	off	4	0	3	45	40	Déchets de Lamine	End +5 · Dégâts sorts +14 · Soins +5	
276272	head	4	5	3	1	1	Chapeau de pêche de maître pêcheur		
276273	off	4	0	3	1	1	Seau de poissons vide		
276274	feet	4	1	3	25	1	Chaussures de surf	End +10	
276332	ranged	2	18	2	60	0	Espoir d’Abigail	For +7 · End +8	
276333	finger	4	0	2	60	0	Sceau de la famille Sawyer	End +10	
276334	off	4	6	2	60	0	Bouclier façonné à la main	End +10 · Puiss. sorts +12	
276335	two	2	8	2	60	0	Lame de garde funeste polie	End +5 · PA +44	
276336	off	4	0	2	60	0	Perles d’esprit de Yashiro	Esp +12 · Dégâts sorts +5 · Soins +15	
276337	trinket	4	0	2	60	0	Talisman de Thaelemaches	PA +18 · Rés. feu +6 · Rés. ombre +6	
276338	one	2	13	2	60	0	Griffe de Shalla’kal	PA +10	
276339	legs	4	2	2	60	0	Jambières traitées en peau de cerf	Agi +15 · End +13 · Déf. +9	
276340	legs	4	2	2	60	0	Hakama de maître-lame	For +7 · Agi +22 · Esp +5	
276341	feet	4	4	2	58	0	Grèves d’écraseur de peste	For +13 · Dégâts sorts +9 · Soins +26	
276538	legs	4	3	4	61	60	Kilt de mande-esprit		c165:1
276539	hands	4	3	4	61	60	Gants de mande-esprit		c165:1
276540	shoulder	4	3	4	61	60	Mantelet de mande-esprit		c165:1
276541	feet	4	3	4	61	60	Bottes de mande-esprit		c165:1
276685	ranged	2	2	2	14	0	Arc de la milice	Agi +1	
276694	ranged	2	3	2	15	0	Pétard veinard du capitaine Sander	For +1	
276695	ranged	2	2	2	15	0	Faucheteigne de moissonneur	Agi +1 · End +1	
276719	head	4	3	2	10	0	DNT HEAD		
276720	shoulder	4	3	2	22	0	Espauliers de criminalité	End +2 · Esp +4	
276721	chest	4	3	2	10	0	DNT CHEST		
276722	wrist	4	3	2	24	0	Menottes de Gnoll	For +2 · Int +4	
276723	hands	4	3	2	18	0	Gantelets sages	Esp +4	
276724	waist	4	3	2	24	0	Ceinture trophée	Int +5 · Esp +3	
276725	legs	4	3	2	10	0	DNT LEGS		
276727	feet	4	3	2	30	0	Croquenots scintillants	For +5 · Int +5	
276754	off	4	6	3	55	0	Veille de Fracécorce	End +12 · Dégâts sorts +6 · Soins +18 · Mana/5 +3	
276886	main	2	7	2	24	1	Épée trophée de Chol’aruk	End +2 · PA +4	q97005
276887	two	2	5	2	24	1	Grand méchant cogneur	For +4 · End +6	q97005
276888	main	2	15	2	24	1	Cure-dent huran	Int +2 · Esp +2	q97005
276889	off	4	6	2	24	1	Bouclier tissépine	End +4 · Esp +2	q97005
276895	trinket	4	0	2	31	1	Cocon de métamorphose		
276897	off	4	0	3	38	1	Une leçon de destruction	End +8 · Esp +6 · Puiss. sorts +6	
276898	off	4	0	3	38	1	Baume (au cœur)	Esp +9 · Dégâts sorts +3 · Soins +9 · Armure +50	
276899	finger	4	0	3	38	1	Cosse articulaire	End +8 · Armure +50	
276900	neck	4	0	2	54	1	Plaques de Denrick	End +6 · Int +10	
276901	back	4	1	2	54	1	Héroïsme avunculaire	For +10 · Esp +6	
276902	ranged	2	2	2	54	1	Premier arc de jeunesse	End +8 · PA +10	
276903	main	2	15	2	52	1	Vin chatoyant perforeur	Agi +7 · End +4	
276904	off	4	0	2	52	1	Vin chatoyant spirituel	Int +6 · Esp +9	
276992	chest	4	3	2	12	7	Cotte de mailles forge-ciel nuageuse	For +2	c164:1
276993	wrist	4	3	2	10	5	Garde-poignets forge-ciel nuageux	For +1	c164:1
276994	hands	4	3	2	11	6	Gantelets forge-ciel nuageux	Agi +1	c164:1
276995	waist	4	3	2	10	5	Chaîne forge-ciel nuageuse	End +1	c164:1
276996	legs	4	3	2	12	7	Garde-jambes forge-ciel nuageux	End +2	c164:1
276997	feet	4	3	2	11	6	Grèves forge-ciel nuageuses	Agi +1	c164:1
276998	chest	4	2	2	12	7	Harnais tisse-souffle nuageux	For +2	c165:1
276999	wrist	4	2	2	10	5	Brassards tisse-souffle nuageux	For +1	c165:1
277000	hands	4	2	2	11	6	Gants tisse-souffle nuageux	Agi +1	c165:1
277001	waist	4	2	2	10	5	Ceinture tisse-souffle nuageuse	End +1	c165:1
277002	legs	4	2	2	12	7	Chausses tisse-souffle nuageuses	End +2	c165:1
277003	feet	4	2	2	11	6	Bottes tisse-souffle nuageuses	Agi +1	c165:1
277004	chest	4	2	2	12	7	Pourpoint mêle-vent nuageux	Int +2	c165:1
277005	wrist	4	2	2	10	5	Garde-bras mêle-vent nuageux	Int +1	c165:1
277006	hands	4	2	2	11	6	Mitaines mêle-vent nuageuses	Esp +1	c165:1
277007	waist	4	2	2	10	5	Lanière mêle-vent nuageuse	End +1	c165:1
277008	legs	4	2	2	12	7	Pantalon mêle-vent nuageux	End +2	c165:1
277009	feet	4	2	2	11	6	Bottillons mêle-vent nuageux	Esp +1	c165:1
277010	chest	4	1	2	12	7	Gilet fil-tempête nuageux	Int +2	c197:1
277011	wrist	4	1	2	10	5	Crispins fil-tempête nuageux	Int +1	c197:1
277012	hands	4	1	2	11	6	Protège-mains fil-tempête nuageux	Esp +1	c197:1
277013	waist	4	1	2	10	5	Corde fil-tempête nuageuse	End +1	c197:1
277014	legs	4	1	2	12	7	Jambières fil-tempête nuageuses	End +2	c197:1
277015	feet	4	1	2	11	6	Chaussures fil-tempête nuageuses	Esp +1	c197:1
277016	chest	4	3	2	12	7	Cotte de mailles forge-ciel azur	For +2	c164:1
277017	wrist	4	3	2	10	5	Garde-poignets forge-ciel azur	For +1	c164:1
277018	hands	4	3	2	11	6	Gantelets forge-ciel azur	Agi +1	c164:1
277019	waist	4	3	2	10	5	Chaîne forge-ciel azur	End +1	c164:1
277020	legs	4	3	2	12	7	Garde-jambes forge-ciel azur	End +2	c164:1
277021	feet	4	3	2	11	6	Grèves forge-ciel azur	Agi +1	c164:1
277022	chest	4	2	2	12	7	Harnais tisse-souffle azur	For +2	c165:1
277023	wrist	4	2	2	10	5	Brassards tisse-souffle azur	For +1	c165:1
277024	hands	4	2	2	11	6	Gants tisse-souffle azur	Agi +1	c165:1
277025	waist	4	2	2	10	5	Ceinture tisse-souffle azur	End +1	c165:1
277026	legs	4	2	2	12	7	Chausses tisse-souffle azur	End +2	c165:1
277027	feet	4	2	2	11	6	Bottes tisse-souffle azur	Agi +1	c165:1
277028	chest	4	2	2	12	7	Pourpoint mêle-vent azur	Int +2	c165:1
277029	wrist	4	2	2	10	5	Garde-bras mêle-vent azur	Int +1	c165:1
277030	hands	4	2	2	11	6	Mitaines mêle-vent azur	Esp +1	c165:1
277031	waist	4	2	2	10	5	Lanière mêle-vent azur	End +1	c165:1
277032	legs	4	2	2	12	7	Pantalon mêle-vent azur	End +2	c165:1
277033	feet	4	2	2	11	6	Bottillons mêle-vent azur	Esp +1	c165:1
277034	chest	4	1	2	12	7	Gilet fil-tempête azur	Int +2	c197:1
277035	wrist	4	1	2	10	5	Crispins fil-tempête azur	Int +1	c197:1
277036	hands	4	1	2	11	6	Protège-mains fil-tempête azur	Esp +1	c197:1
277037	waist	4	1	2	10	5	Corde fil-tempête azur	End +1	c197:1
277038	legs	4	1	2	12	7	Jambières fil-tempête azur	End +2	c197:1
277039	feet	4	1	2	11	6	Chaussures fil-tempête azur	Esp +1	c197:1
277040	head	4	3	2	35	30	Heaume forge-ciel nuageux	For +9 · End +9	c164:1
277041	shoulder	4	3	2	35	30	Espauliers forge-ciel nuageux	Agi +7 · End +7	c164:1
277042	head	4	2	2	35	30	Chaperon tisse-souffle nuageux	For +9 · End +9	c165:1
277043	shoulder	4	2	2	35	30	Spallières tisse-souffle nuageuses	Agi +7 · End +7	c165:1
277044	head	4	2	2	35	30	Couvre-chef mêle-vent nuageux	End +9 · Int +9	c165:1
277045	shoulder	4	2	2	35	30	Drapé mêle-vent nuageux	End +7 · Esp +7	c165:1
277046	head	4	1	2	35	30	Capuche fil-tempête nuageuse	End +9 · Int +9	c197:1
277047	shoulder	4	1	2	35	30	Épaulettes fil-tempête nuageuses	End +7 · Esp +7	c197:1
277048	head	4	3	2	35	30	Heaume forge-ciel azur	For +9 · End +9	c164:1
277049	shoulder	4	3	2	35	30	Espauliers forge-ciel azur	Agi +7 · End +7	c164:1
277050	head	4	2	2	35	30	Chaperon tisse-souffle azur	For +9 · End +9	c165:1
277051	shoulder	4	2	2	35	30	Spallières tisse-souffle azur	Agi +7 · End +7	c165:1
277052	head	4	2	2	35	30	Couvre-chef mêle-vent azur	End +9 · Int +9	c165:1
277053	shoulder	4	2	2	35	30	Drapé mêle-vent azur	End +7 · Esp +7	c165:1
277054	head	4	1	2	35	30	Capuche fil-tempête azur	End +9 · Int +9	c197:1
277055	shoulder	4	1	2	35	30	Épaulettes fil-tempête azur	End +7 · Esp +7	c197:1
277202	neck	4	0	3	58	0	Pendentif de chercheur d’artéfact	For +9 · Agi +8 · End +14	
277203	neck	4	0	2	23	0	Pendentif d’érudition	End +3 · Esp +2	
277204	neck	4	0	2	23	0	Amulette de l’érudit	Agi +2 · End +3	
277205	back	4	1	3	35	0	Cape de la tempête divine	For +5 · End +5	
277206	back	4	1	2	41	0	Cape brillante	End +5 · Int +5 · Puiss. sorts +6	
277207	back	4	1	2	40	0	Cape vieillie	End +6	
277208	finger	4	0	2	45	0	Anneau résolu	End +8 · PA +9	
277209	finger	4	0	2	40	0	Boucle assommante	End +4 · Int +7	
277210	finger	4	0	3	25	0	Chevalière de Bois-du-Bûcher	Agi +4 · End +4 · Toucher +4	
277211	head	4	1	2	46	0	Coiffe de réflexion de Dudd	End +10 · Int +14	
277212	shoulder	4	1	2	45	40	Épaulettes tissâme	End +9 · Esp +9	
277214	wrist	4	1	2	35	0	Crispins croûtés	End +5 · Esp +5	
277215	hands	4	1	2	45	40	Protège-mains simples	Int +8 · Esp +10	
277216	waist	4	1	2	45	40	Corde à couture croisée	End +11 · Mana/5 +3	
277217	legs	4	1	2	45	40	Pantalon recousu	End +15 · Int +8	
277218	feet	4	1	2	28	0	Bottes d’incinérateur	End +3 · Int +6	q95999
277219	head	4	2	2	30	0	Chapeau confortable de Salomon	Agi +9 · Esp +5	
277220	shoulder	4	2	2	45	0	Spallières miteuses	End +10 · Int +8	
277221	chest	4	2	2	45	0	Tunique de naturaliste du Totem-sinistre	For +14 · Agi +10	
277222	wrist	4	2	2	45	40	Crispins ornés de peinture de guerre	End +7	
277223	hands	4	2	2	45	0	Gants de voyage	For +9 · Puiss. sorts +11	
277224	waist	4	2	2	35	0	Cordelière de réducteur de tête de Kurzen	End +8 · Puiss. sorts +5	
277225	legs	4	2	2	45	40	Jambières de plumes	End +13 · PA +25	
277226	feet	4	2	2	28	0	Chaussures décousues	PA +12 · Puiss. sorts +5	q95999
277227	head	4	3	2	30	0	Chaperon en mailles de magistrat	For +5 · End +9	
277228	shoulder	4	3	2	45	40	Espauliers en écailles de serpent	Agi +11 · End +6	
277229	chest	4	3	2	45	40	Lorica endurante	Mana/5 +5	
277230	wrist	4	3	2	45	40	Brassards grisécailles	For +7 · Agi +7	
277231	hands	4	3	2	45	40	Gantelets conducteurs	Int +7 · PA +21	
277232	waist	4	3	2	35	0	Chaîne abandonnée de geôlier	End +7 · PA +12	
277233	legs	4	3	2	45	40	Cuissards cliquetants en mailles	End +10 · Int +14	
277234	feet	4	3	2	28	0	Bottines empressées	For +5 · Agi +5	q95999
277235	head	4	4	2	45	0	Visière de soldat	For +14 · End +10	
277236	shoulder	4	4	3	45	0	Espauliers de justification	For +10 · End +10 · Crit. +10	
277237	chest	4	4	2	45	40	Pansière inspirante	Int +13 · Esp +13	
277238	wrist	4	4	2	45	40	Brassards chatoyants	End +7 · Int +7	
277239	hands	4	4	2	45	40	Boxeurs enchâssés	For +6 · Esp +11	
277240	waist	4	4	2	45	40	Ceinture en plaques dorée	PA +19 · Puiss. sorts +11	
277241	legs	4	4	2	45	40	Cuissards à doubles plaques	End +15 · Armure +82	
277242	feet	4	4	2	45	40	Grèves en runargent	For +10	
277243	one	2	0	3	45	40	Tranchoir plaiedargent	For +9 · Esp +4	
277244	one	2	13	3	45	40	Marteleurs de garde	Agi +9 · Esp +4	
277245	one	2	4	3	45	40	Écraseur maréchine	Agi +4 · End +9	
277246	one	2	7	3	36	0	Lame ornée de rubis	Agi +3 · End +8	
277247	main	2	4	2	12	0	Chope de souvenirs confus	Int +1 · Esp +1	
277248	main	2	15	3	45	40	Côte rituelle ébréchée	End +4 · Int +9	
277250	two	2	5	3	45	40	Le fêle-crâne	Esp +22 · PA +18	
277253	two	2	10	2	43	0	Bâton de ruse brutale	Int +6 · Esp +15	
277254	ranged	2	2	3	45	40	Arc de cherche-vérité	Agi +9 · End +4	
277255	ranged	2	3	2	12	0	Tireur égaré	For +1 · End +1	
277256	ranged	2	19	2	45	40	Deuxième baguette préférée de Dudd	Int +7 · Mana/5 +1	
277257	off	4	6	3	29	0	Cimier de Colline-aux-Corbeaux	Armure +76	
277258	off	4	6	3	45	40	Écu d’élucidation	Esp +12 · Dégâts sorts +4 · Soins +11	
277259	off	4	0	3	45	40	Potion de restauration fermentée	End +12 · Esp +5	
277260	off	4	0	3	45	40	Lueur nocturne de chercheur	End +12	
277286	two	2	1	3	23	1	Requête d’envahissement	For +6 · Esp +9	
277288	main	2	0	3	23	1	Dégagement de guide	End +3 · Int +4	
277289	back	4	1	3	23	1	Châle de voyage	End +4 · Esp +5	
277514	chest	4	1	2	33	1	Vêtements rapiécés d’Aka’rai	End +9 · Esp +9	
277515	one	2	15	2	33	1	Dague de négociation	Agi +4 · End +3	
277555	off	4	6	2	8	0	Monstre – bouclier, Éolide (gris)		
277672	feet	4	3	2	10	4	Bottes grossières en anneaux de cuivre	For +1	c164:1
277844	trinket	4	0	2	40	35	Miroir du mirage		
277910	trinket	4	0	2	40	35	Graine de fleur mystique		
277950	trinket	4	0	2	40	35	Rations des Bat-le-désert		
277979	one	2	4	2	44	1	Mouton de marteleur	End +5 · Esp +6	
277980	off	4	0	2	44	1	Os d’Ogre	End +8 · Int +4	
277981	neck	4	0	2	44	1	Dent d’Ogre souvenir	Agi +5 · End +8	
277988	one	2	15	2	11	0	Lame écrin-de-sabot	For +1	
278002	main	2	4	2	11	0	Gourdin de la vallée	End +1	
278017	finger	4	0	2	35	1	Anneau remboursé	End +8	
278018	finger	4	0	2	35	1	Anneau renégocié	For +3 · End +6	
278019	finger	4	0	2	35	1	Anneau d’excuses	End +6 · Puiss. sorts +4	
278157	off	4	0	4	65	60	Tome de restauration de qualité de connétable	End +13 · Int +13 · Esp +13 · Dégâts sorts +9 · Soins +28	
278158	off	4	0	4	65	60	Tome de puissance de qualité de connétable	End +15 · Int +14 · Puiss. sorts +18	
278423	one	2	14	2	1	1	Monstre – Pioche de minage		
278468	off	4	6	4	65	60	Barricade de qualité de connétable	End +21 · Int +9 · Dégâts sorts +6 · Soins +18	
278469	off	4	6	4	65	60	Barricade de qualité de grand seigneur de guerre	End +21 · Int +9 · Dégâts sorts +6 · Soins +18	
279246	ranged	2	19	4	65	60	Torche de lumière	Esp +15 · Dégâts sorts +7 · Soins +22	c333:1
279247	ranged	4	7	4	65	60	Libram inébranlable		c333:1
279248	ranged	4	7	4	65	60	Libram d’imprégnation		c333:1
279249	ranged	4	9	4	65	60	Totem d’urgence		c333:1
279250	ranged	4	8	4	65	60	Idole de rapidité		c333:1
279251	ranged	4	8	4	65	60	Idole des ours jumeaux		c333:1
279252	waist	4	2	4	65	60	Corde cintrée de Sylvancienne	End +21 · Esp +18 · Dégâts sorts +10 · Soins +30	c165:1
279253	head	4	2	4	65	60	Collerette de hors-la-loi	Agi +21 · End +31 · Crit. +21	c165:1
279254	legs	4	2	4	65	60	Pantalon de Sylvancienne	End +27 · Esp +24 · Dégâts sorts +13 · Soins +40	c165:1
279255	shoulder	4	3	4	65	60	Espauliers d’éternité	End +21 · Esp +18 · Dégâts sorts +10 · Soins +30	c165:1
279256	wrist	4	3	4	65	60	Garde-poignets de tranquillité	For +16 · End +14 · Int +10	c165:1
279257	hands	4	3	4	65	60	Garde-mains endeuillés	Agi +21 · End +18 · Int +14	c165:1
279259	one	2	7	4	65	60	Lame en bois-de-fer	For +8 · End +12 · Toucher +10	c164:1
279260	two	2	1	4	65	60	Hache de défense de la forêt	For +18 · End +27 · Puiss. sorts +28	c164:1
279261	one	2	4	4	65	60	Vertmartel	Agi +8 · End +12 · Toucher +10	c164:1
279262	off	4	6	4	65	60	Bouclier sempervirent	End +16 · Dégâts sorts +8 · Soins +23 · Crit. +14	c164:1
279263	feet	4	4	4	65	60	Solerets en thorium appauvri	For +14 · End +21 · Dégâts sorts +21	c164:1
279264	hands	4	4	4	65	60	Gantelets lourds en thorium	For +21 · End +14 · Déf. +12	c164:1
279265	legs	4	4	4	65	60	Cuissards en azerothium	For +24 · Agi +18 · End +27	c164:1
279266	chest	4	1	4	65	60	Robe de dévastation ardente	End +27 · Int +24	c197:1
279267	waist	4	1	4	65	60	Corde imprégnée de mana	End +21 · Esp +18	c197:1
279268	feet	4	1	4	65	60	Bottes incrustées de givre	End +21 · Esp +18	c197:1
279269	back	4	1	4	65	60	Pèlerine gangrenée	End +16 · Crit. +14	c197:1
279270	back	4	1	4	65	60	Cape de la terre et du ciel	End +16 · Esp +14	c197:1
279273	ranged	2	3	4	65	60	Carabine de précision hyper luxe Mod. XVII	End +10 · Esp +8 · PA dist. +28	c202:1
279392	one	2	7	3	30	0	Luison		
279393	one	2	7	3	30	0	Chutegivre		
280306	waist	4	1	2	35	30	Baudrier fantaisiste		c202:1
280307	waist	4	2	2	35	30	Ceinturon à gadgets		c202:1
280308	waist	4	3	2	35	30	Corde cliquetante		c202:1
280310	head	4	1	2	45	40	Lunettes molles		c202:1
280311	head	4	2	2	45	40	Lunettes tordues		c202:1
280312	head	4	3	2	45	40	Lunettes à bouton cassé		c202:1
280313	head	4	4	2	45	40	Lunettes cabossées		c202:1
280604	two	2	5	3	40	1	Rage du cyclone	End +15 · Int +12	
280605	main	2	13	3	40	1	Griffe de porte-marées	End +5	
280607	main	2	13	3	40	1	Emprise de la foudre	Int +6	
280696	off	4	6	3	40	1	Garde d’élémentaliste	End +9 · Int +6 · Mana/5 +2	
280766	trinket	4	0	2	33	1	Sacoche de potions		
281020	off	4	6	2	8	0	Monstre – bouclier, Éolide (blanc)		
281250	back	4	1	2	11	0	Cape de l’oracle sylvestre	End +1	
281251	wrist	4	2	2	24	0	Garde-poignets de coursier	Agi +3 · End +3	
281252	finger	4	0	2	26	0	Anneau en griffe de harpie	Esp +5	
281253	two	2	1	2	17	0	Bardiche de montagnard	For +3 · End +4	
281254	one	2	4	2	17	0	Masse d’envahisseur	For +2 · Esp +1	
281256	wrist	4	1	2	20	0	Serre-tête reconverti	Int +2 · Esp +2	q86614
281257	one	2	15	2	16	0	Dague-croc de Daguecroc	Agi +2	
281258	neck	4	0	2	33	0	Espoir d’Essène	Esp +7	
281259	feet	4	4	2	50	0	Croquenots de Pierrêche	End +13 · Esp +7	
281260	waist	4	1	2	50	0	Corde cintrée ancestrale	Int +12 · Esp +8	
281261	waist	4	2	2	55	0	Corde parsemée de cristaux	End +9 · Int +14	
281262	waist	4	3	2	55	0	Sangle parsemée de cristaux	For +6 · Int +15	
281263	ranged	2	19	2	29	0	Doigt de liche malfaisante	Int +3 · Esp +2	
281264	ranged	2	2	2	29	0	Arc ignoble	Agi +3 · Esp +3	
281265	neck	4	0	2	20	0	Confiance de guette-chemin	Esp +3	
281267	legs	4	3	2	8	0	Pantalon en écailles de raptor	Agi +1	
281269	wrist	4	1	2	10	0	Bracelet d’amitié de Mogra	Esp +1	
281270	wrist	4	2	2	10	0	Bracelet d’amitié de Thra	Int +1	
281271	wrist	4	2	2	10	0	Bracelet d’amitié de Puk	Agi +1	
281272	wrist	4	3	2	10	0	Bracelet d’amitié de Brog	For +1	
281273	wrist	4	3	2	10	0	Bracelet d’amitié de Migi	End +1	
281274	two	2	10	2	11	0	Mande-foudre improvisé	Int +2	
281275	shoulder	4	1	2	50	0	Mantelet tueur d’écailles	End +11 · Esp +11	
281276	shoulder	4	2	2	50	0	Espauliers tueurs d’écailles	Agi +11 · End +11	
281277	shoulder	4	3	2	50	0	Épaulières tueuses d’écailles	End +11 · Int +11	
281278	shoulder	4	4	2	50	0	Plaques d’épaule tueuses d’écailles	For +11 · End +11	
281279	hands	4	4	2	60	0	Poings de géant de grêle	For +12 · End +14	
281280	hands	4	3	2	60	0	Grave-montagnes	End +15 · Int +10	
281281	neck	4	0	2	60	0	Pendentif de murmure du givre	Puiss. sorts +12 · Rés. givre +10	
281283	legs	4	1	2	11	0	Pantalon d’aile raccomodée	Int +2	
281284	chest	4	2	2	11	0	Gilet en hurlepeau	Agi +2	
281285	feet	4	3	2	11	0	Semelles écaillaileron	For +1	
281286	neck	4	0	2	57	0	Pendentif de l’Ordre suprême	Int +11 · Puiss. sorts +7	
281287	neck	4	0	2	57	0	Pendentif de Sculpte-vent	For +11 · End +6	
281288	finger	4	0	2	57	0	Chevalière shen’dorei	For +7 · End +7 · Int +7	
281289	back	4	1	2	13	0	Cape de Plumelame	For +1	
281290	neck	4	0	2	29	0	Réplique de collier à croissant de lune	Agi +4 · Esp +4	
281291	off	4	0	3	21	0	Orbe de canalisation de Mathystra	End +3 · Int +5	
281292	off	4	0	3	21	0	Patience d’Onu	End +3 · Esp +5	
281293	one	2	7	2	25	0	Lame de nécrotraqueur abîmée	For +4	
281294	off	4	0	2	25	0	Flacon d’apothicaire utilisé	Int +3 · Esp +3	
281295	legs	4	2	2	31	0	Pantalon en fourrure	For +9 · Agi +7	
281296	two	2	6	2	25	0	Hast de chevalier	Agi +7 · End +5	
281297	main	2	15	2	25	0	Dague royale	Int +4	
281298	legs	4	1	2	49	0	Chausses toquées de Ti’ik	Int +16 · Esp +11	
281299	chest	4	2	2	49	0	Robe rituelle impie	Agi +17 · End +9	
281301	wrist	4	4	2	49	0	Entraves sacrificielles	End +7 · Int +9	
281302	neck	4	0	2	44	0	Collier en écailles de dragonnet	For +7 · Esp +7	
281303	chest	4	3	2	44	0	Gilet en écailles blanchies	For +6 · Int +15	
281304	finger	4	0	2	31	0	Chevalière de prospecteur	End +4 · Int +4	
281305	back	4	1	2	31	0	Cape d’excavation	For +4 · End +4	
281306	off	4	0	2	31	0	Grimoire marqué par les flammes	End +2 · Esp +5	
281307	off	4	6	2	31	0	Targe gueule-de-dragon	For +3 · End +5	
281308	two	2	8	2	42	0	Epée de rechange de Jameson	For +11 · Esp +11	
281309	legs	4	2	2	30	0	Bermuda de tranchegueule	Agi +8 · End +6	
281310	legs	4	2	2	30	0	Chausses de carnage	End +6 · Int +8	
281312	two	2	10	3	32	0	Sceptre de Dragon déchu	Int +11 · Esp +13	q98297
281313	two	2	8	3	32	0	Fidèle épée	End +12 · Esp +12	q98297
281314	one	2	15	3	32	0	Croc de Dragon soumis	Agi +7 · End +2	q98297
281315	hands	4	1	2	16	0	Gants de vil-poil	Int +3	
281316	legs	4	3	2	51	0	Chausses chaînetoyantes	End +18 · Int +9	
281317	feet	4	4	2	51	0	Bottes rougepierre	Int +11 · Esp +11	
281318	off	4	0	2	29	0	Bouquet de fleurs d’Auberdine	End +4 · Int +4	
281319	back	4	1	3	32	0	Cape de guerre de golem	For +6 · Armure +72	q98310
281320	finger	4	0	3	32	0	Anneau gravé de runes	End +10	q98310
281321	neck	4	0	3	32	0	Médaillon de pierre des géants	Esp +10	q98310
281323	waist	4	3	2	27	0	Ceinture à boucle d’esprit	For +5 · Int +4	
281324	chest	4	1	2	17	0	Tunique de navigation	Esp +5	
281538	shoulder	4	2	2	59	0	Mantelet de la matriarche	For +10 · Esp +14	
281539	head	4	1	2	59	0	Capuche en fourrure d’ours	End +17 · Int +17	
281586	main	2	4	3	60	1	Marteau de chantier de Sylvancienne	End +8 · Int +10 · Esp +4	
281587	one	2	7	3	60	1	Écorcheuse de Largeflanc	For +5 · End +11 · Déf. +3	
281588	two	2	6	3	60	1	Abattage de la nature	End +26 · PA +23 · Armure +115	
281628	one	2	7	3	52	0	Lame de Bandarion	For +5 · End +11	
281634	finger	4	0	3	35	0	Jonc de recherche de terrain	Agi +7 · End +7	
281635	finger	4	0	3	35	0	Anneau de philanthrope	Int +5 · Puiss. sorts +10	
281636	neck	4	0	3	58	0	Chaîne de garde de musée	End +10 · Int +10 · Puiss. sorts +11	
281637	off	4	6	3	58	0	Rempart antique	End +13 · Déf. +8	
281657	neck	4	0	3	41	36	Pendentif des rives Claires corrompu	For +6 · Agi +9 · Esp +6	
281660	ranged	2	16	2	27	0	Étoile de fer	Agi +4	
281673	finger	4	0	2	28	0	Jonc de sacrifice	For +3 · Int +5	
281675	head	4	1	2	30	0	Bandeau anti-incendie de Comté-du-Lac	End +6 · Int +8	
281685	head	4	1	2	1	1	Heaume en tissu restauré		
281686	shoulder	4	1	2	1	1	Épaulières en tissu restaurées		
281687	chest	4	1	2	1	1	Gilet en tissu restauré		
281688	wrist	4	1	2	1	1	Brassards en tissu restaurés		
281689	hands	4	1	2	1	1	Protège-mains en tissu restaurés		
281690	waist	4	1	2	1	1	Ceinture en tissu restaurée		
281691	legs	4	1	2	1	1	Pantalon en tissu restauré		
281692	feet	4	1	2	1	1	Chaussures en tissu restaurées		
281693	head	4	2	2	1	1	Chaperon en cuir restauré		
281694	shoulder	4	2	2	1	1	Spallières en cuir restaurées		
281695	chest	4	2	2	1	1	Tunique en cuir restaurée		
281696	wrist	4	2	2	1	1	Protège-poignets en cuir restaurés		
281697	hands	4	2	2	1	1	Gants en cuir restaurés		
281698	waist	4	2	2	1	1	Sangle en cuir restaurée		
281699	legs	4	2	2	1	1	Guêtres en cuir restaurées		
281700	feet	4	2	2	1	1	Bottes en cuir restaurées		
281701	head	4	3	2	1	1	Camail en mailles restauré		
281702	shoulder	4	3	2	1	1	Garde-épaules en mailles restaurés		
281703	chest	4	3	2	1	1	Plastron en mailles restauré		
281704	wrist	4	3	2	1	1	Garde-poignets en mailles restaurés		
281705	hands	4	3	2	1	1	Poignes en mailles restaurées		
281706	waist	4	3	2	1	1	Ceinture en mailles restaurée		
281707	legs	4	3	2	1	1	Garde-jambes en mailles restaurés		
281708	feet	4	3	2	1	1	Bottes en mailles restaurées		
281709	head	4	4	2	1	1	Heaume en plaques restauré		
281710	shoulder	4	4	2	1	1	Épaulières en plaques restaurées		
281711	chest	4	4	2	1	1	Corselet en plaques restauré		
281712	wrist	4	4	2	1	1	Garde-poignets en plaques restaurés		
281713	hands	4	4	2	1	1	Garde-mains en plaques restaurés		
281714	waist	4	4	2	1	1	Ceinture en plaques restaurée		
281715	legs	4	4	2	1	1	Jambières en plaques restaurées		
281716	feet	4	4	2	1	1	Bottes en plaques restaurées		
281717	back	4	1	2	1	1	Cape restaurée		
281718	finger	4	0	2	1	1	Anneau restauré		
281719	neck	4	0	2	1	1	Collier restauré		
281720	one	2	0	2	1	1	Couperet restauré		
281721	two	2	1	2	1	1	Fendoir restauré		
281722	one	2	15	2	1	1	Dague restaurée		
281723	one	2	4	2	1	1	Cogneur restauré		
281724	two	2	5	2	1	1	Fracasseur restauré		
281725	two	2	6	2	1	1	Lance restaurée		
281727	two	2	10	2	1	1	Grand bâton restauré		
281728	one	2	7	2	1	1	Épée courte restaurée		
281729	two	2	8	2	1	1	Épée longue restaurée		
281730	off	4	0	2	1	1	Colifichet restauré		
281731	off	4	6	2	1	1	Targe restaurée		
281732	ranged	2	2	2	1	1	Arc restauré		
281733	ranged	2	19	2	1	1	Baguette restaurée		
281927	finger	4	0	2	27	22	Bague de Rochecœur	For +4 · End +2	
282026	finger	4	0	2	58	53	Chevalière de bataille inflexible	For +3 · End +12 · Esp +3	
282064	main	2	15	2	12	0	Côte perdue de Tim	Agi +1 · End +1	
282080	finger	4	0	2	57	52	Chevalière calcinée	End +8 · Puiss. sorts +6	
282283	finger	4	0	3	32	1	Racine malveillante	End +7 · PA +8 · Puiss. sorts +4	
282284	one	2	15	2	10	1	Tranchoir tissebois	Agi +1	
285275	ranged	2	16	2	18	13	Sacoche de bombes en cuivre	End +2	c202:1
285276	ranged	2	16	2	33	28	Sacoche de bombes en bronze	End +5	c202:1
285277	ranged	2	16	2	46	41	Sacoche de bombes en fer	End +8	c202:1
285278	ranged	2	16	2	57	52	Sacoche de bombes en sombrefer	End +10	c202:1
285279	ranged	2	16	2	22	17	Marteau de forgeron fêlé	For +3	c164:1
285280	ranged	2	16	2	39	34	Marteau de forgeron en mithril	For +7	c164:1
285281	ranged	2	16	3	54	49	Marteau de forgeron en arcanite	For +8 · Esp +5	c164:1
285353	back	4	5	3	1	1	Sac à dos de l’exploration éternelle		
286426	back	4	1	2	15	0	Cape liée à l’honneur	End +1 · PA +1 · Dégâts sorts +1	
286427	back	4	1	2	15	0	Cape de l’honorable hôte	End +1 · PA +1 · Dégâts sorts +1	
]==]
function WK.LoadItemsDB()
    if WK.ItemsDB then return WK.ItemsDB end
    local out, raw = {}, WK.ItemsDBRaw or ""
    for line in raw:gmatch("[^\n]+") do
        local id, slot, cls, sub, q, ilvl, req, name, stats, src = line:match("^(%d+)\t([^\t]*)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if id then
            out[#out + 1] = { tonumber(id), slot, tonumber(cls), tonumber(sub), tonumber(q), tonumber(ilvl), tonumber(req), name, stats, src }
        end
    end
    WK.ItemsDB, WK.ItemsDBRaw = out, nil
    return out
end
