import numpy
import theano
import sys
import cPickle as pkl

def prepare_data(clusters, labels, nodes, maxlen=None):
    num_cluster = len(clusters)
    node_emb_dim = len(nodes[0][0][0])

    cluster_lengths = [len(c) for c in clusters]   # cluster lengths in terms of #docs
    max_l_cluster_docs = max(cluster_lengths)

    doc_lengths = []    # document lengths in #sents
    for c in clusters:
        doc_l = [1] * max_l_cluster_docs
        doc_l[:len(c)] = [len(doc) for doc in c]
        doc_lengths += doc_l
    max_l_doc_sents = max(doc_lengths)
    max_l_doc_sents += 1   # add terminal signal for each doc

    sent_lengths = [] # sentence lengths in #words
    for c in clusters:
        for doc in c:
            sent_l = [1] * max_l_doc_sents
            sent_l[1:1+len(doc)] = [len(s) for s in doc]   # terminal signal at the first position
            sent_lengths += sent_l

    n_sents = len(sent_lengths)
    if maxlen is None:
        maxlen = max(sent_lengths)  # maxlen is dynamically determined by each minibatch

    #TODO: what is label

    label_lengths = []
    max_labellen = 0
    for c_l in labels:
        label_l = [1] * max_l_cluster_docs
        label_l[:len(c_l)] = [len(l) for l in c_l]
        label_lengths += label_l
        max_labellen = max(max_labellen,sum([len(l) for l in c_l]))
    max_labellen += 1               # add 1 for terminal signal

    '''
    print 'Number of cluster:', num_cluster
    print 'Cluster Lengths:', cluster_lengths
    print 'doc_lengths', doc_lengths
    print 'sent_lengths', sent_lengths
    print 'label_lengths', label_lengths
    print 'maxlen', maxlen, max_l_doc_sents,max_l_cluster_docs,num_cluster,max_labellen
    print
    print
    '''

    #encoder input
    x_node      = numpy.zeros((node_emb_dim, max_l_doc_sents, max_l_cluster_docs, num_cluster)).astype(theano.config.floatX)
    x           = numpy.zeros((maxlen, max_l_doc_sents, max_l_cluster_docs, num_cluster)).astype('int64')
    x_mask_word = numpy.zeros((maxlen, max_l_doc_sents, max_l_cluster_docs, num_cluster)).astype(theano.config.floatX)
    x_mask_sent = numpy.zeros((        max_l_doc_sents, max_l_cluster_docs, num_cluster)).astype(theano.config.floatX)
    x_mask_doc  = numpy.zeros((                         max_l_cluster_docs, num_cluster)).astype(theano.config.floatX)

    # TODO: what is decoder input/output

    #decoder input
    dec_inp      = numpy.zeros((max_labellen, num_cluster)).astype('int64')
    dec_inp_mask = numpy.zeros((max_labellen, num_cluster)).astype(theano.config.floatX)

    #decoder output
    dec_out      = numpy.zeros((max_labellen, num_cluster)).astype('int64')
    dec_out_mask = numpy.zeros((max_labellen, num_cluster)).astype(theano.config.floatX)

    #TODO: how to add terminal signal

    for i in range(num_cluster):
        cluster_i = clusters[i]
        num_doc = len(cluster_i)
        x_mask_doc[:num_doc,i] = 1.

        #print 'num_doc', num_doc

        for j in range(num_doc):
            doc_j = cluster_i[j]
            num_sent = len(doc_j)

            #x_mask_sent[:num_sent,j,i] = 1.
            x_mask_sent[1:1+num_sent,j,i] = 1. # terminal signal at the first position

            #print '\tnum_sent', num_sent
            for k in range(num_sent):
                sent_k = doc_j[k]
                num_word = len(sent_k)
                x_mask_word[:num_word,k+1,j,i] = 1. # k shift by 1 because of terminal signal

                #print '\t\tnum_word', num_word

                s_len = min(maxlen, num_word)
                x[:s_len,k+1,j,i] = sent_k[:s_len] # k shift by 1 because of terminal signal
                x_node[:,k+1,j,i] = nodes[i][j][k][:]

    for i in range(num_cluster):
        c_l = labels[i]
        num_doc = len(c_l)
        start_idx = 1
        for j in range(num_doc):
            d_l = c_l[j]

            d_l = [l+j*max_l_doc_sents for l in d_l]

            dec_inp[start_idx:start_idx+len(d_l),i] = d_l
            dec_inp_mask[start_idx:start_idx+len(d_l),i] = 1.

            dec_out[start_idx-1:start_idx-1+len(d_l),i] = d_l
            dec_out_mask[start_idx-1:start_idx-1+len(d_l),i] = 1.

            start_idx += len(d_l)
        dec_out_mask[start_idx-1,i] = 1. # need to predict the final terminal signal

    return x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask

