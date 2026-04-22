function FEM_Main()
% =========================================================================
% 三结点三角形常应变单元有限元程序 (CST)
% 控制面板右移版 + 全新配色
% =========================================================================

    % ---- 全局应用数据结构 ----
    app = struct();
    app.NN    = 0;
    app.NE    = 0;
    app.CX    = [];
    app.CY    = [];
    app.LOC   = [];
    
    app.E     = 1.0;
    app.ANU   = 0.0;
    app.T     = 1.0;
    app.GM    = 0.0;
    app.NTYPE = 1;
    
    app.constraints = zeros(0,3);
    app.loads       = zeros(0,3);
    
    app.U     = [];
    app.STRES = [];
    app.STRAN = [];
    app.F_react = [];
    app.solved  = false;
    
    % ---- 构建主窗口 ----
    fig = figure('Name','CST有限元分析系统 ','NumberTitle','off',...
        'Position',[60 60 1400 820],...
        'Resize','on','MenuBar','none','ToolBar','none',...
        'Color',[0.90 0.92 0.95],'CloseRequestFcn',@onClose);
    
    fig.UserData = app;
    buildUI(fig);
end

% =========================================================================
%  UI 构建（控制面板在右侧 + 全新配色）
% =========================================================================
function buildUI(fig)
    % ==== 全新配色方案：现代科技蓝 ====
    clr_panel    = [0.12 0.25 0.45];   % 深蓝面板
    clr_btn_blue = [0.20 0.50 0.85];   % 主按钮蓝
    clr_btn_green= [0.15 0.70 0.55];   % 约束按钮绿
    clr_btn_orng = [0.90 0.55 0.20];   % 载荷按钮橙
    clr_btn_gray = [0.45 0.50 0.55];   % 清除按钮灰
    clr_btext    = [1.00 1.00 1.00];   % 按钮文字白
    clr_txt_gray = [0.75 0.80 0.85];   % 面板文字灰

    % ---- 1. 左侧：网格显示区（原中间位置左移） ----
    pMesh = uipanel(fig,'Position',[0.00 0.50 0.50 0.50],...
        'Title','网格模型 / 边界条件','FontSize',10,'FontWeight','bold',...
        'BackgroundColor','w','ForegroundColor',[0.12 0.25 0.45]);
    ax_mesh = axes(pMesh,'Tag','axMesh');
    axis(ax_mesh,'equal'); grid(ax_mesh,'on');
    ax_mesh.XLabel.String = 'x'; ax_mesh.YLabel.String = 'y';
    title(ax_mesh,'载入网格后点击结点设置边界条件','FontSize',9);
    
    % ---- 2. 左中：结果云图区（原右上位置左移） ----
    pResult = uipanel(fig,'Position',[0.00 0.00 0.50 0.50],...
        'Title','结果云图','FontSize',10,'FontWeight','bold',...
        'BackgroundColor','w','ForegroundColor',[0.12 0.25 0.45]);
    ax_res = axes(pResult,'Tag','axResult');
    axis(ax_res,'equal'); grid(ax_res,'on');
    
    % 云图控制（移到左侧云图上方）
    uicontrol(fig,'Style','text','String','显示结果：',...
        'Units','normalized','Position',[0.02 0.965 0.06 0.025],...
        'FontSize',9,'BackgroundColor',[0.90 0.92 0.95],...
        'HorizontalAlignment','left','ForegroundColor',[0.12 0.25 0.45]);
    uicontrol(fig,'Style','popupmenu','Tag','pmResult',...
        'String',{'X位移 Ux','Y位移 Uy','合位移 |U|',...
                  'X正应力 σx','Y正应力 σy','剪应力 τxy',...
                  'X正应变 εx','Y正应变 εy','剪应变 γxy',...
                  'Mises等效应力'},...
        'Units','normalized','Position',[0.08 0.963 0.20 0.03],...
        'FontSize',9,'BackgroundColor','w','ForegroundColor',[0.12 0.25 0.45],...
        'Callback',@(s,e)updateResultPlot(fig));
    
    uicontrol(fig,'Style','checkbox','Tag','chkDeform',...
        'String','叠加变形','Value',1,...
        'Units','normalized','Position',[0.29 0.965 0.08 0.025],...
        'FontSize',9,'BackgroundColor',[0.90 0.92 0.95],...
        'ForegroundColor',[0.12 0.25 0.45],...
        'Callback',@(s,e)updateResultPlot(fig));

    % ---- 3. 右侧：控制面板（全新位置+全新配色） ----
    pRight = uipanel(fig,'Position',[0.78 0.00 0.22 1.00],...
        'BackgroundColor',clr_panel,'BorderType','line','Title','');
    
    % -- 标题区 --
    uicontrol(pRight,'Style','text','String','CST FEM',...
        'Units','normalized','Position',[0.04 0.94 0.92 0.04],...
        'FontSize',18,'FontWeight','bold','HorizontalAlignment','center',...
        'BackgroundColor',clr_panel,'ForegroundColor',[0.95 0.95 0.98]);
    
    uicontrol(pRight,'Style','text','String','平面应力/应变分析',...
        'Units','normalized','Position',[0.04 0.915 0.92 0.02],...
        'FontSize',8,'HorizontalAlignment','center',...
        'BackgroundColor',clr_panel,'ForegroundColor',clr_txt_gray);
    
    % -- 文件加载区 --
    uicontrol(pRight,'Style','text','String','▌ 网格文件',...
        'Units','normalized','Position',[0.04 0.86 0.92 0.03],...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',[0.95 0.95 0.98]);
    
    uicontrol(pRight,'Style','pushbutton','String','📂  载入网格 (.txt)',...
        'Units','normalized','Position',[0.04 0.815 0.92 0.045],...
        'FontSize',9,'BackgroundColor',clr_btn_blue,'ForegroundColor',clr_btext,...
        'Callback',@(s,e)loadMesh(fig));
    
    hMeshInfo = uicontrol(pRight,'Style','text',...
        'String','未载入网格','Tag','meshInfo',...
        'Units','normalized','Position',[0.04 0.790 0.92 0.025],...
        'FontSize',8,'HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',clr_txt_gray);
    
    % -- 材料参数区 --
    uicontrol(pRight,'Style','text','String','▌ 材料与几何参数',...
        'Units','normalized','Position',[0.04 0.745 0.92 0.03],...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',[0.95 0.95 0.98]);
    
    labels = {'弹性模量 E','泊松比 ν','厚度 T','材料重度 GM'};
    tags   = {'edE','edANU','edT','edGM'};
    defs   = {'1.0','0.0','1.0','0.0'};
    for k = 1:4
        yp = 0.715 - (k-1)*0.048;
        uicontrol(pRight,'Style','text','String',labels{k},...
            'Units','normalized','Position',[0.04 yp+0.015 0.45 0.025],...
            'FontSize',8,'HorizontalAlignment','left',...
            'BackgroundColor',clr_panel,'ForegroundColor',clr_txt_gray);
        uicontrol(pRight,'Style','edit','String',defs{k},'Tag',tags{k},...
            'Units','normalized','Position',[0.51 yp+0.012 0.45 0.028],...
            'FontSize',9,'BackgroundColor',[0.08 0.18 0.35],...
            'ForegroundColor',clr_btext);
    end
    
    % 问题类型
    yp = 0.715 - 4*0.048;
    uicontrol(pRight,'Style','text','String','问题类型',...
        'Units','normalized','Position',[0.04 yp+0.015 0.45 0.025],...
        'FontSize',8,'HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',clr_txt_gray);
    uicontrol(pRight,'Style','popupmenu','String',{'平面应力','平面应变'},...
        'Tag','pmType','Units','normalized','Position',[0.51 yp+0.01 0.45 0.03],...
        'FontSize',8,'BackgroundColor',[0.08 0.18 0.35],...
        'ForegroundColor',clr_btext);
    
    % -- 约束与载荷说明 --
    yDiv1 = 0.485;
    uicontrol(pRight,'Style','text','String','▌ 边界条件',...
        'Units','normalized','Position',[0.04 yDiv1 0.92 0.03],...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',[0.95 0.95 0.98]);
    
    uicontrol(pRight,'Style','pushbutton','String','🔒  设置位移约束',...
        'Units','normalized','Position',[0.04 yDiv1-0.052 0.92 0.044],...
        'FontSize',9,'BackgroundColor',clr_btn_green,'ForegroundColor',clr_btext,...
        'Callback',@(s,e)setConstraintMode(fig));
    
    uicontrol(pRight,'Style','pushbutton','String','→  施加节点载荷',...
        'Units','normalized','Position',[0.04 yDiv1-0.105 0.92 0.044],...
        'FontSize',9,'BackgroundColor',clr_btn_orng,'ForegroundColor',clr_btext,...
        'Callback',@(s,e)setLoadMode(fig));
    
    uicontrol(pRight,'Style','pushbutton','String','🗑  清除所有条件',...
        'Units','normalized','Position',[0.04 yDiv1-0.158 0.92 0.044],...
        'FontSize',9,'BackgroundColor',clr_btn_gray,'ForegroundColor',clr_btext,...
        'Callback',@(s,e)clearConditions(fig));
    
    % 模式提示
    uicontrol(pRight,'Style','text','Tag','modeLabel',...
        'String','当前模式：浏览',...
        'Units','normalized','Position',[0.04 yDiv1-0.195 0.92 0.032],...
        'FontSize',8,'FontWeight','bold',...
        'HorizontalAlignment','center','BackgroundColor',[0.95 0.95 0.80],...
        'ForegroundColor',[0.12 0.25 0.45]);
    
    % -- 已设条件列表 --
    uicontrol(pRight,'Style','text','String','▌ 已设条件列表',...
        'Units','normalized','Position',[0.04 0.265 0.92 0.030],...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','left',...
        'BackgroundColor',clr_panel,'ForegroundColor',[0.95 0.95 0.98]);
    
    uicontrol(pRight,'Style','listbox','Tag','condList',...
        'String',{},...
        'Units','normalized','Position',[0.04 0.07 0.92 0.19],...
        'FontSize',7.5,'BackgroundColor',[0.08 0.18 0.35],...
        'ForegroundColor',clr_btext);
    
    uicontrol(pRight,'Style','pushbutton','String','删除选中条件',...
        'Units','normalized','Position',[0.04 0.035 0.92 0.032],...
        'FontSize',8,'BackgroundColor',[0.75 0.25 0.25],...
        'ForegroundColor',clr_btext,...
        'Callback',@(s,e)deleteSelectedCondition(fig));
    
    % -- 求解按钮（放在最上方，更醒目） --
    uicontrol(pRight,'Style','pushbutton','String','▶  开始求解',...
        'Units','normalized','Position',[0.04 0.99-0.052 0.92 0.052],...
        'FontSize',11,'FontWeight','bold',...
        'BackgroundColor',[0.05 0.15 0.35],'ForegroundColor',clr_btext,...
        'Callback',@(s,e)runSolver(fig));
    
    % ---- 4. 中间：结果表格区（保持原位置，宽度调整） ----
    pTable = uipanel(fig,'Position',[0.50 0.00 0.28 1.00],...
        'Title','数值结果表格','FontSize',10,'FontWeight','bold',...
        'BackgroundColor','w','ForegroundColor',[0.12 0.25 0.45]);
    
    % 子标签按钮
    yBtn = 0.95;
    tnames = {'结点位移','结点反力','单元应力','单元应变'};
    ttags  = {'tbNode','tbReact','tbStress','tbStrain'};
    for k=1:4
        uicontrol(pTable,'Style','pushbutton','String',tnames{k},...
            'Units','normalized','Position',[0.05 yBtn-(k-1)*0.08 0.90 0.06],...
            'FontSize',9,'Tag',['btn_' ttags{k}],...
            'BackgroundColor',[0.70 0.80 0.92],...
            'ForegroundColor',[0.12 0.25 0.45],...
            'Callback',@(s,e)showTable(fig, ttags{k}));
    end
    
    % 表格容器
    tablePos = [0.05 0.02 0.90 0.60];
    uitable(pTable,'Tag','mainTable',...
        'Units','normalized','Position',tablePos,...
        'FontSize',9,'RowStriping','on',...
        'ColumnEditable',false);
    
    fig.Tag = 'FEM_MAIN';
    setappdata(fig,'interactMode','none');
end

% =========================================================================
%  以下所有功能函数完全保留，未做任何修改
% =========================================================================
function loadMesh(fig)
    [fname, fpath] = uigetfile('*.txt','选择网格文件');
    if isequal(fname,0), return; end
    fullpath = fullfile(fpath,fname);
    
    app = fig.UserData;
    try
        fid = fopen(fullpath,'r');
        while true
            line = fgetl(fid);
            if ~ischar(line), break; end
            s = strtrim(line);
            if isempty(s) || s(1)=='%', continue; end
            nums = sscanf(s,'%d %d');
            app.NN = nums(1);
            app.NE = nums(2);
            break;
        end
        
        app.CX  = zeros(app.NN,1);
        app.CY  = zeros(app.NN,1);
        app.LOC = zeros(app.NE,3);
        
        nRead = 0;
        while nRead < app.NN
            line = fgetl(fid);
            if ~ischar(line), break; end
            s = strtrim(line);
            if isempty(s)||s(1)=='%', continue; end
            v = sscanf(s,'%f');
            if length(v)<3, continue; end
            idx = round(v(1));
            app.CX(idx) = v(2);
            app.CY(idx) = v(3);
            nRead = nRead+1;
        end
        
        eRead = 0;
        while eRead < app.NE
            line = fgetl(fid);
            if ~ischar(line), break; end
            s = strtrim(line);
            if isempty(s)||s(1)=='%', continue; end
            v = sscanf(s,'%d');
            if length(v)<4, continue; end
            eid = v(1);
            app.LOC(eid,:) = v(2:4)';
            eRead = eRead+1;
        end
        fclose(fid);
        
        app.constraints = zeros(0,3);
        app.loads       = zeros(0,3);
        app.solved      = false;
        app.U=[];app.STRES=[];app.STRAN=[];app.F_react=[];
        
        fig.UserData = app;
        
        hInfo = findobj(fig,'Tag','meshInfo');
        hInfo.String = sprintf('  %d 结点   %d 单元   ✓',app.NN,app.NE);
        
        drawMesh(fig);
        
        hList = findobj(fig,'Tag','condList');
        hList.String = {};
        ht = findobj(fig,'Tag','mainTable');
        ht.Data = {};
        showTable(fig,'tbNode');
        
    catch ME
        errordlg(['网格文件读取失败：' ME.message],'错误');
    end
end

function drawMesh(fig)
    app = fig.UserData;
    if app.NN == 0, return; end
    
    ax = findobj(fig,'Tag','axMesh');
    cla(ax);
    hold(ax,'on');
    
    patch(ax, 'Vertices', [app.CX, app.CY], 'Faces', app.LOC, ...
          'FaceColor', [0.85 0.90 0.98], 'EdgeColor', [0.25 0.45 0.75], ...
          'LineWidth', 1.2, 'FaceAlpha', 0.6, 'HitTest', 'off');
          
    for e = 1:app.NE
        cx = mean(app.CX(app.LOC(e,:)));
        cy = mean(app.CY(app.LOC(e,:)));
        text(ax,cx,cy,sprintf('e%d',e),'FontSize',7,'Color',[0.25 0.45 0.75],...
            'HorizontalAlignment','center','HitTest','off');
    end
    
    hNodes = scatter(ax, app.CX, app.CY, 60, 'filled',...
        'MarkerFaceColor',[0.20 0.50 0.85],'MarkerEdgeColor','w','LineWidth',1);
    
    for n = 1:app.NN
        text(ax, app.CX(n)+0.02*(max(app.CX)-min(app.CX)+0.1),...
             app.CY(n)+0.02*(max(app.CY)-min(app.CY)+0.1),...
             sprintf('N%d',n),'FontSize',8,'Color',[0.12 0.25 0.45],'FontWeight','bold','HitTest','off');
    end
    
    for k = 1:size(app.constraints,1)
        drawConstraintSymbol(ax, app.CX(app.constraints(k,1)), app.CY(app.constraints(k,1)), app.constraints(k,2), app.constraints(k,3));
    end
    
    maxcoord = max([app.CX; app.CY]);
    arrowScale = 0.15 * max(maxcoord, 0.5);
    for k = 1:size(app.loads,1)
        nid = app.loads(k,1); dof = app.loads(k,2); val = app.loads(k,3);
        if abs(val) < 1e-15, continue; end
        nx = app.CX(nid); ny = app.CY(nid); sgn = sign(val);
        len = max(arrowScale * min(abs(val)/max(abs(app.loads(:,3))+1e-15), 1), arrowScale*0.3);
        if dof==1
            quiver(ax, nx - sgn*len, ny, sgn*len, 0, 'AutoScale','off','Color',[0.90 0.30 0.20],'LineWidth',2,'MaxHeadSize',0.8,'HitTest','off');
            text(ax, nx+sgn*0.05, ny+0.05, sprintf('Fx=%.3g',val),'FontSize',7,'Color',[0.90 0.30 0.20],'HitTest','off');
        else
            quiver(ax, nx, ny - sgn*len, 0, sgn*len, 'AutoScale','off','Color',[0.90 0.30 0.20],'LineWidth',2,'MaxHeadSize',0.8,'HitTest','off');
            text(ax, nx+0.05, ny+sgn*0.05, sprintf('Fy=%.3g',val),'FontSize',7,'Color',[0.90 0.30 0.20],'HitTest','off');
        end
    end
    
    hold(ax,'off');
    axis(ax,'equal'); grid(ax,'on');
    ax.XLabel.String = 'x'; ax.YLabel.String = 'y';
    title(ax,'网格模型 — 点击结点设置约束/载荷','FontSize',9);
    
    set(ax,'ButtonDownFcn',@(s,e)axisClickHandler(fig,s,e));
    hNodes.ButtonDownFcn = @(s,e)axisClickHandler(fig,ax,[]);
end

function drawConstraintSymbol(ax, x, y, dof, val)
    sz = 0.08 * max(ax.XLim(2)-ax.XLim(1), 0.5);
    if dof == 1
        for kk = -1:1
            patch(ax,[x-sz x-sz x-1.5*sz],[y+kk*sz y+(kk+1)*sz y+kk*0.5*sz+0.5*sz*(kk+1)],...
                [0.15 0.70 0.55],'EdgeColor',[0.05 0.50 0.35],'FaceAlpha',0.6,'LineWidth',1.5,'HitTest','off');
        end
        if abs(val)>1e-15
            text(ax,x-sz*2.5,y,sprintf('u=%.3g',val),'FontSize',6.5,'Color',[0.05 0.50 0.35],'HitTest','off');
        end
    else
        for kk = -1:1
            patch(ax,[x+kk*sz x+(kk+1)*sz x+kk*0.5*sz+0.5*sz*(kk+1)],[y-sz y-sz y-1.5*sz],...
                [0.15 0.70 0.55],'EdgeColor',[0.05 0.50 0.35],'FaceAlpha',0.6,'LineWidth',1.5,'HitTest','off');
        end
        if abs(val)>1e-15
            text(ax,x,y-sz*2.2,sprintf('v=%.3g',val),'FontSize',6.5,'Color',[0.05 0.50 0.35],'HitTest','off');
        end
    end
end

function setConstraintMode(fig)
    setappdata(fig,'interactMode','constraint');
    hLbl = findobj(fig,'Tag','modeLabel');
    hLbl.String = '当前模式：设置约束';
    hLbl.BackgroundColor = [0.80 0.95 0.85];
end

function setLoadMode(fig)
    setappdata(fig,'interactMode','load');
    hLbl = findobj(fig,'Tag','modeLabel');
    hLbl.String = '当前模式：施加载荷';
    hLbl.BackgroundColor = [0.98 0.90 0.75];
end

function clearConditions(fig)
    app = fig.UserData;
    app.constraints = zeros(0,3);
    app.loads       = zeros(0,3);
    fig.UserData = app;
    hList = findobj(fig,'Tag','condList');
    hList.String = {};
    drawMesh(fig);
end

function deleteSelectedCondition(fig)
    hList = findobj(fig,'Tag','condList');
    idx = hList.Value;
    strs = hList.String;
    if isempty(strs) || idx > length(strs), return; end
    
    app = fig.UserData;
    nC = size(app.constraints,1);
    nL = size(app.loads,1);
    if idx <= nC
        app.constraints(idx,:) = [];
    elseif idx <= nC+nL
        app.loads(idx-nC,:) = [];
    end
    fig.UserData = app;
    refreshCondList(fig);
    drawMesh(fig);
end

function axisClickHandler(fig, ax, ~)
    app = fig.UserData;
    if app.NN == 0, return; end
    mode = getappdata(fig,'interactMode');
    if strcmp(mode,'none'), return; end
    
    cp = ax.CurrentPoint;
    cx = cp(1,1); cy = cp(1,2);
    
    dist = sqrt((app.CX - cx).^2 + (app.CY - cy).^2);
    [dmin, nid] = min(dist);
    tol = 0.12 * max(max(app.CX)-min(app.CX), max(app.CY)-min(app.CY));
    if dmin > tol, return; end
    
    if strcmp(mode,'constraint')
        openConstraintDialog(fig, nid);
    elseif strcmp(mode,'load')
        openLoadDialog(fig, nid);
    end
end

function openConstraintDialog(fig, nid)
    app = fig.UserData;
    cx_exist = app.constraints(app.constraints(:,1)==nid & app.constraints(:,2)==1, 3);
    cy_exist = app.constraints(app.constraints(:,1)==nid & app.constraints(:,2)==2, 3);
    cx_str = ''; cy_str = ''; cx_chk = 0; cy_chk = 0;
    if ~isempty(cx_exist), cx_str = num2str(cx_exist(end)); cx_chk=1; end
    if ~isempty(cy_exist), cy_str = num2str(cy_exist(end)); cy_chk=1; end
    
    d = dialog('Name',sprintf('结点 N%d 位移约束',nid),'Position',[500 400 340 200],'WindowStyle','modal');
    
    uicontrol(d,'Style','text','String',sprintf('结点 N%d  (x=%.4g, y=%.4g)',nid,app.CX(nid),app.CY(nid)),...
        'Position',[10 165 320 20],'FontSize',9,'HorizontalAlignment','center');
    hCkX = uicontrol(d,'Style','checkbox','String','约束 x 方向位移 u = ','Position',[20 130 180 22],'Value',cx_chk,'FontSize',9);
    hEdX = uicontrol(d,'Style','edit','String',cx_str,'Position',[200 132 100 22],'FontSize',9);
    hCkY = uicontrol(d,'Style','checkbox','String','约束 y 方向位移 v = ','Position',[20 95 180 22],'Value',cy_chk,'FontSize',9);
    hEdY = uicontrol(d,'Style','edit','String',cy_str,'Position',[200 97 100 22],'FontSize',9);
    
    uicontrol(d,'Style','pushbutton','String','确定','Position',[60 20 100 35],'FontSize',10,'Callback',@doOK);
    uicontrol(d,'Style','pushbutton','String','取消','Position',[180 20 100 35],'FontSize',10,'Callback',@(s,e)delete(d));
    uiwait(d);
    
    function doOK(~,~)
        app2 = fig.UserData;
        app2.constraints(app2.constraints(:,1)==nid,:) = [];
        if hCkX.Value
            vx = str2double(hEdX.String); if isnan(vx), vx=0; end
            app2.constraints(end+1,:) = [nid, 1, vx];
        end
        if hCkY.Value
            vy = str2double(hEdY.String); if isnan(vy), vy=0; end
            app2.constraints(end+1,:) = [nid, 2, vy];
        end
        fig.UserData = app2;
        refreshCondList(fig); drawMesh(fig); delete(d);
    end
end

function openLoadDialog(fig, nid)
    app = fig.UserData;
    fx_exist = app.loads(app.loads(:,1)==nid & app.loads(:,2)==1, 3);
    fy_exist = app.loads(app.loads(:,1)==nid & app.loads(:,2)==2, 3);
    fx_str = '0'; fy_str = '0';
    if ~isempty(fx_exist), fx_str = num2str(fx_exist(end)); end
    if ~isempty(fy_exist), fy_str = num2str(fy_exist(end)); end
    
    d = dialog('Name',sprintf('结点 N%d 节点载荷',nid),'Position',[500 400 320 200],'WindowStyle','modal');
    
    uicontrol(d,'Style','text','String',sprintf('结点 N%d  (x=%.4g, y=%.4g)',nid,app.CX(nid),app.CY(nid)),...
        'Position',[10 165 300 20],'FontSize',9,'HorizontalAlignment','center');
    uicontrol(d,'Style','text','String','Fx (x方向力) = ','Position',[20 125 140 22],'FontSize',9,'HorizontalAlignment','left');
    hEdFx = uicontrol(d,'Style','edit','String',fx_str,'Position',[165 127 110 22],'FontSize',9);
    uicontrol(d,'Style','text','String','Fy (y方向力) = ','Position',[20 90 140 22],'FontSize',9,'HorizontalAlignment','left');
    hEdFy = uicontrol(d,'Style','edit','String',fy_str,'Position',[165 92 110 22],'FontSize',9);
    
    uicontrol(d,'Style','pushbutton','String','确定','Position',[55 20 100 35],'FontSize',10,'Callback',@doOK);
    uicontrol(d,'Style','pushbutton','String','取消','Position',[175 20 100 35],'FontSize',10,'Callback',@(s,e)delete(d));
    uiwait(d);
    
    function doOK(~,~)
        app2 = fig.UserData;
        app2.loads(app2.loads(:,1)==nid,:) = [];
        fx = str2double(hEdFx.String); fy = str2double(hEdFy.String);
        if isnan(fx), fx=0; end
        if isnan(fy), fy=0; end
        if fx~=0, app2.loads(end+1,:) = [nid,1,fx]; end
        if fy~=0, app2.loads(end+1,:) = [nid,2,fy]; end
        fig.UserData = app2;
        refreshCondList(fig); drawMesh(fig); delete(d);
    end
end

function refreshCondList(fig)
    app = fig.UserData;
    strs = {}; dofname = {'u','v'}; fdname = {'Fx','Fy'};
    for k = 1:size(app.constraints,1)
        strs{end+1} = sprintf('[约束] N%d: %s = %.4g', app.constraints(k,1), dofname{app.constraints(k,2)}, app.constraints(k,3));
    end
    for k = 1:size(app.loads,1)
        strs{end+1} = sprintf('[载荷] N%d: %s = %.4g', app.loads(k,1), fdname{app.loads(k,2)}, app.loads(k,3));
    end
    hList = findobj(fig,'Tag','condList');
    hList.String = strs;
    if ~isempty(strs), hList.Value = min(hList.Value, length(strs)); end
end

function runSolver(fig)
    app = fig.UserData;
    if app.NN == 0, errordlg('请先载入网格文件！','提示'); return; end
    if size(app.constraints,1) == 0, errordlg('请至少设置一个位移约束！','提示'); return; end
    
    E     = str2double(findobj(fig,'Tag','edE').String);
    ANU   = str2double(findobj(fig,'Tag','edANU').String);
    T_thk = str2double(findobj(fig,'Tag','edT').String);
    GM    = str2double(findobj(fig,'Tag','edGM').String);
    NTYPE = findobj(fig,'Tag','pmType').Value; 
    
    if any(isnan([E ANU T_thk GM])), errordlg('材料参数输入有误！','提示'); return; end
    
    app.E = E; app.ANU = ANU; app.T = T_thk; app.GM = GM; app.NTYPE = NTYPE;
    
    NN = app.NN; NE = app.NE; ND = 2*NN;
    CX = app.CX; CY = app.CY; LOC = app.LOC;
    
    if NTYPE == 1
        D = (E/(1-ANU^2)) * [1 ANU 0; ANU 1 0; 0 0 (1-ANU)/2];
    else
        E2 = E/(1-ANU^2); nu2 = ANU/(1-ANU);
        D = (E2/(1-nu2^2)) * [1 nu2 0; nu2 1 0; 0 0 (1-nu2)/2];
    end
    
    GK = zeros(ND, ND); F = zeros(ND, 1);
    
    for k = 1:size(app.loads,1)
        gidx = (app.loads(k,1)-1)*2 + app.loads(k,2);
        F(gidx) = F(gidx) + app.loads(k,3);
    end
    
    BAK = zeros(NE, 3, 6);  
    
    for ie = 1:NE
        I1 = LOC(ie,1); I2 = LOC(ie,2); I3 = LOC(ie,3);
        xi = CX(I1); yi = CY(I1); xj = CX(I2); yj = CY(I2); xm = CX(I3); ym = CY(I3);
        
        bi = yj-ym; bj = ym-yi; bm = yi-yj;
        ci = -(xj-xm); cj = -(xm-xi); cm = -(xi-xj);
        S2 = xi*bi + xj*bj + xm*bm;  
        
        if abs(S2) < 1e-14, continue; end
        
        BB = (1/S2) * [bi 0 bj 0 bm 0; 0 ci 0 cj 0 cm; ci bi cj bj cm bm];
        A = abs(S2/2);
        ke = BB' * D * BB * T_thk * A;
        BAK(ie,:,:) = D * BB;
        
        if GM ~= 0
            FY_grav = -T_thk * GM * A / 3;
            nodes_e = [I1, I2, I3];
            for kk = 1:3
                gidx_y = (nodes_e(kk)-1)*2 + 2; F(gidx_y) = F(gidx_y) + FY_grav;
            end
        end
        
        gdof = [(I1-1)*2+1, (I1-1)*2+2, (I2-1)*2+1, (I2-1)*2+2, (I3-1)*2+1, (I3-1)*2+2];
        GK(gdof, gdof) = GK(gdof, gdof) + ke;
    end
    
    GK_orig = GK; 
    BIGNUM = 1e15;
    for k = 1:size(app.constraints,1)
        gidx = (app.constraints(k,1)-1)*2 + app.constraints(k,2);
        val = app.constraints(k,3);
        GK(gidx, gidx) = GK(gidx, gidx) * BIGNUM;
        F(gidx) = GK(gidx, gidx) * val;
    end
    
    try
        U = GK \ F;
    catch ME
        errordlg('方程求解失败，模型可能存在刚体位移，请检查约束设置。','错误'); return;
    end
    
    STRES = zeros(NE, 3); STRAN = zeros(NE, 3);
    for ie = 1:NE
        I1=LOC(ie,1); I2=LOC(ie,2); I3=LOC(ie,3);
        gdof = [(I1-1)*2+1, (I1-1)*2+2, (I2-1)*2+1, (I2-1)*2+2, (I3-1)*2+1, (I3-1)*2+2];
        XX = U(gdof);
        STRES(ie,:) = (squeeze(BAK(ie,:,:)) * XX)';
        
        xi = CX(I1); yi = CY(I1); xj = CX(I2); yj = CY(I2); xm = CX(I3); ym = CY(I3);
        bi = yj-ym; bj = ym-yi; bm = yi-yj; ci = -(xj-xm); cj = -(xm-xi); cm = -(xi-xj);
        S2 = xi*bi + xj*bj + xm*bm;
        BB = (1/S2)*[bi 0 bj 0 bm 0; 0 ci 0 cj 0 cm; ci bi cj bj cm bm];
        STRAN(ie,:) = (BB * XX)';
    end
    
    F_react_all = GK_orig * U - F;
    for k = 1:size(app.loads,1)
        gidx = (app.loads(k,1)-1)*2 + app.loads(k,2);
        F_react_all(gidx) = F_react_all(gidx) + app.loads(k,3);
    end
    
    app.U = U; app.STRES = STRES; app.STRAN = STRAN; app.F_react = F_react_all; app.solved = true;
    fig.UserData = app;
    
    updateResultPlot(fig);
    showTable(fig,'tbNode');
    
    % ✅ 修复：正确的msgbox语法
    sx = STRES(:,1); sy = STRES(:,2); txy = STRES(:,3);
    mises = sqrt(sx.^2 - sx.*sy + sy.^2 + 3*txy.^2);
    msgbox(sprintf('求解完成！\n最大位移 = %.6g\n最大 Mises = %.6g', max(abs(U)), max(mises)),'计算成功');
end

function updateResultPlot(fig)
    app = fig.UserData;
    if ~app.solved, return; end
    
    ax = findobj(fig,'Tag','axResult');
    cla(ax);
    
    pmRes   = findobj(fig,'Tag','pmResult');
    chkDef  = findobj(fig,'Tag','chkDeform');
    resIdx  = pmRes.Value;
    showDef = chkDef.Value;
    
    U = app.U;
    
    maxDisp = max(abs(U));
    if maxDisp < 1e-15, scale = 0; else
        refLen = max(max(app.CX)-min(app.CX), max(app.CY)-min(app.CY));
        scale = 0.15 * refLen / maxDisp;
    end
    
    if showDef && scale > 0
        CXd = app.CX + U(1:2:end) * scale;
        CYd = app.CY + U(2:2:end) * scale;
    else
        CXd = app.CX; CYd = app.CY;
    end
    
    resultNames = {'X位移 Ux','Y位移 Uy','合位移 |U|',...
                   'X正应力 σx','Y正应力 σy','剪应力 τxy',...
                   'X正应变 εx','Y正应变 εy','剪应变 γxy',...
                   'Mises等效应力'};
    
    if resIdx == 1
        val_node = U(1:2:end);
    elseif resIdx == 2
        val_node = U(2:2:end);
    elseif resIdx == 3
        val_node = sqrt(U(1:2:end).^2 + U(2:2:end).^2);
    elseif resIdx <= 6
        comp = resIdx - 3;  
        val_node = elemToNode(app, app.STRES(:,comp));
    elseif resIdx <= 9
        comp = resIdx - 6;
        val_node = elemToNode(app, app.STRAN(:,comp));
    else
        sx = app.STRES(:,1); sy = app.STRES(:,2); txy = app.STRES(:,3);
        mises_elem = sqrt(sx.^2 - sx.*sy + sy.^2 + 3*txy.^2);
        val_node = elemToNode(app, mises_elem);
    end
    
    val_node = val_node(:);
    
    hold(ax,'on');
    vmin = min(val_node); vmax = max(val_node);
    if abs(vmax-vmin)<1e-15, vmax = vmin + 1e-10; end
    colormap(ax, parula(256));
    
    patch(ax, 'Vertices', [CXd, CYd], 'Faces', app.LOC, ...
          'FaceVertexCData', val_node, ...
          'FaceColor', 'interp', 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 0.8);
    
    if showDef
        patch(ax, 'Vertices', [app.CX, app.CY], 'Faces', app.LOC, ...
              'FaceColor', 'none', 'EdgeColor', [0.6 0.6 0.6], ...
              'LineStyle', '--', 'LineWidth', 0.7);
    end
    
    hold(ax,'off');
    caxis(ax,[vmin vmax]);
    cb = colorbar(ax);
    cb.Label.String = resultNames{resIdx};
    cb.FontSize = 8;
    axis(ax,'equal'); grid(ax,'on');
    ax.XLabel.String='x'; ax.YLabel.String='y';
    if showDef
        title(ax,sprintf('%s (变形×%.1f)',resultNames{resIdx},scale),'FontSize',9);
    else
        title(ax, resultNames{resIdx},'FontSize',9);
    end
end

function val_node = elemToNode(app, val_elem)
    NN = app.NN; NE = app.NE;
    val_node = zeros(NN,1);
    cnt = zeros(NN,1);
    for ie = 1:NE
        for lk = 1:3
            nid = app.LOC(ie,lk);
            val_node(nid) = val_node(nid) + val_elem(ie);
            cnt(nid) = cnt(nid) + 1;
        end
    end
    val_node = val_node ./ max(cnt, 1);
end

function showTable(fig, tableTag)
    app = fig.UserData;
    if ~app.solved && ~strcmp(tableTag,'tbNode'), return; end
    ht = findobj(fig,'Tag','mainTable');
    NN = app.NN; NE = app.NE;
    
    switch tableTag
        case 'tbNode'
            if ~app.solved
                ht.ColumnName = {'结点','x 坐标','y 坐标'}; data = cell(NN,3);
                for n=1:NN, data{n,1}=n; data{n,2}=app.CX(n); data{n,3}=app.CY(n); end
            else
                ht.ColumnName = {'结点','x 坐标','y 坐标','Ux (x位移)','Uy (y位移)','|U| (合位移)'}; data = cell(NN,6);
                for n=1:NN
                    ux = app.U((n-1)*2+1); uy = app.U((n-1)*2+2);
                    data{n,1}=n; data{n,2}=app.CX(n); data{n,3}=app.CY(n);
                    data{n,4}=ux; data{n,5}=uy; data{n,6}=sqrt(ux^2+uy^2);
                end
            end
            ht.Data = data;
            
        case 'tbReact'
            ht.ColumnName = {'结点','方向','反力值'}; data = {};
            for k=1:size(app.constraints,1)
                nid=app.constraints(k,1); dof=app.constraints(k,2);
                gidx=(nid-1)*2+dof; dname = {'x','y'}; 
                data(end+1,:) = {nid, dname{dof}, app.F_react(gidx)};
            end
            ht.Data = data;
            
        case 'tbStress'
            ht.ColumnName = {'单元','σx','σy','τxy','Mises等效应力'}; data = cell(NE,5);
            for ie=1:NE
                sx=app.STRES(ie,1); sy=app.STRES(ie,2); txy=app.STRES(ie,3);
                data{ie,1}=ie; data{ie,2}=sx; data{ie,3}=sy; data{ie,4}=txy; data{ie,5}=sqrt(sx^2-sx*sy+sy^2+3*txy^2);
            end
            ht.Data = data;
            
        case 'tbStrain'
            ht.ColumnName = {'单元','εx','εy','γxy'}; data = cell(NE,4);
            for ie=1:NE
                data{ie,1}=ie; data{ie,2}=app.STRAN(ie,1); data{ie,3}=app.STRAN(ie,2); data{ie,4}=app.STRAN(ie,3);
            end
            ht.Data = data;
    end
end

function onClose(fig,~)
    delete(fig);
end