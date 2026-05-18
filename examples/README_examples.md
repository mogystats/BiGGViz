# BiGGViz Example Scripts

This folder contains example scripts that generate reusable input files for BiGGViz workflows.

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