'''
def get_idx_from_sent(sent,word_idx_map):
    x = []
    words = sent.split()
    for word in words:
        if word in word_idx_map:
            x.append(word_idx_map[word])
    return x
'''

def label2label_idx(labels):
    #print labels
    #print 'here'
    label_idx = []
    for i,l in enumerate(labels):
        if l == 1: # 1 means the sentence should be extracted
            label_idx.append(i+1) # 1-indexed since we have terminate signal
    return label_idx


def load_data(path='./preprocess/duc04multi.pkl',sort_by_len=False):

    clusters, word_idx_map, vocab = pkl.load(open(path,'rb'))
    train_clusters, valid_clusters, test_clusters = clusters

    max_l_cluster_docs = 0   # max cluster len in terms of #docs
    max_l_doc_sents = 0      # max doc len in terms of #sents
    max_l_sent_words = 0     # max sent len in terms of #words

    train_set_x = []
    train_set_y = []
    train_f = []
    train_node2vec = [] #ADDED'''
    for cluster in train_clusters:
        max_l_cluster_docs = max(max_l_cluster_docs, len(cluster))
        cluster_x = []
        cluster_y = []
        cluster_f = []
        cluster_node2vec = [] #ADDED'''
        for doc in cluster:
            sent = doc['sent']
            node_vec_list = doc['node2vec'] #ADDED'''
            max_l_doc_sents = max(max_l_doc_sents, len(sent))
            max_l_sent_words = max(max_l_sent_words,max([len(sub) for sub in sent]))
            cluster_x.append(sent)
            cluster_node2vec.append(node_vec_list) #ADDED'''
            cluster_y.append(label2label_idx(doc["y"])) #TODO what should be the label here
            cluster_f.append(doc['cluster']+'/'+doc['file'])
        train_set_x.append(cluster_x)
        train_set_y.append(cluster_y)
        train_f.append(cluster_f)
        train_node2vec.append(cluster_node2vec) #ADDED'''

    valid_set_x = []
    valid_set_y = []
    valid_f = []
    valid_node2vec = [] #ADDED'''
    for cluster in valid_clusters:
        max_l_cluster_docs = max(max_l_cluster_docs, len(cluster))
        cluster_x = []
        cluster_y = []
        cluster_f = []
        cluster_node2vec = [] #ADDED'''
        for doc in cluster:
            sent = doc['sent']
            node_vec_list = doc['node2vec'] #ADDED'''
            max_l_doc_sents = max(max_l_doc_sents, len(sent))
            max_l_sent_words = max(max_l_sent_words,max([len(sub) for sub in sent]))
            cluster_x.append(sent)
            cluster_node2vec.append(node_vec_list) #ADDED'''
            cluster_y.append(label2label_idx(doc["y"])) #TODO what should be the label here
            cluster_f.append(doc['cluster']+'/'+doc['file'])
        valid_set_x.append(cluster_x)
        valid_set_y.append(cluster_y)
        valid_f.append(cluster_f)
        valid_node2vec.append(cluster_node2vec) #ADDED'''


    test_set_x = []
    test_set_y = []
    test_f = []
    test_node2vec = [] #ADDED'''
    for cluster in test_clusters:
        max_l_cluster_docs = max(max_l_cluster_docs, len(cluster))
        cluster_x = []
        cluster_y = []
        cluster_f = []
        cluster_node2vec = [] #ADDED'''
        for doc in cluster:
            sent = doc['sent']
            node_vec_list = doc['node2vec'] #ADDED'''
            max_l_doc_sents = max(max_l_doc_sents, len(sent))
            max_l_sent_words = max(max_l_sent_words,max([len(sub) for sub in sent]))
            cluster_x.append(sent)
            cluster_node2vec.append(node_vec_list) #ADDED'''
            cluster_y.append(label2label_idx(doc["y"])) #TODO what should be the label here
            cluster_f.append(doc['cluster']+'/'+doc['file'])
        test_set_x.append(cluster_x)
        test_set_y.append(cluster_y)
        test_f.append(cluster_f)
        test_node2vec.append(cluster_node2vec) #ADDED'''


    print max_l_cluster_docs,max_l_doc_sents,max_l_sent_words
    print 'Original Fold:','Train',len(train_set_x), 'Valid',len(valid_set_x), 'Test', len(test_set_x)

    def len_argsort(seq):
        return sorted(range(len(seq)), key = lambda x: len(seq[x]))

    if sort_by_len:
        sorted_index = len_argsort(train_set_x)
        train_set_x = [train_set_x[i] for i in sorted_index]
        train_set_y = [train_set_y[i] for i in sorted_index]
        train_f = [train_f[i] for i in sorted_index]
        train_node2vec = [train_node2vec[i] for i in sorted_index]

        sorted_index = len_argsort(valid_set_x)
        valid_set_x = [valid_set_x[i] for i in sorted_index]
        valid_set_y = [valid_set_y[i] for i in sorted_index]
        valid_f = [valid_f[i] for i in sorted_index]
        valid_node2vec = [valid_node2vec[i] for i in sorted_index]

        sorted_index = len_argsort(test_set_x)
        test_set_x = [test_set_x[i] for i in sorted_index]
        test_set_y = [test_set_y[i] for i in sorted_index]
        test_f = [test_f[i] for i in sorted_index]
        test_node2vec = [test_node2vec[i] for i in sorted_index]

    train = (train_set_x, train_set_y, train_f, train_node2vec)
    valid = (valid_set_x,valid_set_y, valid_f, valid_node2vec)
    test = (test_set_x, test_set_y, test_f, test_node2vec)

    return train,valid,test,word_idx_map


