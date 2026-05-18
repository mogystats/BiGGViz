function [G_main, metList] = buildMetMetGraph(model, opts)
% BUILDMETMETGRAPH Constructs a directed metabolite-metabolite graph from a COBRA model.
%
% A directed edge exists from Metabolite A to Metabolite B if a reaction 
% consumes A and produces B.
%
% INPUTS:
%   model - COBRA model structure (must contain .S and .mets)
%   opts  - Struct containing graph generation options:
%           .filterCurrency (logical) : If true, removes high-degree metabolites
%           .currencyDegThresh (int)  : Degree threshold for currency metabolites (default: 80)
%
% OUTPUTS:
%   G_main  - digraph object representing the largest weakly-connected component
%   metList - string array of the metabolite IDs preserved in G_main

    disp('Building met-met network...');
    
    %% 1. Parse Options
    if nargin < 2 || ~isfield(opts, 'filterCurrency')
        opts.filterCurrency = true; 
    end
    if ~isfield(opts, 'currencyDegThresh')
        opts.currencyDegThresh = 80; 
    end
    
    %% 2. Currency Metabolite Filtering
    S = model.S;  % stoichiometric matrix
    mets = string(model.mets);
    
    if opts.filterCurrency
        % Calculate the degree of each metabolite (number of reactions it participates in)
        metDeg = full(sum(S ~= 0, 2));
        
        % Retain only metabolites below the degree threshold
        keepMet = metDeg <= opts.currencyDegThresh;
        
        % Subset the S matrix and the metabolite list
        S = S(keepMet, :);
        mets = mets(keepMet);
    end
    
    %% 3. Project Bipartite Network to Directed Met-Met Adjacency
    % A directed edge exists from Met i to Met j if there is at least one 
    % reaction 'k' that consumes 'i' AND produces 'j'.
    Cons = S < 0;  % Matrix where 1 means metabolite is consumed by reaction
    Prod = S > 0;  % Matrix where 1 means metabolite is produced by reaction
    
    % Adjacency matrix (Met x Met)
    % Boolean multiplication: Cons (Met x Rxn) * Prod' (Rxn x Met)
    A = double((Cons * Prod') > 0); 
    
    % Remove self-loops (a metabolite transforming into itself)
    nMets = size(A, 1);
    A(1:nMets+1:end) = 0;  % linear indexing for the diagonal
    
    %% 4. Build Digraph and Extract Largest Connected Component
    G_full = digraph(A, mets);
    
    % Find weakly connected components (ignoring direction of the arrow)
    bins = conncomp(G_full, 'Type', 'weak');
    
    % Check if graph is completely empty
    if isempty(bins)
        warning('Graph is empty. Check your model or currency thresholds.');
        G_main = digraph();
        metList = strings(0,1);
        return;
    end
    
    % The mode of the bins array identifies the largest component's ID
    largestCompIdx = mode(bins);
    keepMets = (bins == largestCompIdx);
    
    % Create the final subgraph
    G_main = subgraph(G_full, keepMets);
    metList = string(G_main.Nodes.Name);
    
    fprintf('Met-Met Graph built: %d metabolites (nodes) and %d edges.\n', numnodes(G_main), numedges(G_main));
end
