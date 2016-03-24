#Author: Suchee
#email: sucheendra.palaniappan@inria.fr

function automated_analyzer
tic;

files = {'/Users/spalania/Desktop/thiagu-data/Mouse1_blood.fcs','/Users/spalania/Desktop/thiagu-data/Mouse2_blood.fcs','/Users/spalania/Desktop/thiagu-data/Mouse3_blood.fcs','/Users/spalania/Desktop/thiagu-data/Mouse4_blood.fcs'};

[fcsdats fcshdrs]=cellfun(@fca_readfcs, files, 'UniformOutput', false);

disp(sprintf('Files loaded: %gs',toc));

global nfcs;

y = 0;
nfcs = size(fcsdats, 2);	
for i=1:nfcs
    y = max([y size(fcsdats{i}, 2)]);
end

% read all data to one huge matrix
% and defined gates according to each filename
% sessionData  = retr('sessionData');

global sessionData 
global gates
sessionData = zeros(0, y);
gates = cell(nfcs,4);
last_gate_ind = 0;

if (isempty(sessionData)) 
    sessionData = zeros(0, y);
    gates = cell(nfcs,4);
    last_gate_ind = 0;
else 
    last_gate_ind = size(gates, 1);

    % if we're adding gates that have extra channels. like after the
    % user has ran tSNE or something like that
    if (size(sessionData, 2)< y) 
        sessionData(:, end+1:y) = zeros(size(sessionData,1), y - size(sessionData,2));
    end
end

for i=1:nfcs
    %-- add data to giant matrix
    currInd = size(sessionData, 1);
    sessionData(currInd+1:currInd+size(fcsdats{i},1), 1:size(fcsdats{i},2)) = fcsdats{i}(:, :);
    %-- save files as gates
    [~, fcsname, ~] = fileparts(files{i}); 
    gates{last_gate_ind+i, 1} = char(fcsname);
    gates{last_gate_ind+i, 2} = currInd+1:currInd+size(fcsdats{i},1);
%           gates{last_gate_ind+i, 3} = cdatas{i}.channel_name_map;        
    gates{last_gate_ind+i, 3} = get_channelnames_from_header(fcshdrs{i});        
    gates{last_gate_ind+i, 4} = files{i}; % opt cell column to hold filename
end

selected_gates = [1:nfcs];
sample_size = 10000;
global gate_indices;

[gate_indices, channel_names] = getSelectedIndices(selected_gates);

global original_number_of_channels;
original_number_of_channels = numel(channel_names);

rand_sample = randsample(gate_indices, min(sample_size, length(gate_indices)));
createNewGate(rand_sample, channel_names, {'sample_all'});

if numel(selected_gates) > 1
    global sessionData;
    v = zeros(size(sessionData,1), 1);

    for j=selected_gates
        v(gates{j, 2}) = j;
    end
    addChannels({'gate_source'}, v(:), 1:numel(v), size(gates, 1));
end

save('testing_before')

runTSNE(2);
phenoEach();
gateContext = gates{[nfcs+1], 2};
temp_source = unique(sessionData(gateContext,14));
for i=1:numel(temp_source)
    gate_indeces_gate=find(sessionData(gateContext,14) == temp_source(i,1));
    createNewGate(gateContext(gate_indeces_gate),gates{[nfcs+1], 3},{num2str(temp_source(i,1))});
end

save('testing_after')

end

function channel_names=get_channelnames_from_header(fcshdr)
    channel_names1 = {fcshdr.par.name};
    channel_names2 = {fcshdr.par.name2};
	if (strcmp(channel_names1,channel_names2)==0)
        channel_names = combineNames(channel_names1,channel_names2);
    else
        channel_names=channel_names2;
	end
end

