%% makeRBCOxidativeDemandAnnotationTable.m
% Generate a reaction annotation CSV comparing the unmodified baseline model
% with a representative model-defined glutathione-peroxidase demand condition
% in iAB-RBC-283.

initCobraToolbox;

clearvars;

naKtRetentionPercentage = 99;
stressFraction = 0.75;
fluxTolerance = 1e-7;

scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptPath);
end

[~, folderName] = fileparts(scriptDir);
if strcmpi(folderName, 'examples') || strcmpi(folderName, 'example')
    repoRoot = fileparts(scriptDir);
else
    repoRoot = scriptDir;
end

modelPath = fullfile(repoRoot, 'data', 'models', 'mat', 'iAB_RBC_283.mat');
outDir = fullfile(repoRoot, 'data', 'annotations');
outFile = fullfile(outDir, ...
    'iAB_RBC_283_oxidative_demand_reaction_annotations.csv');

requiredFunctions = {'changeObjective', 'changeRxnBounds', 'findRxnIDs', ...
    'fluxVariability', 'optimizeCbModel', 'printRxnFormula'};
for i = 1:numel(requiredFunctions)
    if exist(requiredFunctions{i}, 'file') ~= 2
        error('Required COBRA function is unavailable: %s. Initialize the COBRA Toolbox first.', ...
            requiredFunctions{i});
    end
end

if exist(modelPath, 'file') ~= 2
    error('Model file not found: %s', modelPath);
end

loadedData = load(modelPath);
if isfield(loadedData, 'iAB_RBC_283')
    model = loadedData.iAB_RBC_283;
else
    loadedFields = fieldnames(loadedData);
    structFields = loadedFields(structfun(@isstruct, loadedData));
    if numel(structFields) ~= 1
        error('Could not identify a unique COBRA model structure in %s.', modelPath);
    end
    model = loadedData.(structFields{1});
end

requiredModelFields = {'S', 'lb', 'ub', 'c', 'rxns'};
for i = 1:numel(requiredModelFields)
    if ~isfield(model, requiredModelFields{i})
        error('The model is missing required field: %s.', requiredModelFields{i});
    end
end

numReactions = numel(model.rxns);
if size(model.S, 2) ~= numReactions || numel(model.lb) ~= numReactions || ...
        numel(model.ub) ~= numReactions || numel(model.c) ~= numReactions
    error('Reaction-level model fields do not have consistent dimensions.');
end

reactionIds = {'NaKt', 'GTHPi', 'GTHOr', 'ME2', 'G6PDH2r', ...
    'GND', 'FUM', 'FUMtr'};
reactionIndices = zeros(size(reactionIds));
for i = 1:numel(reactionIds)
    reactionIndices(i) = findRxnIDs(model, reactionIds{i});
    if reactionIndices(i) == 0
        error('Required reaction not found in the model: %s.', reactionIds{i});
    end
end

idxNaKt = reactionIndices(1);
idxGTHPi = reactionIndices(2);
idxGTHOr = reactionIndices(3);
idxME2 = reactionIndices(4);
idxG6PDH2r = reactionIndices(5);
idxGND = reactionIndices(6);
idxFUM = reactionIndices(7);
idxFUMtr = reactionIndices(8);

baselineModel = changeObjective(model, 'NaKt');
baselineSolution = optimizeCbModel(baselineModel, 'max', 'one');
assertOptimalSolution(baselineSolution, 'baseline pFBA');

referenceModel = changeRxnBounds(baselineModel, 'NaKt', ...
    (naKtRetentionPercentage / 100) * baselineSolution.f, 'l');
referenceModel = changeObjective(referenceModel, 'GTHPi');
referenceSolution = optimizeCbModel(referenceModel, 'max');
assertOptimalSolution(referenceSolution, 'GTHPi feasibility reference');

baselineGTHPi = baselineSolution.x(idxGTHPi);
maximumGTHPi = referenceSolution.f;
if maximumGTHPi <= baselineGTHPi + fluxTolerance
    error(['The maximum GTHPi flux at %g%% NaKt retention (%g) does not ', ...
        'exceed the baseline pFBA GTHPi flux (%g).'], ...
        naKtRetentionPercentage, maximumGTHPi, baselineGTHPi);
end

stress75GTHPi = baselineGTHPi + ...
    stressFraction * (maximumGTHPi - baselineGTHPi);
if stress75GTHPi <= baselineGTHPi + fluxTolerance
    error(['The calibrated oxidative demand (%g) does not exceed the baseline ', ...
        'GTHPi flux (%g). Increase stressFraction or revise the calibration.'], ...
        stress75GTHPi, baselineGTHPi);
end
if stress75GTHPi > maximumGTHPi + fluxTolerance || ...
        stress75GTHPi > baselineModel.ub(idxGTHPi) + fluxTolerance
    error('The calibrated oxidative demand exceeds the GTHPi upper bound.');
end

