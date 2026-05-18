# BiGGViz

**Version:** 1.0.0  
**Authors:** Shu-Liang Yu and Rachael Hageman Blair  
**Maintainer:** Shu-Liang Yu

BiGGViz is a MATLAB App for interactive visualization and annotation-driven exploration of BiGG/COBRA metabolic models. It supports reaction-reaction and metabolite-metabolite network construction, user-supplied annotation overlays, FBA flux visualization, node coloring and sizing, label selection, pathway highlighting, neighborhood exploration, topology-aware filtering, and export to PNG, PDF, interactive HTML, and Cytoscape-ready node/edge tables.

## Features

- Load COBRA-compatible BiGG models from MAT or SBML/XML files.
- Generate reaction-reaction and metabolite-metabolite network views.
- Overlay user-supplied reaction or metabolite annotation tables.
- Color nodes by pathway, reversibility, gene association, FBA flux, compartment, or metabolite class.
- Size nodes by degree, FBA flux, or user-supplied `NodeSize` values.
- Label nodes by selected model or annotation-table fields.
- Highlight pathways and inspect local graph neighborhoods.
- Filter networks by maximum degree and minimum connected-component size.
- Export current views to PNG, PDF, interactive HTML, or Cytoscape-ready Excel tables.

## Repository structure

```text
BiGGViz/
├─ README.md
├─ VERSION
├─ src/
│  ├─ BiGGViz.mlapp
│  ├─ writeNetworkHTML.m
│  ├─ parseAnnotations.m
│  ├─ buildRxnRxnGraph.m
│  ├─ buildMetMetGraph.m
│  └─ assets/
│     └─ launch.png
├─ examples/
│  ├─ makeEcCoreAnnotationTables.m
│  └─ README_examples.md
├─ data/
│  ├─ models/
│  └─ annotations/
└─ doc/
   ├─ GettingStarted.html
   └─ figures/
```

## Requirements

- MATLAB with App Designer support
- COBRA Toolbox
- A COBRA-compatible LP solver for FBA-related features
- Google Chrome for Capture View PDF export
- Cytoscape, optional, for downstream use of exported node and edge tables

## Installation

Clone or download the repository, then open MATLAB and change to the project root:

```matlab
cd('<path-to-BiGGViz>')
addpath(genpath(fullfile(pwd, 'src')))
```

Launch the app:

```matlab
BiGGViz
```

For FBA-related features, initialize COBRA Toolbox and set an LP solver before launching or using FBA-based options:

```matlab
initCobraToolbox(false)
changeCobraSolver('glpk', 'LP')
```

Use a different COBRA-compatible solver if preferred.

## Example data

Place BiGG model files under:

```text
data/models/
```

Place annotation tables under:

```text
data/annotations/
```

Example rich annotation tables for the BiGG `e_coli_core` model can be generated with:

```matlab
run('examples/makeEcCoreAnnotationTables.m')
```

This creates reaction and metabolite annotation tables under `data/annotations/`.

## Annotation tables

Reaction annotation tables should include a reaction identifier column such as:

```text
ReactionKey
```

Metabolite annotation tables should include a metabolite identifier column such as:

```text
MetaboliteKey
```

Additional columns are retained after parsing and can be used for tooltip display, node labels, node sizing when supported, and Cytoscape node-table export. Common annotation columns include:

```text
PathwayKey
Compartment
MetaboliteClass
NodeSize
FBAFlux
FVA_Min
FVA_Max
KnockoutGrowthRatio
StatisticalScore
ExternalDataset
```

If `FBAFlux` is supplied in a reaction annotation table, BiGGViz uses the provided values for FBA-based coloring or sizing. If `FBAFlux` is not supplied, BiGGViz can compute FBA flux values internally through the COBRA Toolbox when the FBA Flux option is selected.

If `NodeSize` is supplied in an annotation table, BiGGViz exposes **Node Size** as an option in the **Size By** dropdown menu, allowing user-defined quantitative values to control node scaling.

## Getting started

A step-by-step tutorial is provided here:

```text
doc/GettingStarted.html
```

The editable MATLAB Live Script is:

```text
doc/GettingStarted.mlx
```

The tutorial demonstrates workflows using the `iAB_RBC_283` red blood cell model and the `e_coli_core` model with user-supplied reaction and metabolite annotation tables.

## Export options

BiGGViz supports the following Capture View outputs:

- PNG
- PDF
- Interactive HTML
- Cytoscape Tables (`.xlsx`)

The Cytoscape workbook contains:

- `Nodes`: node identifiers and node-level annotations.
- `Edges`: source-target network edges.

## Versioning

The current release is BiGGViz v1.0.0. The project root includes a plain-text `VERSION` file containing the current version number.

## Citation

The BiGGViz manuscript has been submitted to the Great Plains 2026 conference proceedings. Citation details will be updated if the manuscript is accepted and published.

For now, please cite the GitHub repository or the archived release associated with the version used.

## License

BiGGViz is open-source software. The source code is made available under the MIT License. See the `LICENSE` file for details.
