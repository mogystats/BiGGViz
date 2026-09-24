addpath('D:\RHB\BiGGViz\src');
checkcode('D:\RHB\BiGGViz\src\private\makeLaunchPDFHTML.m');
app = BiGGViz;
cleanup = onCleanup(@() delete(app));
assert(strcmp(app.RightAxes.Visible, 'off'));
assert(strcmp(app.HTMLViewer.Visible, 'on'));
source = app.HTMLViewer.HTMLSource;
assert(contains(source, 'pdfjsLib.getDocument'));
assert(~contains(source, '{{PDF_'));
% Observe the real PDF render promise through a temporary test-only bridge.
app.HTMLViewer.DataChangedFcn = [];
app.HTMLViewer.Data = '';
bridge = ['<script>function setup(c){window.launchPDFReady.then(function(){setTimeout(function(){' ...
    'var p=document.getElementById("page");' ...
    'c.Data={status:"PDF_READY",width:p.width,height:p.height,' ...
    'png:p.toDataURL("image/png").split(",")[1]};' ...
    '},2000);' ...
    '}).catch(function(e){c.Data="PDF_ERROR:"+e.message;});}</script>'];
app.HTMLViewer.HTMLSource = strrep(source, '</body>', [bridge '</body>']);
t = tic;
while toc(t) < 30 && ~isstruct(app.HTMLViewer.Data)
    drawnow;
    pause(0.1);
end
result = app.HTMLViewer.Data;
assert(isstruct(result) && strcmp(result.status, 'PDF_READY'), ...
    'The launch PDF did not render successfully.');
assert(result.width == 720 && result.height == 720);
fprintf('PDF rendered at %d x %d pixels.\n', result.width, result.height);
disp('Actual HTML viewport:');
disp(app.HTMLViewer.Position);
fid = fopen('D:\RHB\BiGGViz\.codex_tmp\launch_pdf_canvas.png', 'wb');
fwrite(fid, matlab.net.base64decode(result.png), 'uint8');
fclose(fid);

% Exercise the same renderer with a simulated 2x device pixel ratio.
app.HTMLViewer.Data = '';
hiDPI = strrep(source, 'var density = window.devicePixelRatio || 1;', 'var density = 2;');
app.HTMLViewer.HTMLSource = strrep(hiDPI, '</body>', [bridge '</body>']);
t = tic;
while toc(t) < 30 && ~isstruct(app.HTMLViewer.Data)
    drawnow;
    pause(0.1);
end
result2 = app.HTMLViewer.Data;
assert(isstruct(result2) && strcmp(result2.status, 'PDF_READY'));
assert(result2.width == 1440 && result2.height == 1440);
disp('PASS: 2x display renders from PDF at 1440 x 1440.');

% The same viewer must remain usable when the model view replaces the PDF.
app.HTMLViewer.Data = '';
app.HTMLViewer.HTMLSource = '<html><body>Network view replacement<script>function setup(c){c.Data="REPLACED";}</script></body></html>';
t = tic;
while toc(t) < 10 && ~strcmp(app.HTMLViewer.Data, 'REPLACED')
    drawnow;
    pause(0.1);
end
assert(strcmp(app.HTMLViewer.Data, 'REPLACED'));
disp('PASS: app startup, PDF rendering, and HTML viewer replacement.');
