using UnityEngine;
using AEPsych;

public class ColorConfigGenerator : ConfigGenerator
{
    public override string GetConfigText()
    {
        return @"[common]
parnames = [x0_dim1, x0_dim2, delta_dim1, delta_dim2]
stimuli_per_trial = 1
outcome_types = [binary]
target = 0.667
strategy_names = [init_strat, opt_strat]

[x0_dim1]
par_type = continuous
lower_bound = -0.7
upper_bound = 0.7

[x0_dim2]
par_type = continuous
lower_bound = -0.7
upper_bound = 0.7

[delta_dim1]
par_type = continuous
lower_bound = -0.3
upper_bound = 0.3

[delta_dim2]
par_type = continuous
lower_bound = -0.3
upper_bound = 0.3

[init_strat]
min_asks = 900
generator = SobolGenerator

[opt_strat]
min_asks = 5100
refit_every = 20
generator = OptimizeAcqfGenerator
model = GPClassificationModel

[GPClassificationModel]
inducing_size = 100
mean_covar_factory = default_mean_covar_factory

[OptimizeAcqfGenerator]
restarts = 10
samps = 1000
acqf = MCLevelSetEstimation

[MCLevelSetEstimation]
beta = 3.84
objective = ProbitObjective
target = 0.667";
    }
}