function [indices channels] = getSelectedIndices(selected_gates)
    global gates;
    % extract specific gate or merge multiple gates according to selection
    if (numel(selected_gates) == 1)
        indices = gates{selected_gates, 2};
        channels =  gates{selected_gates, 3};
    else 
        indices = [];
        if (~isempty(selected_gates))
            channels = gates{selected_gates(1),3};
        else
            channels = [];
        end
        
        % --- for simplicity we assume same channels for all gates  except for
        % trailing channels. so changes in size are the only changes in channels. 
        
        % loop thorugh each selected gate. we'll collect (union) the data
        % and 'intersect' the channels as some gates may have more or
        % different channels appended.
        for i=selected_gates
            
            indices = union(gates{i, 2}, indices);            
            
            if (size(channels,2) > size(gates{i,3}, 2)) 
                
                % shorten the channel names in use
                channels = channels(1:size(gates{i,3}, 2));
            end
        end
    end
end

function created=createNewGate(gate_indices, channel_names, opt_gate_name)
    created = false;
    global gates;
    
    %opt_gate_name = {'sample_all'};
    
    if (~isempty(opt_gate_name)) 
        gates(end+1, 1) = opt_gate_name;
        gates{end, 2}   = gate_indices;
        gates{end, 3}   = channel_names;
        created = true;
    end
end

function addChannels(new_channel_names, new_data, opt_gate_context, opt_gates)
    global sessionData;
    global gates;   
    global gate_indices; 

    if (exist('opt_gate_context','var'))
        gate_context = opt_gate_context;
    else
        gate_context = gate_indices;    
    end
    
    if (exist('opt_gates','var'))
        selected_gates = opt_gates;
    else
        selected_gates = get(handles.lstGates, 'Value');
        if isempty(selected_gates)
            selected_gates = 1:size(gates, 1);
        end
        
        % filter indices if user selected to intersect gates
        if get(handles.btnIntersect, 'Value')
            selected_int_gates = get(handles.lstIntGates, 'Value');
            [gate_indices channel_names] = getSelectedIndices(selected_gates);
            [gate_int_indices channel_int_names] = getSelectedIndices(selected_int_gates);
            % check if one group is contained in the other
            if isempty(setdiff(gate_int_indices, gate_indices))
                selected_gates = selected_int_gates;
            else
                msgbox('Your are using intersect mode so SightOf does not know which gates to add the resulting channels to. By default, when the intersecting group is not contained in the main selected gates group, the channels are added to all the main selected gates. ','Channels added to selected gates though content is only added to the intersection.','warn');
            end
        end    

    end
    
    % add necessary channels to the selected gates
    defined_channels = cellfun(@(x)numel(x), gates(selected_gates, 3), 'uniformoutput', true);
    undef_channel_ind = max(defined_channels)+1;
    
    if (size(sessionData,2)-undef_channel_ind >= 0) && ...
        any(~any(sessionData(gate_context, undef_channel_ind:end)))
        
        % find a streak the same width of new_data of empty columns
        d = diff([false any(sessionData(gate_context, undef_channel_ind:end)) == 0 ones(1, size(new_data, 2)) false]);
        p = find(d==1);
        m = find(d==-1);
        lr = find(m-p>=size(new_data, 2));
        last_def_channel = undef_channel_ind - 1 + (p(lr(1)) - 1);
    else
        last_def_channel = size(sessionData,2);
    end
        
    for i=selected_gates
        
        % add new channel names to gate
        channel_names = gates{i, 3};
        if (last_def_channel-numel(channel_names) > 0)
            % add blank\placeholder channel names
            for j=numel(channel_names)+1:last_def_channel
                channel_names{j} = 'cyt_placeholder_tmp';
            end
        end
        channel_names(end+1:end+numel(new_channel_names)) = new_channel_names;
        gates{i, 3} = channel_names;
    end
    
    n_new_columns = size(new_data, 2) - (size(sessionData,2) - last_def_channel);
    
    % extend session data
    if (n_new_columns > 0)
        new_columns = zeros(size(sessionData, 1), n_new_columns);
        sessionData = [sessionData new_columns];
    end
    
    % set new data to session
    sessionData(gate_context, last_def_channel+1:last_def_channel+size(new_data, 2)) = new_data;    

end

