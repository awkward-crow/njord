# Hazard module
# Fits frequency and severity models to historical storm footprints derived
# from ERA5/Copernicus CDS gust-speed data. Frequency is modelled with a
# negative binomial distribution; severity uses a GPD tail above a threshold.
# Produces a simulated event set for use in the trigger and basis risk modules.
