BIOLINK=master

ro-classes.ttl: properties-as-class-hierarchy.rq
	robot merge -I 'http://purl.obolibrary.org/obo/ro.owl' -I 'http://purl.obolibrary.org/obo/bspo.owl' query --use-graphs true --query properties-as-class-hierarchy.rq $@

biolink-model.ttl:
	curl -L "https://raw.githubusercontent.com/biolink/biolink-model/$(BIOLINK)/biolink-model.ttl" -o $@.tmp
	sed -E 's/<https:\/\/w3id.org\/biolink\/vocab\/([^[:space:]][^[:space:]]*):/<http:\/\/purl.obolibrary.org\/obo\/\1_/g' $@.tmp >$@

biolink-slots.ttl: biolink-model.ttl
	arq -q --data=$< --query=slots-as-class-hierarchy.rq >$@

probs.tsv: biolink-model.ttl
	arq -q --data=$< --query=slots-to-mappings.rq --results=tsv \
	| tail -n +2 \
	| sed -E 's/<|>//g' \
	| sed 's/"//g' \
	| sed 's/https:\/\/w3id.org\/biolink\/vocab\//biolink:/' \
	| sed 's/http:\/\/purl.obolibrary.org\/obo\//obo:/' \
	| sed 's/\|/\t/g' \
	| grep 'obo:' | grep -v 'SIO' | grep -v 'WIKIDATA' | grep -v 'ORPHA' >$@

ontology.ttl: ro-classes.ttl biolink-slots.ttl
	robot merge -i ro-classes.ttl -i biolink-slots.ttl -o $@

biolink-boom: ontology.ttl probs.tsv prefixes.yaml
	rm -rf rhea-boom &&\
	boomer --ptable probs.tsv --ontology $< --window-count 20 --runs 100 --prefixes prefixes.yaml --output $@ --exhaustive-search-limit 50 --restrict-output-to-prefixes=obo --restrict-output-to-prefixes=biolink

JSONS=$(wildcard biolink-boom/*.json)
PNGS=$(patsubst %.json, %.png, $(JSONS))

biolink-boom/%.json: biolink-boom

%.dot: %.json
	og2dot.js -s biolink-ro-style.json $< >$@

%.png: %.dot
	dot $< -Tpng -Grankdir=BT >$@

pngs: $(PNGS)
