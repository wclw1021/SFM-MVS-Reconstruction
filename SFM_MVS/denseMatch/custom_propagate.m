function [match_pair, match_im_i, match_im_j] = custom_propagate(initial_match, im_i, im_j, matchable_im_i, matchable_im_j, zncc_i, zncc_j, WinHalfSize)

CostMax = 0.5;
visualization = false;

if visualization
    figure
    h0 = subplot(2,1,1); imshow(im_i); hold(h0, 'on');
    h1 = subplot(2,1,2); imshow(im_j); hold(h1, 'on');
end

match_im_i(:,:,1) = matchable_im_i - 2;
match_im_i(:,:,2) = match_im_i(:,:,1);
match_im_j(:,:,1) = matchable_im_j - 2;
match_im_j(:,:,2) = match_im_j(:,:,1);

maxMatchingNumber = min(numel(matchable_im_i), numel(matchable_im_j));
MaxIndexValidMatch = max(numel(matchable_im_i), numel(matchable_im_j));
NbMaxStartMatch = MaxIndexValidMatch + 5 * 5 * 9;

match_heap = PriorityQueue(NbMaxStartMatch * 25 + MaxIndexValidMatch);

match_pair = initial_match;
for match_pair_size = 1:size(match_pair, 1)
    match_pair(match_pair_size, 5) = sum(zncc_i(match_pair(match_pair_size, 1), match_pair(match_pair_size, 2), :) .* zncc_j(match_pair(match_pair_size, 3), match_pair(match_pair_size, 4), :));
    match_heap.push(match_pair_size, match_pair(match_pair_size, 5));
end

while maxMatchingNumber >= 0 && match_heap.size() > 0
    [bestIndex, ~] = match_heap.pop();
        
    x0 = match_pair(bestIndex, 1);
    y0 = match_pair(bestIndex, 2);
    x1 = match_pair(bestIndex, 3);
    y1 = match_pair(bestIndex, 4);
   
    if visualization
        plot(h0, y0, x0, 'y+');
        plot(h1, y1, x1, 'y+');
    end

    xMin0 = max(WinHalfSize + 1, x0 - WinHalfSize);
    xMax0 = min(size(matchable_im_i, 1) - WinHalfSize, x0 + WinHalfSize + 1);
    yMin0 = max(WinHalfSize + 1, y0 - WinHalfSize);
    yMax0 = min(size(matchable_im_i, 2) - WinHalfSize, y0 + WinHalfSize + 1);
    
    xMin1 = max(WinHalfSize + 1, x1 - WinHalfSize);
    xMax1 = min(size(matchable_im_j, 1) - WinHalfSize, x1 + WinHalfSize + 1);
    yMin1 = max(WinHalfSize + 1, y1 - WinHalfSize);
    yMax1 = min(size(matchable_im_j, 2) - WinHalfSize, y1 + WinHalfSize + 1);

    xx0_values = [];
    yy0_values = [];
    xx1_values = [];
    yy1_values = [];

for yy0 = yMin0:yMax0
    for xx0 = xMin0:xMax0
        if match_im_i(xx0, yy0, 1) == -1
            xx = (xx0 + x1) - x0;
            yy = (yy0 + y1) - y0;
            for yy1 = max(yMin1, yy - 1):min(yMax1, yy + 2)
                for xx1 = max(xMin1, xx - 1):min(xMax1, xx + 2)
                    if match_im_j(xx1, yy1, 1) == -1
                        xx0_values(end+1) = xx0;
                        yy0_values(end+1) = yy0;
                        xx1_values(end+1) = xx1;
                        yy1_values(end+1) = yy1;
                    end
                end
            end
        end
    end
end
AuxCost = arrayfun(@(i) sum(zncc_i(xx0_values(i), yy0_values(i), :) .* zncc_j(xx1_values(i), yy1_values(i), :)), 1:length(xx0_values));

% 筛选符合 CostMax 条件的匹配
valid_cost = 1 - AuxCost <= CostMax;
    
local_heap = [xx0_values(valid_cost);yy0_values(valid_cost);xx1_values(valid_cost);yy1_values(valid_cost);AuxCost(valid_cost)]';

if ~isempty(local_heap)
    [~, sorted_idx] = sort(local_heap(:, 5), 'descend');
    local_heap = local_heap(sorted_idx, :);
    for bestIndex = 1:size(local_heap, 1)
        xx0 = local_heap(bestIndex, 1);
        yy0 = local_heap(bestIndex, 2);
        xx1 = local_heap(bestIndex, 3);
        yy1 = local_heap(bestIndex, 4);
        if match_im_i(xx0, yy0, 1) < 0 && match_im_j(xx1, yy1, 1) < 0
            match_im_i(xx0, yy0, :) = [xx1, yy1];
            match_im_j(xx1, yy1, :) = [xx0, yy0];
            match_pair_size = match_pair_size + 1;
            match_pair(match_pair_size, :) = local_heap(bestIndex, :);
            match_heap.push(match_pair_size, local_heap(bestIndex, 5));
            maxMatchingNumber = maxMatchingNumber - 1;
            if visualization
                plot(h0, [yy0], [xx0], 'r.');
                plot(h1, [yy1], [xx1], 'r.');
            end
        end
    end
end
end

match_pair = match_pair(size(initial_match, 1) + 1:end, :);
match_heap.delete();
end
