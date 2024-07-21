function SFMedu2(visualize,use_binary_tree,app, imageFiles, method_pair)
    %% We do some changes on this framework
    updateMessageArea(app, 'SFMedu: Structrue From Motion for Education Purpose');
    updateMessageArea(app, 'Version 2 @ 2014');
    updateMessageArea(app, 'Written by Jianxiong Xiao (MIT License)');

    %% set up things
    %clear;
    close all;
    % add path
    addpath(genpath('matchSIFT'));
    addpath(genpath('denseMatch'));
    addpath(genpath('RtToolbox'));

    %% data
    frames.images = {imageFiles.name};
    for i = 1:length(frames.images)
        frames.images{i} = fullfile(imageFiles(i).folder, frames.images{i});
    end

    %% data pre-processing
    frames.length = length(frames.images);
    fprintf('length=%d\n', frames.length);

    try
        frames.focal_length = extractFocalFromEXIF(frames.images{1});
    catch
    end
    if ~isfield(frames, 'focal_length') || isempty(frames.focal_length)
        updateMessageArea(app, 'Warning: cannot find the focal length from the EXIF');
        frames.focal_length = 719.5459; % for testing with the B??.jpg sequences
    end

    maxSize = 1024;
    frames.imsize = size(imread(frames.images{1}));
    if max(frames.imsize) > maxSize
        scale = maxSize / max(frames.imsize);
        frames.focal_length = frames.focal_length * scale;
        frames.imsize = size(imresize(imread(frames.images{1}), scale));
    end

    frames.K = f2K(frames.focal_length);
    updateMessageArea(app, 'intrinsics:');
    updateMessageArea(app, mat2str(frames.K));

    %% SIFT matching and Fundamental Matrix Estimation
    frame = 1;
    while frame < frames.length
        tic;
        s = RandStream('mcg16807', 'Seed', 10);
        RandStream.setGlobalStream(s);
        switch method_pair
            case 'SIFT'
                pair = match2viewSIFT(frames, frame, frame + 1);
            case 'SURF'
                pair = match2viewSURF(frames, frame, frame + 1);
            otherwise
                error('未知的配对方法');
        end
        if visualize, showMatches(pair, frames); title('raw feature matching'); end

        pair = estimateF(pair);

        if isempty(pair)
            % 如果 pair 为空，删除相应的 frame 并修改其他相关变量
            frames.images(frame + 1) = [];
            frames.length = length(frames.images);
            updateMessageArea(app, sprintf('Frame %d removed due to none solution.', frame + 1));
            continue; % 重新开始 while 循环
        end

        pair.E = frames.K' * pair.F * frames.K;

        if visualize, showMatches(pair, frames); title('inliers'); end

        pair.Rt = RtFromE(pair, frames);
        Graph{frame} = pair2graph(pair, frames);
        Graph{frame} = triangulate(Graph{frame}, frames);
        if visualize, visualizeGraph(Graph{frame}, frames); title('triangulation'); end

        Graph{frame} = bundleAdjustment(Graph{frame});
        if visualize, visualizeGraph(Graph{frame}, frames); title('after two-view bundle adjustment'); end

        elapsedTime = toc;
        updateMessageArea(app, sprintf('Frame %d processing time: %.2f seconds', frame, elapsedTime));

        frame = frame + 1; % 处理下一个 frame
    end

    %% merge the graphs
    updateMessageArea(app, 'merging graphs....');
    tic;
    if(use_binary_tree)
        tree = buildTree(1, frames.length-1, Graph);
        mergedGraph = mergeTree(tree, frames, visualize);
    else
        mergedGraph = Graph{1};
        for frame = 2:frames.length-1
            fprintf('frame = %d\n', frame);
            mergedGraph = merge2graphs(mergedGraph, Graph{frame});
            mergedGraph = triangulate(mergedGraph, frames);
            if visualize, visualizeGraph(mergedGraph, frames); title('triangulation'); end

            mergedGraph = bundleAdjustment(mergedGraph);
            mergedGraph = removeOutlierPts(mergedGraph, 10);
            mergedGraph = bundleAdjustment(mergedGraph);
            if visualize, visualizeGraph(mergedGraph, frames); title('after bundle adjustment'); end
        end
    end

    points2ply('sparse.ply', mergedGraph.Str);

    if frames.focal_length ~= mergedGraph.f
        updateMessageArea(app, 'Focal length is adjusted by bundle adjustment');
        frames.focal_length = mergedGraph.f;
        frames.K = f2K(frames.focal_length);
        updateMessageArea(app, mat2str(frames.K));
    end

    elapsedTime = toc;
    updateMessageArea(app, sprintf('Merging graphs time: %.2f seconds', elapsedTime));

    %% dense matching
    updateMessageArea(app, 'dense matching ...');
    tic;

    parfor frame = 1:frames.length-1
        fprintf('frame = %d\n', frame);
        Graph{frame} = denseMatch(Graph{frame}, frames, frame, frame + 1);
    end

    elapsedTime = toc;
    updateMessageArea(app, sprintf('Dense matching time: %.2f seconds', elapsedTime));

    %% dense reconstruction
    updateMessageArea(app, 'triangulating dense points ...');
    tic;

    for frame = 1:frames.length-1
        fprintf('frame = %d\n', frame);
        clear X;
        P{1} = frames.K * mergedGraph.Mot(:, :, frame);
        P{2} = frames.K * mergedGraph.Mot(:, :, frame + 1);
        for j = 1:size(Graph{frame}.denseMatch, 2)
            X(:, j) = vgg_X_from_xP_nonlin(reshape(Graph{frame}.denseMatch(1:4, j), 2, 2), P, repmat([frames.imsize(2); frames.imsize(1)], 1, 2));
        end
        X = X(1:3, :) ./ X([4 4 4], :);
        x1 = P{1} * [X; ones(1, size(X, 2))];
        x2 = P{2} * [X; ones(1, size(X, 2))];
        x1 = x1(1:2, :) ./ x1([3 3], :);
        x2 = x2(1:2, :) ./ x2([3 3], :);
        Graph{frame}.denseX = X;
        Graph{frame}.denseRepError = sum(([x1; x2] - Graph{frame}.denseMatch(1:4, :)).^2, 1);

        Rt1 = mergedGraph.Mot(:, :, frame);
        Rt2 = mergedGraph.Mot(:, :, frame + 1);
        C1 = - Rt1(1:3, 1:3)' * Rt1(:, 4);
        C2 = - Rt2(1:3, 1:3)' * Rt2(:, 4);
        view_dirs_1 = bsxfun(@minus, X, C1);
        view_dirs_2 = bsxfun(@minus, X, C2);
        view_dirs_1 = bsxfun(@times, view_dirs_1, 1 ./ sqrt(sum(view_dirs_1 .* view_dirs_1)));
        view_dirs_2 = bsxfun(@times, view_dirs_2, 1 ./ sqrt(sum(view_dirs_2 .* view_dirs_2)));
        Graph{frame}.cos_angles = sum(view_dirs_1 .* view_dirs_2);

        c_dir1 = Rt1(3, 1:3)';
        c_dir2 = Rt2(3, 1:3)';
        Graph{frame}.visible = (sum(bsxfun(@times, view_dirs_1, c_dir1)) > 0) & (sum(bsxfun(@times, view_dirs_2, c_dir2)) > 0);
    end

    elapsedTime = toc;
    updateMessageArea(app, sprintf('Dense reconstruction time: %.2f seconds', elapsedTime));

    if visualize
        figure
        for frame = 1:frames.length-1
            hold on
            goodPoint = Graph{frame}.denseRepError < 0.05;
            plot3(Graph{frame}.denseX(1, goodPoint), Graph{frame}.denseX(2, goodPoint), Graph{frame}.denseX(3, goodPoint), '.b', 'Markersize', 1);
        end
        hold on
        plot3(mergedGraph.Str(1, :), mergedGraph.Str(2, :), mergedGraph.Str(3, :), '.r')
        axis equal
        title('dense cloud')
        for i = 1:frames.length
            drawCamera(mergedGraph.Mot(:, :, i), frames.imsize(2), frames.imsize(1), frames.K(1, 1), 0.001, i * 2 - 1);
        end
        axis tight
    end

    plyPoint = [];
    plyColor = [];
    for frame = 1:frames.length-1
        fprintf('frame = %d\n', frame);
        goodPoint = (Graph{frame}.denseRepError < 0.05) & (Graph{frame}.cos_angles < cos(5 / 180 * pi)) & Graph{frame}.visible;
        X = Graph{frame}.denseX(:, goodPoint);
        P{1} = frames.K * mergedGraph.Mot(:, :, frame);
        x1 = P{1} * [X; ones(1, size(X, 2))];
        x1 = round(x1(1:2, :) ./ x1([3 3], :));
        x1(1, :) = frames.imsize(2) / 2 - x1(1, :);
        x1(2, :) = frames.imsize(1) / 2 - x1(2, :);
        indlin = sub2ind(frames.imsize(1:2), x1(2, :), x1(1, :));
        im = imresize(imread(frames.images{frame}), frames.imsize(1:2));
        imR = im(:, :, 1);
        imG = im(:, :, 2);
        imB = im(:, :, 3);
        colorR = imR(indlin);
        colorG = imG(indlin);
        colorB = imB(indlin);
        plyPoint = [plyPoint X];
        plyColor = [plyColor [colorR; colorG; colorB]];
    end

    points2ply('dense.ply', plyPoint, plyColor);

    updateMessageArea(app, 'SFMedu is finished. The results have been opened in meshlab. Enjoy!');
