%% makeRBCGTHPiDoseResponseFigure.m
% Generate a supplemental dose-response figure for the iAB-RBC-283 case
% study. This analysis is separate from the BiGGViz visualization workflow.

clearvars;

naKtRetentionPercentage = 99;
demandFractions = unique(sort([0:0.1:1, 0.75]));
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
figureDir = fullfile(repoRoot, 'docs', 'figures');
dataDir = fullfile(repoRoot, 'data', 'annotations');
figureFile = fullfile(figureDir, 'rbc_gthpi_dose_response.pdf');
svgFigureFile = fullfile(figureDir, 'Figure2D_GTHPi_dose_response.svg');
dataFile = fullfile(dataDir, 'rbc_gthpi_dose_response.csv');

requiredFunctions = {'changeCobraSolver', 'changeObjective', ...
    'changeRxnBounds', 'findRxnIDs', 'optimizeCbModel', 'exportgraphics'};
for i = 1:numel(requiredFunctions)
    if exist(requiredFunctions{i}, 'file') == 0
        error(['Required function is unavailable: %s. Initialize the COBRA ', ...
            'Toolbox before running this script.'], requiredFunctions{i});
    end
end

solverConfigured = changeCobraSolver('glpk', 'LP', 0);
if ~solverConfigured
    error('GLPK could not be selected as the LP solver.');
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
        error('Could not identify a unique COBRA model in %s.', modelPath);
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

reactionIds = {'NaKt', 'GTHPi', 'ME2', 'G6PDH2r', 'GND'};
reactionIndices = zeros(size(reactionIds));
for i = 1:numel(reactionIds)
    reactionIndices(i) = findRxnIDs(model, reactionIds{i});
    if reactionIndices(i) == 0
        error('Required reaction not found in the model: %s.', reactionIds{i});
    end
end

idxNaKt = reactionIndices(1);
idxGTHPi = reactionIndices(2);
idxME2 = reactionIndices(3);
idxG6PDH2r = reactionIndices(4);
idxGND = reactionIndices(5);

% D0 is taken from the parsimonious solution of the unmodified model.
baselineModel = changeObjective(model, 'NaKt');
baselineSolution = optimizeCbModel(baselineModel, 'max', 'one');
assertOptimalSolution(baselineSolution, 'baseline NaKt pFBA');
baselineNaKt = baselineSolution.f;
baselineGTHPi = baselineSolution.x(idxGTHPi);

% Dmax is the greatest GTHPi flux compatible with retaining the selected
% percentage of the baseline maximum NaKt flux.
minimumRetainedNaKt = ...
    (naKtRetentionPercentage / 100) * baselineNaKt;
calibrationModel = changeRxnBounds(baselineModel, 'NaKt', ...
    minimumRetainedNaKt, 'l');
calibrationModel = changeObjective(calibrationModel, 'GTHPi');
calibrationSolution = optimizeCbModel(calibrationModel, 'max');
assertOptimalSolution(calibrationSolution, 'GTHPi capacity calibration');
maximumGTHPi = calibrationSolution.f;

if maximumGTHPi <= baselineGTHPi + fluxTolerance
    error(['The calibrated GTHPi capacity (%g) does not exceed the ', ...
        'baseline pFBA flux (%g).'], maximumGTHPi, baselineGTHPi);
end

% Sample the baseline-to-capacity interval, not zero-to-capacity. Including
% 0.75 explicitly keeps the representative BiGGViz condition in the table.
gthpiDemand = baselineGTHPi + ...
    demandFractions * (maximumGTHPi - baselineGTHPi);
numConditions = numel(gthpiDemand);

gthpiFlux = nan(numConditions, 1);
me2Flux = nan(numConditions, 1);
g6pdh2rFlux = nan(numConditions, 1);
gndFlux = nan(numConditions, 1);
naKtFlux = nan(numConditions, 1);
gthpiBoundBinding = false(numConditions, 1);

for i = 1:numConditions
    demandModel = changeRxnBounds(baselineModel, 'GTHPi', ...
        gthpiDemand(i), 'l');
    solution = optimizeCbModel(demandModel, 'max', 'one');
    assertOptimalSolution(solution, ...
        sprintf('GTHPi demand fraction %.3g', demandFractions(i)));

    gthpiFlux(i) = solution.x(idxGTHPi);
    me2Flux(i) = solution.x(idxME2);
    g6pdh2rFlux(i) = solution.x(idxG6PDH2r);
    gndFlux(i) = solution.x(idxGND);
    naKtFlux(i) = solution.x(idxNaKt);
    gthpiBoundBinding(i) = ...
        abs(gthpiFlux(i) - gthpiDemand(i)) <= fluxTolerance;
end

if any(~gthpiBoundBinding)
    failedFractions = demandFractions(~gthpiBoundBinding);
    error('GTHPi lower bound is not binding at demand fraction(s): %s.', ...
        strjoin(compose('%.3g', failedFractions), ', '));
end
if any(naKtFlux < minimumRetainedNaKt - fluxTolerance)
    error(['At least one dose condition retains less than %g%% of the ', ...
        'baseline maximum NaKt flux.'], naKtRetentionPercentage);
end
if any(abs(g6pdh2rFlux - gndFlux) > fluxTolerance)
    error(['G6PDH2r and GND fluxes differ within the sampled dose range; ', ...
        'plot them separately rather than as one PPP response.']);
end
pppFlux = 0.5 * (g6pdh2rFlux + gndFlux);

