from collections import OrderedDict
import cPickle as pkl
import sys
import time
import argparse
import pprint

import random
import numpy
import theano
from theano import config
import theano.tensor as tensor
from theano.sandbox.rng_mrg import MRG_RandomStreams as RandomStreams
#from shapely.geometry.polygon import Polygon

from optimizer import *
from utils import *
from layer_multi import *

import dailymail
import multidoc
from dailymail import dailymail_eva, dailymail_eval_cost
from multidoc import duc_multi_eva, duc_multi_eval_cost

datasets = {
    'dailymail': (dailymail.load_data, dailymail.prepare_data),
    'duc02single': (dailymail.load_data, dailymail.prepare_data),
    'duc04multi.concat': (dailymail.load_data, dailymail.prepare_data),
    'ducmulti': (multidoc.load_data, multidoc.prepare_data),
}

# Set the random number generators' seeds for consistency
SEED = 777
numpy.random.seed(SEED)

def get_dataset(name):
    return datasets[name][0], datasets[name][1]

def build_model(tparams, options):
    # for training

    # encoder input
    x_node = tensor.tensor4('x_node', dtype=config.floatX)
    x           = tensor.tensor4('x', dtype='int64')
    x_mask_word = tensor.tensor4('x_mask_word', dtype=config.floatX)
    x_mask_sent = tensor.tensor3('x_mask_sent', dtype=config.floatX)
    x_mask_doc  = tensor.matrix('x_mask_doc', dtype=config.floatX)

    # decoder input
    dec_inp      = tensor.matrix('dec_inp', dtype='int64')
    dec_inp_mask = tensor.matrix('dec_inp_mask', dtype=config.floatX)

    # decoder output
    dec_out      = tensor.matrix('dec_out', dtype='int64')
    dec_out_mask = tensor.matrix('dec_out_mask', dtype=config.floatX)

    #TODO
    # for generation
    hidi = tensor.matrix('hidi', dtype=config.floatX)
    celi = tensor.matrix('celi', dtype=config.floatX)
    hids = tensor.tensor4('hids', dtype=config.floatX)
    xi = tensor.vector('xi', dtype='int64')
    xi_mask = tensor.vector('xi_mask', dtype=config.floatX)

    preds, f_encode, f_decode, f_probi = ptr_network(tparams, x_node,x, x_mask_word, x_mask_sent, x_mask_doc,
                                                     dec_inp, dec_inp_mask,
                                                     xi, xi_mask, hidi, celi, hids, options)

    #cost = None
    #return x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask, preds, cost, f_encode, f_decode, f_probi

    n_steps    = preds.shape[0]
    n_sents    = preds.shape[1]
    n_docs     = preds.shape[2]
    n_clusters = preds.shape[3]

    #preds = preds.reshape([n_steps, n_sents * n_docs, n_clusters])
    preds_contiguous = preds.dimshuffle(0,2,1,3).reshape([n_steps, n_docs * n_sents, n_clusters])

    # pull out the probs of the correct ones
    n_steps = dec_inp.shape[0]
    n_samples = dec_inp.shape[1]
    idx_steps = tensor.outer(tensor.arange(n_steps, dtype='int64'), tensor.ones((n_samples,), dtype='int64'))
    idx_samples = tensor.outer(tensor.ones((n_steps,), dtype='int64'), tensor.arange(n_samples, dtype='int64'))
    # idx_steps, dec_out, idx_samples are all n_steps x n_samples, then probs is also n_steps x n_samples
    #probs = preds[idx_steps, dec_out, idx_samples] # n_steps x n_samples
    probs = preds_contiguous[idx_steps, dec_out, idx_samples] # n_steps x n_samples

    # probs *= y_mask
    off = 1e-8
    if probs.dtype == 'float16':
        off = 1e-6
    # probs += (1 - y_mask)  # change unmasked position to 1, since log(1) = 0
    probs += off
    probs_printed = theano.printing.Print('this is probs')(probs)
    cost = -tensor.log(probs)
    cost *= dec_out_mask
    #TODO: might cause NaN here !
    # This should be okay since in dec_out_mask, we always have at least one 1. for the terminate signal.
    cost = cost.sum(axis=0) / tensor.maximum(1.0, dec_out_mask.sum(axis=0))
    cost = cost.mean()

    return x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask, preds, cost, f_encode, f_decode, f_probi


