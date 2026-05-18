%% makeEcCoreAnnotationTables.m
% Generate richer example annotation tables for BiGGViz using E. coli core IDs.
%
% Intended project location:
%   examples/makeEcCoreAnnotationTables.m
%
% Intended outputs:
%   data/annotations/e_coli_core_reaction_annotations_rich.xlsx
%   data/annotations/e_coli_core_metabolite_annotations_rich.xlsx
%
% Notes:
%   1. The reaction table uses ReactionKey as the first column.
%   2. The metabolite table uses MetaboliteKey as the first column.
%   3. The columns include examples of FBA/FVA summaries, knockout results,
%      statistical scores, and external analysis outputs. Values are illustrative
%      and are intended for testing BiGGViz annotation overlays, not publication.

clearvars;

%% Resolve output directory relative to this script
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    % Fallback for running sections interactively from the Editor
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptPath);
end

% If this file is saved under examples/, repoRoot is the parent folder.
[~, thisFolderName] = fileparts(scriptDir);
if strcmpi(thisFolderName, 'examples') || strcmpi(thisFolderName, 'example')
    repoRoot = fileparts(scriptDir);
else
    repoRoot = scriptDir;
end

outDir = fullfile(repoRoot, 'data', 'annotations');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Reaction-reaction annotation table, E. coli core, 20 reactions
ReactionKey = string({
    'HEX1'; 'PGI'; 'PFK'; 'FBA'; 'TPI'; ...
    'GAPD'; 'PGK'; 'PGM'; 'ENO'; 'PYK'; ...
    'LDH_D'; 'G6PDH2r'; 'PGL'; 'GND'; 'RPI'; ...
    'RPE'; 'CS'; 'ACONTa'; 'ACONTb'; 'ICDHyr'});

Name = string({
    'Hexokinase';
    'Glucose-6-phosphate isomerase';
    'Phosphofructokinase';
    'Fructose-bisphosphate aldolase';
    'Triose-phosphate isomerase';
    'Glyceraldehyde-3-phosphate dehydrogenase';
    'Phosphoglycerate kinase';
    'Phosphoglycerate mutase';
    'Enolase';
    'Pyruvate kinase';
    'D-lactate dehydrogenase';
    'Glucose-6-phosphate dehydrogenase';
    '6-phosphogluconolactonase';
    'Phosphogluconate dehydrogenase';
    'Ribose-5-phosphate isomerase';
    'Ribulose-5-phosphate 3-epimerase';
    'Citrate synthase';
    'Aconitase, citrate hydro-lyase';
    'Aconitase, aconitate hydratase';
    'Isocitrate dehydrogenase'});

PathwayKey = string({
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Fermentation'; 'Pentose Phosphate Pathway';
    'Pentose Phosphate Pathway'; 'Pentose Phosphate Pathway';
    'Pentose Phosphate Pathway'; 'Pentose Phosphate Pathway';
    'Citric Acid Cycle'; 'Citric Acid Cycle';
    'Citric Acid Cycle'; 'Citric Acid Cycle'});

EnzymeKey = string({
    'Hexokinase'; 'Glucose-6-phosphate isomerase'; '6-phosphofructokinase';
    'Fructose-bisphosphate aldolase'; 'Triose-phosphate isomerase';
    'GAPDH'; 'Phosphoglycerate kinase'; 'Phosphoglycerate mutase';
    'Enolase'; 'Pyruvate kinase'; 'D-lactate dehydrogenase';
    'Glucose-6-phosphate dehydrogenase'; '6-phosphogluconolactonase';
    '6-phosphogluconate dehydrogenase'; 'Ribose-5-phosphate isomerase';
    'Ribulose-phosphate 3-epimerase'; 'Citrate synthase'; 'Aconitase';
    'Aconitase'; 'Isocitrate dehydrogenase'});

ECNumber = string({
    '2.7.1.1'; '5.3.1.9'; '2.7.1.11'; '4.1.2.13'; '5.3.1.1';
    '1.2.1.12'; '2.7.2.3'; '5.4.2.12'; '4.2.1.11'; '2.7.1.40';
    '1.1.1.28'; '1.1.1.49'; '3.1.1.31'; '1.1.1.44'; '5.3.1.6';
    '5.1.3.1'; '2.3.3.1'; '4.2.1.3'; '4.2.1.3'; '1.1.1.42'});

