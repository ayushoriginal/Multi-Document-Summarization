# Multi-Document Summarization
==============================

## Papers List (Introductory + Posted on Slack)

### I. Extend existing work on Single-Doc to Multi-doc.

  1)[Neural Summarization by Extracting Sentences and Words](https://arxiv.org/abs/1603.07252)
  
  2)[SummaRuNNer: A Recurrent Neural Network based Sequence Model for Extractive Summarization of Documents](https://arxiv.org/abs/1611.04230)
  
  3)[SummaRuNNer: A Recurrent Neural Network based Sequence Model for Extractive Summarization of Documents](https://arxiv.org/abs/1611.04244)

### II. Using graph representation of multi-doc and graph embedding:

  1)[Towards Coherent Multi-Document Summarization](http://knowitall.cs.washington.edu/gflow/publications/christensen_naacl13.pdf)

  2)[LexRank: Graph-based Lexical Centrality as Salience in Text Summarization](http://www.jair.org/media/1523/live-1523-2354-jair.pdf)

  3)[DeepGraph: Graph Structure Predicts Network Growth](https://arxiv.org/abs/1610.06251)

  4)[Revisiting Semi-Supervised Learning with Graph Embeddings](https://arxiv.org/abs/1603.08861)

  5)[node2vec: Scalable Feature Learning for Networks](http://arxiv.org/abs/1607.00653)
    Code and Dataset at -> http://snap.stanford.edu/node2vec/

## III. MORE

  1)[Pointer Networks](https://arxiv.org/pdf/1506.03134v2.pdf)
  
  2)[Neural Summarization by Extracting Sentences and Words](https://arxiv.org/pdf/1603.07252v3.pdf)
  
  3)[Towards Coherent Multi-Document Summarization](http://knowitall.cs.washington.edu/gflow/publications/christensen_naacl13.pdf)

  4)[Hierarchical Summarization: Scaling Up Multi-Document Summarization](http://homes.cs.washington.edu/~janara/publications/christensen_acl14.pdf)

  5)[DivRank: the interplay of prestige and diversity in information networks](http://dl.acm.org/citation.cfm?doid=1835804.1835931)

  6)[A Repository of State of the Art and Competitive Baseline Summaries for Generic News Summarization](http://www.lrec-conf.org/proceedings/lrec2014/pdf/1093_Paper.pdf)
  -> [See actual Summaries](http://www.cis.upenn.edu/~nlp/corpora/sumrepo.html)
  
  7)[Extractive Summarization by Maximizing Semantic Volume](http://www.aclweb.org/anthology/D15-1228)
  

## tangra directory: /data/projects/mds


# DUC 2004 Dataset
-------------------

## Documents for summarization

### 50 TDT English document clusters (for tasks 1 & 2)
**Documents/clusters:** NIST staff chose 50 TDT topics/events/timespans and a subset of the documents TDT annotators found for each topic/event/timespan. Each subset contained on average 10 documents.

The documents came from the AP newswire and New York Times newswire.

**Manual summaries:** NIST assessors created a very short summary (<= 75 bytes, no specific format other than linear) of each document and a short summary (<= 665 bytes) of each cluster. These summaries were not be focused in any particular way beyond by the documents. The manual summarizers were NOT given the TDT topic. Here are the summarization instructions the NIST summarizers were given.

### 25 TDT Arabic document clusters (for tasks 3 & 4)
**Documents/clusters:** The above 50 TDT topics were chosen so that 13 of them also have relevant documents in an Arabic source. These were supplemented with 12 new topics in the same style. We used these 25 topics and a subset of the documents TDT annotators found for each topic/event/timespan. Each subset contained on average 10 documents.

For each cluster we also attempted to provide documents that came from the TDT English sources and were relevant to the topic. The numbers of such documents varied by topic. For 13 of the topics there were some relevant documents from English sources; for the others we used however many were found after a fixed amount of searching; in some cases none may have been found. To the extent possible, the English documents came from dates the same or close to those for the Arabic documents.

The Arabic documents came from the Agence France Press (AFP) Arabic Newswire (1998, 2000-2001). They were translated to English by two fully automatic machine translation (MT) systems.

=> IBM and ISI provided five example translations from two such MT systems to give an idea of the quality of the English output.

Summarizers created a very short summary (~10 words, no specific format other than linear) of each document and a short summary (~ 100 words) of each cluster in English. In both cases the summarizer worked from professional translations to English of the original Arabic document(s). Here are the [summarization instructions](http://duc.nist.gov/duc2004/t3.4.summarization.instructions) the LDC summarizers were given. (The instructions pre-date the determination of the size limits in bytes, that's why the limits are in terms of words.) These summaries were not focused in any particular way beyond by the documents.
For one of the test docsets (30047) we did not use for testing, we provided sample test data files: the output of two machine translation systems, the manual translations for the document set and for each document, additional English documents relevant to the topic of the docset, and the manual summaries (4 humans' versions) of the manually translated documents. The MT output contains mutiple variants for each sentence, ranked by descending quality. In the actual test data NIST will provide a version containing only the best translation for each sentence. Note that ISI and IBM used independent sentence separation.

### 50 TREC English document clusters (for task 5)

**Documents/clusters:** NIST assessors chose 50 clusters of TREC documents such that all the documents in a given cluster provide at least part of the answer to a broad question the assessor formulated. The question was of the form "Who is X?", where X was the name of a person. Each subset contained on average 10 documents.

The documents came from the following collections with their own taggings:

AP newswire, 1998-2000
New York Times newswire, 1998-2000
Xinhua News Agency (English version), 1996-2000
Here is a DTD.

**Manual summaries:** NIST assessors created a focused short summary (<= 665 bytes) of each cluster, designed to answer the question defined by the assessor. 

Here are the question creation, document selection, and summarization instructions for the NIST document selectors/summarizers. 
 

## Tasks and measures

In what follows, the evaluation of quality and coverage implements the [SEE manual evaluation protocol](http://duc.nist.gov/duc2004/protocol.html).

The discussion group led by Ani Nenkova has produced the following [linguistic questions and answers](http://duc.nist.gov/duc2004/quality.questions.txt), which will be used within the SEE manual evaluation protocol. (Note please that SEE will only be used in task 5 for 2004).

For all tasks, we truncated summaries over the target length (defined in terms of characters, with whitespace and punctuation included) and there will be no bonus for summarizing in less than the target length. We modeled a situation in which an application has a fixed amount of time/space for a summary. Summary material beyond the target length cannot be used and compression to less than the target length underutilizes the available time/space.

For short summaries, overlap in content between a submitted summary and a manual model was defined for the assessors in terms of shared facts.

Because very short summaries may be list of key words, the requirement that they express complete **facts** was relaxed and for very short summaries overlap in content between a submitted summary and a manual model was defined for the assessors in terms of shared **references** to entities such as people, things, places, events, etc.

The TDT topics themselves were not input either to the manual summarizers or the automatic summarization systems

NIST created some simple automatic (baseline) summaries to be included in the evaluation along with the other submissions. [Definitions of the baselines](http://duc.nist.gov/duc2004/baseline_definitions) are available.

Each group could submit up to 3 prioritized runs/results for each task.

### Task 1 - Very short single-document summaries
Use the 50 TDT English clusters. Given each document, create a **very short summary** (<= 75 bytes) of the document.

Summaries over the size limit will be truncated; no bonus for creating a shorter summary . No specific format other than linear is required.

Submitted summaries will be evaluated solely using ROUGE n-gram matching.

### Task 2 - Short multi-document summaries focused by TDT events
Use the 50 TDT English clusters. Given each document cluster, create a **short summary** (<= 665 bytes) of the cluster.

Summaries over the size limit will be truncated; no bonus for creating a shorter summary. Note that the TDT topic will NOT be input to the system.

Submitted summaries will be evaluated solely using ROUGE n-gram matching.

### Task 3 - Very short cross-lingual single-document summaries
Two required runs and one optional one per group:

Required: (Priority=1) Given one or more automatic English translations of each document in the 25 TDT clusters, create a **very short summary** (<= 75 bytes) of the document in English. No other English documents can be used.
Required: (Priority=2) Given a manual English translation of each document in the 25 TDT clusters, create a **very short summary** (<= 75 bytes) of the document in English. No other English documents can be used.
Optional: (Priority=3) A run using the MT output and any other documents from English sources,e.g., relevant documents for these 25 clusters provided by NIST.
Summaries over the size limit will be truncated; no bonus for creating a shorter summary. No specific format other than linear is required.

Submitted summaries will be evaluated solely using ROUGE n-gram matching.

### Task 4 - Short cross-lingual multi-document summaries focused by TDT events
Two required runs and one optional one per group:

Required: (Priority=1) Given one or more automatic English translations of each of the documents in the 25 TDT document clusters, create a **short summary** (<= 665 bytes) of the cluster in English. No other English documents can be used.
Required: (Priority=2) Given a manual English translation of each document in the 25 TDT clusters, create a **short summary** (<= 665 bytes) of the cluster in English. No other English documents can be used.
Optional: (Priority=3) A run using the MT output and any other documents from English sources,e.g., relevant documents for these 25 clusters provided by NIST.
Summaries over the size limit will be truncated; no bonus for creating a shorter summary.

Submitted summaries will be evaluated solely using ROUGE n-gram matching.

## Task 5 - Short summaries focused by questions
Use the 50 TREC clusters. Given each document cluster and a question of the form "Who is X?", where X is the name of a person or group of people, create a **short summary** (<= 665 bytes) of the cluster that responds to the question.

Summaries over the size limit will be truncated; no bonus for creating a shorter summary.

The summary should be focused by the given natural language question (stated in a sentence).

NIST will evaluate the summaries intrinsically (SEE) for **quality** and **coverage**. Here are the [instructions](http://duc.nist.gov/duc2004/abstract.assessment.instructions) to the assessors for using SEE. In addition, NIST will evaluate each summary for its **"responsiveness"** to the question. Here are the [instructions](http://duc.nist.gov/duc2004/responsiveness.assessment.instructions) to the assessors for judging relative responsiveness. 









## Tool Information:
-----------------

ROUGE depends on the XML::DOM perl module. On Ubuntu, install it using 

```bash
sudo apt-get install libxml-dom-perl
```

