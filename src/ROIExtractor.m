classdef ROIExtractor < handle
    properties (SetAccess = private)
        method;
        max_region_number;
    end
    
    methods (Access = public)
        function obj = ROIExtractor(method, max_region_number)
            if ~exist('method', 'var')
                method = 'vbgmm';
            end
            
            if ~exist('max_region_number', 'var')
                max_region_number = [];
            end
            
            if ~any(strcmp({'approach1', 'approach2'}, method))
                error('ROIExtractor: method should be "approach1" or "approach2"');
            end
            
            obj.method = method;
            obj.max_region_number = max_region_number;
        end
        
        function regions = extract(obj, images)
            if ~iscell(images) || ~isvector(images)
                error('ROIExtractor: images should be a cell array whose size is N x 1');
            end
                        
            switch obj.method
                case 'approach1'
                    regions = obj.extract_by_range(images);
                case 'approach2'
                    regions = obj.extract_by_vbgmm(images);
            end
        end
    end
    
    methods (Access = private)
        function regions = extract_by_range(obj, images)
            if isempty(obj.max_region_number)
                max_region_number = length(images);
            else
                max_region_number = obj.max_region_number;
            end
            
            sorted_images = sort_images(images);
            image_number = length(images);
            med = ceil((1 + image_number) / 2);
            image = sorted_images{med};
            
            luminance = calculate_luminance(image);
            sorted_luminance = sort(luminance(:), 'ascend');
            
            range = sorted_luminance(end) - sorted_luminance(1);
            tmp_endpoints = (range / max_region_number) * (0:max_region_number);
            endpoints = tmp_endpoints + sorted_luminance(1);

            regions = cell(max_region_number, 1);
            for i = 1:max_region_number
                j = max_region_number - i + 1;
                if i == 1
                    regions{i} = luminance >= endpoints(j);
                    continue;
                end
                regions{i} = (luminance >= endpoints(j)) & (luminance < endpoints(j+1));
            end
        end
        
        function regions = extract_by_vbgmm(obj, images)
            if isempty(obj.max_region_number)
                max_region_number = length(images);
            else
                max_region_number = obj.max_region_number;
            end
            
            luminances = cell(size(images));
            down_luminances = cell(size(images));
            
            [height, width, ~] = size(images{1});
            if height > width
                down_size = [256, NaN];
            else
                down_size = [NaN, 256];
            end
            
            for i = 1:length(images(:))
                luminances{i} = calculate_luminance(images{i});
                down_luminances{i} = imresize(luminances{i}, down_size);
            end
            
            X = zeros(length(luminances{1}(:)), length(images(:)));
            X_down = zeros(length(down_luminances{1}(:)), length(images(:)));
            for i = 1:length(images(:))
                X(:, i) = luminances{i}(:);
                X_down(:, i) = down_luminances{i}(:);
            end
            
            vbgmm = VariationalGaussianMixtureModel(max_region_number);
            max_iter = 100;
            vbgmm.fit(X_down, max_iter);
            clusters = vbgmm.classify(X);
            
            valid_clusters = unique(clusters(~isnan(clusters)));
            regions = cell(length(valid_clusters), 1);
            for i = 1:length(valid_clusters)
                regions{i} = true(size(luminances{1}));
                regions{i}(clusters ~= valid_clusters(i)) = false;
            end
        end
    end
end