GeneAssociation = string({
    'b2388'; 'b4025'; 'b3916 or b1723'; 'b2097 or b2925'; 'b3919';
    'b1779'; 'b2926'; 'b0755'; 'b2779'; 'b1854 or b1676';
    'b1380'; 'b1852'; 'b0767'; 'b2029'; 'b2914 or b4090';
    'b3386'; 'b0720'; 'b1276 or b0118'; 'b1276 or b0118'; 'b1136'});

Compartment = repmat("c", numel(ReactionKey), 1);
SubsystemSource = repmat("BiGG e_coli_core", numel(ReactionKey), 1);

% Illustrative external analysis summaries
FBAFlux = [7.48; 4.86; 7.48; 7.48; 7.48; 16.02; -16.02; -14.72; 14.72; 1.76; ...
           0.00; 4.96; 4.96; 4.96; -2.28; 2.68; 6.01; 6.01; 6.01; 6.01];
FVA_Min = FBAFlux - [0.20; 0.35; 0.10; 0.15; 0.15; 0.50; 0.50; 0.40; 0.40; 0.75; ...
                    0.00; 0.90; 0.90; 0.90; 1.10; 1.10; 0.45; 0.45; 0.45; 0.45];
FVA_Max = FBAFlux + [0.25; 0.30; 0.15; 0.15; 0.15; 0.45; 0.45; 0.35; 0.35; 0.80; ...
                    1.20; 0.85; 0.85; 0.85; 1.05; 1.05; 0.50; 0.50; 0.50; 0.50];
FluxVariabilityWidth = FVA_Max - FVA_Min;
KnockoutGrowthRatio = [0.72; 0.85; 0.18; 0.41; 0.62; 0.05; 0.08; 0.55; 0.60; 0.22; ...
                       0.97; 0.88; 0.93; 0.80; 0.76; 0.79; 0.12; 0.25; 0.25; 0.19];
EssentialityClass = strings(numel(ReactionKey),1);
EssentialityClass(KnockoutGrowthRatio < 0.10) = "Essential";
EssentialityClass(KnockoutGrowthRatio >= 0.10 & KnockoutGrowthRatio < 0.50) = "Growth-limiting";
EssentialityClass(KnockoutGrowthRatio >= 0.50) = "Non-essential";

DifferentialFlux = [1.10; -0.35; 0.92; 0.75; 0.70; 1.85; -1.70; -0.80; 0.78; 0.20; ...
                    -0.05; 0.66; 0.55; 0.48; -0.42; 0.37; 0.90; 0.82; 0.80; 0.77];
StatisticalScore = [3.5; 1.2; 4.8; 3.1; 2.7; 5.6; 5.1; 2.0; 2.2; 1.6; ...
                    0.4; 2.9; 2.5; 2.8; 1.8; 1.7; 4.1; 3.8; 3.7; 4.3];
AdjustedPValue = [0.004; 0.210; 0.0008; 0.012; 0.031; 0.0001; 0.0002; 0.080; 0.071; 0.140; ...
                  0.780; 0.018; 0.030; 0.022; 0.090; 0.110; 0.003; 0.006; 0.007; 0.002];
EvidenceLevel = string({
    'Curated + simulation'; 'Curated'; 'Curated + knockout'; 'Curated + simulation'; 'Curated';
    'Curated + knockout'; 'Curated + knockout'; 'Curated'; 'Curated'; 'Curated';
    'External fluxomics'; 'Curated + simulation'; 'Curated'; 'Curated + simulation'; 'Curated';
    'Curated'; 'Curated + knockout'; 'Curated + simulation'; 'Curated + simulation'; 'Curated + knockout'});
PubMedID = string({
    '20118174'; '20118174'; '20118174'; '20118174'; '20118174';
    '20118174'; '20118174'; '20118174'; '20118174'; '20118174';
    '25572378'; '20118174'; '20118174'; '20118174'; '20118174';
    '20118174'; '20118174'; '20118174'; '20118174'; '20118174'});
ExternalDataset = string({
    'FBA_baseline'; 'FBA_baseline'; 'KO_screen_A'; 'FVA_screen_A'; 'FVA_screen_A';
    'KO_screen_A'; 'KO_screen_A'; 'FBA_baseline'; 'FBA_baseline'; 'KO_screen_A';
    'Fluxomics_lactate'; 'PPP_stress_comparison'; 'PPP_stress_comparison'; 'PPP_stress_comparison'; 'PPP_stress_comparison';
    'PPP_stress_comparison'; 'TCA_KO_screen'; 'TCA_KO_screen'; 'TCA_KO_screen'; 'TCA_KO_screen'});
