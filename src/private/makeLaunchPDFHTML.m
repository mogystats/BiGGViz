function html = makeLaunchPDFHTML(pdfPath)
%MAKELAUNCHPDFHTML Display page 1 of the launch PDF in an offline uihtml view.
% Render from the PDF at the current viewport size and device pixel ratio.
% Uses the PDF.js distribution shipped with MATLAB's print/export UI.

rendererDir = fullfile(matlabroot, 'toolbox', 'matlab', 'uitools', ...
    'uidialogs', 'printexportappjs', 'release', 'pdfjs');
rendererPath = fullfile(rendererDir, 'pdf.min.js');
workerPath = fullfile(rendererDir, 'pdf.worker.min.js');
if ~isfile(rendererPath) || ~isfile(workerPath)
    error('BiGGViz:PDFRendererMissing', ...
        'The PDF renderer bundled with MATLAB was not found at %s.', rendererDir);
end

[fid, message] = fopen(pdfPath, 'rb');
if fid == -1
    error('BiGGViz:LaunchPDFMissing', 'Cannot open %s: %s', pdfPath, message);
end
cleanup = onCleanup(@() fclose(fid));
pdfBytes = fread(fid, Inf, '*uint8');
pdfBase64 = matlab.net.base64encode(pdfBytes);

templatePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'assets', 'launch_pdf_viewer.html');
html = fileread(templatePath);
% Escape closing script tags when embedding the bundled JavaScript inline.
workerCode = regexprep(fileread(workerPath), '</script', '<\\/script', 'ignorecase');
rendererCode = regexprep(fileread(rendererPath), '</script', '<\\/script', 'ignorecase');
html = strrep(html, '{{PDF_WORKER}}', workerCode);
html = strrep(html, '{{PDF_RENDERER}}', rendererCode);
html = strrep(html, '{{PDF_BASE64}}', char(pdfBase64));
end
