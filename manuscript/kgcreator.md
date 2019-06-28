# Knowledge Graph Creator

The large project described here processes raw text inputs and generates data for knowledge graphs in formats for both the Neo4J graph database and in RDF format for semantic web and linked data applications.

This application works by identifying entities in text. Example entity types are people, companies, country names, city names, broadcast network names, political party names, and university names. We saw earlier code for detecting entities in the chapter on natural language processing (NLP) and we will reuse this code.