# greedy search (beam_width == 1)
def gen_summ_refine(x_node,x, x_mask_word, x_mask_sent, f_encode, f_probi, options):
    n_sents    = x_mask_sent.shape[0]
    n_docs     = x_mask_sent.shape[1]
    n_clusters = x_mask_sent.shape[2]

    hiddens_mask = numpy.copy(x_mask_sent)
    #hiddens_mask[0,:,:] = 1.

    # TODO: x_mask_l should indicate the maximum decoding length for each cluster with the first to be 0 and 1 * maximum_decoding_length
    decode_length = x_mask_sent.reshape([-1,n_clusters]).sum(axis=0).astype(int)
    max_decode_length = 1 + numpy.max(decode_length)
    x_mask_l = numpy.zeros((max_decode_length,n_clusters)).astype(theano.config.floatX)
    #print 'here', decode_length
    for i in range(n_clusters):
        max_i = decode_length[i]
        x_mask_l[1:1+max_i,i] = 1.

    n_sizes    = x_mask_l.shape[0]
    n_samples  = x_mask_l.shape[1]

    def find_max_no_repeat(probi,points,n_sents):
        xi = numpy.zeros((n_samples,), dtype='int64')

        # sort the sentence index
        xi_sort = probi.argsort(axis=0)
        # in descending order
        xi_sort = numpy.flipud(xi_sort)

        for i in range(n_samples):
            for s_idx,s in enumerate(xi_sort[:,i]):
                prob_s_idx = probi[s,i]
                #if s % n_sents == 0.:
                if prob_s_idx == 0.:
                    assert sum(probi[xi_sort[:,i][s_idx:],i]) == 0.
                    xi[i] = 0
                    break
                if s not in points[i,:]:
                    xi[i] = s
                    break

        return xi

    proj_sent, proj_doc = f_encode(x_node,x, x_mask_word, x_mask_sent)
    hprev = proj_sent

    points = numpy.zeros((n_samples, n_sizes), dtype='int64')
    h = proj_doc.mean(axis=0)
    c = numpy.zeros((n_samples, options['dim_proj']), dtype=theano.config.floatX)

    xi = numpy.zeros((n_samples,), dtype='int64')
    xi_mask = numpy.ones((n_samples,), dtype=theano.config.floatX)

    #print n_sents, n_docs, n_clusters

    for i in range(n_sizes):
        h, c, probi = f_probi(x_mask_l[i], xi, h, c, hprev, x_mask_sent)

        '''
        n_sents    = probi.shape[0]
        n_docs     = probi.shape[1]
        n_clusters = probi.shape[2]
        '''

        probi = probi * hiddens_mask
        probi = probi.transpose((1,0,2)).reshape([n_sents * n_docs, n_clusters])
        for j in range(n_clusters):
            for k in range(n_docs):
                assert probi[k*n_sents,j] == 0.
        xi = find_max_no_repeat(probi,points,n_sents)

        xi *= xi_mask.astype(numpy.int64)  # Avoid compatibility problem in numpy 1.10
        xi_mask = (numpy.not_equal(xi, 0)).astype(theano.config.floatX)
        if numpy.equal(xi_mask, 0).all() or i>10:
            break
        points[:, i] = xi
    return points


