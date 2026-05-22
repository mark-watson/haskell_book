#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""SpaCy NLP entity extraction and tokenization server.
A simple server providing NLP entity extraction and tokenization via spaCy.

"""
from __future__ import unicode_literals
from __future__ import print_function

import json
from urllib.parse import unquote
from wsgiref.simple_server import make_server
import falcon
import spacy

unicode_ = str      # Python 3

class AllResource(object):
    def __init__(self):
        self.nlp = spacy.load('en_core_web_sm')
        print("Server loaded")
        self.response = None

    def on_get(self, req, resp):
        self.response = {}

        text_param = req.get_param("text")
        if text_param is not None:
            
            text = ",".join(text_param) if isinstance(text_param, list) else text_param
            text = unicode_(text)
            text = unquote(text)
            print("** text=", text)
            doc = self.nlp(text)
            #print("** doc=", doc)
            self.response['entities'] = [ent.text + "/" + ent.label_ for ent in doc.ents]
            self.response['tokens'] = [token.text for token in doc]

            resp.text = json.dumps(self.response)
            resp.content_type = 'application/json'
        resp.append_header('Access-Control-Allow-Origin', "*")
        resp.status = falcon.HTTP_200

if __name__ == '__main__':
    RESSOURCE = AllResource()
    APP = falcon.App()
    APP.add_route('/', RESSOURCE)
    HTTPD = make_server('127.0.0.1', 8008, APP)
    HTTPD.serve_forever()