stressModel = changeRxnBounds(baselineModel, 'GTHPi', stress75GTHPi, 'l');
stressSolution = optimizeCbModel(stressModel, 'max', 'one');
assertOptimalSolution(stressSolution, '75% glutathione-peroxidase-demand pFBA');
if abs(stressSolution.x(idxGTHPi) - stress75GTHPi) > fluxTolerance
    error(['The representative GTHPi lower bound is not binding: ', ...
        'bound = %g, pFBA flux = %g.'], ...
        stress75GTHPi, stressSolution.x(idxGTHPi));
end
minimumRetainedNaKt = (naKtRetentionPercentage / 100) * baselineSolution.f;
if stressSolution.f < minimumRetainedNaKt - fluxTolerance
    error(['The representative condition retains less than %g%% of the ', ...
        'baseline maximum NaKt flux.'], naKtRetentionPercentage);
end

[FVA_Baseline_Min, FVA_Baseline_Max] = fluxVariability( ...
    baselineModel, naKtRetentionPercentage, 'max', baselineModel.rxns, 0, 1);
[FVA_Stress75_Min, FVA_Stress75_Max] = fluxVariability( ...
    stressModel, naKtRetentionPercentage, 'max', stressModel.rxns, 0, 1);

Flux_Baseline = double(baselineSolution.x(:));
Flux_Stress75 = double(stressSolution.x(:));
FVA_Baseline_Min = double(FVA_Baseline_Min(:));
FVA_Baseline_Max = double(FVA_Baseline_Max(:));
FVA_Stress75_Min = double(FVA_Stress75_Min(:));
FVA_Stress75_Max = double(FVA_Stress75_Max(:));

assertFluxInsideFVA(Flux_Baseline, FVA_Baseline_Min, ...
    FVA_Baseline_Max, fluxTolerance, 'baseline');
assertFluxInsideFVA(Flux_Stress75, FVA_Stress75_Min, ...
    FVA_Stress75_Max, fluxTolerance, '75% glutathione-peroxidase demand');

DeltaFlux = Flux_Stress75 - Flux_Baseline;
AbsDeltaFlux = abs(DeltaFlux);
DeltaAbsFlux = abs(Flux_Stress75) - abs(Flux_Baseline);
changed = AbsDeltaFlux > fluxTolerance;
NodeSize = zeros(size(AbsDeltaFlux));
if any(changed)
    maxAbsDeltaFlux = max(AbsDeltaFlux(changed));
    NodeSize(changed) = 4 + 12 * ...
        AbsDeltaFlux(changed) / maxAbsDeltaFlux;
end
ResponseClass = classifyResponses(Flux_Baseline, ...
    Flux_Stress75, fluxTolerance);
Required_Baseline = intervalExcludesZero(FVA_Baseline_Min, ...
    FVA_Baseline_Max, fluxTolerance);
Required_Stress75 = intervalExcludesZero(FVA_Stress75_Min, ...
    FVA_Stress75_Max, fluxTolerance);

ReactionKey = string(model.rxns(:));
Name = getStringField(model, 'rxnNames', ReactionKey, numReactions);
PathwayKey = getPathwayKeys(model, numReactions);
FormulaKey = string(printRxnFormula(model, 'rxnAbbrList', model.rxns, ...
    'printFlag', false, 'lineChangeFlag', false));
FormulaKey = strtrim(FormulaKey(:));
GeneAssociation = getStringField(model, 'grRules', strings(numReactions, 1), ...
    numReactions);
Evidence = repmat("iAB-RBC-283 model metadata; COBRA pFBA/FVA; model-defined GTHPi demand", ...
    numReactions, 1);

if numel(FormulaKey) ~= numReactions
    error('Reaction formula generation returned an unexpected number of values.');
end

reactionAnnotations = table(ReactionKey, Name, PathwayKey, FormulaKey, ...
    GeneAssociation, Flux_Baseline, Flux_Stress75, DeltaFlux, ...
    AbsDeltaFlux, DeltaAbsFlux, FVA_Baseline_Min, FVA_Baseline_Max, ...
    FVA_Stress75_Min, FVA_Stress75_Max, Required_Baseline, ...
    Required_Stress75, ResponseClass, Evidence, NodeSize);

if height(reactionAnnotations) ~= numReactions || ...
        numel(unique(reactionAnnotations.ReactionKey)) ~= numReactions
    error('The annotation table must contain one unique row per model reaction.');
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end
writetable(reactionAnnotations, outFile, 'Encoding', 'UTF-8');

g6pdContainsZero = ~Required_Stress75(idxG6PDH2r);
g6pdKnockoutModel = changeRxnBounds(stressModel, 'G6PDH2r', 0, 'b');
g6pdKnockoutSolution = optimizeCbModel(g6pdKnockoutModel, 'max');
g6pdKnockoutOptimal = isOptimalSolution(g6pdKnockoutSolution);
if g6pdKnockoutOptimal
    g6pdObjectiveLoss = stressSolution.f - g6pdKnockoutSolution.f;
else
    g6pdObjectiveLoss = Inf;