def gen_summ(x_node,x, x_mask_word, x_mask_sent, f_encode, f_probi, options):
    n_sents    = x_mask_sent.shape[0]
    n_docs     = x_mask_sent.shape[1]
    n_clusters = x_mask_sent.shape[2]

    hiddens_mask = numpy.copy(x_mask_sent)
    hiddens_mask[0,:,:] = 1.

    # TODO: x_mask_l should indicate the maximum decoding length for each cluster with the first to be 0 and 1 * maximum_decoding_length
    decode_length = x_mask_sent.reshape([-1,n_clusters]).sum(axis=0).astype(int)
    max_decode_length = 1 + numpy.max(decode_length)
    x_mask_l = numpy.zeros((max_decode_length,n_clusters)).astype(theano.config.floatX)
    #print 'here', decode_length
    for i in range(n_clusters):
        max_i = decode_length[i]
        x_mask_l[1:1+max_i,i] = 1.

    n_sizes    = x_mask_l.shape[0]
    n_samples  = x_mask_l.shape[1]

    def find_max_no_repeat(probi,points,n_sents):
        xi = numpy.zeros((n_samples,), dtype='int64')

        # sort the sentence index
        xi_sort = probi.argsort(axis=0)
        # in descending order
        xi_sort = numpy.flipud(xi_sort)

        for i in range(n_samples):
            for s in xi_sort[:,i]:
                if s == 0 or s not in points[i,:]:
                    xi[i] = s
                    break
        return xi

    proj_sent, proj_doc = f_encode(x_node,x, x_mask_word, x_mask_sent)
    hprev = proj_sent

    points = numpy.zeros((n_samples, n_sizes), dtype='int64')
    h = proj_doc.mean(axis=0)
    c = numpy.zeros((n_samples, options['dim_proj']), dtype=theano.config.floatX)

    xi = numpy.zeros((n_samples,), dtype='int64')
    xi_mask = numpy.ones((n_samples,), dtype=theano.config.floatX)

    for i in range(n_sizes):
        h, c, probi = f_probi(x_mask_l[i], xi, h, c, hprev, x_mask_sent)

        '''
        n_sents    = probi.shape[0]
        n_docs     = probi.shape[1]
        n_clusters = probi.shape[2]
        '''

        probi = probi * hiddens_mask
        probi = probi.transpose((1,0,2)).reshape([n_sents * n_docs, n_clusters])
        xi = find_max_no_repeat(probi,points,n_sents)

        xi *= xi_mask.astype(numpy.int64)  # Avoid compatibility problem in numpy 1.10
        xi_mask = (numpy.not_equal(xi, 0)).astype(theano.config.floatX)
        if numpy.equal(xi_mask, 0).all():
            break
        points[:, i] = xi
    return points

