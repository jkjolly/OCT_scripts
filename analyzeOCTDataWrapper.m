function analyzeOCTDataWrapper(inputSubjectDir,outputSubjectDir,centroidCSVPath,visFieldDiameterLimit, retinaMeanToggle)
%analyzeOCTDataWrapper(inputSubjectDir,outputSubjectDir,centroidCSVPath,visFieldDiameterLimit, retinaMeanToggle)
%
%This function analyses the multilayer sum output files generated by
%createCSVsumOutputFiles and parseCsvExport.  Iteratively, by degrees of
%visual angle, takes the mean and standard deviation of the relevant
%sections of the retina.  Saves down a per subject CSV output.
%
%  INPUTS
%
%  primaryOutputDir:  output directory from
%  createCSVsumOutputFiles/parseCsvExport.  Only files contained here
%  should be the relevant CSVs
%
%  outputSubjectDir:  the directory to save down the output from these
%  analyses.  If not specified will create ('subjectLayerAnalyses')
%  sub-directory directory in <inputSubjectDir>
%
%  centroidCSVPath:  path to the CSV file containing the data indicating
%  the centroid? of the eye
%
%  visFieldDiameterLimit:  Even integer value (under the assumption of
%  symetric visual field measurement with an integer radidus measure)
%  assumed, will throw error otherwise.  This input designates the maximum visual
%  field diameter that should be computed across analyses.  Specified to
%  preemptively control for intersubject variance resulting from centroid
%  displacement in <createCSVsumOutputFiles/parseCsvExport> output data
%  arrays(?).
%
%  pixelsTOvisAngle:  Integer value, corresponding to how many pixels (horzontal, lateral, X axis?)
%  correspond to one degree of visual angle.  If not set, defaults to
%  recommended? value of 51. THIS IS ACTUALLY COMPUTED FROM THE DATA NOW,
%  NO NEED TO INPUT IT
%
%  retinaMeanToggle:  either "rings" or "full".  This indicates whether the
%  mean of the visual field should be computed as hollow, cocentric, 1mm
%  rings (think dart board) or as a full circle/elipsoid.
%
%  OUTPUTS:
%
%  none, saves down the output
%
% Adapted from code produced by Dan Bullock and Jasleen Jolley 05 Nov 2019
% Dan Bullock 22 Jan 2020
%% Begin Code
% initialize variables and perform checks

% set output directory to subdirectory of <subjDataDir> if it isn't defined, 
if isempty(outputSubjectDir)
    outputSubjectDir=fullfile(inputSubjectDir,'subjectLayerAnalyses');
else
    %do nothing
end

%create output directory if it doesnt exist
if ~isfolder(outputSubjectDir)
    mkdir(outputSubjectDir);
else
    %do nothing
end

if isempty(visFieldDiameterLimit)
    fprintf('\n visFieldDiameter not set, computing maximum available')
else
    if rem(visFieldDiameterLimit,2)==0 %iseven
    visFieldRadiusLimit=visFieldDiameterLimit/2;
    else %isodd
    error('\n input visFieldDiameterLimit is not even')
    end
end

if isempty(retinaMeanToggle)
    fprintf('\n retinaMeanToggle not set, computing means as hollow, cocentric, 1mm rings')
else
    %do nothing
end

%%  Begin parsing of file names 
% overall this is setting the foveal point, known as the centroid here. Need to
% read the slice and position information from Heidelberg and add into the
% centroid table.


inputDirContents = dir(inputSubjectDir);
inputFileNames = {inputDirContents(~[inputDirContents(:).isdir]).name};

