#!/usr/bin/env python3
"""Generates destinations.json and validates it with the same rules as ContentValidator.swift."""
import json, re, sys, unicodedata, os

countries = [
    dict(id="jp", name="Japan", region="eastAsia", latitude=36.2, longitude=138.25, unlockAfter=[], isPlusCollection=False),
    dict(id="it", name="Italy", region="europe", latitude=41.87, longitude=12.57, unlockAfter=[], isPlusCollection=False),
    dict(id="fr", name="France", region="europe", latitude=46.6, longitude=2.2, unlockAfter=["it"], isPlusCollection=False),
    dict(id="us", name="United States", region="northAmerica", latitude=39.8, longitude=-98.6, unlockAfter=["jp"], isPlusCollection=False),
    dict(id="eg", name="Egypt", region="africa", latitude=26.8, longitude=30.8, unlockAfter=["fr"], isPlusCollection=False),
    dict(id="br", name="Brazil", region="southAmerica", latitude=-14.2, longitude=-51.9, unlockAfter=["us"], isPlusCollection=False),
]

def D(id, name, c, lat, lon, diff, clues, fact, aliases=()):
    return dict(id=id, name=name, countryID=c, latitude=lat, longitude=lon, difficulty=diff,
                clues=[dict(kind=k, text=t) for k, t in clues], fact=fact, aliases=list(aliases))

