# Section 3 - Larger Projects

This section is new for the second edition of this book. So far we have covered the basics of Haskell programming and seen many short examples. In this section we look at a few larger projects and hopefully encourage you to think of novel uses for Haskell in your own work.

The project **knowledge_graph_creator** helps to automate the process of creating Knowledge Graphs from raw text input and generates data for both the Neo4J open source graph database as well as RDF data for use in semantic web and linked data applications. I have also implemented this same application in Common Lisp that is also a new example in the latest edition of my book [Loving Common Lisp, Or The Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp).

The next two chapters in this section are similar in that they both use examples of using Python for Natural Language Processing (NLP) tasks, wrapping the Python code as a REST service, and then writing Haskell clients for these services.

The project **HybridHaskellPythonNlp** uses web services written in Python for natural language processing. The Python web services use the SpaCy library.

The project **HybridHaskellPythonCorefAnaphoraResolution** uses web services written in Python to allow Haskell applications to use deep learning models created with TensorFlow and Keras.