%reading in the files, generating the paths to serve as analysis targets
for iInputFiles=1:length(inputFileNames)
    currentFileName=inputFileNames{iInputFiles};
    %finding the indexes of underscores, just as before
    underscoreIndexes=strfind(currentFileName,'_');
    %here we are finding the last part of the file name.  Theoretically, we
    %could have used the outputs of the function fileparts on the full file
    %path for each file in <primaryOutputDir>
    dotIndexes=strfind(currentFileName,'.');
    
    %working under assumption that first name component is subjectID
    inputSubjectID{iInputFiles}=currentFileName(1:underscoreIndexes(1)-1);
    %working under assumption that second name component is eye
    inputEye{iInputFiles}=currentFileName(underscoreIndexes(1)+1:underscoreIndexes(2)-1);
    %working under assumption that third and last (it makes both
    %assumptions) name component is analysis
    inputLayerAnalyses{iInputFiles}=currentFileName(underscoreIndexes(2)+1:dotIndexes-1);
end %end analyis target path generation iteration

%Create unique subject/eye stems
%remove .csv
allFileNamesinput=erase(inputFileNames,'.csv');

%delete the layer labels, feed forward variables
allFileNamesinputNoNL=erase(allFileNamesinput,'_NL');
allFileNamesinputNoONL=erase(allFileNamesinputNoNL,'_ONL');
allFileNamesinputNoPROS=erase(allFileNamesinputNoONL,'_PROS');
allFileNamesinputNoTT=erase(allFileNamesinputNoPROS,'_TT');

%again, overengineering for input agnostic purposes
uniqueSubjEyeNames=unique(allFileNamesinputNoTT);

%% Begin analysis computations

%load the excel file to obtain the centroid data
centroidTable =readtable(centroidCSVPath);
%determine the size of <centroidTable>.  This gives us the number of subjects
tableSize=size(centroidTable);

%here we obtain the entire column under the table heading <Filename>, returns a cell string vector
centerNames=centroidTable.Filename;
%Here we are iterating over subjects, as inferred from the first entry in <tableSize>
%probably shouldn't let tableSize be dicating the analyses performed.