def train_lstm(
        node_dim=128,
        dim_proj=128,  # LSTM number of hidden units.
        patience=10,  # Number of epoch to wait before early stop if no progress
        max_epochs=5000,  # The maximum number of epoch to run
        dispFreq=10,  # Display to stdout the training progress every N updates
        decay_c=0.,  # Weight decay for the classifier applied to the U weights.
        lrate=0.01,  # Learning rate for sgd (not used for adadelta and rmsprop)
        optimizer=rmsprop,
        saveto='ptr_model.npz',  # The best model will be saved there
        validFreq=370,  # Compute the validation error after this number of update.
        saveFreq=1110,  # Save the parameters after every saveFreq updates
        maxlen=100,  # Sequence longer then this get ignored
        batch_size=16,  # The batch size during training.
        valid_batch_size=64,  # The batch size used for validation/test set.
        dataset='ducmulti',
        # Parameter for extra option
        noise_std=0.,
        use_dropout=False,  # if False slightly faster, but worst test error
        # This frequently need a bigger model.
        reload_model=None,  # Path to a saved model we want to start from.
        datapath='data.pkl.gz',
        mode='train',
        writeto='result',
):
    model_options = locals().copy()
    load_data, prepare_data = get_dataset(dataset)

    print 'Loading data'
    model_options['W'] = None
    train, valid, test, word_idx_map = load_data(path=datapath)

    '''
    train, valid, test, word_idx_map, W = load_data(path=datapath)
    if W is not None:
        model_options['W'] = W
        print W.shape
        print len(word_idx_map)
    else:
        model_options['W'] = None
    '''
    # word_idx_map is 1-indexed inlcuding the unk token, 0 is for the padding

    # Sanity Check
    idx_word_map = {}
    for word in word_idx_map:
        idx = word_idx_map[word]
        idx_word_map[idx] = word

    model_options['data_dim'] = 300
    model_options['n_words'] = len(word_idx_map)
    model_options['node_dim'] = node_dim
    #TODO: load model_options if in test mode?

    pp = pprint.PrettyPrinter()
    pp.pprint(model_options)

    print 'Building model'
    params = init_params(model_options)

    if reload_model:
        print 'Reload from', reload_model
        load_params(reload_model, params)

    tparams = init_tparams(params)

    (x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask, preds, cost, f_encode, f_decode, f_probi) = build_model(tparams,model_options)
    f_cost = theano.function([x_node,x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask, dec_out, dec_out_mask], cost, name='f_cost')

    if mode == 'train':
        grads = tensor.grad(theano.gradient.grad_clip(cost, -2.0, 2.0), wrt=tparams.values())
        f_grad = theano.function([x_node,x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask, dec_out, dec_out_mask], grads, name='f_grad')

        #lr = tensor.scalar(name='lr')
        #f_grad_shared, f_update = optimizer(lr, tparams, grads, x, x_mask, x_mask_l, num_doc, max_llen, dec_inp, dec_inp_mask, dec_out, dec_out_mask, cost)

        all_params = [vv for kk,vv in tparams.iteritems()]
        updates = adam_clip(cost, all_params)
        f_train = theano.function([x_node,x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask, dec_out, dec_out_mask], cost, updates=updates, name='f_train')

    print 'Optimization'

    kf_valid = get_minibatches_idx(len(valid[0]), valid_batch_size)
    kf_test = get_minibatches_idx(len(test[0]), valid_batch_size)

    print "%d train examples" % len(train[0])
    print "%d valid examples" % len(valid[0])
    print "%d test examples" % len(test[0])

    history_err = []
    best_p = None
    bad_counter = 0

    if validFreq == -1:
        validFreq = len(train[0]) / batch_size
    if saveFreq == -1:
        saveFreq = len(train[0]) / batch_size

    uidx = 0  # the number of update done
    eidx = 0
    estop = False
    start_time = time.time()
    train_err = 0.0
    valid_err = 0.0
    test_err = 0.0

    try:
        for eidx in xrange(max_epochs):

            kf = get_minibatches_idx(len(train[0]), batch_size, shuffle=True)

            #if eidx % 5 == 0 and eidx > 0:
            if eidx < 0:
                if dataset == 'dailymail':
                    train_err =  dailymail_eva(f_encode, f_probi, prepare_data, train, kf, model_options)
                    train_cost = dailymail_eval_cost(f_cost, prepare_data, train, kf, model_options)
                    print 'Train Cost', train_cost, 'Train P/R', train_err
                elif dataset == 'ducmulti':
                    train_err =  duc_multi_eva(f_encode, f_probi, prepare_data, train, kf, model_options)
                    train_cost = duc_multi_eval_cost(f_cost, prepare_data, train, kf, model_options)

                    valid_err =  duc_multi_eva(f_encode, f_probi, prepare_data, valid, kf_valid, model_options)
                    valid_cost = duc_multi_eval_cost(f_cost, prepare_data, valid, kf_valid, model_options)

                    test_err =   duc_multi_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options)

                    print 'Train Cost %.2f' % train_cost, 'Train P/R %.2f/%.2f' % train_err, 'Valid Cost %.2f' % valid_cost, 'Valid P/R %.2f/%.2f' % valid_err, 'Test P/R %.2f/%.2f' % test_err
                    print

            for _, train_index in kf:
                uidx += 1
                #print uidx
                sys.stdout.flush()

                #print 'train_index', train_index

                clusters = [train[0][t] for t in train_index]
                labels   = [train[1][t] for t in train_index]
                files    = [train[2][t] for t in train_index]
                nodes = [train[3][t] for t in train_index]
                x_node,x, x_mask_word, x_mask_sent, x_mask_doc, dec_inp, dec_inp_mask, dec_out, dec_out_mask = prepare_data(clusters, labels,nodes)

                #Sanity Check
                '''
                idx_word_map[0] = '0'

                cluster_id = 0
                f = files[cluster_id]
                print f

                dec_out = dec_out[:,cluster_id]
                dec_inp = dec_inp[:,cluster_id]
                print dec_inp
                print dec_out

                n_sents = x.shape[1]

                for d in dec_out:
                    if d == 0:
                        break
                    doc_id = int(d/n_sents)
                    sent_id = d % n_sents
                    x_d = x[:,sent_id,doc_id,cluster_id]
                    print f[doc_id], sent_id
                    print ' '.join(idx_word_map[s] for s in x_d)
                if uidx == 10:
                    sys.exit()
                continue
                '''

                '''
                print 'input data'
                print x.shape
                print x_mask_sent.shape
                print dec_inp.shape
                print dec_inp_mask.shape
                print dec_out.shape
                print dec_out_mask.shape
                '''

                '''
                print 'encode'
                proj_sent, proj_doc = f_encode(x, x_mask_word, x_mask_sent)
                print proj_sent.shape, numpy.any(numpy.isnan(proj_sent))
                print proj_doc.shape, numpy.any(numpy.isnan(proj_doc))

                print 'decode'
                preds = f_decode(x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask)
                print preds.shape, numpy.any(numpy.isnan(preds))

                print 'cost'
                print f_cost(x,x_mask_word,x_mask_sent,dec_inp,dec_inp_mask,dec_out,dec_out_mask)
                '''

                cost = f_train(x_node,x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask, dec_out, dec_out_mask)

                #cost = f_grad_shared(x, x_mask, x_mask_l, num_doc, max_llen, dec_inp, dec_inp_mask, dec_out, dec_out_mask)
                #f_update(lrate)

                if numpy.isnan(cost) or numpy.isinf(cost):
                    print 'NaN detected',uidx
                    continue
                    return 1., 1., 1.

                if numpy.mod(uidx, dispFreq) == 0:
                    print 'Epoch ', eidx, 'Update ', uidx, 'Cost ', cost

                if saveto and numpy.mod(uidx, saveFreq) == 0:
                    print 'Saving...',
                    sys.stdout.flush()

                    if best_p is not None:
                        params = best_p
                    else:
                        params = unzip(tparams)
                    numpy.savez(saveto+"."+str(uidx), history_err=history_err, **params)
                    pkl.dump(model_options, open('%s.pkl' % saveto, 'wb'), -1)
                    print 'Done'
                    sys.stdout.flush()

                if numpy.mod(uidx, validFreq) == 0:
                    if dataset == 'dailymail':
                        #train_err = dailymail_eva(f_encode, f_probi, prepare_data, train, kf, model_options)
                        valid_err = dailymail_eva(f_encode, f_probi, prepare_data, valid, kf_valid, model_options)
                        test_err  = dailymail_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options)

                        valid_cost = dailymail_eval_cost(f_cost, prepare_data, valid, kf_valid, model_options)
                        print ('Valid Cost', valid_cost, 'Valid P/R', valid_err, 'Test P/R', test_err)
                        #print ('Valid ', valid_err, 'Test ', test_err)
                        #print ('Train', train_err, 'Valid ', valid_err, 'Test ', test_err)
                    elif dataset == 'ducmulti':
                        train_err =  duc_multi_eva(f_encode, f_probi, prepare_data, train, kf, model_options)
                        train_cost = duc_multi_eval_cost(f_cost, prepare_data, train, kf, model_options)

                        valid_err =  duc_multi_eva(f_encode, f_probi, prepare_data, valid, kf_valid, model_options)
                        valid_cost = duc_multi_eval_cost(f_cost, prepare_data, valid, kf_valid, model_options)

                        test_err =   duc_multi_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options, write_file = writeto+'.test.'+str(uidx)) ####added

                        print 'Train Cost %.2f' % train_cost, 'Train P/R %.2f/%.2f' % train_err, 'Valid Cost %.2f' % valid_cost, 'Valid P/R %.2f/%.2f' % valid_err, 'Test P/R %.2f/%.2f' % test_err
                        print

                    history_err.append([valid_cost, 0.])

                    if best_p is None or valid_cost <= numpy.array(history_err)[:, 0].min():
                        best_p = unzip(tparams)
                        bad_counter = 0
                        #break

                    if len(history_err) > patience and valid_cost >= numpy.array(history_err)[:-patience, 0].min():
                        bad_counter += 1
                        if bad_counter > patience:
                            print 'Early Stop!'
                            estop = True
                            break
                    sys.stdout.flush()

            sys.stdout.flush()

            if estop:
                break

    except KeyboardInterrupt:
        print "Training interrupted"

    end_time = time.time()
    if best_p is not None:
        zipp(best_p, tparams)
    else:
        best_p = unzip(tparams)

    print 'Training Done'

    kf_train_sorted = get_minibatches_idx(len(train[0]), batch_size)
    if dataset == 'dailymail':
        if mode == 'train':
            train_err = dailymail_eva(f_encode, f_probi, prepare_data, train, kf_train_sorted, model_options)
            train_cost = dailymail_eval_cost(f_cost, prepare_data, train, kf_train_sorted, model_options)
        else:
            train_err = None
            train_cost = None

        valid_err  = dailymail_eva(f_encode, f_probi, prepare_data, valid, kf_valid, model_options, write_file = writeto+'.valid')
        valid_cost = dailymail_eval_cost(f_cost, prepare_data, valid, kf_valid, model_options)

        test_err   = dailymail_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options, write_file = writeto+'.test')
        print ('Train Cost', train_cost, 'Valid Cost', valid_cost, 'Train P/R', train_err, 'Valid P/R', valid_err, 'Test P/R', test_err)
    elif dataset == 'duc02single':
        dailymail_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options, write_file = writeto)
    elif dataset == 'duc04multi':
        dailymail_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options, write_file = writeto)
    elif dataset == 'ducmulti':
        train_err =  duc_multi_eva(f_encode, f_probi, prepare_data, train, kf_train_sorted, model_options)
        train_cost = duc_multi_eval_cost(f_cost, prepare_data, train, kf_train_sorted, model_options)

        valid_err =  duc_multi_eva(f_encode, f_probi, prepare_data, valid, kf_valid, model_options)
        valid_cost = duc_multi_eval_cost(f_cost, prepare_data, valid, kf_valid, model_options)

        test_err =   duc_multi_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options)

        print 'Train Cost %.2f' % train_cost, 'Train P/R %.2f/%.2f' % train_err, 'Valid Cost %.2f' % valid_cost, 'Valid P/R %.2f/%.2f' % valid_err, 'Test P/R %.2f/%.2f' % test_err
        print

        duc_multi_eva(f_encode, f_probi, prepare_data, test, kf_test, model_options, write_file = writeto)

    if saveto:
        numpy.savez(saveto, train_err=train_err, valid_err=valid_err, test_err=test_err,
                    history_err=history_err,
                    **best_p)
    print 'The code run for %d epochs, with %f sec/epochs' % ((eidx + 1), (end_time - start_time) / (1. * (eidx + 1)))
    print >> sys.stderr, ('Training took %.1fs' % (end_time - start_time))

    return train_err, valid_err, test_err


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Pointer Networks")
    parser.add_argument('-m', '--mode', choices=['train','test'], default='train', help='mode')
    parser.add_argument('-d', '--dim', type=int, default=256, help='dimension')
    parser.add_argument('-n', '--nodedim', type=int, default=128, help='node2vec dimension')
    parser.add_argument('-b', '--batch', type=int, default=128, help='batch size')
    parser.add_argument('-l', '--lrate', type=float, default=0.001, help='learning rate')
    parser.add_argument('-e', '--epochs', type=int, default=100, help='max training epochs')
    parser.add_argument('-p', '--patience', type=int, default=10, help='patience for early stopping')
    parser.add_argument('-o', '--optimizer', choices=['sgd', 'rmsprop', 'adadelta', 'adam'], default='rmsprop', help='optimizer')
    parser.add_argument('-r', '--reload', default=False, help='reload model')
    parser.add_argument('--dispf', type=int, default=128, help='display frequency')
    parser.add_argument('--validf', type=int, default=512, help='validation frequency')
    parser.add_argument('--savef', type=int, default=8192, help='saving frequency')
    parser.add_argument('--writeto', default='result', help='the result file')
    parser.add_argument('task', choices=['dailymail', 'duc02single', 'ducmulti' ], default='dailymail', help='task')
    parser.add_argument('datapath', help='path to training data.')
    parser.add_argument('saveto', help='save the model to...')
    args = parser.parse_args()
    print args
    opts = args.optimizer
    if opts == 'rmsprop':
        opt = rmsprop
    elif opts == 'adadelta':
        opt = adadelta
    elif opts == 'adam':
        opt = adam
    else:
        opt = sgd

    if args.mode == 'test':
        args.reload = args.saveto
        args.saveto = None
        args.epochs = 0   # No Training

    # See function train for all possible parameter and there definition.
    train_lstm(
        dataset=args.task,
        max_epochs=args.epochs,
        patience=args.patience,
        dim_proj=args.dim,
        node_dim=args.nodedim,
        lrate=args.lrate,
        validFreq=args.validf,
        saveFreq=args.savef,
        dispFreq=args.dispf,
        batch_size=args.batch,
        valid_batch_size=10,
        optimizer=opt,
        saveto=args.saveto,
        datapath=args.datapath,
        reload_model=args.reload,
        mode=args.mode,
        writeto = args.writeto,
    )