destinations = [
  # Japan
  D("jp-tokyo","Tokyo","jp",35.68,139.69,1,[
    ("history","Until 1868 this city went by a different name, Edo."),
    ("food","Its fish market moved from Tsukiji to Toyosu in 2018."),
    ("culture","A scramble crossing here can see thousands of pedestrians cross at once."),
    ("geography","It is the most populous metropolitan area on Earth."),
    ("landmark","Home to the Skytree and the capital of Japan."),
  ],"Greater Tokyo is home to roughly 37 million people — more than all of Canada."),
  D("jp-kyoto","Kyoto","jp",35.01,135.77,2,[
    ("history","It served as the imperial capital for more than a thousand years."),
    ("nature","A famous bamboo grove grows in its Arashiyama district."),
    ("culture","Geiko and maiko still perform in its Gion district."),
    ("landmark","Thousands of vermilion torii gates climb the hill at Fushimi Inari."),
    ("geography","A short bullet-train ride from Osaka in Japan's Kansai region."),
  ],"The city was largely spared bombing in WWII, which is why so many wooden temples survive."),
  D("jp-fuji","Mount Fuji","jp",35.36,138.73,1,[
    ("nature","An active stratovolcano that last erupted in 1707."),
    ("culture","Hokusai made it the star of thirty-six famous woodblock prints."),
    ("geography","Five lakes ring its northern base."),
    ("history","It became a UNESCO World Heritage cultural site in 2013."),
    ("landmark","At 3,776 m, it is the tallest mountain in Japan."),
  ],"The official climbing season is only about two months long, in July and August.", aliases=["Fuji","Fujisan"]),
  # Italy
  D("it-rome","Rome","it",41.90,12.50,1,[
    ("history","Legend says twin brothers raised by a she-wolf founded it."),
    ("food","Cacio e pepe and carbonara are its signature pastas."),
    ("geography","An entire independent country sits inside this city."),
    ("culture","Tossing a coin into the Trevi Fountain supposedly guarantees a return trip."),
    ("landmark","The Colosseum stands in the heart of Italy's capital."),
  ],"Around €1.5 million in coins are thrown into the Trevi Fountain every year; they go to charity.", aliases=["Roma"]),
  D("it-venice","Venice","it",45.44,12.32,1,[
    ("geography","It is built across 118 small islands in a lagoon."),
    ("history","For centuries it was the capital of a powerful maritime republic."),
    ("culture","Elaborate masks are worn at its pre-Lent carnival."),
    ("nature","Seasonal 'acqua alta' floods regularly cover its main square."),
    ("landmark","Gondolas glide under the Rialto Bridge on its Grand Canal."),
  ],"There are no cars in the historic center — even ambulances and fire engines are boats.", aliases=["Venezia"]),
  D("it-florence","Florence","it",43.77,11.26,2,[
    ("history","The Medici banking family ruled here for generations."),
    ("culture","Many call it the birthplace of the Renaissance."),
    ("food","A famous thick T-bone steak is named after this city."),
    ("landmark","Brunelleschi's enormous brick dome crowns its cathedral."),
    ("geography","The capital of Tuscany, on the Arno river."),
  ],"Michelangelo's David has stood here since 1504; the original moved indoors in 1873.", aliases=["Firenze"]),
  # France
  D("fr-paris","Paris","fr",48.86,2.35,1,[
    ("history","Its old medieval fortress, the Bastille, was stormed in 1789."),
    ("culture","The world's most visited art museum sits beside the Seine here."),
    ("food","Bakeries here compete each year to make the city's best baguette."),
    ("geography","Its streets are numbered in 20 spiralling arrondissements."),
    ("landmark","The Eiffel Tower rises over the capital of France."),
  ],"The Eiffel Tower was meant to be temporary and was nearly dismantled in 1909."),
  D("fr-nice","Nice","fr",43.70,7.27,2,[
    ("history","It only became part of its current country in 1860."),
    ("food","Socca, a chickpea pancake, is its classic street food."),
    ("culture","Matisse spent much of his later life painting here."),
    ("landmark","The Promenade des Anglais curves along its pebble beach."),
    ("geography","The largest city on the French Riviera, near Monaco."),
  ],"The Promenade des Anglais was named for English winter visitors who paid to build it in the 1820s."),
  D("fr-mont-saint-michel","Mont-Saint-Michel","fr",48.64,-1.51,3,[
    ("nature","Some of the largest tidal ranges in Europe surround it."),
    ("history","It withstood a siege for decades during the Hundred Years' War."),
    ("culture","A Benedictine abbey has crowned this rock for over a millennium."),
    ("geography","A tidal island just off the coast where Normandy meets Brittany."),
    ("landmark","A walled village climbs up to a Gothic abbey on a rocky islet in France."),
  ],"Only around 30 people live on the island, but it receives millions of visitors a year.", aliases=["Mont Saint Michel","Saint-Michel"]),
  # United States
  D("us-new-york","New York City","us",40.71,-74.01,1,[
    ("history","The Dutch called it New Amsterdam."),
    ("food","Its thin, foldable slices made one style of pizza world-famous."),
    ("culture","Broadway theatres are clustered around its Times Square."),
    ("geography","Its five boroughs include Brooklyn and Manhattan."),
    ("landmark","The Statue of Liberty welcomes ships into its harbor."),
  ],"More than 700 languages are spoken in the city, making it one of the most linguistically diverse places on Earth.", aliases=["New York","NYC"]),
  D("us-grand-canyon","Grand Canyon","us",36.11,-112.11,1,[
    ("nature","Rock layers here expose nearly two billion years of geologic history."),
    ("history","John Wesley Powell led the first known expedition down its river in 1869."),
    ("culture","The Havasupai people have lived in its side canyons for centuries."),
    ("geography","Carved by the Colorado River in northern Arizona."),
    ("landmark","A mile-deep gorge that became a U.S. National Park in 1919."),
  ],"The North and South Rims are only about 16 km apart, but a 350 km drive separates them."),
  D("us-new-orleans","New Orleans","us",29.95,-90.07,2,[
    ("history","It joined the United States through the Louisiana Purchase."),
    ("food","Beignets, gumbo and po'boys are local staples."),
    ("culture","Many consider it the birthplace of jazz."),
    ("landmark","Wrought-iron balconies line its French Quarter."),
    ("geography","A Louisiana city near the mouth of the Mississippi, famous for Mardi Gras."),
  ],"Much of the city lies below sea level, so many of its cemeteries are built above ground.", aliases=["NOLA"]),
  # Egypt
  D("eg-cairo","Cairo","eg",30.04,31.24,1,[
    ("history","Its Al-Azhar university, founded in 970, is one of the oldest still running."),
    ("food","Koshari, a mix of lentils, rice and pasta, is its favorite street food."),
    ("culture","Khan el-Khalili has been a bustling bazaar since the 14th century."),
    ("geography","The largest city in the Arab world, on the banks of the Nile."),
    ("landmark","The Pyramids of Giza stand on the edge of Egypt's capital."),
  ],"The Great Pyramid was the tallest human-made structure on Earth for nearly 4,000 years."),
  D("eg-luxor","Luxor","eg",25.69,32.64,2,[
    ("history","As ancient Thebes, it was the capital at the height of the New Kingdom."),
    ("culture","Hot-air balloons drift over its west bank at sunrise."),
    ("nature","It sits in one of the sunniest, driest places on the planet."),
    ("landmark","The Valley of the Kings, with Tutankhamun's tomb, is just across the river."),
    ("geography","A Nile city in Upper Egypt home to Karnak Temple."),
  ],"It's sometimes called the world's greatest open-air museum."),
  D("eg-alexandria","Alexandria","eg",31.20,29.92,2,[
    ("history","Founded by a Macedonian conqueror in 331 BC."),
    ("culture","Its ancient library was the greatest center of learning in the classical world."),
    ("food","Seafood from its harbor is grilled fresh along the Corniche."),
    ("landmark","One of the Seven Wonders, a great lighthouse, once stood at its harbor."),
    ("geography","Egypt's second-largest city, on the Mediterranean coast."),
  ],"Cleopatra, the last active ruler of Ptolemaic Egypt, ruled from this city."),
  # Brazil
  D("br-rio","Rio de Janeiro","br",-22.91,-43.17,1,[
    ("history","It was the capital of the Portuguese Empire for 13 years."),
    ("culture","Its samba schools spend all year preparing for one parade."),
    ("nature","One of the world's largest urban forests, Tijuca, grows inside it."),
    ("geography","Sugarloaf Mountain rises over its Guanabara Bay."),
    ("landmark","Christ the Redeemer watches over Copacabana from Corcovado."),
  ],"Its name means 'River of January' — Portuguese explorers mistook the bay for a river's mouth.", aliases=["Rio"]),
  D("br-manaus","Manaus","br",-3.12,-60.02,3,[
    ("history","A rubber boom made it one of the richest cities in South America around 1900."),
    ("culture","It built an opulent opera house in the middle of the rainforest."),
    ("nature","Two rivers of different colors flow side by side without mixing nearby."),
    ("geography","The largest city in the heart of the Amazon rainforest."),
    ("landmark","The 'Meeting of the Waters' gateway city in Brazil's Amazonas state."),
  ],"The dark Rio Negro and sandy Solimões run side by side for about 6 km before they mix."),
  D("br-iguazu","Iguazu Falls","br",-25.69,-54.44,2,[
    ("nature","It is made up of around 275 separate drops."),
    ("history","Eleanor Roosevelt reportedly said Niagara looked poor by comparison."),
    ("culture","Its name means 'big water' in the Guarani language."),
    ("landmark","Its most powerful section is called the Devil's Throat."),
    ("geography","A vast waterfall system on the border with Argentina."),
  ],"In flood season, the falls can carry around 6,500 cubic meters of water per second.", aliases=["Iguacu Falls","Iguassu Falls","Foz do Iguacu"]),
]

