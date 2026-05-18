function cleanTable = parseAnnotations(annotationInput)
% parseAnnotations
% Reads and cleans BiGGViz annotation tables.
%
% Supports both:
%   1. Reaction annotation tables
%      Required ID-like column: ReactionKey, Reaction, Reaction ID, etc.
%
%   2. Metabolite annotation tables
%      Required ID-like column: MetaboliteKey, Metabolite, Metabolite ID, etc.
%
% The output table always places the key column first:
%   ReactionKey   for reaction annotations
%   MetaboliteKey for metabolite annotations
%
% All additional columns are preserved whenever possible, including:
%   PathwayKey, Compartment, MetaboliteClass, Enzyme, Category, PubMedID,
%   NodeSize, FBAFlux, FVA summaries, knockout results, statistical scores,
%   and external analysis results.

    arguments
        annotationInput {mustBeA(annotationInput, ["string", "char", "table"])}
    end

    %% 1. Load input table
    if istable(annotationInput)
        Traw = annotationInput;
    else
        if exist(annotationInput, 'file') ~= 2
            error('Annotation file not found: %s', annotationInput);
        end

        [~, ~, ext] = fileparts(annotationInput);

        switch lower(ext)
            case {'.xlsx', '.xls', '.csv', '.txt', '.tsv'}
                Traw = readtable(annotationInput, 'VariableNamingRule', 'preserve');
            otherwise
                error('Unsupported annotation file type: %s', ext);
        end
    end

    if isempty(Traw) || height(Traw) == 0
        error('Annotation table is empty.');
    end

    colNames = string(Traw.Properties.VariableNames);
    colNamesTrim = strtrim(colNames);
    colNamesLower = lower(colNamesTrim);

    %% 2. Detect reaction or metabolite key column

    % Reaction key candidates
    rxnCol = find( ...
        strcmpi(colNamesTrim, "ReactionKey") | ...
        strcmpi(colNamesTrim, "Reaction") | ...
        strcmpi(colNamesTrim, "Reaction ID") | ...
        strcmpi(colNamesTrim, "Reaction_ID") | ...
        strcmpi(colNamesTrim, "Rxn") | ...
        strcmpi(colNamesTrim, "RxnID") | ...
        strcmpi(colNamesTrim, "Rxn ID") | ...
        strcmpi(colNamesTrim, "Rxn_ID"), 1);

    if isempty(rxnCol)
        rxnCol = find( ...
            contains(colNamesLower, "reaction") & ...
            ~contains(colNamesLower, "formula") & ...
            ~contains(colNamesLower, "symbol"), 1);
    end

    % Metabolite key candidates
    metCol = find( ...
        strcmpi(colNamesTrim, "MetaboliteKey") | ...
        strcmpi(colNamesTrim, "Metabolite") | ...
        strcmpi(colNamesTrim, "Metabolite ID") | ...
        strcmpi(colNamesTrim, "Metabolite_ID") | ...
        strcmpi(colNamesTrim, "Met") | ...
        strcmpi(colNamesTrim, "MetID") | ...
        strcmpi(colNamesTrim, "Met ID") | ...
        strcmpi(colNamesTrim, "Met_ID"), 1);

    if isempty(metCol)
        metCol = find( ...
            contains(colNamesLower, "metabolite") & ...
            ~contains(colNamesLower, "class") & ...
            ~contains(colNamesLower, "name"), 1);
    end

    if ~isempty(rxnCol) && isempty(metCol)
        tableType = "reaction";
        keyCol = rxnCol;
        keyName = "ReactionKey";
    elseif isempty(rxnCol) && ~isempty(metCol)
        tableType = "metabolite";
        keyCol = metCol;
        keyName = "MetaboliteKey";
    elseif ~isempty(rxnCol) && ~isempty(metCol)
        % Ambiguous table. Prefer the first of the two detected key columns.
        if rxnCol < metCol
            tableType = "reaction";
            keyCol = rxnCol;
            keyName = "ReactionKey";
        else
            tableType = "metabolite";
            keyCol = metCol;
            keyName = "MetaboliteKey";
        end
    else
        error(['Could not detect an annotation key column. ', ...
               'Accepted reaction keys include ReactionKey, Reaction, Reaction ID. ', ...
               'Accepted metabolite keys include MetaboliteKey, Metabolite, Metabolite ID.']);
    end

    %% 3. Start clean output table with standardized key column first

    cleanTable = table();
    cleanTable.(keyName) = strtrim(string(Traw{:, keyCol}));

    %% 4. Preserve all other columns

    for c = 1:numel(colNames)

        if c == keyCol
            continue;
        end

        originalName = colNames(c);
        matlabName = matlab.lang.makeValidName(originalName);

        % Avoid overwriting the standardized key column.
        if strcmpi(matlabName, keyName)
            continue;
        end

        values = Traw{:, c};

        % Convert cellstr/categorical/char to string, but preserve numeric columns.
        if iscell(values) || ischar(values) || iscategorical(values)
            values = string(values);
        end

        if isstring(values)
            values = strtrim(values);
            values(ismissing(values)) = "";
        end

        cleanTable.(matlabName) = values;
    end

    %% 5. Normalize common column names

    cleanTable = normalizeCommonAnnotationNames(cleanTable, tableType);

    %% 6. Remove empty keys

    keyVals = strtrim(string(cleanTable.(keyName)));
    keep = ~(ismissing(keyVals) | keyVals == "");

    nEmpty = sum(~keep);
    if nEmpty > 0
        warning('Removed %d rows with empty %s.', nEmpty, keyName);
    end

    cleanTable = cleanTable(keep, :);

    %% 7. Remove duplicated keys

    nRowsBefore = height(cleanTable);

    [~, uniqueIndices] = unique(string(cleanTable.(keyName)), 'stable');
    cleanTable = cleanTable(uniqueIndices, :);

    nRowsRemoved = nRowsBefore - height(cleanTable);

    if nRowsRemoved > 0
        warning('Removed %d duplicated %s rows from the annotation table.', ...
            nRowsRemoved, keyName);
    end

