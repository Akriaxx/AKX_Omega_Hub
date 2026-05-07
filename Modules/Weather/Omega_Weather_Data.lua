-- Omega_Weather_Data.lua
-- Données de la Tempête maudite :
-- - Tableau Visual
-- - Tableau Audio
-- - Helpers pour retrouver une fourchette et tirer une émote

OmegaWeatherData = OmegaWeatherData or {}
local Data = OmegaWeatherData

-- //////////////////////////////////////////////////////////
-- Helpers
-- //////////////////////////////////////////////////////////

local function ClampRoll(value)
    value = tonumber(value) or 1
    if value < 1 then return 1 end
    if value > 100 then return 100 end
    return math.floor(value)
end

local function PickRandom(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then
        return nil
    end
    return tbl[math.random(1, #tbl)]
end

local function FindRange(tbl, roll)
    roll = ClampRoll(roll)

    if type(tbl) ~= "table" then
        return nil
    end

    for _, entry in ipairs(tbl) do
        if roll >= entry.min and roll <= entry.max then
            return entry
        end
    end

    return nil
end

-- //////////////////////////////////////////////////////////
-- Visual
-- //////////////////////////////////////////////////////////

Data.Visual = {
    {
        min = 1,
        max = 20,
        title = "Voile uniforme",
        description = "Rideau de sable homogène. Aucune profondeur perceptible.",
        emotes = {
            "Un rideau de sable s’étend sur l’horizon comme une mer figée. Les rafales forment une masse continue, sans relief ni profondeur discernable.",
            "La tempête déploie un voile dense et homogène. Rien ne s’en détache, aucune variation ne trouble la surface mouvante du sable.",
            "Le désert érige un mur de poussière uniforme. L’air lui-même semble saturé, privé de toute perspective.",
            "Le sable tourbillonne en nappes compactes, effaçant les contours et les distances. L’espace se réduit à une seule texture mouvante.",
            "Une épaisse couche de grains soulevés recouvre l’horizon. Le monde paraît aplati, sans creux ni relief apparent.",
        },
    },
    {
        min = 21,
        max = 40,
        title = "Formes équivoques",
        description = "Le rideau reste dense, mais des formes fugitives semblent parfois s’y dessiner. Rien de stable. Rien de certain.",
        emotes = {
            "Le théâtre de sable laisse apparaître une masse inclinée, dont les contours pourraient évoquer la coque d’un navire. La forme vacille, semble se briser sous une houle invisible, puis se dissout brutalement dans le sable.",
            "Une structure anguleuse se dessine brièvement dans le voile, comme une tour lointaine battue par une tempête intérieure. Elle se déforme, s’effondre sur elle-même et disparaît sans laisser de trace.",
            "Des volumes indistincts se forment et se déplacent derrière le rideau de sable. Ils semblent glisser latéralement, comme portés par une logique différente de celle du vent, avant de s’effacer soudainement.",
            "Une masse sombre traverse lentement la tempête, assez nette pour troubler l’esprit, trop instable pour être réelle. Elle se fragmente en une pluie de grains et redevient indistinguable.",
            "Une forme allongée paraît fendre le rideau, évoquant un objet massif dérivant dans une mer invisible. Elle s’incline, se disloque et se résorbe aussitôt dans l’opacité mouvante.",
        },
    },
    {
        min = 41,
        max = 60,
        title = "Présences illusoires",
        description = "Le rideau s'anime. Des mouvements prennent forme et imitent le vivant, mais rien ne persiste. Le désert altère la perception.",
        emotes = {
            "Des formes anguleuses se heurtent derrière le voile, comme si des structures invisibles entraient en collision. Au centre du chaos, une silhouette plus fine semble immobile un instant… puis se fragmente en poussière.",
            "Une masse se détache du rideau et traverse la tempête à contre-sens du vent. Son mouvement paraît intentionnel. Elle ralentit, se redresse presque… avant de se dissoudre brutalement.",
            "Les nappes de sable s’ouvrent brièvement, révélant une forme à hauteur d’homme qui paraît avancer d’un pas lent. Elle s’interrompt net, comme si elle vous avait aperçu, puis s’efface sans laisser de trace.",
            "Plusieurs volumes se déplacent dans la tempête, leurs trajectoires semblant se croiser avec une logique propre. L’un d’eux s’arrête, pivote légèrement… puis s’éparpille en une pluie de grains.",
            "Une silhouette plus petite que les autres apparaît au milieu du tumulte, figée, presque distincte. Le vent la traverse sans la briser… puis elle se fissure d’un seul coup et disparaît.",
        },
    },
    {
        min = 61,
        max = 80,
        title = "Présence manifeste",
        description = "Les illusions ne viennent plus seules. Plusieurs formes persistent simultanément dans la tempête. Le phénomène ne peut plus être ignoré.",
        emotes = {
            "Les formes brisées qui évoquaient des navires et des architectures impossibles surgissent encore dans le rideau de sable. Mais entre elles circulent désormais d'autres mouvements. Plusieurs. Trop nombreux pour être confondus avec un simple mirage.",
            "Le voile de sable se déchire par endroits. Une silhouette traverse la tempête. Puis une autre. Puis d'autres encore, disséminées dans l'opacité mouvante. Aucune ne disparaît aussi vite que les illusions d'autrefois.",
            "Au milieu des masses qui s'entrechoquent dans la tempête, plusieurs silhouettes avancent lentement. Elles se déplacent à des endroits différents du rideau, comme si quelque chose occupait réellement l'espace derrière le sable.",
            "Les illusions d'architecture continuent de naître et de mourir dans le tumulte. Mais entre ces formes gigantesques se déplacent des présences plus petites. Elles apparaissent en plusieurs points à la fois.",
            "Le théâtre de sable ne projette plus un seul mouvement isolé. Plusieurs silhouettes se déplacent dans la tempête, parfois visibles au même instant, assez longtemps pour que le doute disparaisse.",
        },
    },
    {
        min = 81,
        max = 95,
        title = "Présences tangibles",
        description = "Les formes ne sont plus lointaines. Le rideau semble devenir une frontière. Le contact visuel est direct.",
        emotes = {
            "Le manteau de sable voile la réalité d’une épaisseur presque vivante. Les formes y naissent et y dansent comme elles l’ont toujours fait — masses inclinées, architectures brisées, silhouettes mouvantes. Mais cette fois, quelque chose ne traverse pas le rideau. Quelque chose s’en approche. Lentement. Les grains se tendent vers l’extérieur, comme pressés de l’intérieur. Puis une main se dépose contre la surface mouvante. On la voit clairement. Trop longue. Trop anguleuse. Ses doigts se déforment sous la pression du sable. Elle n’a rien d’humain. Elle reste là… une seconde de trop. Puis elle se délite, grain par grain.",
            "Le théâtre de sable s’agite plus violemment que d’ordinaire. Les formes se croisent, se heurtent, se superposent. Et parmi ce tumulte, une masse se distingue en s’approchant du rideau lui-même. Le sable se creuse autour d’elle comme s’il épousait une structure solide. Une surface irrégulière, presque osseuse, se dessine à travers le voile. Elle semble observer. Immobile. Puis le vent reprend son droit et efface la forme sans explication.",
            "Des silhouettes se multiplient derrière le voile, certaines immenses, d’autres trop basses pour être naturelles. Soudain, l’une d’elles cesse de dériver avec la tempête. Elle avance à contre-vent. Le rideau de sable se tend sous sa proximité. On distingue nettement une extrémité qui vient en contact avec la surface — comme une paume posée contre une vitre invisible. Le sable épouse sa forme… puis la structure s’effondre d’un coup, redevenant poussière.",
            "La tempête ne projette plus seulement des ombres. Elle retient des formes. Plusieurs évoluent dans le tumulte, mais l’une s’approche suffisamment pour que ses contours deviennent indiscutables. Le sable s’agglutine contre une surface stable. Une main. Ou quelque chose qui en imite une. Les doigts se plient à l’envers. Les grains glissent entre des jointures impossibles. Puis tout se disperse, comme si rien n’avait jamais touché le rideau.",
            "Le voile semble respirer, se contracter sous des pressions venues de l’intérieur. Des silhouettes s’y déplacent, trop nombreuses pour être ignorées. Puis l’une d’elles s’immobilise juste derrière la surface mouvante. On distingue une forme appuyée contre le sable, suffisamment proche pour en déformer la texture. Elle ne frappe pas. Elle ne traverse pas. Elle reste là. Présente. Puis se retire lentement dans l’opacité."
        },
    },
    {
        min = 96,
        max = 99,
        title = "Marée derrière le voile",
        description = "Les présences ne sont plus isolées. Le rideau est saturé de formes multiples. La pression devient collective, presque organisée.",
        emotes = {
            "Le manteau de sable ne laisse plus entrevoir des formes isolées, mais une densité mouvante, compacte, presque continue. Des silhouettes innombrables se pressent derrière le rideau. Certaines immenses, d’autres ramassées, toutes animées d’un mouvement coordonné. Le sable se tend sous leur proximité comme sous une marée invisible.",
            "Le théâtre de sable se peuple d’une multitude. Les formes ne dansent plus au hasard : elles convergent. Des masses massives s’élèvent, des lignes semblent se former, des volumes se déplacent dans un même élan. La tempête n’est plus un chaos. Elle ressemble à une formation.",
            "Le voile est saturé de présences. Là où l’on distinguait quelques silhouettes, il y en a désormais des dizaines, peut-être plus. Elles avancent par vagues successives derrière le rideau, comme si quelque chose les poussait en avant sans jamais franchir la surface.",
            "Des structures de sable se dressent brièvement dans la tempête — pics, crêtes, élévations — comme si le désert lui-même érigeait des positions. Entre ces reliefs mouvants, des formes se déplacent en masse, trop nombreuses pour être comptées.",
            "Le sable se comprime sous une pression invisible. Le rideau vibre par endroits, non plus sous le contact d’une seule forme, mais sous celui d’une multitude. On distingue des silhouettes superposées, certaines plus hautes que les dunes, d’autres glissant en essaim à leur base. Rien ne traverse encore. Mais le voile ploie.",
        },
    },
    {
        min = 100,
        max = 100,
        title = "Rupture du Voile",
        description = "Le rideau cesse d’être une frontière stable. La tempête devient une marée verticale. Une présence colossale domine l’ensemble du chaos.",
        emotes = {
            "Le ciel disparaît entièrement derrière une marée de sable inversée. Le rideau ne sépare plus le monde de ce qu’il contient : il s’élève, se tord, se déploie vers le haut comme une vague figée dans l’instant. Des centaines de formes se pressent derrière la surface mouvante. Puis, au loin — trop vaste pour être ignorée — une silhouette domine tout le tumulte.",
            "La tempête se soulève en colonnes immenses qui se rejoignent au-dessus de l’horizon. Entre les vagues de sable saturées de présences, une masse colossale se détache. Elle dépasse les autres formes comme une forteresse ambulante. Ses contours sont irréguliers, brisés, mais sa stature est indéniable. Deux lueurs pâles s’ouvrent dans l’opacité, fixant à travers le rideau.",
            "Le voile ploie sous la pression d’une multitude en mouvement constant. Mais derrière cette armée indistincte, une forme plus vaste encore se dresse. Elle est haute comme un bâtiment effondré, large comme une muraille en marche. Le sable glisse le long de sa surface comme le long d’un monument vivant. Elle avance lentement. Chaque pas semble déplacer la tempête elle-même.",
            "Des silhouettes innombrables saturent la tempête, frappant et comprimant le rideau. Puis le sable se creuse au loin, révélant une présence gigantesque. Sa taille dépasse toute mesure humaine. Sa forme ne se dissout pas. Elle reste stable, massive, impossible. Deux lueurs brûlent dans ce qui pourrait être un visage. Elles ne clignent pas.",
            "La marée de sable monte si haut qu’elle efface toute limite entre ciel et terre. Au cœur de ce chaos vertical, une silhouette titanesque domine la scène. Elle est plus grande que les dunes, plus haute qu’une tour. Le rideau épouse sa forme sans jamais la briser. Elle avance. Lentement. Chaque mouvement fait vibrer la surface entière. Rien ne traverse encore. Mais tout comprend."
        },
    },
}

-- //////////////////////////////////////////////////////////
-- Audio
-- //////////////////////////////////////////////////////////

Data.Audio = {
    {
        min = 1,
        max = 20,
        title = "Tumulte matériel",
        description = "Impact de débris, fractures, bris cristallins. Aucun son organique identifiable.",
        emotes = {
            "Des pierres et des fragments heurtent violemment les surfaces alentour. Des planches se brisent, des morceaux se déchirent dans la rafale. Entre chaque impact résonne un tintement cristallin aigu, comme des aiguilles de verre qui éclatent contre la pierre.",
            "Le vent semble projetter des débris avec une brutalité sèche. Bois arraché, éclats de roche, plaques métalliques frappées sans relâche. À travers le vacarme, un son cristallin revient sans cesse — fragile, aigu, comme du cristal pulvérisé contre une paroi invisible.",
            "Des impacts irréguliers martèlent les structures proches. Des objets inconnus s’écrasent et se fracturent. Un grincement métallique se mêle à un éclatement aigu et presque pur, comme si des éclats de verre s’éparpillaient dans l’air."
        },
    },
    {
        min = 21,
        max = 40,
        title = "Écrasement massif",
        description = "Débris lourds, torsions structurelles, métal broyé. Toujours aucun son organique distinct.",
        emotes = {
            "Des masses lourdes s’écrasent dans la tempête. On entend le bois se tordre jusqu’à rupture, des plaques métalliques se froisser sous une pression incompréhensible. Le tintement cristallin persiste, mais plus grave, plus étouffé, comme noyé sous le poids.",
            "Quelque chose de volumineux percute les parois rocheuses à intervalles irréguliers. Des structures entières semblent céder dans le vent. Le son n’est plus seulement violent : il est massif, écrasant.",
            "Des pièces entières de matière — bois, métal, pierre — sont projetées et broyées dans la tempête. Le fracas devient continu. Le bruit cristallin aigu perce encore le tumulte, mais il semble maintenant plus dense, plus insistant."
        },
    },
    {
        min = 41,
        max = 60,
        title = "Murmures noyés",
        description = "Premiers sons organiques perceptibles, recouverts par le tumulte destructeur.",
        emotes = {
            "Sous le fracas des débris et le métal tordu, un son plus fin semble se glisser. À peine perceptible. Comme un murmure porté par le vent. Il disparaît aussitôt sous un impact violent.",
            "Entre deux chocs massifs, un son fragile s’élève — peut-être une voix, peut-être un pleur lointain. Il est aussitôt englouti par le rugissement du bois qui se brise.",
            "Le vacarme matériel domine toujours, mais parfois, derrière le fracas, un hurlement très lointain se distingue. Il ne dure qu’un instant. Puis la tempête reprend toute la place."
        },
    },
    {
        min = 61,
        max = 80,
        title = "Clameurs distinctes",
        description = "Hurlements, pleurs et rugissements émergent clairement du tumulte.",
        emotes = {
            "Les hurlements ne sont plus noyés. Ils percent le fracas avec netteté. Certains sont humains, d’autres profondément étrangers. Le vent ne les efface plus.",
            "Des pleurs et des cris se superposent aux impacts matériels. Entre eux, un rugissement grave, animal, se détache clairement du reste du tumulte.",
            "Le fracas des débris continue, mais il est désormais accompagné de sons organiques incontestables. Des voix, des gémissements, des grognements profonds, tous distincts, tous proches."
        },
    },
    {
        min = 81,
        max = 95,
        title = "Encerclement sonore",
        description = "Les sons organiques entourent complètement la position. La proximité est évidente.",
        emotes = {
            "Les hurlements ne viennent plus d’une seule direction. Ils tournent autour, proches, presque au contact. On distingue même des respirations lourdes entre deux rafales.",
            "Des bruits de déplacement encerclent la structure. Des griffures effleurent les parois, lentes, méthodiques. Entre les cris, un battement sourd semble résonner, comme un cœur massif quelque part dans la tempête.",
            "Les rugissements se répondent tout autour. Trop proches pour être ignorés. Des sons de pas irréguliers écrasent le sol à intervalles lents, sans jamais révéler leur origine."
        },
    },
    {
        min = 96,
        max = 99,
        title = "Saturation",
        description = "Hurlements proches, impacts directs, bruits anormaux et organiques massifs.",
        emotes = {
            "Des griffures raclent les parois avec insistance. Des rires brisés, gutturaux, éclatent tout près. Un hurlement surgit contre la surface même de votre abri, si proche qu’il semble vibrer dans votre poitrine.",
            "Des pas lourds martèlent le sol à proximité immédiate. Quelque chose frappe, gratte, respire derrière les murs. Des sons organiques profonds, presque liquides, se mêlent au tumulte général.",
            "La tempête devient un chœur dissonant de cris, de rires déformés, de rugissements et d’impacts. Certains sons semblent provenir d’entités bien plus vastes que le reste, leurs voix résonnant avec une profondeur anormale."
        },
    },
    {
        min = 100,
        max = 100,
        title = "Marche colossale",
        description = "Les pas du Titan dominent tout le reste.",
        emotes = {
            "Un impact colossal écrase le tumulte. Le sol vibre. Puis un second. Lent. Régulier. Chaque pas semble déplacer l’air lui-même. Le reste des cris paraît insignifiant face à cette marche monumentale.",
            "Le vacarme s’écrase soudain sous un rythme plus lourd. Un pas. Puis un autre. Chaque impact résonne jusque dans la poitrine. Quelque chose d’immense avance dans la tempête.",
            "Au milieu du chaos, un battement profond s’impose. Les pas sont espacés, colossaux. À chaque impact, l’air tremble et le sable semble se soumettre."
        },
    },   
}

-- //////////////////////////////////////////////////////////
-- Special Event
-- //////////////////////////////////////////////////////////

Data.SpecialEvents = {
    Assault = {
        min = 80,
        max = 95,
        emotes = {
            "Le rideau cède par endroits. Des formes franchissent enfin la barrière de sable. Elles ne sont plus des ombres.",
            "Le voile se déchire sous la pression. Plusieurs créatures émergent du tumulte et fondent vers vous sans hésitation.",
            "La membrane de sable se rompt. Des silhouettes passent à travers et prennent forme dans votre réalité.",
        }
    },

    OverwhelmingAssault = {
        min = 96,
        max = 99,
        emotes = {
            "Le rideau explose sous une poussée synchronisée. Des créatures surgissent en nombre, accompagnées de formes plus massives, plus anciennes, plus lentes.",
            "La tempête recrache non seulement les silhouettes déjà entrevues, mais d'autres présences plus vastes encore. Leur simple avancée écrase l'air.",
            "La barrière de sable cède brutalement. Parmi les formes qui traversent, certaines dominent les autres par leur taille et leur aura oppressive.",
        }
    }
}

-- //////////////////////////////////////////////////////////
-- API publique
-- //////////////////////////////////////////////////////////

function Data.GetVisualEntry(roll)
    return FindRange(Data.Visual, roll)
end

function Data.GetAudioEntry(roll)
    return FindRange(Data.Audio, roll)
end

function Data.GetVisualEmote(roll)
    local entry = Data.GetVisualEntry(roll)
    if not entry then return nil, nil end
    return PickRandom(entry.emotes), entry
end

function Data.GetAudioEmote(roll)
    local entry = Data.GetAudioEntry(roll)
    if not entry then return nil, nil end
    return PickRandom(entry.emotes), entry
end