# Gazetteer: decoy guesses (never answers). name, country, lat, lon
G = """Osaka|Japan|34.69|135.50
Sapporo|Japan|43.06|141.35
Hiroshima|Japan|34.39|132.46
Nara|Japan|34.68|135.80
Seoul|South Korea|37.57|126.98
Busan|South Korea|35.18|129.08
Beijing|China|39.90|116.40
Shanghai|China|31.23|121.47
Hong Kong|China|22.32|114.17
Taipei|Taiwan|25.03|121.57
Bangkok|Thailand|13.76|100.50
Hanoi|Vietnam|21.03|105.85
Singapore|Singapore|1.35|103.82
Manila|Philippines|14.60|120.98
Jakarta|Indonesia|-6.21|106.85
Bali|Indonesia|-8.34|115.09
Delhi|India|28.61|77.21
Mumbai|India|19.08|72.88
Agra|India|27.18|78.01
Kathmandu|Nepal|27.72|85.32
Dubai|United Arab Emirates|25.20|55.27
Istanbul|Turkey|41.01|28.98
Jerusalem|Israel|31.77|35.21
Petra|Jordan|30.33|35.44
Milan|Italy|45.46|9.19
Naples|Italy|40.85|14.27
Pisa|Italy|43.72|10.40
Turin|Italy|45.07|7.69
Lyon|France|45.76|4.84
Marseille|France|43.30|5.37
Bordeaux|France|44.84|-0.58
Monaco|Monaco|43.74|7.42
Madrid|Spain|40.42|-3.70
Barcelona|Spain|41.39|2.17
Seville|Spain|37.39|-5.98
Lisbon|Portugal|38.72|-9.14
London|United Kingdom|51.51|-0.13
Edinburgh|United Kingdom|55.95|-3.19
Dublin|Ireland|53.35|-6.26
Amsterdam|Netherlands|52.37|4.90
Brussels|Belgium|50.85|4.35
Berlin|Germany|52.52|13.40
Munich|Germany|48.14|11.58
Vienna|Austria|48.21|16.37
Zurich|Switzerland|47.38|8.54
Prague|Czechia|50.08|14.44
Budapest|Hungary|47.50|19.04
Athens|Greece|37.98|23.73
Santorini|Greece|36.39|25.46
Dubrovnik|Croatia|42.65|18.09
Copenhagen|Denmark|55.68|12.57
Stockholm|Sweden|59.33|18.07
Oslo|Norway|59.91|10.75
Reykjavik|Iceland|64.15|-21.94
Moscow|Russia|55.76|37.62
Marrakesh|Morocco|31.63|-8.01
Casablanca|Morocco|33.57|-7.59
Tunis|Tunisia|36.81|10.18
Aswan|Egypt|24.09|32.90
Giza|Egypt|30.01|31.21
Khartoum|Sudan|15.50|32.56
Addis Ababa|Ethiopia|9.03|38.74
Nairobi|Kenya|-1.29|36.82
Zanzibar|Tanzania|-6.17|39.20
Lagos|Nigeria|6.52|3.38
Accra|Ghana|5.60|-0.19
Cape Town|South Africa|-33.92|18.42
Johannesburg|South Africa|-26.20|28.05
Victoria Falls|Zimbabwe|-17.92|25.86
Los Angeles|United States|34.05|-118.24
San Francisco|United States|37.77|-122.42
Las Vegas|United States|36.17|-115.14
Chicago|United States|41.88|-87.63
Miami|United States|25.76|-80.19
Washington, D.C.|United States|38.91|-77.04
Boston|United States|42.36|-71.06
Seattle|United States|47.61|-122.33
Atlanta|United States|33.75|-84.39
Nashville|United States|36.16|-86.78
Yellowstone|United States|44.43|-110.59
Yosemite|United States|37.87|-119.54
Honolulu|United States|21.31|-157.86
Niagara Falls|Canada|43.08|-79.07
Toronto|Canada|43.65|-79.38
Vancouver|Canada|49.28|-123.12
Montreal|Canada|45.50|-73.57
Mexico City|Mexico|19.43|-99.13
Cancun|Mexico|21.16|-86.85
Havana|Cuba|23.11|-82.37
Panama City|Panama|8.98|-79.52
Bogota|Colombia|4.71|-74.07
Cartagena|Colombia|10.39|-75.48
Lima|Peru|-12.05|-77.04
Cusco|Peru|-13.53|-71.97
Machu Picchu|Peru|-13.16|-72.55
Quito|Ecuador|-0.18|-78.47
La Paz|Bolivia|-16.49|-68.12
Santiago|Chile|-33.45|-70.67
Buenos Aires|Argentina|-34.60|-58.38
Montevideo|Uruguay|-34.90|-56.16
Sao Paulo|Brazil|-23.55|-46.63
Salvador|Brazil|-12.97|-38.50
Brasilia|Brazil|-15.79|-47.88
Belem|Brazil|-1.46|-48.49
Sydney|Australia|-33.87|151.21
Melbourne|Australia|-37.81|144.96
Uluru|Australia|-25.34|131.04
Auckland|New Zealand|-36.85|174.76
Queenstown|New Zealand|-45.03|168.66"""

