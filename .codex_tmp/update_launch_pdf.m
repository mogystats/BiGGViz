appPath = 'D:\RHB\BiGGViz\src\BiGGViz.mlapp';
reader = appdesigner.internal.serialization.FileReader(appPath);
originalCode = char(reader.readMATLABCodeText());
codeData = reader.readAppCodeData();
metadata = reader.readAppMetadata();
oldBody = strjoin(codeData.StartupCallback.Code, newline);
oldBody = strrep(oldBody, sprintf('\r\n'), newline);
cut = strfind(oldBody, '            % 3. Compute right-side axes position');
assert(isscalar(cut), 'Expected exactly one launch image block.');
newBody = [oldBody(1:cut-1), strjoin({ ...
    '            % Display the launch PDF at the viewport''s native resolution.'; ...
    '            appFolder = fileparts(which(''BiGGViz.mlapp''));'; ...
    '            pdfPath = fullfile(appFolder, ''assets'', ''launch.pdf'');'; ...
    '            app.RightAxes.Visible = ''off'';'; ...
    '            app.HTMLViewer.HTMLSource = makeLaunchPDFHTML(pdfPath);'; ...
    '            app.HTMLViewer.Visible = ''on'';'; ...
    '            app.UIFigure.Color = [250 250 250] / 255;'}, newline)];
normalizedCode = strrep(originalCode, sprintf('\r\n'), newline);
assert(count(string(normalizedCode), string(oldBody)) == 1);
updatedCode = strrep(normalizedCode, oldBody, newBody);
codeData.StartupCallback.Code = reshape(strsplit(newBody, newline, ...
    'CollapseDelimiters', false), 1, []);

backup = fullfile('D:\RHB\BiGGViz\.codex_tmp', ...
    ['BiGGViz_before_launch_pdf_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.mlapp']);
copyfile(appPath, backup);
writer = appdesigner.internal.serialization.FileWriter(appPath);
writer.writeAppCodeData(updatedCode, struct('code', codeData), metadata);

verify = appdesigner.internal.serialization.FileReader(appPath);
assert(strcmp(char(verify.readMATLABCodeText()), updatedCode));
savedCode = verify.readAppCodeData();
assert(isequal(savedCode.StartupCallback.Code, codeData.StartupCallback.Code));
assert(isequal(savedCode.Callbacks, codeData.Callbacks));
assert(isequal(savedCode.EditableSectionCode, codeData.EditableSectionCode));
fprintf('Updated startup code and App Designer metadata. Backup: %s\n', backup);
