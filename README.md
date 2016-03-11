# rpcops-onmetal-labconfigurator
Configuration script that builds out a X node lab environment for onboarding and testing purposes for Rackspace Private Cloud.

Note:
This uses a trial license from Citrix - NetScaler VPX 1000 - which is good for 90 days. Once your lab is online, check the loadbalancer via SSH with the command 'show license'. You will want to be sure you see the following:

	License status:
	                ...
	                Load Balancing: YES
	                ...

If not, run the following command to get the latest license file, remove the current license, and install the new license:
## need to add command ##