NodeSize = 5 + 8*abs(FBAFlux)./max(abs(FBAFlux));
Notes = "Illustrative rich reaction annotation for BiGGViz testing" + strings(numel(ReactionKey),1);

rxnAnno = table(ReactionKey, Name, PathwayKey, EnzymeKey, ECNumber, GeneAssociation, ...
    Compartment, SubsystemSource, FBAFlux, FVA_Min, FVA_Max, FluxVariabilityWidth, ...
    KnockoutGrowthRatio, EssentialityClass, DifferentialFlux, StatisticalScore, ...
    AdjustedPValue, EvidenceLevel, PubMedID, ExternalDataset, NodeSize, Notes);

%% Metabolite-metabolite annotation table, E. coli core, 20 metabolites
MetaboliteKey = string({
    'glc__D_c'; 'g6p_c'; 'f6p_c'; 'fdp_c'; 'dhap_c'; ...
    'g3p_c'; '13dpg_c'; '3pg_c'; '2pg_c'; 'pep_c'; ...
    'pyr_c'; 'lac__D_c'; '6pgl_c'; '6pgc_c'; 'ru5p__D_c'; ...
    'r5p_c'; 'xu5p__D_c'; 'cit_c'; 'acon_C_c'; 'icit_c'});

Name = string({
    'D-Glucose'; 'D-Glucose 6-phosphate'; 'D-Fructose 6-phosphate';
    'D-Fructose 1,6-bisphosphate'; 'Dihydroxyacetone phosphate';
    'Glyceraldehyde 3-phosphate'; '3-Phospho-D-glyceroyl phosphate';
    '3-Phospho-D-glycerate'; '2-Phospho-D-glycerate'; 'Phosphoenolpyruvate';
    'Pyruvate'; 'D-Lactate'; '6-Phospho-D-glucono-1,5-lactone';
    '6-Phospho-D-gluconate'; 'D-Ribulose 5-phosphate';
    'Alpha-D-ribose 5-phosphate'; 'D-Xylulose 5-phosphate';
    'Citrate'; 'cis-Aconitate'; 'Isocitrate'});

MetaboliteClass = string({
    'Sugar'; 'Sugar phosphate'; 'Sugar phosphate'; 'Sugar phosphate'; 'Sugar phosphate';
    'Sugar phosphate'; 'Organic acid phosphate'; 'Organic acid phosphate';
    'Organic acid phosphate'; 'Organic acid phosphate'; 'Organic acid'; 'Organic acid';
    'Sugar acid'; 'Sugar acid'; 'Sugar phosphate'; 'Sugar phosphate'; 'Sugar phosphate';
    'Organic acid'; 'Organic acid'; 'Organic acid'});

Compartment = repmat("c", numel(MetaboliteKey), 1);
PathwayContext = string({
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Gluconeogenesis'; 'Glycolysis/Gluconeogenesis';
    'Glycolysis/Fermentation'; 'Fermentation'; 'Pentose Phosphate Pathway';
    'Pentose Phosphate Pathway'; 'Pentose Phosphate Pathway';
    'Pentose Phosphate Pathway'; 'Pentose Phosphate Pathway';
    'Citric Acid Cycle'; 'Citric Acid Cycle'; 'Citric Acid Cycle'});

Formula = string({
    'C6H12O6'; 'C6H13O9P'; 'C6H13O9P'; 'C6H14O12P2'; 'C3H7O6P';
    'C3H7O6P'; 'C3H8O10P2'; 'C3H7O7P'; 'C3H7O7P'; 'C3H5O6P';
    'C3H3O3'; 'C3H5O3'; 'C6H11O9P'; 'C6H10O10P'; 'C5H9O8P';
    'C5H9O8P'; 'C5H9O8P'; 'C6H5O7'; 'C6H3O6'; 'C6H5O7'});
Charge = [0; -2; -2; -4; -2; -2; -4; -3; -3; -3; -1; -1; -2; -3; -2; -2; -2; -3; -3; -3];
CarbonCount = [6; 6; 6; 6; 3; 3; 3; 3; 3; 3; 3; 3; 6; 6; 5; 5; 5; 6; 6; 6];

% Illustrative metabolite-level external analysis summaries
ConcentrationFoldChange = [1.45; 1.28; 1.22; 1.30; 0.82; 0.86; 1.55; 1.42; 1.35; 1.18; ...
                           1.10; 0.72; 1.50; 1.47; 0.90; 0.92; 0.95; 1.25; 1.20; 1.18];
