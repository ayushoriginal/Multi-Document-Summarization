from collections import OrderedDict

import random
import numpy
import theano
from theano import config
import theano.tensor as tensor
from theano.sandbox.rng_mrg import MRG_RandomStreams as RandomStreams

from utils import *
from utils import _p
from optimizer import *

def dropout_layer(state_before, use_noise, trng):
    proj = tensor.switch(use_noise,
                         (state_before *
                          trng.binomial(state_before.shape,
                                        p=0.5, n=1,
                                        dtype=state_before.dtype)),
                         state_before * 0.5)
    return proj

def init_params(options):
    params = OrderedDict()

    # Word Embeddings
    if options['W'] is None:
        params['Wemb'] = (0.01 * numpy.random.rand(options['n_words'],options['data_dim'])).astype(config.floatX)
    else:
        params['Wemb'] = options['W'][1:,:].astype(config.floatX) # skipping the first zero column since we have padding in sentence encoder

    # GRU Sentence Encoder
    params = param_init_gru(options, params, prefix='gru_sent', nin=options['data_dim'],dim=(options['dim_proj']-options['node_dim']))
    """ ADDED """

    # GRU Document Encoder
    params = param_init_gru(options, params, prefix='gru_doc')


    '''
    # lstm gates parameters
    W = numpy.concatenate([rand_weight(options['data_dim'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['data_dim'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['data_dim'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['data_dim'], options['dim_proj'], -0.08, 0.08)], axis=1)
    params['lstm_en_W'] = W
    U = numpy.concatenate([rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08)], axis=1)
    params['lstm_en_U'] = U
    b = numpy.zeros((4 * options['dim_proj'],))
    params['lstm_en_b'] = b.astype(config.floatX)
    '''

    # LSTM decoder
    W = numpy.concatenate([rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08)], axis=1)
    params['lstm_de_W'] = W
    U = numpy.concatenate([rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08),
                           rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08)], axis=1)
    params['lstm_de_U'] = U
    b = numpy.zeros((4 * options['dim_proj'],))
    params['lstm_de_b'] = b.astype(config.floatX)

    #params['lstm_hterm'] = rand_weight(options['dim_proj'], 1, -0.08, 0.08)[:, 0]

    # ptr parameters
    params['ptr_W1'] = rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08)
    params['ptr_W2'] = rand_weight(options['dim_proj'], options['dim_proj'], -0.08, 0.08)
    params['ptr_v'] = rand_weight(options['dim_proj'], 1, -0.08, 0.08)[:, 0]

    return params

# GRU layer
def param_init_gru(options, params, prefix='gru', nin=None, dim=None):
    """
    Gated Recurrent Unit (GRU)
    """
    if nin == None:
        nin = options['dim_proj']
    if dim == None:
        dim = options['dim_proj']

    W = numpy.concatenate([norm_weight(nin,dim),
                           norm_weight(nin,dim)], axis=1)
    params[_p(prefix,'W')] = W
    params[_p(prefix,'b')] = numpy.zeros((2 * dim,)).astype(config.floatX)

    U = numpy.concatenate([ortho_weight(dim),
                           ortho_weight(dim)], axis=1)
    params[_p(prefix,'U')] = U

    Wx = norm_weight(nin, dim)
    params[_p(prefix,'Wx')] = Wx
    Ux = ortho_weight(dim)
    params[_p(prefix,'Ux')] = Ux
    params[_p(prefix,'bx')] = numpy.zeros((dim,)).astype(config.floatX)

    return params

def gru_layer(tparams, state_below, options, init_state=None, prefix='gru', mask=None, **kwargs):
    """
    Feedforward pass through GRU
    """
    nsteps = state_below.shape[0]
    if state_below.ndim == 3:
        n_samples = state_below.shape[1]
    else:
        n_samples = 1

    dim = tparams[_p(prefix,'Ux')].shape[1]

    if init_state == None:
        init_state = tensor.alloc(0., n_samples, dim)

    if mask == None:
        mask = tensor.alloc(1., state_below.shape[0], 1)

    def _slice(_x, n, dim):
        if _x.ndim == 3:
            return _x[:, :, n*dim:(n+1)*dim]
        return _x[:, n*dim:(n+1)*dim]

    state_below_ = tensor.dot(state_below, tparams[_p(prefix, 'W')]) + tparams[_p(prefix, 'b')]
    state_belowx = tensor.dot(state_below, tparams[_p(prefix, 'Wx')]) + tparams[_p(prefix, 'bx')]
    U = tparams[_p(prefix, 'U')]
    Ux = tparams[_p(prefix, 'Ux')]

    def _step_slice(m_, x_, xx_, h_, U, Ux):
        preact = tensor.dot(h_, U)
        preact += x_

        r = tensor.nnet.sigmoid(_slice(preact, 0, dim))
        u = tensor.nnet.sigmoid(_slice(preact, 1, dim))

        preactx = tensor.dot(h_, Ux)
        preactx = preactx * r
        preactx = preactx + xx_

        h = tensor.tanh(preactx)

        h = u * h_ + (1. - u) * h
        h = m_[:,None] * h + (1. - m_)[:,None] * h_

        return h

    seqs = [mask, state_below_, state_belowx]
    _step = _step_slice

    rval, updates = theano.scan(_step,
                                sequences=seqs,
                                outputs_info = [init_state],
                                non_sequences = [tparams[_p(prefix, 'U')],
                                                 tparams[_p(prefix, 'Ux')]],
                                name=_p(prefix, '_layers'),
                                n_steps=nsteps,
                                profile=False,
                                strict=True)
    #rval = [rval]
    return rval

