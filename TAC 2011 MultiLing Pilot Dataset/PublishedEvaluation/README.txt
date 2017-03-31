This file describes contents of the archive.

Directories
===========
AutomaticEvaluation: Contains the evaluation results of AutoSummENG and ROUGE.
  -- AutoSummENG: Contains information on the scores of the AutoSummENG metric (Merged Model Graphs variation, MeMoG, parameters: symmetric graph, m=M=D_{win}=3)
    -- Averages: Contains average system performances per language, for AutoSummENG.
    -- Detailed: Contains detailed summary performances per language, for AutoSummENG.
  -- ROUGE: Contains information on the scores of the ROUGE metric (ROUGE-1, ROUGE-2, ROUGE-SU4 variations, parameters: -a -x -2 4 -u -c 95 -r 1000 -n 2 -f A -p 0.5 -t 0 -d)
    -- Averages: Contains average system performances per language, for ROUGE.
    -- Detailed: Contains detailed summary performances per language, for ROUGE.

HumanEvaluation: Contains the evaluation results of human judges, per language.
  Each file, one per language, contains the following fields:
  Topic: The topic of the summary
  Peer: The ID of the peer system
  Length: The maximum allowed length in words (always 250).
  Evaluator: The ID of the evaluator.
  Grade: The grade assigned by the evaluator to the summary (between 1 and 5).
  TrueLength: The actual length of the summary. Allowed range was 240-250 words. However, some summaries were below the lower limit.
  LengthAwareGrade: The final grade, taking into account out-of-limit summaries. 
    For a summary of X words, the formula for the calculation of the Length Aware Grade (LAG), given that the grade G is given is:
    LAG = G * (1 - max(max(240-X, X-250), 0) / 240)


Team to ID mapping
==================
We note that systems ID9, ID10 were ``baseline'' and ``topline'' automatic systems, correspondingly.
ID9: ``Centroid document''-based summary.
ID10: ``Genetic algorithm''-based summary using model summary information.
Details of these systems will be supplied at the TAC conference and in corresponding publications.

CIST1 -> ID1
CLASSY1 -> ID2
JRC1 -> ID3
LIF1 -> ID4
SIEL_IIITH1 -> ID5
TALN_UPF1 -> ID6
UBSummarizer1 -> ID7
UoEssex1 -> ID8
CentroidBaseline -> ID9
GATopline -> ID10


Languages per Participant
=========================
CIST1 -> ID1 		: Arabic Czech English French Greek Hebrew Hindi
CLASSY1 -> ID2 		: Arabic Czech English French Greek Hebrew Hindi
JRC1 -> ID3 		: Arabic Czech English French Greek Hebrew Hindi	Coorganizer (Czech)
LIF1 -> ID4 		: Arabic Czech English French Greek Hebrew Hindi	Coorganizer (French)
SIEL_IIITH1 -> ID5 	:              English French              Hindi	Coorganizer (Hindi)
TALN_UPF1 -> ID6 	: Arabic       English French              Hindi
UBSummarizer1 -> ID7 	: Arabic Czech English French Greek Hebrew Hindi	Coorganizer (Arabic)
UoEssex1 -> ID8 	: Arabic       English
CentroidBaseline -> ID9 : Arabic Czech English French Greek Hebrew Hindi	Baseline by NCSR Demokritos (All)
GATopline -> ID10	: Arabic Czech English French Greek Hebrew Hindi	Topline by NCSR Demokritos (All)

Thanks
======
Sentence splitting for ROUGE was performed based on Python NLTK toolkit.