Log2FoldChange = log2(ConcentrationFoldChange);
AdjustedPValue = [0.005; 0.014; 0.019; 0.011; 0.080; 0.090; 0.002; 0.004; 0.007; 0.070; ...
                  0.120; 0.030; 0.006; 0.008; 0.200; 0.180; 0.160; 0.020; 0.025; 0.028];
CentralityScore = [0.95; 0.88; 0.84; 0.70; 0.61; 0.66; 0.73; 0.76; 0.74; 0.82; ...
                   0.91; 0.40; 0.55; 0.58; 0.52; 0.57; 0.54; 0.68; 0.64; 0.67];
MetaboliteEssentialityScore = [0.40; 0.55; 0.52; 0.47; 0.30; 0.35; 0.62; 0.58; 0.56; 0.70; ...
                               0.80; 0.20; 0.38; 0.41; 0.33; 0.36; 0.34; 0.59; 0.50; 0.61];
KnockoutPerturbationScore = [0.30; 0.48; 0.44; 0.38; 0.22; 0.25; 0.51; 0.49; 0.45; 0.60; ...
                             0.72; 0.18; 0.36; 0.39; 0.29; 0.32; 0.31; 0.53; 0.46; 0.55];
FVA_LinkedFluxSpan = [8.0; 7.2; 7.1; 6.8; 5.0; 5.2; 9.5; 9.2; 8.9; 8.3; ...
                      7.8; 2.1; 6.4; 6.6; 5.7; 5.9; 5.8; 6.9; 6.5; 6.7];
ExternalConfidence = string({
    'High'; 'High'; 'High'; 'High'; 'Moderate'; 'Moderate'; 'High'; 'High'; 'High'; 'Moderate';
    'Moderate'; 'Low'; 'High'; 'High'; 'Moderate'; 'Moderate'; 'Moderate'; 'High'; 'Moderate'; 'High'});
ExternalDataset = string({
    'Metabolomics_condition_A'; 'Metabolomics_condition_A'; 'Metabolomics_condition_A';
    'Metabolomics_condition_A'; 'Metabolomics_condition_A'; 'Metabolomics_condition_A';
    'Metabolomics_condition_A'; 'Metabolomics_condition_A'; 'Metabolomics_condition_A';
    'Metabolomics_condition_A'; 'Metabolomics_condition_A'; 'Fermentation_profile';
    'PPP_stress_metabolomics'; 'PPP_stress_metabolomics'; 'PPP_stress_metabolomics';
    'PPP_stress_metabolomics'; 'PPP_stress_metabolomics'; 'TCA_metabolomics';
    'TCA_metabolomics'; 'TCA_metabolomics'});
PubChemCID = string({
    '5793'; '5958'; '69507'; '10267'; '668'; '729'; '439191'; '724'; '59'; '1005';
    '1060'; '61503'; '439326'; '91493'; '439184'; '439167'; '439177'; '311'; '643757'; '1198'});
NodeSize = 5 + 10*CentralityScore./max(CentralityScore);
Notes = "Illustrative rich metabolite annotation for BiGGViz testing" + strings(numel(MetaboliteKey),1);

metAnno = table(MetaboliteKey, Name, MetaboliteClass, Compartment, PathwayContext, ...
    Formula, Charge, CarbonCount, ConcentrationFoldChange, Log2FoldChange, ...
    AdjustedPValue, CentralityScore, MetaboliteEssentialityScore, ...
    KnockoutPerturbationScore, FVA_LinkedFluxSpan, ExternalConfidence, ...
    ExternalDataset, PubChemCID, NodeSize, Notes);

%% Write outputs
rxnXlsx = fullfile(outDir, 'e_coli_core_reaction_annotations_rich.xlsx');
metXlsx = fullfile(outDir, 'e_coli_core_metabolite_annotations_rich.xlsx');

writetable(rxnAnno, rxnXlsx, 'Sheet', 'ReactionAnnotations');
writetable(metAnno, metXlsx, 'Sheet', 'MetaboliteAnnotations');

fprintf('Wrote reaction annotations:   %s\n', rxnXlsx);
fprintf('Wrote metabolite annotations: %s\n', metXlsx);

%% Optional quick preview
fprintf('\nReaction annotation preview:\n');
disp(rxnAnno(1:min(5,height(rxnAnno)), :));

fprintf('\nMetabolite annotation preview:\n');
disp(metAnno(1:min(5,height(metAnno)), :));
