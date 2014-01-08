function [ oneGrp ] = GroupClustering( nCluster )
%% GroupClustering
%  Desc: clustering classes for one group
%  In: 
%    nCluster -- number of clusters
%  Out:
%    oneGrp -- (struct) 
%      - oneGrp.nCluster     - number of clusters
%      - oneGrp.cluster      - 1 * nCluster cell
%      - oneGrp.clsToCluster - nSample * 1 indicator
%%

fprintf( 'function: %s\n', mfilename );

% get configuration
conf = InitConf( );
% load imdb, kernel
load( conf.imdbPath );
fprintf( '\t loading kernel (maybe slow)\n' );
load( conf.kernelPath );

% get similarity matrix
clsSim = KernelToSim( kernel, imdb.clsLabel, imdb.ttSplit );

% get oneGrp struct
oneGrp.nCluster = nCluster;
oneGrp.cluster = cell( 1, nCluster );
% clusterring
fprintf( '\t Cluaster method: %s\n', conf.clusterType );
fprintf( '\t Cluaster number: %d\n', nCluster );
switch conf.clusterType
  case 'spectral'
    % Spectral clustering
    [ C, ~, ~ ] = SpectralClustering( clsSim, nCluster, 3 );
    for  k = 1 : nCluster
      oneGrp.cluster{ k } = find( C == k );
    end
  case 'tree'
    % load from phylogeny tree
    fprintf( '\t Load phylogeny tree manually\n' );
  otherwise
    fprintf( '\t Error: unknow clustering method %s\n', conf.clusterType );
end

% end function GroupClustering