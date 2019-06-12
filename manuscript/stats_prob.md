# Statistics and Probability

While it is more common to use scripting languages like Python and R for data engineering there are also advantages to using a strongly typed language to design and implement data processing pipelines. Here I show you how to perform common statistical and probailistic operations on data.

TBD - more background

## Using the Math.Statistics Package

[**Math.Statistics**](https://hackage.haskell.org/package/statistics) was implemented by Bryan O'Sullivan. Here we work with discrete and continous probability distributions, calculate correlation between two datasets, and perform commonly used statistical tests.

### Kernel Density Estimation

Kernel Density Estimation (KDE) is used to estimate a smoothed kernel distribution given noisy random data. I refer you to the [Wikipedia page for KDE](https://en.wikipedia.org/wiki/Kernel_density_estimation) for background informstion. Here we concentrate on Haskell examples but I will assume that you have read throught the Wikipedia KDE page.

### KMeans

