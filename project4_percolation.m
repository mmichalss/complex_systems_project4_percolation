% Complex Systems Project 4: Percolation
% Due date: 13.12.2024
set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
%% Burn and H-K algorithm figures
clear

L = 10;
r = rand(L,L);
p = [0.4 0.6 0.8];
for pi = p
    lattice = r<pi;
    [burnt] = burn(lattice);
    plot_percolation(burnt,lattice)
    [K,~,~,] = HK_algorithm(lattice);
    plot_clusters(K)
end

%% Creating output data

[L, T, p0, pk, dp] = readInputParameters('perc-ini.txt');

p_values = p0 : dp : pk;

if ~exist('output_data', 'dir')
    mkdir('output_data');
end

avg_filename = ['output_data/Ave-L', num2str(L), 'T', num2str(T), '.txt'];
avg_file = fopen(avg_filename, 'w');

p_flow = zeros(size(p_values));
avg_max_cluster_size = zeros(size(p_values));

for idx = 1:length(p_values)
    pi = p_values(idx);
    fprintf('Processing p = %.4f\n', pi);
    [p_flow(idx), avg_max_cluster_size(idx)] = probability_clusterSize(T, L, pi);

    fprintf(avg_file, '%.4f  %.6f  %.6f\n', pi, p_flow(idx), avg_max_cluster_size(idx));

    [clusterSizes, clusterDistribution] = calculateRelativeClusterDistribution(T, L, pi);
    dist_filename = ['output_data/Dist-p', num2str(pi), 'L', num2str(L), 'T', num2str(T), '.txt'];
    dist_file = fopen(dist_filename, 'w');
    for j = 1:length(clusterSizes)
        fprintf(dist_file, '%d  %.6f\n', clusterSizes(j), clusterDistribution(j));
    end
    fclose(dist_file);
end

fclose(avg_file);

figure;
subplot(2,1,1);
plot(p_values, p_flow, '-o');
xlabel('$p$');
ylabel('$P_{flow}$');
title('Probability of Percolation');

subplot(2,1,2);
plot(p_values, avg_max_cluster_size, '-o');
xlabel('$p$', 'Interpreter', 'latex');
ylabel('$\langle s_{max} \rangle$');
title('Average Maximum Cluster Size');

%% Reading file

