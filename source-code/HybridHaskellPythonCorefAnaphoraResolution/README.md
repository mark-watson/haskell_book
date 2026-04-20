# HybridHaskellPythonCorefAnaphoraResolution

**Book Chapter:** [Hybrid Haskell and Python For Coreference Resolution](https://leanpub.com/read/haskell-cookbook/hybrid-haskell-and-python-for-coreference-resolution) — *Haskell Tutorial and Cookbook* (free to read online).

This project uses a the BERT model with the spaCy NP library.

To run the Python server that the Haskell code in this project calls, 'cd python_coreference_anaphora_resolution_server'
and follow the instructions in the README.md file.

## Running the Haskell client

    stack build --fast --exec HybridHaskellPythonCorefAnaphoraResolution-exe