end

% 创建一个二叉树节点的结构体
function node = createNode(graph)
    node.graph = graph;
    node.left = [];
    node.right = [];
end

% 构建二叉树的递归函数
function node = buildTree(startIdx, endIdx, Graph)
    if startIdx == endIdx
        node = createNode(Graph{startIdx});
    else
        mid = floor((startIdx + endIdx) / 2);
        node = createNode([]);
        node.left = buildTree(startIdx, mid, Graph);
        node.right = buildTree(mid + 1, endIdx, Graph);
    end
end

% 递归合并二叉树的函数
function mergedGraph = mergeTree(node, frames, visualize)
    if isempty(node.left) && isempty(node.right)
        mergedGraph = node.graph;
    else
        leftGraph = mergeTree(node.left, frames, visualize);
        rightGraph = mergeTree(node.right, frames, visualize);

        if isempty(leftGraph)
            mergedGraph = rightGraph;
        elseif isempty(rightGraph)
            mergedGraph = leftGraph;
        else
            mergedGraph = merge2graphs(leftGraph, rightGraph);
            mergedGraph = triangulate(mergedGraph, frames);
            if visualize
                visualizeGraph(mergedGraph, frames);
                title('triangulation');
            end

            mergedGraph = bundleAdjustment(mergedGraph);
            mergedGraph = removeOutlierPts(mergedGraph, 10);
            mergedGraph = bundleAdjustment(mergedGraph);
            if visualize
                visualizeGraph(mergedGraph, frames);
                title('after bundle adjustment');
            end
        end
    end
end