end
g6pdRestrictionIndicated = ~g6pdContainsZero || ...
    ~g6pdKnockoutOptimal || g6pdObjectiveLoss > fluxTolerance;

fprintf('Wrote reaction annotations: %s\n', outFile);
fprintf('Baseline NaKt optimum: %.9g\n', baselineSolution.f);
fprintf('Baseline pFBA GTHPi flux (D0): %.9g\n', baselineGTHPi);
fprintf('Maximum GTHPi at %g%% of baseline NaKt: %.9g\n', ...
    naKtRetentionPercentage, maximumGTHPi);
fprintf(['Applied %g%% baseline-to-capacity GTHPi lower bound ', ...
    '(D75): %.9g\n'], 100 * stressFraction, stress75GTHPi);
fprintf('Stress75 NaKt optimum: %.9g (%.6g%% of baseline)\n', ...
    stressSolution.f, 100 * stressSolution.f / baselineSolution.f);
fprintf('Stress75 GTHPi lower bound binding: true\n');
fprintf('Stress75 G6PDH2r FVA interval: [%.9g, %.9g]\n', ...
    FVA_Stress75_Min(idxG6PDH2r), FVA_Stress75_Max(idxG6PDH2r));
fprintf('G6PDH2r restriction indicated by diagnostics: %s\n', ...
    string(g6pdRestrictionIndicated));

keyIndices = [idxNaKt, idxGTHPi, idxGTHOr, idxME2, idxG6PDH2r, ...
    idxGND, idxFUM, idxFUMtr];
fprintf('\nKey reaction diagnostics:\n');
for i = 1:numel(keyIndices)
    idx = keyIndices(i);
    fprintf(['  %-8s baseline=% .9g stress75=% .9g ', ...
        'baselineFVA=[% .9g, % .9g] stress75FVA=[% .9g, % .9g] ', ...
        'requiredBaseline=%s requiredStress75=%s\n'], ...
        model.rxns{idx}, Flux_Baseline(idx), Flux_Stress75(idx), ...
        FVA_Baseline_Min(idx), FVA_Baseline_Max(idx), ...
        FVA_Stress75_Min(idx), FVA_Stress75_Max(idx), ...
        string(Required_Baseline(idx)), string(Required_Stress75(idx)));
end


function assertOptimalSolution(solution, label)
    if ~isOptimalSolution(solution) || ~isfield(solution, 'x') || ...
            isempty(solution.x) || any(~isfinite(solution.x)) || ...
            ~isfield(solution, 'f') || ~isfinite(solution.f)
        error('Optimization failed for %s.', label);
    end
end


function tf = isOptimalSolution(solution)
    tf = isstruct(solution) && isfield(solution, 'stat') && ...
        isequal(solution.stat, 1);
end


function assertFluxInsideFVA(flux, minFlux, maxFlux, tolerance, label)
    if numel(flux) ~= numel(minFlux) || numel(flux) ~= numel(maxFlux)
        error('FVA dimensions do not match the %s flux vector.', label);
    end
    invalid = flux < minFlux - tolerance | flux > maxFlux + tolerance;
    if any(invalid)
        error('%d %s flux values fall outside their FVA intervals.', ...
            sum(invalid), label);
    end
end


function required = intervalExcludesZero(minFlux, maxFlux, tolerance)
    required = minFlux > tolerance | maxFlux < -tolerance;
end


function values = getStringField(model, fieldName, fallback, expectedLength)
    if isfield(model, fieldName) && numel(model.(fieldName)) == expectedLength
        values = strtrim(string(model.(fieldName)(:)));
        values(ismissing(values)) = "";
    else
        values = string(fallback(:));
    end
end


function pathways = getPathwayKeys(model, numReactions)
    pathways = repmat("Unassigned", numReactions, 1);
    if ~isfield(model, 'subSystems') || numel(model.subSystems) ~= numReactions
        return;
    end

    for i = 1:numReactions
        value = model.subSystems{i};
        if isempty(value)
            continue;
        elseif iscell(value)
            value = strjoin(string(value), '; ');
        else
            value = string(value);
        end
        value = strtrim(value);
        if ~ismissing(value) && value ~= ""
            pathways(i) = value;
        end
    end
end


function classes = classifyResponses(baselineFlux, stressFlux, tolerance)
    baselineActive = abs(baselineFlux) > tolerance;
    stressActive = abs(stressFlux) > tolerance;
    deltaMagnitude = abs(stressFlux) - abs(baselineFlux);

    classes = repmat("Unchanged", numel(baselineFlux), 1);
    classes(~baselineActive & stressActive) = "Activated";
    classes(baselineActive & ~stressActive) = "Inactivated";

    bothActive = baselineActive & stressActive;
    reversed = bothActive & sign(baselineFlux) ~= sign(stressFlux);
    classes(reversed) = "Reversed";

    comparable = bothActive & ~reversed;
    classes(comparable & deltaMagnitude > tolerance) = "Increased";
    classes(comparable & deltaMagnitude < -tolerance) = "Decreased";
end
