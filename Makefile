R = nix develop -c Rscript -e

.PHONY: document check readme articles

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