def slug(s): return re.sub(r"[^a-z0-9]+","-",unicodedata.normalize("NFKD",s).encode("ascii","ignore").decode().lower()).strip("-")
gazetteer = []
for line in G.splitlines():
    n,c,la,lo = line.split("|")
    gazetteer.append(dict(id="g-"+slug(c)+"-"+slug(n), name=n, countryName=c, latitude=float(la), longitude=float(lo), aliases=[]))

pack = dict(version=1, countries=countries, destinations=destinations, gazetteer=gazetteer)

# ---- validation (mirror of ContentValidator.swift) ----
def norm(s): return unicodedata.normalize("NFKD", s).encode("ascii","ignore").decode().lower().strip()
def contains_word(h, n):
    return re.search(r"(?<![a-z])"+re.escape(n)+r"(?![a-z])", h) is not None
issues=[]
cids={c["id"] for c in countries}
seen={}
for d in destinations:
    if d["countryID"] not in cids: issues.append((d["id"],"bad country"))
    if len(d["clues"])!=5: issues.append((d["id"],"clue count"))
    forb=[norm(x) for x in [d["name"]]+d["aliases"] if len(norm(x))>=3]
    for i,cl in enumerate(d["clues"]):
        t=norm(cl["text"])
        for f in forb:
            if contains_word(t,f): issues.append((d["id"],f"clue {i+1} leaks '{f}'"))
        if t in seen: issues.append((d["id"],"dup clue"))
        seen[t]=d["id"]
ids=[d["id"] for d in destinations]+[g["id"] for g in gazetteer]
if len(ids)!=len(set(ids)): issues.append(("pack","dup ids"))
for c in countries:
    if not any(d["countryID"]==c["id"] for d in destinations): issues.append((c["id"],"empty country"))
# guess-pool name collisions with answers (would make two identical entries in the picker)
dn={(norm(d["name"])) for d in destinations}
for g in gazetteer:
    if norm(g["name"]) in dn: issues.append((g["id"],"gazetteer duplicates a destination name"))
if issues:
    for i in issues: print("ISSUE", i)
    sys.exit(1)
out=os.path.join(os.path.dirname(__file__),"..","Packages","WorldTrailsCore","Sources","WorldTrailsCore","Resources","destinations.json")
with open(out,"w") as f: json.dump(pack,f,indent=2,ensure_ascii=False)
print(f"OK: {len(countries)} countries, {len(destinations)} destinations, {len(gazetteer)} decoy places -> {os.path.normpath(out)}")
