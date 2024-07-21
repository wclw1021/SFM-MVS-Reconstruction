createSFMeduGUI;

function createSFMeduGUI()
    % 获取屏幕尺寸
    screenSize = get(0, 'ScreenSize');
    width = 800;
    height = 500;
    xPos = (screenSize(3) - width) / 2;
    yPos = (screenSize(4) - height) / 2;

    % 创建GUI
    app = uifigure('Name', 'SFM几何重建', 'Position', [xPos yPos width height]);

    % 获取当前脚本所在文件夹并设置默认图片文件夹路径
    currentFolder = fileparts(mfilename('fullpath'));
    imagesFolder = fullfile(currentFolder, 'images');

    % 创建点云生成方法选择下拉菜单及其标签
    pointCloudMethodLabel = uilabel(app, 'Text', '点云配对方法:', 'Position', [20 400 100 22]);
    pointCloudMethodDropdown = uidropdown(app, 'Items', {'SIFT','SURF'}, 'Position', [130 400 200 22]);

    % 创建曲面重建方法选择下拉菜单及其标签
    surfaceReconstructionMethodLabel = uilabel(app, 'Text', '曲面重建方法:', 'Position', [20 360 100 22]);
    surfaceReconstructionMethodDropdown = uidropdown(app, 'Items', {'Alpha Shapes','Poisson Surface Reconstruction'}, 'Position', [130 360 200 22]);

    % 创建可视化选择复选框和二叉树加速选择复选框（同一行）
    visualizeCheckbox = uicheckbox(app, 'Text', '可视化', 'Position', [20 320 100 22]);
    useBinaryTreeCheckbox = uicheckbox(app, 'Text', '使用二叉树加速', 'Position', [130 320 150 22]);

    % 创建选择图片文件夹的按钮及其标签
    folderPathLabel = uilabel(app, 'Text', '图片文件夹:', 'Position', [20 280 100 22]);
    folderPathEdit = uieditfield(app, 'text', 'Position', [130 280 200 22], 'Value', imagesFolder);
    folderBrowseButton = uibutton(app, 'Text', '浏览', ...
        'Position', [340 280 80 22], 'ButtonPushedFcn', @(btn, event) browseFolderPath(folderPathEdit));

    % 创建选择Meshlab路径的按钮及其标签
    meshlabPathLabel = uilabel(app, 'Text', 'Meshlab路径:', 'Position', [20 240 100 22]);
    meshlabPathEdit = uieditfield(app, 'text', 'Position', [130 240 200 22]);
    meshlabBrowseButton = uibutton(app, 'Text', '浏览', ...
        'Position', [340 240 80 22], 'ButtonPushedFcn', @(btn, event) browseMeshlabPath(meshlabPathEdit));

    % 创建选择.ply文件的按钮及其标签
    plyFileLabel = uilabel(app, 'Text', '.ply 文件:', 'Position', [20 200 100 22]);
    plyFileEdit = uieditfield(app, 'text', 'Position', [130 200 200 22], 'Value', fullfile(currentFolder, 'dense.ply'));
    plyBrowseButton = uibutton(app, 'Text', '浏览', ...
        'Position', [340 200 80 22], 'ButtonPushedFcn', @(btn, event) browsePlyFile(plyFileEdit));

    % 创建点云生成的运行按钮
    runButton = uibutton(app, 'Text', '点云配对', 'Position', [20 160 100 22], ...
        'ButtonPushedFcn', @(runButton, event) runSFMedu(app, pointCloudMethodDropdown, visualizeCheckbox, useBinaryTreeCheckbox, folderPathEdit, meshlabPathEdit));

    % 创建曲面重建的运行按钮
    reconstructButton = uibutton(app, 'Text', '曲面重建', 'Position', [130 160 100 22], ...
        'ButtonPushedFcn', @(reconstructButton, event) runSurfaceReconstruction(app, surfaceReconstructionMethodDropdown, plyFileEdit, meshlabPathEdit));

    % 创建消息区域
    messageArea = uitextarea(app, 'Editable', 'off', 'HorizontalAlignment', 'center', 'Position', [20 20 700 120]);
    app.UserData.messageArea = messageArea;

    % 设置窗口大小变化时的回调函数
    app.SizeChangedFcn = @(src, event) resizeComponents(app);
end

