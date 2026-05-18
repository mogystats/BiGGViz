
function [G_main, rxnList] = buildRxnRxnGraph(model, opts)
% BUILDRXNRXNGRAPH Constructs a directed reaction-reaction graph from a COBRA model.
%
% INPUTS:
%   model - COBRA model structure (must contain .S and .rxns)
%   opts  - Struct containing graph generation options:
%           .filterCurrency (logical) : If true, removes high-degree metabolites
%           .currencyDegThresh (int)  : Degree threshold for currency metabolites (default: 80)
%
% OUTPUTS:
%   G_main  - digraph object representing the largest weakly-connected component
%   rxnList - string array of the reaction IDs preserved in G_main

    disp('Building rxn-rxn network...');
    
    %% 1. Parse Options

    if nargin < 2 || ~isfield(opts, 'filterCurrency')  % if fewer than 2 arguments (only model is provided, or opts does not have a "filterCurrency" field)
        opts.filterCurrency = true; 
    end
    if ~isfield(opts, 'currencyDegThresh')
        opts.currencyDegThresh = 80; 
    end
    
    %% 2. Currency Metabolite Filtering

    S = model.S;  % stoichiometric matrix
    if opts.filterCurrency
        % Calculate the degree of each metabolite (number of reactions it participates in)
        metDeg = full(sum(S ~= 0, 2));
        
        % Retain only metabolites below the degree threshold
        keepMet = metDeg <= opts.currencyDegThresh;
        S = S(keepMet, :);
    end
    
    %% 3. Project Bipartite Network to Directed Rxn-Rxn Adjacency
    % This converts a bipartite graph into a unipartite directed graph. S
    % is bipartite (linking metabolites to reactions), but we want a
    % reaction-reaction graph.

    % A directed edge exists from Rxn i to Rxn j if 'i' produces a metabolite that 'j' consumes.
    Prod = S > 0;  % a matrix where 1 means this reaction produces this metabolite
    Cons = S < 0;  % a matrix where 1 means this reaction consumes this metabolite
    
    % Adjacency matrix (Rxn x Rxn), in 1 or 0.
    A = double((Prod' * Cons) > 0); 

    % Remove self-loops (a reaction feeding into itself) by setting the diagonal to 0
    nRxns = size(A, 1);
    A(1:nRxns+1:end) = 0;  % linear indexing - setting the diagonal to 0

    %% 4. Build Digraph and Extract Largest Connected Component
    G_full = digraph(A, string(model.rxns));
    
    % Find weakly connected components (ignoring direction of the arrow)
    bins = conncomp(G_full, 'Type', 'weak');
    
    % The mode of the bins array identifies the largest component's ID
    largestCompIdx = mode(bins);
    keepRxns = (bins == largestCompIdx);
    
    % Create the final subgraph
    G_main = subgraph(G_full, keepRxns);
    rxnList = string(G_main.Nodes.Name);

end