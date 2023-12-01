# Adaptive Proximal Algorithms

This repository contains Julia code for experiments of the paper

> Latafat, Themelis, Patrinos, *On the convergence of adaptive first order methods: proximal gradient and alternating minimization algorithms*, [arXiv:2301.04431](https://arxiv.org/abs/2301.04431) (2023).

Algorithms are implemented in [this](https://github.com/pylat/adaptive-proximal-algorithms) repository. 

## Running experiments

Install the package following the instructions of [the main repository](https://github.com/pylat/adaptive-proximal-algorithms) above. 


Then, you can download the datasets required in some of the experiments by running:

```
julia --project=. download_datasets.jl
```

Numerical simulations for different problems are contained in subfolders.
For example, the lasso example can be found [here](https://github.com/pylat/adaptive-proximal-algorithms-extended-experiments/tree/master/experiments/lasso). The `runme.jl` file includes the associated simulations. Executing `main()` will generate the plots in the same subfolder.
