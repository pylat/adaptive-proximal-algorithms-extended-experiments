# Adaptive Proximal Algorithms

This repository contains Julia code for the paper

> Latafat, Themelis, Patrinos, *On the convergence of adaptive first order methods: proximal gradient and alternating minimization algorithms*, [arXiv:???](https://arxiv.org/abs/2301.04431) (2023).

Algorithms are implemented . 

## Running experiments

Install the package following the instructions of the [sister repository](https://github.com/pylat/adaptive-proximal-algorithms)

Then run the scripts from the subfolders here. 
For example, run the lasso experiments as follows:

```sh
julia --project=./experiments experiments/lasso/runme.jl
```

This will generate plots in the same subfolder.
