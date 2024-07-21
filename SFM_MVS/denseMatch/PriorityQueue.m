% 自定义优先队列的实现
classdef PriorityQueue < handle
    properties
        data
        size
    end
    
    methods
        function obj = PriorityQueue(maxSize)
            obj.data = zeros(maxSize, 2);
            obj.size = 0;
        end
        
        function push(obj, index, priority)
            obj.size = obj.size + 1;
            obj.data(obj.size, :) = [index, priority];
        end
        
        function [index, priority] = pop(obj)
            [~, idx] = max(obj.data(1:obj.size, 2));
            index = obj.data(idx, 1);
            priority = obj.data(idx, 2);
            obj.data(idx, :) = obj.data(obj.size, :);
            obj.size = obj.size - 1;
        end
        
        function sz = get_size(obj)
            sz = obj.size;
        end
        
        function delete(obj)
            % 清理队列
            obj.data = [];
            obj.size = 0;
        end
    end
end