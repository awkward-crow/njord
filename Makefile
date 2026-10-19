NIX = nix develop -c
R = $(NIX) Rscript -e
DEMOS = $(wildcard inst/demos/*.R)

.PHONY: document check readme articles demos

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
