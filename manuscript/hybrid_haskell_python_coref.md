# Hybrid Haskell and Python For Coreference Resolution

Coreference resolution is also called anaphora resolution and is the process for replacing pronouns in text with the original nouns, proper nouns, or noun phrases that the pronouns refer to.

Before discussing setting up the Python library for performing coreference analysis and the Haskell client, let's run the client so you can see and understand anaphora resolution:

 ~~~~~~~~
 $ stack build --fast --exec HybridHaskellPythonCorefAnaphoraResolution-exe
Enter text (all on one line)
John Smith drove a car. He liked it.


***  Processing John%20Smith%20drove%20a%20car.%20He%20liked%20it.
status code: 200
content type: Just "application/text"
response body: John Smith drove a car. John Smith liked a car.
response from coreference server:	"John Smith drove a car. John Smith liked a car."
Enter text (all on one line)
~~~~~~~~

In this example notice that the words "He" and "it" in the second sentence are replaced by "John Smith" and "a car" which makes it easier to write information extraction applications.

## Installing the Python Coreference Server

I recommend that you use virtual Python environments when using Python applications to separate the dependencies required for each application or development project. Here I assume that you are running in a Python version 3.6 (or higher) version environment. First install the dependencies:

~~~~~~~~
pip install spacy==2.1.0
pip install neuralcoref 
~~~~~~~~

As I write this chapter the *neuralcoref* model and library require a slightly older version of SpaCy (the current latest version is 2.1.4).

Then change directory to the subdirectory **python_coreference_anaphora_resolution_server** and install the coref server:

~~~~~~~~
cd python_coreference_anaphora_resolution_server
python setup.py install
~~~~~~~~

Once you install the server, then you can run it from any directory on your laptop or server using:

~~~~~~~~
corefserver
~~~~~~~~

I use deep learning models written in Python using TensorFlow or PyTorch in applications I write in Haskell or Common Lisp. While it is possible to directly embed models in Haskell and Common Lisp, I find it much easier and developer friendly to wrap deep learning models I need a REST services as I have done here. Often deep learning models only require about a gigabyte of memory and using pre-trained models has light weight CPU resource needs so while I am developing on my laptop I might have two or three models running and available as wrapped REST services. For production, I configure both the Python services and my Haskell and Common Lisp applications to start automatically on system startup.

This is not a Python programming book and I will not discuss the simple Python wrapping code but if you are also a Python developer you can easily read and understand the code.

## Understanding the Haskell Coreference Client Code

TBD