def document_encoder(tparams, options, x_node,x, x_mask_word, x_mask_sent, x_mask_doc):
    n_timesteps = x.shape[0]
    n_sents     = x.shape[1]
    n_docs      = x.shape[2]
    n_clusters  = x.shape[3]
    node_dim = x_node.shape[0]

    total_sents = n_sents * n_docs * n_clusters
    total_docs  =           n_docs * n_clusters

    # pad a zero vector for word idx 0
    pad = theano.shared(numpy.zeros((1,options['data_dim']), dtype=theano.config.floatX))
    E = tensor.concatenate([pad,tparams['Wemb']])
    emb = E[x.flatten()].reshape([n_timesteps,total_sents,options['data_dim']])

    # GRU Sentence Encoder
    x_mask_word_reshape = x_mask_word.reshape([n_timesteps,total_sents])
    proj_sent = gru_layer(tparams,emb,options,prefix='gru_sent',mask=x_mask_word_reshape) # n_timesteps x total_sents x dim_proj

    # Take the final step as sentence embeddings
    proj_sent = proj_sent[-1]     # total_sents x dim_proj
    x_node_reshaped = x_node.reshape([node_dim,total_sents]).dimshuffle(1,0) # total_n_sents x 128
    proj_sent = tensor.concatenate([proj_sent,x_node_reshaped], axis=1)
    """ADDED node2vec HERE"""

    # GRU Document Encoder
    proj = proj_sent.reshape([n_sents,total_docs,options['dim_proj']]) # n_sents x total_docs x dim_proj


    x_mask_sent_reshape = x_mask_sent.reshape([n_sents,total_docs])
    proj_sent = gru_layer(tparams,proj,options,prefix='gru_doc',mask=x_mask_sent_reshape) # n_sents x total_docs x dim_proj

    # Average Pooling to get document embeddings
    proj_doc = (proj_sent * x_mask_sent_reshape[:,:,None]).sum(axis=0)                    # total_docs x dim_proj
    proj_doc = proj_doc / tensor.maximum(1.0, x_mask_sent_reshape.sum(axis=0)[:,None])    # total_docs x dim_proj

    proj_doc = proj_doc.reshape([n_docs, n_clusters, options['dim_proj']])                #           n_docs x n_clusters x dim_proj
    proj_sent = proj_sent.reshape([n_sents, n_docs, n_clusters ,options['dim_proj']])     # n_sents x n_docs x n_clusters x dim_proj

    return proj_doc, proj_sent

