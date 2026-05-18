function writeNetworkHTML(G_main, annoTable, outFile, labelBy, exportMode)
if nargin < 4 || isempty(labelBy)
    labelBy = "None";
end

% Backward compatibility:
% old calls used showLabels = true/false.
if islogical(labelBy) || isnumeric(labelBy)
    if logical(labelBy)
        labelBy = "NodeID";
    else
        labelBy = "None";
    end
end

labelBy = string(labelBy);

if nargin < 5 || isempty(exportMode)
    exportMode = false;
end
disp(['Preparing dynamic HTML export to: ', char(outFile)]);
varNames = string(annoTable.Properties.VariableNames);

%% 1. Dynamic Column Detection
validIds = ["Reaction","ReactionKey","Metabolite","MetaboliteKey","ID"];
keyCol = varNames(ismember(varNames, validIds));
if isempty(keyCol), error('annoTable must contain an ID column (e.g., ReactionKey, MetaboliteKey)'); end
keyCol = keyCol(1);

validSizes = ["Size"];
sizeCol = "";
for vi = 1:numel(validSizes)
    if ismember(validSizes(vi), varNames)
        sizeCol = validSizes(vi);
        break;
    end
end

validColors = ["ColorGroup","Pathway","PathwayKey","subSystems","Compartment","Category"];
colorCol = "";
for vi = 1:numel(validColors)
    if ismember(validColors(vi), varNames)
        colorCol = validColors(vi);
        break;
    end
end

hasFluxColor = false;

if ismember("FluxColor", varNames)
    fc = annoTable.FluxColor;
    if isnumeric(fc)
        hasFluxColor = any(isfinite(fc));
    end
end

hasHighlightFlag = ismember("HighlightFlag", varNames);

%% 2. Map Data to Graph Nodes
nodeList = string(G_main.Nodes.Name);
N = numel(nodeList);
t_keys = string(annoTable.(keyCol));
idxMap = containers.Map(cellstr(t_keys), num2cell(1:numel(t_keys)));
nodes = struct('id',cell(N,1), ...
    'nameID',cell(N,1), ...
    'labelText',cell(N,1), ...
    'colorVal',cell(N,1), ...
    'sizeVal',cell(N,1), ...
    'colorNum',cell(N,1), ...
    'isHighlighted',cell(N,1), ...
    'info',cell(N,1));

for i = 1:N
    k = char(nodeList(i));
    nodes(i).id = i - 1;
    nodes(i).nameID = k;
    nodes(i).labelText = '';
    nodes(i).colorVal = 'Unassigned';
    nodes(i).sizeVal = 0;
    nodes(i).colorNum = NaN;
    nodes(i).isHighlighted = true;
    nodeInfo = struct();
    if isKey(idxMap, k)
        r = idxMap(k);
        if colorCol ~= "", nodes(i).colorVal = char(string(annoTable{r, colorCol})); end
        if sizeCol  ~= "", nodes(i).sizeVal  = double(annoTable{r, sizeCol});        end
        for c = 1:length(varNames)
            colName = char(varNames(c));
            val = annoTable{r, c};
            if isnumeric(val)
                if isnan(val)
                    nodeInfo.(colName) = '';   % blank → JS v !== "" filters it out cleanly
                else
                    nodeInfo.(colName) = num2str(val);
                end
            elseif ismissing(string(val))
                nodeInfo.(colName) = '';
            else
                nodeInfo.(colName) = char(string(val));
            end
        end

        % ADD: populate colorNum if FluxColor column exists
        if hasFluxColor
            fcVal = annoTable{r, "FluxColor"};
            if isnumeric(fcVal) && isfinite(fcVal)
                nodes(i).colorNum = fcVal;
            end
        end
        if hasHighlightFlag
            hfVal = annoTable{r, "HighlightFlag"};
            if islogical(hfVal) || isnumeric(hfVal)
                nodes(i).isHighlighted = logical(hfVal);
            end
        end
    end

    % Label text used for on-graph labels
    if labelBy == "None"
        nodes(i).labelText = '';
    elseif labelBy == "NodeID"
        nodes(i).labelText = k;
    elseif ismember(labelBy, varNames)
        labelVal = annoTable{r, labelBy};
        if isnumeric(labelVal)
            if isfinite(labelVal)
                nodes(i).labelText = num2str(labelVal);
            else
                nodes(i).labelText = '';
            end
        elseif ismissing(string(labelVal))
            nodes(i).labelText = '';
        else
            nodes(i).labelText = char(string(labelVal));
        end
    else
        nodes(i).labelText = '';
    end
    nodes(i).info = nodeInfo;
    
end

