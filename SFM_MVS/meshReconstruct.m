
function outputFilePath = meshReconstruct(plyFilePath, method)
    % 读取 .ply 文件
    ptCloud = pcread(plyFilePath);

    % 获取点云数据
    points = double(ptCloud.Location);  % 转换为 double 类型

    switch method
        case 'Alpha Shapes'
            colors = double(ptCloud.Color) / 255;  % 转换为 double 类型
            % 估计最优alpha参数
            optimalAlpha = estimateOptimalAlpha(points, 'randomPicking');

            % 使用alphaShape来构建三角面片
            shp = alphaShape(points, optimalAlpha);
            [faces, vertices] = boundaryFacets(shp);
            % 保存结果为 .obj 文件
            outputFilePath = fullfile(fileparts(plyFilePath), 'alphaShapes.obj');

        case 'Poisson Surface Reconstruction'
            colors = single(ptCloud.Color) / 255;  % 转换为 double 类型
            % 使用泊松表面重建
            [mesh, depth, perVertexDensity] = pc2surfacemesh(ptCloud, 'poisson', 8);  % 这里指定octree depth为8

            % 从surfaceMesh对象提取顶点和面
            vertices = mesh.Vertices;
            faces = mesh.Faces;

            % 保存结果为 .obj 文件
            outputFilePath = fullfile(fileparts(plyFilePath), 'Poisson.obj');

        case 'Ball Pivoting'
            % 使用球形旋转法进行表面重建，这种方法似乎不太适合
            [mesh, radius] = pc2surfacemesh(ptCloud, 'ball-pivot');

            % 从surfaceMesh对象提取顶点和面
            vertices = mesh.Vertices;
            faces = mesh.Faces;
            % vertexNormals = mesh.VertexNormals;
            outputFilePath = fullfile(fileparts(plyFilePath), 'ballPivoting.obj');
        otherwise
            error('未知的重建方法');
    end

    if isempty(colors)
        writeOBJ(outputFilePath, vertices, faces);
    else
        num=0;
        verticesInfo=zeros(size(vertices,1),6);
        parfor i=1:size(vertices,1)
            nowVertex=vertices(i,:);
            for j=1:size(points,1)
                if norm(points(j,:)-nowVertex)<1e-6
                    verticesInfo(i,:)=[nowVertex,colors(j,:)];
                    num=num+1;
                    break;
                end
            end
        end
        if num==size(vertices,1)
            writeOBJ(outputFilePath, verticesInfo, faces);
        else
            writeOBJ(outputFilePath, vertices, faces);
        end
    end
end

function writeOBJ(filename, vertices, faces, varargin)
    % 打开文件，若不存在则创建，若存在则清空内容
    fid = fopen(filename, 'w');
    if fid == -1
        error('无法创建文件: %s', filename);
    end

    % 解析可选参数
    vertexNormals = [];
    vertexTextures = [];

    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'vertexnormals'
                vertexNormals = varargin{i+1};
            case 'vertextexture'
                vertexTextures = varargin{i+1};
            otherwise
                error('未知的参数: %s', varargin{i});
        end
    end

    if size(vertices(1,:),2)==3
        % 写入顶点数据
        for i = 1:size(vertices, 1)
            fprintf(fid, 'v %f %f %f\n', vertices(i, :));
        end
        % 包含颜色信息的顶点数据
    elseif size(vertices(1,:),2)==6
        for i = 1:size(vertices, 1)
            fprintf(fid, 'v %f %f %f %f %f %f\n', vertices(i, :));
        end
    end

    % 写入顶点法向量数据
    if ~isempty(vertexTextures)
        for i = 1:size(vertexTextures, 1)
            fprintf(fid, 'vt %f %f %f\n', vertexTextures(i, :));
        end
    end

   % 写入顶点纹理坐标数据
    if ~isempty(vertexNormals)
        for i = 1:size(vertexNormals, 1)
            fprintf(fid, 'vn %f %f %f\n', vertexNormals(i, :));
        end
    end
    % 写入面数据，确保面数据索引从 1 开始
    for i = 1:size(faces, 1)
        fprintf(fid, 'f %d %d %d\n', faces(i, :));
    end

    % 关闭文件
    fclose(fid);
end

function optimalAlpha = estimateOptimalAlpha(points,model)
    % 点的总数
    numPoints = size(points, 1);

    k = 6; % 最近邻个数，可以调整
    switch model
        case 'randomPicking'
            % 选择子集的大小
            testSize=4;
            subsetSize = min(2500, numPoints); % 如果点的总数少于5000，选择所有点
            temp=zeros(1,testSize);
            % 随机选择子集
            for i=1:testSize
            subsetIndices = randperm(numPoints, subsetSize);
            subsetPoints = points(subsetIndices, :);
            % 计算子集中每个点到其最近邻点的距离
            [~, D] = knnsearch(subsetPoints, subsetPoints, 'K', k);
            distances = D(:, 2:end); % 忽略自身距离,它总是0
            temp(i) = median(distances(:));
            end
            distance=median(temp);
            % 设定一个比例因子，可以根据需要进行调整
            alphaFactor = 1.0;
        case 'allPicking'
            [~, D] = knnsearch(points, points, 'K', k);
            % 使用距离的中位数作为alpha参数
            distances = D(:, 2:end); % 忽略自身距离
            distance = median(distances(:));
            % 设定一个比例因子，可以根据需要进行调整
            alphaFactor = 2.3;
    end

    optimalAlpha = alphaFactor*distance;
end