for iAnalysis=1:length(uniqueSubjEyeNames)  %loop over input files
    
    %quick adaptation from previous version of code.  Results in
    %redundancies later on, but efficient for now.
    currentCenterName=strcat(uniqueSubjEyeNames{iAnalysis},'_T');
    
    %finding the underscores in the name, just as before
    underscoreIndexes=strfind(currentCenterName,'_');
    
    %extract eye and subjID
    currentSubjectID=currentCenterName(1:underscoreIndexes(1)-1);
    %operating under the assumption that second name component is eye 
    currentEye=currentCenterName(underscoreIndexes(1)+1:underscoreIndexes(2)-1);
    
    %<currentAnalysis> is not used, likely because we are assuming that if a subject and eye combination exists, so to does all analyses for it
    %NOTE:  IF THIS ASSUMPTION DOES NOT HOLD, IT WOULD BE NECESSARY TO
    %GENERATE THIS FOR LATER ITERATION, at least for the purposes of
    %detecting missing data
    %currentAnalysis=currentFileName(underscoreIndexes(2)+1:dotIndexes-1);
    
    %make sure the centroid is chosen for the right subjects and eyes
    %creates a boolean vector corresponding to the variable outputSubjectID
    validSubjects=strcmp(currentSubjectID,inputSubjectID);
    %creates a boolean vector corresponding to the variable outputEye
    validEye=strcmp(currentEye,inputEye);
    
    %apply both criteria to narrow down the valid analysis files
    %NOTE, IN THE CASE WHERE YOU DIDN'T HAVE ALL ANALYSES FOR A SUBJECT, THIS IS WHERE YOU WOULD APPLY A <validAnalysis> bool variable, after generation
    currentAnalysisBool=and(validSubjects,validEye);
    
    %find index of centroid in centroid table using current file name
    currentCentroidIndex=find(strcmp(centerNames,currentCenterName));
    
    % set X and Y
    % be careful though because there appears to be a mismatch between our intuitions about x and y and the standard indexing practices of matlab
    currentXVal=centroidTable.position(iAnalysis);
    currentYVal=centroidTable.slice(iAnalysis);
    
    %returns the indexes
    %actually, this may actually make the function robust against instances where there isn't a full set of analyses.
    analysesIndexes=find(currentAnalysisBool);
    
    %layer labels for the upcoming analyses
    analysesLayerLabels={inputLayerAnalyses{analysesIndexes}};
    
    % establish empty matricies for sorted output
    %NOTE: this clears the matrix from the last iteration
    sortedMaskedMean=zeros(length(analysesLayerLabels),[visFieldDiameterLimit/2]);
    sortedmaskedStd=zeros(length(analysesLayerLabels),[visFieldDiameterLimit/2]);
    
    %iterates across the indexes of <analysesIndexes> .  The working presumption here is that length(analysesIndexes) always == 4
    for iCurrentAnalyses=1:length(analysesIndexes)  %iterate across the output names to perform analyses
        
        %generates name for current analysis file.  Note double indexing using <analysesIndexes(iCurrentAnalyses)>
        analysisFileName=strcat(inputSubjectID{analysesIndexes(iCurrentAnalyses)},'_',inputEye{analysesIndexes(iCurrentAnalyses)},'_',inputLayerAnalyses{analysesIndexes(iCurrentAnalyses)},'.csv');
        %load corresponding file.  Here we are using fullfile.
        
        %obtaining consistent ordering of <analysesLayerLabels>
        [sortedLabels,sortOrder]=sort(analysesLayerLabels);
        
        %find index of current layer analysis in alpha sorted list
        currentAnalysisLayerIndex=find(strcmp(analysesLayerLabels,inputLayerAnalyses{analysesIndexes(iCurrentAnalyses)}));
        
        %generate path to current analysis file
        subjectLayersCSVpath=fullfile(inputSubjectDir,analysisFileName);
        
        %compute masked means across 1 degree incriments of the input data.
        [maskedMeans,maskedStds] = iteratedCentroidMeanCompute(subjectLayersCSVpath,[currentXVal,currentYVal],visFieldRadiusLimit,retinaMeanToggle,[],[]);
        
        %store means and std for this analysis iteration
        sortedMaskedMean(currentAnalysisLayerIndex,:)=maskedMeans;
        sortedmaskedStd(currentAnalysisLayerIndex,:)=maskedStds;
    end
    
    
    %store output from previous iteractions.  Here we are resorting using the <sortOrder>
    % it might be worthwhile to include a fprintf with the <sortOrder> here just to give an indication of when things are being resorted

    %adding the labels as the first column of the cell structure, so that it can function as a table
    meanDataCell=horzcat(sortedLabels',num2cell(sortedMaskedMean));
    stdDataCell=horzcat(sortedLabels',num2cell(sortedmaskedStd));
    
    %NOTE degreeTotal-1 USED HERE AGAIN FOR CONSISTENCY, this is in keeping with line 183
    varNames=horzcat({'LayerNames'},strcat('degree ',strsplit(num2str(1:visFieldRadiusLimit),' ')));
    
    % create results tables
    meanDataTable=cell2table(meanDataCell,'VariableNames',varNames);
    stdDataTable=cell2table(stdDataCell,'VariableNames',varNames);
    
    %WARNING:  THIS ASSIGNMENT USES THE iCurrentAnalyses VARIBLE TO
    %ASSIGN NAMES.  NOT IDEAL, BUT SHOULDN'T CAUSE PROBLEMS.  FIX LATER
    %find a better/more independently reliable way to generate the names
    meanTableName=strcat(inputSubjectID{analysesIndexes(iCurrentAnalyses)},'_',inputEye{analysesIndexes(iCurrentAnalyses)},'_meanTable.csv');
    stdTableName=strcat(inputSubjectID{analysesIndexes(iCurrentAnalyses)},'_',inputEye{analysesIndexes(iCurrentAnalyses)},'_stdTable.csv');
    
    %writes them as table
    writetable(meanDataTable,fullfile(outputSubjectDir,meanTableName))
    writetable(stdDataTable,fullfile(outputSubjectDir,stdTableName))
    
    %just in case they need to be cleared
    clear maskedMean
    clear maskedStd
end