end


function T = normalizeCommonAnnotationNames(T, tableType)
% Normalize common annotation-column variants to names used by BiGGViz.

    vars = string(T.Properties.VariableNames);
    lowerVars = lower(vars);

    %% Name column
    nameIdx = find( ...
        strcmpi(vars, "Name") | ...
        strcmpi(vars, "DisplayName") | ...
        strcmpi(vars, "Display_Name") | ...
        strcmpi(vars, "ReactionName") | ...
        strcmpi(vars, "MetaboliteName") | ...
        strcmpi(vars, "Description"), 1);

    if ~isempty(nameIdx) && ~ismember("Name", vars)
        T = renamevars(T, vars(nameIdx), "Name");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    %% Pathway column
    pathIdx = find( ...
        strcmpi(vars, "PathwayKey") | ...
        strcmpi(vars, "Pathway") | ...
        strcmpi(vars, "Subsystem") | ...
        strcmpi(vars, "SubSystem") | ...
        strcmpi(vars, "Sub_System") | ...
        strcmpi(vars, "SubSystemKey"), 1);

    if ~isempty(pathIdx) && ~ismember("PathwayKey", vars)
        T = renamevars(T, vars(pathIdx), "PathwayKey");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    %% Formula column
    formIdx = find( ...
        strcmpi(vars, "FormulaKey") | ...
        strcmpi(vars, "Formula") | ...
        strcmpi(vars, "ReactionFormula") | ...
        strcmpi(vars, "Reaction_Formula"), 1);

    if ~isempty(formIdx) && ~ismember("FormulaKey", vars)
        T = renamevars(T, vars(formIdx), "FormulaKey");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    %% Enzyme column
    enzIdx = find( ...
        strcmpi(vars, "EnzymeKey") | ...
        strcmpi(vars, "Enzyme") | ...
        strcmpi(vars, "EnzymeName") | ...
        strcmpi(vars, "ECNumber") | ...
        strcmpi(vars, "EC_Number"), 1);

    if ~isempty(enzIdx) && ~ismember("EnzymeKey", vars)
        T = renamevars(T, vars(enzIdx), "EnzymeKey");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    %% NodeSize column
    sizeIdx = find( ...
        strcmpi(vars, "NodeSize") | ...
        strcmpi(vars, "Node Size") | ...
        strcmpi(vars, "Node_Size") | ...
        strcmpi(vars, "nodesize") | ...
        strcmpi(vars, "SizeValue"), 1);

    if ~isempty(sizeIdx) && ~ismember("NodeSize", vars)
        T = renamevars(T, vars(sizeIdx), "NodeSize");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    if ismember("NodeSize", vars)
        if ~isnumeric(T.NodeSize)
            T.NodeSize = str2double(string(T.NodeSize));
        else
            T.NodeSize = double(T.NodeSize);
        end
    end

    %% FBAFlux column
    fluxIdx = find( ...
        strcmpi(vars, "FBAFlux") | ...
        strcmpi(vars, "FBA Flux") | ...
        strcmpi(vars, "FBA_Flux") | ...
        strcmpi(vars, "Flux"), 1);

    if ~isempty(fluxIdx) && ~ismember("FBAFlux", vars)
        T = renamevars(T, vars(fluxIdx), "FBAFlux");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    if ismember("FBAFlux", vars)
        if ~isnumeric(T.FBAFlux)
            T.FBAFlux = str2double(string(T.FBAFlux));
        else
            T.FBAFlux = double(T.FBAFlux);
        end
    end

    %% Metabolite class column
    metClassIdx = find( ...
        strcmpi(vars, "MetaboliteClass") | ...
        strcmpi(vars, "Metabolite Class") | ...
        strcmpi(vars, "Metabolite_Class") | ...
        strcmpi(vars, "Class"), 1);

    if tableType == "metabolite" && ~isempty(metClassIdx) && ~ismember("MetaboliteClass", vars)
        T = renamevars(T, vars(metClassIdx), "MetaboliteClass");
        vars = string(T.Properties.VariableNames);
        lowerVars = lower(vars);
    end

    %% Clean string columns
    vars = string(T.Properties.VariableNames);

    for v = vars
        if isstring(T.(v))
            T.(v)(ismissing(T.(v))) = "";
            T.(v) = strtrim(T.(v));
        elseif iscellstr(T.(v))
            T.(v) = strtrim(string(T.(v)));
            T.(v)(ismissing(T.(v))) = "";
        end
    end

end