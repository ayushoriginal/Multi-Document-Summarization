#ifndef __PRMAIN_DIS_H__
#define __PRMAIN_DIS_H__

#include <stdio.h>
#include <vector>

#ifndef FLOAT
#define FLOAT float
#endif

/**** Constants */

/* Size of stack-allocated buffer used to store in and out lists */
#define ID_BUF_SIZE (131072)

/* 
 * For a specific page with <nsame> internal links and 
 *                          <ndiff = ndiff_ned + ndiff_ed> external links, 
 * we will set the probabilities as follows:
 * 
 * first, we limit the probability of following internal links:
 *   max_fsame_p = MAX_FOLLOW_SAMEHOST * 
 *                 min(nsame, FULLCOUNT_SAMEHOST)/FULLCOUNT_SAMEHOST
 * 
 * (so if the number of same-host links is small, their overall probability
 *  will be less than the max. allowed)
 *
 * We now calculate the following value:
 *
 *   fdiff_p = (1.0 - MIN_RAND_JUMP - max_fsame_p) * 
 *             min(ndiff, FULLCOUNT_DIFFHOST)/FULLCOUNT_DIFFHOST
 *
 * The jump probability is now set to 1.0 - (fdiff_p + max_fsame_p). Hence,
 * a small number of external links will cause more random jumps.
 *
 * We now need to distribute the non-random probabilities among the links.
 * We initialize the probability of every internal link to 
 * max_fsame_p / nsame, and initialize accordingly the probabilities of 
 * external links according to the ratios DIFF_?ED_TO_SAMEHOST_RATIO.     
 *
 * We check if ndiff_ed*p_ed + ndiff_ned*p_ned > fdiff_p.
 *    if so, we scale down all three probabilities (keeping the ratios intact)
 *    nsame*psame + ndiff_ed*p_ed + ndiff_ned*p_ned = fdiff_p + max_fsame_p.
 *    Effectively, this limits even more the total probability of remaining in
 *    the same host.
 * Whenever ndiff_ed*p_ed + ndiff_ned*p_ned < fdiff_p, we scale up the 
 * probabilities p_ed and p_ned to pick up the slack. Effectively, this gives 
 * external links higher ratios than are specified by the constants.
 */

#define ERRORB 0.000001 /* Default desired error bound */


/**** Global variables */

/** Variables from command-line arguments */

/* Value given to "-out" flag; "NULL" if that flag not given. */
extern const char *resultfile;

/* Bound on acceptable error (stop iterating when error is less than this */
extern double errorb;

extern int text; /* True iff -text flag is given by user. */

extern FILE *proglog; /* File to send progress information.  Usually either
			 stderr or /dev/null depending on -silent. */

extern int debug; /* True iff -debug flag is given by user. */

extern int rev_pr_flag; /* True iff user wants to run reverse PR. Defalut= false*/
 
extern double mrj_topic_fraction;

/** Other globals */

extern unsigned int N, Nt; /* Total number nodes */
extern int minid, maxid; /* Conveniences for conn_min/maxid(cdb) */

extern pthread_mutex_t *mu; /* For general use */

typedef struct node_info{
  std::vector<int> inlinks;
  std::vector<float> inweights;
  float out_random;
}node_info_t;

extern std::vector<node_info_t> graph_nodes;
/* 
 *probability of random jump from each page. Separated from the above
 * probabilities because of caching reasons.
 */

extern FLOAT* biases;
extern FLOAT* old_pr;
extern FLOAT* new_pr;

/**** Functions */

/* The "main" function in "ermain.c" calls this function after
   initializing the above variables.  "doit" may call "process_nodes"
   to process pages in parallel.  "doit" is expected to return an
   array "res" of "FLOAT" values of size "maxid+1" elements in which, for
   "minid <= i <= maxid", "res[i]" contains the score for page "i".  This
   array should be heap allocated so it can be freed with "free".  If,
   for some reason, a result could not be computed, returns "NULL".
   "doit" should print progress information to "proglog" */
extern FLOAT *doit(void);

/* Starts "nthreads" worker threads, all of which call "fn".  Each
   call to "fn" is given a low and high page identifier specifying the
   range of nodes they are supposed to process (inclusive).  "fn" may
   use "mu" to synchronize across threads (but of course must leave
   "mu" unlocked when it exists).  Again, new threads are created on
   each call to "process_pages", so, on startup, the caches of these
   threads should be coherent with the calling thread's cache.

   Usually, "process_pages" waits for the worker threads to finish and
   then returns "0".  However, if SIGQUIT is received during the call,
   then "process_pages" will return "1" immediately.  Note
   that, even when "1" is returned, the worker threads will continue
   until they finish (they aren't cancelled).  Also, when "1" is
   returned, "process_pages" should not be called again. */
extern int process_pages(void (*fn)(int lo, int hi));


#endif  /* __PRMAIN_DIS_H__ */