function runTSNE(normalize)
    ndims = 2; % fast tsne is only implemented for 2 dims.
    global original_number_of_channels;
    global sessionData;
    global gates;
    global nfcs;
    
    selected_channels = [1:original_number_of_channels];
    gate_context = gates{[nfcs+1], 2};
            
    MAX_TSNE = 1000000;
    
    if (numel(gate_context) > MAX_TSNE)
        setStatus(sprintf('Cannot run tSNE locally on more than %g points. Please subsample first.', MAX_TSNE));
        return;
    end
    
    data = sessionData(gate_context, selected_channels);
            
    try
        map = fast_tsne(data, 110);
    catch 
        msgbox(...
                ['tSNE Failed: Common causes are \n' ...
                'a) illegal cyt installation path - spaces in path.\n' ...
                'b) illegal cyt installation path - no writing persmissions in folder.\n' ...
                'c) perplexity too high caused by insufficient number of points.'],...
               'Error','error');  
        return;        
    end

    disp(sprintf('map generated in %g m', toc/60));

    new_channel_names = cell(1, ndims);
    for i=1:numel(new_channel_names)
        new_channel_names{i} = sprintf('bh-SNE%g', i);
    end

    addChannels(new_channel_names, map, gate_context,nfcs+1);
    
end

function channel_names = combineNames(channel_names1,channel_names2)
    channel_names = cell(size(channel_names1));
    if isempty(channel_names2{1})
        channel_names = channel_names1;
        add_channel=channel_names2;   
    else
        channel_names = channel_names2;
        add_channel=channel_names1; 
    end
    
    for i=1:length(channel_names)
      % if i>3
           channel_names{i}=strcat(channel_names{i},'_',add_channel{i});
     %  end
    end

end

function phenoEach
    global sessionData;
    global gates;  
    global original_number_of_channels;
    global nfcs;
    
    session_data  = sessionData;
    selected_channels = [1:original_number_of_channels];
    gate_names        = gates(:,1);
    selected_gates = nfcs+1;
    
    mehtod=1;
    k_neigh='100';
    selection=7;
        
    try
        %if the user didn't choose K or the K=0
        if (isempty(k_neigh) || str2num(k_neigh) == 0)
            uiwait(msgbox('K must be a positive integer','Error','error'));
            return;
        end

        k_neigh = str2num(k_neigh);
    catch
        uiwait(msgbox('K must be a positive integer','Error','error'));
        return;
    end
    
    %getting the distance metric
    distance = '';
    
    switch selection %defining distance from user selection
        case 1
            distance = 'euclidean';
        case 2
            distance = 'seuclidean';
        case 3
            distance = 'cosine';    
        case 4
            distance = 'correlation';
        case 5
            distance = 'spearman';
        case 6
            distance = 'cityblock';
        case 7
            distance = 'mahalanobis';     
    end

    allClusters=[];   
    gate_context=[];   
    if mehtod==1 % phenograph each gate separately 

        uniqueID={};
        nSelectedGates = numel(selected_gates);
        for i=1:nSelectedGates
            data = session_data(gates{selected_gates(i), 2}, selected_channels);

            [clusterLable,~,~,ID] = phenograph(data, k_neigh,'distance',distance);
            
            uniqueID{end+1}=ID;
            maxClu = max([allClusters;0]);
            clusterLable(find(clusterLable))=clusterLable(find(clusterLable))+maxClu;            
            
            allClusters=[allClusters;clusterLable];
            gate_context = [gate_context(:);gates{selected_gates(i), 2}(:)];
        end

        % Giving a temporary name to the channel
        tmpChannelName = 'PhenoGraph Each UID0000';
        addChannels({tmpChannelName}, allClusters, gate_context,nfcs+1);
        
        % Changing the channels name by the unique ID
        for i=1:numel(selected_gates)
            gate=selected_gates(i);
            ch_names=gates{gate,3};
            chTMP = cellstrfnd(ch_names, tmpChannelName);
            ch_names(chTMP) = {sprintf('PhenoGraph Each K%g %s',...
                                      k_neigh,uniqueID{i})};
            gates{gate,3}=ch_names;           
        end    
        return;  
    else  % phenograph all gates together 
        data = session_data(gate_context, selected_channels);

        [clusterLable,~,~,ID] = phenograph(data, k_neigh,'distance',distance);
        channelName = sprintf('PhenoGraph K%g %s', k_neigh, ID);
        addChannels({channelName}, clusterLable, gate_context,nfcs+1);
    end
end

