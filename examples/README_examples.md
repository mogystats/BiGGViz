# BiGGViz Example Scripts

This folder contains reproducible scripts that generate annotation tables and supporting analyses for BiGGViz workflows.

## `makeEcCoreAnnotationTables.m`

Generates rich example annotation tables for the BiGG `e_coli_core` model.

The script creates two separate annotation tables:

1. A reaction annotation table for reaction-reaction network visualization.
2. A metabolite annotation table for metabolite-metabolite network visualization.

Each table contains 20 entries and includes example columns for annotation-driven visualization, tooltip display, labeling, and Cytoscape export.

## Output files

The script writes the generated annotation tables to:

```text
data/annotations/
```

## `makeRBCOxidativeDemandAnnotationTable.m`

Generates the reaction annotation table used in the `iAB_RBC_283` antioxidant-demand case study. The script compares the baseline parsimonious solution with a representative model-defined GTHPi demand condition while retaining at least 99% of baseline maximum NaKt flux. It adds fluxes, flux changes, FVA ranges, required-reaction flags, response classes, pathway annotations, and node-size values for BiGGViz.

Output:

```text
data/annotations/iAB_RBC_283_oxidative_demand_reaction_annotations.csv
```

## `makeRBCGTHPiDoseResponseFigure.m`

Runs the complementary dose-response analysis used in Figure 2D of the manuscript. This plot is generated outside BiGGViz: the minimum GTHPi demand is increased across the calibrated feasible range, and parsimonious ME2 and G6PDH2r/GND fluxes are recorded.

Outputs:

```text
data/annotations/rbc_gthpi_dose_response.csv
docs/figures/rbc_gthpi_dose_response.pdf
docs/figures/Figure2D_GTHPi_dose_response.svg
```

Both RBC scripts require the COBRA Toolbox and a compatible LP solver. Run them from MATLAB after initializing the COBRA Toolbox, for example:

```matlab
run('examples/makeRBCOxidativeDemandAnnotationTable.m')
run('examples/makeRBCGTHPiDoseResponseFigure.m')
```