function resizeComponents(app)
    % 获取窗口尺寸
    figPos = app.Position;

    % 按比例调整控件位置和大小
    margin = 0.05;
    app.Children(1).Position = [figPos(3) * margin, figPos(4) * margin, figPos(3) * (1 - 5 * margin), figPos(4) * 0.2]; % messageArea
    app.Children(2).Position = [figPos(3) * margin, figPos(4) * 0.35, figPos(3) * 0.15, figPos(4) * 0.05]; % runButton
    app.Children(3).Position = [figPos(3) * 0.25, figPos(4) * 0.35, figPos(3) * 0.15, figPos(4) * 0.05]; % reconstructButton
    app.Children(4).Position = [figPos(3) * margin, figPos(4) * 0.45, figPos(3) * 0.15, figPos(4) * 0.05]; % plyFileLabel
    app.Children(5).Position = [figPos(3) * 0.25, figPos(4) * 0.45, figPos(3) * 0.25, figPos(4) * 0.05]; % plyFileEdit
    app.Children(6).Position = [figPos(3) * 0.55, figPos(4) * 0.45, figPos(3) * 0.15, figPos(4) * 0.05]; % plyBrowseButton
    app.Children(7).Position = [figPos(3) * margin, figPos(4) * 0.55, figPos(3) * 0.15, figPos(4) * 0.05]; % meshlabPathLabel
    app.Children(8).Position = [figPos(3) * 0.25, figPos(4) * 0.55, figPos(3) * 0.25, figPos(4) * 0.05]; % meshlabPathEdit
    app.Children(9).Position = [figPos(3) * 0.55, figPos(4) * 0.55, figPos(3) * 0.15, figPos(4) * 0.05]; % meshlabBrowseButton
    app.Children(10).Position = [figPos(3) * margin, figPos(4) * 0.65, figPos(3) * 0.15, figPos(4) * 0.05]; % surfaceReconstructionMethodLabel
    app.Children(11).Position = [figPos(3) * 0.25, figPos(4) * 0.65, figPos(3) * 0.25, figPos(4) * 0.05]; % surfaceReconstructionMethodDropdown
    app.Children(12).Position = [figPos(3) * margin, figPos(4) * 0.75, figPos(3) * 0.15, figPos(4) * 0.05]; % pointCloudMethodLabel
    app.Children(13).Position = [figPos(3) * 0.25, figPos(4) * 0.75, figPos(3) * 0.25, figPos(4) * 0.05]; % pointCloudMethodDropdown
    app.Children(14).Position = [figPos(3) * margin, figPos(4) * 0.85, figPos(3) * 0.15, figPos(4) * 0.05]; % visualizeCheckbox
    app.Children(15).Position = [figPos(3) * margin, figPos(4) * 0.95, figPos(3) * 0.15, figPos(4) * 0.05]; % folderPathLabel
    app.Children(16).Position = [figPos(3) * 0.25, figPos(4) * 0.95, figPos(3) * 0.25, figPos(4) * 0.05]; % folderPathEdit
    app.Children(17).Position = [figPos(3) * 0.55, figPos(4) * 0.95, figPos(3) * 0.15, figPos(4) * 0.05]; % folderBrowseButton
end

%% Open files
function browseMeshlabPath(meshlabPathEdit)
    % 获取桌面路径
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    if ~isfolder(desktopPath)
        desktopPath = fullfile(getenv('HOME'), 'Desktop');
    end

    % 选择Meshlab路径
    [file, path] = uigetfile('*.exe', '选择Meshlab可执行文件', desktopPath);
    if isequal(file, 0)
        return;
    else
        meshlabPathEdit.Value = fullfile(path, file);
    end
end

function browseFolderPath(folderPathEdit)
    % 选择图片文件夹
    folder = uigetdir();
    if isequal(folder, 0)
        return;
    else
        folderPathEdit.Value = folder;
    end
end

function browsePlyFile(plyFileEdit)
    % 选择.ply文件
    [file, path] = uigetfile('*.ply', '选择 .ply 文件');
    if isequal(file, 0)
        return;
    else
        plyFileEdit.Value = fullfile(path, file);
    end
end

%% Process data
function runSFMedu(app, methodDropdown, visualizeCheckbox, useBinaryTreeCheckbox, folderPathEdit, meshlabPathEdit)
    % 获取用户选择的参数
    method_pair = methodDropdown.Value;
    visualize = visualizeCheckbox.Value;
    use_binary_tree = useBinaryTreeCheckbox.Value;
    folderPath = folderPathEdit.Value;
    meshlabPath = meshlabPathEdit.Value;

    % 检查图片文件夹路径是否有效
    if isempty(folderPath) || ~isfolder(folderPath)
        updateMessageArea(app, '图片文件夹路径无效，请选择有效的文件夹。');
        return;
    end

    % 获取文件夹中的所有图片文件
    imageFiles = [dir(fullfile(folderPath, '*.jpg'));...
        dir(fullfile(folderPath, '*.png'));...
        dir(fullfile(folderPath, '*.bmp'))];
    if isempty(imageFiles)
        updateMessageArea(app, '选择的文件夹中没有找到任何图片文件。');
        return;
    end

    % 更新消息区域
    currentText = app.UserData.messageArea.Value;
    currentText{end+1} = '正在运行...';
    app.UserData.messageArea.Value = currentText;
    drawnow;

    % 调用SFMedu函数
    try
        SFMedu2(visualize, use_binary_tree, app, imageFiles, method_pair);
        updateMessageArea(app, '运行完成！');
        drawnow;

        % 自动用Meshlab打开PLY文件
        if isfile(meshlabPath)
            system([meshlabPath ' dense.ply &']);
            system([meshlabPath ' sparse.ply &']);
        else
            updateMessageArea(app, 'Meshlab路径无效，请重新选择。');
        end
    catch ME
        updateMessageArea(app, ['运行失败：' ME.message]);
    end

end


function runSurfaceReconstruction(app, methodDropdown, plyFileEdit, meshlabPathEdit)
    % 获取用户选择的参数
    method = methodDropdown.Value;
    meshlabPath = meshlabPathEdit.Value;
    plyFilePath = plyFileEdit.Value;

    % 检查 .ply 文件路径是否有效
    if isempty(plyFilePath) || ~isfile(plyFilePath)
        updateMessageArea(app, '.ply 文件路径无效，请选择有效的文件。');
        return;
    end

    % 更新消息区域
    currentText = app.UserData.messageArea.Value;
    currentText{end+1} = '正在进行曲面重建...';
    app.UserData.messageArea.Value = currentText;
    drawnow;

    % 处理 .ply 文件
    try

        % 根据选择的方法进行重建
        outputFilePath=meshReconstruct(plyFilePath,method);

        % 自动用Meshlab打开结果
        if isfile(meshlabPath)
            system([meshlabPath ' ' outputFilePath ' &']);
        else
            updateMessageArea(app, 'Meshlab路径无效，请重新选择。');
        end

        updateMessageArea(app, '曲面重建完成！');
    catch ME
        updateMessageArea(app, ['曲面重建失败：' ME.message]);
    end
end