doseResponse = table(demandFractions(:), gthpiDemand(:), gthpiFlux, ...
    me2Flux, g6pdh2rFlux, gndFlux, pppFlux, naKtFlux, gthpiBoundBinding, ...
    'VariableNames', {'DemandFractionOfRange', 'GTHPiLowerBound', ...
    'GTHPiFlux', 'ME2Flux', 'G6PDH2rFlux', 'GNDFlux', 'PPPFlux', ...
    'NaKtFlux', 'GTHPiBoundBinding'});

if ~exist(figureDir, 'dir')
    mkdir(figureDir);
end
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end
writetable(doseResponse, dataFile, 'Encoding', 'UTF-8');

panelWidthCm = 8.5;
panelHeightCm = 6.485; % Match the 637-by-486 reference panel aspect ratio.
fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'centimeters', ...
    'Position', [1 1 panelWidthCm panelHeightCm], ...
    'ToolBar', 'none', 'MenuBar', 'none');
cleanupFigure = onCleanup(@() closeFigureIfValid(fig));
ax = axes(fig);
ax.FontName = 'Arial';
ax.FontSize = 8;
hold(ax, 'on');

lineColors = [0.90 0.43 0.10; 0.20 0.55 0.82];
me2Handle = plot(ax, gthpiDemand, me2Flux, '-o', ...
    'Color', lineColors(1, :), 'LineWidth', 2.0, 'MarkerSize', 5.5, ...
    'MarkerFaceColor', 'white');
pppHandle = plot(ax, gthpiDemand, pppFlux, '-s', ...
    'Color', lineColors(2, :), 'LineWidth', 1.8, 'MarkerSize', 5.0, ...
    'MarkerFaceColor', 'white');

capacityLine = yline(ax, 0.75, ':', ...
    sprintf(['maximum feasible ME2 flux under\n', ...
    'current model constraints']), ...
    'Color', [0.40 0.40 0.40], 'LineWidth', 1.0, ...
    'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'bottom');
capacityLine.FontName = 'Arial';
capacityLine.FontSize = 7.5;
capacityLine.Annotation.LegendInformation.IconDisplayStyle = 'off';

ax.LineWidth = 0.8;
ax.TickDir = 'out';
ax.Box = 'off';
ax.XGrid = 'off';
ax.YGrid = 'on';
ax.GridAlpha = 0.18;
xlim(ax, [baselineGTHPi maximumGTHPi]);
ylim(ax, [0, 1.08 * max([me2Flux; pppFlux; 0.75])]);
xlabel(ax, 'Minimum GTHPi demand', ...
    'FontName', 'Arial', 'FontSize', 8);
ylabel(ax, 'Parsimonious flux', ...
    'FontName', 'Arial', 'FontSize', 8);
title(ax, 'NADPH-producing fluxes across GTHPi demand', ...
    'FontName', 'Arial', 'FontSize', 9.5, 'FontWeight', 'bold');
subtitle(ax, sprintf(['Demand range: baseline pFBA to maximum compatible ', ...
    'with %g%% NaKt retention'], naKtRetentionPercentage), ...
    'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'normal');
lgd = legend(ax, [me2Handle, pppHandle], ...
    {'ME2 (ME1-associated model reaction)', 'G6PDH2r/GND (PPP)'}, ...
    'Location', 'west', 'Box', 'off');
lgd.FontName = 'Arial';
lgd.FontSize = 7.5;

exportgraphics(fig, figureFile, 'ContentType', 'vector', ...
    'BackgroundColor', 'white', 'Width', panelWidthCm, ...
    'Height', panelHeightCm, 'Units', 'centimeters');
exportgraphics(fig, svgFigureFile, 'ContentType', 'vector', ...
    'BackgroundColor', 'white', 'Width', panelWidthCm, ...
    'Height', panelHeightCm, 'Units', 'centimeters');

fprintf('Wrote dose-response data: %s\n', dataFile);
fprintf('Wrote vector figure: %s\n', figureFile);
fprintf('Wrote SVG figure: %s\n', svgFigureFile);
fprintf('Baseline maximum NaKt: %.9g\n', baselineNaKt);
fprintf('Baseline pFBA GTHPi flux (D0): %.9g\n', baselineGTHPi);
fprintf('Maximum GTHPi at %g%% NaKt retention (Dmax): %.9g\n', ...
    naKtRetentionPercentage, maximumGTHPi);

firstPPPIndex = find(pppFlux > fluxTolerance, 1, 'first');
if isempty(firstPPPIndex)
    fprintf('PPP flux does not exceed the tolerance across the sampled range.\n');
else
    fprintf(['PPP flux first exceeds the tolerance at GTHPi demand %.9g ', ...
        '(range fraction %.3g); ME2 flux = %.9g.\n'], ...
        gthpiDemand(firstPPPIndex), demandFractions(firstPPPIndex), ...
        me2Flux(firstPPPIndex));
end


function closeFigureIfValid(fig)
    if isgraphics(fig)
        close(fig);
    end
end


function assertOptimalSolution(solution, label)
    if ~isstruct(solution) || ~isfield(solution, 'stat') || ...
            ~isequal(solution.stat, 1) || ~isfield(solution, 'f') || ...
            ~isfinite(solution.f) || ~isfield(solution, 'x') || ...
            isempty(solution.x) || any(~isfinite(solution.x))
        error('Optimization failed for %s.', label);
    end
end
