% This code uses the standard COBRA Toolbox function to run Flux Balance
% Analysis (FBA)

function fbaTable = runFBA(model, options)
    % Runs FBA on a COBRA model and extracts fluxes
    % 
    % Inputs:
    %   model - A COBRA model structure (e.g., from BiGG)
    %   options - Optional struct for FBA settings (e.g., max vs. min)
    % 
    % Outputs:
    %   fbaTable - A table containing the ReactionKey and the simulated
    %   Flux

    arguments
        model (1, 1) struct  % force to have 1 model only
        options.ObjectiveReaction (1, 1) string = ""  % Default is original
        options.ObjectiveSense (1, 1) string = "max"  % Default is to maximize
        options.Solver (1, 1) string = ""  % Solver: specify 'gurobi', 'glpk', etc.
    end
    
    % Verify COBRA Toolbox is initialized
    if exist('optimizeCbModel', 'file') ~= 2
        error('COBRA Toolbox is not initialized. Please check your installation.');
    end

    %% Run FBA

    % Update Model Objective
    if options.ObjectiveReaction ~= ""
        if ~ismember(char(options.ObjectiveReaction), model.rxns)
            error('Objective reaction "%s" not found in model.rxns.', options.ObjectiveReaction);
        end

        model = changeObjective(model, char(options.ObjectiveReaction), 1);
        fprintf('Model objective updated to: %s\n', options.ObjectiveReaction);
    end
    
    % Run FBA
    fprintf('Running FBA (Objective Sense: %s)...\n', options.ObjectiveSense);
    
    if options.Solver ~= ""
        changeCobraSolver(char(options.Solver), 'all');
    end

    solution = optimizeCbModel(model, char(options.ObjectiveSense));
    
    % Check results and format output
    if solution.stat ~= 1
        warning('FBA failed or was infeasible. Solver status: %d', solution.stat);
        % create placeholders for missing flux values
        fbaTable = table(string(model.rxns), NaN(numel(model.rxns), 1), ...
            'VariableNames', {'ReactionKey', 'FBA_Flux'});
        return;
    end

    fprintf('FBA successful. Objective value: %.4f\n', solution.f);

    % Extract flux values and create output table
    fbaTable = table(string(model.rxns), solution.x, ...
        'VariableNames', {'ReactionKey', 'FBA_Flux'});

end