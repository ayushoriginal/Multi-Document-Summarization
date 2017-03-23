#include <unistd.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <ctype.h>
#include <errno.h>

#undef NDEBUG /* Don't allow assertions to be turned off. */
#include <assert.h>

#include <set>
#include <algorithm>
#include <string>
#include <vector>

#include "prmain.h"

/*** Parameters */


static int nthreads; /* Number of worker threads */


/*** Command-line arguments (used in this file only) ***/
double follow_p;
double jump_p = 0;

const char *resultfile;
const char *linkfile;
const char *biasfile = NULL;

double errorb;
FILE *proglog;
int debug;
unsigned int N, Nt;
int minid, maxid;

std::vector<node_info_t> graph_nodes;

FLOAT * biases;
FLOAT * old_pr;
FLOAT * new_pr;


/*** Local functions */

/* Process command-line arguments.  Sets variables listed in
   "Parameters" section. */
static void process_args(int argc, char **argv);

/* Passed to "process_pages" to fill in "outp".  Assumes
   "outp" and random_jump have been allocated. */
static void compute_outp(int lo, int hi);

static void record_result(FLOAT* result);

/*** Main function */

int main(int argc, char **argv) {
    int i;
    FLOAT *result;
    time_t start, end;

    minid = 0;
    process_args(argc, argv);

    if (jump_p == 0) jump_p = 0.15;
    follow_p = 1.0 - jump_p;

//    maxid = 0;
    N = 1 + (maxid - minid);

    assert((biases = (FLOAT *)calloc((maxid+1) , sizeof(FLOAT))) != NULL);
    assert((old_pr = (FLOAT *)malloc((maxid+1) * sizeof(FLOAT))) != NULL);
    assert((new_pr = (FLOAT *)malloc((maxid+1) * sizeof(FLOAT))) != NULL);

    struct node_info anode;
    anode.out_random = 0;
    graph_nodes.insert(graph_nodes.end(), maxid+1, anode);

    FILE* linkfp = fopen(linkfile, "r");
    //read all links
    int srcid, dstid;
    FLOAT edgeweight;
    while( (fscanf(linkfp, "%d\t%d\t%f\n", &srcid, &dstid, &edgeweight)) != EOF){
      if (edgeweight <= 0) continue;
      graph_nodes[dstid].inlinks.insert(graph_nodes[dstid].inlinks.end(), srcid);
      graph_nodes[dstid].inweights.insert(graph_nodes[dstid].inweights.end(), edgeweight);
      graph_nodes[srcid].out_random += edgeweight;
    }

    fclose(linkfp);

    //read the node biases for random jump
    if (biasfile != NULL) {
      FILE* biasfp = fopen(biasfile, "r");
      int srcid;
      FLOAT bias;
      double total_bias = 0;
      while( (fscanf(biasfp, "%d\t%f\n", &srcid, &bias)) != EOF) {
        biases[srcid] = bias;
        total_bias += bias;
      }
      fclose (biasfp);
      // now normalize the biases
      for (int i=minid; i <= maxid; i++) {
           biases[i] /= total_bias;
      }
      printf ("total:.......... %f\n", total_bias);
    }
    //there is no bias file, so jump uniformly
    else {
      double initial_prob = 1.0 / (N + .0);
      for (int i=0; i < minid; i++) {
        biases[i] = 0;
      }
      for (int i=minid; i <= maxid; i++) {
        biases[i] = initial_prob;
      }
    }

    fprintf(proglog, "Computing outp");
    start = time(NULL);
    compute_outp(minid, maxid);
    end = time(NULL);
    fprintf(proglog, " time = %ds (outp)\n", (int)(end-start));
    
    result = doit();
    record_result(result);
    if (result) free(result);
    
    free(biases);
}

static void record_result(FLOAT* result){
  FILE* resultfp = fopen(resultfile, "w");
  for(int id = minid; id <= maxid; id++){
    FLOAT f = result[id];
//    fwrite(&f, sizeof(FLOAT), 1, resultfp);
    fprintf(resultfp, "%d\t%.10f\n", id, f);
    
  }
  fclose(resultfp);
}

/*
 * This method is used to compute outp and random_jump components.
 * Both arrays are written w/out any synchronization.
 * Note that we don't care about the final update to <denp>.
 *
 * Calculations are carried out in FLOAT. The accuracy is not a real issue
 * here (one-time computation).
 */
static void compute_outp(int lo, int hi) 
{
    int i, helpdeg;
    FLOAT *f;

    for (i = lo; i <= hi; i++) {
      /* Print progress indication */
      if ((i % 10000000) == 0) fputc('.', proglog);
      
      std::vector<float>::iterator itr1;
      std::vector<int>::iterator itr2;

      for (itr1 = graph_nodes[i].inweights.begin(), itr2 = graph_nodes[i].inlinks.begin(); itr1 !=  graph_nodes[i].inweights.end(); itr1++, itr2++) {
          *itr1 *= follow_p / graph_nodes[*itr2].out_random;
      }

    }   /* end of loop from lo to hi */

    for (i = lo; i <= hi; i++) {
      f = &(graph_nodes[i].out_random);
      if(*f > 0){
	/* assign probabilities */
	*f = jump_p;
      }
      else {
	/* assign probabilities */
	*f = (FLOAT)1.0;
      }
    } /* end for */
}

static int atonat(const char *arg) {
    const char *p = arg;
    while (*p != '\0' && isdigit(*p++)) ;
    if (*p != '\0' || 10 < p - arg) return -1;
    return atoi(arg);
}

void process_args(int argc, char **argv) {
    int argi, i;

    errorb = ERRORB;
    proglog = stderr;
    debug = 0;

    /* Process optional arguments. */
    for (argi = 1; argi < argc; ) {
      if (strcmp(argv[argi], "-help") == 0) goto usage;
      else if (strcmp(argv[argi], "-debug") == 0) {
	debug = 1;
	argi += 1;
      } else if (strcmp(argv[argi], "-out") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((resultfile = strdup(argv[argi+1])) != NULL);
	argi += 2;
      } else if (strcmp(argv[argi], "-jump") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((jump_p = atof(argv[argi+1])) != 0);
	argi += 2;
      } else if (strcmp(argv[argi], "-maxid") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((maxid = atoi(argv[argi+1])) != 0);
	argi += 2;
      } else if (strcmp(argv[argi], "-minid") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((minid = atoi(argv[argi+1])) != 0);
	argi += 2;
      } else if (strcmp(argv[argi], "-link") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((linkfile = strdup(argv[argi+1])) != NULL);
	argi += 2;
      } else if (strcmp(argv[argi], "-bias") == 0) {
	if (argc <= argi + 1) goto usage;
	assert((biasfile = strdup(argv[argi+1])) != NULL);
	argi += 2;
      } else goto usage;
    }
    
    /* Make sure output resultfile has been provided */
    if (resultfile != NULL) {
        assert((resultfile = strdup(resultfile)) != NULL);
    } else {
		fprintf(stderr, "%s: -out option is required\n",argv[0]);
		goto usage;
    }

    /* Make sure graph file has been provided */
    if (linkfile != NULL) {
        assert((linkfile = strdup(linkfile)) != NULL);
    } else {
		fprintf(stderr, "%s: -link option is required\n",argv[0]);
		goto usage;
    }

    return;

  usage:
    fprintf(stderr, "Usage: %s -link link_file -out output_file [-jump jump_prob] [-bias bias_file] [-debug] [-maxid max_id] [-minid min_id]\n",
	    argv[0]);
    exit(1);
}
