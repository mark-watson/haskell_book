#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Coreference resolution server example.
A simple server serving the coreference system.

This file is copied and modified from an example
program from https://github.com/huggingface/neuralcoref

"""
from __future__ import unicode_literals
from __future__ import print_function

import json
from wsgiref.simple_server import make_server
import falcon
import spacy
from fastcoref import spacy_component

unicode_ = str      # Python 3


class AllResource(object):
    def __init__(self):
        # Load spaCy model and add fastcoref component
        self.nlp = spacy.load('en_core_web_sm')
        self.nlp.add_pipe("fastcoref")
        print("Server loaded")
        self.response = None

    def on_get(self, req, resp):
        self.response = {}

        text_param = req.get_param("text")
        no_detail  = req.get_param("no_detail")
        if text_param is not None:
            text = ",".join(text_param) if isinstance(text_param, list) else text_param
            text = unicode_(text)
            text = text.replace("%20", " ").replace("%3B", ";").replace("%2C", ",").replace("%3A", ":").replace("%24","$").replace("%2C",",")
            print("** text=", text)
            
            # Run pipeline and resolve coreference text
            doc = self.nlp(text, component_cfg={"fastcoref": {"resolve_text": True}})
            resolved = doc._.resolved_text if doc._.resolved_text is not None else text
            
            if no_detail is not None:
                self.response = resolved
                resp.text = self.response
                resp.content_type = 'application/text'
            else:
                raw_clusters = doc._.coref_clusters or []
                mentions = []
                clusters = []
                
                for cluster_spans in raw_clusters:
                    if not cluster_spans:
                        continue
                    main_start, main_end = cluster_spans[0]
                    main_text = text[main_start:main_end]
                    
                    cluster_texts = []
                    for start, end in cluster_spans:
                        mention_text = text[start:end]
                        cluster_texts.append(mention_text)
                        
                        mentions.append({
                            'start': start,
                            'end': end,
                            'text': mention_text,
                            'resolved': main_text
                        })
                    clusters.append(cluster_texts)
                
                self.response['mentions'] = mentions
                self.response['clusters'] = clusters
                self.response['resolved'] = resolved

                resp.text = json.dumps(self.response)
                resp.content_type = 'application/json'
        
        resp.append_header('Access-Control-Allow-Origin', "*")
        resp.status = falcon.HTTP_200

if __name__ == '__main__':
    RESSOURCE = AllResource()
    APP = falcon.App()
    APP.add_route('/', RESSOURCE)
    HTTPD = make_server('0.0.0.0', 8000, APP)
    HTTPD.serve_forever()

