NIX = nix develop -c
R = $(NIX) Rscript -e
DEMOS = $(wildcard inst/demos/*.R)

.PHONY: document check readme articles demos docs clean-articles

document:
	$(R) 'devtools::document()'

check:
	$(R) 'devtools::check()'

readme: README.md
README.md: README.Rmd
	$(R) 'rmarkdown::render("README.Rmd", output_options = list(html_preview = FALSE))'

articles: $(patsubst %.Rmd,%.html,$(wildcard vignettes/articles/*.Rmd))
vignettes/articles/%.html: vignettes/articles/%.Rmd
	$(R) 'rmarkdown::render("$<")'

demos:
	$(NIX) sh -c 'for f in $(DEMOS); do echo "== $$f"; Rscript "$$f" || exit 1; done'

clean-articles:
	rm -f vignettes/articles/*.html

# docs/njord-method.md: the vignette as GitHub-flavoured markdown, figures
# in docs/figures/. Knitted from a copy outside the project against njord
# installed in a temporary library.
docs: docs/njord-method.md
docs/njord-method.md: vignettes/njord-method.Rmd $(wildcard R/*.R) $(wildcard inst/extdata/*)
	$(NIX) sh -c 'set -e; d=$$(mktemp -d); mkdir $$d/lib $$d/gfm; \
	  R CMD INSTALL --no-test-load -l $$d/lib . > $$d/install.log 2>&1; \
	  cp $< $$d/gfm/; \
	  (cd $$d/gfm && R_LIBS=$$d/lib Rscript -e "f <- rmarkdown::github_document(html_preview = FALSE); f\$$knitr\$$opts_chunk\$$fig.path <- \"figures/\"; rmarkdown::render(\"njord-method.Rmd\", output_format = f, quiet = TRUE)"); \
	  mkdir -p docs; rm -rf docs/figures.new; \
	  cp -r $$d/gfm/figures docs/figures.new; cp $$d/gfm/njord-method.md docs/; \
	  rm -rf docs/figures; mv docs/figures.new docs/figures; \
	  rm -rf $$d; echo "wrote docs/njord-method.md and docs/figures/"'
