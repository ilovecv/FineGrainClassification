function [ curGrp ] = TrainClusterModel( curGrp )
%% TrainClusterModel
%  Desc: train cluster model --> get test cluster label
%  In: 
%    curGrp -- (struct) clustering infomation for one group
%  Out:
%    curGrp -- (struct) 
%      - curGrp.nCluster  - number of clusters
%      - curGrp.cluster      - (1 * nCluster) class index
%      - curGrp.clusterGtLab - (nSample * 1) ground truth cluster label 
%      - curGrp.clusterSVM   - (1 * nCluster) SVM model
%      - curGrp.testScore - (nSample * cluterNum) SVM score
%      - curGrp.testConf  - (nCluster * nCluster) confusion matrix
%      - curGrp.clsToCluster - (nSample * 1) cluster for each sample
%%

fprintf( 'function: %s\n', mfilename );
tic;

% init basic variables
conf = InitConf( );
load( conf.imdbPath );
fprintf( '\t loading kernel (maybe slow)\n' );
load( conf.kernelPath );
nSample = length( imdb.clsLabel );
train = find( imdb.ttSplit == 1 );
test  = find( imdb.ttSplit == 0 );
clsNum = curGrp.nCluster;

% get cluster label
curGrp.clusterGtLab = zeros( size( imdb.clsLabel ) );
for k = 1 : curGrp.nCluster
  clusterIdx = find( ismember( imdb.clsLabel, curGrp.cluster{ k } ) );
  curGrp.clusterGtLab( clusterIdx ) = k;
end
% get train valid index
[ cvTrain, cvValid ] = SplitCVFold( conf.nFold, ...
  curGrp.clusterGtLab, imdb.ttSplit );

% using n-fold CV to get training sample cluster label
curGrp.clusterScore = zeros( nSample, clsNum );
for f = 1 : conf.nFold
  fprintf( '\t Fold: %d (%.2f %%)\n', f, 100 * f / conf.nFold );
  for c = 1 : clsNum
    fprintf( '\t fold cluster class: %d (%.2f %%)\n', c, 100 * c / clsNum );
    % init train valid index
    trainIdx = cvTrain{ f };
    validIdx = cvValid{ f };

    trainK = kernel( trainIdx, trainIdx );
    validK = kernel( validIdx , trainIdx );

    trainK = [ ( 1 : size( trainK, 1 ) )', trainK ];
    validK = [ ( 1 : size( validK, 1 ) )', validK ];

    yTrain = 2 * ( curGrp.clusterGtLab( trainIdx ) == c ) - 1;
    yValid = 2 * ( curGrp.clusterGtLab( validIdx ) == c ) - 1;
    % train
    tmpSVM = libsvmtrain( double( yTrain ), ...
      double( trainK ), conf.clusterSVMOPT );
    % validation score
    [ ~,~, tmpScore ] = libsvmpredict( double( yValid ), ...
      double( validK ), tmpSVM );
    curGrp.clusterScore( validIdx, c ) = tmpScore;
  end
end % end each fold

% init training and testing kernel
train = find( imdb.ttSplit == 1 );
test  = find( imdb.ttSplit == 0 );
trainK = kernel( train, train );
trainK = [ ( 1 : size( trainK, 1 ) )', trainK ];
testK  = kernel( test, train );
testK = [ ( 1 : size( testK, 1 ) )', testK ];

% train and test cluster SVM
curGrp.clusterSVM = cell( 1, clsNum );

% get test cluster label
for c = 1 : clsNum
  fprintf( '\t cluster train test: %d (%.2f %%)\n', c, 100 * c / clsNum );
  y = 2 * ( curGrp.clusterGtLab == c ) - 1;
  % train
  curGrp.clusterSVM{ c } = libsvmtrain( double( y( train ) ), ...
    double( trainK ), conf.clusterSVMOPT );
  % test
  [ ~,~, tmpScore ] = libsvmpredict( double( y( test ) ), ...
    double( testK ), curGrp.clusterSVM{ c } );
  curGrp.clusterScore( test, c ) = tmpScore;
end

% set train and test class to cluster label
[ ~, trainPred ] = max( curGrp.clusterScore( train, : ), [], 2 );
[ ~, testPred ] = max( curGrp.clusterScore( test, : ), [], 2 );
curGrp.clsToCluster = zeros( size( imdb.clsLabel ) );
curGrp.clsToCluster( train ) = trainPred;
curGrp.clsToCluster( test ) = testPred;

% get confusion matrix
[ curGrp.trainConf, curGrp.trainAcc ] = ...
  ScoreToConf( curGrp.clusterScore( train, : ), curGrp.clusterGtLab( train ) );

fprintf( '\t train mean accuracy: %.2f %%\n', curGrp.trainAcc );

[ curGrp.testConf, curGrp.testAcc ] = ...
  ScoreToConf( curGrp.clusterScore( test, : ), curGrp.clusterGtLab( test ) );

fprintf( '\t test mean accuracy: %.2f %%\n', curGrp.testAcc );

% kernel regression
curGrp.regScore = TrainMapReg( conf, imdb, ...
  curGrp.clusterScore, curGrp.clusterGtLab );

[ curGrp.regConf, curGrp.regAcc ] = ...
  ScoreToConf( curGrp.regScore( test, : ), curGrp.clusterGtLab( test ) );

fprintf( '\t reg mean accuracy: %.2f %%\n', curGrp.regAcc );


fprintf( 'function: %s -- time: %.2f (s)\n', mfilename, toc );

% end function TrainClusterModel