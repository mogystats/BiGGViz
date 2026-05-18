%% download_bigg_models_for_BiGGViz.m
% Run this from BiGGViz project root folder.
% Requires:
%   1) COBRA Toolbox initialized
%   2) internet connection

clear; clc;

% Initialize the COBRA Toolbox
initCobraToolbox(false);

%% 0. Project paths
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelsRoot  = fullfile(projectRoot, 'data', 'models');
matDir      = fullfile(modelsRoot, 'mat');
xmlDir      = fullfile(modelsRoot, 'xml');

if ~exist(modelsRoot, 'dir'); mkdir(modelsRoot); end
if ~exist(matDir, 'dir'); mkdir(matDir); end
if ~exist(xmlDir, 'dir'); mkdir(xmlDir); end

fprintf('Project root: %s\n', projectRoot);
fprintf('MAT output:   %s\n', matDir);
fprintf('XML output:   %s\n\n', xmlDir);

%% 1. Make sure COBRA Toolbox functions are available
if exist('readCbModel', 'file') ~= 2
    error(['COBRA Toolbox is not on the MATLAB path. ' ...
           'Run initCobraToolbox(false) first.']);
end

if exist('writeCbModel', 'file') ~= 2
    error(['writeCbModel was not found. ' ...
           'Make sure the COBRA Toolbox is initialized correctly.']);
end

%% 2. Get model IDs from the BiGG API
apiURL = 'http://bigg.ucsd.edu/api/v2/models';
apiData = webread(apiURL);

if ~isfield(apiData, 'results') || isempty(apiData.results)
    error('Could not retrieve model list from the BiGG API.');
end

allIDs = string({apiData.results.bigg_id});

% Remove missing/empty IDs just in case
allIDs = allIDs(strlength(strtrim(allIDs)) > 0);

% Keep a stable order and take the first 50
nTarget = 50;
if numel(allIDs) < nTarget
    warning('BiGG API returned only %d models. Proceeding with all of them.', numel(allIDs));
    nTarget = numel(allIDs);
end

modelIDs = allIDs(1:nTarget);

fprintf('Will download %d model IDs.\n\n', numel(modelIDs));

%% 3. Download and save each model in both formats
results = table( ...
    modelIDs(:), ...
    false(numel(modelIDs),1), ...
    false(numel(modelIDs),1), ...
    strings(numel(modelIDs),1), ...
    'VariableNames', {'ModelID','SavedMAT','SavedXML','Note'});

for i = 1:numel(modelIDs)
    modelID = char(modelIDs(i));
    fprintf('(%d/%d) %s\n', i, numel(modelIDs), modelID);

    try
        %% 3A. Download/save MAT version
        % BiGG = load from BiGG database MAT representation
        model_mat = readCbModel(modelID, 'fileType', 'BiGG');
        outMat = fullfile(matDir, [modelID '.mat']);
        writeCbModel(model_mat, 'format', 'mat', 'fileName', outMat);
        results.SavedMAT(i) = true;
        fprintf('    MAT saved: %s\n', outMat);
    catch ME_mat
        results.Note(i) = "MAT failed: " + string(ME_mat.message);
        fprintf('    MAT failed: %s\n', ME_mat.message);
    end

    try
        %% 3B. Download/save XML version
        % BiGGSBML = load from BiGG database SBML representation
        model_xml = readCbModel(modelID, 'fileType', 'BiGGSBML');
        outXml = fullfile(xmlDir, [modelID '.xml']);
        writeCbModel(model_xml, 'format', 'sbml', 'fileName', outXml);
        results.SavedXML(i) = true;
        fprintf('    XML saved: %s\n', outXml);
    catch ME_xml
        if strlength(results.Note(i)) == 0
            results.Note(i) = "XML failed: " + string(ME_xml.message);
        else
            results.Note(i) = results.Note(i) + " | XML failed: " + string(ME_xml.message);
        end
        fprintf('    XML failed: %s\n', ME_xml.message);
    end

    fprintf('\n');
end

%% 4. Save a download report
reportFile = fullfile(modelsRoot, 'download_report.csv');
writetable(results, reportFile);

fprintf('Done.\n');
fprintf('MAT files saved in: %s\n', matDir);
fprintf('XML files saved in: %s\n', xmlDir);
fprintf('Report saved to:    %s\n', reportFile);

fprintf('\nSummary:\n');
fprintf('  MAT successful: %d / %d\n', nnz(results.SavedMAT), height(results));
fprintf('  XML successful: %d / %d\n', nnz(results.SavedXML), height(results));