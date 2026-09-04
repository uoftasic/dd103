# Lab 02 — RTL becomes gates
# Runs inside hpretl/iic-osic-tools:2026.08 (Yosys 0.68, graphviz 2.43, cairosvg 2.9.0).
#
#   make          the two pictures of fulladder, plus their sizes
#   make bigger   the same two pictures of ripple4 — the second one is the point
#   make png      SVG -> PNG, only if you need a raster
#   make sizes    reprint the canvas size of every SVG in results/
#   make clean    delete results/, keep sources

RES := results

.PHONY: all bigger png sizes clean

all: | $(RES)
	yosys show.ys | tee $(RES)/show.log
	@$(MAKE) --no-print-directory sizes

## bigger — why this lab draws gates for one adder and not four
bigger: | $(RES)
	yosys bigger.ys | tee $(RES)/bigger.log
	@$(MAKE) --no-print-directory sizes

## png — graphviz SVG is already scalable; use this only for slides
png:
	@for f in $(RES)/*.svg; do \
	  cairosvg $$f -o $${f%.svg}.png --output-width 1200; \
	  echo "wrote $${f%.svg}.png"; \
	done

## sizes — the number that decides whether a diagram was worth drawing
sizes:
	@echo ""
	@echo "=============================================================="
	@echo " DIAGRAM CANVAS SIZES  (graphviz points; 72 pt = 1 inch)"
	@echo "=============================================================="
	@for f in $(RES)/*.svg; do \
	  printf "%-34s %s\n" "$$f" "$$(grep -m1 -oE 'width=\"[0-9]+pt\" height=\"[0-9]+pt\"' $$f)"; \
	done

$(RES):
	@mkdir -p $(RES)

clean:
	rm -f $(RES)/*.svg $(RES)/*.png $(RES)/*.dot $(RES)/*.log $(RES)/*.v