def compare_summ(points, n_sents, n_docs, dec_out, dec_out_mask, files=None, write_file=None):
    precision = 0.
    recall = 0.
    n_samples = points.shape[0]
    n_sizes = points.shape[1]
    assert len(files) == n_samples

    '''
    def match(answer,predict):
        flag = True
        for i in range(len(answer)):
            if predict[i] != answer[i]:
                flag = False
                break
        return flag
    '''
    def doc_sent_idx(p,n_sents,n_docs):
        doc_id =  int(p/n_sents) + 1
        sent_id =  p % n_sents
        #print p, n_sents
        return (doc_id,sent_id)

    def precision_recall(answer,predict):
        ans =  set(answer)
        if 0 in ans:
            ans.remove(0)
        pred = set(predict)
        if 0 in pred:
            pred.remove(0)
        overlap = set.intersection(ans, pred)

        precision = len(overlap) / float(max(1,len(pred)))
        recall = len(overlap) / float(max(1,len(ans)))

        return precision, recall

    for i in range(n_samples):
        #print len(points[i,:])
        #print points[i,:]
        #print len(dec_out[:,i])
        #print dec_out[:,i]
        answer = dec_out[:,i]
        predict = points[i,:]
        #ismatch = match(answer,predict)
        p,r = precision_recall(answer,predict)
        precision += p
        recall += r
        #print answer
        #print predict
        if write_file:
            with open(write_file,'a') as f:
                f.write(' '.join(files[i]) + '\n')
                f.write(' '.join(['%d/%d' % doc_sent_idx(p,n_sents,n_docs) for p in answer if p != 0]) + '\n')
                f.write(' '.join(['%d/%d' % doc_sent_idx(p,n_sents,n_docs) for p in predict if p != 0]) + '\n\n')

    return precision, recall

def duc_multi_eva(f_encode, f_probi, prepare_data, data, iterator, options, write_file=None):
    total = 0
    precision = 0.
    recall = 0.
    for _, valid_index in iterator:
        # get data
        clusters   = [data[0][t] for t in valid_index]
        labels = [data[1][t] for t in valid_index]
        files  = [data[2][t] for t in valid_index]
        nodes = [data[3][t] for t in valid_index]
        x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask = prepare_data(clusters, labels,nodes)

        n_sents    = x_mask_sent.shape[0]
        n_docs     = x_mask_sent.shape[1]
        n_clusters = x_mask_sent.shape[2]

        # produce summary
        #points = gen_summ(x, x_mask_word, x_mask_sent, f_encode, f_probi, options)
        points = gen_summ_refine(x_node,x, x_mask_word, x_mask_sent, f_encode, f_probi, options)

        # update stats for accuracy
        total += n_clusters
        p,r = compare_summ(points, n_sents, n_docs, dec_out, dec_out_mask, files, write_file)
        precision += p
        recall += r

    total = max(1,total)
    return precision / total, recall / total

def duc_multi_eval_cost(f_cost, prepare_data, data, iterator, options):
    cost = 0.
    total = 0
    for _, valid_index in iterator:
        # get data
        clusters = [data[0][t] for t in valid_index]
        labels   = [data[1][t] for t in valid_index]
        nodes = [data[3][t] for t in valid_index]
        x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask = prepare_data(clusters, labels,nodes)

        num_cluster = x_mask_sent.shape[2]
        total += num_cluster
        cost += num_cluster * f_cost(x_node,x,x_mask_word,x_mask_sent,dec_inp,dec_inp_mask,dec_out,dec_out_mask)

    total = max(1,total)
    cost = cost / total
    return cost