function [L, T, p0, pk, dp] = readInputParameters(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open input file: %s', filename);
    end
    data = textscan(fid, '%f %*[^\n]', 5);
    fclose(fid);
    L = data{1}(1);
    T = data{1}(2);
    p0 = data{1}(3);
    pk = data{1}(4);
    dp = data{1}(5);
end

%% Monte Carlo
T = 1e3;
L = [10 50 100];
p = 0.5: 0.01 :0.7;

figure;
for ll=1:length(L)
    L_label = ['$L=$', num2str(L(ll))];
    p_flow = zeros(1,length(p));
    avg_max_cluster_size = zeros(1,length(p));
    for ii=1:length(p)
        Li = L(ll);
        pi = p(ii);
        [p_flow(ii),avg_max_cluster_size(ii)] = probability_clusterSize(T,Li,pi);
    end
    subplot(211)
    plot(p,p_flow, 'DisplayName', L_label)
    title('$P_{flow}$')
    xlabel('$p$')
    ylabel('$P_{flow}$')
    legend('Location','best')
    hold on
    subplot(212)
    plot(p,avg_max_cluster_size, 'DisplayName', L_label)
    title('$\left<c_{max}\right>$')
    xlabel('$p$')
    ylabel('$\left< c_{max}\right>$')
    legend('Location','best')
    hold on
end

hold off

%% Relative cluster distribution

T = 1e4;
L = 100;
plotClusterDistributions(T,L)

%%

function [burnt, percolates] = burn(t)

   [rows, cols] = size(t);
   burnt = zeros(rows, cols);
   percolates = false;

   % step 1
   for ii = 1:cols
        if t(1,ii) == 1
            burnt(1,ii) = 2;
        end
   end

   % step 2
   ttime = 3;
   while true
        new_burnt = burnt;
        for i = 1:rows
            for j = 1:cols
                if burnt(i, j) == ttime - 1
                    % Check neighbors
                    for di = -1:1
                        for dj = -1:1
                            ni = i + di;
                            nj = j + dj;
                            if abs(di) + abs(dj) ~= 1 % Only orthogonal neighbors
                                continue;
                            end
                            if ni >= 1 && ni <= rows && nj >= 1 && nj <= cols
                                if t(ni, nj) == 1 && burnt(ni, nj) == 0
                                    new_burnt(ni, nj) = ttime;
                                end
                            end
                        end
                    end
                end
            end
        end
        % If no new cells are burnt, break the loop
        if isequal(new_burnt, burnt)
            break;
        end
        burnt = new_burnt;

        if any(burnt(rows, :) > 0)
            percolates = true;
            fprintf('Percolation path exists at time step %d.\n', ttime);
            break;
        end
        ttime = ttime + 1;
   end
end

function plot_percolation(burnt, t)
    
    burnt_display = burnt;
    burnt_display(burnt_display == 0) = NaN; 
    
    plot_data = NaN(size(t));
    plot_data(t == 1 & burnt == 0) = 0;            % Unburnt occupied sites set to 0
    plot_data(burnt > 0) = burnt(burnt > 0);       % Burnt sites keep their time steps
    
    max_time = max(burnt(:));
    
    % Create the colormap
    max_time = max(burnt(:));
    color_unburnt = [1, 1, 1];   
    colormap_burnt = [...
        linspace(1, 1, max_time)', ...            
        linspace(1, 0, max_time)', ...             
        zeros(max_time, 1)];                      
    cmap = [color_unburnt; colormap_burnt];       
   

    [rows, cols] = size(plot_data);
    figure;
    imagesc(plot_data);
    axis equal off;
    colormap(cmap);
    caxis([-0.5, max_time + 0.5]);  
    colorbar;
    title('Burnt Sites');
    hold on;
    for k = 0.5:1:rows+0.5
        plot([0.5, cols+0.5], [k, k], 'k-');
        plot([k, k], [0.5, rows+0.5], 'k-');
    end
    hold off;

    colorbar_ticks = [0, round(linspace(1, max_time, min(max_time, 5)))];
    colorbar('Ticks', colorbar_ticks, 'TickLabels', arrayfun(@num2str, colorbar_ticks, 'UniformOutput', false));
    
    
    hold on;
    for i = 1:rows
        for j = 1:cols
            value = plot_data(i, j);
            if isnan(value) || value == 0
                continue; 
            else
                x = j;
                y = i;
                time_step = value;
                
                if time_step < (max_time / 2)
                    txt_color = 'k'; 
                else
                    txt_color = 'w';
                end
                text(x, y, num2str(time_step), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 6, 'Color', txt_color);
            end
        end
    end
    hold off;
    
    [burnt_i, burnt_j] = find(~isnan(burnt_display));
    burnt_time_steps = burnt(sub2ind(size(burnt), burnt_i, burnt_j));
    
    max_time = max(burnt_time_steps);
    half_time = max_time / 2;
    txt_colors = cell(size(burnt_time_steps));
    txt_colors(burnt_time_steps < half_time) = {'k'};
    txt_colors(burnt_time_steps >= half_time) = {'w'};
    
    % Add time step numbers
    hold on;
    for idx = 1:length(burnt_i)
        x = burnt_j(idx);
        y = burnt_i(idx);
        time_step = burnt_time_steps(idx);
        text(x, y, num2str(time_step), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 6, 'Color', txt_colors{idx});
    end
    hold off;
    
    % Plot the initial grid of occupied sites
    figure;
    imagesc(t);
    colormap([1 1 1; 0 0 0]);
    axis equal off;
    title('Initial Occupied Sites');
    hold on;
    for k = 0.5:1:rows+0.5
        plot([0.5, cols+0.5], [k, k], 'k-');
        plot([k, k], [0.5, rows+0.5], 'k-');
    end
    hold off;
end

function plot_clusters(K)
    cluster_labels = unique(K);
    cluster_labels(cluster_labels == 0) = []; % Remove background label (0)
    num_clusters = length(cluster_labels);
    
    colors = hsv(num_clusters);
    full_colormap = [1 1 1; colors];
    
    % Map cluster numbers to indices in the colormap
    % Background (0) -> 1, Cluster labels -> 2 onwards
    % Create a mapping from cluster label to colormap index
    cluster_to_color_index = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for idx = 1:num_clusters
        cluster_to_color_index(cluster_labels(idx)) = idx + 1; % +1 for the background color
    end
    
    [m, n] = size(K);
    color_index_matrix = zeros(m, n);
    for i = 1:m
        for j = 1:n
            if K(i, j) == 0
                color_index_matrix(i, j) = 1; % Background color index
            else
                color_index_matrix(i, j) = cluster_to_color_index(K(i, j));
            end
        end
    end
    
    figure('Color', 'w');
    imagesc(color_index_matrix);
    colormap(full_colormap);
    axis equal off; 
    title('Cluster Visualization', 'Interpreter', 'latex', 'FontSize', 14);
    
    colorbar_handle = colorbar('Ticks', []);
    num_ticks = num_clusters + 1;
    tick_positions = linspace(1 + 0.5, num_clusters + 1 + 0.5, num_ticks);
    
    tick_labels = ['0', arrayfun(@num2str, cluster_labels', 'UniformOutput', false)];
    set(colorbar_handle, 'Ticks', tick_positions, 'TickLabels', tick_labels);
    ylabel(colorbar_handle, 'Cluster Number', 'Interpreter', 'latex', 'FontSize', 12);
    hold on;
    for k = 0.5:1:m+0.5
        plot([0.5, n+0.5], [k, k], 'k-');
        plot([k, k], [0.5, m+0.5], 'k-');
    end
    hold off;
end

function [K, Mk, Cluster_Histogram] = HK_algorithm(lattice)
    [rows, columns] = size(lattice);
    K = zeros(rows, columns);                   % Cluster label matrix
    max_labels = rows * columns;                % Maximum possible number of labels
    Label = 1:max_labels;                       % Label equivalence array
    Mk = zeros(max_labels, 1);                  % Cluster masses (only one column needed)
    k = 1;                                      % Initial label

    for i = 1:rows
        for j = 1:columns
            if lattice(i, j) == 1
                neighbors = [];
                if i > 1 && lattice(i - 1, j) == 1
                    neighbors(end + 1) = K(i - 1, j);
                end
                if j > 1 && lattice(i, j - 1) == 1
                    neighbors(end + 1) = K(i, j - 1);
                end

                if isempty(neighbors)
                    K(i, j) = k;
                    Mk(k) = 1;
                    k = k + 1;
                else
                    min_label = min(neighbors);
                    K(i, j) = min_label;
                    Mk(min_label) = Mk(min_label) + 1;

                    for n = neighbors
                        if n ~= min_label
                            root_min = findRoot(Label, min_label);
                            root_n = findRoot(Label, n);
                            if root_min ~= root_n
                                Label(root_n) = root_min;
                            end
                        end
                    end
                end
            end
        end
    end
    [K_corrected, Mk_corrected] = relabelClusters(K, Mk, Label);

    unique_labels = unique(K_corrected(:));
    unique_labels(unique_labels == 0) = [];  % Remove background label (0)
    Cluster_Histogram = zeros(length(unique_labels), 1);

    for idx = 1:length(unique_labels)
        label = unique_labels(idx);
        Cluster_Histogram(idx) = Mk_corrected(label);
    end

    % Remove zero entries from Mk and adjust K
    Mk = Mk_corrected(1:max(unique_labels));
    K = K_corrected;
end

function root = findRoot(Label, k)
    while Label(k) ~= k
        k = Label(k);
    end
    root = k;
end

function [K_corrected, Mk_corrected] = relabelClusters(K, Mk, Label)
    % Resolve label equivalences
    max_label = max(K(:));
    CorrectLabels = 1:max_label;
    for k = 1:max_label
        CorrectLabels(k) = findRoot(Label, k);
    end

    [unique_labels, ~, new_labels] = unique(CorrectLabels);
    label_mapping = zeros(max_label, 1);
    label_mapping(unique_labels) = 1:length(unique_labels);

    K_corrected = zeros(size(K));
    occupied = K > 0;
    K_corrected(occupied) = label_mapping(CorrectLabels(K(occupied)));

    Mk_corrected = zeros(length(unique_labels), 1);
    for idx = 1:length(unique_labels)
        old_label = unique_labels(idx);
        Mk_corrected(idx) = sum(Mk(CorrectLabels == old_label));
    end
end

function [p_flow, avg_max_cluster_size] = probability_clusterSize(T,L,p)
    percolates=zeros(1,T);
    MaxClusterSizes=zeros(1,T);
    for i=1:T
        lattice = rand(L,L) < p;
        [~,percolates(i)] = burn(lattice);
        [~,~,Cluster_Histogram] = HK_algorithm(lattice);
        MaxClusterSizes(1,i) = max(Cluster_Histogram);
    end

    p_flow = sum(percolates)/T;
    avg_max_cluster_size = mean(MaxClusterSizes);
end

function plotClusterDistributions(T,L)
    p_values = [0.2, 0.3, 0.4, 0.5, 0.592746, 0.6, 0.7, 0.8];
    p_c = 0.592746;  

    fig_less = figure;
    hold on;
    title('Cluster Size Distribution for $p < p_c$', 'Interpreter', 'latex');
    xlabel('$s$', 'Interpreter', 'latex');
    ylabel('$ln(n_s)$', 'Interpreter', 'latex');
    xlim([0 50])

    fig_equal = figure;
    hold on;
    title('Cluster Size Distribution for $p = p_c$', 'Interpreter', 'latex');
    xlabel('$ln(s)$', 'Interpreter', 'latex');
    ylabel('$ln(n_s) L^2$', 'Interpreter', 'latex');
    xlim([0 5])

    fig_greater = figure;
    hold on;
    title('Cluster Size Distribution for $p > p_c$', 'Interpreter', 'latex');
    xlabel('$s$', 'Interpreter', 'latex');
    ylabel('$ln(n_s)$', 'Interpreter', 'latex');
    xlim([0 100])

    num_p_values = length(p_values);
    colors = lines(num_p_values);
    marker_shapes = {'o', 's', '^', 'v', '.', '*', 'x', '+'};

    for idx = 1:num_p_values
        pi = p_values(idx);
        fprintf('Processing p = %.6f\n', pi);

        marker = marker_shapes{mod(idx - 1, length(marker_shapes)) + 1};
        [clusterSizes, relativeClusterDistribution] = calculateRelativeClusterDistribution(T, L, pi);

        if pi < p_c
            figure(fig_less);
            plot(clusterSizes, log(relativeClusterDistribution), marker, 'Color', colors(idx,:), 'DisplayName', sprintf('$p = %.3f$', pi));
        elseif abs(pi - p_c) < 1e-6
            figure(fig_equal);
            plot(log(clusterSizes), log(relativeClusterDistribution) .* L^2, marker,'Color', colors(idx,:), 'DisplayName', sprintf('$p = %.6f$', pi));
        else
            figure(fig_greater);
            plot(clusterSizes, log(relativeClusterDistribution), marker, 'Color', colors(idx,:), 'DisplayName', sprintf('$p = %.3f$', pi));
        end
    end

    figure(fig_less);
    legend('show', 'Location', 'best');
    grid on;
    hold off;

    figure(fig_equal);
    legend('show', 'Location', 'best');
    grid on;
    hold off;

    figure(fig_greater);
    legend('show', 'Location', 'best');
    grid on;
    hold off;
end

function [clusterSizes, relativeClusterDistribution] = calculateRelativeClusterDistribution(T, L, p)
    maxClusterSize = L * L;
    totalClusterCounts = zeros(1, maxClusterSize);

    for t = 1:T
    lattice = rand(L, L) < p;
    [~, Mk, ~] = HK_algorithm(lattice);
    cluster_sizes = Mk(Mk > 0);
    for sizeIdx = 1:length(cluster_sizes)
        size = cluster_sizes(sizeIdx);
        if size > 0 && size <= maxClusterSize
            totalClusterCounts(size) = totalClusterCounts(size) + 1;
        end
    end
    end
    
    totalClusters = sum(totalClusterCounts);
    if totalClusters > 0
        relativeClusterDistribution = totalClusterCounts / totalClusters;
    else
        relativeClusterDistribution = zeros(1, maxClusterSize);
    end
    
    clusterSizes = find(relativeClusterDistribution > 0);
    relativeClusterDistribution = relativeClusterDistribution(clusterSizes);
end