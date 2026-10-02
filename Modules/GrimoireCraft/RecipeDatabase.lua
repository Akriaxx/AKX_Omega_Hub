-- GrimoireCraft - Base officielle des recettes
-- Généré par Tools/Update-GrimoireDatabase.py depuis « GrimoireCraft — Database Maître » (Google Drive).
-- Les recettes sans ID de sortie restent visibles mais ne sont pas fabricables tant que l’ID n’est pas renseigné.
GrimoireCraftOfficialRecipes = {
    {
        officialKey="couture_vetement_simple_i",
        name="Vêtement Simple I",
        outputItemID=14073246,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073033, quantity=2}, -- Cuir Souple
            {itemID=14073063, quantity=8}, -- Étoffe de Lin
            {itemID=14073060, quantity=2}, -- Étoffe de Laine
        },
    },
    {
        officialKey="couture_vetement_habille_i",
        name="Vêtement Habillé I",
        outputItemID=14073247,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073033, quantity=4}, -- Cuir Souple
            {itemID=14073058, quantity=4}, -- Étoffe de Coton
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="couture_vetement_chaud_i",
        name="Vêtement Chaud I",
        outputItemID=14073249,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073036, quantity=2}, -- Cuir Lourd
            {itemID=14073060, quantity=4}, -- Étoffe de Laine
            {itemID=14073032, quantity=4}, -- Bandes de Cuir
        },
    },
    {
        officialKey="couture_bandage_simple",
        name="Bandage Simple",
        outputItemID=14072869,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073341, quantity=1}, -- Eau Bénite du Temple
            {itemID=14073063, quantity=4}, -- Étoffe de Lin
        },
    },
    {
        officialKey="couture_bandage_lourd",
        name="Bandage Lourd",
        outputItemID=14072870,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073341, quantity=1}, -- Eau Bénite du Temple
            {itemID=14073063, quantity=8}, -- Étoffe de Lin
        },
    },
    {
        officialKey="tanneur_sac_6",
        name="Sac ( 6 )",
        outputItemID=14073243,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073033, quantity=2}, -- Cuir Souple
            {itemID=14072527, quantity=1}, -- Alun de Roche
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="tanneur_sac_8",
        name="Sac ( 8 )",
        outputItemID=14073245,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073033, quantity=4}, -- Cuir Souple
            {itemID=14072527, quantity=2}, -- Alun de Roche
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="tanneur_sac_10",
        name="Sac ( 10 )",
        outputItemID=14073244,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073033, quantity=6}, -- Cuir Souple
            {itemID=14072527, quantity=3}, -- Alun de Roche
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="forge_lingot_runique",
        name="Lingot Runique",
        outputItemID=14072913,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14072914, quantity=4}, -- Minerais Runifiés
            {itemID=14073114, quantity=2}, -- Essence Runique
        },
    },
    {
        officialKey="forge_anneau_runique",
        name="Anneau Runique",
        outputItemID=14073113,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14072913, quantity=1}, -- Lingot Runique
        },
    },
    {
        officialKey="forge_anneau_runique_enchante",
        name="Anneau Runique Enchanté",
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073113, quantity=1}, -- Anneau Runique
            {itemID=14073114, quantity=1}, -- Essence Runique
        },
    },
    {
        officialKey="forge_lingot_astral",
        name="Lingot Astral",
        outputItemID=14072911,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14072910, quantity=4}, -- Minerais Stellaires
            {itemID=14073115, quantity=2}, -- Essence Astrale
        },
    },
    {
        officialKey="forge_anneau_astral",
        name="Anneau Astral",
        outputItemID=14073342,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14072911, quantity=1}, -- Lingot Astral
        },
    },
    {
        officialKey="forge_anneau_runique_enchante_2",
        name="Anneau Runique Enchanté",
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073342, quantity=1}, -- Anneau Astral
            {itemID=14073115, quantity=1}, -- Essence Astrale
        },
    },
    {
        officialKey="couture_etoffe_de_coton",
        name="Étoffe de Coton",
        outputItemID=14073058,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073062, quantity=4}, -- Coton
        },
    },
    {
        officialKey="couture_etoffe_de_lin",
        name="Étoffe de Lin",
        outputItemID=14073063,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073051, quantity=4}, -- Lin
        },
    },
    {
        officialKey="couture_etoffe_de_laine",
        name="Étoffe de Laine",
        outputItemID=14073060,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073050, quantity=4}, -- Laine
        },
    },
    {
        officialKey="couture_tissu_melange",
        name="Tissu Mélangé",
        outputItemID=14073061,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073060, quantity=1}, -- Étoffe de Laine
            {itemID=14073063, quantity=1}, -- Étoffe de Lin
        },
    },
    {
        officialKey="couture_tissu_renforce",
        name="Tissu Renforcé",
        outputItemID=14073059,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073061, quantity=1}, -- Tissu Mélangé
            {itemID=14073054, quantity=1}, -- Fil
            {itemID=14073033, quantity=1}, -- Cuir Souple
        },
    },
    {
        officialKey="couture_fil",
        name="Fil",
        outputItemID=14073054,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073062, quantity=1}, -- Coton
        },
    },
    {
        officialKey="couture_chemise_matelassee_du_voyageur",
        name="Chemise Matelassée du Voyageur",
        outputItemID=14073261,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=2}, -- Fil
            {itemID=14073060, quantity=2}, -- Étoffe de Laine
            {itemID=14073063, quantity=1}, -- Étoffe de Lin
        },
    },
    {
        officialKey="couture_pourpoint_souple_de_rodeur",
        name="Pourpoint Souple de Rôdeur",
        outputItemID=14073262,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=2}, -- Fil
            {itemID=14073063, quantity=2}, -- Étoffe de Lin
            {itemID=14073060, quantity=1}, -- Étoffe de Laine
        },
    },
    {
        officialKey="couture_tunique_des_routes_ouvertes",
        name="Tunique des Routes Ouvertes",
        outputItemID=14073260,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=2}, -- Fil
            {itemID=14073059, quantity=1}, -- Tissu Renforcé
            {itemID=14073058, quantity=2}, -- Étoffe de Coton
        },
    },
    {
        officialKey="couture_gilet_renforce_de_milice",
        name="Gilet Renforcé de Milice",
        outputItemID=14073263,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=2}, -- Fil
            {itemID=14073059, quantity=2}, -- Tissu Renforcé
            {itemID=14073033, quantity=1}, -- Cuir Souple
        },
    },
    {
        officialKey="couture_coiffe_de_toile_epaisse",
        name="Coiffe de Toile Épaisse",
        outputItemID=14073266,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=1}, -- Fil
            {itemID=14073061, quantity=1}, -- Tissu Mélangé
        },
    },
    {
        officialKey="couture_capuchon_du_guetteur",
        name="Capuchon du Guetteur",
        outputItemID=14073264,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=1}, -- Fil
            {itemID=14073060, quantity=2}, -- Étoffe de Laine
        },
    },
    {
        officialKey="couture_bandeau_de_l_erudit",
        name="Bandeau de l'Érudit",
        outputItemID=14073267,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=1}, -- Fil
            {itemID=14073063, quantity=1}, -- Étoffe de Lin
        },
    },
    {
        officialKey="couture_capuche_en_tissu_rembourre",
        name="Capuche en Tissu Rembourré",
        outputItemID=14073265,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073054, quantity=1}, -- Fil
            {itemID=14073059, quantity=1}, -- Tissu Renforcé
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
        },
    },
    {
        officialKey="forge_lingot_d_acier",
        name="Lingot d'Acier",
        outputItemID=14072996,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072827, quantity=1}, -- Charbon
            {itemID=14072525, quantity=4}, -- Minerais d'Acier
        },
    },
    {
        officialKey="forge_lingot_de_cuivre",
        name="Lingot de Cuivre",
        outputItemID=14072997,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072827, quantity=1}, -- Charbon
            {itemID=14072526, quantity=4}, -- Minerais de Cuivre
        },
    },
    {
        officialKey="forge_fil_de_cuivre",
        name="Fil de Cuivre",
        outputItemID=14073524,
        outputQuantity=4,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072997, quantity=1}, -- Lingot de Cuivre
        },
    },
    {
        officialKey="forge_vis_en_cuivre",
        name="Vis en Cuivre",
        outputItemID=14072842,
        outputQuantity=6,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072997, quantity=1}, -- Lingot de Cuivre
        },
    },
    {
        officialKey="forge_plaque_en_acier",
        name="Plaque en Acier",
        outputItemID=14072999,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072996, quantity=2}, -- Lingot d'Acier
        },
    },
    {
        officialKey="forge_cuirasse_d_acier_brut",
        name="Cuirasse d'Acier Brut",
        outputItemID=14073271,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=2}, -- Plaque en Acier
            {itemID=14072996, quantity=2}, -- Lingot d'Acier
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
        },
    },
    {
        officialKey="forge_armure_rivetee_du_garde",
        name="Armure Rivetée du Garde",
        outputItemID=14073269,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=1}, -- Plaque en Acier
            {itemID=14072996, quantity=2}, -- Lingot d'Acier
            {itemID=14073032, quantity=1}, -- Bandes de Cuir
        },
    },
    {
        officialKey="forge_plastron_du_bastion",
        name="Plastron du Bastion",
        outputItemID=14073270,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=1}, -- Plaque en Acier
            {itemID=14072997, quantity=2}, -- Lingot de Cuivre
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
        },
    },
    {
        officialKey="forge_cuirasse_mixte_d_avant_garde",
        name="Cuirasse Mixte d'Avant-Garde",
        outputItemID=14073268,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=2}, -- Plaque en Acier
            {itemID=14073036, quantity=1}, -- Cuir Lourd
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
        },
    },
    {
        officialKey="forge_heaume_integral",
        name="Heaume Intégral",
        outputItemID=14073274,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072996, quantity=2}, -- Lingot d'Acier
            {itemID=14073001, quantity=4}, -- Limaille de Cuivre
        },
    },
    {
        officialKey="forge_casque_a_nasal_du_fantassin",
        name="Casque à Nasal du Fantassin",
        outputItemID=14073273,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072997, quantity=1}, -- Lingot de Cuivre
            {itemID=14073001, quantity=4}, -- Limaille de Cuivre
        },
    },
    {
        officialKey="forge_grand_heaume_du_rempart",
        name="Grand Heaume du Rempart",
        outputItemID=14073275,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072996, quantity=1}, -- Lingot d'Acier
            {itemID=14073001, quantity=4}, -- Limaille de Cuivre
        },
    },
    {
        officialKey="forge_casque_renforce_de_legion",
        name="Casque Renforcé de Légion",
        outputItemID=14073272,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=1}, -- Plaque en Acier
            {itemID=14073001, quantity=2}, -- Limaille de Cuivre
            {itemID=14073032, quantity=1}, -- Bandes de Cuir
        },
    },
    {
        officialKey="tanneur_cuir_souple",
        name="Cuir Souple",
        outputItemID=14073033,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072527, quantity=1}, -- Alun de Roche
            {itemID=14072551, quantity=1}, -- Peau de Gibier
            {itemID=14073034, quantity=1}, -- Chaux Vive
        },
    },
    {
        officialKey="tanneur_cuir_lourd",
        name="Cuir Lourd",
        outputItemID=14073036,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072527, quantity=1}, -- Alun de Roche
            {itemID=14072551, quantity=2}, -- Peau de Gibier
            {itemID=14072556, quantity=1}, -- Cire d'Abeille Brute
        },
    },
    {
        officialKey="tanneur_bandes_de_cuir",
        name="Bandes de Cuir",
        outputItemID=14073032,
        outputQuantity=4,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072527, quantity=2}, -- Alun de Roche
            {itemID=14073036, quantity=1}, -- Cuir Lourd
        },
    },
    {
        officialKey="tanneur_veste_de_cuir_renforce",
        name="Veste de Cuir Renforcé",
        outputItemID=14073276,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073036, quantity=2}, -- Cuir Lourd
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="tanneur_capeline_de_cuir_durci",
        name="Capeline de Cuir Durci",
        outputItemID=14073278,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073061, quantity=1}, -- Tissu Mélangé
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
            {itemID=14073035, quantity=1}, -- Teinture en Broux de Noix
        },
    },
    {
        officialKey="tanneur_gants_en_cuir_epais",
        name="Gants en Cuir Épais",
        outputItemID=14073280,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073036, quantity=1}, -- Cuir Lourd
            {itemID=14073032, quantity=1}, -- Bandes de Cuir
        },
    },
    {
        officialKey="tanneur_gants_renforces",
        name="Gants Renforcés",
        outputItemID=14073279,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073033, quantity=2}, -- Cuir Souple
            {itemID=14073059, quantity=1}, -- Tissu Renforcé
        },
    },
    {
        officialKey="tanneur_cape_de_voyageur_endurci",
        name="Cape de Voyageur Endurci",
        outputItemID=14073286,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073033, quantity=4}, -- Cuir Souple
            {itemID=14073032, quantity=1}, -- Bandes de Cuir
            {itemID=14073061, quantity=1}, -- Tissu Mélangé
        },
    },
    {
        officialKey="tanneur_cape_de_peaux",
        name="Cape de Peaux",
        outputItemID=14073285,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073033, quantity=4}, -- Cuir Souple
            {itemID=14073032, quantity=2}, -- Bandes de Cuir
            {itemID=14073060, quantity=1}, -- Étoffe de Laine
        },
    },
    {
        officialKey="tanneur_ceinture_a_outils_en_cuir",
        name="Ceinture à Outils en Cuir",
        outputItemID=14073284,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073036, quantity=1}, -- Cuir Lourd
            {itemID=14073033, quantity=1}, -- Cuir Souple
        },
    },
    {
        officialKey="tanneur_ceinture_de_force",
        name="Ceinture de Force",
        outputItemID=14073283,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073036, quantity=1}, -- Cuir Lourd
            {itemID=14073032, quantity=4}, -- Bandes de Cuir
        },
    },
    {
        officialKey="tanneur_bottes_de_cuir",
        name="Bottes de Cuir",
        outputItemID=14073281,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073033, quantity=1}, -- Cuir Souple
            {itemID=14072556, quantity=1}, -- Cire d'Abeille Brute
        },
    },
    {
        officialKey="tanneur_bottes_du_pisteur",
        name="Bottes du Pisteur",
        outputItemID=14073282,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073036, quantity=1}, -- Cuir Lourd
            {itemID=14072556, quantity=1}, -- Cire d'Abeille Brute
        },
    },
    {
        officialKey="cuisinier_ragout_reconfortant",
        name="Ragoût Réconfortant",
        outputItemID=14073293,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072553, quantity=2}, -- Viande de Gibier
            {itemID=14073020, quantity=2}, -- Légumes du Matin
            {itemID=14072836, quantity=1}, -- Sel de Roche
        },
    },
    {
        officialKey="cuisinier_plat_du_marcheur",
        name="Plat du Marcheur",
        outputItemID=14073294,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072553, quantity=1}, -- Viande de Gibier
            {itemID=14073019, quantity=1}, -- Farine de Froment
            {itemID=14073018, quantity=1}, -- Graisse de Porc
        },
    },
    {
        officialKey="cuisinier_souffle_des_hautes_brises",
        name="Soufflé des Hautes Brises",
        outputItemID=14073297,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073019, quantity=2}, -- Farine de Froment
            {itemID=14072555, quantity=1}, -- Miel des Forêts
            {itemID=14072548, quantity=4}, -- Oignon Sauvage
        },
    },
    {
        officialKey="cuisinier_tourte_des_racines",
        name="Tourte des Racines",
        outputItemID=14073298,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073019, quantity=1}, -- Farine de Froment
            {itemID=14073020, quantity=2}, -- Légumes du Matin
            {itemID=14073018, quantity=1}, -- Graisse de Porc
        },
    },
    {
        officialKey="cuisinier_potage_des_eaux_claires",
        name="Potage des Eaux Claires",
        outputItemID=14073295,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073020, quantity=3}, -- Légumes du Matin
            {itemID=14072836, quantity=1}, -- Sel de Roche
            {itemID=14072547, quantity=1}, -- Baies de Genièvre
        },
    },
    {
        officialKey="cuisinier_brochette_du_brasier_doux",
        name="Brochette du Brasier Doux",
        outputItemID=14073296,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072553, quantity=2}, -- Viande de Gibier
            {itemID=14072547, quantity=1}, -- Baies de Genièvre
            {itemID=14073018, quantity=1}, -- Graisse de Porc
        },
    },
    {
        officialKey="alchimiste_elixir_de_vie_i",
        name="Elixir de Vie I",
        outputItemID=14073288,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072531, quantity=4}, -- Lys des Rosées
            {itemID=14072537, quantity=2}, -- Mousse Chatoyante
        },
    },
    {
        officialKey="alchimiste_elixir_de_maitrise_i",
        name="Elixir de Maîtrise I",
        outputItemID=14073292,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072538, quantity=4}, -- Sauge de Bleuée
            {itemID=14072537, quantity=2}, -- Mousse Chatoyante
        },
    },
    {
        officialKey="alchimiste_elixir_de_vigueur_i",
        name="Elixir de Vigueur I",
        outputItemID=14073291,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072534, quantity=2}, -- Chardon de Plaie-de-Nuit
            {itemID=14072529, quantity=2}, -- Corolle de Dorevan
        },
    },
    {
        officialKey="alchimiste_elixir_de_vitesse_i",
        name="Elixir de Vitesse I",
        outputItemID=14073287,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072533, quantity=2}, -- Rose d'Antimoine
            {itemID=14072529, quantity=4}, -- Corolle de Dorevan
        },
    },
    {
        officialKey="alchimiste_elixir_de_protection_physique_i",
        name="Elixir de Protection : Physique I",
        outputItemID=14073290,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072532, quantity=2}, -- Primevère de Vitriol
            {itemID=14072531, quantity=2}, -- Lys des Rosées
        },
    },
    {
        officialKey="alchimiste_elixir_de_protection_magique_i",
        name="Elixir de Protection : Magique I",
        outputItemID=14073289,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072537, quantity=2}, -- Mousse Chatoyante
            {itemID=14072543, quantity=4}, -- Ombelle d'Argent
        },
    },
    {
        officialKey="ingenieur_valve_en_laiton",
        name="Valve en Laiton",
        outputItemID=14073043,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073052, quantity=4}, -- Boulons et Écrous
            {itemID=14072999, quantity=1}, -- Plaque en Acier
        },
    },
    {
        officialKey="ingenieur_plaque_de_pression",
        name="Plaque de Pression",
        outputItemID=14073042,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=1}, -- Plaque en Acier
            {itemID=14073524, quantity=1}, -- Fil de Cuivre
        },
    },
    {
        officialKey="ingenieur_piston_simple",
        name="Piston Simple",
        outputItemID=14073041,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073040, quantity=2}, -- Rouages et Ressorts
            {itemID=14073053, quantity=1}, -- Engrenages et Courroies
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_defense_i_physique",
        name="Mécanisme de Défense I : Physique",
        outputItemID=14073302,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073041, quantity=1}, -- Piston Simple
            {itemID=14073042, quantity=2}, -- Plaque de Pression
            {itemID=14073040, quantity=4}, -- Rouages et Ressorts
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_defense_i_magique",
        name="Mécanisme de Défense I : Magique",
        outputItemID=14073301,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073043, quantity=1}, -- Valve en Laiton
            {itemID=14073042, quantity=2}, -- Plaque de Pression
            {itemID=14073040, quantity=4}, -- Rouages et Ressorts
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_vision_1_0_i",
        name="Mécanisme de Vision 1.0 I",
        outputItemID=14073300,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073053, quantity=4}, -- Engrenages et Courroies
            {itemID=14073041, quantity=1}, -- Piston Simple
            {itemID=14072842, quantity=2}, -- Vis en Cuivre
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_vision_2_0_i",
        name="Mécanisme de Vision 2.0 I",
        outputItemID=14073299,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073053, quantity=4}, -- Engrenages et Courroies
            {itemID=14073041, quantity=1}, -- Piston Simple
            {itemID=14072842, quantity=2}, -- Vis en Cuivre
        },
    },
    {
        officialKey="ingenieur_mecanisme_d_attaque_i_physique",
        name="Mécanisme d'Attaque I : Physique",
        outputItemID=14073303,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073052, quantity=4}, -- Boulons et Écrous
            {itemID=14073043, quantity=1}, -- Valve en Laiton
            {itemID=14073524, quantity=2}, -- Fil de Cuivre
        },
    },
    {
        officialKey="ingenieur_mecanisme_d_attaque_i_magique",
        name="Mécanisme d'Attaque I : Magique",
        outputItemID=14073304,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14073052, quantity=4}, -- Boulons et Écrous
            {itemID=14073043, quantity=1}, -- Valve en Laiton
            {itemID=14073524, quantity=2}, -- Fil de Cuivre
        },
    },
    {
        officialKey="couture_etoffe_de_lin_de_skoliag",
        name="Etoffe de Lin de Skoliag",
        outputItemID=14073057,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073066, quantity=4}, -- Lin de Skoliag
        },
    },
    {
        officialKey="couture_etoffe_de_laine_de_skoliag",
        name="Etoffe de Laine de Skoliag",
        outputItemID=14073055,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073064, quantity=4}, -- Laine de Skoliag
        },
    },
    {
        officialKey="couture_tissus_melanges_de_skoliag",
        name="Tissus Mélangés de Skoliag",
        outputItemID=14073065,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073066, quantity=2}, -- Lin de Skoliag
            {itemID=14073064, quantity=2}, -- Laine de Skoliag
        },
    },
    {
        officialKey="couture_robe_de_givre_runique",
        name="Robe de Givre Runique",
        outputItemID=14073369,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073065, quantity=3}, -- Tissus Mélangés de Skoliag
            {itemID=14073027, quantity=1}, -- Pierre Gravée de Runes
            {itemID=14072545, quantity=2}, -- Givre Condensé
        },
    },
    {
        officialKey="couture_casaque_de_veine_blanche",
        name="Casaque de Veine Blanche",
        outputItemID=14073367,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073065, quantity=3}, -- Tissus Mélangés de Skoliag
            {itemID=14073029, quantity=2}, -- Bandes de Cuir des Géants
            {itemID=14073057, quantity=1}, -- Étoffe de Lin de Skoliag
        },
    },
    {
        officialKey="couture_capuche_de_l_il_boreal",
        name="Capuche de l'Œil Boréal",
        outputItemID=14073361,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073055, quantity=2}, -- Étoffe de Laine de Skoliag
            {itemID=14073056, quantity=1}, -- Fil teint en Marron
        },
    },
    {
        officialKey="couture_heaume_de_peau_rime",
        name="Heaume de Peau-Rime",
        outputItemID=14073362,
        outputQuantity=1,
        profession="Couturier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073028, quantity=1}, -- Morceau de Cuir Titanien
            {itemID=14073065, quantity=2}, -- Tissus Mélangés de Skoliag
            {itemID=14073056, quantity=2}, -- Fil teint en Marron
        },
    },
    {
        officialKey="forge_cuirasse_du_mur_de_glace",
        name="Cuirasse du Mur de Glace",
        outputItemID=14073366,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073005, quantity=3}, -- Plaque en Skodelite
            {itemID=14073003, quantity=1}, -- Lingot de Fer Noir
            {itemID=14072998, quantity=4}, -- Clous en Fer Noir
        },
    },
    {
        officialKey="forge_plastron_du_froid_enchaine",
        name="Plastron du Froid Enchaîné",
        outputItemID=14073365,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073005, quantity=2}, -- Plaque en Skodelite
            {itemID=14073029, quantity=2}, -- Bandes de Cuir des Géants
            {itemID=14073006, quantity=2}, -- Fil de Fer Noir
        },
    },
    {
        officialKey="forge_casque_de_l_hiver_immobile",
        name="Casque de l'Hiver Immobile",
        outputItemID=14073364,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073002, quantity=2}, -- Lingot de Skodelite
            {itemID=14073007, quantity=4}, -- Limaille de Fer Noir
            {itemID=14072545, quantity=1}, -- Givre Condensé
        },
    },
    {
        officialKey="forge_bassinet_du_souffle_pale",
        name="Bassinet du Souffle Pâle",
        outputItemID=14073363,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073005, quantity=1}, -- Plaque en Skodelite
            {itemID=14073007, quantity=4}, -- Limaille de Fer Noir
            {itemID=14073028, quantity=1}, -- Morceau de Cuir Titanien
        },
    },
    {
        officialKey="forge_lingot_de_skodelite",
        name="Lingot de Skodelite",
        outputItemID=14073002,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072530, quantity=4}, -- Minerais de Skodelite
        },
    },
    {
        officialKey="forge_plaque_de_skodelite",
        name="Plaque de Skodelite",
        outputItemID=14073005,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073002, quantity=2}, -- Lingot de Skodelite
        },
    },
    {
        officialKey="forge_lingot_de_fer_noir",
        name="Lingot de Fer Noir",
        outputItemID=14073003,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072528, quantity=4}, -- Minerais de Fer Noir
        },
    },
    {
        officialKey="forge_fil_de_fer_noir",
        name="Fil de Fer Noir",
        outputItemID=14073006,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073003, quantity=1}, -- Lingot de Fer Noir
        },
    },
    {
        officialKey="forge_clous_en_fer_noir",
        name="Clous en Fer Noir",
        outputItemID=14072998,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073003, quantity=1}, -- Lingot de Fer Noir
        },
    },
    {
        officialKey="tanneur_cape_lourde_de_skoliag",
        name="Cape Lourde de Skoliag",
        outputItemID=14073360,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073026, quantity=2}, -- Cuir Lourd des Géants
            {itemID=14073029, quantity=2}, -- Bandes de Cuir des Géants
            {itemID=14072557, quantity=1}, -- Cire Hivernale
        },
    },
    {
        officialKey="tanneur_gants_resistants_de_skoliag",
        name="Gants Résistants de Skoliag",
        outputItemID=14073359,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073031, quantity=1}, -- Cuir Souple des Géants
            {itemID=14073029, quantity=1}, -- Bandes de Cuir des Géants
        },
    },
    {
        officialKey="tanneur_bottes_en_cuir_de_skoliag",
        name="Bottes en Cuir de Skoliag",
        outputItemID=14073357,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073031, quantity=2}, -- Cuir Souple des Géants
            {itemID=14073030, quantity=1}, -- Teinture aux Marrons
        },
    },
    {
        officialKey="tanneur_ceinture_lourde_de_skoliag",
        name="Ceinture Lourde de Skoliag",
        outputItemID=14073358,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073029, quantity=1}, -- Bandes de Cuir des Géants
            {itemID=14073028, quantity=1}, -- Morceau de Cuir Titanien
        },
    },
    {
        officialKey="tanneur_bandes_de_cuir_des_geants",
        name="Bandes de Cuir des Géants",
        outputItemID=14073029,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073031, quantity=2}, -- Cuir Souple des Géants
        },
    },
    {
        officialKey="tanneur_cuir_souple_des_geants",
        name="Cuir Souple des Géants",
        outputItemID=14073031,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072552, quantity=2}, -- Peau de Gibier Skolagien
        },
    },
    {
        officialKey="tanneur_cuir_lourd_des_geants",
        name="Cuir Lourd des Géants",
        outputItemID=14073026,
        outputQuantity=1,
        profession="Tanneur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072552, quantity=4}, -- Peau de Gibier Skolagien
        },
    },
    {
        officialKey="cuisinier_bouillon_du_fjord",
        name="Bouillon du Fjord",
        outputItemID=14073352,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073024, quantity=1}, -- Lait de Chèvre des Montagne
            {itemID=14072550, quantity=2}, -- Racine de Njordford
            {itemID=14072554, quantity=1}, -- Viande de Gibier Skolagien
        },
    },
    {
        officialKey="cuisinier_pain_noir_du_chasseur",
        name="Pain Noir du Chasseur",
        outputItemID=14073353,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073021, quantity=2}, -- Farine de Seigle Noir
            {itemID=14073022, quantity=1}, -- Beurre Salé de Skoliag
            {itemID=14072542, quantity=2}, -- Poudre d'Aile de Givre Animée
        },
    },
    {
        officialKey="cuisinier_viande_fumee_de_skoliag",
        name="Viande Fumée de Skoliag",
        outputItemID=14073354,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072554, quantity=1}, -- Viande de Gibier Skolagien
            {itemID=14073023, quantity=1}, -- Huile de Baleine
            {itemID=14072836, quantity=1}, -- Sel de Roche
        },
    },
    {
        officialKey="cuisinier_ragout_des_hautes_glaces",
        name="Ragoût des Hautes Glaces",
        outputItemID=14073355,
        outputQuantity=1,
        profession="Cuisinier",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072554, quantity=4}, -- Viande de Gibier Skolagien
            {itemID=14072550, quantity=4}, -- Racine de Njordford
            {itemID=14072549, quantity=4}, -- Baies d'Argousier
        },
    },
    {
        officialKey="alchimiste_elixir_de_soin_de_skoliag",
        name="Elixir de Soin de Skoliag",
        outputItemID=14073348,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072539, quantity=2}, -- Sève de Vie
            {itemID=14072540, quantity=4}, -- Lichen de Runavik
            {itemID=14072920, quantity=1}, -- Fiole Gravée
        },
    },
    {
        officialKey="alchimiste_elixir_de_vigueur_de_skoliag",
        name="Elixir de Vigueur de Skoliag",
        outputItemID=14073349,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072546, quantity=1}, -- Souffle Tellurique
            {itemID=14072544, quantity=2}, -- Écorce de Skard
            {itemID=14072920, quantity=1}, -- Fiole Gravée
        },
    },
    {
        officialKey="alchimiste_elixir_de_defenses_de_skoliag",
        name="Elixir de Défenses de Skoliag",
        outputItemID=14073350,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072536, quantity=2}, -- Ambre du Fjord
            {itemID=14072535, quantity=2}, -- Chèvrefeuille de l'Hermite
            {itemID=14072920, quantity=1}, -- Fiole Gravée
        },
    },
    {
        officialKey="alchimiste_elixir_du_froid_blanc",
        name="Elixir du Froid Blanc",
        outputItemID=14073351,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14072541, quantity=2}, -- Lys de Glace d'Hudra
            {itemID=14072545, quantity=4}, -- Givre Condensé
            {itemID=14072920, quantity=1}, -- Fiole Gravée
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_puissance_titanien",
        name="Mécanisme de Puissance Titanien",
        outputItemID=14073344,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073044, quantity=1}, -- Vilebrequin en Skodelite
            {itemID=14073047, quantity=1}, -- Cardan de Transmission
            {itemID=14073049, quantity=2}, -- Ressort de Compression
        },
    },
    {
        officialKey="ingenieur_mecanisme_du_combattant_titanien",
        name="Mécanisme du Combattant Titanien",
        outputItemID=14073345,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073041, quantity=1}, -- Piston Simple
            {itemID=14073046, quantity=2}, -- Tuyauterie Isolée
            {itemID=14073048, quantity=1}, -- Brûleur à Huile de Pin
        },
    },
    {
        officialKey="ingenieur_mecanisme_d_endurance_titanien",
        name="Mécanisme d'Endurance Titanien",
        outputItemID=14073346,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073045, quantity=1}, -- Soupape à Vapeur de Skard
            {itemID=14073049, quantity=2}, -- Ressort de Compression
            {itemID=14072998, quantity=4}, -- Clous en Fer Noir
        },
    },
    {
        officialKey="ingenieur_mecanisme_de_vitalite_titanien",
        name="Mécanisme de Vitalité Titanien",
        outputItemID=14073347,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073046, quantity=1}, -- Tuyauterie Isolée
            {itemID=14073048, quantity=1}, -- Brûleur à Huile de Pin
            {itemID=14073006, quantity=1}, -- Fil de Fer Noir
        },
    },
    {
        officialKey="ingenieur_tuyauterie_isolee",
        name="Tuyauterie Isolée",
        outputItemID=14073046,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073005, quantity=1}, -- Plaque en Skodelite
            {itemID=14073052, quantity=4}, -- Boulons et Écrous
        },
    },
    {
        officialKey="ingenieur_soupape_a_vapeur_de_skard",
        name="Soupape à Vapeur de Skard",
        outputItemID=14073045,
        outputQuantity=1,
        profession="Ingénieur",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073003, quantity=1}, -- Lingot de Fer Noir
            {itemID=14073006, quantity=1}, -- Fil de Fer Noir
            {itemID=14073053, quantity=1}, -- Engrenages et Courroies
        },
    },
    {
        officialKey="forge_vilebrequin_en_skodelite",
        name="Vilebrequin en Skodelite",
        outputItemID=14073044,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Moyen",
        difficultyMinimum=8,
        materials={
            {itemID=14073002, quantity=2}, -- Lingot de Skodelite
            {itemID=14073052, quantity=4}, -- Boulons et Écrous
            {itemID=14072998, quantity=4}, -- Clous en Fer Noir
        },
    },
    {
        officialKey="forge_fiole",
        name="Fiole",
        outputItemID=14072843,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14073735, quantity=1}, -- Verre
            {itemID=14072827, quantity=1}, -- Charbon
        },
    },
    {
        officialKey="forge_fiole_gravé",
        name="Fiole Gravée",
        outputItemID=14072920,
        outputQuantity=1,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=5,
        materials={
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14072996, quantity=1}, -- Lingot d'Acier
            {itemID=14072827, quantity=1}, -- Charbon
        },
    },
    {
        officialKey="forge_outils_crochetage",
        name="Outils de Crochetage",
        outputItemID=14072807,
        outputQuantity=4,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14072996, quantity=1}, -- Lingot d'Acier
            {itemID=14072827, quantity=1}, -- Charbon
        },
    },
    {
        officialKey="forge_outils_crochetage_renforce",
        name="Outils de Crochetage Renforcé",
        outputItemID=14072963,
        outputQuantity=4,
        profession="Forgeron",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072999, quantity=1}, -- Plaque en Acier
            {itemID=14072827, quantity=1}, -- Charbon
        },
    },
    {
        officialKey="forge_charbon",
        name="Charbon",
        outputItemID=14072827,
        outputQuantity=8,
        profession="Forgeron",
        difficulty="Basique",
        difficultyMinimum=0,
        materials={
            {itemID=14076445, quantity=1}, -- Planche de Bois
        },
    },
    {
        officialKey="alchimiste_chaux_vive",
        name="Chaux Vive",
        outputItemID=14073034,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072836, quantity=4}, -- Sel de Roche
            {itemID=14072843, quantity=1}, -- Fiole
            {itemID=14073505, quantity=1}, -- Vodka Amoréenne
        },
    },
    {
        officialKey="alchimiste_eau_benite",
        name="Eau Bénite du Temple",
        outputItemID=14073341,
        outputQuantity=1,
        profession="Alchimiste",
        difficulty="Mineur",
        difficultyMinimum=5,
        materials={
            {itemID=14072836, quantity=4}, -- Sel de Roche
            {itemID=14073734, quantity=1}, -- Eau
            {itemID=14073155, quantity=1}, -- Jeton de Foi
        },
    },
}