uniqueVals = unique(string({nodes.colorVal})');
uniqueVals(uniqueVals == "Unassigned") = [];
palette20 = ["#1f77b4","#ff7f0e","#2ca02c","#d62728","#9467bd", ...
    "#8c564b","#e377c2","#17becf","#bcbd22","#aec7e8", ...
    "#ffbb78","#98df8a","#ff9896","#c5b0d5","#c49c94", ...
    "#f7b6d2","#dbdb8d","#9edae5","#393b79","#637939"];
nColors = numel(uniqueVals);
entries = strings(nColors, 1);
for ci = 1:nColors
    hexCol  = palette20(mod(ci-1, numel(palette20)) + 1);
    safeVal = strrep(char(uniqueVals(ci)), '"', '\"');
    entries(ci) = sprintf('  ["%s","%s"]', safeVal, char(hexCol));
end
colorMapJS = sprintf('const presetColorMap = new Map([\n%s\n]);', ...
    strjoin(entries, ',\n'));

% Compute flux range for gradient normalization
if hasFluxColor
    allNums = [nodes.colorNum];
    validNums = allNums(isfinite(allNums));
    if isempty(validNums)
        fluxColorMin = 0; fluxColorMax = 1;
    else
        fluxColorMin = min(validNums);
        fluxColorMax = max(validNums);
    end
else
    fluxColorMin = 0; fluxColorMax = 1;
end

%% 3. Build the Links Structure
ends = G_main.Edges.EndNodes;
E = size(ends, 1);
mapNode = containers.Map(cellstr(nodeList), num2cell(0:N-1));
links = struct('source',cell(E,1),'target',cell(E,1),'isHighlighted',cell(E,1));
for k = 1:E
    sIdx = mapNode(char(ends(k,1)));
    tIdx = mapNode(char(ends(k,2)));

    links(k).source = sIdx;
    links(k).target = tIdx;

    % Edge is highlighted only if both endpoint nodes are highlighted
    if isfield(nodes, 'isHighlighted')
        links(k).isHighlighted = nodes(sIdx + 1).isHighlighted && nodes(tIdx + 1).isHighlighted;
    else
        links(k).isHighlighted = true;
    end
end

%% 4. Encode to JSON & Write HTML
nodesJson = strrep(jsonencode(nodes), '</script>', '<\/script>');
linksJson = strrep(jsonencode(links), '</script>', '<\/script>');

if N == 0
    nodesJson = '[]';
else
    nodesJson = strrep(jsonencode(nodes), '</script>', '<\/script>');
    if N == 1 && ~startsWith(nodesJson, "[")
        nodesJson = "[" + nodesJson + "]";
    end
end

if E == 0
    linksJson = '[]';
else
    linksJson = strrep(jsonencode(links), '</script>', '<\/script>');
    if E == 1 && ~startsWith(linksJson, "[")
        linksJson = "[" + linksJson + "]";
    end
end

fid = fopen(outFile, 'w');
fprintf(fid, '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><title>Network Viewer</title>\n');
fprintf(fid, ['<style>' ...
    'body{margin:0;overflow:hidden;background:#fbfbfb;font-family:Arial;}' ...
    '#banner{position:fixed;top:0;width:100%%;padding:6px 10px;background:#111;color:#fff;z-index:1000;font-size:12px;display:flex;gap:10px;align-items:center;}' ...
    '#search{margin-left:auto;margin-right:20px;}' ...
    '#q{padding:4px;border-radius:4px;}' ...
    '#wrap{position:fixed;top:28px;bottom:0;width:100%%;}' ...
    'canvas{display:block;}' ...
    '#tip{position:fixed;pointer-events:none;opacity:0;background:rgba(0,0,0,0.92);color:#fff;padding:10px;border-radius:8px;font-size:12px;max-width:400px;z-index:2000;transition:opacity 0.1s;}' ...
    '#legend{position:fixed;right:18px;bottom:18px;width:120px;padding:10px 10px 12px 10px;background:rgba(255,255,255,0.96);border:1px solid #cccccc;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.15);z-index:1500;display:none;}' ...
    '#legendTitle{font-size:12px;font-weight:bold;margin-bottom:8px;color:#222;}' ...
    '#legendInner{display:flex;align-items:stretch;gap:8px;}' ...
    '#legendBar{width:18px;height:180px;border:1px solid #777;border-radius:4px;flex:0 0 auto;}' ...
    '#legendTicks{height:180px;display:flex;flex-direction:column;justify-content:space-between;font-size:11px;color:#222;line-height:1;}' ...
    '</style>\n']);
fprintf(fid, ['</head><body>\n<div id="banner">' ...
    '<span id="status">Wheel: zoom | Drag bg: pan | Drag node: pin | Hover: info | Space: pause</span>' ...
    '<div id="search">' ...
    '<select id="captureFormat" style="margin-right:6px; padding:2px 4px; border-radius:4px;">' ...
    '<option value="png">PNG</option>' ...
    '<option value="pdf">PDF</option>' ...
    '<option value="html">Interactive HTML</option>' ...
    '<option value="cytoscape">Cytoscape Tables (.xlsx)</option>' ...
    '</select>' ...
    '<button id="btnExport" style="margin-right:10px; padding:2px 8px; cursor:pointer; color:black;">Capture View</button>' ...
    '<input id="q" placeholder="Find ID + Enter">' ...
    '</div></div>\n']);
fprintf(fid, ['<div id="wrap"><canvas id="c"></canvas></div>' ...
    '<div id="tip"></div>' ...
    '<div id="legend">' ...
    '<div id="legendTitle">FBA Flux</div>' ...
    '<div id="legendInner">' ...
    '<div id="legendBar"></div>' ...
    '<div id="legendTicks"></div>' ...
    '</div>' ...
    '</div>\n']);
fprintf(fid, '<script src="https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js"></script>\n');
fprintf(fid, '<script src="https://cdn.jsdelivr.net/npm/svg2pdf.js@2.5.0/dist/svg2pdf.umd.min.js"></script>\n');
fprintf(fid, '<script>\nconst nodesRaw = %s;\nconst linksRaw = %s;\nconst nodes = Array.isArray(nodesRaw) ? nodesRaw : [nodesRaw];\nconst links = Array.isArray(linksRaw) ? linksRaw : [linksRaw];\n', nodesJson, linksJson);
fprintf(fid, '%s\n', strrep(colorMapJS, '%', '%%'));
fprintf(fid, 'const fluxColorMin = %g;\n', fluxColorMin);
fprintf(fid, 'const fluxColorMax = %g;\n', fluxColorMax);
if hasFluxColor
    fprintf(fid, 'const hasFluxGradient = true;\n');
else
    fprintf(fid, 'const hasFluxGradient = false;\n');
end
fprintf(fid, 'const displayLabels = {"NodeSize":"Node Size","Size":"Plotted Size","ReactionKey":"Reaction ID","MetaboliteKey":"Metabolite ID","PathwayKey":"Pathway","FormulaKey":"Formula","FBA_Flux":"FBA Flux","FBAFlux":"FBA Flux","GeneAssociation":"Gene Association","MetaboliteClass":"Metabolite Class","Reversibility":"Reversibility"};\n');
fprintf(fid, 'const skipKeys = new Set(["ColorGroup","HighlightFlag","FluxColor", "Size"]);\n');
fprintf(fid, 'const exportedNodeCount = %d;\n', N);
fprintf(fid, 'const exportedEdgeCount = %d;\n', E);
if labelBy == "None"
    fprintf(fid, 'const showTextLabels = false;\n');
else
    fprintf(fid, 'const showTextLabels = true;\n');
end
if exportMode
    fprintf(fid, 'const exportMode = true;\n');
else
    fprintf(fid, 'const exportMode = false;\n');
end

jsLines = {
    'let matlabComponent = null;'
    'function setup(htmlComponent) {'
    '  matlabComponent = htmlComponent;'
    '}'
    'const canvas = document.getElementById("c"), ctx = canvas.getContext("2d"), wrap = document.getElementById("wrap"), tip = document.getElementById("tip"), q = document.getElementById("q"), status = document.getElementById("status");'
    'window.onerror = function(msg, src, line, col, err){ status.textContent = "JS ERROR: " + msg + " @ line " + line; return false; };'
    'window.onunhandledrejection = function(e){ console.error(e.reason); status.textContent = "PROMISE ERROR: " + (e.reason && e.reason.message ? e.reason.message : e.reason); };'
    'window.onunhandledrejection = function(e){ console.error(e.reason); status.textContent = "PROMISE ERROR: " + (e.reason && e.reason.message ? e.reason.message : e.reason); };'
    'function resize() { canvas.width = wrap.clientWidth; canvas.height = wrap.clientHeight; }'
    'window.addEventListener("resize", resize); resize();'
    'status.textContent = `Nodes: ${exportedNodeCount} | Edges: ${exportedEdgeCount} | Wheel: zoom | Drag bg: pan | Drag node: pin | Hover: info | Space: pause`;'
    'let zoom = 0.5, panX = 0, panY = 0; function W() { return canvas.width; } function H() { return canvas.height; }'
    'function worldToScreen(x,y) { return { x: W()/2 + (x + panX)*zoom, y: H()/2 + (y + panY)*zoom }; }'
    'function screenToWorld(x,y) { return { x: (x - W()/2)/zoom - panX, y: (y - H()/2)/zoom - panY }; }'
    'function fitView(){'
    '  if(nodes.length===0) return;'
    '  let minX=Infinity, maxX=-Infinity, minY=Infinity, maxY=-Infinity;'
    '  for(const n of nodes){'
    '    if(n.x<minX) minX=n.x;'
    '    if(n.x>maxX) maxX=n.x;'
    '    if(n.y<minY) minY=n.y;'
    '    if(n.y>maxY) maxY=n.y;'
    '  }'
    '  const spanX = Math.max(1, maxX-minX);'
    '  const spanY = Math.max(1, maxY-minY);'
    '  const midX = (minX+maxX)/2;'
    '  const midY = (minY+maxY)/2;'
    '  const pad = exportMode ? 80 : ((W() > 1500) ? 600 : 150);'
    '  const zx = (W()-pad)/spanX;'
    '  const zy = (H()-pad)/spanY;'
    '  zoom = Math.max(0.08, Math.min(exportMode ? 20 : 12, 0.95 * Math.min(zx, zy)));'
    '  panX = -midX;'
    '  panY = -midY;'
    '}'
    'function initNodePositions(){'
    '  if(nodes.length===1){'
    '    nodes[0].x = 0;'
    '    nodes[0].y = 0;'
    '  } else if(nodes.length===2){'
    '    nodes[0].x = -120; nodes[0].y = 0;'
    '    nodes[1].x =  120; nodes[1].y = 0;'
    '  } else if(nodes.length===3){'
    '    nodes[0].x =   0; nodes[0].y = -120;'
    '    nodes[1].x = -100; nodes[1].y =  80;'
    '    nodes[2].x =  100; nodes[2].y =  80;'
    '  } else if(nodes.length<=20){'
    '    const R = Math.max(100, 35*nodes.length);'
    '    nodes.forEach((n,i) => {'
    '      const ang = 2*Math.PI*i/nodes.length;'
    '      n.x = R*Math.cos(ang);'
    '      n.y = R*Math.sin(ang);'
    '    });'
    '  } else {'
    '    nodes.forEach(n => {'
    '      n.x = (Math.random()-0.5)*600;'
    '      n.y = (Math.random()-0.5)*600;'
    '    });'
    '  }'
    '  nodes.forEach(n => { n.vx = 0; n.vy = 0; n.fx = null; n.fy = null; });'
    '}'
    'initNodePositions();'
    'fitView();'
    'const ultraSmallGraph = nodes.length <= 3 || links.length <= 2;'
    'let running = true;'
    'let autoFitFrames = exportMode ? 0 : 60;'
    'const springLen = ultraSmallGraph ? 120 : (exportMode ? 120 : 30), kSpring = ultraSmallGraph ? 0.01 : (exportMode ? 0.012 : 0.02), kRepel = ultraSmallGraph ? 40 : (exportMode ? 1800 : 200), damp = ultraSmallGraph ? 0.92 : (exportMode ? 0.90 : 0.85), dt = exportMode ? 1.0 : 0.8;'
    'const palette = ["#1f77b4","#ff7f0e","#2ca02c","#d62728","#9467bd","#8c564b","#e377c2","#17becf","#bcbd22","#aec7e8","#ffbb78","#98df8a","#ff9896","#c5b0d5","#c49c94","#f7b6d2","#dbdb8d","#9edae5","#393b79","#637939"];'
    'const pathwayHighlightActive = nodes.some(n => n.isHighlighted === false);'
    'const colorMap = new Map(); let cIdx = 0;'
    'function nodeRadius(n) { const v = Math.abs(n.sizeVal); if(!isFinite(v) || v < 1e-6) return 5; return Math.max(0.5, Math.min(28, 5 + 3.54 * Math.sqrt(v))); }'
    'function lerpRGB(c1,c2,t){return[Math.round(c1[0]+(c2[0]-c1[0])*t),Math.round(c1[1]+(c2[1]-c1[1])*t),Math.round(c1[2]+(c2[2]-c1[2])*t)];}'
    'function toHex(rgb){return"#"+rgb.map(v=>v.toString(16).padStart(2,"0")).join("");}'
    'function escapeXML(s){return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/''/g,"&apos;");}'
    'function fluxToColor(v){if(!isFinite(v))return"#888888";if(Math.abs(v)<1e-6)return"#cccccc";if(v<0){const t=Math.min(1,Math.abs(v)/Math.max(1e-6,Math.abs(fluxColorMin)));return toHex(lerpRGB([200,220,255],[0,50,200],t));}const t=Math.min(1,v/Math.max(1e-6,fluxColorMax));return toHex(lerpRGB([255,220,180],[200,30,0],t));}'
    'function fluxToLegendColor(v, legendMin, legendMax){if(!isFinite(v))return"#888888";if(Math.abs(v)<1e-6)return"#cccccc";if(v<0){const denom=Math.max(1e-6,Math.abs(Math.min(legendMin,0)));const t=Math.min(1,Math.abs(v)/denom);return toHex(lerpRGB([200,220,255],[0,50,200],t));}const denom=Math.max(1e-6,Math.max(legendMax,0));const t=Math.min(1,v/denom);return toHex(lerpRGB([255,220,180],[200,30,0],t));}'
    'function formatLegendValue(v){if(!isFinite(v)) return "NA"; const av=Math.abs(v); if(av>=1000 || (av>0 && av<0.01)) return v.toExponential(2); return v.toFixed(2);}'
    'function buildFluxLegend(){'
    '  const legend = document.getElementById("legend");'
    '  const legendTitle = document.getElementById("legendTitle");'
    '  const legendBar = document.getElementById("legendBar");'
    '  const legendTicks = document.getElementById("legendTicks");'
    '  if(!hasFluxGradient){ legend.style.display = "none"; return; }'
    '  legend.style.display = "block";'
    '  legendTitle.textContent = "FBA Flux";'
    '  if(fluxColorMin < 0 && fluxColorMax > 0){'
    '    legendBar.style.background = `linear-gradient(to top, ${fluxToColor(fluxColorMin)} 0%, ${fluxToColor(0)} 50%, ${fluxToColor(fluxColorMax)} 100%)`;'
    '    legendTicks.innerHTML = `<span>${formatLegendValue(fluxColorMax)}</span><span>0</span><span>${formatLegendValue(fluxColorMin)}</span>`;'
    '  } else if(fluxColorMax <= 0){'
    '    legendBar.style.background = `linear-gradient(to top, ${fluxToColor(0)} 0%, ${fluxToColor(fluxColorMin)} 100%)`;'
    '    legendTicks.innerHTML = `<span>0</span><span>${formatLegendValue(fluxColorMin)}</span>`;'
    '  } else {'
    '    legendBar.style.background = `linear-gradient(to top, ${fluxToColor(fluxColorMax)} 0%, ${fluxToColor(0)} 100%)`;'
    '    legendTicks.innerHTML = `<span>${formatLegendValue(fluxColorMax)}</span><span>0</span>`;'
    '  }'
    '}'
    'function nodeColors(n){if(pathwayHighlightActive && !n.isHighlighted){return{fill:"#d9d9d9",stroke:"#a6a6a6"};}if(hasFluxGradient&&isFinite(n.colorNum)){return{fill:fluxToColor(n.colorNum),stroke:"#222222"};}const v=n.colorVal;if(!v||v==="Unassigned")return{fill:"#cccccc",stroke:"#555555"};const hex=presetColorMap.get(v)||"#aaaaaa";return{fill:hex,stroke:"#222222"};}'
    'buildFluxLegend();'
    'function step() { if(!running) return;'
    'const cellSize = 150; const grid = new Map();'
    'for(let i=0; i<nodes.length; i++){ const n=nodes[i], k=Math.floor(n.x/cellSize)+","+Math.floor(n.y/cellSize); if(!grid.has(k)) grid.set(k, []); grid.get(k).push(n); }'
    'for(let i=0; i<nodes.length; i++){ const a=nodes[i], cx=Math.floor(a.x/cellSize), cy=Math.floor(a.y/cellSize);'
    'for(let dx=-1; dx<=1; dx++){ for(let dy=-1; dy<=1; dy++){ const cell=grid.get((cx+dx)+","+(cy+dy)); if(!cell) continue;'
    'for(let j=0; j<cell.length; j++){ const b=cell[j]; if(a===b) continue; const dX=a.x-b.x, dY=a.y-b.y, d2=dX*dX+dY*dY+5.0;'
    'if(d2 < 20000){ const f=kRepel/d2; a.vx+=f*dX; a.vy+=f*dY; } } } } }'
    'for(const e of links){ const a=nodes[e.source], b=nodes[e.target]; if(!a || !b) continue; const dx=b.x-a.x, dy=b.y-a.y, dist=Math.sqrt(dx*dx+dy*dy)+1e-6, f=kSpring*(dist-springLen)/dist; a.vx+=f*dx; a.vy+=f*dy; b.vx-=f*dx; b.vy-=f*dy; }'
    'for(const n of nodes){ if(n.fx!==null){n.x=n.fx; n.y=n.fy; n.vx=0; n.vy=0; continue;} n.vx*=damp; n.vy*=damp; let vMag=Math.sqrt(n.vx*n.vx+n.vy*n.vy); if(vMag>25){n.vx=(n.vx/vMag)*25; n.vy=(n.vy/vMag)*25;} n.x+=n.vx*dt; n.y+=n.vy*dt; } }'
    'function draw() { ctx.fillStyle="#fbfbfb"; ctx.fillRect(0,0,W(),H()); const cx = W()/2, cy = H()/2;'
    'let drawnEdges = 0;'
    'for(const e of links) { const a = nodes[e.source], b = nodes[e.target]; if(!a || !b) continue;'
    'const Ax = cx + (a.x + panX)*zoom, Ay = cy + (a.y + panY)*zoom, Bx = cx + (b.x + panX)*zoom, By = cy + (b.y + panY)*zoom;'
    'if (!ultraSmallGraph && ((Ax < 0 && Bx < 0) || (Ay < 0 && By < 0) || (Ax > W() && Bx > W()) || (Ay > H() && By > H()))) continue;'
    'if(pathwayHighlightActive){ if(e.isHighlighted){ ctx.globalAlpha = 0.9; ctx.strokeStyle = "#606060"; ctx.lineWidth = Math.max(0.5, 1.2 * zoom); } else { ctx.globalAlpha = 0.25; ctx.strokeStyle = "#c8c8c8"; ctx.lineWidth = Math.max(0.25, 0.6 * zoom); } } else { ctx.globalAlpha = 0.7; ctx.strokeStyle = "#606060"; ctx.lineWidth = Math.max(0.3, 0.8 * zoom); }'
    'ctx.beginPath(); ctx.moveTo(Ax, Ay); ctx.lineTo(Bx, By); ctx.stroke(); drawnEdges++; }'
    'ctx.globalAlpha = 1.0;'
    'ctx.globalAlpha = 1.0; const minR = Math.max(0.45, 1.2 * Math.sqrt(zoom));'
    'for(const n of nodes) { const Px = cx + (n.x + panX)*zoom, Py = cy + (n.y + panY)*zoom, r = nodeRadius(n) * minR;'
    'if (!ultraSmallGraph && (Px+r < 0 || Py+r < 0 || Px-r > W() || Py-r > H())) continue;'
    'const c = nodeColors(n); ctx.fillStyle = c.fill; ctx.strokeStyle = c.stroke; ctx.lineWidth = 1.0; ctx.beginPath(); ctx.arc(Px, Py, r, 0, 2*Math.PI); ctx.fill(); ctx.stroke(); }'
    'if (showTextLabels) {'
    '  ctx.textAlign = "center"; ctx.textBaseline = "middle";'
    '  for(const n of nodes) {'
    '    const Px = cx + (n.x + panX)*zoom, Py = cy + (n.y + panY)*zoom, r = nodeRadius(n) * minR;'
    '    if (!ultraSmallGraph && (Px+r < 0 || Py+r < 0 || Px-r > W() || Py-r > H())) continue;'
    '    let fSize = Math.max(10, r * 1.2);'
    '    if (fSize > 48) fSize = 48;'
    '    ctx.font = "bold " + fSize + "px Arial, sans-serif";'
    '    ctx.lineWidth = fSize * 0.25;'
    '    ctx.strokeStyle = "rgba(255,255,255,0.85)";'
    '    const label = n.labelText || "";'
    '    if(label !== "") {'
    '      ctx.strokeText(label, Px, Py);'
    '      ctx.fillStyle = "#111111";'
    '      ctx.fillText(label, Px, Py);'
    '    }'
    '  }'
    '}'
    '}'
    'let frameSkip = 0;'
    'if (exportMode) {'
    '  const oldRunning = running;'
    '  running = true;'
    '  for(let i=0; i<1500; i++) step();'
    '  fitView();'
    '  running = false;'
    '}'
    'draw();'
    'function loop() {'
    '  step();'
    '  if(autoFitFrames > 0){'
    '    fitView();'
    '    autoFitFrames--;'
    '  }'
    '  if(nodes.length > 2000 && running) {'
    '    frameSkip++;'
    '    if(frameSkip >= 3) {'
    '      draw();'
    '      frameSkip = 0;'
    '    }'
    '  } else {'
    '    draw();'
    '  }'
    '  requestAnimationFrame(loop);'
    '}'
    'loop();'
    'function findNode(sx,sy) { const w=screenToWorld(sx,sy); let best=null, bestD2=1e18; for(const n of nodes){ const r=nodeRadius(n), dx=n.x-w.x, dy=n.y-w.y, d2=dx*dx+dy*dy; if(d2<(r/zoom)*(r/zoom)*3.0 && d2<bestD2){bestD2=d2; best=n;} } return best; }'
    'let dragNode=null, dragging=false, lastX=0, lastY=0;'
    'canvas.addEventListener("mousedown", e => { dragging=true; lastX=e.clientX; lastY=e.clientY; const hit=findNode(e.clientX,e.clientY); if(hit){dragNode=hit; dragNode.fx=dragNode.x; dragNode.fy=dragNode.y;} });'
    'window.addEventListener("mouseup", () => { dragging=false; dragNode=null; });'
    'canvas.addEventListener("mousemove", e => { if(dragging){ if(dragNode){ const w=screenToWorld(e.clientX,e.clientY); dragNode.fx=w.x; dragNode.fy=w.y; }else{ panX+=(e.clientX-lastX)/zoom; panY+=(e.clientY-lastY)/zoom; } lastX=e.clientX; lastY=e.clientY; return; }'
    'const hit=findNode(e.clientX,e.clientY); if(hit){ tip.style.opacity=1; tip.style.left=(e.clientX+15)+"px"; tip.style.top=(e.clientY+15)+"px";'
    'let html=`<b style="color:#1f77b4;font-size:14px;">${hit.nameID}</b><hr style="margin:4px 0;border-color:#444;">`;'
    'for(const [k,v] of Object.entries(hit.info)){ if(skipKeys.has(k)) continue; if(v !== null && v !== undefined && v !== "") { const label = displayLabels[k] || k; html+=`<b>${label}:</b> ${v}<br>`; } }'
    'tip.innerHTML=html; }else{ tip.style.opacity=0; } });'
    'canvas.addEventListener("wheel", e => { e.preventDefault(); const before=screenToWorld(e.clientX,e.clientY), z=Math.exp(-e.deltaY*0.0015); zoom=Math.max(0.05,Math.min(15,zoom*z)); const after=screenToWorld(e.clientX,e.clientY); panX+=after.x-before.x; panY+=after.y-before.y; }, {passive:false});'
    'window.addEventListener("keydown", e => { if(e.code==="Space") running=!running; });'
    'const mapByID = new Map(nodes.map(n => [n.nameID.toLowerCase(), n]));'
    'q.addEventListener("keydown", e => { if(e.key==="Enter"){ const n=mapByID.get(q.value.trim().toLowerCase()); if(n){ panX=-n.x; panY=-n.y; zoom=1.5; } } });'
    'function buildExportCanvas() {'
    '  const exportCanvas = document.createElement("canvas");'
    '  exportCanvas.width = canvas.width;'
    '  exportCanvas.height = canvas.height;'
    ''
    '  const ex = exportCanvas.getContext("2d");'
    ''
    '  ex.drawImage(canvas, 0, 0);'
    ''
    '  if(hasFluxGradient) {'
    ''
    '    const barX = exportCanvas.width - 90;'
    '    const barY = exportCanvas.height - 240;'
    '    const barW = 22;'
    '    const barH = 180;'
    ''
    '    ex.fillStyle = "rgba(255,255,255,0.96)";'
    '    ex.strokeStyle = "#cccccc";'
    '    ex.lineWidth = 1;'
    '    ex.beginPath();'
    '    ex.roundRect(barX - 20, barY - 35, 70, 230, 8);'
    '    ex.fill();'
    '    ex.stroke();'
    ''
    '    const grad = ex.createLinearGradient(0, barY + barH, 0, barY);'
    ''
    '    if(fluxColorMin < 0 && fluxColorMax > 0) {'
    '      grad.addColorStop(0.0, fluxToColor(fluxColorMin));'
    '      const zeroPos = (0 - fluxColorMin) / (fluxColorMax - fluxColorMin);'
    '      grad.addColorStop(zeroPos, fluxToColor(0));'
    '      grad.addColorStop(1.0, fluxToColor(fluxColorMax));'
    '    } else if(fluxColorMax <= 0) {'
    '      grad.addColorStop(0.0, fluxToColor(0));'
    '      grad.addColorStop(1.0, fluxToColor(fluxColorMin));'
    '    } else {'
    '      grad.addColorStop(0.0, fluxToColor(fluxColorMax));'
    '      grad.addColorStop(1.0, fluxToColor(0));'
    '    }'
    ''
    '    ex.fillStyle = grad;'
    '    ex.fillRect(barX, barY, barW, barH);'
    ''
    '    ex.strokeStyle = "#666";'
    '    ex.strokeRect(barX, barY, barW, barH);'
    ''
    '    ex.fillStyle = "#111";'
    '    ex.font = "12px Arial";'
    '    ex.textAlign = "left";'
    ''
    '    ex.fillText("FBA Flux", barX - 6, barY - 12);'
    ''
    '    ex.fillText(formatLegendValue(fluxColorMax), barX + 28, barY + 6);'
    ''
    '    if(fluxColorMin < 0 && fluxColorMax > 0) {'
    '      ex.fillText("0", barX + 28, barY + barH/2 + 4);'
    '    }'
    ''
    '    ex.fillText(formatLegendValue(fluxColorMin), barX + 28, barY + barH);'
    '  }'
    ''
    '  return exportCanvas;'
    '}'
    'function exportSVGString() {'
    '  const w = canvas.width;'
    '  const h = canvas.height;'
    ''
    '  let svg = [];'
    ''
    '  svg.push(`<?xml version="1.0" encoding="UTF-8"?>`);'
    '  svg.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">`);'
    '  svg.push(`<rect width="100%" height="100%" fill="#fbfbfb"/>`);'
    ''
    '  const cx = w/2;'
    '  const cy = h/2;'
    ''
    '  for(const e of links) {'
    '    const a = nodes[e.source];'
    '    const b = nodes[e.target];'
    '    if(!a || !b) continue;'
    ''
    '    const Ax = cx + (a.x + panX)*zoom;'
    '    const Ay = cy + (a.y + panY)*zoom;'
    '    const Bx = cx + (b.x + panX)*zoom;'
    '    const By = cy + (b.y + panY)*zoom;'
    ''
    '    svg.push(`<line x1="${Ax}" y1="${Ay}" x2="${Bx}" y2="${By}" stroke="#666" stroke-width="1"/>`);'
    '  }'
    ''
    '  for(const n of nodes) {'
    '    const Px = cx + (n.x + panX)*zoom;'
    '    const Py = cy + (n.y + panY)*zoom;'
    '    const r = nodeRadius(n) * Math.max(0.45, 1.2 * Math.sqrt(zoom));'
    ''
    '    const c = nodeColors(n);'
    ''
    '    svg.push(`<circle cx="${Px}" cy="${Py}" r="${r}" fill="${c.fill}" stroke="${c.stroke}" stroke-width="1"/>`);'
    ''
    '    if(showTextLabels) {'
    '      const fs = Math.min(48, Math.max(10, r * 1.2));'
    ''
    '    const label = escapeXML(n.labelText || "");'
    '    if(label !== "") {'
    '      svg.push(`<text x="${Px}" y="${Py}" font-size="${fs}" font-family="Arial" text-anchor="middle" dominant-baseline="middle" fill="#111">${label}</text>`);'
    '    }'
    '    }'
    '  }'
    ''
    '  if(hasFluxGradient) {'
    ''
    '    const barX = w - 90;'
    '    const barY = h - 240;'
    '    const barW = 22;'
    '    const barH = 180;'
    ''
    '    svg.push(`<rect x="${barX-20}" y="${barY-35}" width="70" height="230" rx="8" fill="#ffffff" fill-opacity="0.96" stroke="#cccccc"/>`);'
    ''
    '    let gradStops = [];'
    ''
    '    const nStops = 80;'
    ''
    '    let legendMin = fluxColorMin;'
    '    let legendMax = fluxColorMax;'
    ''
    '    if(fluxColorMin >= 0 && fluxColorMax > 0) {'
    '      legendMin = 0;'
    '      legendMax = fluxColorMax;'
    '    } else if(fluxColorMax <= 0 && fluxColorMin < 0) {'
    '      legendMin = fluxColorMin;'
    '      legendMax = 0;'
    '    } else if(fluxColorMin === fluxColorMax) {'
    '      legendMin = Math.min(0, fluxColorMin);'
    '      legendMax = Math.max(1, fluxColorMax);'
    '    }'
    ''
    '    const legendSpan = Math.max(1e-12, legendMax - legendMin);'
    ''
    '    for(let i = 0; i <= nStops; i++) {'
    '      const t = i / nStops;'
    '      const val = legendMin + t * legendSpan;'
    '      const col = fluxToLegendColor(val);'
    '      const pct = 100 * t;'
    '      gradStops.push(`<stop offset="${pct}%" stop-color="${col}"/>`);'
    '    }'
    ''
    '    svg.push(`'
    '      <defs>'
    '        <linearGradient id="fluxGrad" x1="0%" y1="100%" x2="0%" y2="0%">'
    '          ${gradStops.join("")}'
    '        </linearGradient>'
    '      </defs>'
    '    `);'
    ''
    '    const nLegendBands = 120;'
    '    const bandH = barH / nLegendBands;'
    ''
    '    for(let bi = 0; bi < nLegendBands; bi++) {'
    '      const tMid = (bi + 0.5) / nLegendBands;'
    '      const val = legendMax - tMid * (legendMax - legendMin);'
    '      const col = fluxToColor(val);'
    '      const yBand = barY + bi * bandH;'
    '      svg.push(`<rect x="${barX}" y="${yBand}" width="${barW}" height="${bandH + 0.3}" fill="${col}" stroke="none"/>`);'
    '    }'
    ''
    '    svg.push(`<rect x="${barX}" y="${barY}" width="${barW}" height="${barH}" fill="none" stroke="#666"/>`);'
    ''
    '    svg.push(`<text x="${barX-6}" y="${barY-12}" font-size="12" font-family="Arial" fill="#111">FBA Flux</text>`);'
    ''
    '    svg.push(`<text x="${barX+30}" y="${barY+6}" font-size="11" font-family="Arial" fill="#111">${formatLegendValue(legendMax)}</text>`);'
    ''
    '    if(legendMin < 0 && legendMax > 0) {'
    '      const zeroY = barY + barH * (1 - ((0 - legendMin) / Math.max(1e-12, legendMax - legendMin)));'
    '      svg.push(`<text x="${barX+30}" y="${zeroY+4}" font-size="11" font-family="Arial" fill="#111">0</text>`);'
    '    }'
    ''
    '    svg.push(`<text x="${barX+30}" y="${barY+barH}" font-size="11" font-family="Arial" fill="#111">${formatLegendValue(legendMin)}</text>`);'
    '  }'
    '  svg.push(`</svg>`);'
    ''
    '  return svg.join("");'
    '}'
    'document.getElementById("btnExport").addEventListener("click", async () => {'
    '  const fmt = document.getElementById("captureFormat").value;'
    ''
    '  if(fmt === "html") {'
    '    try {'
    '      if(matlabComponent) {'
    '        status.textContent = "Sending Interactive HTML export request to MATLAB...";'
    '        matlabComponent.Data = "CAPTURE_VIEW_HTML::" + Date.now().toString() + "::" + Math.random().toString(36).slice(2);'
    '      } else {'
    '        status.textContent = "MATLAB bridge unavailable.";'
    '        alert("Interactive HTML export is available only inside the BiGGViz app.");'
    '      }'
    '    } catch(err) {'
    '      console.error(err);'
    '      status.textContent = "Interactive HTML export failed: " + err.message;'
    '      alert("Interactive HTML export failed: " + err.message);'
    '    }'
    '    return;'
    '  }'
    ''
    '  if(fmt === "cytoscape") {'
    '    try {'
    '      if(matlabComponent) {'
    '        status.textContent = "Sending Cytoscape table export request to MATLAB...";'
    '        matlabComponent.Data = "CAPTURE_VIEW_CYTOSCAPE::" + Date.now().toString() + "::" + Math.random().toString(36).slice(2);'
    '      } else {'
    '        status.textContent = "MATLAB bridge unavailable.";'
    '        alert("Cytoscape table export is available only inside the BiGGViz app.");'
    '      }'
    '    } catch(err) {'
    '      console.error(err);'
    '      status.textContent = "Cytoscape export failed: " + err.message;'
    '      alert("Cytoscape export failed: " + err.message);'
    '    }'
    '    return;'
    '  }'
    ''
    '  const exportCanvas = buildExportCanvas();'
    '  const imgData = exportCanvas.toDataURL("image/png");'
    ''
    '  if(fmt === "png") {'
    '    const lnk = document.createElement("a");'
    '    lnk.download = "BiGGViz_CaptureView.png";'
    '    lnk.href = imgData;'
    '    lnk.click();'
    '  } else if(fmt === "pdf") {'
    '    try {'
    '      const svgString = exportSVGString();'
    ''
    '      if(matlabComponent) {'
    '        status.textContent = "Sending Capture View PDF request to MATLAB...";'
    '        matlabComponent.Data = "CAPTURE_VIEW_PDF::" + Date.now().toString() + "::" + encodeURIComponent(svgString);'
    '      } else {'
    '        status.textContent = "MATLAB bridge unavailable.";'
    '        alert("PDF export is available only inside the BiGGViz app.");'
    '      }'
    '    } catch(err) {'
    '      console.error(err);'
    '      status.textContent = "PDF export failed: " + err.message;'
    '      alert("PDF export failed: " + err.message);'
    '    }'
    '  }'
    '});'
    };

for i = 1:numel(jsLines)
    fprintf(fid, '%s\n', jsLines{i});
end

fprintf(fid, '</script></body></html>\n');
fclose(fid);
disp(['Success! Exported ', num2str(N), ' nodes.']);
end