def ptr_network(tparams, x_node,x, x_mask_word, x_mask_sent, x_mask_doc,
                dec_inp, dec_inp_mask,
                xi, xi_mask, hidi, celi, hids, options):
    #TODO: think about if padding etc. is correct
    #TODO: how to use x_mask_doc: average pooling over proj_doc as the initalization of controller LSTM hidden state

    n_timesteps = x.shape[0]
    n_sents     = x.shape[1]
    n_docs      = x.shape[2]
    n_clusters  = x.shape[3]


    #proj_doc:            n_docs x n_clusters x dim_proj
    #proj_sent: n_sents x n_docs x n_clusters x dim_proj
    proj_doc, proj_sent = document_encoder(tparams, options, x_node,x, x_mask_word, x_mask_sent, x_mask_doc)

    f_encode = theano.function([x_node,x, x_mask_word, x_mask_sent], [proj_sent, proj_doc])

    n_steps = dec_inp.shape[0]  # number of decoding steps
    beam_width = xi.shape[0]

    assert x_mask_word is not None
    assert x_mask_sent is not None
    assert x_mask_doc is not None
    assert dec_inp_mask is not None
    assert xi_mask is not None

    def _slice(_x, n, dim):
        if _x.ndim == 3:
            return _x[:, :, n * dim:(n + 1) * dim]
        if _x.ndim == 2:
            return _x[:, n * dim:(n + 1) * dim]
        return _x[n * dim:(n + 1) * dim]

    def _lstm(m_, x_, h_, c_, prefix='lstm_en'):
        preact = tensor.dot(x_, tparams[_p(prefix, 'W')]) + tparams[_p(prefix, 'b')]
        preact += tensor.dot(h_, tparams[_p(prefix, 'U')])

        i = tensor.nnet.sigmoid(_slice(preact, 0, options['dim_proj']))
        f = tensor.nnet.sigmoid(_slice(preact, 1, options['dim_proj']))
        o = tensor.nnet.sigmoid(_slice(preact, 2, options['dim_proj']))
        c = tensor.tanh(_slice(preact, 3, options['dim_proj']))

        c = f * c_ + i * c
        c = m_[:, None] * c + (1. - m_)[:, None] * c_
        h = o * tensor.tanh(c)
        h = m_[:, None] * h + (1. - m_)[:, None] * h_

        return h, c

    def softmax(m_, x_):
        #m_: n_sents x n_docs x n_clusters
        #x_: n_sents x n_docs x n_clusters

        n_sents    = m_.shape[0]
        n_docs     = m_.shape[1]
        n_clusters = m_.shape[2]

        # Option1: Reshape m_ and x_ such that we apply softmax at each document
        m_ = m_.reshape([n_sents, n_docs * n_clusters])
        x_ = x_.reshape([n_sents, n_docs * n_clusters])

        # Option2: Reshape m_ and x_ such that we apply softmax at each cluster
        #m_ = m_.reshape([n_sents * n_docs, n_clusters])
        #x_ = x_.reshape([n_sents * n_docs, n_clusters])

        maxes = tensor.max(x_, axis=0, keepdims=True)
        e = tensor.exp(x_ - maxes)
        #TODO: might cause NaN here!
        #It should be okay, because m_ (hiddens_mask) will always first 1., and elements in e are non-zero
        dist = e / tensor.sum(e * m_, axis=0)

        dist = dist.reshape([n_sents,n_docs,n_clusters])
        return dist

    def _ptr_probs(xm_, x_, h_, c_, _, hprevs, hprevs_m):
        # xm_: n_clusters
        # x_:  n_clusters

        # h_:  n_clusters x dim_proj
        # c_:  n_clusters x dim_proj
        # _:   n_sents x n_docs x n_clusters

        # hprevs:    n_sents x n_docs x n_clusters x dim_proj
        # hprevs_m:  n_sents x n_docs x n_clusters

        n_sents =    hprevs_m.shape[0]
        n_docs =     hprevs_m.shape[1]
        n_clusters = hprevs_m.shape[2]

        hprevs_contiguous = hprevs.dimshuffle(1,0,2,3).reshape([-1, n_clusters, options['dim_proj']])
        xemb = hprevs_contiguous[x_, tensor.arange(n_clusters), :]  # n_clusters x dim_proj

        # Update Controller LSTM
        h, c = _lstm(xm_, xemb, h_, c_, 'lstm_de')

        # Calculate Scores for Sentences
        u = tensor.dot(hprevs, tparams['ptr_W1']) + tensor.dot(h, tparams['ptr_W2'])   # n_sents x n_docs x n_clusters x dim_proj
        u = tensor.tanh(u)                   # n_sents x n_docs x n_clusters x dim_proj
        u = tensor.dot(u, tparams['ptr_v'])  # n_sents x n_docs x n_clusters

        # For each document, apply softmax
        prob = softmax(hprevs_m, u)          # n_sents x n_docs x n_clusters

        return h, c, prob

    # decoding
    hiddens = proj_sent # n_sents x n_docs x n_clusters x dim_proj

    #hiddens_mask = tensor.set_subtensor(x_mask_sent[0, :], tensor.constant(1, dtype=config.floatX)) # n_sents x n_docs x n_clusters
    # Every document has the first mask as 1
    hiddens_mask = tensor.set_subtensor(x_mask_sent[0, :, :], tensor.constant(1, dtype=config.floatX)) # n_sents x n_docs x n_clusters

    rval, _ = theano.scan(_ptr_probs,
                          sequences=[dec_inp_mask, dec_inp],
                          outputs_info=[proj_doc.mean(axis=0),       # h_0: n_clusters x dim_proj
                                        tensor.alloc(numpy_floatX(0.), n_clusters, options['dim_proj']),
                                        tensor.alloc(numpy_floatX(0.), n_sents, n_docs, n_clusters)],
                          non_sequences=[hiddens, hiddens_mask],
                          name='decoding',
                          n_steps=n_steps)

    preds = rval[2] # n_steps x n_sents x n_docs x n_clusters

    f_decode = theano.function([x_node,x, x_mask_word, x_mask_sent, dec_inp, dec_inp_mask], preds)

    # TODO
    # generating
    # xi, vector
    # xi_mask, vector
    # hidi, matrix beam_width * dim_proj
    # celi matrix beam_width * dim_proj
    # hids, tensor3D
    # c0 = tensor.alloc(numpy_floatX(0.), beam_width, options['dim_proj'])

    u0 = tensor.alloc(numpy_floatX(0.), hidi.shape[0], beam_width)  # note that u0 is actually not used in _ptr_probs
    hiddeni, celli, probi = _ptr_probs(xi_mask, xi, hidi, celi, u0, hids, hiddens_mask)
    f_probi = theano.function(inputs=[xi_mask, xi, hidi, celi, hids, x_mask_sent], outputs=[hiddeni, celli, probi], on_unused_input='ignore')

    return preds, f_encode, f_decode, f_probi
