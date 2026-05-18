function generatedFiles = exportBiGGViz(model, graphType, outDir, rxnAnnoTable, opts)
% EXPORTBIGGVIZ Main public function to generate BiGGViz interactive HTML networks.
%
% USAGE:
%   exportBiGGViz(model)
%   exportBiGGViz(model, 'both', outDir, annoTable, opts)
%
% INPUTS:
%   model        - COBRA model structure
%   graphType    - String/char: 'rxn', 'met', or 'both' (Default: 'both')
%   outDir       - Directory path to save the HTML files (Default: current dir)
%   rxnAnnoTable - (Optional) Table containing reaction metadata (e.g. FBA fluxes).
%                  If empty, a basic table is auto-generated from the model.
%   opts         - (Optional) Struct with graph settings:
%                  .filterCurrency (logical, default: true)
%                  .currencyDegThresh (int, default: 80)
%
% OUTPUTS:
%   generatedFiles - String array of the absolute paths to the generated HTML files.

    %% 1. Parse Inputs and Set Defaults
    if nargin < 2 || isempty(graphType), graphType = "both"; end
    if nargin < 3 || isempty(outDir), outDir = pwd; end
    if nargin < 4, rxnAnnoTable = table(); end
    if nargin < 5, opts = struct(); end

    graphType = lower(string(graphType));
    if ~ismember(graphType, ["rxn", "met", "both"])
        error('BiGGViz:InvalidGraphType', 'graphType must be "rxn", "met", or "both".');
    end

    if ~isfield(opts, 'filterCurrency'), opts.filterCurrency = true; end
    if ~isfield(opts, 'currencyDegThresh'), opts.currencyDegThresh = 80; end

    % Ensure output directory exists
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % Determine a model name for the output file prefix
    if isfield(model, 'description') && ~isempty(model.description)
        % Sanitize name for file systems
        modelName = regexprep(string(model.description), '[\\/:*?"<>|]', '_');
    else
        modelName = "BiGG_Model";
    end

    generatedFiles = strings(0);

    disp('===================================================');
    disp('           Initializing BiGGViz Export              ');
    disp('===================================================');

    %% 2. Reaction-Reaction Graph
    if ismember(graphType, ["rxn", "both"])
        disp('--- Processing Reaction-Reaction Graph ---');

        % Build topology
        G_rxn = buildRxnRxnGraph(model, opts);

        % Resolve reaction metadata table
        if isempty(rxnAnnoTable)
            disp('No rxnAnnoTable provided. Auto-generating from model...');
            rxnMeta = buildDefaultRxnAnnoTable(model);
        else
            rxnMeta = rxnAnnoTable;
        end

        outRxnHTML = fullfile(outDir, sprintf('%s_RxnRxn_Viewer.html', modelName));
        writeNetworkHTML(G_rxn, rxnMeta, outRxnHTML);
        generatedFiles(end+1) = outRxnHTML;

        disp(['=> Rxn-Rxn Viewer: <a href="matlab:web(''', char(outRxnHTML), ''')">Open File</a>']);
    end

    %% 3. Metabolite-Metabolite Graph
    if ismember(graphType, ["met", "both"])
        disp('--- Processing Metabolite-Metabolite Graph ---');

        % Build topology
        [G_met, metList] = buildMetMetGraph(model, opts);

        % Build default metabolite metadata table
        metMeta = buildDefaultMetAnnoTable(model, metList);

        outMetHTML = fullfile(outDir, sprintf('%s_MetMet_Viewer.html', modelName));
        writeNetworkHTML(G_met, metMeta, outMetHTML);
        generatedFiles(end+1) = outMetHTML;

        disp(['=> Met-Met Viewer: <a href="matlab:web(''', char(outMetHTML), ''')">Open File</a>']);
    end

    disp('===================================================');
    disp('         BiGGViz export finished successfully!      ');
    disp('===================================================');
end


% Helper: reactions metadata
function rxnMeta = buildDefaultRxnAnnoTable(model)
    numRxns = numel(model.rxns);
    ReactionKey = string(model.rxns);

    if isfield(model, 'rxnNames')
        Name = string(model.rxnNames);
    else
        Name = ReactionKey;
    end

    Pathway = repmat("Unassigned", numRxns, 1);
    if isfield(model, 'subSystems') && ~isempty(model.subSystems)
        for i = 1:numRxns
            if isempty(model.subSystems{i})
                Pathway(i) = "Unassigned";
            elseif iscell(model.subSystems{i})
                Pathway(i) = string(strjoin(model.subSystems{i}, '; '));
            else
                Pathway(i) = string(model.subSystems{i});
            end
        end
    end

    disp('Fetching formulas (this may take a moment)...');
    Formula = string(printRxnFormula(model, model.rxns, false));

    rxnMeta = table(ReactionKey, Name, Pathway, Formula);
end

% Helper: metabolite metadata
function metMeta = buildDefaultMetAnnoTable(model, metList)
    [~, metIdx] = ismember(string(metList), string(model.mets));

    MetaboliteKey = string(metList);
    numMets = numel(MetaboliteKey);

    if isfield(model, 'metNames')
        Name = string(model.metNames(metIdx));
    else
        Name = MetaboliteKey;
    end

    Compartment = strings(numMets, 1);

    if isfield(model, 'metComps') && isfield(model, 'comps') && isnumeric(model.metComps)
        compIndices = model.metComps(metIdx);
        for i = 1:numMets
            if compIndices(i) > 0 && compIndices(i) <= length(model.comps)
                Compartment(i) = string(model.comps{compIndices(i)});
            else
                Compartment(i) = "Unknown";
            end
        end

    elseif isfield(model, 'metComps') && ~isnumeric(model.metComps)
        Compartment = string(model.metComps(metIdx));

    else
        for i = 1:numMets
            id = char(MetaboliteKey(i));
            tok = regexp(id, '\[([A-Za-z0-9_]+)\]$', 'tokens', 'once');
            if isempty(tok)
                tok = regexp(id, '_([A-Za-z0-9]+)$', 'tokens', 'once');
            end

            if ~isempty(tok)
                Compartment(i) = string(tok{1});
            else
                Compartment(i) = "Unknown";
            end
        end
    end

    Degree = full(sum(model.S(metIdx, :) ~= 0, 2));

    metMeta = table(MetaboliteKey, Name, Compartment, Degree);
end